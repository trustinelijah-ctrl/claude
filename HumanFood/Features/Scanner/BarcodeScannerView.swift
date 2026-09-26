import AVFoundation
import SwiftUI
import UIKit
import VisionKit

/// Holds a reference to the live scanner so SwiftUI can ask it for a photo.
@MainActor
final class ScannerController {
    fileprivate weak var scanner: DataScannerViewController?

    static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func capturePhoto() async throws -> UIImage {
        guard let scanner else { throw CocoaError(.featureUnsupported) }
        return try await scanner.capturePhoto()
    }

    func setTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
}

/// VisionKit's DataScanner — Apple's fast, on-device barcode reader.
struct BarcodeScannerView: UIViewControllerRepresentable {
    var isActive: Bool
    let controller: ScannerController
    /// Called with newly recognised barcode payloads.
    var onBarcodes: ([String]) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128, .itf14])],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: false
        )
        scanner.delegate = context.coordinator
        controller.scanner = scanner
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onBarcodes = onBarcodes
        if isActive, !scanner.isScanning {
            try? scanner.startScanning()
        } else if !isActive, scanner.isScanning {
            scanner.stopScanning()
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onBarcodes: onBarcodes) }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onBarcodes: ([String]) -> Void

        init(onBarcodes: @escaping ([String]) -> Void) {
            self.onBarcodes = onBarcodes
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            let codes = addedItems.compactMap { item -> String? in
                if case .barcode(let barcode) = item { return barcode.payloadStringValue }
                return nil
            }
            if !codes.isEmpty { onBarcodes(codes) }
        }
    }
}
