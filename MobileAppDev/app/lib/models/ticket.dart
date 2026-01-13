class Ticket {
  final int id;
  final String problemType;
  final String description;
  final String customerName;
  final String billNumber;
  final String billDate;
  final int warehouseId;
  final String? warehouseName;
  final int status; // 0=Open, 1=InProgress, 2=Resolved, 3=Closed
  final String createdDate;
  final String? creatorId;
  final int commentCount;
  final String? lastCommentDate;

  // Local UI state (not from JSON directly)
  bool hasNewActivity;

  Ticket({
    required this.id,
    required this.problemType,
    required this.description,
    required this.customerName,
    required this.billNumber,
    required this.billDate,
    required this.warehouseId,
    this.warehouseName,
    required this.status,
    required this.createdDate,
    this.creatorId,
    this.commentCount = 0,
    this.lastCommentDate,
    this.hasNewActivity = false,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] ?? json['Id'],
      problemType: json['problemType'] ?? json['ProblemType'] ?? 'Unknown',
      description: json['description'] ?? json['Description'] ?? '',
      customerName: json['customerName'] ?? json['CustomerName'] ?? '',
      billNumber: json['billNumber'] ?? json['BillNumber'] ?? '',
      billDate: json['billDate'] ?? json['BillDate'] ?? '',
      warehouseId: json['warehouseId'] ?? json['WarehouseId'] ?? 0,
      warehouseName: json['warehouseName'] ?? json['WarehouseName'],
      status: json['status'] ?? json['Status'] ?? 0,
      createdDate: json['createdDate'] ?? json['CreatedDate'] ?? '',
      creatorId: json['creatorId'] ?? json['CreatorId'],
      commentCount: json['commentCount'] ?? json['CommentCount'] ?? 0,
      lastCommentDate: json['lastCommentDate'] ?? json['LastCommentDate'],
    );
  }

  String get statusText {
    switch (status) {
      case 0: return 'Open';
      case 1: return 'In Progress';
      case 2: return 'Resolved';
      case 3: return 'Closed';
      default: return 'Unknown';
    }
  }
}
