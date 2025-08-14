import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppNav extends StatelessWidget implements PreferredSizeWidget {
  const AppNav({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Task Tool'),
      actions: [
        TextButton(onPressed: () => context.go('/projects'), child: const Text('Projects', style: TextStyle(color: Colors.white))),
        TextButton(onPressed: () => context.go('/profile'), child: const Text('Profile', style: TextStyle(color: Colors.white))),
      ],
    );
  }
}

