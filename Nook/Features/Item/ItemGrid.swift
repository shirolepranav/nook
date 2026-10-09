import SwiftUI
import SwiftData
import NookKit
import NookUI

/// Items as photo cards (03 §8.3), or rows at accessibility sizes (03 §4). Tapping opens
/// the item with a zoom (I-01); while selecting, tapping toggles it (I-08). The context menu
/// also opens with a secondary click (D29).
struct ItemGrid: View {
    let items: [Item]
    var selection: Binding<Set<UUID>?> = .constant(nil)
    @Binding var toast: ToastMessage?

    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager
    @State private var editing: Item?
    @State private var moving: Item?
    @State private var lending: Item?

    private var actions: ItemActions { ItemActions(context: context, undoManager: undoManager) }

    var body: some View {
        NookGrid {
            ForEach(items) { item in
                cell(item)
            }
        }
        .sheet(item: $editing) { ItemEditor(item: $0) }
        .sheet(item: $lending) { LendSheet(item: $0) { toast = $0 } }
        .sheet(item: $moving) { item in
            MovePicker(title: Text("Move \(item.name)"), current: Location(of: item)) { place in
                if let place, let message = actions.move([item], to: place) { toast = message }
            }
        }
    }

    @ViewBuilder
    private func cell(_ item: Item) -> some View {
        if let selected = selection.wrappedValue {
            let isSelected = selected.contains(item.id)
            Button {
                selection.wrappedValue = isSelected ? selected.subtracting([item.id]) : selected.union([item.id])
            } label: {
                ItemCell(item: item, isSelected: isSelected)
            }
            .buttonStyle(.nookCard)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            NavigationLink(value: item) {
                ItemCell(item: item, isSelected: nil)
            }
            .buttonStyle(.nookCard)
            .itemZoomSource(item)
            .contextMenu {
                Button("Edit", systemImage: "pencil") { editing = item }
                Button("Move", systemImage: "arrow.up.and.down.and.arrow.left.and.right") { moving = item }
                Button(item.activeLoan == nil ? "Lend" : "Edit Loan", systemImage: "person.badge.plus") { lending = item }
                Button(item.isPrivate ? "Mark Not Private" : "Mark Private",
                       systemImage: item.isPrivate ? "lock.open" : "lock") {
                    toast = actions.setPrivate([item], !item.isPrivate)
                }
                Button("Duplicate", systemImage: "plus.square.on.square") { toast = actions.duplicate(item) }
                Divider()
                Button("Delete", systemImage: "trash", role: .destructive) { toast = actions.delete([item]) }
            }
        }
    }
}

/// One item: a photo card, or a row once text is at an accessibility size.
struct ItemCell: View {
    let item: Item
    let isSelected: Bool?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        StoredImage(fileName: item.cover?.fileName) { image in
            if typeSize.isAccessibilitySize {
                ItemRow(name: item.name, detail: item.placeText, photo: image, isSelected: isSelected) {
                    if let value = item.value { MoneyText(value.amount, currencyCode: value.currencyCode) }
                }
                .padding(.horizontal, NookSpace.s2)
                .nookCard(elevation: .flat)
                .accessibilityElement(children: .combine)
            } else {
                PhotoCard(name: item.name, location: Location(of: item)?.path ?? String(localized: "No room yet"),
                          photo: image, badges: item.badges, value: item.value, isSelected: isSelected)
            }
        }
    }
}

/// A section of items under a heading, the way Room, Spot and Home show them.
struct ItemSection<Header: View>: View {
    let items: [Item]
    var selection: Binding<Set<UUID>?> = .constant(nil)
    @Binding var toast: ToastMessage?
    @ViewBuilder let header: Header

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: NookSpace.s1) {
                header
                ItemGrid(items: items, selection: selection, toast: $toast)
            }
        }
    }
}
