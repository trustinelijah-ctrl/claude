import SwiftUI
import SwiftData
import UIKit
import PianoCore

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @Environment(AudioRecorder.self) private var recorder
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @AppStorage("remindersOn") private var remindersOn = false
    @AppStorage("reminderMinutes") private var reminderMinutes = 18 * 60 + 30
    @AppStorage("reminderDays") private var reminderDaysRaw = ReminderScheduler.Days.everyDay.rawValue
    @AppStorage("inventoryHidden") private var inventoryHidden = false

    @State private var notificationsRefused = false
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            reminderMinutes = (parts.hour ?? 18) * 60 + (parts.minute ?? 30)
        }
    }

    private var reminderDays: ReminderScheduler.Days {
        ReminderScheduler.Days(rawValue: reminderDaysRaw) ?? .everyDay
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Practice reminder", isOn: $remindersOn)
                    if remindersOn {
                        DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                        Picker("Days", selection: $reminderDaysRaw) {
                            ForEach(ReminderScheduler.Days.allCases) { Text($0.label).tag($0.rawValue) }
                        }
                    }
                    if notificationsRefused {
                        Text("Notifications are off for Piano, Deeply. Turn them on in Settings to get reminders.")
                            .font(.footnote)
                            .foregroundStyle(Palette.inkSoft)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("It says “\(ReminderScheduler.body)” and nothing else. Missed days aren't counted anywhere.")
                }

                Section {
                    Button("Open the six-sample inventory") {
                        inventoryHidden = false
                        app.pendingSheet = .inventory
                        dismiss()
                    }
                } footer: {
                    Text("Log samples any time. Each gets a cold retest four weeks later.")
                }

                Section {
                    Button("Export as JSON", action: export)
                    if let exportError {
                        Text(exportError).font(.footnote).foregroundStyle(Palette.inkSoft)
                    }
                } header: {
                    Text("Your data")
                } footer: {
                    Text("Every session, target, attempt, retest, note, and recording's details, as readable JSON. Audio files aren't inside it; share a recording from the Journal to get its file. Everything stays on this iPhone: no account, no analytics.")
                }

                Section {
                    LabeledContent("Microphone") {
                        Text(microphoneStatus)
                    }
                    if recorder.permission == .denied {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                } footer: {
                    Text("Only used while you're recording. Recordings are for listening back; the app doesn't grade them.")
                }

                Section {
                    ForEach(Array(SuggestionEngine.rulesDescription.enumerated()), id: \.offset) { index, rule in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(index + 1).").monospacedDigit().foregroundStyle(Palette.inkSoft)
                            Text(rule)
                        }
                    }
                } header: {
                    Text("How Today's suggestion works")
                } footer: {
                    Text("Checked in this order; the first rule that applies wins, and the suggestion always says which one. Plain rules, no AI.")
                }
            }
            .canvasBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onAppear { recorder.refreshPermission() }
            .onChange(of: remindersOn) { _, _ in updateReminders() }
            .onChange(of: reminderMinutes) { _, _ in updateReminders() }
            .onChange(of: reminderDaysRaw) { _, _ in updateReminders() }
            .sheet(item: $exportFile) { file in
                ActivityView(items: [file.url])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var microphoneStatus: String {
        switch recorder.permission {
        case .granted: "Allowed"
        case .denied: "Off"
        case .undetermined: "Not asked yet"
        }
    }

    private func updateReminders() {
        let hour = reminderMinutes / 60, minute = reminderMinutes % 60, days = reminderDays
        Task {
            if remindersOn {
                let ok = await ReminderScheduler.enable(hour: hour, minute: minute, days: days)
                await MainActor.run {
                    notificationsRefused = !ok
                    if !ok { remindersOn = false }
                }
            } else {
                await ReminderScheduler.cancel()
            }
        }
    }

    private func export() {
        do {
            exportError = nil
            exportFile = ExportFile(url: try ExportService.writeFile(from: context))
        } catch {
            exportError = "Export failed: \(error.localizedDescription)"
        }
    }
}

struct ExportFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// The system share sheet, for handing over a file that was just written.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#if DEBUG
#Preview("Settings") {
    SettingsView()
        .previewEnvironment(.severalWeeks)
}
#endif
