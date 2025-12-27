import Foundation
import CoreGraphics
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
class ImageToPDFViewModel: ObservableObject {

    struct ImageListItem: Identifiable {
        let id: UUID
        let url: URL
        let displayName: String
        let thumbnail: CGImage
    }

    @Published var items: [ImageListItem] = []
    @Published var selectedImageIDs: Set<UUID> = []

    @Published var selectedOutputURL: URL?

    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var exportedURL: URL?

    private let assetLoader: ImageAssetLoading
    private let pdfMerger: ImagePDFMerging
    private var lastSelectedID: UUID?

    init(
        assetLoader: ImageAssetLoading = ImageAssetLoader(),
        pdfMerger: ImagePDFMerging = ImagePDFMerger()
    ) {
        self.assetLoader = assetLoader
        self.pdfMerger = pdfMerger
    }

    func addImages(from urls: [URL]) {
        let imageURLs = urls.filter(isSupportedImageURL(_:))

        guard !imageURLs.isEmpty else {
            errorMessage = "請加入圖片檔案"
            return
        }

        let existing = Set(items.map { $0.url })
        let newURLs = imageURLs.filter { !existing.contains($0) }

        guard !newURLs.isEmpty else {
            errorMessage = "圖片已在清單中"
            return
        }

        isProcessing = true
        errorMessage = nil
        successMessage = nil
        exportedURL = nil

        Task {
            do {
                let newItems = try await Task.detached(priority: .userInitiated) { [assetLoader] in
                    return try newURLs.map { url in
                        let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() } }

                        let thumbnail = try assetLoader.loadImage(from: url, maxPixelSize: 320)
                        return ImageListItem(
                            id: UUID(),
                            url: url,
                            displayName: url.lastPathComponent,
                            thumbnail: thumbnail
                        )
                    }
                }.value

                self.items.append(contentsOf: newItems)
        if self.selectedImageIDs.isEmpty, let first = newItems.first {
            self.selectedImageIDs = [first.id]
        }
                self.successMessage = "已加入 \(newItems.count) 張圖片"
            } catch {
                self.errorMessage = "載入圖片失敗：\(error.localizedDescription)"
            }

            self.isProcessing = false
        }
    }

    func removeAll() {
        items.removeAll()
        selectedImageIDs = []
        selectedOutputURL = nil
        exportedURL = nil
        lastSelectedID = nil
    }

    func removeItem(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }

        let wasSelected = selectedImageIDs.contains(items[index].id)
        items.remove(at: index)

        if wasSelected {
            selectedImageIDs.remove(id)
        }

        exportedURL = nil
    }

    func removeSelectedItem() {
        let ids = selectedImageIDs
        guard !ids.isEmpty else {
            return
        }

        items.removeAll { ids.contains($0.id) }
        selectedImageIDs = []
        exportedURL = nil
        lastSelectedID = nil
    }

    func selectSingleItem(id: UUID) {
        selectedImageIDs = [id]
        lastSelectedID = id
    }

    func toggleSelection(id: UUID) {
        if selectedImageIDs.contains(id) {
            selectedImageIDs.remove(id)
        } else {
            selectedImageIDs.insert(id)
        }
        lastSelectedID = id
    }

    func selectRange(to id: UUID) {
        guard let lastSelectedID = lastSelectedID,
              let startIndex = items.firstIndex(where: { $0.id == lastSelectedID }),
              let endIndex = items.firstIndex(where: { $0.id == id }) else {
            selectSingleItem(id: id)
            return
        }

        let range = startIndex <= endIndex ? startIndex...endIndex : endIndex...startIndex
        selectedImageIDs = Set(items[range].map { $0.id })
        self.lastSelectedID = id
    }

    func moveSelection(direction: MoveCommandDirection) {
        guard !items.isEmpty else {
            return
        }

        let currentID = lastSelectedID ?? selectedImageIDs.first ?? items.first?.id
        guard let currentID, let currentIndex = items.firstIndex(where: { $0.id == currentID }) else {
            return
        }

        let nextIndex: Int
        switch direction {
        case .up, .left:
            nextIndex = max(currentIndex - 1, 0)
        case .down, .right:
            nextIndex = min(currentIndex + 1, items.count - 1)
        @unknown default:
            return
        }

        let nextID = items[nextIndex].id
        selectedImageIDs = [nextID]
        lastSelectedID = nextID
    }

    func primarySelectedItem() -> ImageListItem? {
        guard let id = selectedImageIDs.first else {
            return nil
        }
        return items.first(where: { $0.id == id })
    }

    func mergeToPDF() {
        guard let outputDirectory = selectedOutputURL else {
            errorMessage = "請先選擇輸出目錄"
            return
        }

        guard !items.isEmpty else {
            errorMessage = "請先加入圖片"
            return
        }

        let outputURL = createOutputURL(in: outputDirectory)
        let imageURLs = items.map { $0.url }

        isProcessing = true
        errorMessage = nil
        successMessage = nil
        exportedURL = nil

        Task {
            let outputAccess = outputDirectory.startAccessingSecurityScopedResource()
            defer { if outputAccess { outputDirectory.stopAccessingSecurityScopedResource() } }

            do {
                try await Task.detached(priority: .userInitiated) { [pdfMerger] in
                    let accessFlags = imageURLs.map { $0.startAccessingSecurityScopedResource() }
                    defer {
                        for (index, access) in accessFlags.enumerated() where access {
                            imageURLs[index].stopAccessingSecurityScopedResource()
                        }
                    }

                    try pdfMerger.merge(imagesAt: imageURLs, to: outputURL, dpi: 144.0)
                }.value

                self.exportedURL = outputURL
                self.successMessage = "已合併 \(items.count) 張圖片"
            } catch {
                self.errorMessage = "合併失敗：\(error.localizedDescription)"
            }

            self.isProcessing = false
        }
    }

    private func createOutputURL(in directory: URL) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let name = "Merged_\(formatter.string(from: Date())).pdf"
        return directory.appendingPathComponent(name)
    }

    private func isSupportedImageURL(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else {
            return false
        }
        return type.conforms(to: .jpeg) || type.conforms(to: .png)
    }
}
