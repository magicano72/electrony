import 'dart:convert';
import 'dart:io';

import 'package:Electrony/custom/button.dart';
import 'package:Electrony/custom/snacbar.dart';
import 'package:Electrony/networking/api_services.dart';
import 'package:Electrony/theming/style.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class CreateChatScreen extends StatefulWidget {
  final Function(List<String>, File?, bool) onEmailsCollected;

  const CreateChatScreen({
    Key? key,
    required this.onEmailsCollected,
  }) : super(key: key);

  @override
  _CreateChatScreenState createState() => _CreateChatScreenState();
}

class _CreateChatScreenState extends State<CreateChatScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final List<String> _emails = [];
  File? file;
  bool isImage = false;
  String title = '';

  @override
  void dispose() {
    _emailController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _addEmail() {
    final email = _emailController.text.trim();
    if (email.isNotEmpty && _isValidEmail(email) && !_emails.contains(email)) {
      setState(() {
        _emails.add(email);
        _emailController.clear();
      });
    } else if (!_isValidEmail(email)) {
      showCustomSnackBar(
        context,
        'Please enter a valid email address',
        isError: true,
      );
    } else if (_emails.contains(email)) {
      showCustomSnackBar(
        context,
        'Email already added',
        isError: true,
      );
    }
  }

  void _removeEmail(String email) {
    setState(() {
      _emails.remove(email);
    });
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
        r'^[\w-]+(\.[\w-]+)*@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*(\.[a-zA-Z]{2,})$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        file = File(pickedFile.path);
        isImage = true;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_emails.isEmpty) {
      showCustomSnackBar(context, 'Please add at least one user',
          isError: true);
      return;
    }

    title = _titleController.text.trim();
    if (title.isEmpty) {
      showCustomSnackBar(context, 'Please enter a chat title', isError: true);
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    final isConnected = connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.mobile);
    if (!isConnected) {
      showCustomSnackBar(context, 'No internet connection.', isError: true);
      return;
    }
    final apiService =
        AuthApiService(baseUrl: dotenv.env['API_BASE_URL'] ?? '');

    final token = await apiService.getValidToken();
    final userId = JwtDecoder.decode(token!)['id'];
    if (userId == null)
      throw Exception("Failed to extract user ID from token.");

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // Prepare chat data
      Map<String, dynamic> chatData = {
        "chat_title": title,
        "creator": userId,
      };

      // Upload avatar image if available
      String? avatarFileId;
      if (file != null && isImage) {
        // Create multipart request for file upload
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('${apiService.baseUrl}/files'),
        );

        // Add headers including authorization
        request.headers.addAll({
          "Authorization": "Bearer $token",
        });

        // Add the file to the request
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          file!.path,
        ));

        // Send the request
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 || response.statusCode == 201) {
          final fileData = json.decode(response.body);
          avatarFileId = fileData['data']['id'];
          print('✅ Uploaded avatar image: $avatarFileId');

          // Add avatar to chat data
          if (avatarFileId != null) {
            chatData["avatar"] = avatarFileId;
          }
        } else {
          print('❌ Failed to upload avatar: ${response.body}');
        }
      }

      // Create chat
      final createChatResponse = await http.post(
        Uri.parse('${apiService.baseUrl}/items/chats'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode(chatData),
      );

      if (createChatResponse.statusCode == 200 ||
          createChatResponse.statusCode == 201) {
        final responseData = json.decode(createChatResponse.body)['data'];
        final int chatId = responseData['id'];
        final Set<String> uniqueEmails = Set.from(_emails);
        for (final email in uniqueEmails) {
          final userResponse = await http.get(
            Uri.parse('${apiService.baseUrl}/users?filter[email][_eq]=$email'),
            headers: {
              "Authorization": "Bearer $token",
            },
          );
          if (userResponse.statusCode == 200) {
            final usersData = json.decode(userResponse.body)['data'];
            if (usersData.isNotEmpty) {
              final participantUserId = usersData[0]['id'];
              final participantResponse = await http.post(
                Uri.parse('${apiService.baseUrl}/items/chat_participants'),
                headers: {
                  "Content-Type": "application/json",
                  "Authorization": "Bearer $token",
                },
                body: json.encode({
                  "chat": chatId,
                  "user_id": participantUserId,
                }),
              );
              if (participantResponse.statusCode == 200 ||
                  participantResponse.statusCode == 201) {
                print('✅ Added participant: $email');
              } else {
                print('❌ Failed to add $email: ${participantResponse.body}');
              }
            }
          } else {
            print('❌ Failed to fetch user for $email: ${userResponse.body}');
          }
        }

        // Close loading indicator
        Navigator.of(context).pop();

        // Optionally call onEmailsCollected to continue flow
        widget.onEmailsCollected(_emails, file, isImage);

        // Navigate back or show success message
        showCustomSnackBar(context, 'Chat created successfully!');
        Navigator.of(context).pop(); // Return to previous screen
      } else {
        // Close loading indicator
        Navigator.of(context).pop();

        print('❌ Failed to create chat: ${createChatResponse.body}');
        showCustomSnackBar(context, 'Failed to create chat.', isError: true);
      }
    } catch (e) {
      // Close loading indicator
      Navigator.of(context).pop();

      print('❌ Error during chat creation: $e');
      showCustomSnackBar(context, 'An error occurred.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Create New Chat',
          style: textStyleVersion2(fontSize: 22),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Chat Title'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _titleController,
              hintText: 'Enter chat title',
              onChanged: (value) {
                setState(() {
                  title = value;
                });
              },
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Chat Avatar (Optional)'),
            const SizedBox(height: 8),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: file != null ? FileImage(file!) : null,
                  child: file == null
                      ? Icon(Icons.add_a_photo,
                          size: 32, color: Colors.grey[600])
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Add Participants'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _emailController,
                    hintText: 'Enter email address',
                    keyboardType: TextInputType.emailAddress,
                    onSubmitted: (_) => _addEmail(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _addEmail,
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(0xff3F90C3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Add',
                    style: textStyleVersion2(fontSize: 15, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_emails.isNotEmpty) ...[
              Text(
                'Participants:',
                style: textStyleVersion2(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _emails.map((email) {
                  return Chip(
                    label: Text(email),
                    deleteIcon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xffF0F4F8),
                    ),
                    onDeleted: () => _removeEmail(email),
                    backgroundColor: const Color(0xff3F90C3),
                    labelStyle: TextStyle(color: Colors.white),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
            ],
            CustomButton(text: 'Create Chat', onPressed: _handleSubmit)
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: textStyleVersion2(fontSize: 16),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      keyboardType: keyboardType,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}
