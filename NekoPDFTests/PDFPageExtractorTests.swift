import XCTest
import PDFKit
@testable import NekoPDF

final class PDFPageExtractorTests: XCTestCase {
    
    var extractor: PDFPageExtracting!
    
    override func setUp() {
        super.setUp()
        extractor = PDFPageExtractor()
    }
    
    override func tearDown() {
        extractor = nil
        super.tearDown()
    }
    
    func testExtract_WithValidPDF_ShouldReturnAssets() throws {
        // Given
        let expectedPageCount = 2
        let pdfURL = try createMockPDF(pageCount: expectedPageCount)
        let dpi: CGFloat = 72.0 // Standard screen DPI, scale 1.0
        
        // When
        let assets = try extractor.extract(from: pdfURL, dpi: dpi)
        
        // Then
        XCTAssertEqual(assets.count, expectedPageCount)
        
        for (index, asset) in assets.enumerated() {
            XCTAssertEqual(asset.pageIndex, index)
            // Default PDFPage is 612x792 (Letter) usually, but let's just check it's not empty
            XCTAssertTrue(asset.pageSize.width > 0)
            XCTAssertTrue(asset.pageSize.height > 0)
            XCTAssertNotNil(asset.image)
        }
        
        // Cleanup
        try? FileManager.default.removeItem(at: pdfURL)
    }
    
    func testExtract_WithInvalidURL_ShouldThrow() {
        // Given
        let invalidURL = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent.pdf")
        let dpi: CGFloat = 72.0
        
        // When/Then
        XCTAssertThrowsError(try extractor.extract(from: invalidURL, dpi: dpi))
    }
    
    // MARK: - Helper
    
    private func createMockPDF(pageCount: Int) throws -> URL {
        let pdfDoc = PDFDocument()
        for i in 0..<pageCount {
            // Create a simple page
            let page = PDFPage()
            // Just ensure it has some bounds so it can be rendered
            page.setBounds(CGRect(x: 0, y: 0, width: 100, height: 100), for: .mediaBox)
            pdfDoc.insert(page, at: i)
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        pdfDoc.write(to: tempURL)
        return tempURL
    }
}
