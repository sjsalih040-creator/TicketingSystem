import Foundation

enum APIError: Error {
    case invalidURL
    case requestFailed
    case decodingFailed
    case serverError(String)
    case unauthorized
    
    var localizedDescription: String {
        switch self {
        case .invalidURL: return "رابط غير صالح"
        case .requestFailed: return "فشل الاتصال بالخادم"
        case .decodingFailed: return "فشل قراءة البيانات"
        case .serverError(let msg): return msg
        case .unauthorized: return "غير مصرح"
        }
    }
}
