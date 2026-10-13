import SwiftUI

struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(AppContainer.self) private var container
    @State private var isEditing = false
    @State private var isConfirmingSignOut = false
    @State private var stats = ProfileStats()
    @ObserveInjection var inject

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.x3) {
                    if let user = session.user {
                        ProfileHeader(user: user) { isEditing = true }
                        statsRow
                    }
                    menu
                    signOutButton
                    Text("Rail keeps your account and tickets on this device only.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding(Spacing.x2)
            }
            .background(Color.canvas)
            .navigationTitle("Profile")
            .task(id: session.user?.id) { await loadStats() }
            .sheet(isPresented: $isEditing) {
                if let user = session.user {
                    EditProfileView(user: user)
                }
            }
            .confirmationDialog("Sign out of Rail?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { Task { await session.logOut() } }
            } message: {
                Text("Your tickets stay saved on this device.")
            }
        }
        .enableInjection()
    }

    private var statsRow: some View {
        HStack(spacing: Spacing.x1 + 4) {
            stat(stats.upcoming, "Upcoming")
            stat(stats.completed, "Travelled")
            stat(stats.passengers, "Saved")
        }
    }

    private func stat(_ value: Int, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(radius: Radius.large)
        .accessibilityElement(children: .combine)
    }

    private var menu: some View {
        VStack(spacing: 0) {
            NavigationLink {
                SavedPassengersView()
            } label: {
                MenuRow(title: "Saved Passengers", subtitle: "Fill bookings in one tap", symbol: "person.2.fill")
            }
            Divider().padding(.leading, Spacing.x2 + 36 + Spacing.x2)
            NavigationLink {
                SettingsView()
            } label: {
                MenuRow(title: "Settings", subtitle: "Theme, default class, account", symbol: "gearshape.fill")
            }
        }
        .buttonStyle(.plain)
        .background(Color.raised, in: RoundedRectangle(cornerRadius: Radius.xlarge, style: .continuous))
    }

    private var signOutButton: some View {
        Button(role: .destructive) {
            isConfirmingSignOut = true
        } label: {
            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color.raised, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        }
        .buttonStyle(.pressable)
        .foregroundStyle(.red)
    }

    private func loadStats() async {
        guard let user = session.user else { return }
        let bookings = (try? await container.bookings.bookings(for: user)) ?? []
        let passengers = (try? await container.passengers.passengers(for: user)) ?? []
        withAnimation(.snappy) {
            stats = ProfileStats(
                upcoming: bookings.filter(\.isUpcoming).count,
                completed: bookings.filter { $0.status == .confirmed && !$0.isUpcoming }.count,
                passengers: passengers.count
            )
        }
    }
}

private struct ProfileStats {
    var upcoming = 0
    var completed = 0
    var passengers = 0
}

private struct MenuRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    @ObserveInjection var inject

    var body: some View {
        HStack(spacing: Spacing.x2) {
            IconBadge(systemName: symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Spacing.x1)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Spacing.x2)
        .padding(.vertical, Spacing.x1 + 4)
        .contentShape(Rectangle())
        .enableInjection()
    }
}

private struct ProfileHeader: View {
    let user: User
    let onEdit: () -> Void
    @ScaledMetric(relativeTo: .title) private var avatarSize: CGFloat = 72
    @ObserveInjection var inject

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            HStack(spacing: Spacing.x2) {
                Text(user.initials)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.onAccent)
                    .frame(width: avatarSize, height: avatarSize)
                    .background(.tint, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name)
                        .font(.title3.bold())
                    Label(user.email, systemImage: "envelope")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Label(user.phone, systemImage: "phone")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .labelStyle(TightLabelStyle())
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            }
            .accessibilityElement(children: .combine)
            Button(action: onEdit) {
                Text("Edit Profile")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            }
            .buttonStyle(.pressable)
            .foregroundStyle(.tint)
        }
        .surface(radius: Radius.xlarge, padding: Spacing.x2 + 4)
        .enableInjection()
    }
}

private struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.half + 2) {
            configuration.icon.font(.caption)
            configuration.title
        }
    }
}

struct EditProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var phone: String
    @State private var errorMessage: String?
    private let user: User
    @ObserveInjection var inject

    init(user: User) {
        self.user = user
        _name = State(initialValue: user.name)
        _phone = State(initialValue: user.phone)
    }

    private var canSave: Bool {
        Validation.isName(name) && Validation.isMobile(phone) && (name != user.name || phone != user.phone)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Full name", text: $name)
                        .textContentType(.name)
                    TextField("Mobile number", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    FieldError(phone.isEmpty || Validation.isMobile(phone) ? nil : "Use an 11-digit number starting with 01.")
                } footer: {
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                }
                Section {
                    LabeledContent("Email", value: user.email)
                } footer: {
                    Text("Email is your sign-in and can't be changed.")
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!canSave)
                }
            }
        }
        .enableInjection()
    }

    private func save() async {
        var updated = user
        updated.name = name
        updated.phone = phone
        do {
            try await session.update(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
