import Foundation
import CoreGraphics
import ImageIO

enum ImageAssetLoadingError: Error, LocalizedError {
    case fileNotFound
    case invalidImage
    case unsupportedImageType

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "無法讀取圖片檔案"
        case .invalidImage:
            return "圖片檔案格式不正確"
        case .unsupportedImageType:
            return "不支援的圖片格式"
        }
    }
}

final class ImageAssetLoader: ImageAssetLoading, @unchecked Sendable {

    func loadImage(from url: URL, maxPixelSize: CGFloat?) throws -> CGImage {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ImageAssetLoadingError.fileNotFound
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImageAssetLoadingError.invalidImage
        }

        guard CGImageSourceGetType(source) != nil else {
            throw ImageAssetLoadingError.unsupportedImageType
        }

        if let maxPixelSize = maxPixelSize {
            return try createThumbnail(from: source, maxPixelSize: maxPixelSize)
        }

        if let pixelSize = loadPixelSize(from: source), pixelSize.width > 0, pixelSize.height > 0 {
            let maxSize = max(pixelSize.width, pixelSize.height)
            if let image = try? createThumbnail(from: source, maxPixelSize: maxSize) {
                return image
            }
        }

        if let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            return image
        }

        throw ImageAssetLoadingError.invalidImage
    }

    private func createThumbnail(from source: CGImageSource, maxPixelSize: CGFloat) throws -> CGImage {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        if let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return image
        }

        throw ImageAssetLoadingError.invalidImage
    }

    private func loadPixelSize(from source: CGImageSource) -> CGSize? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }

        let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0
        let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0

        guard width > 0, height > 0 else {
            return nil
        }

        return CGSize(width: width, height: height)
    }
}
