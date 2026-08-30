import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/devices_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
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
  bool onboardingCompleted = false;
  String? savedUsername;
  ThemeMode themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    loadPreferences();
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final username = prefs.getString('username');
    var storedOnboarding = prefs.getBool('onboarding_completed');
    if (storedOnboarding == null && username != null) {
      await prefs.setBool('onboarding_completed', true);
      storedOnboarding = true;
    }

    setState(() {
      onboardingCompleted = storedOnboarding ?? false;
      savedUsername = username;
      themeMode = (prefs.getBool('dark_mode') ?? false)
          ? ThemeMode.dark
          : ThemeMode.light;
      loading = false;
    });
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (!mounted) return;
    setState(() => onboardingCompleted = true);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (themeMode == mode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', mode == ThemeMode.dark);
    if (!mounted) return;
    setState(() => themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Audoack',
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : !onboardingCompleted
              ? OnboardingScreen(onComplete: completeOnboarding)
              : savedUsername != null
                  ? DevicesScreen(
                      username: savedUsername!,
                      apiService: apiService,
                      themeMode: themeMode,
                      onThemeModeChanged: setThemeMode,
                    )
                  : LoginScreen(
                      apiService: apiService,
                      themeMode: themeMode,
                      onThemeModeChanged: setThemeMode,
                    ),
      routes: {
        '/settings': (_) => SettingsScreen(
              themeMode: themeMode,
              onThemeModeChanged: setThemeMode,
            ),
      },
    );
  }
}
