import SwiftUI

struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @AppStorage(AppStorageKey.appearance) private var appearance = Appearance.system
    @AppStorage(AppStorageKey.defaultSeatClass) private var defaultSeatClass = SeatClass.sChair
    @AppStorage(AppStorageKey.tripReminders) private var tripReminders = true
    @State private var isConfirmingDelete = false
    @State private var errorMessage: String?
    @ObserveInjection var inject

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                }
            }

            Section {
                Picker("Default class", selection: $defaultSeatClass) {
                    ForEach(SeatClass.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Trip reminders", isOn: $tripReminders)
            } header: {
                Text("Booking")
            } footer: {
                Text("The default class is preselected when you search.")
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Data", value: "Stored on this device")
            }

            Section {
                Button("Delete Account", role: .destructive) { isConfirmingDelete = true }
            } footer: {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else {
                    Text("Deletes your profile, saved passengers and tickets from this device.")
                }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Delete your account?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) {
                Task {
                    do { try await session.deleteAccount() } catch { errorMessage = error.localizedDescription }
                }
            }
        } message: {
            Text("This can't be undone.")
        }
        .enableInjection()
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
