import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import 'devices_screen.dart';

class LoginScreen extends StatefulWidget {
  final ApiService apiService;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const LoginScreen({
    super.key,
    required this.apiService,
    this.themeMode = ThemeMode.light,
    required this.onThemeModeChanged,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool obscurePassword = true;
  String? error;

  static final Uri _signupUrl = Uri.parse('https://audoack.in/signup/');
  static final Uri _privacyUrl = Uri.parse('https://audoack.in/privacy/');

  Future<void> _openUrl(Uri url) async {
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the website.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the website.')),
        );
      }
    }
  }

  Future<void> login() async {
    FocusScope.of(context).unfocus();
    setState(() { loading = true; error = null; });

    try {
      final username = usernameController.text.trim();
      final password = passwordController.text;
      if (username.isEmpty || password.isEmpty) {
        setState(() => error = 'Username and password are required.');
        return;
      }

      final success = await widget.apiService.login(username: username, password: password);
      if (!success) {
        setState(() => error = 'Invalid username or password.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DevicesScreen(
            username: username,
            apiService: widget.apiService,
            themeMode: widget.themeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
          ),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to connect to server.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('AudoAck', textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Audio Analysis Dashboard', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 40),
                  TextField(controller: usernameController, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  TextField(controller: passwordController, obscureText: obscurePassword, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock), border: const OutlineInputBorder(), suffixIcon: IconButton(onPressed: () => setState(() => obscurePassword = !obscurePassword), icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off)))),
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: loading ? null : login,
                      child: loading ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('LOGIN', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _openUrl(_signupUrl),
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Create account'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _openUrl(_privacyUrl),
                    icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                    label: const Text('Privacy Policy'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your AudoAck account is created on the AudoAck website and can be used to sign in here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
