import SwiftUI

struct PageDetailView: View {
    @ObservedObject var viewModel: PDFProcessViewModel
    
    var body: some View {
        GeometryReader { geometry in
            if let selectedID = viewModel.selectedPageID,
               let page = viewModel.pages.first(where: { $0.id == selectedID }) {
                
                VStack(spacing: 0) {
                    ScrollView([.horizontal, .vertical]) {
                        ZStack {
                            Color(nsColor: .windowBackgroundColor) // Background for scroll area
                                .frame(
                                    minWidth: geometry.size.width,
                                    minHeight: geometry.size.height
                                )
                            
                            Image(decorative: page.image, scale: 1.0)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 800) // Max width constraint
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                                .padding(40)
                        }
                    }
                }
                .id(selectedID) // Force redraw scrollview on page change
                
            } else {
                VStack(spacing: 20) {
                    if viewModel.isProcessing {
                        ProgressView("正在處理...")
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: 80))
                            .foregroundStyle(.tertiary)
                        Text("選擇頁面以檢視細節")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
    }
}
