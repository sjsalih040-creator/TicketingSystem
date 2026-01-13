import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../models/ticket.dart';
import '../models/comment.dart';
import '../models/user_session.dart';
import '../models/attachment.dart';
import 'full_screen_image_viewer.dart';

class TicketDetailScreen extends StatefulWidget {
  final Ticket ticket;
  final String baseUrl;
  final UserSession userSession;

  const TicketDetailScreen({super.key, required this.ticket, required this.baseUrl, required this.userSession});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  List<Comment> comments = [];
  List<Attachment> attachments = [];
  bool isLoading = true;
  final TextEditingController _commentController = TextEditingController();

  List<PlatformFile> _commentFiles = [];
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> _pickCommentFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null) {
      setState(() {
        _commentFiles.addAll(result.files);
      });
    }
  }

  Future<void> fetchData() async {
    await Future.wait([
      fetchComments(),
      fetchAttachments(),
    ]);
    setState(() => isLoading = false);
  }

  Future<void> fetchComments() async {
    try {
      final response = await http.get(Uri.parse('${widget.baseUrl}/api/mobile/tickets/${widget.ticket.id}/comments'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          comments = data.map((json) => Comment.fromJson(json)).toList();
        });
      }
    } catch (e) {
      print('Error fetching comments: $e');
    }
  }

  Future<void> fetchAttachments() async {
    try {
      final response = await http.get(Uri.parse('${widget.baseUrl}/api/mobile/tickets/${widget.ticket.id}/attachments'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          attachments = data.map((json) => Attachment.fromJson(json)).toList();
        });
      }
    } catch (e) {
      print('Error fetching attachments: $e');
    }
  }

  Future<void> addComment() async {
    if (_commentController.text.isEmpty) return;

    setState(() => isUploading = true);
    
    try {
      var request = http.MultipartRequest('POST', Uri.parse('${widget.baseUrl}/api/mobile/tickets/comments'));
      
      request.fields['ticketId'] = widget.ticket.id.toString();
      request.fields['content'] = _commentController.text;
      request.fields['userId'] = widget.userSession.id;

      for (var file in _commentFiles) {
        if (file.path != null) {
          request.files.add(await http.MultipartFile.fromPath('attachments', file.path!));
        }
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        _commentController.clear();
        setState(() => _commentFiles.clear());
        fetchComments(); // Refresh list
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إضافة التعليق')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إضافة التعليق')));
      }
    } catch (e) {
      print('Error adding comment: $e');
    } finally {
        setState(() => isUploading = false);
    }
  }
  
  Future<void> updateStatus(int newStatus) async {
    try {
      final response = await http.put(
        Uri.parse('${widget.baseUrl}/api/mobile/tickets/${widget.ticket.id}/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context, true); // Return true to indicate update
      }
    } catch (e) {
      print('Error updating status: $e');
    }
  }

  Future<void> _openAttachment(Attachment attachment) async {
    if (attachment.isImage) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenImageViewer(
              attachment: attachment,
              baseUrl: widget.baseUrl,
            ),
          ),
        );
        return;
    }

    final url = Uri.parse('${widget.baseUrl}${attachment.filePath}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن فتح الملف')),
        );
      }
    }
  }

  Color getStatusColor(int status) {
    switch (status) {
      case 0: return Colors.red; // Open
      case 1: return Colors.orange; // In Progress
      case 2: return Colors.green; // Resolved
      case 3: return Colors.green[800]!; // Closed
      default: return Colors.black;
    }
  }

  String getStatusArabic(int status) {
    switch (status) {
      case 0: return 'مفتوح';
      case 1: return 'قيد المعالجة';
      case 2: return 'محلول';
      case 3: return 'مغلق';
      default: return 'غير معروف';
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = widget.userSession.roles.contains('Admin');
    
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text('تذكرة رقم #${widget.ticket.id}'),
          centerTitle: true,
          actions: [
            if (isAdmin)
            PopupMenuButton<int>(
              onSelected: updateStatus,
              icon: const Icon(Icons.edit_outlined),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 1, child: Text('تغيير لقيد المعالجة')),
                const PopupMenuItem(value: 2, child: Text('تغيير لمحلول')),
                const PopupMenuItem(value: 3, child: Text('إغلاق التذكرة')),
              ],
            )
          ],
        ),
        body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  // Header Details
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.05),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                widget.ticket.problemType,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Chip(
                              label: Text(getStatusArabic(widget.ticket.status), style: const TextStyle(color: Colors.white, fontSize: 12)),
                              backgroundColor: getStatusColor(widget.ticket.status),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('الوصف:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(widget.ticket.description, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 18, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(widget.ticket.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 20),
                            const Icon(Icons.store_outlined, size: 18, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(widget.ticket.warehouseName ?? 'المستودع'),
                          ],
                        ),
                         const SizedBox(height: 8),
                         Row(
                           children: [
                             const Icon(Icons.receipt_long_outlined, size: 18, color: Colors.grey),
                             const SizedBox(width: 8),
                             Text('فاتورة رقم: ${widget.ticket.billNumber}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                             const SizedBox(width: 10),
                             Text('(${widget.ticket.billDate.split('T')[0]})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                           ],
                         ),
                      ],
                    ),
                  ),
                  
                  // Attachments Section
                  if (attachments.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.attach_file, size: 20, color: Colors.deepOrange),
                          const SizedBox(width: 8),
                          Text('المرفقات (${attachments.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: attachments.length,
                        itemBuilder: (context, index) {
                          final att = attachments[index];
                          return GestureDetector(
                            onTap: () => _openAttachment(att),
                            child: Container(
                              width: 110,
                              margin: const EdgeInsets.only(left: 12, bottom: 10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    att.isImage ? Icons.image : Icons.insert_drive_file,
                                    color: att.isImage ? Colors.purple : Colors.blue,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      att.fileName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                  ],

                  // Comments Header
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('التعليقات والمحادثة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),

                  // Comments List
                   if (comments.isEmpty)
                     const Padding(
                       padding: EdgeInsets.all(20.0),
                       child: Center(child: Text('لا يوجد تعليقات بعد', style: TextStyle(color: Colors.grey))),
                     )
                   else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        bool isMe = comment.authorName == widget.userSession.username;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: isMe ? MainAxisAlignment.start : MainAxisAlignment.end,
                            children: [
                              if (isMe) ...[
                                  CircleAvatar(
                                  backgroundColor: Colors.deepOrange,
                                  radius: 16,
                                  child: Text(comment.authorName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isMe ? Colors.deepOrange.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(12),
                                      topRight: const Radius.circular(12),
                                      bottomLeft: isMe ? const Radius.circular(0) : const Radius.circular(12),
                                      bottomRight: isMe ? const Radius.circular(12) : const Radius.circular(0),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(isMe ? 'أنا' : comment.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                                      Text(comment.content),
                                      const SizedBox(height: 4),
                                      Text(
                                        comment.createdDate.split('T').join(' ').substring(0, 16),
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (!isMe) ...[
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  backgroundColor: Colors.blueGrey,
                                  radius: 16,
                                  child: Text(comment.authorName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            
            // Comment Attachments Preview
            if (_commentFiles.isNotEmpty)
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: Theme.of(context).cardColor,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _commentFiles.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(left: 8, top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.attach_file, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            _commentFiles[index].name.length > 15 
                              ? '${_commentFiles[index].name.substring(0, 15)}...' 
                              : _commentFiles[index].name, 
                            style: const TextStyle(fontSize: 10)
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.red),
                            onPressed: () => setState(() => _commentFiles.removeAt(index)),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),

            // Add Comment Input (Fixed at bottom)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: SafeArea( 
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file, color: Colors.grey),
                      onPressed: _pickCommentFiles,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        textAlign: TextAlign.right,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'اكتب تعليقك هنا...',
                          filled: true,
                          fillColor: Theme.of(context).scaffoldBackgroundColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      backgroundColor: Colors.deepOrange,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 18),
                        onPressed: addComment,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
