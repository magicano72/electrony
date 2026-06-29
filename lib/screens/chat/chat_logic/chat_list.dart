import 'dart:convert';

import 'package:Electrony/custom/chat_text_form.dart';
import 'package:Electrony/custom/shimmer_loading.dart';
import 'package:Electrony/networking/api_services.dart';
import 'package:Electrony/screens/chat/chat_logic/chat_message.dart';
import 'package:Electrony/screens/chat/chat_logic/create_new_chat.dart';
import 'package:Electrony/screens/chat/models/chat_list_model.dart';
import 'package:Electrony/theming/colors.dart';
import 'package:Electrony/theming/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:page_transition/page_transition.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatModel> _chats = [];
  List<ChatModel> _filteredChats = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _locallyMarkedMessages = {}; // Track locally marked messages

  final apiService = AuthApiService(baseUrl: dotenv.env['API_BASE_URL'] ?? '');

  Map<int, String> chatAvatars = {};

  @override
  void initState() {
    super.initState();
    print('DEBUG: Initializing ChatListScreen, calling fetchChats');
    fetchChats();

    _searchController.addListener(() {
      print('DEBUG: Search query changed: ${_searchController.text}');
      filterChats(_searchController.text);
    });
  }

  @override
  void dispose() {
    print(
        'DEBUG: Disposing ChatListScreen, mounted: $mounted, reason: disposing');
    _searchController.dispose();
    super.dispose();
  }

  String? userId;
  bool _isFetching = false;

  Future<void> fetchChats() async {
    if (!mounted || _isFetching) {
      print(
          'DEBUG: fetchChats aborted - not mounted: $mounted, isFetching: $_isFetching');
      return;
    }

    _isFetching = true;
    print('DEBUG: Starting fetchChats');

    try {
      if (!mounted) {
        print('DEBUG: Widget not mounted, aborting fetchChats');
        return;
      }

      setState(() {
        _loading = true;
        print('DEBUG: Set loading to true');
      });

      final token = await apiService.getValidToken();

      userId = JwtDecoder.decode(token)['id'];
      print('DEBUG: Decoded user ID: $userId');

      try {
        final chatParticipantsUrl = Uri.parse(
          '${apiService.baseUrl}/items/chat_participants?filter[user_id][_eq]=$userId&fields=chat.id,chat.chat_title,chat.created_at',
        );
        print('DEBUG: Chat participants URL: $chatParticipantsUrl');

        final chatParticipantsResponse = await http.get(
          chatParticipantsUrl,
          headers: {
            'Authorization': 'Bearer $token',
          },
        );
        print(
            'DEBUG: Chat participants response status: ${chatParticipantsResponse.statusCode}');
        print(
            'DEBUG: Chat participants response body: ${chatParticipantsResponse.body}');

        if (chatParticipantsResponse.statusCode != 200) {
          print(
              'DEBUG: Failed to load chat participants: ${chatParticipantsResponse.statusCode}');
          throw Exception(
              'Failed to load chat participants: ${chatParticipantsResponse.statusCode}');
        }

        final responseData = json.decode(chatParticipantsResponse.body);
        print('DEBUG: Response data keys: ${responseData.keys}');

        if (!responseData.containsKey('data')) {
          print('DEBUG: Response missing "data" key: $responseData');
          throw Exception('Invalid response format: missing data key');
        }

        final List<dynamic> participantsData = responseData['data'];
        print('DEBUG: Found ${participantsData.length} chat participants');
        print('DEBUG: Participants data: $participantsData');

        final chatIds = participantsData
            .where((e) => e['chat'] != null)
            .map<int>((e) => e['chat']['id'] as int)
            .toList();
        print('DEBUG: Found ${chatIds.length} unique chat IDs: $chatIds');

        final List<ChatModel> chatsWithMessages = [];

        for (final chatId in chatIds) {
          print('DEBUG: Processing chat ID: $chatId');
          try {
            final chatUrl =
                Uri.parse('${apiService.baseUrl}/items/chats/$chatId');
            print('DEBUG: Chat details URL: $chatUrl');
            final chatResponse = await http.get(
              chatUrl,
              headers: {'Authorization': 'Bearer $token'},
            );
            print('DEBUG: Chat response status: ${chatResponse.statusCode}');
            print('DEBUG: Chat response body: ${chatResponse.body}');

            if (chatResponse.statusCode == 200) {
              final chatData = json.decode(chatResponse.body)['data'];
              print('DEBUG: Chat data: $chatData');
              String? avatarUrl;
              if (chatData['avatar'] != null) {
                avatarUrl =
                    "${apiService.baseUrl}/assets/${chatData['avatar']}";
                print('DEBUG: Avatar URL for chat $chatId: $avatarUrl');
              } else {
                print('DEBUG: No avatar for chat $chatId');
              }

              // Fetch all messages to calculate unseen count
              final messagesUrl = Uri.parse(
                '${apiService.baseUrl}/items/messages?filter[chat][_eq]=$chatId&sort=-timestamp',
              );
              print('DEBUG: Messages URL: $messagesUrl');
              final messagesResponse = await http.get(
                messagesUrl,
                headers: {'Authorization': 'Bearer $token'},
              );
              print(
                  'DEBUG: Messages response status: ${messagesResponse.statusCode}');
              print('DEBUG: Messages response body: ${messagesResponse.body}');

              int unseenCount = 0;
              String lastMessage = 'No messages yet';
              String lastMessageTime = '';
              DateTime? timestamp;

              if (messagesResponse.statusCode == 200) {
                final messagesData = json.decode(messagesResponse.body)['data'];
                print('DEBUG: Messages data for chat $chatId: $messagesData');

                // Calculate unseen count, accounting for locally marked messages
                unseenCount = messagesData
                    .where((msg) =>
                        !_locallyMarkedMessages.contains(msg['id']) &&
                        !(msg['seen_by'] ?? [])
                            .map((id) => id.toString())
                            .contains(userId))
                    .length;
                print(
                    'DEBUG: Unseen message count for chat $chatId: $unseenCount');

                if (messagesData.isNotEmpty) {
                  final latestMessage = messagesData[0];
                  print('DEBUG: Latest message: $latestMessage');
                  lastMessage = latestMessage['type'] == 'image'
                      ? 'Photo'
                      : latestMessage['type'] == 'audio'
                          ? 'Voice message'
                          : latestMessage['type'] == 'file'
                              ? 'File'
                              : latestMessage['text'] ?? 'No message ';
                  print('DEBUG: Last message content: $lastMessage');

                  if (latestMessage['timestamp'] != null) {
                    timestamp = DateTime.parse(latestMessage['timestamp'])
                        .add(Duration(hours: 3));
                    print('DEBUG: Message timestamp: $timestamp');

                    final DateTime now = DateTime.now();
                    if (timestamp!.day == now.day &&
                        timestamp.month == now.month &&
                        timestamp.year == now.year) {
                      lastMessageTime =
                          '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
                    } else {
                      lastMessageTime =
                          '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}';
                    }
                    print(
                        'DEBUG: Formatted last message time: $lastMessageTime');
                  } else {
                    print('DEBUG: No timestamp in latest message');
                  }
                } else {
                  print('DEBUG: No messages found for chat $chatId');
                  if (chatData['created_at'] != null) {
                    final creationDate = DateTime.parse(chatData['created_at'])
                        .add(Duration(hours: 3));
                    timestamp = creationDate;
                    print(
                        'DEBUG: Using chat creation date as timestamp: $timestamp');

                    final DateTime now = DateTime.now();
                    if (creationDate.day == now.day &&
                        creationDate.month == now.month &&
                        creationDate.year == now.year) {
                      lastMessageTime =
                          '${creationDate.hour.toString().padLeft(2, '0')}:${creationDate.minute.toString().padLeft(2, '0')}';
                    } else {
                      lastMessageTime =
                          '${creationDate.day.toString().padLeft(2, '0')}/${creationDate.month.toString().padLeft(2, '0')}';
                    }
                    print(
                        'DEBUG: Formatted creation date time: $lastMessageTime');
                  }
                }

                final chatModel = ChatModel(
                  id: chatId,
                  title: chatData['chat_title'] ?? 'Untitled Chat',
                  lastMessage: lastMessage,
                  lastMessageTime: lastMessageTime,
                  timestamp: timestamp,
                  chatCreationDate: chatData['created_at'] != null
                      ? DateTime.parse(chatData['created_at'])
                      : null,
                  avatarUrl: avatarUrl,
                  unseenCount: unseenCount,
                );
                print(
                    'DEBUG: Created ChatModel for chat $chatId: {id: ${chatModel.id}, title: ${chatModel.title}, unseenCount: ${chatModel.unseenCount}}');
                chatsWithMessages.add(chatModel);
              } else {
                print(
                    'DEBUG: Failed to fetch messages for chat $chatId: ${messagesResponse.body}');
              }
            } else {
              print(
                  'DEBUG: Failed to fetch chat details for chat $chatId: ${chatResponse.statusCode}');
            }
          } catch (e) {
            print('DEBUG: Error processing chat $chatId: $e');
          }
        }

        print('DEBUG: Sorting ${chatsWithMessages.length} chats');
        chatsWithMessages.sort((a, b) {
          if (a.timestamp != null && b.timestamp != null) {
            return b.timestamp!.compareTo(a.timestamp!);
          } else if (a.timestamp != null) {
            return -1;
          } else if (b.timestamp != null) {
            return 1;
          }
          return 0;
        });
        print('DEBUG: Chats sorted');

        if (!mounted) {
          print('DEBUG: Widget not mounted, skipping setState');
          return;
        }
        setState(() {
          _chats = chatsWithMessages;
          _filteredChats = chatsWithMessages;
          _loading = false;
          print('DEBUG: Updated state with ${_chats.length} chats');
          print('DEBUG: Chats in state: ${_chats.map((c) => {
                'id': c.id,
                'title': c.title,
                'unseenCount': c.unseenCount
              }).toList()}');
        });

        print('DEBUG: Successfully loaded ${_chats.length} chats');
      } catch (e) {
        print('DEBUG: Error fetching chats: $e');
        if (!mounted) {
          print('DEBUG: Widget not mounted, skipping error setState');
          return;
        }
        setState(() {
          _loading = false;
          _chats = [];
          _filteredChats = [];
          print('DEBUG: Error state updated: chats cleared');
        });
      }
    } finally {
      _isFetching = false;
      print('DEBUG: fetchChats completed, isFetching set to false');
    }
  }

  Future<List<int>> markMessagesAsSeen(int chatId) async {
    print('DEBUG: markMessagesAsSeen called for chat $chatId');
    List<int> markedMessageIds = [];
    try {
      final token = await apiService.getValidToken();

      // Fetch all messages to find unseen ones
      final messagesUrl = Uri.parse(
        '${apiService.baseUrl}/items/messages?filter[chat][_eq]=$chatId',
      );
      print('DEBUG: Messages URL for marking: $messagesUrl');
      final messagesResponse = await http.get(
        messagesUrl,
        headers: {'Authorization': 'Bearer $token'},
      );
      print(
          'DEBUG: Messages response status for marking: ${messagesResponse.statusCode}');
      print(
          'DEBUG: Messages response body for marking: ${messagesResponse.body}');

      if (messagesResponse.statusCode == 200) {
        final messagesData = json.decode(messagesResponse.body)['data'];
        print('DEBUG: Found ${messagesData.length} messages for chat $chatId');
        for (var message in messagesData) {
          final currentSeenBy =
              (message['seen_by'] ?? []).map((id) => id.toString()).toList();
          print(
              'DEBUG: Current seen_by for message ${message['id']}: $currentSeenBy');
          if (!currentSeenBy.contains(userId) &&
              !_locallyMarkedMessages.contains(message['id'])) {
            final messageId = message['id'];
            print('DEBUG: Marking message $messageId as seen for user $userId');
            // Temporary: Assume marked for UI
            markedMessageIds.add(messageId);
            _locallyMarkedMessages.add(messageId);
            // Comment out backend call until schema is fixed
            /*
            final updateUrl = Uri.parse('${apiService.baseUrl}/items/message_seen');
            final updateResponse = await http.post(
              updateUrl,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: json.encode({
                'message_id': messageId,
                'user_id': userId,
              }),
            );
            print('DEBUG: Update response for message $messageId: ${updateResponse.statusCode}');
            print('DEBUG: Update response body: ${updateResponse.body}');
            if (updateResponse.statusCode == 200 || updateResponse.statusCode == 201) {
              print('DEBUG: Successfully marked message $messageId as seen');
              markedMessageIds.add(messageId);
              _locallyMarkedMessages.add(messageId);
            } else {
              print('DEBUG: Failed to mark message $messageId as seen: ${updateResponse.statusCode}');
              print('DEBUG: Error details: ${updateResponse.body}');
            }
            */
          } else {
            print(
                'DEBUG: Message ${message['id']} already seen by user $userId or locally marked');
          }
        }
      } else {
        print(
            'DEBUG: Failed to fetch messages for marking: ${messagesResponse.statusCode}');
        print('DEBUG: Messages fetch error details: ${messagesResponse.body}');
      }
    } catch (e) {
      print('DEBUG: Error marking messages as seen: $e');
    }
    return markedMessageIds;
  }

  void filterChats(String query) {
    print('DEBUG: Filtering chats with query: $query');
    final filtered = _chats.where((chat) {
      return chat.title.toLowerCase().contains(query.toLowerCase());
    }).toList();
    print('DEBUG: Filtered ${filtered.length} chats');
    print('DEBUG: Filtered chats: ${filtered.map((c) => {
          'id': c.id,
          'title': c.title,
          'unseenCount': c.unseenCount
        }).toList()}');

    setState(() {
      _filteredChats = filtered;
      print('DEBUG: Updated filtered chats in state');
    });
  }

  Future<bool> _navigateToChatScreen(
      int chatId, String title, String? avatarUrl) async {
    if (!mounted) {
      print('DEBUG: Widget not mounted, skipping navigation to ChatScreen');
      return false;
    }
    try {
      print('DEBUG: Navigating to ChatScreen for chat $chatId');
      await Navigator.of(context, rootNavigator: true).push(
        PageTransition(
          type: PageTransitionType.fade,
          child: ChatScreen(
            chatId: chatId,
            chatName: title,
            initialAvatarUrl: avatarUrl,
          ),
        ),
      );
      // Refresh chats after returning
      if (mounted) {
        print('DEBUG: Returned from ChatScreen, refreshing chats');
        await fetchChats();
      }
      return true;
    } catch (e) {
      print('DEBUG: Navigation error: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
        'DEBUG: Building ChatListScreen, loading: $_loading, chats: ${_filteredChats.length}');
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.black, size: 20),
              onPressed: () {
                print('DEBUG: Back button pressed');
                Navigator.pop(context);
              },
            ),
          ],
        ),
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Chats',
          style: textStyleVersion2(fontSize: 22),
        ),
        backgroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
          backgroundColor: Color(0xff3F90C3),
          onPressed: () async {
            print(
                'DEBUG: Floating action button pressed, navigating to CreateChatScreen');
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreateChatScreen(
                  onEmailsCollected: (emails, file, isImage) {
                    print('DEBUG: Emails collected: $emails');
                  },
                ),
              ),
            );

            if (mounted) {
              print('DEBUG: Returned from CreateChatScreen, refreshing chats');
              await Future.delayed(Duration(milliseconds: 500));
              fetchChats();
            }
          },
          child: Image.asset(
            'assets/newChat.png',
            color: Colors.white,
            width: 30.w,
            height: 30.h,
            fit: BoxFit.contain,
          )),
      body: RefreshIndicator(
        backgroundColor: Colors.white,
        color: Color(0xff3F90C3),
        onRefresh: () async {
          print('DEBUG: Refresh indicator triggered');
          await fetchChats();
        },
        child: _loading
            ? ShimmerLoading()
            : Column(
                children: [
                  Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16.h, vertical: 8.w),
                      child: ChatTextForm(
                        hintText: 'Search by document name',
                        controller: _searchController,
                        prefixIcon: Icon(Icons.search),
                        prefixIconColor: Color(0xff1E1E1E),
                        containerColor: Color(0xffF0F4F8),
                      )),
                  Expanded(
                    child: _filteredChats.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Image.asset('assets/empty_chat.png'),
                                  SizedBox(height: 32.h),
                                  Text('You don\'t have chats yet',
                                      style: textStyleVersion2(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400)),
                                  SizedBox(height: 12.h),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Tap ',
                                          style: textStyleVersion2(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w400)),
                                      Image.asset(
                                        width: 25.w,
                                        height: 25.h,
                                        'assets/comment.png',
                                        color: PrimaryColors.maxUsed,
                                      ),
                                      Text(' to start chatting',
                                          style: textStyleVersion2(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w400)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredChats.length,
                            itemBuilder: (context, index) {
                              final chat = _filteredChats[index];
                              print(
                                  'DEBUG: Building MessageTile for chat ${chat.id}, title: ${chat.title}, unseenCount: ${chat.unseenCount}');
                              return SingleChildScrollView(
                                child: Column(
                                  children: [
                                    MessageTile(
                                      onTap: () async {
                                        print(
                                            'DEBUG: Tapped chat ${chat.id}, marking messages as seen');
                                        final markedMessageIds =
                                            await markMessagesAsSeen(chat.id);
                                        if (mounted) {
                                          // Update unseenCount locally
                                          setState(() {
                                            final chatIndex = _chats.indexWhere(
                                                (c) => c.id == chat.id);
                                            if (chatIndex != -1) {
                                              _chats[chatIndex] = ChatModel(
                                                id: _chats[chatIndex].id,
                                                title: _chats[chatIndex].title,
                                                lastMessage: _chats[chatIndex]
                                                    .lastMessage,
                                                lastMessageTime:
                                                    _chats[chatIndex]
                                                        .lastMessageTime,
                                                timestamp:
                                                    _chats[chatIndex].timestamp,
                                                chatCreationDate:
                                                    _chats[chatIndex]
                                                        .chatCreationDate,
                                                avatarUrl:
                                                    _chats[chatIndex].avatarUrl,
                                                unseenCount: _chats[chatIndex]
                                                        .unseenCount -
                                                    markedMessageIds.length,
                                              );
                                              _filteredChats =
                                                  List.from(_chats);
                                            }
                                          });
                                          await _navigateToChatScreen(
                                            chat.id,
                                            chat.title,
                                            chat.avatarUrl,
                                          );
                                        }
                                      },
                                      name: chat.title,
                                      message: chat.lastMessage!,
                                      timestamp: chat.lastMessageTime!,
                                      avatarUrl: chat.avatarUrl,
                                      unseenCount: chat.unseenCount,
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 30.w),
                                      child: Divider(
                                        color: Color(0xFFEAECF0),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class MessageTile extends StatelessWidget {
  final String name;
  final String message;
  final String timestamp;
  final String? avatarUrl;
  final VoidCallback? onTap;
  final int unseenCount;

  const MessageTile({
    Key? key,
    required this.name,
    required this.message,
    required this.timestamp,
    this.avatarUrl,
    this.onTap,
    this.unseenCount = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print(
        'DEBUG: Building MessageTile - name: $name, unseenCount: $unseenCount');
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: GestureDetector(
        onTap: avatarUrl != null
            ? () {
                print('DEBUG: Avatar tapped for $name');
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: EdgeInsets.zero,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        InteractiveViewer(
                          panEnabled: true,
                          boundaryMargin: EdgeInsets.all(20),
                          minScale: 0.5,
                          maxScale: 4,
                          child: Image.network(
                            avatarUrl!,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              print('DEBUG: Loading avatar for $name');
                              return Container(
                                width: MediaQuery.of(context).size.width,
                                height:
                                    MediaQuery.of(context).size.height * 0.4,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              print(
                                  'DEBUG: Error loading avatar for $name: $error');
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.error, color: Colors.white),
                                  TextButton(
                                    onPressed: () {
                                      print('DEBUG: Closing avatar dialog');
                                      Navigator.pop(context);
                                    },
                                    child: Text('Close',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: 40,
                          right: 20,
                          child: IconButton(
                            icon: Icon(Icons.close,
                                color: Colors.white, size: 30),
                            onPressed: () {
                              print(
                                  'DEBUG: Closing avatar dialog via close button');
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            : null,
        child: CircleAvatar(
          backgroundColor: Color(0xffF0F8FF),
          radius: 24,
          child: ClipOval(
              child: avatarUrl != null
                  ? Image.network(
                      avatarUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        print(
                            'DEBUG: Loading avatar for $name in CircleAvatar');
                        return Center(
                          child: CircularProgressIndicator(
                            color: Color(0xff3F90C3),
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        print(
                            'DEBUG: Error loading CircleAvatar for $name: $error');
                        return Icon(
                          Icons.group,
                          color: Color(0xff3F90C3),
                        );
                      },
                    )
                  : Icon(
                      Icons.group,
                      color: Color(0xff3F90C3),
                    )),
        ),
      ),
      title: Padding(
        padding: EdgeInsets.only(bottom: 2.h),
        child: Row(
          children: [
            Flexible(
              child: Text(name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: textStyleVersion2(
                    color: Colors.black,
                    fontSize: 16,
                  )),
            ),
            const Spacer(),
            Text(timestamp,
                style: textStyleVersion2(
                    color: Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: textStyleVersion2(color: Colors.black87, fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (unseenCount > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Color(0xff3F90C3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unseenCount.toString(),
                style: textStyleVersion2(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
