import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    
    // Using the same URL logic as Android (assuming on same network or emulator)
    // Adjust this IP if running on real device
    private let baseUrl = "http://samijamal87-001-site1.mtempurl.com" 
    
    private init() {}
    
    func login(username: String, password: String) async throws -> UserSession {
        guard let url = URL(string: "\(baseUrl)/api/mobile/login") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "username": username.trimmingCharacters(in: .whitespaces),
            "password": password
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.requestFailed
        }
        
        let decoder = JSONDecoder()
        
        if httpResponse.statusCode == 200 {
            struct LoginResponse: Codable {
                let success: Bool
                let user: UserSession
                let message: String?
            }
            
            do {
                let loginResponse = try decoder.decode(LoginResponse.self, from: data)
                if loginResponse.success {
                    return loginResponse.user
                } else {
                    throw APIError.serverError(loginResponse.message ?? "فشل تسجيل الدخول")
                }
            } catch {
                throw APIError.decodingFailed
            }
        } else {
             // Try to parse error message
             if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let message = errorJson["message"] as? String {
                 throw APIError.serverError(message)
             }
            throw APIError.unauthorized
        }
    }
    
    func fetchTickets(userId: String) async throws -> [Ticket] {
        guard let url = URL(string: "\(baseUrl)/api/mobile/tickets?userId=\(userId)") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
        
        do {
            return try JSONDecoder().decode([Ticket].self, from: data)
        } catch {
            print("Decoding error: \(error)")
            throw APIError.decodingFailed
        }
    }
    func fetchComments(ticketId: Int) async throws -> [Comment] {
        guard let url = URL(string: "\(baseUrl)/api/mobile/tickets/\(ticketId)/comments") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
        
        do {
            return try JSONDecoder().decode([Comment].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }
    

    
    func fetchWarehouses(userId: String) async throws -> [Warehouse] {
        guard let url = URL(string: "\(baseUrl)/api/mobile/warehouses?userId=\(userId)") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
        
        do {
            return try JSONDecoder().decode([Warehouse].self, from: data)
        } catch {
            // Try alternate casing if first fails, or just log
            throw APIError.decodingFailed
        }
    }
    
    func fetchAttachments(ticketId: Int) async throws -> [Attachment] {
        guard let url = URL(string: "\(baseUrl)/api/mobile/tickets/\(ticketId)/attachments") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
        
        do {
            return try JSONDecoder().decode([Attachment].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func createTicket(problemType: String, description: String, customerName: String, billNumber: String, billDate: Date, warehouseId: Int, userId: String, attachments: [Data] = [], fileNames: [String] = []) async throws {
        guard let url = URL(string: "\(baseUrl)/api/mobile/tickets") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        let params: [String: String] = [
            "ProblemType": problemType,
            "Description": description,
            "CustomerName": customerName,
            "BillNumber": billNumber,
            "BillDate": ISO8601DateFormatter().string(from: billDate),
            "WarehouseId": "\(warehouseId)",
            "userId": userId
        ]
        
        for (key, value) in params {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add Attachments
        for (index, fileData) in attachments.enumerated() {
            let fileName = index < fileNames.count ? fileNames[index] : "file_\(index).jpg"
            let mimeType = fileName.hasSuffix(".pdf") ? "application/pdf" : "image/jpeg"
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"attachments\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
    }
    
    func addComment(ticketId: Int, content: String, userId: String, attachments: [Data] = [], fileNames: [String] = []) async throws {
         guard let url = URL(string: "\(baseUrl)/api/mobile/tickets/comments") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
         
        var body = Data()
        
        // Fields expected by `AddCommentRequest` or the API endpoint logic
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let params: [String: String] = [
            "ticketId": "\(ticketId)",
            "content": content,
            "userId": userId
        ]
        
        for (key, value) in params {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add Attachments
        for (index, fileData) in attachments.enumerated() {
            let fileName = index < fileNames.count ? fileNames[index] : "file_\(index).jpg"
            let mimeType = fileName.hasSuffix(".pdf") ? "application/pdf" : "image/jpeg"
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"attachments\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
    }
}
