import Foundation
import CoreGraphics

enum ImagePDFMergeError: Error, LocalizedError {
    case noImages
    case invalidDPI
    case outputDirectoryNotFound
    case outputFileExists
    case pdfContextCreationFailed
    case imageLoadFailed(name: String)

    var errorDescription: String? {
        switch self {
        case .noImages:
            return "請先加入至少一張圖片"
        case .invalidDPI:
            return "DPI 設定不正確"
        case .outputDirectoryNotFound:
            return "輸出目錄不存在"
        case .outputFileExists:
            return "輸出檔案已存在"
        case .pdfContextCreationFailed:
            return "無法建立 PDF 檔案"
        case .imageLoadFailed(let name):
            return "圖片載入失敗：\(name)"
        }
    }
}

final class ImagePDFMerger: ImagePDFMerging, @unchecked Sendable {
    private let loader: ImageAssetLoading

    init(loader: ImageAssetLoading = ImageAssetLoader()) {
        self.loader = loader
    }

    func merge(imagesAt urls: [URL], to outputURL: URL, dpi: CGFloat) throws {
        guard !urls.isEmpty else {
            throw ImagePDFMergeError.noImages
        }

        guard dpi > 0 else {
            throw ImagePDFMergeError.invalidDPI
        }

        let outputDirectory = outputURL.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: outputDirectory.path) else {
            throw ImagePDFMergeError.outputDirectoryNotFound
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            throw ImagePDFMergeError.outputFileExists
        }

        let scale = dpi / 72.0

        var firstImage: CGImage
        do {
            firstImage = try loader.loadImage(from: urls[0], maxPixelSize: nil)
        } catch {
            throw ImagePDFMergeError.imageLoadFailed(name: urls[0].lastPathComponent)
        }

        let firstPageSize = CGSize(
            width: CGFloat(firstImage.width) / scale,
            height: CGFloat(firstImage.height) / scale
        )
        var mediaBox = CGRect(origin: .zero, size: firstPageSize)

        guard let context = CGContext(outputURL as CFURL, mediaBox: &mediaBox, nil) else {
            throw ImagePDFMergeError.pdfContextCreationFailed
        }

        do {
            draw(image: firstImage, in: context, pageSize: firstPageSize)

            if urls.count > 1 {
                for url in urls.dropFirst() {
                    let image: CGImage
                    do {
                        image = try loader.loadImage(from: url, maxPixelSize: nil)
                    } catch {
                        throw ImagePDFMergeError.imageLoadFailed(name: url.lastPathComponent)
                    }

                    let pageSize = CGSize(
                        width: CGFloat(image.width) / scale,
                        height: CGFloat(image.height) / scale
                    )

                    draw(image: image, in: context, pageSize: pageSize)
                }
            }

            context.closePDF()
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
    }

    private func draw(image: CGImage, in context: CGContext, pageSize: CGSize) {
        var pageBox = CGRect(origin: .zero, size: pageSize)
        context.beginPDFPage([kCGPDFContextMediaBox as String: pageBox] as CFDictionary)

        context.draw(image, in: CGRect(origin: .zero, size: pageSize))

        context.endPDFPage()
    }
}
