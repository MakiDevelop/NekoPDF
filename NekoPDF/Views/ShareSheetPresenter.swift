import SwiftUI
import AppKit

struct ShareSheetPresenter: NSViewRepresentable {
    let items: [Any]
    @Binding var isPresented: Bool

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard isPresented, !items.isEmpty else {
            return
        }

        DispatchQueue.main.async {
            let picker = NSSharingServicePicker(items: items)
            picker.show(relativeTo: nsView.bounds, of: nsView, preferredEdge: .minY)
            isPresented = false
        }
    }
}
