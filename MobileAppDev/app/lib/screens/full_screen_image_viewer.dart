import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import '../models/attachment.dart';

class FullScreenImageViewer extends StatelessWidget {
  final Attachment attachment;
  final String baseUrl;

  const FullScreenImageViewer({super.key, required this.attachment, required this.baseUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(attachment.fileName, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: PhotoView(
        imageProvider: NetworkImage('$baseUrl${attachment.filePath}'),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
      ),
    );
  }
}
