import Foundation
import Combine

@MainActor
class TicketListViewModel: ObservableObject {
    @Published var tickets: [Ticket] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showCreateTicket = false
    @Published var showSettings = false
    
    @Published var searchText = ""
    
    private let networkManager = NetworkManager.shared
    private let userSession: UserSession
    
    var filteredTickets: [Ticket] {
        if searchText.isEmpty {
            return tickets
        } else {
            return tickets.filter { ticket in
                return ticket.customerName.contains(searchText) ||
                       ticket.billNumber.contains(searchText) ||
                       ticket.problemType.contains(searchText) ||
                       (ticket.warehouseName?.contains(searchText) ?? false) ||
                       String(ticket.id).contains(searchText)
            }
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init(userSession: UserSession) {
        self.userSession = userSession
    }
    
    func setupSignalRListeners() {
        SignalRService.shared.connect(userId: userSession.id)
        
        SignalRService.shared.ticketCreated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                AudioManager.shared.playAlarm()
                Task { await self?.fetchTickets() }
            }
            .store(in: &cancellables)
            
        SignalRService.shared.commentAdded
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ticketId in
                AudioManager.shared.playAlarm()
                // Ideally mark ticketId as "hasNewActivity"
                Task { await self?.fetchTickets() }
            }
            .store(in: &cancellables)
    }
    
    func disconnectSignalR() {
        SignalRService.shared.stop()
        cancellables.removeAll()
    }
    
    func fetchTickets() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedTickets = try await networkManager.fetchTickets(userId: userSession.id)
            self.tickets = fetchedTickets.sorted { $0.createdDate > $1.createdDate }
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
        
        isLoading = false
    }
}
