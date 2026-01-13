import Foundation
import Combine
import SwiftUI

@MainActor
class LoginViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isLoggedIn = false
    @Published var userSession: UserSession?
    
    private let networkManager = NetworkManager.shared
    
    func login() async {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "يرجى إدخال اسم المستخدم وكلمة المرور"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await networkManager.login(username: username, password: password)
            self.userSession = session
            self.isLoggedIn = true
            
            // Save to UserDefaults
            if let encoded = try? JSONEncoder().encode(session) {
                UserDefaults.standard.set(encoded, forKey: "userSession")
            }
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
        
        isLoading = false
    }
    func logout() {
        isLoggedIn = false
        userSession = nil
        username = ""
        password = ""
        UserDefaults.standard.removeObject(forKey: "userSession")
    }
}
