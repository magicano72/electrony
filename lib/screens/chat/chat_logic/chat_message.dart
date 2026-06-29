import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Electrony/custom/chat_text_form.dart';
import 'package:Electrony/custom/shimmer_loading.dart';
import 'package:Electrony/helper/pdf_preview.dart';
import 'package:Electrony/networking/api_services.dart';
import 'package:Electrony/screens/chat/chat_logic/chat_details.dart';
import 'package:Electrony/screens/chat/chat_logic/message_seen_by_info.dart';
import 'package:Electrony/screens/chat/models/chat_model.dart';
import 'package:Electrony/theming/colors.dart';
import 'package:Electrony/theming/style.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class ChatScreen extends StatefulWidget {
  final int chatId;
  final String chatName;
  final String? initialAvatarUrl;

  ChatScreen({
    Key? key,
    required this.chatId,
    required this.chatName,
    this.initialAvatarUrl,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> messages = [];
  final TextEditingController messageController = TextEditingController();
  final ScrollController _scrollController =
      ScrollController(); // Add this line

  final apiService = AuthApiService(baseUrl: dotenv.env['API_BASE_URL'] ?? '');
  String? userId;
  String? userEmail; // Store current user's email
  bool isLoading = true;
  bool isParticipant = false;
  Map<String, String> userEmails = {}; // Cache for user emails
  Map<String, String> userAvatars = {}; // Add this line
  Timer? _messageTimer;
  String? chatAvatarUrl;
  final ImagePicker _picker = ImagePicker();
  late String currentChatName;
  String? relatedDocumentId;
  bool _messagesMarkedAsSeen = false;
  final _audioRecorder = AudioRecorder(); // Import from record package
  final _audioPlayer = AudioPlayer(); // from just_audio

  bool _isRecording = false;
  String? _currentRecordingPath;
  bool _isPlaying = false;
  int? _playingMessageId;

  @override
  void initState() {
    super.initState();
    currentChatName = widget.chatName;
    chatAvatarUrl = widget.initialAvatarUrl;

    initializeChat();
    fetchChatAvatar();

    _messageTimer = Timer.periodic(Duration(milliseconds: 1200), (timer) {
      if (mounted) {
        fetchMessages();
      }
    });
    _initializeAudioRecorder();
    _initializeAudioPlayer();
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    messageController.dispose();
    _scrollController.dispose(); // Add this line
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> updateMessageStatus(int messageId, String status) async {
    try {
      final token = await apiService.getValidToken();
      if (token == null) return;

      final response = await http.patch(
        Uri.parse("${apiService.baseUrl}/items/messages/$messageId"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'status': status}),
      );

      if (response.statusCode == 200) {
        // Status updated successfully
        print('Message $messageId status updated to $status');
      } else {
        print('Failed to update message status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating message status: $e');
    }
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.image, color: Color(0xff3F90C3)),
                title: Text('Upload Image'),
                onTap: () {
                  Navigator.pop(context);
                  pickAndSendImage();
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.insert_drive_file, color: Color(0xff3F90C3)),
                title: Text('Upload File'),
                onTap: () {
                  Navigator.pop(context);
                  pickAndSendFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

// 4. Add method to mark messages as seen when user opens the chat
  Future<void> markMessagesAsSeen() async {
    try {
      final token = await apiService.getValidToken();
      if (token == null) return;

      // Find messages that are not from current user and not seen yet by this user
      List<ChatMessage> unseenMessages =
          messages.where((message) => message.sender != userId).toList();

      for (var message in unseenMessages) {
        await _markMessageAsSeen(message, token);
      }
    } catch (e) {
      print('Error marking messages as seen: $e');
    }
  }

  Future<void> _markMessageAsSeen(ChatMessage message, String token) async {
    try {
      // Fetch the user's email if not already available
      if (userEmail == null) {
        await fetchCurrentUserEmail(token);
        if (userEmail == null) {
          print("Failed to fetch user email. Cannot mark message as seen.");
          return;
        }
      }

      // First check from backend if already seen (prevent duplicate entries)
      final checkResponse = await http.get(
        Uri.parse("${apiService.baseUrl}/items/message_seen"
            "?filter[message_id][_eq]=${message.id}"
            "&filter[user_id][_eq]=$userId"),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (checkResponse.statusCode == 200) {
        final data = json.decode(checkResponse.body);
        final alreadySeenRemotely = (data['data'] as List).isNotEmpty;

        if (!alreadySeenRemotely) {
          // Create new "seen" record
          final seenByResponse = await http.post(
            Uri.parse("${apiService.baseUrl}/items/message_seen"),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'message_id': message.id,
              'user_id': userId,
            }),
          );

          if (seenByResponse.statusCode == 200 ||
              seenByResponse.statusCode == 201) {
            print("Marked message ${message.id} as seen by user $userId");
          } else {
            print(
                'Failed to mark message as seen: ${seenByResponse.statusCode}');
          }
        }
      } else {
        print('Error checking if message was already seen');
      }

      // Update message status to "seen" if not already
      if (message.status != 'seen') {
        await updateMessageStatus(message.id, 'seen');
      }
    } catch (e) {
      print('Error marking message as seen: $e');
    }
  }

// Make sure these variables are available in the state class
  String? userFirstName;
  String? userLastName;

  Future<void> initializeChat() async {
    final token = await apiService.getValidToken();

    userId = JwtDecoder.decode(token)['id'].toString();
    // Get current user's email
    await fetchCurrentUserEmail(token);

    final participantCheck = await isUserParticipant(widget.chatId, userId!);
    if (participantCheck) {
      await fetchChatParticipants();
      await fetchMessages();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Access denied: You are not a participant.")),
      );
      Navigator.of(context).pop();
    }

    setState(() {
      isParticipant = participantCheck;
      isLoading = false;
    });
  }

  Future<void> fetchMessages() async {
    try {
      final token = await apiService.getValidToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse(
            "${apiService.baseUrl}/items/messages?filter[chat][_eq]=${widget.chatId}&sort=timestamp&fields=*,seen_by.*,seen_by.user_id.first_name,seen_by.user_id.last_name,seen_by.user_id.avatar"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'] as List;
        List<ChatMessage> fetchedMessages = [];

        for (var messageData in data) {
          ChatMessage message = ChatMessage.fromJson(messageData);

          // Get sender email from cache or fetch it
          if (!userEmails.containsKey(message.sender)) {
            final email = await fetchUserEmail(message.sender);
            if (email != null) {
              userEmails[message.sender] = email;
            }
          }
          message.senderEmail = userEmails[message.sender];

          // Get sender avatar from cache or fetch it
          if (!userAvatars.containsKey(message.sender)) {
            final avatarUrl = await fetchUserAvatar(message.sender);
            if (avatarUrl != null) {
              userAvatars[message.sender] = avatarUrl;
            }
          }
          message.senderAvatarUrl = userAvatars[message.sender];

          fetchedMessages.add(message);
        }

        // Check if there are new messages
        bool hasNewMessages = messages.isEmpty ||
            fetchedMessages.length > messages.length ||
            (fetchedMessages.isNotEmpty &&
                messages.isNotEmpty &&
                fetchedMessages.last.id != messages.last.id);

        setState(() {
          messages.clear();
          messages.addAll(fetchedMessages);
        });

        // Mark new messages as seen if the user has opened the chat
        // Only mark messages as seen if there are new messages
        if (hasNewMessages) await markMessagesAsSeen();

        if (hasNewMessages) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    } catch (e) {
      print('Error fetching messages: $e');
    }
  }

  // Fetch current user's email
  Future<void> fetchCurrentUserEmail(String token) async {
    try {
      final url = Uri.parse("${apiService.baseUrl}/users/${userId}");
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        final userData = json.decode(response.body)['data'];
        userEmail = userData['email'];
        userFirstName = userData['first_name'];
        userLastName = userData['last_name'];

        if (userEmail != null) {
          userEmails[userId!] = userEmail!;
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  Future<bool> isUserParticipant(int chatId, String userId) async {
    final token = await apiService.getValidToken();
    final url = Uri.parse(
        "${apiService.baseUrl}/items/chat_participants?filter[chat][_eq]=$chatId&filter[user_id][_eq]=$userId");

    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body)['data'];
      return data != null && data.length > 0;
    }
    return false;
  }

  Future<void> fetchChatParticipants() async {
    try {
      final token = await apiService.getValidToken();
      if (token == null) return;

      // First get all participant IDs
      final participantsResponse = await http.get(
        Uri.parse(
            "${apiService.baseUrl}/items/chat_participants?filter[chat][_eq]=${widget.chatId}"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (participantsResponse.statusCode == 200) {
        final participantsData =
            json.decode(participantsResponse.body)['data'] as List;

        // For each participant, fetch their user details
        for (var participant in participantsData) {
          if (participant['user_id'] != null) {
            String participantId = participant['user_id'].toString();

            // Skip if it's the current user - we already have their email
            if (participantId == userId && userEmail != null) {
              continue;
            }

            final userResponse = await http.get(
              Uri.parse("${apiService.baseUrl}/users/$participantId"),
              headers: {'Authorization': 'Bearer $token'},
            );

            if (userResponse.statusCode == 200) {
              final userData = json.decode(userResponse.body)['data'];
              if (userData != null) {
                if (userData['email'] != null) {
                  userEmails[participantId] = userData['email'].toString();
                }
                if (userData['avatar'] != null) {
                  String avatarId = userData['avatar'].toString();
                  String avatarUrl = "${apiService.baseUrl}/assets/$avatarId";
                  userAvatars[participantId] = avatarUrl;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching participants: $e');
    }
  }

  Future<String?> fetchUserAvatar(String userId) async {
    try {
      final token = await apiService.getValidToken();
      final response = await http.get(
        Uri.parse("${apiService.baseUrl}/users/$userId"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body)['data'];
        if (userData != null && userData['avatar'] != null) {
          return "${apiService.baseUrl}/assets/${userData['avatar']}";
        }
      }
    } catch (e) {
      print("Error fetching user avatar: $e");
    }
    return "${apiService.baseUrl}/assets/fe9e38f9-d43d-4d34-97d6-7e759ff91a9e";
  }

  // Helper method to fetch a user's email by ID
  Future<String?> fetchUserEmail(String userId) async {
    try {
      final token = await apiService.getValidToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse("${apiService.baseUrl}/users/$userId"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body)['data'];
        if (userData != null && userData['email'] != null) {
          return userData['email'].toString();
        }
      }
      return null;
    } catch (e) {
      print('Error fetching user email: $e');
      return null;
    }
  }

  Future<String?> getGroupChatReceiver() async {
    // Get a list of participants other than the current user
    List<String> otherParticipantIds =
        userEmails.keys.where((id) => id != userId).toList();

    // If it's a direct message (only 2 participants total), return the other person's ID
    if (otherParticipantIds.length == 1) {
      return otherParticipantIds.first;
    }
    // For group chats, you might return null or implement appropriate group message handling
    return null;
  }

  Future<void> pickAndSendFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Uploading document...')));

        File file = File(result.files.single.path!);
        String fileName = result.files.single.name;

        final maxSize = 10 * 1024 * 1024;
        final fileSize = await file.length();

        if (fileSize > maxSize) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('File too large. Maximum size is 10MB')));
          return;
        }

        // Store the actual filename in the message text for display purposes
        await sendMessage('📄 $fileName', docFile: file);
      }
    } catch (e) {
      print('Error picking file: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to select document')));
    }
  }

  Future<void> sendMessage(String text,
      {File? imageFile, File? docFile, File? audioFile}) async {
    final token = await apiService.getValidToken();

    try {
      String? receiver = await getGroupChatReceiver();
      String type = 'text';
      String? actualFileName;

      // Determine message type and extract filename if needed
      if (imageFile != null) {
        type = 'image';
        // Extract file name from path for images too
        actualFileName = imageFile.path.split('/').last;
      } else if (docFile != null) {
        type = 'file';
        // Extract the filename from the text if it contains a file emoji
        if (text.startsWith('📄 ')) {
          actualFileName = text.substring(2).trim();
        } else {
          // Otherwise extract from the file path
          actualFileName = docFile.path.split('/').last;
        }
      } else if (audioFile != null) {
        type = 'audio';
      }

      String? uploadedFileId;

      // Upload file if present
      if (imageFile != null || docFile != null || audioFile != null) {
        var fileUploadRequest = http.MultipartRequest(
          'POST',
          Uri.parse("${apiService.baseUrl}/files"),
        );
        fileUploadRequest.headers['Authorization'] = 'Bearer $token';

        // Add the file to upload
        File fileToUpload;
        if (imageFile != null) {
          fileToUpload = imageFile;
        } else if (docFile != null) {
          fileToUpload = docFile;
        } else {
          fileToUpload = audioFile!;
        }

        // Include the actual filename in the upload if we have it
        if (actualFileName != null) {
          fileUploadRequest.files.add(
            await http.MultipartFile.fromPath('file', fileToUpload.path,
                filename: actualFileName),
          );
        } else {
          fileUploadRequest.files.add(
            await http.MultipartFile.fromPath('file', fileToUpload.path),
          );
        }

        var fileResponse = await fileUploadRequest.send();
        if (fileResponse.statusCode == 200) {
          var fileResponseData = await fileResponse.stream.bytesToString();
          uploadedFileId = json.decode(fileResponseData)['data']['id'];
        } else {
          throw Exception('Failed to upload file');
        }
      }

      Map<String, dynamic> requestBody = {
        'chat': widget.chatId,
        'text': type == 'text' ? text : (type == 'file' ? text : null),
        'sender': userId,
        'receiver': receiver,
        'type': type,
      };

      if (type == 'image' && uploadedFileId != null) {
        requestBody['image_url'] = uploadedFileId;
      } else if (type == 'file' && uploadedFileId != null) {
        requestBody['file_url'] = uploadedFileId;
      } else if (type == 'audio' && uploadedFileId != null) {
        requestBody['audio_url'] = uploadedFileId;
      }

      final response = await http.post(
        Uri.parse("${apiService.baseUrl}/items/messages"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        messageController.clear();
        await fetchMessages();

        // Scroll to bottom after sending a message
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        print(
            'Error sending message: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  Future<void> pickAndSendImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await sendMessage('', imageFile: File(image.path));
    }
  }

  Future<void> fetchChatAvatar() async {
    try {
      final token = await apiService.getValidToken();
      final response = await http.get(
        Uri.parse("${apiService.baseUrl}/items/chats/${widget.chatId}"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final chatData = json.decode(response.body)['data'];
        if (chatData != null && chatData['avatar'] != null) {
          setState(() {
            relatedDocumentId = chatData['related_document']?.toString();
            chatAvatarUrl =
                "${apiService.baseUrl}/assets/${chatData['avatar']}";
          });
        }
      }
    } catch (e) {
      print('Error fetching chat avatar: $e');
    }
  }

  Future<void> updateChatAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final token = await apiService.getValidToken();

      // Upload image first
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

        // Update chat with new avatar
        final response = await http.patch(
          Uri.parse("${apiService.baseUrl}/items/chats/${widget.chatId}"),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'avatar': uploadedImageId}),
        );

        if (response.statusCode == 200) {
          await fetchChatAvatar();
        }
      }
    } catch (e) {
      print('Error updating chat avatar: $e');
    }
  }

  Future<bool> _requestPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.microphone,
        Permission.storage,
      ].request();

      if (statuses[Permission.microphone]?.isGranted == true) {
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Microphone permission is required for voice messages')),
        );
        return false;
      }
    } catch (e) {
      print('Permission error: $e');
      return false;
    }
  }

  Future<String> _getRecordingPath() async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return path.join(directory.path, 'audio_$timestamp.m4a');
  }

  Future<void> _startRecording() async {
    if (!await _requestPermissions()) {
      return;
    }

    try {
      final recordingPath = await _getRecordingPath();
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: recordingPath,
      );
      setState(() => _isRecording = true);
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start recording')),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _currentRecordingPath = path;
      });
      if (_currentRecordingPath != null) {
        await _sendAudioMessage(_currentRecordingPath!);
      }
    } catch (e) {
      print('Error stopping recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stop recording')),
      );
    }
  }

  Future<void> _initializeAudioRecorder() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Microphone permission is required')),
        );
      }
    } catch (e) {
      print('Error initializing audio recorder: $e');
    }
  }

  Future<void> _sendAudioMessage(String audioPath) async {
    final token = await apiService.getValidToken();
    if (token == null) return;

    try {
      // Upload audio file
      var audioUploadRequest = http.MultipartRequest(
        'POST',
        Uri.parse("${apiService.baseUrl}/files"),
      );
      audioUploadRequest.headers['Authorization'] = 'Bearer $token';
      audioUploadRequest.files.add(
        await http.MultipartFile.fromPath('file', audioPath),
      );

      var audioResponse = await audioUploadRequest.send();
      if (audioResponse.statusCode == 200) {
        var audioResponseData = await audioResponse.stream.bytesToString();
        String uploadedAudioId = json.decode(audioResponseData)['data']['id'];

        String? receiver = await getGroupChatReceiver();

        // Send message with audio
        Map<String, dynamic> requestBody = {
          'chat': widget.chatId,
          'sender': userId,
          'receiver': receiver,
          'type': 'audio',
          'audio_url': uploadedAudioId,
        };

        final response = await http.post(
          Uri.parse("${apiService.baseUrl}/items/messages"),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode(requestBody),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          await fetchMessages();
        }
      }
    } catch (e) {
      print('Error sending audio message: $e');
    }
  }

  Future<void> _playAudio(String audioUrl, int messageId) async {
    try {
      final fullUrl = "${apiService.baseUrl}/assets/$audioUrl";

      // Case 1: Playing new audio (different from current)
      if (_playingMessageId != messageId) {
        // Stop any currently playing audio
        await _audioPlayer.stop();

        // Update state before setting URL to avoid UI lag
        setState(() {
          _isPlaying = false;
          _playingMessageId = messageId;
        });

        // Set up new audio
        await _audioPlayer.setUrl(fullUrl);

        // Play after a short delay to ensure audio is loaded
        await Future.delayed(Duration(milliseconds: 50));
        await _audioPlayer.play();

        setState(() {
          _isPlaying = true;
        });
        return;
      }

      // Case 2: Toggle play/pause for current audio
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() {
          _isPlaying = false;
        });
      } else {
        await _audioPlayer.play();
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
      print('Error playing audio: $e');
      setState(() {
        _isPlaying = false;
        _playingMessageId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to play audio message')),
      );
    }
  }

