import Foundation

struct Comment: Identifiable, Codable {
    let id: Int
    let content: String
    let createdDate: String
    let ticketId: Int
    let authorName: String
}
