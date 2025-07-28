import 'package:flutter/material.dart';

class SimpleProjectsScreen extends StatelessWidget {
  const SimpleProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Projects Screen',
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 8),
            Text('Coming soon...'),
          ],
        ),
      ),
    );
  }
}