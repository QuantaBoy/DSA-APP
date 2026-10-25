import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_page.dart';
import 'screens/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MemoryStackApp());
}

const brand = Color(0xFF6C4EF5);

class MemoryStackApp extends StatelessWidget {
  const MemoryStackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Stack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: brand),
      darkTheme: ThemeData(colorSchemeSeed: brand, brightness: Brightness.dark),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snapshot.data == null ? const LoginPage() : HomePage(user: snapshot.data!);
        },
      ),
    );
  }
}
