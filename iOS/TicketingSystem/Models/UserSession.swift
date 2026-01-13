import Foundation

struct UserSession: Codable {
    let id: String
    let username: String
    let roles: [String]
    let warehouses: [UserWarehouse]
    let isAdmin: Bool
    
    struct UserWarehouse: Codable {
        let Id: Int
        let Name: String
    }
}
