import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool _isSending = false;
  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    setState(() {
      _isSending = true;
    });

    final User? user = _auth.currentUser;
    if (user != null) {
      final String currentUserId = user.uid;
      final String recipientId = widget.recipientId;

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
          'lastMessage': _messageController.text.trim(),
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
        });

        await conversationRef.collection('messages').add({
          'content': _messageController.text.trim(),
          'senderId': currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        // Create a new conversation document
        conversationRef = await _firestore.collection('conversations').add({
          'users': [currentUserId, recipientId],
          'lastMessage': _messageController.text.trim(),
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
        });

        // Add subcollection 'messages' within the new conversation document
        await conversationRef.collection('messages').add({
          'content': _messageController.text.trim(),
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

      _messageController.clear();
    }

    setState(() {
      _isSending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(widget.recipientPhotoUrl),
        ),
        title: Text(widget.recipientName),
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
                  return Center(child: CircularProgressIndicator());
                }

                final List<DocumentSnapshot> conversations =
                    snapshot.data!.docs.where((doc) {
                  List<dynamic> users = doc['users'];
                  return users.contains(widget.recipientId);
                }).toList();

                if (conversations.isEmpty) {
                  return Center(child: Text('Start Conversation'));
                }

                final conversationRef = conversations.first.reference;

                return StreamBuilder<QuerySnapshot>(
                  stream: conversationRef
                      .collection('messages')
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    final List<DocumentSnapshot> docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return Center(child: Text('Start Conversation'));
                    }

                    return ListView.builder(
                      reverse: false,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final bool isSender =
                            data['senderId'] == _auth.currentUser?.uid;

                        return Align(
                          alignment: isSender
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Card(
                            color: isSender ? Colors.blue : Colors.grey[200],
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
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
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    data['timestamp'] != null
                                        ? (data['timestamp'] as Timestamp)
                                            .toDate()
                                            .toString()
                                        : 'No timestamp',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isSender
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                ],
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
                  child: TextField(
                    controller: _messageController,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
