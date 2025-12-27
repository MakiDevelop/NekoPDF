import CoreGraphics
import Foundation

struct PDFPageAsset: Identifiable, Sendable {
    let id: UUID
    let pageIndex: Int
    let pageSize: CGSize
    let renderScale: CGFloat
    let image: CGImage
    var isSelected: Bool
    
    init(
        id: UUID = UUID(),
        pageIndex: Int,
        pageSize: CGSize,
        renderScale: CGFloat,
        image: CGImage,
        isSelected: Bool = true
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.pageSize = pageSize
        self.renderScale = renderScale
        self.image = image
        self.isSelected = isSelected
    }
}
