import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final String recipientPhotoUrl;

  const ChatPage({
    Key? key,
    required this.recipientId,
    required this.recipientName,
    required this.recipientPhotoUrl,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final DateFormat timeFormat = DateFormat('h:mm a');
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final String message = _messageController.text.trim();
    _messageController.clear(); // Clear the text field immediately

    setState(() {
      _isSending = true;
    });

    final User? user = _auth.currentUser;
    if (user != null) {
      final String currentUserId = user.uid;
      final String recipientId = widget.recipientId;

      // Perform Firestore operations in the background
      Future<void> sendMessageToFirestore() async {
        // Check if a conversation already exists
        QuerySnapshot existingConversations = await _firestore
            .collection('conversations')
            .where('users', arrayContains: currentUserId)
            .get();

        DocumentReference? conversationRef;

        if (existingConversations.docs.isNotEmpty) {
          // Check if any of the existing conversations include the recipientId
          for (var doc in existingConversations.docs) {
            List<dynamic> users = doc['users'];
            if (users.contains(recipientId)) {
              conversationRef = doc.reference;
              break;
            }
          }
        }

        if (conversationRef != null) {
          // Conversation exists, update the last message and add new message to the messages subcollection
          await conversationRef.update({
            'lastMessage': message,
            'lastMessageTimestamp': FieldValue.serverTimestamp(),
          });

          await conversationRef.collection('messages').add({
            'content': message,
            'senderId': currentUserId,
            'timestamp': FieldValue.serverTimestamp(),
          });
        } else {
          // Create a new conversation document
          conversationRef = await _firestore.collection('conversations').add({
            'users': [currentUserId, recipientId],
            'lastMessage': message,
            'lastMessageTimestamp': FieldValue.serverTimestamp(),
          });

          // Add subcollection 'messages' within the new conversation document
          await conversationRef.collection('messages').add({
            'content': message,
            'senderId': currentUserId,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }

        // Update the user's document to add the recipient to the friends array
        await _firestore.collection('users').doc(currentUserId).update({
          'friends': FieldValue.arrayUnion([recipientId]),
        });
        await _firestore.collection('users').doc(recipientId).update({
          'friends': FieldValue.arrayUnion([currentUserId]),
        });
      }

      await sendMessageToFirestore();

      _scrollToBottom();
    }

    setState(() {
      _isSending = false;
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        leadingWidth: 40,
        leading: Padding(
          padding: const EdgeInsets.only(
            left: 12.0,
            top: 12.0,
            bottom: 8.0, // Added bottom padding
          ),
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: const IconTheme(
              data: IconThemeData(
                size: 30, // Increased size for a thicker appearance
                color: Colors.black,
              ),
              child: const Icon(Icons.arrow_back),
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 0, 0, 0), // Border color
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    offset: const Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: CircleAvatar(
                backgroundImage: NetworkImage(widget.recipientPhotoUrl),
                radius: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.recipientName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: "HelveticaNeue",
                color: Colors.black,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Container(
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.more_vert, color: Colors.black),
            ),
          ),
        ],
        elevation: 0,
        backgroundColor: const Color(0xFFDAF5F0),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.black, width: 2.8),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('conversations')
                  .where('users', arrayContains: _auth.currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final List<DocumentSnapshot> conversations =
                    snapshot.data!.docs.where((doc) {
                  List<dynamic> users = doc['users'];
                  return users.contains(widget.recipientId);
                }).toList();

                if (conversations.isEmpty) {
                  return const Center(
                    child: Text(
                      'Start Conversation',
                      style: TextStyle(
                        fontSize: 24,
                        fontFamily: "HelveticaNeue",
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  );
                }

                final conversationRef = conversations.first.reference;

                return StreamBuilder<QuerySnapshot>(
                  stream: conversationRef
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final List<DocumentSnapshot> docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'Start Conversation',
                          style: TextStyle(
                            fontSize: 24,
                            fontFamily: "HelveticaNeue",
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      );
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom();
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final bool isSender =
                            data['senderId'] == _auth.currentUser?.uid;

                        return Align(
                          alignment: isSender
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 70),
                            child: Card(
                              color: isSender
                                  ? const Color(
                                      0xFFFF6B6B) // Sender's message color
                                  : const Color(
                                      0xFFBAFCA2), // Recipient's message color
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(
                                    color: Colors.black, width: 2),
                              ),
                              elevation: 0,
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  crossAxisAlignment: isSender
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['content'],
                                      style: TextStyle(
                                        color: isSender
                                            ? Colors.white
                                            : Colors.black,
                                        fontFamily: "HelveticaNeue",
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12, // Reduced font size
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      data['timestamp'] != null
                                          ? timeFormat.format(
                                              (data['timestamp'] as Timestamp)
                                                  .toDate())
                                          : 'No timestamp',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontFamily: "HelveticaNeue",
                                        color: isSender
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFDAF5F0),
                      border: Border.all(color: Colors.black, width: 2),
                      borderRadius: BorderRadius.circular(30.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          offset: const Offset(4, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _messageController,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          color: Colors.black.withOpacity(0.6),
                          fontFamily: "HelveticaNeue",
                          fontWeight: FontWeight.bold,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide:
                              const BorderSide(color: Colors.black, width: 8),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFDAF5F0),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 20), // Increased vertical padding
                      ),
                      style: const TextStyle(
                        color: Colors.black,
                        fontFamily: "HelveticaNeue",
                        fontWeight: FontWeight.bold,
                        fontSize: 16, // Reduced font size
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA7DBD8), // Updated send button color
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black, // Border color
                      width: 2.8, // Border width
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        offset: const Offset(4, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
