import SwiftUI

struct PageListView: View {
    @ObservedObject var viewModel: PDFProcessViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.pages.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("拖曳 PDF 至此\n或從上方開啟")
                        .multilineTextAlignment(.center)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
            } else {
                List(selection: $viewModel.selectedPageID) {
                    ForEach(viewModel.pages) {
                        page in
                        HStack {
                            // Selection Toggle
                            Toggle("Select", isOn: Binding(
                                get: { page.isSelected },
                                set: { _ in viewModel.toggleSelection(for: page.id) }
                            ))
                            .labelsHidden()
                            
                            // Thumbnail
                            Image(decorative: page.image, scale: 1.0)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 50)
                                .cornerRadius(4)
                                .shadow(radius: 1)
                            
                            // Info
                            Text("Page \(page.pageIndex + 1)")
                                .font(.system(.subheadline, design: .monospaced))
                        }
                        .padding(.vertical, 4)
                        .tag(page.id)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .navigationTitle("頁面清單")
    }
}
