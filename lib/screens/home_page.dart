import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Temporary home screen. The real Today screen replaces it in Layer 4.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final name = user.displayName?.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Stack'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Hi ${name == null || name.isEmpty ? user.email ?? 'there' : name.split(' ').first}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
