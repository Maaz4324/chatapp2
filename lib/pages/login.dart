import 'package:RickRoll/pages/home.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:google_sign_in/google_sign_in.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  User? _user;

  @override
  void initState() {
    super.initState();
    _auth.authStateChanges().listen((event) {
      setState(() {
        _user = event;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _user != null ? const Home() : _googleSignInButton(),
    );
  }

  Widget _googleSignInButton() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue,
            Colors.green,
          ],
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFDAF5F0),
          elevation: 0,
          title: const Text(
            'Login Page',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(4.0),
            child: Container(
              color: Colors.black,
              height: 3.0,
            ),
          ),
        ),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.yellow,
              border: Border.all(
                color: Colors.black,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  offset: Offset(10, 10),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'RickRoll welcomes you!',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Image.network(
                  'https://media1.tenor.com/m/x8v1oNUOmg4AAAAd/rickroll-roll.gif', // Replace with your image URL
                  width: 100, // Adjust width as needed
                  height: 100, // Adjust height as needed
                  fit: BoxFit
                      .cover, // Adjust the fit type according to your preference
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: SignInButton(
                    Buttons.google,
                    text: "Sign up with Google",
                    onPressed: _handleGoogleSignIn,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.black, width: 3),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<User?> _handleGoogleSignIn() async {
    try {
      // Ensure GoogleSignIn prompts the account picker
      await _googleSignIn.signOut();
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // The user canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      // Sign in to Firebase with the new credential
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        storeInFirestore(userCredential.user!);
      }
      return userCredential.user;
    } catch (e) {
      print(e);
      return null;
    }
  }

  void storeInFirestore(User user) async {
    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userSnapshot = await userDoc.get();

    // Retrieve displayName from providerData if it's null in the user object
    String? displayName = user.displayName;
    if (displayName == null || displayName.isEmpty) {
      for (var profile in user.providerData) {
        if (profile.displayName != null && profile.displayName!.isNotEmpty) {
          displayName = profile.displayName;
          break;
        }
      }
    }

    if (!userSnapshot.exists) {
      await userDoc.set({
        'uid': user.uid,
        'displayName': displayName,
        'email': user.email,
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'friends': [],
      });
    }
  }
}
