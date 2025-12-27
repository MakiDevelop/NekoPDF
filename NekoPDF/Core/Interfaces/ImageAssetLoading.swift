import Foundation
import CoreGraphics

protocol ImageAssetLoading: Sendable {
    func loadImage(from url: URL, maxPixelSize: CGFloat?) throws -> CGImage
}
