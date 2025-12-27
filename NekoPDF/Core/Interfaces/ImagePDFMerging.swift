import Foundation

protocol ImagePDFMerging: Sendable {
    func merge(imagesAt urls: [URL], to outputURL: URL, dpi: CGFloat) throws
}
