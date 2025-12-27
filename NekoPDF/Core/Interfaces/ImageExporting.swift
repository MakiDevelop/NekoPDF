import Foundation

protocol ImageExporting: Sendable {
    func export(
        pages: [PDFPageAsset],
        to directory: URL,
        format: ImageFormat,
        folderName: String // Added folderName to satisfy requirement "{outputDirectory}/{PDFFileName}/"
    ) throws
}
