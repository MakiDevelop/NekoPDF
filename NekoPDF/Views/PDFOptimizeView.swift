import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PDFOptimizeView: View {
    @StateObject private var viewModel = PDFOptimizeViewModel()
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "doc.zipper.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.linearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .symbolEffect(.bounce, value: viewModel.isProcessing)

                Text("PDF 壓縮")
                    .font(.title.bold())

                Text("優化 PDF 文件大小，支援多種壓縮模式")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)

            VStack(alignment: .leading, spacing: 16) {
                Group {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("來源 PDF", systemImage: "doc.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)

                        HStack {
                            Text(viewModel.selectedPDFURL?.lastPathComponent ?? "尚未選擇")
                                .font(.callout)
                                .foregroundColor(viewModel.selectedPDFURL == nil ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            if viewModel.selectedPDFURL != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.leading, 24)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Label("輸出目錄", systemImage: "folder.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)

                        HStack {
                            Text(viewModel.selectedOutputURL?.path ?? "尚未選擇")
                                .font(.callout)
                                .foregroundColor(viewModel.selectedOutputURL == nil ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            if viewModel.selectedOutputURL != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.leading, 24)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Label("壓縮模式", systemImage: "slider.horizontal.3")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)

                        Picker("", selection: $viewModel.compressionMode) {
                            ForEach(PDFCompressionMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .padding(.leading, 24)
                    }

                    if viewModel.compressionMode == .ghostscript {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Label("壓縮品質", systemImage: "dial.medium")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)

                            Picker("", selection: $viewModel.compressionQuality) {
                                ForEach(PDFCompressionQuality.allCases) { quality in
                                    Text(quality.displayName).tag(quality)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .padding(.leading, 24)

                            HStack(spacing: 4) {
                                Image(systemName: "info.circle.fill")
                                    .font(.caption)
                                Text("外部壓縮需安裝 Ghostscript（gs）")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                            .padding(.leading, 24)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                            Text("不取出圖片、不改品質，重新封裝 PDF 結構")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        .padding(.leading, 24)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 600)
            .background(.regularMaterial)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 10, y: 4)

            HStack(spacing: 16) {
                Button {
                    selectPDFFile()
                } label: {
                    Label("選擇 PDF", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.blue)

                Button {
                    selectOutputFolder()
                } label: {
                    Label("輸出目錄", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.blue)
            }
            .frame(maxWidth: 600)
            .padding(.horizontal, 20)

            Button {
                viewModel.optimizePDF()
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isProcessing {
                        ProgressView()
                            .controlSize(.small)
                            .progressViewStyle(.circular)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                    }
                    Text(viewModel.isProcessing ? "壓縮中..." : "開始壓縮")
                        .font(.headline)
                }
                .frame(maxWidth: 600)
                .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isProcessing || viewModel.selectedPDFURL == nil || viewModel.selectedOutputURL == nil)
            .keyboardShortcut(.defaultAction)

            if isTargeted {
                Text("拖放 PDF 文件到這裡")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            if let error = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundColor(.red)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("壓縮失敗")
                                .font(.headline)
                            Text("請檢查錯誤訊息或嘗試其他壓縮模式")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button {
                            copyToPasteboard(error)
                        } label: {
                            Label("複製", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            withAnimation {
                                viewModel.errorMessage = nil
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }

                    ScrollView {
                        Text(error)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                    .padding(12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(20)
                .frame(maxWidth: 700)
                .background(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                )
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                .padding(24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let success = viewModel.successMessage {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)

                    Text(success)
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Button {
                        withAnimation {
                            viewModel.successMessage = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .frame(maxWidth: 600)
                .background(
                    LinearGradient(
                        colors: [.green, .green.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .green.opacity(0.3), radius: 20, y: 10)
                .padding(24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onTapGesture {
                    withAnimation {
                        viewModel.successMessage = nil
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.errorMessage)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.successMessage)
        .background(
            isTargeted ?
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [10, 5]))
                    .foregroundStyle(.blue.opacity(0.5))
                    .padding(8)
                : nil
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first(where: { $0.canLoadObject(ofClass: URL.self) }) else {
                return false
            }

            let _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }

                DispatchQueue.main.async {
                    if url.pathExtension.lowercased() == "pdf" {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectedPDFURL = url
                        }
                    } else {
                        var isDir: ObjCBool = false
                        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.selectedOutputURL = url
                            }
                        }
                    }
                }
            }
            return true
        }
    }

    private func selectPDFFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.pdf]
        panel.message = "請選擇要壓縮的 PDF 文件"
        panel.prompt = "選擇"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.selectedPDFURL = url
                }
            }
        }
    }

    private func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "請選擇壓縮後的 PDF 輸出目錄"
        panel.prompt = "選擇"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.selectedOutputURL = url
                }
            }
        }
    }

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
