import SwiftUI
import UIKit

/// Renders the printable QR sheet as a PDF at runtime, so the code shown in the
/// app can be printed or saved straight from the phone.
enum QRSheet {

    /// Write an A4 PDF for `value` to a temp file and return its URL.
    static func makePDF(value: String) -> URL? {
        let pageW: CGFloat = 595.2, pageH: CGFloat = 841.8   // A4 @ 72 dpi
        let bounds = CGRect(x: 0, y: 0, width: pageW, height: pageH)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Aufstehen-QR.pdf")

        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()

                func centered(_ text: String, font: UIFont, color: UIColor, y: CGFloat) {
                    let p = NSMutableParagraphStyle(); p.alignment = .center
                    let attrs: [NSAttributedString.Key: Any] =
                        [.font: font, .foregroundColor: color, .paragraphStyle: p]
                    let h = font.lineHeight * 1.4
                    (text as NSString).draw(in: CGRect(x: 40, y: y, width: pageW - 80, height: h),
                                            withAttributes: attrs)
                }

                centered("Aufstehen", font: .systemFont(ofSize: 34, weight: .bold),
                         color: UIColor(red: 0.25, green: 0.16, blue: 0.43, alpha: 1), y: 60)
                centered("QR-Code zum Stoppen des Weckers",
                         font: .systemFont(ofSize: 16), color: .darkGray, y: 110)

                // QR.
                let side: CGFloat = 300
                let qx = (pageW - side) / 2, qy: CGFloat = 190
                if let qr = QRCodeView.makeQR(from: value, side: side) {
                    UIColor(white: 0.9, alpha: 1).setStroke()
                    let border = UIBezierPath(rect: CGRect(x: qx - 12, y: qy - 12, width: side + 24, height: side + 24))
                    border.lineWidth = 1; border.stroke()
                    qr.draw(in: CGRect(x: qx, y: qy, width: side, height: side))
                }

                centered(value, font: .monospacedSystemFont(ofSize: 18, weight: .semibold),
                         color: .black, y: qy + side + 24)

                let hint = "Häng dieses Blatt außerhalb deines Bettbereichs auf – z. B. an der Badezimmertür. Morgens musst du aufstehen und hierher laufen, um den Wecker per Scan zu stoppen."
                let p = NSMutableParagraphStyle(); p.alignment = .center; p.lineSpacing = 4
                (hint as NSString).draw(in: CGRect(x: 70, y: pageH - 150, width: pageW - 140, height: 120),
                                        withAttributes: [.font: UIFont.systemFont(ofSize: 14),
                                                         .foregroundColor: UIColor.darkGray,
                                                         .paragraphStyle: p])
            }
            return url
        } catch {
            return nil
        }
    }
}

/// Identifiable wrapper so a generated PDF URL can drive `.sheet(item:)`.
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// Wraps UIActivityViewController so SwiftUI can present Print / Save-to-Files / share.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
