import SwiftUI

/// A quick reminder made in Pop In: a few words and a time. It rings like a meeting, with the bubble.
struct AddReminderSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var date = Date.now.addingTimeInterval(30 * 60)
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField("What for? (Pick up Nora)", text: $title)
                    .focused($focused)
                    .submitLabel(.done)
                DatePicker("When", selection: $date, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                Section {
                    ForEach(model.ownReminders) { r in
                        HStack {
                            Text(r.title)
                            Spacer()
                            Text(r.date.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(Brand.secondary)
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets { model.deleteReminder(model.ownReminders[i].id) }
                    }
                } header: {
                    if !model.ownReminders.isEmpty { Text("Your reminders") }
                } footer: {
                    Text("Reminders stay on this iPhone and ring like a meeting. Swipe one to delete it.")
                }
            }
            .navigationTitle("New reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        model.addReminder(title: title, at: date)
                        dismiss()
                    }
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }
}
