import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat.dart';

class SearchFriendsPage extends StatefulWidget {
  const SearchFriendsPage({super.key});

  @override
  _SearchFriendsPageState createState() => _SearchFriendsPageState();
}

class _SearchFriendsPageState extends State<SearchFriendsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search Friends',
          style: TextStyle(
            fontFamily: "HelveticaNeue",
            color: Colors.black,
          ),
        ),
        backgroundColor: const Color(0xFFF4D738),
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.black, width: 3),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFDAF5F0),
                border: Border.all(color: Colors.black, width: 3),
                borderRadius: BorderRadius.circular(30.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    offset: const Offset(5, 5),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(
                    color: Colors.black.withOpacity(0.6),
                    fontFamily: "HelveticaNeue",
                  ),
                  prefixIcon: const Icon(Icons.search, color: Colors.black),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                ),
                style: const TextStyle(
                  color: Colors.black,
                  fontFamily: "HelveticaNeue",
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim();
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: _searchQuery.isEmpty
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF90EE90),
                        border: Border.all(color: Colors.black, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            offset: const Offset(5, 5),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: const Text(
                        'Start searching for friends',
                        style: TextStyle(
                          color: Colors.black,
                          fontFamily: "HelveticaNeue",
                        ),
                      ),
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('users').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator(
                          backgroundColor: Colors.black,
                        ));
                      }

                      List<DocumentSnapshot> docs = snapshot.data!.docs;

                      // Filter users based on search query and exclude current user
                      List<DocumentSnapshot> filteredDocs = docs.where((doc) {
                        Map<String, dynamic> data =
                            doc.data() as Map<String, dynamic>;
                        String displayName = data['displayName'] ?? '';
                        return displayName
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()) &&
                            doc.id != user?.uid;
                      }).toList();

                      return ListView.builder(
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          Map<String, dynamic> data = filteredDocs[index]
                              .data()! as Map<String, dynamic>;

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
                                  color: Colors.black.withOpacity(0.5),
                                  offset: const Offset(5, 5),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: ListTile(
                              leading: Container(
                                padding:
                                    const EdgeInsets.all(2), // Border width
                                decoration: BoxDecoration(
                                  color: Colors.black, // Border color
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
                                  color: Colors.black,
                                ),
                              ),
                              subtitle: Text(
                                data['email'] ?? 'No Email',
                                style: const TextStyle(
                                  fontFamily: "HelveticaNeue",
                                  color: Colors.black,
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatPage(
                                      recipientId: filteredDocs[index].id,
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
                  ),
          ),
        ],
      ),
    );
  }
}
