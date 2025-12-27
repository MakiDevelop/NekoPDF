import Foundation

protocol PDFPageExtracting: Sendable {
    func extract(
        from pdfURL: URL,
        dpi: CGFloat
    ) throws -> [PDFPageAsset]
}
