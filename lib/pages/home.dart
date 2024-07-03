import 'package:chatapp2/pages/search.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    print("Friends--------${user}");
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

  void _signOut(BuildContext context) async {
    await _auth.signOut();
    try {
      // ignore: use_build_context_synchronously
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      print("Error signing out: $e");
      // Optionally, show an error message to the user
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Company Name',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (user != null)
            PopupMenuButton<String>(
              onSelected: (String value) {
                if (value == 'logout') {
                  _signOut(context);
                }
              },
              itemBuilder: (BuildContext context) {
                return [
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Text('Sign out'),
                  ),
                ];
              },
              child: CircleAvatar(
                backgroundImage: NetworkImage(user.photoURL ?? ''),
                radius: 20,
              ),
            ),
        ],
      ),
      body: FutureBuilder<List<DocumentSnapshot>>(
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

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(data['photoURL'] ?? ''),
                  ),
                  title: Text(data['displayName'] ?? 'No Name'),
                  subtitle: Text(data['email'] ?? 'No Email'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          recipientId: friendsDocs[index].id,
                          recipientName: data['displayName'] ?? 'No Name',
                          recipientPhotoUrl: data['photoURL'] ?? '',
                        ),
                      ),
                    );
                  },
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SearchFriendsPage()),
          );
          _fetchFriends(); // Refresh friends list after returning from the search page
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
