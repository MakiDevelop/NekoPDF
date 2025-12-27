import SwiftUI
import UniformTypeIdentifiers

struct PDFToImagesView: View {
    @StateObject private var viewModel = PDFProcessViewModel()
    @State private var isImportingPDF = false
    @State private var isImportingFolder = false
    @State private var isTargeted = false

    var body: some View {
        NavigationSplitView {
            PageListView(viewModel: viewModel)
                .frame(minWidth: 250)
        } detail: {
            PageDetailView(viewModel: viewModel)
        }
        .toolbar {
            // Main Actions
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { isImportingPDF = true }) {
                    Label("開啟 PDF", systemImage: "doc.badge.plus")
                }
                .help("開啟 PDF 檔案")

                Button(action: { isImportingFolder = true }) {
                    Label("輸出目錄", systemImage: "folder")
                }
                .help(viewModel.selectedOutputURL?.path ?? "選擇輸出目錄")

                Button(action: {
                    if viewModel.selectedOutputURL == nil {
                        isImportingFolder = true
                    } else {
                        viewModel.exportSelectedPages()
                    }
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text(viewModel.selectedOutputURL == nil ? "選擇目錄並匯出" : "匯出")
                    }
                }
                .disabled(viewModel.pages.isEmpty || viewModel.isProcessing)
                .keyboardShortcut("e", modifiers: .command)
            }

            // Selection Tools (Sidebar)
            ToolbarItemGroup(placement: .automatic) {
                Button(action: { viewModel.selectAll(true) }) {
                    Label("全選", systemImage: "checkmark.circle")
                }
                .disabled(viewModel.pages.isEmpty)

                Button(action: { viewModel.selectAll(false) }) {
                    Label("取消全選", systemImage: "circle")
                }
                .disabled(viewModel.pages.isEmpty)
            }
        }
        .overlay(alignment: .bottom) {
            // Toast / Status Overlay
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
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first(where: { $0.canLoadObject(ofClass: URL.self) }) else {
                return false
            }

            let _ = provider.loadObject(ofClass: URL.self) { url, error in
                guard let url = url else { return }

                DispatchQueue.main.async {
                    if url.pathExtension.lowercased() == "pdf" {
                        viewModel.selectedPDFURL = url
                    } else {
                        var isDir: ObjCBool = false
                        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                            viewModel.selectedOutputURL = url
                        }
                    }
                }
            }
            return true
        }
        .fileImporter(
            isPresented: $isImportingPDF,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            if let url = try? result.get().first {
                viewModel.selectedPDFURL = url
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
