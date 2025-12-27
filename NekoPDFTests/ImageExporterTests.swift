import XCTest
import CoreGraphics
@testable import NekoPDF

final class ImageExporterTests: XCTestCase {
    
    var exporter: ImageExporting!
    let fileManager = FileManager.default
    var tempDir: URL!
    
    override func setUp() {
        super.setUp()
        exporter = ImageExporter()
        tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? fileManager.removeItem(at: tempDir)
        exporter = nil
        super.tearDown()
    }
    
    func testExport_PNG_ShouldCreateFiles() throws {
        // Given
        let assets = createMockAssets(count: 2)
        let folderName = "TestPDF"
        
        // When
        try exporter.export(pages: assets, to: tempDir, format: .png, folderName: folderName)
        
        // Then
        let outputFolder = tempDir.appendingPathComponent(folderName)
        var isDir: ObjCBool = false
        XCTAssertTrue(fileManager.fileExists(atPath: outputFolder.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
        
        let file1 = outputFolder.appendingPathComponent("page_001.png")
        let file2 = outputFolder.appendingPathComponent("page_002.png")
        
        XCTAssertTrue(fileManager.fileExists(atPath: file1.path))
        XCTAssertTrue(fileManager.fileExists(atPath: file2.path))
    }
    
    private func createMockAssets(count: Int) -> [PDFPageAsset] {
        var assets: [PDFPageAsset] = []
        for i in 0..<count {
            let width = 10
            let height = 10
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            )!
            // Fill red
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
            
            let image = context.makeImage()!
            
            assets.append(PDFPageAsset(
                pageIndex: i,
                pageSize: CGSize(width: 10, height: 10),
                renderScale: 1.0,
                image: image
            ))
        }
        return assets
    }
}
