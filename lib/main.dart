import 'package:flutter/material.dart';

void main() {
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
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Memory Stack', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text('Solve once. Review on schedule. Never forget.'),
            ],
          ),
        ),
      ),
    );
  }
}
