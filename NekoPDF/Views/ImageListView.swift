import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ImageListView: View {
    @ObservedObject var viewModel: ImageToPDFViewModel
    @State private var draggingID: UUID?

    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.items.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("拖曳 JPG/PNG 至此\n可一次加入多張")
                        .multilineTextAlignment(.center)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.items) { item in
                            VStack(spacing: 8) {
                                Image(decorative: item.thumbnail, scale: 1.0)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 120)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(nsColor: .windowBackgroundColor))
                                    .cornerRadius(8)
                                    .shadow(radius: 2)

                                Text(item.displayName)
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(viewModel.selectedImageIDs.contains(item.id) ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                let modifiers = NSEvent.modifierFlags
                                if modifiers.contains(.shift) {
                                    viewModel.selectRange(to: item.id)
                                } else if modifiers.contains(.command) {
                                    viewModel.toggleSelection(id: item.id)
                                } else {
                                    viewModel.selectSingleItem(id: item.id)
                                }
                            }
                            .onDrag {
                                draggingID = item.id
                                return NSItemProvider(object: item.id.uuidString as NSString)
                            }
                            .contextMenu {
                                Button("刪除", role: .destructive) {
                                    viewModel.removeItem(id: item.id)
                                }
                            }
                            .onDrop(of: [.text], delegate: DragRelocateDelegate(
                                item: item,
                                items: $viewModel.items,
                                draggingID: $draggingID
                            ))
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("圖片清單")
        .focusable(true)
        .onDeleteCommand {
            viewModel.removeSelectedItem()
        }
        .onMoveCommand { direction in
            viewModel.moveSelection(direction: direction)
        }
    }
}

private struct DragRelocateDelegate: DropDelegate {
    let item: ImageToPDFViewModel.ImageListItem
    @Binding var items: [ImageToPDFViewModel.ImageListItem]
    @Binding var draggingID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggingID = draggingID,
              draggingID != item.id,
              let fromIndex = items.firstIndex(where: { $0.id == draggingID }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        if items[toIndex].id != draggingID {
            items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}
