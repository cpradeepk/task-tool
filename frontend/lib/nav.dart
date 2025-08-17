import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_login.dart';

class AppNav extends StatelessWidget implements PreferredSizeWidget {
  const AppNav({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Task Tool'),
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      actions: [
        TextButton(
          onPressed: () => context.go('/projects'),
          child: const Text('Projects', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
        ),
        TextButton(
          onPressed: () => context.go('/profile'),
          child: const Text('Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
        ),
        IconButton(
          onPressed: () => _showAdminLogin(context),
          icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
          tooltip: 'Admin Login',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _showAdminLogin(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AdminLoginDialog(
        onSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Admin login successful')),
          );
        },
      ),
    );
  }
}

