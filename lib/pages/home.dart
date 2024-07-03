import 'package:RickRoll/pages/search.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'chat.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  Future<List<DocumentSnapshot>>? _friendsFuture;

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  void _showGifPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFDAF5F0),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.black, width: 3),
          ),
          content: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  offset: const Offset(3, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Image.network(
              'https://media1.tenor.com/m/x8v1oNUOmg4AAAAd/rickroll-roll.gif',
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  Future<void> _fetchFriends() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        List<dynamic> friends = userDoc['friends'] ?? [];
        if (friends.isNotEmpty) {
          QuerySnapshot friendsQuery = await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: friends)
              .get();
          setState(() {
            _friendsFuture = Future.value(friendsQuery.docs);
          });
        } else {
          setState(() {
            _friendsFuture = Future.value([]);
          });
        }
      } else {
        // Handle case where document does not exist
        setState(() {
          _friendsFuture = Future.value([]);
        });
      }
    } else {
      setState(() {
        _friendsFuture = Future.value([]);
      });
    }
  }

  Future<String?> _getLastMessage(String friendId) async {
    User? user = _auth.currentUser;
    if (user != null) {
      QuerySnapshot conversationQuery = await _firestore
          .collection('conversations')
          .where('users', arrayContains: user.uid)
          .get();
      for (var doc in conversationQuery.docs) {
        List<dynamic> users = doc['users'];
        if (users.contains(friendId)) {
          return doc['lastMessage'];
        }
      }
    }
    return null;
  }

  void _signOut(BuildContext context) async {
    // Clear the FirebaseAuth session
    await _auth.signOut();

    // Clear the GoogleSignIn session
    await _googleSignIn.disconnect();
    try {
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      print("Error signing out: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFDAF5F0),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => _showGifPopup(context),
            child: Container(
              padding: const EdgeInsets.all(3), // Border width
              decoration: BoxDecoration(
                color: Color(0xFFFF6B6B), // Border color
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    offset: const Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  'https://media1.tenor.com/m/x8v1oNUOmg4AAAAd/rickroll-roll.gif',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
        title: const Text(
          'RickRoll',
          style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 24,
              fontFamily: "HelveticaNeue"),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.black, width: 3),
            ),
          ),
        ),
        actions: [
          if (user != null)
            FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(user.uid).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return const Icon(Icons.error);
                } else if (snapshot.hasData && snapshot.data != null) {
                  var userData = snapshot.data!.data() as Map<String, dynamic>;

                  var createdAt;
                  if (userData['createdAt'] != null &&
                      userData['createdAt'] is Timestamp) {
                    createdAt = (userData['createdAt'] as Timestamp).toDate();
                  }

                  return PopupMenuButton<String>(
                    onSelected: (String value) {
                      if (value == 'logout') {
                        _signOut(context);
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return [
                        PopupMenuItem<String>(
                          value: 'info',
                          enabled: false,
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDAF5F0),
                              border: Border.all(color: Colors.black, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  offset: const Offset(3, 3),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Name: ${userData['displayName']}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: "HelveticaNeue",
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Email: ${userData['email']}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic,
                                    fontFamily: "HelveticaNeue",
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Joined: ${createdAt != null ? DateFormat.yMMMd().format(createdAt) : 'N/A'}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontFamily: "HelveticaNeue",
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'logout',
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Color(0xFFFF6B6B),
                              border: Border.all(color: Colors.black, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  offset: const Offset(3, 3),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: const Text(
                              'Sign out',
                              style: TextStyle(
                                fontFamily: "HelveticaNeue",
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ];
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        padding: const EdgeInsets.all(3), // Border width
                        decoration: BoxDecoration(
                          color: Color(0xFFFF6B6B), // Border color
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
                          backgroundImage: NetworkImage(user.photoURL ?? ''),
                          radius: 20,
                        ),
                      ),
                    ),
                  );
                } else {
                  return const Icon(Icons.error);
                }
              },
            ),
        ],
      ),
      body: Container(
        color: const Color(0xFFE0E0E0), // Greyish white background
        child: FutureBuilder<List<DocumentSnapshot>>(
          future: _friendsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return const Center(child: Text('Error fetching friends'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No friends found'));
            } else {
              List<DocumentSnapshot> friendsDocs = snapshot.data!;
              return ListView.builder(
                itemCount: friendsDocs.length,
                itemBuilder: (context, index) {
                  Map<String, dynamic> data =
                      friendsDocs[index].data()! as Map<String, dynamic>;

                  return FutureBuilder<String?>(
                    future: _getLastMessage(friendsDocs[index].id),
                    builder: (context, snapshot) {
                      String lastMessage = snapshot.data ?? 'No messages yet';
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA388EF),
                          border: Border.all(
                            color: Colors.black,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              offset: const Offset(5, 5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: EdgeInsets.all(2), // Border width
                            decoration: BoxDecoration(
                              color: Colors.black, // Border color
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              backgroundImage:
                                  NetworkImage(data['photoURL'] ?? ''),
                              radius: 20,
                            ),
                          ),
                          title: Text(
                            data['displayName'] ?? 'No Name',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: "HelveticaNeue",
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            lastMessage,
                            style: const TextStyle(
                                fontFamily: "HelveticaNeue",
                                color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatPage(
                                  recipientId: friendsDocs[index].id,
                                  recipientName:
                                      data['displayName'] ?? 'No Name',
                                  recipientPhotoUrl: data['photoURL'] ?? '',
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              );
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SearchFriendsPage()),
          );
          _fetchFriends();
        },
        child: const Icon(Icons.add),
        backgroundColor: Color(0xFFFF6B6B),
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.black, width: 3),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
