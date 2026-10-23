import CoreImage.CIFilterBuiltins
import SwiftUI

/// QR-код из строки (`VerifyQR`). Чёрный на белом при любой теме: так его уверенно читает камера.
struct QRCodeView: View {
    let text: String

    var body: some View {
        if let image = Self.image(for: text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityLabel("QR-код для сверки")
        }
    }

    private static func image(for text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let cgImage = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    QRCodeView(text: VerifyQR.payload(requestID: "0123456789abcdef0123", code: "042917"))
        .frame(width: 200)
}
