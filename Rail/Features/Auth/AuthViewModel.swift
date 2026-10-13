import Foundation
import Observation

@MainActor
@Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    private(set) var isSubmitting = false
    var errorMessage: String?

    var canSubmit: Bool { Validation.isEmail(email.trimmed) && !password.isEmpty && !isSubmitting }

    func submit(using session: SessionStore) async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await session.logIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
@Observable
final class SignUpViewModel {
    var name = ""
    var email = ""
    var phone = ""
    var password = ""
    var confirmPassword = ""
    private(set) var isSubmitting = false
    var errorMessage: String?

    var nameError: String? { name.isEmpty || Validation.isName(name) ? nil : "Enter your full name." }
    var emailError: String? { email.isEmpty || Validation.isEmail(email.trimmed) ? nil : "Enter a valid email address." }
    var phoneError: String? { phone.isEmpty || Validation.isMobile(phone) ? nil : "Use an 11-digit number starting with 01." }
    var passwordError: String? {
        password.isEmpty || password.count >= Validation.minimumPasswordLength
            ? nil : "Use at least \(Validation.minimumPasswordLength) characters."
    }
    var confirmError: String? { confirmPassword.isEmpty || confirmPassword == password ? nil : "Passwords don't match." }

    var canSubmit: Bool {
        Validation.isName(name) && Validation.isEmail(email.trimmed) && Validation.isMobile(phone)
            && password.count >= Validation.minimumPasswordLength && password == confirmPassword && !isSubmitting
    }

    func submit(using session: SessionStore) async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await session.signUp(name: name, email: email, phone: phone, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
