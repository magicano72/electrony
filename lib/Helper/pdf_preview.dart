import 'dart:io';

import 'package:Electrony/Custom/snacbar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfPreviewScreen extends StatefulWidget {
  final String pdfUrl;
  final String fileName;

  const PdfPreviewScreen({
    Key? key,
    required this.pdfUrl,
    required this.fileName,
  }) : super(key: key);

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  @override
  Widget build(BuildContext context) {
    final PdfViewerController _pdfController = PdfViewerController();
    final TextEditingController _pageNumberController = TextEditingController();

    // Extract the file name from the fileName property
    // If the fileName still contains a URL or path, further extract just the file name
    String displayFileName = widget.fileName;
    if (displayFileName.contains('/')) {
      displayFileName = displayFileName.split('/').last;
    }

    // Remove any URL encoding if present
    if (displayFileName.contains('%')) {
      try {
        displayFileName = Uri.decodeFull(displayFileName);
      } catch (e) {
        print('Error decoding file name: $e');
      }
    }

    Future<void> _downloadFile(String fileUrl, String fileName) async {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloading file...')),
        );

        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/$fileName';

        final response = await http.get(Uri.parse(fileUrl));

        if (response.statusCode == 200) {
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          print('Downloaded to $filePath');
          showCustomSnackBar(context, 'File downloaded successfully');
        } else {
          throw 'Failed to download file: ${response.statusCode}';
        }
      } catch (e) {
        print("Error downloading file: $e");
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to download file')));
      }
    }

    String _getFileNameWithExtension(String fileName, String url) {
      final hasExtension = fileName.contains('.');
      if (hasExtension) return fileName;

      final uriPath = Uri.parse(url).path;
      final ext = uriPath.contains('.') ? uriPath.split('.').last : 'pdf';
      return '$fileName.$ext';
    }

    final fixedFileName =
        _getFileNameWithExtension(displayFileName, widget.pdfUrl);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Color(0xFFF5F5F5),
        elevation: 4, // Adds a slight shadow for depth

        title: Text(
          fixedFileName, // Use the processed file name
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_left),
                  onPressed: () {
                    if (_pdfController.pageNumber > 1) {
                      _pdfController.previousPage();
                    }
                  },
                ),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _pageNumberController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '${_pdfController.pageNumber}',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                    onSubmitted: (value) {
                      final pageNumber = int.tryParse(value);
                      if (pageNumber != null &&
                          pageNumber >= 1 &&
                          pageNumber <= _pdfController.pageCount) {
                        _pdfController.jumpToPage(pageNumber);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Invalid page number. Please enter a number between 1 and ${_pdfController.pageCount}.'),
                          ),
                        );
                        _pageNumberController.text =
                            _pdfController.pageNumber.toString();
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_right),
                  onPressed: () {
                    if (_pdfController.pageNumber < _pdfController.pageCount) {
                      _pdfController.nextPage();
                    }
                  },
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'Download') {
                await _downloadFile(widget.pdfUrl, fixedFileName);
              } else if (value == 'Share') {
                final tempDir = await getTemporaryDirectory();
                final tempFile = File('${tempDir.path}/$fixedFileName');
                final response = await http.get(Uri.parse(widget.pdfUrl));
                await tempFile.writeAsBytes(response.bodyBytes);
                await Share.shareXFiles(
                  [XFile(tempFile.path)],
                  text: 'Sharing $fixedFileName',
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'Download', child: Text('Download')),
              PopupMenuItem(value: 'Share', child: Text('Share')),
            ],
          ),
        ],
      ),
      body: SfPdfViewer.network(
        widget.pdfUrl,
        controller: _pdfController,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        pageLayoutMode: PdfPageLayoutMode.single,
      ),
    );
  }
}

class PdfMessageCard extends StatelessWidget {
  final String fileName;
  final String fileUrl;
  final bool isMe;

  const PdfMessageCard({
    Key? key,
    required this.fileName,
    required this.fileUrl,
    required this.isMe,
  }) : super(key: key);

  // Helper method to extract the actual filename from a path or URL
  String _extractFileName(String path) {
    // First attempt to extract just the file name from a path or URL
    String displayName = path;

    // If it's a URL or file path, get the last segment
    if (displayName.contains('/')) {
      displayName = displayName.split('/').last;
    }

    // Try to decode any URL encoding
    if (displayName.contains('%')) {
      try {
        displayName = Uri.decodeFull(displayName);
      } catch (e) {
        print('Error decoding filename: $e');
      }
    }

    // If it's a UUID (common in Directus file IDs), use a generic name instead
    if (RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
        .hasMatch(displayName)) {
      displayName = 'Document.pdf';
    }

    // If no extension, add .pdf
    if (!displayName.toLowerCase().endsWith('.pdf')) {
      displayName += '.pdf';
    }

    return displayName;
  }

  @override
  Widget build(BuildContext context) {
    // Get a properly formatted filename for display
    final displayFileName = _extractFileName(fileName);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              pdfUrl: fileUrl,
              fileName: displayFileName, // Pass the properly formatted name
            ),
          ),
        );
      },
      child: Container(
        width: 200,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Color(0xff3F90C3).withOpacity(0.1) : Color(0xffF0F4F8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.redAccent),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                displayFileName, // Use the properly formatted name
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isMe ? Colors.black87 : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
