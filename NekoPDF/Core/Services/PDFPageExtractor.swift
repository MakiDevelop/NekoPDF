import Foundation
import PDFKit
import CoreGraphics

enum PDFExtractionError: Error, LocalizedError {
    case fileNotFound
    case invalidPDF
    case pageRenderFailed(pageIndex: Int)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound: return "無法讀取 PDF 檔案"
        case .invalidPDF: return "PDF 檔案損毀或格式錯誤"
        case .pageRenderFailed(let index): return "第 \(index + 1) 頁渲染失敗"
        }
    }
}

final class PDFPageExtractor: PDFPageExtracting, @unchecked Sendable {
    
    func extract(from pdfURL: URL, dpi: CGFloat) throws -> [PDFPageAsset] {
        guard FileManager.default.fileExists(atPath: pdfURL.path) else {
            throw PDFExtractionError.fileNotFound
        }
        
        guard let document = PDFDocument(url: pdfURL) else {
            throw PDFExtractionError.invalidPDF
        }
        
        // Handle encrypted PDFs? For now, if it's locked and we can't read, it might fail or return 0 pages.
        // Assuming unlocked or valid PDFs for this MVP phase.
        
        guard document.pageCount > 0 else {
            return []
        }
        
        var assets: [PDFPageAsset] = []
        let scale = dpi / 72.0
        
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else {
                throw PDFExtractionError.pageRenderFailed(pageIndex: i)
            }
            
            let box: PDFDisplayBox = .cropBox
            let pdfRect = page.bounds(for: box)
            
            let width = Int(ceil(pdfRect.width * scale))
            let height = Int(ceil(pdfRect.height * scale))
            
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else {
                throw PDFExtractionError.pageRenderFailed(pageIndex: i)
            }
            
            // Draw white background
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
            
            context.saveGState()
            
            // Setup Transform
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -pdfRect.origin.x, y: -pdfRect.origin.y)
            
            // Render
            page.draw(with: box, to: context)
            
            context.restoreGState()
            
            guard let image = context.makeImage() else {
                throw PDFExtractionError.pageRenderFailed(pageIndex: i)
            }
            
            let asset = PDFPageAsset(
                pageIndex: i,
                pageSize: pdfRect.size,
                renderScale: scale,
                image: image
            )
            assets.append(asset)
        }
        
        return assets
    }
}