// Also modify the _initializeAudioPlayer function for better state management
  Future<void> _initializeAudioPlayer() async {
    try {
      // Listen to player state changes
      _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
            if (state.processingState == ProcessingState.completed) {
              _isPlaying = false;
            }
          });
        }
      });

      // Add a listener for errors
      _audioPlayer.playbackEventStream.listen(
        (event) {},
        onError: (Object e, StackTrace st) {
          print('Error from audio player: $e');
          if (mounted) {
            setState(() {
              _isPlaying = false;
            });
          }
        },
      );
    } catch (e) {
      print('Error initializing audio player: $e');
    }
  }

  // Extract the message content builder into its own method
  Widget _buildMessageContent(
      ChatMessage message, bool isMe, String formattedTime, String? avatarUrl) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isMe && avatarUrl != null) ...[
          CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage(avatarUrl),
            backgroundColor: Colors.grey[300],
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Name + Timestamp
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMe && message.senderEmail != null)
                    Text(
                      message.senderEmail!.split('@')[0], // Just name
                      style: textStyleVersion2(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Color(0xff6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (!isMe) ...[
                    const SizedBox(width: 4),
                    Text(
                      "•",
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    formattedTime,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Message bubble with content
              Stack(
                children: [
                  message.type == 'image' || message.type == 'audio'
                      ? _buildMessageContentByType(message, isMe)
                      : Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe
                                ? PrimaryColors.navyBlue
                                : Color(0xffF0F4F8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _buildMessageContentByType(message, isMe),
                        ),
                  // Show message status indicators only for messages sent by the current user
                  if (isMe)
                    Positioned(
                      bottom: 0,
                      right: 4,
                      child: _buildMessageStatusIndicator(message),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Finally, update the _buildMessageItem to include swipe functionality:
  Widget _buildMessageItem(ChatMessage message) {
    final isMe = message.sender == userId;
    final adjustedTimestamp = message.timestamp.add(Duration(hours: 3));
    final formattedTime = DateFormat('h:mm a').format(adjustedTimestamp);

    final avatarUrl =
        !isMe ? message.senderAvatarUrl : 'assets/default_avatar.png';

    // Wrap the message in a dismissible widget for swipe functionality
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Column(
        children: [
          // For sent messages - use Dismissible to swipe and see who viewed it
          (isMe && message.seenBy.isNotEmpty)
              ? Dismissible(
                  key: Key('message_${message.id}'),
                  direction: DismissDirection.startToEnd,
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.only(left: 20),
                    color: Colors.blue[50],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.remove_red_eye, color: Color(0xff3F90C3)),
                        Text(
                          'Seen by ${message.seenBy.length}',
                          style: TextStyle(color: Color(0xff3F90C3)),
                        ),
                      ],
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MessageSeenScreen(
                          message: message,
                          apiService: apiService,
                        ),
                      ),
                    );
                    return false; // Don't actually dismiss
                  },
                  child: _buildMessageContent(
                      message, isMe, formattedTime, avatarUrl),
                )
              : _buildMessageContent(message, isMe, formattedTime, avatarUrl),
          SizedBox(
            height: 10.h,
          )
        ],
      ),
    );
  }

  Widget _buildMessageContentByType(ChatMessage message, bool isMe) {
    if (message.type == 'file' && message.fileUrl != null) {
      // Extract the filename from the text if it exists
      String fileName = message.text ?? '';

      // If text contains the file emoji (📄) pattern, it likely contains the filename
      if (fileName.startsWith('📄 ')) {
        fileName = fileName.substring(2).trim(); // Remove the emoji prefix
      } else {
        // If no proper filename in text, use the fileUrl but extract just the filename part
        fileName = message.fileUrl!;

        // Extract the last part of the path as the filename
        if (fileName.contains('/')) {
          fileName = fileName.split('/').last;
        }

        // Try to decode URL encoding if present
        if (fileName.contains('%')) {
          try {
            fileName = Uri.decodeFull(fileName);
          } catch (e) {
            print('Error decoding filename: $e');
          }
        }
      }

      return PdfMessageCard(
        fileName: fileName,
        fileUrl: "${apiService.baseUrl}/assets/${message.fileUrl}",
        isMe: isMe,
      );
    }

    if (message.type == 'audio' && message.audioUrl != null) {
      // Audio message code...
      final isThisPlaying = _playingMessageId == message.id && _isPlaying;

      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isMe ? Color(0xff3F90C3) : Color(0xffF0F4F8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                _isPlaying && _playingMessageId == message.id
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: isMe ? Colors.white : Colors.black,
                size: 24,
              ),
              onPressed: () {
                _playAudio(message.audioUrl!, message.id);
              },
            ),
            Container(
              width: 150,
              height: 30,
              decoration: BoxDecoration(
                color: isMe ? Colors.white24 : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: Text(
                  isThisPlaying ? 'Playing...' : 'Voice Message',
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (message.type == 'image' && message.imageUrl != null) {
      // Image message code...
      String fullImageUrl = "${apiService.baseUrl}/assets/${message.imageUrl}";
      return GestureDetector(
        onTap: () {
          // Image view code...
        },
        child: Container(
          width: 200,
          decoration: BoxDecoration(
            color:
                isMe ? Color(0xff3F90C3).withOpacity(0.1) : Color(0xffF0F4F8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              fullImageUrl,
              width: 200,
              fit: BoxFit.cover,
              headers: {'Cache-Control': 'no-cache'},
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    color: isMe ? Color(0xff3F90C3) : Colors.grey,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error,
                        color: isMe ? Color(0xff3F90C3) : Colors.grey),
                    TextButton(
                      onPressed: () => setState(() {}),
                      child: Text(
                        'Retry',
                        style: TextStyle(
                          color: isMe ? Color(0xff3F90C3) : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }

    // Text message content
    return Text(
      message.text ?? '',
      style: textStyleVersion2(
        fontFamily: 'Inter',
        color: isMe ? Colors.white : Color(0xff1F2937),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildMessageStatusIndicator(ChatMessage message) {
    // Only show status for messages sent by the current user
    if (message.sender != userId) {
      return SizedBox.shrink();
    }

    // For messages with seen_by data in a group chat
    if (message.seenBy.isNotEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.done_all,
            size: 16,
            color: Colors.white,
          ),
          SizedBox(width: 2),
          Text(
            '${message.seenBy.length}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      );
    }
    // Choose icon based on message status
    else if (message.status == 'seen') {
      // Double check mark for seen messages
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.done_all,
            size: 16,
            color: Colors.white,
          ),
        ],
      );
    } else {
      // Single check mark for sent/delivered messages
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.done,
            size: 16,
            color: Colors.white,
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: false, // Change to false
        scrolledUnderElevation: 0,
        backgroundColor: Color(0xffF0F4F8),
        leading: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.black, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        title: GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatDetailsScreen(
                  chatId: widget.chatId,
                  chatName: currentChatName,
                  chatAvatarUrl: chatAvatarUrl,
                  relatedDocumentId: relatedDocumentId,
                ),
              ),
            );

            if (result != null &&
                result is Map<String, dynamic> &&
                result['success'] == true) {
              setState(() {
                currentChatName = result['newTitle'];
              });
            }
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[300],
                backgroundImage:
                    chatAvatarUrl != null ? NetworkImage(chatAvatarUrl!) : null,
                child: chatAvatarUrl == null
                    ? Icon(Icons.group, color: Colors.grey[600])
                    : null,
              ),
              SizedBox(width: 12),
              Flexible(
                child: Text(
                  currentChatName,
                  style: textStyleVersion2(color: Color(0xff2D3748)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      body: isLoading
          ? ShimmerLoading()
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController, // Add this line
                    itemCount: messages.length,
                    itemBuilder: (context, index) =>
                        _buildMessageItem(messages[index]),
                  ),
                ),
                Container(
                  color: Color(0xffF0F4F8),
                  width: double.infinity,
                  height: 85.h,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: _showUploadOptions,
                          child: Image.asset(
                            'assets/upload_image.png',
                            width: 28.w,
                            height: 28.h,
                          ),
                        ),
                        SizedBox(
                          width: 8.w,
                        ),
                        GestureDetector(
                          onLongPress: _startRecording,
                          onLongPressEnd: (_) => _stopRecording(),
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isRecording ? Colors.red : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isRecording ? Icons.mic : Icons.mic_none,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 8.w,
                        ),
                        Expanded(
                          child: ChatTextForm(
                            hintText: 'Type a message...',
                            controller: messageController,
                            prefixIconColor: Color(0xff1E1E1E),
                            containerColor: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Container(
                          decoration: BoxDecoration(
                            color: Color(0xff3F90C3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          width: 50.w,
                          height: 50.h,
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed: () {
                              final text = messageController.text.trim();
                              if (text.isNotEmpty) {
                                sendMessage(text);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
