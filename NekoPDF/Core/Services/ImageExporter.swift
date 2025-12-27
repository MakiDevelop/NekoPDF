import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum ImageExportError: Error, LocalizedError {
    case directoryCreationError
    case imageWriteError(pageIndex: Int)
    
    var errorDescription: String? {
        switch self {
        case .directoryCreationError: return "無法建立輸出目錄"
        case .imageWriteError(let index): return "第 \(index + 1) 頁寫入失敗"
        }
    }
}

final class ImageExporter: ImageExporting, @unchecked Sendable {
    
    func export(
        pages: [PDFPageAsset],
        to directory: URL,
        format: ImageFormat,
        folderName: String
    ) throws {
        let outputFolder = directory.appendingPathComponent(folderName)
        
        do {
            try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
        } catch {
            throw ImageExportError.directoryCreationError
        }
        
        for asset in pages {
            // Page index is 0-based, file name is 1-based (page_001)
            let filename = String(format: "page_%03d.%@", asset.pageIndex + 1, format.fileExtension)
            let fileURL = outputFolder.appendingPathComponent(filename)
            
            let typeIdentifier: String
            switch format {
            case .png:
                typeIdentifier = UTType.png.identifier
            }
            
            guard let destination = CGImageDestinationCreateWithURL(
                fileURL as CFURL,
                typeIdentifier as CFString,
                1,
                nil
            ) else {
                throw ImageExportError.imageWriteError(pageIndex: asset.pageIndex)
            }
            
            // Optional: Set DPI properties
            // 72 DPI is standard, but if we rendered at higher scale, we might want to set metadata.
            // For now, simple export.
            
            CGImageDestinationAddImage(destination, asset.image, nil)
            
            if !CGImageDestinationFinalize(destination) {
                throw ImageExportError.imageWriteError(pageIndex: asset.pageIndex)
            }
        }
    }
}
