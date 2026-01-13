import Foundation
import AVFoundation

class AudioManager: ObservableObject {
    static let shared = AudioManager()
    private var audioPlayer: AVAudioPlayer?
    
    @Published var isAlarmPlaying: Bool = false
    @Published var selectedRingtoneName: String = "Default"
    
    // Allow selecting file URL logic if needed
    
    private init() {}
    
    func playAlarm() {
        guard !isAlarmPlaying else { return }
        
        // 1. Setup Session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Session Config Error: \(error)")
        }

        // 2. Find File
        // Try to find custom ringtone first (implementation future), else use bundle
        guard let url = Bundle.main.url(forResource: "alarm", withExtension: "mp3") else {
            print("alarm.mp3 not found in bundle. Please drag 'alarm.mp3' into the Xcode project.")
            return
        }
        
        // 3. Play
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 1.0
            audioPlayer?.play()
            
            DispatchQueue.main.async {
                self.isAlarmPlaying = true
            }
        } catch {
            print("Audio Playback Error: \(error)")
        }
    }
    
    func stopAlarm() {
        audioPlayer?.stop()
        audioPlayer = nil
        
        // Deactivate session to allow other music to resume (optional)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        
        DispatchQueue.main.async {
            self.isAlarmPlaying = false
        }
    }
}
