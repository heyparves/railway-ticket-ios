import SwiftUI

enum AppStorageKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let appearance = "appearance"
    static let defaultSeatClass = "defaultSeatClass"
    static let tripReminders = "tripReminders"
    static let recentRoutes = "recentRoutes"
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
