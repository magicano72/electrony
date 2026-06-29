import 'dart:convert';
import 'dart:io';

import 'package:Electrony/Custom/snacbar.dart';
import 'package:Electrony/helper/pdf_preview.dart';
import 'package:Electrony/networking/api_services.dart';
import 'package:Electrony/theming/style.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class ChatDetailsScreen extends StatefulWidget {
  final int chatId;
  final String chatName;
  final String? chatAvatarUrl;
  final String? relatedDocumentId;

  const ChatDetailsScreen({
    Key? key,
    required this.chatId,
    required this.chatName,
    this.chatAvatarUrl,
    this.relatedDocumentId,
  }) : super(key: key);

  @override
  State<ChatDetailsScreen> createState() => _ChatDetailsScreenState();
}

class _ChatDetailsScreenState extends State<ChatDetailsScreen> {
  final apiService = AuthApiService(baseUrl: dotenv.env['API_BASE_URL'] ?? '');
  List<ChatMember> members = [];
  bool isLoading = true;
  bool isLoadingDocument = false;
  final TextEditingController _titleController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool isUpdatingAvatar = false;
  bool isUpdatingTitle = false;
  String currentChatName = '';
  Document? relatedDocument;
  String? currentRelatedDocumentId;

  @override
  void initState() {
    super.initState();
    currentChatName = widget.chatName;
    _titleController.text = widget.chatName;
    currentRelatedDocumentId = widget.relatedDocumentId;

    // Initialize loading states
    setState(() {
      isLoading = true; // For members
      isLoadingDocument = true; // For document
    });

    // Fetch members and document concurrently
    fetchChatMembers();
    fetchDocumentDetails();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> fetchDocumentDetails() async {
    setState(() => isLoadingDocument = true);

    try {
      String? token = await apiService.getValidToken();
      if (token == null) {
        setState(() => isLoadingDocument = false);
        return;
      }

      final chatResponse = await http.get(
        Uri.parse("${apiService.baseUrl}/items/chats/${widget.chatId}"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (chatResponse.statusCode == 200) {
        final chatData = json.decode(chatResponse.body)['data'];
        final documentId = chatData['related_document'];

        setState(() {
          currentRelatedDocumentId = documentId;
        });

        if (documentId == null) {
          setState(() {
            relatedDocument = null;
            isLoadingDocument = false;
          });
          return;
        }

        final docResponse = await http.get(
          Uri.parse("${apiService.baseUrl}/files/$documentId"),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (docResponse.statusCode == 200) {
          final fileData = json.decode(docResponse.body)['data'];
          final url = "${apiService.baseUrl}/assets/${fileData['id']}";

          String filename = fileData['filename']?.toString() ?? 'Document';
          filename = filename.replaceAll(RegExp(r'^file_\d+_'), '');
          filename = filename.replaceAll(
              RegExp(
                  r'_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'),
              '');
          if (filename.isEmpty) filename = 'Document';

          final inferredType =
              await _inferFileType(url, filename, fileData['type'], token);

          if (!filename.contains('.')) {
            final extension = _getExtensionForType(inferredType);
            if (extension.isNotEmpty) {
              filename = '$filename.$extension';
            }
          }

          int? pageCount;
          if (inferredType == 'pdf') {
            pageCount = await _getPdfPageCount(url, token);
            try {
              final pdfTitle = await _extractPdfTitle(url, token);
              if (pdfTitle != null && pdfTitle.isNotEmpty) {
                filename = pdfTitle;
              }
            } catch (e) {
              print('Error extracting PDF title: $e');
            }
          }

          setState(() {
            relatedDocument = Document(
              id: fileData['id'],
              url: url,
              title: filename,
              fileType: inferredType.toUpperCase(),
              icon: _getIconForType(inferredType),
              pageCount: pageCount,
            );
            isLoadingDocument = false;
          });
        } else {
          throw Exception('Failed to load document details');
        }
      } else {
        throw Exception('Failed to load chat details');
      }
    } catch (e) {
      print('Error fetching document: $e');
      setState(() {
        relatedDocument = null;
        isLoadingDocument = false;
      });
      showCustomSnackBar(context, 'Failed to load document', isError: true);
    }
  }

// Helper function to extract PDF title from metadata
  Future<String?> _extractPdfTitle(String url, String token) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final document = PdfDocument(inputBytes: response.bodyBytes);
        final title = document.documentInformation.title;
        document.dispose();
        return title.isNotEmpty ? title : null;
      }
    } catch (e) {
      print('Error extracting PDF title: $e');
    }
    return null;
  }

  // Infer file type using Content-Type and magic bytes
  Future<String> _inferFileType(
      String url, String filename, String? mimeType, String token) async {
    print('Inferring type for filename: $filename, MIME: $mimeType');

    // Check filename extension first
    if (filename.contains('.')) {
      final extension = filename.split('.').last.toLowerCase();
      if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) return 'image';
      if (extension == 'pdf') return 'pdf';
      if (['doc', 'docx'].contains(extension)) return 'doc';
      if (['xls', 'xlsx'].contains(extension)) return 'excel';
      if (extension == 'txt') return 'text';
    }

    // Check MIME type from API
    if (mimeType != null) {
      if (mimeType == 'application/pdf') return 'pdf';
      if (mimeType.startsWith('image/')) return 'image';
      if (mimeType == 'application/msword' ||
          mimeType ==
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document')
        return 'doc';
      if (mimeType == 'application/vnd.ms-excel' ||
          mimeType ==
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        return 'excel';
      if (mimeType == 'text/plain') return 'text';
    }

    // Fetch Content-Type or magic bytes
    try {
      // Try HEAD request for Content-Type
      final headResponse = await http.head(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      final contentType = headResponse.headers['content-type'];
      print('Content-Type: $contentType');
      if (contentType != null) {
        if (contentType.contains('pdf')) return 'pdf';
        if (contentType.contains('image')) return 'image';
        if (contentType.contains('msword') ||
            contentType.contains(
                'vnd.openxmlformats-officedocument.wordprocessingml.document'))
          return 'doc';
        if (contentType.contains('ms-excel') ||
            contentType.contains(
                'vnd.openxmlformats-officedocument.spreadsheetml.sheet'))
          return 'excel';
        if (contentType.contains('text/plain')) return 'text';
      }

      // Fetch first 1KB to check magic bytes
      final getResponse = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Range': 'bytes=0-1023',
        },
      );
      if (getResponse.statusCode == 206 || getResponse.statusCode == 200) {
        final bytes = getResponse.bodyBytes;
        if (bytes.length > 4) {
          // PDF: %PDF
          if (bytes[0] == 0x25 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x44 &&
              bytes[3] == 0x46) return 'pdf';
          // JPEG: FF D8
          if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image';
          // PNG: 89 50 4E 47
          if (bytes[0] == 0x89 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x4E &&
              bytes[3] == 0x47) return 'image';
          // DOCX: PK (ZIP format)
          if (bytes[0] == 0x50 && bytes[1] == 0x4B) return 'doc';
          // XLSX: PK (ZIP format)
          if (bytes[0] == 0x50 && bytes[1] == 0x4B) return 'excel';
        }
      }
    } catch (e) {
      print('Error fetching Content-Type or magic bytes: $e');
    }

    return 'unknown';
  }

  // Get file extension for type
  String _getExtensionForType(String type) {
    switch (type) {
      case 'pdf':
        return 'pdf';
      case 'image':
        return 'jpg';
      case 'doc':
        return 'docx';
      case 'excel':
        return 'xlsx';
      case 'text':
        return 'txt';
      default:
        return '';
    }
  }

  // Get icon for file type
  IconData _getIconForType(String type) {
    switch (type) {
      case 'image':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
        return Icons.description;
      case 'excel':
        return Icons.table_chart;
      case 'text':
        return Icons.text_fields;
      default:
        return Icons.description;
    }
  }

  // Get PDF page count
  Future<int?> _getPdfPageCount(String url, String token) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final document = PdfDocument(inputBytes: response.bodyBytes);
        final pageCount = document.pages.count;
        document.dispose();
        print('PDF page count: $pageCount');
        return pageCount;
      }
    } catch (e) {
      print('Error getting PDF page count: $e');
    }
    return null;
  }

  Future<void> fetchChatMembers() async {
    try {
      String? token = await apiService.getValidToken();
      if (token == null) {
        setState(() => isLoading = false);
        return;
      }

      final response = await http.get(
        Uri.parse(
            "${apiService.baseUrl}/items/chat_participants?filter[chat][_eq]=${widget.chatId}"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> participantsData =
            json.decode(response.body)['data'];
        List<ChatMember> fetchedMembers = [];

        for (var participant in participantsData) {
          if (participant['user_id'] != null) {
            final userResponse = await http.get(
              Uri.parse(
                  "${apiService.baseUrl}/users/${participant['user_id']}"),
              headers: {'Authorization': 'Bearer $token'},
            );

            if (userResponse.statusCode == 200) {
              final userData = json.decode(userResponse.body)['data'];
              String? avatarUrl;
              if (userData['avatar'] != null) {
                avatarUrl =
                    "${apiService.baseUrl}/assets/${userData['avatar']}";
              }

              fetchedMembers.add(ChatMember(
                id: userData['id'],
                email: userData['email'],
                avatarUrl: avatarUrl,
              ));
            }
          }
        }

        setState(() {
          members = fetchedMembers;
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load chat members');
      }
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> updateChatAvatar() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xff3F90C3)),
                SizedBox(height: 16),
                Text(
                  'Updating avatar...',
                  style: textStyleVersion2(
                    fontSize: 16,
                    color: Color(0xff2D3748),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      String? token = await apiService.getValidToken();

      var imageUploadRequest = http.MultipartRequest(
        'POST',
        Uri.parse("${apiService.baseUrl}/files"),
      );
      imageUploadRequest.headers['Authorization'] = 'Bearer $token';
      imageUploadRequest.files.add(
        await http.MultipartFile.fromPath('file', image.path),
      );

      var imageResponse = await imageUploadRequest.send();
      if (imageResponse.statusCode == 200) {
        var imageResponseData = await imageResponse.stream.bytesToString();
        String uploadedImageId = json.decode(imageResponseData)['data']['id'];

        final response = await http.patch(
          Uri.parse("${apiService.baseUrl}/items/chats/${widget.chatId}"),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'avatar': uploadedImageId}),
        );

        if (response.statusCode == 200) {
          await fetchChatMembers();
          Navigator.of(context).pop();
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      print('Error updating chat avatar: $e');
      Navigator.of(context).pop();
    }
  }

  Future<void> openDocumentPicker() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    setState(() => isLoadingDocument = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xff3F90C3)),
              SizedBox(height: 16),
              Text(
                'Uploading document...',
                style: textStyleVersion2(
                  fontSize: 16,
                  color: Color(0xff2D3748),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      String? token = await apiService.getValidToken();
      if (token == null) {
        Navigator.of(context).pop();
        setState(() => isLoadingDocument = false);
        return;
      }

      var fileUploadRequest = http.MultipartRequest(
        'POST',
        Uri.parse("${apiService.baseUrl}/files"),
      );
      fileUploadRequest.headers['Authorization'] = 'Bearer $token';
      fileUploadRequest.files.add(
        await http.MultipartFile.fromPath('file', result.files.single.path!),
      );

      var fileResponse = await fileUploadRequest.send();
      if (fileResponse.statusCode == 200) {
        var fileResponseData = await fileResponse.stream.bytesToString();
        final fileData = json.decode(fileResponseData)['data'];
        String uploadedFileId = fileData['id'];

        // Update the chat with the new document
        final response = await http.patch(
          Uri.parse("${apiService.baseUrl}/items/chats/${widget.chatId}"),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'related_document': uploadedFileId}),
        );

        if (response.statusCode == 200) {
          // Update local state and fetch the new document details
          setState(() {
            currentRelatedDocumentId = uploadedFileId;
          });
          await fetchDocumentDetails();
        }
      }
    } catch (e) {
      print('Error uploading document: $e');
      showCustomSnackBar(context, 'Error uploading document', isError: true);
    } finally {
      Navigator.of(context).pop();
      setState(() => isLoadingDocument = false);
    }
  }

  Future<void> refreshDocument() async {
    setState(() => isLoadingDocument = true);
    try {
      String? token = await apiService.getValidToken();
      if (token == null) {
        setState(() => isLoadingDocument = false);
        return;
      }

      final response = await http.get(
        Uri.parse("${apiService.baseUrl}/items/chats/${widget.chatId}"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final chatData = json.decode(response.body)['data'];
        setState(() {
          currentRelatedDocumentId = chatData['related_document'];
        });
        await fetchDocumentDetails();
      }
    } catch (e) {
      print('Error refreshing chat data: $e');
      setState(() => isLoadingDocument = false);
    }
  }

  Future<void> _downloadFile(
      String fileUrl, String fileName, String fileType) async {
    try {
      showCustomSnackBar(context, 'Downloading file...');
      final token = await apiService.getValidToken();
      final directory = await getTemporaryDirectory();
      final extension = _getExtensionForType(fileType.toLowerCase());
      final filePath = extension.isEmpty
          ? '${directory.path}/$fileName'
          : '${directory.path}/$fileName.$extension';

      final response = await http.get(
        Uri.parse(fileUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        print('Downloaded to $filePath');
        showCustomSnackBar(context, 'File downloaded to $filePath');
      } else {
        throw 'Failed to download file: ${response.statusCode}';
      }
    } catch (e) {
      print('Error downloading file: $e');
      showCustomSnackBar(context, 'Failed to download file', isError: true);
    }
  }

  Future<void> viewDocument() async {
    if (relatedDocument == null) return;

    final token = await apiService.getValidToken();
    final fileType = relatedDocument!.fileType.toLowerCase();
    print('Opening document: ${relatedDocument!.title}, type: $fileType');

    if (fileType == 'pdf') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            pdfUrl: relatedDocument!.url,
            fileName: relatedDocument!.title,
          ),
        ),
      );
    } else if (fileType == 'image') {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(
                relatedDocument!.url,
                headers: {'Authorization': 'Bearer $token'},
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(
                    Icons.error,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'File: ${relatedDocument!.title}',
            style: textStyleVersion2(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xff2D3748),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fileType == 'unknown'
                    ? 'Unknown file type'
                    : 'File type: ${relatedDocument!.fileType}',
                style: textStyleVersion2(
                  fontSize: 16,
                  color: Color(0xff2D3748),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'This file cannot be previewed in the app.',
                style: textStyleVersion2(
                  fontSize: 14,
                  color: Color(0xff6B7280),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: textStyleVersion2(
                  fontSize: 16,
                  color: Color(0xff6B7280),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _downloadFile(
                  relatedDocument!.url,
                  relatedDocument!.title,
                  relatedDocument!.fileType,
                );
              },
              child: Text(
                'Download',
                style: textStyleVersion2(
                  fontSize: 16,
                  color: Color(0xff3F90C3),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _openFileExternally(
                  relatedDocument!.url,
                  relatedDocument!.title,
                  relatedDocument!.fileType,
                );
              },
              child: Text(
                'Open Externally',
                style: textStyleVersion2(
                  fontSize: 16,
                  color: Color(0xff3F90C3),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> updateChatTitle(String newTitle) async {
    setState(() => isUpdatingTitle = true);
    try {
      String? token = await apiService.getValidToken();
      final response = await http.patch(
        Uri.parse("${apiService.baseUrl}/items/chats/${widget.chatId}"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'chat_title': newTitle}),
      );

      if (response.statusCode == 200) {
        setState(() {
          currentChatName = newTitle;
        });
        Navigator.pop(context);
        Navigator.pop(context, {'success': true, 'newTitle': newTitle});
      }
    } catch (e) {
      print('Error updating chat title: $e');
    } finally {
      if (mounted) setState(() => isUpdatingTitle = false);
    }
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          'Edit Chat',
          style: textStyleVersion2(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xff2D3748),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.image, color: Color(0xff3F90C3)),
              title: Text(
                'Change Avatar',
                style:
                    textStyleVersion2(fontSize: 16, color: Color(0xff2D3748)),
              ),
              onTap: () {
                Navigator.pop(context);
                updateChatAvatar();
              },
            ),
            ListTile(
              enabled: !isUpdatingAvatar && !isUpdatingTitle,
              leading: Icon(Icons.edit, color: Color(0xff3F90C3)),
              title: Text(
                'Change Title',
                style:
                    textStyleVersion2(fontSize: 16, color: Color(0xff2D3748)),
              ),
              trailing: isUpdatingTitle
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xff3F90C3)),
                      ),
                    )
                  : null,
              onTap: () {
                Navigator.pop(context);
                _showTitleEditDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.description, color: Color(0xff3F90C3)),
              title: Text(
                'Change Document',
                style:
                    textStyleVersion2(fontSize: 16, color: Color(0xff2D3748)),
              ),
              onTap: () {
                Navigator.pop(context);
                openDocumentPicker();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTitleEditDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'Edit Chat Title',
            style: textStyleVersion2(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xff2D3748),
            ),
          ),
          content: Container(
            decoration: BoxDecoration(
              color: Color(0xffF0F4F8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _titleController,
              enabled: !isUpdatingTitle,
              style: textStyleVersion2(
                fontSize: 16,
                color: Color(0xff1F2937),
              ),
              decoration: InputDecoration(
                hintText: 'Enter new title',
                hintStyle: textStyleVersion2(
                  fontSize: 16,
                  color: Color(0xff6B7280),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUpdatingTitle ? null : () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: textStyleVersion2(
                  fontSize: 16,
                  color: isUpdatingTitle
                      ? Color(0xff6B7280).withOpacity(0.5)
                      : Color(0xff6B7280),
                ),
              ),
            ),
            TextButton(
              onPressed: isUpdatingTitle
                  ? null
                  : () async {
                      if (_titleController.text.trim().isNotEmpty) {
                        setState(() => isUpdatingTitle = true);
                        await updateChatTitle(_titleController.text.trim());
                        setState(() => isUpdatingTitle = false);
                      }
                    },
              child: isUpdatingTitle
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xff3F90C3)),
                      ),
                    )
                  : Text(
                      'Save',
                      style: textStyleVersion2(
                        fontSize: 16,
                        color: Color(0xff3F90C3),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Open file in external app
  Future<void> _openFileExternally(
      String url, String fileName, String fileType) async {
    print('Attempting to open externally: $url, type: $fileType');
    try {
      // Download the file to a temporary directory
      final token = await apiService.getValidToken();
      final directory = await getTemporaryDirectory();
      final extension = _getExtensionForType(fileType.toLowerCase());
      final filePath = extension.isEmpty
          ? '${directory.path}/$fileName'
          : '${directory.path}/$fileName.$extension';

      showCustomSnackBar(context, 'Preparing file...');
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        print('File saved to $filePath');

        // Share the file to open it externally
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Opening $fileName',
        );
        showCustomSnackBar(context, 'File opened externally');
      } else {
        throw 'Failed to download file: ${response.statusCode}';
      }
    } catch (e) {
      print('Error opening file externally: $e');
      showCustomSnackBar(context, 'Could not open file. Try downloading it.',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xffF0F4F8),
        title: Text(
          'Chat Details',
          style: textStyleVersion2(
            color: Color(0xff2D3748),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            color: Color(0xffFAFAFA),
            icon: Icon(Icons.more_vert, color: Color(0xff2D3748)),
            onSelected: (value) {
              if (value == 'edit_avatar') {
                updateChatAvatar();
              } else if (value == 'edit_title') {
                _showTitleEditDialog();
              } else if (value == 'edit_document') {
                openDocumentPicker();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'edit_avatar',
                child: Row(
                  children: [
                    Icon(Icons.image, color: Color(0xff3F90C3), size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Change Avatar',
                      style: textStyleVersion2(
                        fontSize: 16,
                        color: Color(0xff2D3748),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'edit_title',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined,
                        color: Color(0xff3F90C3), size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Change Title',
                      style: textStyleVersion2(
                        fontSize: 16,
                        color: Color(0xff2D3748),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'edit_document',
                child: Row(
                  children: [
                    Icon(Icons.description, color: Color(0xff3F90C3), size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Change Document',
                      style: textStyleVersion2(
                        fontSize: 16,
                        color: Color(0xff2D3748),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 27.h),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: GestureDetector(
                          onTap: widget.chatAvatarUrl != null
                              ? () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      child: InteractiveViewer(
                                        panEnabled: true,
                                        minScale: 0.5,
                                        maxScale: 4,
                                        child: Image.network(
                                          widget.chatAvatarUrl!,
                                          loadingBuilder:
                                              (context, child, progress) {
                                            if (progress == null) return child;
                                            return Container(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.8,
                                              height: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.8,
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  value: progress
                                                              .expectedTotalBytes !=
                                                          null
                                                      ? progress
                                                              .cumulativeBytesLoaded /
                                                          progress
                                                              .expectedTotalBytes!
                                                      : null,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Color(0xffF0F4F8),
                            backgroundImage: widget.chatAvatarUrl != null
                                ? NetworkImage(widget.chatAvatarUrl!)
                                : null,
                            child: widget.chatAvatarUrl == null
                                ? Icon(Icons.group,
                                    size: 60, color: Color(0xff3F90C3))
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    currentChatName,
                    style: textStyleVersion2(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff2D3748),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xffE5E7EB), width: 1),
                  bottom: BorderSide(color: Color(0xffE5E7EB), width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.file_copy, color: Color(0xff3F90C3)),
                      SizedBox(width: 12.w),
                      Text(
                        'Related Document',
                        style: textStyleVersion2(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xff2D3748),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  if (isLoadingDocument)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child:
                            CircularProgressIndicator(color: Color(0xff3F90C3)),
                      ),
                    )
                  else if (relatedDocument != null)
                    GestureDetector(
                      onTap: viewDocument,
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color(0xffF0F4F8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Color(0xffE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              relatedDocument!.icon,
                              size: 40,
                              color: Color(0xff3F90C3),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    relatedDocument!.title,
                                    style: textStyleVersion2(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xff2D3748),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    relatedDocument!.fileType,
                                    style: textStyleVersion2(
                                      fontSize: 14,
                                      color: Color(0xff6B7280),
                                    ),
                                  ),
                                  if (relatedDocument!.pageCount != null)
                                    Text(
                                      '${relatedDocument!.pageCount} page${relatedDocument!.pageCount! > 1 ? 's' : ''}',
                                      style: textStyleVersion2(
                                        fontSize: 14,
                                        color: Color(0xff6B7280),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.visibility,
                              color: Color(0xff3F90C3),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    InkWell(
                      onTap: openDocumentPicker,
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color(0xffF0F4F8),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Color(0xffE5E7EB), width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline,
                                color: Color(0xff3F90C3)),
                            SizedBox(width: 8),
                            Text(
                              'Add Related Document',
                              style: textStyleVersion2(
                                fontSize: 16,
                                color: Color(0xff3F90C3),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Row(
                      children: [
                        Icon(Icons.people, color: Color(0xff3F90C3)),
                        SizedBox(width: 12.w),
                        Text(
                          'Members',
                          style: textStyleVersion2(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff2D3748),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '(${members.length})',
                          style: textStyleVersion2(
                            fontSize: 16,
                            color: Color(0xff6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  if (isLoading)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child:
                            CircularProgressIndicator(color: Color(0xff3F90C3)),
                      ),
                    )
                  else if (members.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          'No members found',
                          style: textStyleVersion2(
                            fontSize: 16,
                            color: Color(0xff6B7280),
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        return Column(
                          children: [
                            Container(
                              margin: EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: member.avatarUrl != null
                                      ? NetworkImage(member.avatarUrl!)
                                      : null,
                                  child: member.avatarUrl == null
                                      ? Icon(Icons.person,
                                          color: Colors.grey[600])
                                      : null,
                                ),
                                title: Text(
                                  member.email.split('@')[0],
                                  style: textStyleVersion2(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xff2D3748),
                                  ),
                                ),
                                subtitle: Text(
                                  member.email,
                                  style: textStyleVersion2(
                                    fontSize: 14,
                                    color: Color(0xff6B7280),
                                  ),
                                ),
                              ),
                            ),
                            Divider(
                              color: Color(0xffE5E7EB),
                              height: 1,
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMember {
  final String id;
  final String email;
  final String? avatarUrl;

  ChatMember({
    required this.id,
    required this.email,
    this.avatarUrl,
  });
}

class Document {
  final String id;
  final String url;
  final String title;
  final String fileType;
  final IconData icon;
  final int? pageCount;

  Document({
    required this.id,
    required this.url,
    required this.title,
    required this.fileType,
    required this.icon,
    this.pageCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'fileType': fileType,
      'icon': icon.toString(),
      'pageCount': pageCount,
    };
  }
}
