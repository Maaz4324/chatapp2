import 'package:chatapp2/pages/search.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  Future<List<DocumentSnapshot>>? _friendsFuture;

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
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
    await _auth.signOut();
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
        backgroundColor: Colors.white,
        elevation: 0,
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
          decoration: BoxDecoration(
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
                  return CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Icon(Icons.error);
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Name: ${userData['displayName']}',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: "HelveticaNeue"),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Email: ${userData['email']}',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic,
                                    fontFamily: "HelveticaNeue"),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Joined: ${createdAt != null ? DateFormat.yMMMd().format(createdAt) : 'N/A'}',
                                style: TextStyle(
                                    fontSize: 16, fontFamily: "HelveticaNeue"),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'logout',
                          child: Text('Sign out'),
                        ),
                      ];
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircleAvatar(
                        backgroundImage: NetworkImage(user.photoURL ?? ''),
                        radius: 20,
                      ),
                    ),
                  );
                } else {
                  return Icon(Icons.error);
                }
              },
            ),
        ],
      ),
      body: Container(
        color: Color(0xFFE0E0E0), // Greyish white background
        child: FutureBuilder<List<DocumentSnapshot>>(
          future: _friendsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error fetching friends'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text('No friends found'));
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
                        margin:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          border: Border.all(
                            color: Colors.black,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              offset: Offset(5, 5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                NetworkImage(data['photoURL'] ?? ''),
                          ),
                          title: Text(
                            data['displayName'] ?? 'No Name',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            lastMessage,
                            style: TextStyle(fontFamily: "HelveticaNeue"),
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
        child: Icon(Icons.add),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.black, width: 3),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
