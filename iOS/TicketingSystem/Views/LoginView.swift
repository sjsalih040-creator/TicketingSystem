import SwiftUI
import UIKit

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    
    var body: some View {
        if viewModel.isLoggedIn, let session = viewModel.userSession {
            TicketListView(userSession: session)
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("Logout"))) { _ in
                    viewModel.logout() 
                }
        } else {
            ZStack {
                // Gradient Background
                LinearGradient(
                    gradient: Gradient(colors: [Color.orange.opacity(0.6), Color.red.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Logo/Icon
                    Image(systemName: "building.2.fill") // Warehouse icon substitute
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.white)
                    
                    Text("موظفي المستودع")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    } else {
                        VStack(spacing: 20) {
                            TextField("اسم المستخدم", text: $viewModel.username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .multilineTextAlignment(.trailing)
                                .textInputAutocapitalization(.never)
                            
                            SecureField("كلمة المرور", text: $viewModel.password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .multilineTextAlignment(.trailing)
                            
                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                            }
                            
                            Button(action: {
                                Task {
                                    await viewModel.login()
                                }
                            }) {
                                Text("تسجيل الدخول")
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                            }
                        }
                        .padding(30)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(20)
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
