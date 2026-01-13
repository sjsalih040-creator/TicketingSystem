import SwiftUI

struct SettingsView: View {
    @StateObject private var audioManager = AudioManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("التنبيهات الصوتية")) {
                    HStack {
                        Text("نغمة التنبيه")
                        Spacer()
                        Text(audioManager.selectedRingtoneName)
                            .foregroundColor(.gray)
                    }
                    
                    Button("تجربة النغمة") {
                        audioManager.playAlarm()
                    }
                    
                    Button("إيقاف النغمة") {
                        audioManager.stopAlarm()
                        }
                        .foregroundColor(.red)
                }
                
                Section(header: Text("المظهر")) {
                    Picker("الوضع الليلي / النهاري", selection: $themeManager.currentTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.localizedName).tag(theme)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("معلومات")) {
                    Text("الإصدار 1.0.0")
                    
                    Button("محاكاة تذكرة جديدة (تست)") {
                        SignalRService.shared.triggerTestEvent()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                Section {
                    Button(action: {
                        // Clear session
                        // In a real app, this would be handled by a higher-level state object (like AppState)
                        // For now, we simulate by clearing UserDefaults (if we used them) or just notifying.
                        // Since the main Login switch is in `LoginView`, we need to reset `LoginViewModel` state or `UserSession`.
                        // Ideally, we post a notification or use an EnvironmentObject.
                        
                        // HACK for generated code: Reset the root view model via a Notification
                        NotificationCenter.default.post(name: NSNotification.Name("Logout"), object: nil)
                    }) {
                        Text("تسجيل الخروج")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("الإعدادات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("إغلاق") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
