import UIKit
import CoreImage.CIFilterBuiltins

/// Generates a high-contrast QR code suitable for embedding in the
/// MonthlyWrappedShareCard. Renders at the requested point-size at 3x
/// scale so it stays crisp inside the 1080×1920 ImageRenderer output.
enum QRCodeGenerator {

    /// Returns a QR code as a UIImage. Falls back to a 1×1 transparent
    /// pixel if Core Image fails (never returns nil — caller doesn't
    /// branch).
    static func image(for string: String, size: CGFloat = 120) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H"

        guard let output = filter.outputImage else { return Self.emptyPixel }

        // Scale up — CIQRCodeGenerator emits a tiny image; we want
        // pixel-perfect bars at the target point size.
        let scale = (size * 3) / output.extent.width  // 3x for retina
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return Self.emptyPixel
        }
        return UIImage(cgImage: cgImage, scale: 3, orientation: .up)
    }

    private static let emptyPixel: UIImage = {
        let r = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return r.image { _ in }
    }()
}
