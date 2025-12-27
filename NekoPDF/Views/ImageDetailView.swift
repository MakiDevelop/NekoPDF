import SwiftUI

struct ImageDetailView: View {
    @ObservedObject var viewModel: ImageToPDFViewModel

    var body: some View {
        GeometryReader { geometry in
            if let item = viewModel.primarySelectedItem() {
                ScrollView([.horizontal, .vertical]) {
                    ZStack {
                        Color(nsColor: .windowBackgroundColor)
                            .frame(
                                minWidth: geometry.size.width,
                                minHeight: geometry.size.height
                            )

                        Image(decorative: item.thumbnail, scale: 1.0)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 800)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                            .padding(40)
                    }
                }
            } else {
                VStack(spacing: 20) {
                    if viewModel.isProcessing {
                        ProgressView("正在處理...")
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 80))
                            .foregroundStyle(.tertiary)
                        Text("選擇圖片以檢視")
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
