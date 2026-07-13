import SwiftUI
import AVFoundation

/// What to do with a scanned code.
enum ScanResult {
    case accept
    case reject(String)
}

/// A camera scanner screen with a viewfinder and an instruction line.
/// Used to register a new stop-code from the menu.
struct QRScannerScreen: View {
    let title: String
    let instruction: String
    let onFound: (String) -> ScanResult

    @Environment(\.dismiss) private var dismiss
    @State private var authorization: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var errorText: String?
    @State private var lastHandled = ""

    var body: some View {
        ZStack {
            Color.oathBlack.ignoresSafeArea()

            switch authorization {
            case .authorized: cameraLayer
            case .notDetermined: Color.oathBlack.onAppear(perform: requestAccess)
            default: permissionDenied
            }

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.title2.weight(.semibold))
                            .foregroundColor(.oathWhite).padding(12)
                            .background(Color.oathWhite.opacity(0.15), in: Circle())
                    }
                    Spacer()
                }
                .padding()
                Spacer()
                Text(errorText ?? instruction)
                    .font(.headline).foregroundColor(.oathWhite).multilineTextAlignment(.center)
                    .padding()
                    .background(Color.oathBlack.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.bottom, 40)
                    .animation(.default, value: errorText)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var cameraLayer: some View {
        ZStack {
            CameraPreview { handle($0) }.ignoresSafeArea()
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.oathWhite.opacity(0.9), lineWidth: 3)
                .frame(width: 240, height: 240)
        }
    }

    private var permissionDenied: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.metering.none").font(.system(size: 48)).foregroundColor(.oathWhite)
            Text(S.t("Camera access is off.", "Kamerazugriff ist deaktiviert."))
                .font(.headline).foregroundColor(.oathWhite)
            Text(S.t("Allow camera access in Settings to scan the QR code. Otherwise use the emergency code.",
                     "Erlaube den Kamerazugriff in den Einstellungen, um den QR-Code zu scannen. Alternativ nutze den Notfall-Code."))
                .font(.subheadline).foregroundColor(.oathWhite.opacity(0.8))
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Button(S.t("Open Settings", "Einstellungen öffnen")) {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .buttonStyle(.borderedProminent).tint(.oathAccent)
        }
    }

    private func requestAccess() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { authorization = granted ? .authorized : .denied }
        }
    }

    private func handle(_ code: String) {
        guard code != lastHandled else { return }
        lastHandled = code
        switch onFound(code) {
        case .accept: dismiss()
        case .reject(let message):
            errorText = message
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { lastHandled = "" }
        }
    }
}

/// UIKit AVFoundation camera preview that reports scanned QR payloads.
struct CameraPreview: UIViewControllerRepresentable {
    let onFound: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFound: onFound) }
    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController(); vc.delegate = context.coordinator; return vc
    }
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    final class Coordinator: NSObject, ScannerViewControllerDelegate {
        let onFound: (String) -> Void
        init(onFound: @escaping (String) -> Void) { self.onFound = onFound }
        func scanner(_ controller: ScannerViewController, didFind code: String) { onFound(code) }
    }
}

protocol ScannerViewControllerDelegate: AnyObject {
    func scanner(_ controller: ScannerViewController, didFind code: String)
}

/// Minimal AVFoundation QR capture controller.
final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: ScannerViewControllerDelegate?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let sessionQueue = DispatchQueue(label: "timeoath.camera")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer

        sessionQueue.async { [weak self] in self?.session.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            if self?.session.isRunning == true { self?.session.stopRunning() }
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }
        delegate?.scanner(self, didFind: value)
    }
}
