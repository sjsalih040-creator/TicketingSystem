import Foundation

@MainActor
class CreateTicketViewModel: ObservableObject {
    @Published var problemType = ""
    @Published var description = ""
    @Published var customerName = ""
    @Published var billNumber = ""
    @Published var billDate = Date()
    @Published var selectedWarehouse: Warehouse?
    
    // Attachments
    @Published var selectedImages: [Data] = []
    @Published var selectedFileNames: [String] = []
    
    @Published var warehouses: [Warehouse] = []
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var submissionSuccess = false
    
    private let networkManager = NetworkManager.shared
    let userSession: UserSession
    
    init(userSession: UserSession) {
        self.userSession = userSession
    }
    
    func fetchWarehouses() async {
        isLoading = true
        do {
            let fetched = try await networkManager.fetchWarehouses(userId: userSession.id)
            self.warehouses = fetched
            if let first = fetched.first {
                self.selectedWarehouse = first
            }
        } catch {
            errorMessage = "فشل تحميل المستودعات"
        }
        isLoading = false
    }
    
    func submit() async {
        guard !problemType.isEmpty, !description.isEmpty, !customerName.isEmpty, !billNumber.isEmpty, let warehouse = selectedWarehouse else {
            errorMessage = "يرجى تعبئة جميع الحقول المطلوبة"
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        do {
            try await networkManager.createTicket(
                problemType: problemType,
                description: description,
                customerName: customerName,
                billNumber: billNumber,
                billDate: billDate,
                warehouseId: warehouse.id,
                userId: userSession.id,
                attachments: selectedImages,
                fileNames: selectedFileNames
            )
            submissionSuccess = true
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
        
        isSubmitting = false
    }
    func addAttachment(data: Data, name: String) {
        selectedImages.append(data)
        selectedFileNames.append(name)
    }
    
    func removeAttachment(at index: Int) {
        guard index < selectedImages.count, index < selectedFileNames.count else { return }
        selectedImages.remove(at: index)
        selectedFileNames.remove(at: index)
    }
}
