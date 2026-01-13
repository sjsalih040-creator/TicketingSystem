import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { self.rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    var localizedName: String {
        switch self {
        case .system: return "تلقائي (النظام)"
        case .light: return "فاتح"
        case .dark: return "داكن"
        }
    }
}

class ThemeManager: ObservableObject {
    @AppStorage("appTheme") var currentTheme: AppTheme = .system
    
    static let shared = ThemeManager()
    
    private init() {}
}
