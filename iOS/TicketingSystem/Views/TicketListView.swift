import SwiftUI
import UIKit
import Combine

struct TicketListView: View {
    let userSession: UserSession
    @StateObject private var viewModel: TicketListViewModel
    @StateObject private var audioManager = AudioManager.shared
    
    init(userSession: UserSession) {
        self.userSession = userSession
        _viewModel = StateObject(wrappedValue: TicketListViewModel(userSession: userSession))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading && viewModel.tickets.isEmpty {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    VStack {
                        Text("حدث خطأ")
                            .font(.headline)
                        Text(error)
                            .foregroundColor(.gray)
                        Button("إعادة المحاولة") {
                            Task {
                                await viewModel.fetchTickets()
                            }
                        }
                        .padding()
                    }
                } else {
                    List(viewModel.filteredTickets) { ticket in
                        NavigationLink(destination: TicketDetailView(ticket: ticket, userSession: userSession)) {
                            TicketRow(ticket: ticket)
                        }
                    }
                    .searchable(text: $viewModel.searchText, prompt: "بحث (العميل، الفاتورة، المستودع...)")
                    .refreshable {
                        await viewModel.fetchTickets()
                    }
                }
                
                // Alarm Overlay
                if audioManager.isAlarmPlaying {
                    ZStack {
                        Color.black.opacity(0.8).ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.yellow)
                                .symbolEffect(.pulse, isActive: true)
                            
                            Text("تنبيه تذكرة جديدة!")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("يوجد نشاط جديد يتطلب انتباهك")
                                .foregroundColor(.white.opacity(0.8))
                            
                            Button(action: {
                                audioManager.stopAlarm()
                                Task { await viewModel.fetchTickets() } // Refresh on stop
                            }) {
                                Text("إيقاف التنبيه")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.red)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, 40)
                            .padding(.top, 20)
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6).opacity(0.2))
                        .cornerRadius(20)
                        .padding(30)
                    }
                    .transition(.opacity)
                    .zIndex(100)
                }
            }
            .navigationTitle("تذاكر المستودع")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                     Button(action: {
                         viewModel.showSettings = true
                     }) {
                         Image(systemName: "gear")
                     }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                           await viewModel.fetchTickets()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            viewModel.setupSignalRListeners()
            await viewModel.fetchTickets()
        }
        .onDisappear {
            viewModel.disconnectSignalR()
        }
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.showCreateTicket = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title.weight(.semibold))
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .shadow(radius: 4, x: 0, y: 4)
                    }
                    .padding()
                }
            }
        )
        .sheet(isPresented: $viewModel.showCreateTicket) {
            CreateTicketView(userSession: userSession)
        }
        .sheet(isPresented: $viewModel.showSettings) {
             SettingsView()
        }
    }
}


struct TicketRow: View {
    let ticket: Ticket
    
    var statusColor: Color {
        switch ticket.statusEnum {
        case .open: return .red
        case .inProgress: return .orange
        case .resolved: return .green
        case .closed: return .green.opacity(0.8)
        case .unknown: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ticket.statusEnum.title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
                
                Spacer()
                
                Text("#\(ticket.id)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Text(ticket.problemType)
                .font(.headline)
            
            Text(ticket.description)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(2)
            
            HStack {
                Image(systemName: "person")
                    .font(.caption)
                Text(ticket.customerName)
                    .font(.caption)
                
                Spacer()
                
                Text(ticket.createdDate.components(separatedBy: "T").first ?? "")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}
