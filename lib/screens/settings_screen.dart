import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const SettingsScreen({super.key, required this.themeMode, required this.onThemeModeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final InAppReview _review = InAppReview.instance;
  bool _requestingReview = false;

  void _setDarkMode(bool enabled) {
    widget.onThemeModeChanged(
      enabled ? ThemeMode.dark : ThemeMode.light,
    );
  }

  static final Uri _signupUrl = Uri.parse('https://audoack.in/signup/');
  static final Uri _privacyUrl = Uri.parse('https://audoack.in/privacy/');

  Future<void> _openUrl(Uri url) async {
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to open the website.')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to open the website.')));
    }
  }

  Future<void> _rateApp() async {
    if (_requestingReview) return;
    setState(() => _requestingReview = true);
    try {
      if (await _review.isAvailable()) {
        await _review.requestReview();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('In-app review is not available right now.')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to open the review prompt.')));
    } finally {
      if (mounted) setState(() => _requestingReview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = widget.themeMode == ThemeMode.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(title: Text('Appearance'), subtitle: Text('Keep the interface comfortable in different lighting conditions.')),
          SwitchListTile(title: const Text('Dark mode'), subtitle: const Text('Use a dark color scheme throughout the app.'), value: darkMode, onChanged: _setDarkMode),
          const Divider(),
          const ListTile(title: Text('AudoAck account'), subtitle: Text('Your mobile login uses the same account created on the AudoAck website.')),
          ListTile(leading: const Icon(Icons.person_add_outlined), title: const Text('Create account'), subtitle: const Text('Create an AudoAck account on the website.'), onTap: () => _openUrl(_signupUrl)),
          ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('Privacy Policy'), subtitle: const Text('Read how AudoAck handles your information.'), onTap: () => _openUrl(_privacyUrl)),
          const Divider(),
          const ListTile(title: Text('Feedback'), subtitle: Text('Help us improve AudoAck during closed testing.')),
          ListTile(leading: const Icon(Icons.star_outline), title: const Text('Rate AudoAck'), subtitle: const Text('Share your experience on Google Play.'), trailing: _requestingReview ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right), onTap: _requestingReview ? null : _rateApp),
        ],
      ),
    );
  }
}
