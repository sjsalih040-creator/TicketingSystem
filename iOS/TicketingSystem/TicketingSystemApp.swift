import SwiftUI

@main
struct TicketingSystemApp: App {
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if sessionManager.isLoggedIn, let session = sessionManager.userSession {
                    TicketListView(userSession: session)
                } else {
                    LoginView()
                }
            }
            .preferredColorScheme(themeManager.currentTheme.colorScheme)
        }
    }
}

class SessionManager: ObservableObject {
    @Published var isLoggedIn = false
    @Published var userSession: UserSession?
    
    init() {
        checkSession()
    }
    
    func checkSession() {
        if let data = UserDefaults.standard.data(forKey: "userSession"),
           let session = try? JSONDecoder().decode(UserSession.self, from: data) {
            self.userSession = session
            self.isLoggedIn = true
        }
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: "userSession")
        self.userSession = nil
        self.isLoggedIn = false
    }
}
