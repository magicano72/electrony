import 'dart:convert';

import 'package:Electrony/custom/chat_text_form.dart';
import 'package:Electrony/custom/shimmer_loading.dart';
import 'package:Electrony/networking/api_services.dart';
import 'package:Electrony/screens/chat/models/chat_list_model.dart';
import 'package:Electrony/theming/colors.dart';
import 'package:Electrony/theming/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

class ChatListSelectionScreen extends StatefulWidget {
  final String? documentId;

  const ChatListSelectionScreen({Key? key, this.documentId}) : super(key: key);

  @override
  State<ChatListSelectionScreen> createState() =>
      _ChatListSelectionScreenState();
}

class _ChatListSelectionScreenState extends State<ChatListSelectionScreen> {
  List<ChatModel> _chats = [];
  List<ChatModel> _filteredChats = [];
  bool _loading = true;
  int? _selectedChatId;
  final TextEditingController _searchController = TextEditingController();

  final apiService = AuthApiService(baseUrl: dotenv.env['API_BASE_URL'] ?? '');

  @override
  void initState() {
    super.initState();
    fetchChats();

    _searchController.addListener(() {
      filterChats(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void filterChats(String query) {
    final filtered = _chats.where((chat) {
      return chat.title.toLowerCase().contains(query.toLowerCase());
    }).toList();

    setState(() {
      _filteredChats = filtered;
    });
  }

  Future<void> fetchChats() async {
    try {
      setState(() {
        _loading = true;
      });

      final token = await apiService.getValidToken();

      final String? userId = JwtDecoder.decode(token)['id'];

      final chatParticipantsUrl = Uri.parse(
        '${apiService.baseUrl}/items/chat_participants?filter[user_id][_eq]=$userId&fields=chat.id,chat.chat_title,chat.avatar,chat.related_document',
      );

      final chatParticipantsResponse = await http.get(
        chatParticipantsUrl,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (chatParticipantsResponse.statusCode != 200) {
        throw Exception('Failed to load chat participants');
      }

      final responseData = json.decode(chatParticipantsResponse.body);
      final List<dynamic> participantsData = responseData['data'];

      final chatIds = participantsData
          .where((e) => e['chat'] != null)
          .map<int>((e) => e['chat']['id'] as int)
          .toList();

      final List<ChatModel> chats = [];

      for (final chatId in chatIds) {
        final chatUrl = Uri.parse('${apiService.baseUrl}/items/chats/$chatId');
        final chatResponse = await http.get(
          chatUrl,
          headers: {'Authorization': 'Bearer $token'},
        );

        if (chatResponse.statusCode == 200) {
          final chatData = json.decode(chatResponse.body)['data'];
          String? avatarUrl;
          if (chatData['avatar'] != null) {
            avatarUrl = "${apiService.baseUrl}/assets/${chatData['avatar']}";
          }

          chats.add(ChatModel(
            id: chatId,
            title: chatData['chat_title'] ?? 'Untitled Chat',
            avatarUrl: avatarUrl,
            relatedDocument:
                chatData['related_document'], // Add related document
          ));
        }
      }

      setState(() {
        _chats = chats;
        _filteredChats = chats;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      print('Error fetching chats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Select Chat',
          style: textStyleVersion2(fontSize: 22),
        ),
        actions: [
          if (_selectedChatId != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context, _selectedChatId);
              },
              child: Text(
                'Select',
                style: textStyleVersion2(
                  fontSize: 18,
                  color: PrimaryColors.maxUsed,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ChatTextForm(
                hintText: 'Search by document name',
                controller: _searchController,
                prefixIcon: Icon(Icons.search),
                prefixIconColor: Color(0xff1E1E1E),
                containerColor: Color(0xffF0F4F8),
              )),
          SizedBox(
            height: 16.h,
          ),
          Expanded(
            child: _loading
                ? ShimmerLoading()
                : _filteredChats.isEmpty
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
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredChats.length,
                        itemBuilder: (context, index) {
                          final chat = _filteredChats[index];
                          return Column(
                            children: [
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Color(0xffF0F8FF),
                                  radius: 24,
                                  child: chat.avatarUrl != null
                                      ? ClipOval(
                                          child: Image.network(
                                            chat.avatarUrl!,
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Icon(
                                                Icons.group,
                                                color: Color(0xff3F90C3),
                                              );
                                            },
                                          ),
                                        )
                                      : Icon(
                                          Icons.group,
                                          color: Color(0xff3F90C3),
                                        ),
                                ),
                                title: Text(chat.title,
                                    style: textStyleVersion2(
                                      color: Colors.black,
                                      fontSize: 16,
                                    )),
                                trailing: Theme(
                                  data: Theme.of(context).copyWith(
                                    radioTheme: RadioThemeData(
                                      fillColor: MaterialStateProperty
                                          .resolveWith<Color>((states) {
                                        if (states
                                            .contains(MaterialState.selected)) {
                                          return PrimaryColors
                                              .maxUsed; // Selected color
                                        }
                                        return Colors.grey; // Unselected color
                                      }),
                                      overlayColor: MaterialStateProperty
                                          .resolveWith<Color>((states) {
                                        if (states
                                            .contains(MaterialState.hovered)) {
                                          return PrimaryColors.maxUsed
                                              .withOpacity(0.1);
                                        }
                                        return Colors.transparent;
                                      }),
                                    ),
                                  ),
                                  child: Radio<int>(
                                    value: chat.id,
                                    groupValue: _selectedChatId,
                                    onChanged: chat.relatedDocument != null
                                        ? null
                                        : (int? value) {
                                            setState(() {
                                              _selectedChatId = value;
                                            });
                                          },
                                  ),
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedChatId = chat.id;
                                  });
                                },
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 30.w),
                                child: Divider(
                                  color: Color(0xFFEAECF0),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
