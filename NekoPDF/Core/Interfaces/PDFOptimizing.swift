import Foundation

protocol PDFOptimizing: Sendable {
    func optimize(
        pdfURL: URL,
        to outputURL: URL,
        mode: PDFCompressionMode,
        quality: PDFCompressionQuality
    ) throws
}
