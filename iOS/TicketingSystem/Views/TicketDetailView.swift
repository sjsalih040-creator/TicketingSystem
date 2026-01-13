import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers

struct TicketDetailView: View {
    @StateObject private var viewModel: TicketDetailViewModel
    
    // Attachment States
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isImportingFile = false
    
    init(ticket: Ticket, userSession: UserSession) {
        _viewModel = StateObject(wrappedValue: TicketDetailViewModel(ticket: ticket, userSession: userSession))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Details
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(viewModel.ticket.problemType)
                                .font(.title3)
                                .fontWeight(.bold)
                            Spacer()
                            StatusBadge(status: viewModel.ticket.statusEnum)
                        }
                        
                        Divider()
                        
                        Text("الوصف:")
                            .font(.headline)
                        Text(viewModel.ticket.description)
                            .padding(.bottom, 8)
                        
                        HStack {
                            Label(viewModel.ticket.customerName, systemImage: "person")
                            Spacer()
                            Label(viewModel.ticket.warehouseName ?? "المستودع", systemImage: "building.2")
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                        
                        HStack {
                            Label("فاتورة: \(viewModel.ticket.billNumber)", systemImage: "newspaper")
                            Spacer()
                            Text(viewModel.ticket.billDate.components(separatedBy: "T").first ?? "")
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding()
                    
                    // Attachments List (Horizontal)
                    if !viewModel.attachments.isEmpty {
                        VStack(alignment: .leading) {
                            Text("المرفقات")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.attachments) { attachment in
                                        AttachmentThumbnail(attachment: attachment, baseUrl: "http://samijamal87-001-site1.mtempurl.com")
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom)
                    }
                    
                    // Comments Header
                    Text("التعليقات والمحادثة")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if viewModel.isLoading && viewModel.comments.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if viewModel.comments.isEmpty {
                        Text("لا يوجد تعليقات بعد")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        ForEach(viewModel.comments) { comment in
                            CommentRow(comment: comment, currentUsername: viewModel.userSession.username)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            // Input Area
            VStack(spacing: 0) {
                Divider()
                
                // New Attachments Preview
                if !viewModel.newCommentFileNames.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(0..<viewModel.newCommentFileNames.count, id: \.self) { index in
                                HStack {
                                    Image(systemName: "doc.fill")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(viewModel.newCommentFileNames[index])
                                        .font(.caption)
                                        .lineLimit(1)
                                    
                                    Button(action: {
                                        viewModel.removeAttachment(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
                
                HStack(alignment: .bottom) {
                    
                    // Attachment Menu
                    Menu {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("ألبوم الصور", systemImage: "photo")
                        }
                        
                        Button(action: { isImportingFile = true }) {
                            Label("ملفات", systemImage: "folder")
                        }
                    } label: {
                        Image(systemName: "paperclip")
                            .font(.title3)
                            .foregroundColor(.gray)
                            .padding(10)
                    }

                    TextField("اكتب تعليقك هنا...", text: $viewModel.newCommentContent, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .multilineTextAlignment(.trailing)
                    
                    Button(action: {
                        Task {
                            await viewModel.addComment()
                        }
                    }) {
                        if viewModel.isPosting {
                            ProgressView()
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.orange)
                                .clipShape(Circle())
                        }
                    }
                    .disabled((viewModel.newCommentContent.trimmingCharacters(in: .whitespaces).isEmpty && viewModel.newCommentImages.isEmpty) || viewModel.isPosting)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
            }
        }
        .navigationTitle("تذكرة #\(viewModel.ticket.id)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchComments()
        }
        // Handle Photo Selection
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    // Try to get a meaningful name? Hard with PhotosPicker item sometimes, stick to generic or timestamp
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyyMMdd_HHmmss"
                    let name = "IMG_\(formatter.string(from: Date())).jpg"
                    
                    viewModel.addAttachment(data: data, name: name)
                    selectedPhotoItem = nil // Reset
                }
            }
        }
        // Handle File Selection
        .fileImporter(
            isPresented: $isImportingFile,
            allowedContentTypes: [.content],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    // Security scoped resource access
                    guard url.startAccessingSecurityScopedResource() else { continue }
                    
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    if let data = try? Data(contentsOf: url) {
                        viewModel.addAttachment(data: data, name: url.lastPathComponent)
                    }
                }
            case .failure(let error):
                print("File importing failed: \(error.localizedDescription)")
            }
        }
    }
}

struct StatusBadge: View {
    let status: Ticket.Status
    
    var color: Color {
        switch status {
        case .open: return .red
        case .inProgress: return .orange
        case .resolved: return .green
        case .closed: return .green.opacity(0.8)
        case .unknown: return .gray
        }
    }
    
    var body: some View {
        Text(status.title)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

struct CommentRow: View {
    let comment: Comment
    let currentUsername: String
    
    var isMe: Bool {
        comment.authorName == currentUsername
    }
    
    var body: some View {
        HStack(alignment: .top) {
            if isMe { Spacer() }
            
            if !isMe {
                Avatar(name: comment.authorName, color: .gray)
            }
            
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                HStack {
                    if isMe { Spacer() }
                    Text(isMe ? "أنا" : comment.authorName)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    if !isMe { Spacer() }
                }
                
                Text(comment.content)
                    .padding(10)
                    .background(isMe ? Color.orange.opacity(0.2) : Color.gray.opacity(0.2))
                    .cornerRadius(12)
                    .cornerRadius(isMe ? 0 : 12, corners: .bottomRight)
                    .cornerRadius(!isMe ? 0 : 12, corners: .bottomLeft)
                
                Text(comment.createdDate.components(separatedBy: "T").last?.prefix(5) ?? "")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            if isMe {
                Avatar(name: comment.authorName, color: .orange)
            }
            
            if !isMe { Spacer() }
        }
        .padding(.vertical, 4)
    }
}

struct Avatar: View {
    let name: String
    let color: Color
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 32, height: 32)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .foregroundColor(.white)
                    .font(.caption)
                    .fontWeight(.bold)
            )
    }
}

// Extension to round specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct AttachmentThumbnail: View {
    let attachment: Attachment
    let baseUrl: String
    
    var body: some View {
        if let url = URL(string: "\(baseUrl)\(attachment.filePath)") {
            Link(destination: url) {
                VStack {
                    if attachment.isImage {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty: ProgressView()
                            case .success(let image): image.resizable().scaledToFill()
                            case .failure: IconFallback(isImage: true)
                            @unknown default: EmptyView()
                            }
                        }
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                        .clipped()
                    } else {
                        IconFallback(isImage: false)
                    }
                    Text(attachment.fileName)
                        .font(.caption2)
                        .lineLimit(1)
                        .frame(width: 80)
                }
            }
        }
    }
}

struct IconFallback: View {
    let isImage: Bool
    var body: some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: isImage ? "photo" : "doc.fill")
                .foregroundColor(isImage ? .purple : .blue)
        }
        .frame(width: 80, height: 80)
        .cornerRadius(8)
    }
}
