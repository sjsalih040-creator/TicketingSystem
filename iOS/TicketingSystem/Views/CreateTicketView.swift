import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct CreateTicketView: View {
    @StateObject private var viewModel: CreateTicketViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Attachment States
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isImportingFile = false
    
    init(userSession: UserSession) {
        _viewModel = StateObject(wrappedValue: CreateTicketViewModel(userSession: userSession))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("معلومات التذكرة")) {
                    TextField("نوع المشكلة", text: $viewModel.problemType)
                        .multilineTextAlignment(.trailing)
                    
                    TextField("الوصف التفصيلي", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...6)
                        .multilineTextAlignment(.trailing)
                    
                    if viewModel.isLoading {
                        ProgressView("جاري تحميل المستودعات...")
                    } else {
                        Picker("المستودع", selection: $viewModel.selectedWarehouse) {
                            ForEach(viewModel.warehouses) { warehouse in
                                Text(warehouse.name).tag(Optional(warehouse))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Section(header: Text("بيانات العميل")) {
                    TextField("اسم العميل", text: $viewModel.customerName)
                        .multilineTextAlignment(.trailing)
                    
                    TextField("رقم الفاتورة", text: $viewModel.billNumber)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                    
                    DatePicker("تاريخ الفاتورة", selection: $viewModel.billDate, displayedComponents: .date)
                }
                
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("المرفقات")) {
                    // New Attachments Preview
                    if !viewModel.selectedFileNames.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(0..<viewModel.selectedFileNames.count, id: \.self) { index in
                                    HStack {
                                        Image(systemName: "doc.fill")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text(viewModel.selectedFileNames[index])
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
                        }
                        .padding(.vertical, 5)
                    }
                    
                    HStack {
                         PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("ألبوم الصور", systemImage: "photo")
                        }
                        Spacer()
                        Button(action: { isImportingFile = true }) {
                            Label("ملفات", systemImage: "folder")
                        }
                    }
                    .foregroundColor(.blue)
                }
                
                Section {
                    Button(action: {
                        Task {
                            await viewModel.submit()
                        }
                    }) {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("إرسال التذكرة")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    .listRowBackground(Color.orange)
                    .disabled(viewModel.isSubmitting)
                }
            }
            .navigationTitle("تذكرة جديدة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("تم") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                }
            }
            .task {
                await viewModel.fetchWarehouses()
            }
            .onChange(of: viewModel.submissionSuccess) { success in
                if success {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            // Handle Photo Selection
            .onChange(of: selectedPhotoItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
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
}
