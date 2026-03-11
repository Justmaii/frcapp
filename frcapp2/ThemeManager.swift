import SwiftUI
import Combine

// MARK: - Theme Manager

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var colorScheme: ColorScheme? = nil

    private let key = "app_theme"

    init() {
        let saved = UserDefaults.standard.string(forKey: key) ?? "dark"
        apply(saved)
    }

    var currentThemeName: String {
        UserDefaults.standard.string(forKey: key) ?? "dark"
    }

    func apply(_ name: String) {
        UserDefaults.standard.set(name, forKey: key)
        switch name {
        case "light": colorScheme = .light
        case "system": colorScheme = nil
        default: colorScheme = .dark
        }
    }
}
