class Comment {
  final int id;
  final String content;
  final String createdDate;
  final int ticketId;
  final String authorName; // We joined this in SQL

  Comment({
    required this.id,
    required this.content,
    required this.createdDate,
    required this.ticketId,
    required this.authorName,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? json['Id'],
      content: json['content'] ?? json['Content'] ?? '',
      createdDate: json['createdDate'] ?? json['CreatedDate'] ?? '',
      ticketId: json['ticketId'] ?? json['TicketId'] ?? 0,
      authorName: json['authorName'] ?? json['AuthorName'] ?? 'Unknown',
    );
  }
}
