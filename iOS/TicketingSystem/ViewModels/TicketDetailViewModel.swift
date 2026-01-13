import Foundation
import Combine
import SwiftUI

@MainActor
class TicketDetailViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var attachments: [Attachment] = [] // View attachments
    
    // New Comment Attachments
    @Published var newCommentImages: [Data] = []
    @Published var newCommentFileNames: [String] = []
    
    @Published var isLoading = false
    @Published var isPosting = false
    @Published var errorMessage: String?
    @Published var newCommentContent = ""
    
    private let networkManager = NetworkManager.shared
    let ticket: Ticket
    let userSession: UserSession
    
    init(ticket: Ticket, userSession: UserSession) {
        self.ticket = ticket
        self.userSession = userSession
    }
    
    func fetchComments() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedComments = try await networkManager.fetchComments(ticketId: ticket.id)
            self.comments = fetchedComments
            
            let fetchedAttachments = try await networkManager.fetchAttachments(ticketId: ticket.id)
            self.attachments = fetchedAttachments
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
        
        isLoading = false
    }
    
    func addComment() async {
        // Allow adding if there's text OR attachments
        guard !newCommentContent.trimmingCharacters(in: .whitespaces).isEmpty || !newCommentImages.isEmpty else { return }
        
        isPosting = true
        
        do {
            try await networkManager.addComment(ticketId: ticket.id, content: newCommentContent, userId: userSession.id, attachments: newCommentImages, fileNames: newCommentFileNames)
            newCommentContent = ""
            newCommentImages = []
            newCommentFileNames = []
            // Refresh comments
            await fetchComments()
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
        
        isPosting = false
    }
    
    func addAttachment(data: Data, name: String) {
        newCommentImages.append(data)
        newCommentFileNames.append(name)
    }
    
    func removeAttachment(at index: Int) {
        guard index < newCommentImages.count, index < newCommentFileNames.count else { return }
        newCommentImages.remove(at: index)
        newCommentFileNames.remove(at: index)
    }
}
