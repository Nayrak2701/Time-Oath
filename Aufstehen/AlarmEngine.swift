import AVFoundation
import MediaPlayer
import UIKit

/// Audio engine for a *reliable* alarm on iOS without the Critical Alerts
/// entitlement (which a free developer account can't get).
///
/// Trick used by real alarm apps: keep a `.playback` audio session alive in the
/// background by looping a silent track. Media audio is **not** silenced by
/// Do-Not-Disturb / Focus or by the ring/mute switch — so when the alarm time
/// arrives we swap the silent track for the loud tone and it actually sounds,
/// even on a locked phone in DND. The app also raises the system output volume
/// so "full" really means full.
@MainActor
final class AlarmEngine {

    static let notificationSoundName = "alarm.wav"

    private var keepAlivePlayer: AVAudioPlayer?
    private var alarmPlayer: AVAudioPlayer?
    private var volumeView: MPVolumeView?

    private(set) var isKeepAliveRunning = false
    private(set) var isAlarmPlaying = false

    // MARK: - Keep-alive (silent background audio)

    /// Start looping silence so the app stays alive in the background until the
    /// alarm fires. Interrupts other audio on purpose — reliability over politeness.
    func startKeepAlive() {
        guard !isKeepAliveRunning, !isAlarmPlaying else { return }
        activateSession()
        guard let url = Bundle.main.url(forResource: "silence", withExtension: "wav"),
              let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.numberOfLoops = -1
        p.volume = 1.0                 // it's digital silence; keeps the session busy
        p.prepareToPlay()
        p.play()
        keepAlivePlayer = p
        isKeepAliveRunning = true
    }

    func stopKeepAlive() {
        guard !isAlarmPlaying else { return }   // never kill audio while ringing
        keepAlivePlayer?.stop()
        keepAlivePlayer = nil
        isKeepAliveRunning = false
        deactivateSession()
    }

    // MARK: - Loud alarm

    func startAlarm(volume: Float) {
        activateSession()
        keepAlivePlayer?.stop(); keepAlivePlayer = nil
        isKeepAliveRunning = false

        setSystemVolume(volume)        // pull the hardware volume up to the setting

        guard let url = Bundle.main.url(forResource: "alarm", withExtension: "wav"),
              let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.numberOfLoops = -1
        p.volume = 1.0                 // app level full; loudness comes from system volume
        p.prepareToPlay()
        p.play()
        alarmPlayer = p
        isAlarmPlaying = true

        // Re-assert the system volume shortly after — iOS sometimes settles it late.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.setSystemVolume(volume)
        }
    }

    /// Stop the loud tone. If `keepAlive` is true (alarm still armed for next day),
    /// resume the silent keep-alive so the app stays ready.
    func stopAlarm(keepAlive: Bool) {
        alarmPlayer?.stop()
        alarmPlayer = nil
        isAlarmPlaying = false
        if keepAlive {
            startKeepAlive()
        } else {
            deactivateSession()
        }
    }

    // MARK: - Session

    private func activateSession() {
        let s = AVAudioSession.sharedInstance()
        // `.playback` = plays through the mute switch and is not silenced by DND.
        try? s.setCategory(.playback, options: [.duckOthers])
        try? s.setActive(true)
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    // MARK: - System volume

    /// Raise the hardware output volume by driving a hidden MPVolumeView slider.
    private func setSystemVolume(_ value: Float) {
        let v = max(0, min(1, value))
        if volumeView == nil, let window = anyWindow() {
            let mv = MPVolumeView(frame: CGRect(x: -2000, y: -2000, width: 1, height: 1))
            mv.isHidden = false        // must be in a window & not hidden to work
            window.addSubview(mv)
            volumeView = mv
        }
        guard let slider = volumeView?.subviews.compactMap({ $0 as? UISlider }).first else { return }
        slider.value = v
        slider.sendActions(for: .valueChanged)
    }

    /// Any attached window — works even in the background (no key window),
    /// so the volume boost still applies when the phone is locked.
    private func anyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
            ?? scenes.flatMap { $0.windows }.first
    }
}
