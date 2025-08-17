import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class PinAuthWidget extends StatefulWidget {
  final VoidCallback onSuccess;
  
  const PinAuthWidget({super.key, required this.onSuccess});

  @override
  State<PinAuthWidget> createState() => _PinAuthWidgetState();
}

class _PinAuthWidgetState extends State<PinAuthWidget> {
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  bool _isRegistering = false;
  String? _errorMessage;
  bool _hasPin = false;

  Future<void> _checkPin() async {
    if (_emailController.text.isEmpty) return;
    
    try {
      final response = await http.post(
        Uri.parse('$apiBase/task/api/pin-auth/check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _hasPin = data['hasPin']);
      }
    } catch (e) {
      // Ignore errors for PIN check
    }
  }

  Future<void> _authenticate() async {
    if (_emailController.text.isEmpty || _pinController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter both email and PIN');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final endpoint = _isRegistering ? 'register' : 'login';
      final response = await http.post(
        Uri.parse('$apiBase/task/api/pin-auth/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text,
          'pin': _pinController.text,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        final user = data['user'];

        // Store credentials
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt', token);
        await prefs.setString('email', user['email']);
        await prefs.setBool('isAdmin', false);

        widget.onSuccess();
      } else {
        final error = jsonDecode(response.body);
        setState(() => _errorMessage = error['error'] ?? 'Authentication failed');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Network error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.pin, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  _isRegistering ? 'Register with PIN' : 'Login with PIN',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLoading,
              onChanged: (_) => _checkPin(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              decoration: InputDecoration(
                labelText: _isRegistering ? 'Create PIN (4-6 digits)' : 'Enter PIN',
                prefixIcon: const Icon(Icons.lock),
                border: const OutlineInputBorder(),
                helperText: _isRegistering ? 'Choose a 4-6 digit PIN' : null,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              obscureText: true,
              enabled: !_isLoading,
              onSubmitted: (_) => _authenticate(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade700),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _authenticate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isRegistering ? 'Register' : 'Login'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isLoading ? null : () {
                setState(() {
                  _isRegistering = !_isRegistering;
                  _errorMessage = null;
                });
              },
              child: Text(
                _isRegistering 
                    ? 'Already have a PIN? Login instead'
                    : 'New user? Register with PIN',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }
}
