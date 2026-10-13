import SwiftUI

struct AuthFlowView: View {
    @ObserveInjection var inject

    var body: some View {
        NavigationStack {
            LoginView()
        }
        .enableInjection()
    }
}

struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @State private var model = LoginViewModel()
    @State private var isShowingPassword = false
    @FocusState private var focus: Field?

    private enum Field { case email, password }
    @ObserveInjection var inject

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x4) {
                AuthHeader(title: "Welcome back", message: "Sign in to book tickets and see your trips.")

                VStack(alignment: .leading, spacing: Spacing.x2) {
                    InputField(label: "Email", symbol: "envelope", isFocused: focus == .email) {
                        TextField("Email", text: $model.email, prompt: Text("you@example.com"))
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focus, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focus = .password }
                    }
                    InputField(label: "Password", symbol: "lock", isFocused: focus == .password) {
                        PasswordInput(title: "Password", text: $model.password, isRevealed: $isShowingPassword)
                            .textContentType(.password)
                            .focused($focus, equals: .password)
                            .submitLabel(.go)
                            .onSubmit(submit)
                    }
                    if let error = model.errorMessage {
                        FieldError(error)
                    }
                }

                VStack(spacing: Spacing.x2) {
                    Button(action: submit) {
                        ZStack {
                            Text("Sign In").opacity(model.isSubmitting ? 0 : 1)
                            if model.isSubmitting { ProgressView().tint(Color.onAccent) }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .primaryAction()
                    .disabled(!model.canSubmit)

                    HStack(spacing: Spacing.half) {
                        Text("New to Rail?")
                            .foregroundStyle(.secondary)
                        NavigationLink("Create an account") { SignUpView() }
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                }

                Label("Your account and tickets are stored only on this device.", systemImage: "lock.iphone")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.x3)
            .padding(.bottom, Spacing.x4)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.canvas)
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.error, trigger: model.errorMessage) { _, new in new != nil }
        .enableInjection()
    }

    private func submit() {
        focus = nil
        Task { await model.submit(using: session) }
    }
}

struct SignUpView: View {
    @Environment(SessionStore.self) private var session
    @State private var model = SignUpViewModel()
    @State private var isShowingPassword = false
    @FocusState private var focus: Field?

    private enum Field: Hashable { case name, phone, email, password, confirm }
    @ObserveInjection var inject

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x3) {
                VStack(alignment: .leading, spacing: Spacing.x1) {
                    Text("Create your account")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("It takes a minute. Your details fill tickets automatically.")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, Spacing.x2)

                VStack(alignment: .leading, spacing: Spacing.x2) {
                    SectionTitle("Your details")
                    field(.name, "Full name", symbol: "person", error: model.nameError) {
                        TextField("Full name", text: $model.name, prompt: Text("As on your NID"))
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                    }
                    field(.phone, "Mobile number", symbol: "phone", error: model.phoneError) {
                        TextField("Mobile number", text: $model.phone, prompt: Text("01XXXXXXXXX"))
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                            .monospacedDigit()
                    }
                    field(.email, "Email", symbol: "envelope", error: model.emailError) {
                        TextField("Email", text: $model.email, prompt: Text("you@example.com"))
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Text("Your mobile number appears on tickets and is used to verify them.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: Spacing.x2) {
                    SectionTitle("Password")
                    field(.password, "Password", symbol: "lock", error: model.passwordError) {
                        PasswordInput(title: "Password", text: $model.password, isRevealed: $isShowingPassword)
                            .textContentType(.newPassword)
                    }
                    field(.confirm, "Confirm password", symbol: "lock.rotation", error: model.confirmError) {
                        PasswordInput(title: "Confirm password", text: $model.confirmPassword, isRevealed: $isShowingPassword)
                            .textContentType(.newPassword)
                    }
                    if let error = model.errorMessage {
                        FieldError(error)
                    }
                }

                Button {
                    focus = nil
                    Task { await model.submit(using: session) }
                } label: {
                    ZStack {
                        Text("Create Account").opacity(model.isSubmitting ? 0 : 1)
                        if model.isSubmitting { ProgressView().tint(Color.onAccent) }
                    }
                    .frame(maxWidth: .infinity)
                }
                .primaryAction()
                .disabled(!model.canSubmit)
            }
            .padding(.horizontal, Spacing.x3)
            .padding(.bottom, Spacing.x4)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.canvas)
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.error, trigger: model.errorMessage) { _, new in new != nil }
        .enableInjection()
    }

    private func field(_ id: Field, _ label: String, symbol: String, error: String?,
                       @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.half) {
            InputField(label: label, symbol: symbol, isFocused: focus == id) {
                content().focused($focus, equals: id)
            }
            FieldError(error)
        }
    }
}

/// Secure field with a show/hide toggle that keeps the same text binding.
private struct PasswordInput: View {
    let title: String
    @Binding var text: String
    @Binding var isRevealed: Bool
    @ObserveInjection var inject

    var body: some View {
        HStack(spacing: Spacing.x1) {
            Group {
                if isRevealed {
                    TextField(title, text: $text)
                } else {
                    SecureField(title, text: $text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
        }
        .enableInjection()
    }
}

private struct AuthHeader: View {
    let title: String
    let message: String
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 64
    @ObserveInjection var inject

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x3) {
            BrandLogo(size: iconSize)
                .shadow(color: BrandPalette.deep.opacity(0.25), radius: 12, y: 6)
            VStack(alignment: .leading, spacing: Spacing.x1) {
                Text(title)
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.x6 + Spacing.x2)
        .enableInjection()
    }
}

/// Inline validation message shown under a form field.
struct FieldError: View {
    let message: String?
    @ObserveInjection var inject

    init(_ message: String?) {
        self.message = message
    }

    var body: some View {
        Group {
            if let message {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }
        }
        .enableInjection()
    }
}

#Preview {
    let container = AppContainer.preview()
    AuthFlowView()
        .environment(container)
        .environment(SessionStore(auth: container.auth))
}
