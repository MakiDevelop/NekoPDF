import Foundation
import Combine
import SwiftUI

@MainActor
class PDFOptimizeViewModel: ObservableObject {
    @Published var selectedPDFURL: URL?
    @Published var selectedOutputURL: URL?
    @Published var compressionMode: PDFCompressionMode = .lossless
    @Published var compressionQuality: PDFCompressionQuality = .ebook

    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let optimizer: PDFOptimizing

    init(optimizer: PDFOptimizing = PDFOptimizer()) {
        self.optimizer = optimizer
    }

    func optimizePDF() {
        guard let inputURL = selectedPDFURL else {
            errorMessage = "請先選擇 PDF"
            return
        }

        guard let outputDirectory = selectedOutputURL else {
            errorMessage = "請先選擇輸出目錄"
            return
        }

        let outputURL = makeOutputURL(inputURL: inputURL, outputDirectory: outputDirectory)
        let mode = compressionMode
        let quality = compressionQuality

        isProcessing = true
        errorMessage = nil
        successMessage = nil

        Task {
            let inputAccess = inputURL.startAccessingSecurityScopedResource()
            let outputAccess = outputDirectory.startAccessingSecurityScopedResource()
            defer {
                if inputAccess { inputURL.stopAccessingSecurityScopedResource() }
                if outputAccess { outputDirectory.stopAccessingSecurityScopedResource() }
            }

            do {
                try await Task.detached(priority: .userInitiated) { [optimizer] in
                    try optimizer.optimize(
                        pdfURL: inputURL,
                        to: outputURL,
                        mode: mode,
                        quality: quality
                    )
                }.value

                self.successMessage = "壓縮完成：\(outputURL.lastPathComponent)"
            } catch {
                self.errorMessage = "壓縮失敗：\(error.localizedDescription)"
            }

            self.isProcessing = false
        }
    }

    private func makeOutputURL(inputURL: URL, outputDirectory: URL) -> URL {
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let fileName = "\(baseName)_optimized.pdf"
        return outputDirectory.appendingPathComponent(fileName)
    }
}
