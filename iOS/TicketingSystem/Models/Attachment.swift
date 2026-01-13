import Foundation

struct Attachment: Identifiable, Codable {
    var id: String { filePath }
    let fileName: String
    let filePath: String
    let fileType: String // e.g. "image/jpeg", "application/pdf"
    
    // Computed property to check if it's an image
    var isImage: Bool {
        let lower = fileName.lowercased()
        return lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".png")
    }
}
