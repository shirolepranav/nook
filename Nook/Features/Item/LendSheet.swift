import SwiftUI
import SwiftData
import ContactsUI
import NookKit
import NookUI

/// I-06 Lend sheet (F7): who has it, since when, back by when, and a reminder the morning
/// it's due. Editing a loan that's out uses the same sheet.
struct LendSheet: View {
    let item: Item
    let onSave: (ToastMessage) -> Void

    @State private var person: String
    @State private var contactID: String?
    /// The name the picked contact gave; typing over it drops the contact.
    @State private var contactName: String?
    @State private var lentAt: Date
    @State private var dueAt: Date?
    @State private var remind: Bool
    @State private var choosesContact = false
    @State private var nameError = false
    @State private var saved = 0
    @FocusState private var nameFocused: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager
    @Environment(\.reminders) private var reminders
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss

    init(item: Item, onSave: @escaping (ToastMessage) -> Void) {
        self.item = item
        self.onSave = onSave
        let loan = item.activeLoan
        _person = State(initialValue: loan?.personName ?? "")
        _contactID = State(initialValue: loan?.contactID)
        _contactName = State(initialValue: loan?.contactID == nil ? nil : loan?.personName)
        _lentAt = State(initialValue: loan?.lentAt ?? Calendar.current.startOfDay(for: .now))
        _dueAt = State(initialValue: loan?.dueAt)
        _remind = State(initialValue: loan?.remind ?? true)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NookSpace.s3) {
                    who
                    dates
                    if dueAt != nil { reminderRow }
                }
                .padding(NookSpace.s2)
                .frame(maxWidth: NookLayout.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(NookColor.canvas)
            .navigationTitle(Text("Lend \(item.name)"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", role: .confirm, action: save)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationSizing(.form)   // D45: a form sheet on regular width
        .nookHaptic(.saved, trigger: saved)
        .background { ContactPicker(isPresented: $choosesContact) { name, id in
            person = name
            (contactID, contactName) = (id, name)
            nameError = false
        } }
        .onAppear { if person.isEmpty { nameFocused = true } }
    }

    private var who: some View {
        // Side by side, stacked at accessibility sizes.
        let row = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: NookSpace.s1))
            : AnyLayout(HStackLayout(alignment: .bottom, spacing: NookSpace.s1))
        return row {
            NookTextField(Text("Who has it?"), text: $person, prompt: Text("Name"),
                          error: nameError ? Text("Add who has it.") : nil)
                .focused($nameFocused)
                .textContentType(.name)
                .submitLabel(.done)
                .onChange(of: person) { _, name in
                    if !name.isEmpty { nameError = false }
                    if name != contactName { (contactID, contactName) = (nil, nil) }
                }
            Button { choosesContact = true } label: {
                Label("Contacts", systemImage: "person.2")
            }
            .buttonStyle(.nookSecondary)
            .fixedSize(horizontal: !typeSize.isAccessibilitySize, vertical: false)
            .accessibilityLabel(Text("Choose from Contacts"))
        }
    }

    private var dates: some View {
        let row = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: NookSpace.s2)) : AnyLayout(HStackLayout(alignment: .top, spacing: NookSpace.s2))
        return row {
            FieldWell(Text("Lent on")) {
                DatePicker(selection: $lentAt, in: ...Date.now, displayedComponents: .date) { Text("Lent on") }
                    .labelsHidden()
            }
            FieldWell(Text("Back by")) {
                if let due = dueAt {
                    ClearableDate(Text("Back by"), date: Binding { due } set: { dueAt = $0 }, range: lentAt...,
                                  clearLabel: Text("Clear return date")) { dueAt = nil }
                } else {
                    Button("Add date") {
                        dueAt = Calendar.current.date(byAdding: .day, value: 14, to: Calendar.current.startOfDay(for: .now))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(Text("Add return date"))
                }
            }
        }
    }

    /// Only with a return date: the reminder comes the morning it's due (D50).
    private var reminderRow: some View {
        VStack(alignment: .leading, spacing: NookSpace.s1) {
            Toggle(isOn: $remind) {
                VStack(alignment: .leading, spacing: NookSpace.half) {
                    Text("Remind me").font(.nookBody).foregroundStyle(NookColor.textPrimary)
                    Text("The morning it’s due").font(.nookFootnote).foregroundStyle(NookColor.textSecondary)
                }
            }
            .padding(NookSpace.s2)
            .nookCard(elevation: .flat)
            if remind, reminders?.isDenied == true {
                RemindersOffNote()
            }
        }
    }

    private func save() {
        do {
            let message = try ItemActions(context: context, undoManager: undoManager)
                .lend(item, to: person, contactID: contactID, lentAt: lentAt, dueAt: dueAt, remind: remind)
            saved += 1
            if remind, dueAt != nil { Task { [reminders] in await reminders?.askIfNeeded() } }   // D15
            onSave(message)
            dismiss()
        } catch {
            nameError = true
            nameFocused = true
        }
    }
}

/// "Reminders are off for Nook." with a way to Settings (01 §13), on I-01, I-06 and S-07.
struct RemindersOffNote: View {
    var body: some View {
        VStack(alignment: .leading, spacing: NookSpace.half) {
            Label("Reminders are off for Nook.", systemImage: "bell.slash")
                .font(.nookFootnote)
                .foregroundStyle(NookColor.warning)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
            }
            .buttonStyle(.nookTertiary)
        }
    }
}

/// The system contact picker. It shares only the chosen contact, so Nook never asks for
/// Contacts access (D15, 01 §13). Presented from a host controller, because the picker
/// doesn't work embedded in a SwiftUI sheet.
private struct ContactPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let pick: (String, String) -> Void

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard isPresented, host.presentedViewController == nil else { return }
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        host.present(picker, animated: true)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPicker

        init(parent: ContactPicker) { self.parent = parent }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let name = CNContactFormatter.string(from: contact, style: .fullName) ?? contact.givenName
            parent.pick(name, contact.identifier)
            parent.isPresented = false
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.isPresented = false
        }
    }
}

#Preview {
    let store = PreviewStore.seeded(.lived)
    let item = try! store.mainContext.fetch(.init(predicate: #Predicate<Item> { $0.name == "Cordless drill" })).first!
    return Text(verbatim: "").sheet(isPresented: .constant(true)) { LendSheet(item: item) { _ in } }
        .modelContainer(store)
        .nookAccent(.terracotta)
}
