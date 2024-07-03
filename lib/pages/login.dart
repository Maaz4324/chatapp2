import 'package:chatapp2/pages/home.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_button/sign_in_button.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login page'),
      ),
      body: Center(
        child: SizedBox(
          height: 50,
          child: SignInButton(
            Buttons.google,
            text: "Sign up with google",
            onPressed: _handleGoogleSignIn,
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      GoogleAuthProvider _googleAuthProvider = GoogleAuthProvider();

      UserCredential userCredential =
          await _auth.signInWithProvider(_googleAuthProvider);
      print(userCredential.user);
      User? user = userCredential.user;

      if (user != null) {
        print(user);
        //   // Store user data in Firestore
        storeInFirestore(user);
      }
    } catch (e) {
      print(e);
    }
  }

  void storeInFirestore(User user) async {
    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    print(userDoc);
    final userSnapshot = await userDoc.get();
    print(userSnapshot);
    if (!userSnapshot.exists) {
      // If the user document does not exist, create it
      userDoc.set({
        'uid': user.uid,
        'displayName': user.displayName,
        'email': user.email,
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
