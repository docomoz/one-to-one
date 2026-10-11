import SwiftUI
import VisionKit

/// Камера внутри приложения для QR сверки кода. Отдаёт первый найденный QR и больше ничего не ищет.
/// На симуляторе и iPhone без нужной камеры недоступна: тогда кнопки сканирования нет, сверяют цифры.
struct QRScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    @MainActor static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
                                                qualityLevel: .balanced, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        return scanner
    }

    // Сканировать можно только после показа экрана, поэтому запускаем здесь, а не при создании.
    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        guard !scanner.isScanning else { return }
        try? scanner.startScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScan: (String) -> Void
        private var isDone = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ scanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard !isDone else { return }
            for case .barcode(let barcode) in addedItems {
                guard let text = barcode.payloadStringValue else { continue }
                isDone = true
                scanner.stopScanning()
                onScan(text)
                return
            }
        }
    }
}

/// Окно с камерой: «Отмена» закрывает без результата.
struct QRScannerSheet: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            QRScannerView { text in
                dismiss()
                onScan(text)
            }
            .ignoresSafeArea()
            .navigationTitle("QR-код партнёра")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }
}
