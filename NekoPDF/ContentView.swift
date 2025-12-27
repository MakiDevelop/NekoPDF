import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PDFToImagesView()
                .tabItem {
                    Label("PDF → PNG", systemImage: "doc.richtext")
                }

            ImagesToPDFView()
                .tabItem {
                    Label("Images → PDF", systemImage: "photo.stack")
                }

            PDFOptimizeView()
                .tabItem {
                    Label("PDF 壓縮", systemImage: "doc.zipper")
                }
        }
    }
}
