import Foundation
import SwiftUI
import Combine

@MainActor
class PDFProcessViewModel: ObservableObject {
    
    // MARK: - State Properties
    @Published var selectedPDFURL: URL? {
        didSet {
            if let url = selectedPDFURL {
                loadPDF(url: url)
            }
        }
    }
    @Published var selectedOutputURL: URL?
    
    @Published var pages: [PDFPageAsset] = []
    @Published var selectedPageID: UUID?
    
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // Dependencies
    private let extractor: PDFPageExtracting
    private let exporter: ImageExporting
    
    init(
        extractor: PDFPageExtracting = PDFPageExtractor(),
        exporter: ImageExporting = ImageExporter()
    ) {
        self.extractor = extractor
        self.exporter = exporter
    }
    
    // MARK: - Actions
    
    func loadPDF(url: URL) {
        isProcessing = true
        errorMessage = nil
        successMessage = nil
        pages = [] // Clear previous
        
        Task {
            do {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                
                // 1. Extract (Heavy lifting)
                // We use a lower DPI for preview to save memory/time, or high DPI for quality?
                // Let's stick to 72 or 144. 72 is usually enough for screen preview.
                // NOTE: If we want high quality export later, we might need to re-extract OR extract high quality now.
                // For MVP, extract @2x (144) is good balance.
                let assets = try await Task.detached(priority: .userInitiated) { [extractor] in
                    return try extractor.extract(from: url, dpi: 144.0)
                }.value
                
                self.pages = assets
                if let first = assets.first {
                    self.selectedPageID = first.id
                }
                
            } catch {
                self.errorMessage = "載入失敗：\(error.localizedDescription)"
            }
            self.isProcessing = false
        }
    }
    
    func toggleSelection(for id: UUID) {
        if let index = pages.firstIndex(where: { $0.id == id }) {
            pages[index].isSelected.toggle()
        }
    }
    
    func selectAll(_ isSelected: Bool) {
        for i in 0..<pages.count {
            pages[i].isSelected = isSelected
        }
    }
    
    func exportSelectedPages() {
        guard let outputURL = selectedOutputURL else {
            errorMessage = "請先選擇輸出目錄"
            return
        }
        
        let selectedPages = pages.filter { $0.isSelected }
        guard !selectedPages.isEmpty else {
            errorMessage = "請至少選擇一頁進行輸出"
            return
        }
        
        // Ensure we have a PDF source name for folder creation, fallback to "UnknownPDF"
        let folderName = selectedPDFURL?.deletingPathExtension().lastPathComponent ?? "ExportedPages"
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let access = outputURL.startAccessingSecurityScopedResource()
                defer { if access { outputURL.stopAccessingSecurityScopedResource() } }
                
                try await Task.detached(priority: .userInitiated) { [exporter] in
                    try exporter.export(
                        pages: selectedPages,
                        to: outputURL,
                        format: .png,
                        folderName: folderName
                    )
                }.value
                
                self.successMessage = "成功輸出 \(selectedPages.count) 張圖片！"
            } catch {
                self.errorMessage = "輸出失敗：\(error.localizedDescription)"
            }
            self.isProcessing = false
        }
    }
}