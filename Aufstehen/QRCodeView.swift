import SwiftUI
import CoreImage.CIFilterBuiltins

/// Renders a crisp QR code for a given string using CoreImage.
struct QRCodeView: View {
    let value: String
    var size: CGFloat = 180

    var body: some View {
        Group {
            if let image = Self.makeQR(from: value, side: size) {
                Image(uiImage: image)
                    .interpolation(.none)          // keep the modules sharp
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(12)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.oathSecondary.opacity(0.3))
                    .frame(width: size, height: size)
                    .overlay(Text(S.t("QR error", "QR-Fehler")).foregroundColor(.oathSecondary))
            }
        }
    }

    static func makeQR(from string: String, side: CGFloat) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }

        // Scale the tiny generated image up to the requested size.
        let scale = side / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
