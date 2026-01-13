import Foundation

struct Ticket: Identifiable, Codable {
    let id: Int
    let problemType: String
    let description: String
    let customerName: String
    let billNumber: String
    let billDate: String
    let warehouseId: Int
    let warehouseName: String?
    let status: Int
    let createdDate: String
    let creatorId: String?
    let commentCount: Int
    let lastCommentDate: String?
    
    // Status enum for UI logic
    enum Status: Int {
        case open = 0
        case inProgress = 1
        case resolved = 2
        case closed = 3
        case unknown = -1
        
        var title: String {
            switch self {
            case .open: return "مفتوح"
            case .inProgress: return "قيد المعالجة"
            case .resolved: return "محلول"
            case .closed: return "مغلق"
            case .unknown: return "غير معروف"
            }
        }
    }
    
    var statusEnum: Status {
        return Status(rawValue: status) ?? .unknown
    }
}
