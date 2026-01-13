class Attachment {
  final int id;
  final String fileName;
  final String filePath;
  final String uploadedDate;

  Attachment({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.uploadedDate,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] ?? json['Id'],
      fileName: json['fileName'] ?? json['FileName'] ?? 'unknown',
      filePath: json['filePath'] ?? json['FilePath'] ?? '',
      uploadedDate: json['uploadedDate'] ?? json['UploadedDate'] ?? '',
    );
  }

  bool get isImage {
    final ext = fileName.toLowerCase();
    return ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') || ext.endsWith('.gif');
  }
}
