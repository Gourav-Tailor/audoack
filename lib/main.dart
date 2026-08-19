import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/devices_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AutoAceApp());
}

class AutoAceApp extends StatefulWidget {
  const AutoAceApp({super.key});

  @override
  State<AutoAceApp> createState() => _AutoAceAppState();
}

class _AutoAceAppState extends State<AutoAceApp> {
  final ApiService apiService = ApiService();
  bool loading = true;
  String? savedUsername;

  @override
  void initState() {
    super.initState();
    loadSession();
  }

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');

    if (!mounted) return;

    setState(() {
      savedUsername = username;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Audoack',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: loading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : savedUsername != null
              ? DevicesScreen(
                  username: savedUsername!,
                  apiService: apiService,
                )
              : LoginScreen(apiService: apiService),
    );
  }
}
