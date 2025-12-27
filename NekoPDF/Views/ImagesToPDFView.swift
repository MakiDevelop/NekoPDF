import SwiftUI
import UniformTypeIdentifiers

struct ImagesToPDFView: View {
    @StateObject private var viewModel = ImageToPDFViewModel()
    @State private var isImportingImages = false
    @State private var isImportingFolder = false
    @State private var isTargeted = false
    @State private var isSharing = false

    var body: some View {
        NavigationSplitView {
            ImageListView(viewModel: viewModel)
                .frame(minWidth: 250)
        } detail: {
            ImageDetailView(viewModel: viewModel)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { isImportingImages = true }) {
                    Label("加入圖片", systemImage: "photo.on.rectangle.angled")
                }
                .help("加入多張圖片")

                Button(action: { isImportingFolder = true }) {
                    Label("輸出目錄", systemImage: "folder")
                }
                .help(viewModel.selectedOutputURL?.path ?? "選擇輸出目錄")

                Button(action: {
                    viewModel.mergeToPDF()
                }) {
                    HStack {
                        Image(systemName: "doc.badge.arrow.up")
                        Text("匯出 PDF")
                    }
                }
                .disabled(viewModel.items.isEmpty || viewModel.isProcessing)
                .keyboardShortcut("m", modifiers: .command)
            }

            ToolbarItemGroup(placement: .automatic) {
                Button("刪除") {
                    viewModel.removeSelectedItem()
                }
                .disabled(viewModel.selectedImageIDs.isEmpty)

                Button("清除") {
                    viewModel.removeAll()
                }
                .disabled(viewModel.items.isEmpty)
            }
        }
        .overlay(alignment: .bottom) {
            if let error = viewModel.errorMessage {
                Text(error)
                    .padding()
                    .background(.red.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture { viewModel.errorMessage = nil }
            } else if let success = viewModel.successMessage {
                Text(success)
                    .padding()
                    .background(.green.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture { viewModel.successMessage = nil }
            }
        }
        .background(
            ShareSheetPresenter(
                items: viewModel.exportedURL.map { [$0] } ?? [],
                isPresented: $isSharing
            )
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            var droppedURLs = Array<URL?>(repeating: nil, count: providers.count)
            let group = DispatchGroup()

            for (index, provider) in providers.enumerated() where provider.canLoadObject(ofClass: URL.self) {
                group.enter()
                let _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    DispatchQueue.main.async {
                        droppedURLs[index] = url
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                let urls = droppedURLs.compactMap { $0 }
                if !urls.isEmpty { viewModel.addImages(from: urls) }
            }

            return true
        }
        .onChange(of: viewModel.exportedURL) { _, newValue in
            if newValue != nil {
                isSharing = true
            }
        }
        .fileImporter(
            isPresented: $isImportingImages,
            allowedContentTypes: [.jpeg, .png],
            allowsMultipleSelection: true
        ) { result in
            if let urls = try? result.get() {
                viewModel.addImages(from: urls)
            }
        }
        .fileImporter(
            isPresented: $isImportingFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if let url = try? result.get().first {
                viewModel.selectedOutputURL = url
            }
        }
    }
}
