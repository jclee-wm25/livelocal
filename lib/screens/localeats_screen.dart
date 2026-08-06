import 'package:flutter/material.dart';

class LocalEatsScreen extends StatelessWidget {
  const LocalEatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LocalEats'),
      ),
      body: const Center(
        child: Text(
          'Module 3: LocalEats (Pending Implementation)',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }
}
