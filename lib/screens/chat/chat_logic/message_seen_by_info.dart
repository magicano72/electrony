import 'package:Electrony/networking/api_services.dart';
import 'package:Electrony/screens/chat/models/chat_model.dart';
import 'package:Electrony/theming/style.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MessageSeenScreen extends StatelessWidget {
  final ChatMessage message;
  final AuthApiService apiService;

  const MessageSeenScreen({
    Key? key,
    required this.message,
    required this.apiService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: Color(0xffF0F4F8),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Seen by',
          style: textStyleVersion2(color: Color(0xff2D3748)),
        ),
      ),
      body: Column(
        children: [
          // Display original message at the top
          Container(
            padding: EdgeInsets.all(16),
            color: Color(0xffF9FAFC),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Message',
                        style: textStyleVersion2(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Color(0xff6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      if (message.type == 'text')
                        Text(
                          message.text ?? '',
                          style: textStyleVersion2(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            color: Color(0xff1F2937),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (message.type == 'image')
                        Text('📷 Image', style: TextStyle(fontSize: 16)),
                      if (message.type == 'file')
                        Text(
                            '📄 File: ${message.text?.substring(2) ?? "Document"}',
                            style: TextStyle(fontSize: 16)),
                      if (message.type == 'audio')
                        Text('🎤 Voice message',
                            style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: Color(0xffE5E7EB)),

          // List of people who've seen the message
          Expanded(
            child: message.seenBy.isEmpty
                ? Center(
                    child: Text(
                      'No one has seen this message yet',
                      style: TextStyle(
                        color: Color(0xff6B7280),
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: message.seenBy.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 1,
                      indent: 72,
                      color: Color(0xffE5E7EB),
                    ),
                    itemBuilder: (context, index) {
                      final seenItem = message.seenBy[index];
                      final adjustedTimestamp =
                          seenItem.seenAt.add(Duration(hours: 3));
                      final formattedTime =
                          DateFormat('h:mm a, MMM d').format(adjustedTimestamp);

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: seenItem.user.avatar != null
                              ? NetworkImage(
                                  "${apiService.baseUrl}/assets/${seenItem.user.avatar}")
                              : null,
                          child: seenItem.user.avatar == null
                              ? Text(
                                  seenItem.user.firstName[0],
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.black54),
                                )
                              : null,
                        ),
                        title: Text(
                          seenItem.user.fullName,
                          style: textStyleVersion2(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Seen at $formattedTime',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xff6B7280),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
