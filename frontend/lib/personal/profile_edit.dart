import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../modern_layout.dart';
import '../theme/theme_provider.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _telegramController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _bioController = TextEditingController();
  
  late TabController _tabController;
  bool _isLoading = false;
  bool _emailNotifications = true;
  bool _pushNotifications = false;
  String _timezone = 'Asia/Kolkata'; // Default to IST
  String _language = 'English';
  String _selectedTheme = 'Blue';
  String _selectedFont = 'Default';
  String? _avatarPath;

  final List<String> _timezones = [
    'Asia/Kolkata', // Indian Standard Time (IST) - Default
    'UTC',
    'America/New_York',
    'America/Los_Angeles',
    'Europe/London',
    'Europe/Paris',
    'Asia/Tokyo',
    'Asia/Shanghai',
    'Australia/Sydney',
  ];

  final List<String> _languages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Chinese',
    'Japanese',
    'Korean',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final jwt = await _getJwt();
      final prefs = await SharedPreferences.getInstance();

      if (jwt == null) {
        // Load from SharedPreferences if available
        final email = prefs.getString('email');
        final name = prefs.getString('name');
        if (email != null) {
          _populateForm({
            'name': name ?? '',
            'email': email,
            'timezone': 'Asia/Kolkata',
            'theme': 'Blue',
            'font': 'Default',
          });
        }
        return;
      }

      // Try to get user profile from API
      final response = await http.get(
        Uri.parse('$apiBase/task/api/user/profile'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        final profile = jsonDecode(response.body);
        _populateForm(profile);

        // Update SharedPreferences with latest data
        if (profile['email'] != null) {
          await prefs.setString('email', profile['email']);
        }
        if (profile['name'] != null) {
          await prefs.setString('name', profile['name']);
        }
      } else {
        // Fallback to SharedPreferences data
        final email = prefs.getString('email');
        final name = prefs.getString('name');
        _populateForm({
          'name': name ?? 'User',
          'email': email ?? 'user@example.com',
          'timezone': 'Asia/Kolkata',
          'theme': 'Blue',
          'font': 'Default',
        });
      }
    } catch (e) {
      // Use SharedPreferences data or mock data for development
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('email');
      final name = prefs.getString('name');

      _populateForm({
        'name': name ?? 'John Doe',
        'email': email ?? 'john@example.com',
        'telegram': '',
        'whatsapp': '',
        'bio': 'Software Developer',
        'timezone': 'Asia/Kolkata',
        'theme': 'Blue',
        'font': 'Default',
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _populateForm(Map<String, dynamic> profile) {
    setState(() {
      _nameController.text = profile['name'] ?? '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim();
      _emailController.text = profile['email'] ?? '';
      _telegramController.text = profile['telegram'] ?? '';
      _whatsappController.text = profile['whatsapp'] ?? '';
      _bioController.text = profile['bio'] ?? '';
      _emailNotifications = profile['email_notifications'] ?? true;
      _pushNotifications = profile['push_notifications'] ?? false;
      _timezone = profile['timezone'] ?? 'Asia/Kolkata';
      _language = profile['language'] ?? 'English';
      _selectedTheme = profile['theme'] ?? 'Blue';
      _selectedFont = profile['font'] ?? 'Default';
      _avatarPath = profile['avatar'];
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final jwt = await _getJwt();
      final prefs = await SharedPreferences.getInstance();

      final profileData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'telegram': _telegramController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'bio': _bioController.text.trim(),
        'email_notifications': _emailNotifications,
        'push_notifications': _pushNotifications,
        'timezone': _timezone,
        'language': _language,
        'theme': _selectedTheme,
        'font': _selectedFont,
        'avatar': _avatarPath,
      };

      if (jwt != null) {
        // Try to update via API
        final response = await http.put(
          Uri.parse('$apiBase/task/api/user/profile'),
          headers: {
            'Authorization': 'Bearer $jwt',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(profileData),
        );

        if (response.statusCode == 200) {
          // Update SharedPreferences with new data
          await prefs.setString('name', profileData['name'] as String);
          await prefs.setString('email', profileData['email'] as String);
          _showSuccessMessage('Profile updated successfully');
          return;
        } else {
          final errorBody = response.body;
          print('Profile update failed: ${response.statusCode} - $errorBody');
          _showErrorMessage('Failed to update profile: ${response.statusCode}');
          return;
        }
      }

      // Fallback: Update SharedPreferences directly (demo mode)
      await prefs.setString('name', profileData['name'] as String);
      await prefs.setString('email', profileData['email'] as String);
      _showSuccessMessage('Profile updated successfully (Demo Mode)');

    } catch (e) {
      print('Profile update error: $e');

      // Still try to save to SharedPreferences as fallback
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('name', _nameController.text.trim());
        await prefs.setString('email', _emailController.text.trim());
        _showSuccessMessage('Profile updated locally (Offline Mode)');
      } catch (prefError) {
        _showErrorMessage('Failed to update profile: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModernLayout(
      title: 'Edit Profile',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Colors.blue, size: 28),
                      const SizedBox(width: 12),
                      const Text(
                        'Edit Profile',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _saveProfile,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Changes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person),
                            SizedBox(width: 8),
                            Text('Profile'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.palette),
                            SizedBox(width: 8),
                            Text('Customization'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications),
                            SizedBox(width: 8),
                            Text('Notifications'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildProfileTab(),
                      _buildCustomizationTab(),
                      _buildNotificationsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 20),

              // Avatar Section
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blue.shade100,
                      backgroundImage: _avatarPath != null ? NetworkImage(_avatarPath!) : null,
                      child: _avatarPath == null
                          ? Icon(Icons.person, size: 50, color: Colors.blue.shade700)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Avatar upload - Coming Soon')),
                        );
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Change Avatar'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Email is required';
                  }
                  if (!value!.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telegramController,
                decoration: const InputDecoration(
                  labelText: 'Telegram Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.telegram),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _whatsappController,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomizationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Appearance & Customization',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),

            // Theme Selection
            const Text(
              'Theme Color',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: ['Blue', 'Green', 'Purple', 'Orange', 'Red', 'Teal', 'Indigo', 'Pink'].map((theme) {
                final themeNotifier = ref.read(themeProvider.notifier);
                final currentTheme = ref.watch(themeProvider);
                return ChoiceChip(
                  label: Text(theme),
                  selected: currentTheme.selectedTheme == theme,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedTheme = theme);
                      themeNotifier.setTheme(theme);
                    }
                  },
                  selectedColor: _getThemeColor(theme),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Dark Mode Toggle
            Row(
              children: [
                const Icon(Icons.dark_mode, color: Colors.grey),
                const SizedBox(width: 12),
                const Text(
                  'Dark Mode',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Consumer(
                  builder: (context, ref, child) {
                    final themeNotifier = ref.read(themeProvider.notifier);
                    final currentTheme = ref.watch(themeProvider);
                    return Switch(
                      value: currentTheme.isDarkMode,
                      onChanged: (value) {
                        themeNotifier.setDarkMode(value);
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Font Selection
            const Text(
              'Font Family',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.font_download),
              ),
              value: _selectedFont,
              items: ['Default', 'Roboto', 'Open Sans', 'Lato', 'Montserrat'].map((font) {
                return DropdownMenuItem(value: font, child: Text(font));
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedFont = value!);
              },
            ),
            const SizedBox(height: 24),

            // Language & Timezone
            const Text(
              'Localization',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Language',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.language),
              ),
              value: _language,
              items: _languages.map((language) {
                return DropdownMenuItem(value: language, child: Text(language));
              }).toList(),
              onChanged: (value) {
                setState(() => _language = value!);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Timezone',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.access_time),
              ),
              value: _timezone,
              items: _timezones.map((timezone) {
                return DropdownMenuItem(value: timezone, child: Text(timezone));
              }).toList(),
              onChanged: (value) {
                setState(() => _timezone = value!);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notification Preferences',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),

            SwitchListTile(
              title: const Text('Email Notifications'),
              subtitle: const Text('Receive notifications via email'),
              value: _emailNotifications,
              onChanged: (value) {
                setState(() => _emailNotifications = value);
              },
            ),
            SwitchListTile(
              title: const Text('Push Notifications'),
              subtitle: const Text('Receive push notifications'),
              value: _pushNotifications,
              onChanged: (value) {
                setState(() => _pushNotifications = value);
              },
            ),
            const Divider(),
            const Text(
              'Notification Types',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('Task Assignments'),
              subtitle: const Text('When tasks are assigned to you'),
              value: true,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text('Due Date Reminders'),
              subtitle: const Text('Reminders for upcoming due dates'),
              value: true,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text('Project Updates'),
              subtitle: const Text('Updates on project progress'),
              value: false,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text('Team Messages'),
              subtitle: const Text('Messages from team members'),
              value: true,
              onChanged: (value) {},
            ),
          ],
        ),
      ),
    );
  }

  Color _getThemeColor(String theme) {
    switch (theme) {
      case 'Blue':
        return Colors.blue;
      case 'Green':
        return Colors.green;
      case 'Purple':
        return Colors.purple;
      case 'Orange':
        return Colors.orange;
      case 'Red':
        return Colors.red;
      case 'Teal':
        return Colors.teal;
      case 'Indigo':
        return Colors.indigo;
      case 'Pink':
        return Colors.pink;
      default:
        return Colors.blue;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _telegramController.dispose();
    _whatsappController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}
