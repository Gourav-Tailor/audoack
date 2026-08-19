import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/analysis.dart';
import '../models/device.dart';

class ApiService {
  static const String baseUrl = 'http://34.148.248.202';
  static const String _tokenKey = 'mobile_auth_token';

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/mobile/login/'),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    print('LOGIN STATUS: ${response.statusCode}');
    print('LOGIN BODY: ${response.body}');

    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['success'] != true) {
      return false;
    }

    final token = data['token']?.toString();

    if (token == null || token.isEmpty) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);

    return true;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);

    if (token != null && token.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$baseUrl/api/v1/mobile/logout/'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      } finally {
        await prefs.remove(_tokenKey);
      }
    }
  }

  Future<List<Device>> getDevices() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/mobile/devices/'),
      headers: await _headers(),
    );

    print('DEVICES STATUS: ${response.statusCode}');
    print('DEVICES BODY: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load devices: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final List devices = data['devices'] ?? [];

    return devices
        .map(
          (device) => Device.fromJson(
            Map<String, dynamic>.from(device),
          ),
        )
        .toList();
  }

  Future<Analysis?> getLatestAnalysis({
    required String deviceId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/v1/mobile/devices/$deviceId/latest-analysis/',
      ),
      headers: await _headers(),
    );

    print('ANALYSIS STATUS: ${response.statusCode}');
    print('ANALYSIS BODY: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load analysis: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['latestAnalysis'] == null) {
      return null;
    }

    return Analysis.fromJson(
      Map<String, dynamic>.from(data['latestAnalysis']),
    );
  }

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);

    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }
}
