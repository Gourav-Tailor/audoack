import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/analysis.dart';
import '../models/device.dart';

class AuthException implements Exception {
  final String message;

  const AuthException([this.message = 'Authentication required.']);

  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = 'https://audoack.in';
  static const String _tokenKey = 'mobile_auth_token';
  static const String _usernameKey = 'username';
  static const String _deviceTokenKey = 'recording_device_token';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

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
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode != 200) return false;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true) return false;

    final token = data['token']?.toString();
    if (token == null || token.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    return true;
  }

  Future<void> clearAuthSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);

    try {
      if (token != null && token.isNotEmpty) {
        await http.post(
          Uri.parse('$baseUrl/api/v1/mobile/logout/'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    } finally {
      await clearAuthSession();
    }
  }

  Future<List<Device>> getDevices() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/mobile/devices/'),
      headers: await _headers(),
    );

    _throwIfUnauthorized(response.statusCode);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load devices: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final List devices = data['devices'] ?? [];

    return devices
        .map((device) => Device.fromJson(Map<String, dynamic>.from(device)))
        .toList();
  }

  Future<Analysis?> getLatestAnalysis({required String deviceId}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/mobile/devices/$deviceId/latest-analysis/'),
      headers: await _headers(),
    );

    _throwIfUnauthorized(response.statusCode);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load analysis: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['latestAnalysis'] == null) return null;

    return Analysis.fromJson(
      Map<String, dynamic>.from(data['latestAnalysis']),
    );
  }

  Future<void> setRecordingDeviceToken(String token) async {
    final value = token.trim();
    if (value.isEmpty) {
      throw ArgumentError('Device token cannot be empty.');
    }
    await _secureStorage.write(key: _deviceTokenKey, value: value);
  }

  Future<String?> getRecordingDeviceToken() {
    return _secureStorage.read(key: _deviceTokenKey);
  }

  Future<void> clearRecordingDeviceToken() {
    return _secureStorage.delete(key: _deviceTokenKey);
  }

  Future<String> createRecordingSession({
    required String deviceToken,
    String title = 'Audoack Live Recording',
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/api/v1/sessions/'),
          )
          ..headers['Authorization'] = 'Token ${deviceToken.trim()}'
          ..headers['Accept'] = 'application/json'
          ..fields['title'] = title;

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Session creation failed: ${response.statusCode} $body',
      );
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    final batchId = data['batch_id']?.toString();
    if (batchId == null || batchId == 'null' || batchId.isEmpty) {
      throw const FormatException(
        'Session response did not contain batch_id.',
      );
    }

    return batchId;
  }

  Future<void> uploadRecordingChunk({
    required String deviceToken,
    required String batchId,
    required int index,
    required File audioFile,
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/api/v1/sessions/$batchId/chunks/'),
          )
          ..headers['Authorization'] = 'Token ${deviceToken.trim()}'
          ..headers['Accept'] = 'application/json'
          ..fields['index'] = index.toString()
          ..files.add(
            await http.MultipartFile.fromPath(
              'chunk_data',
              audioFile.path,
              filename: 'chunk_${index.toString().padLeft(4, '0')}.wav',
            ),
          );

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Chunk upload failed: ${response.statusCode} $body');
    }

    final data = jsonDecode(body);
    if (data is Map &&
        data['chunk_queued'] != true &&
        data['duplicate'] != true) {
      throw HttpException('Chunk was not queued: $body');
    }
  }

  Future<void> finalizeRecordingSession({
    required String deviceToken,
    required String batchId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/sessions/$batchId/finalize/'),
      headers: {
        'Authorization': 'Token ${deviceToken.trim()}',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Session finalization failed: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);

    if (token == null || token.trim().isEmpty) {
      throw const AuthException();
    }

    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void _throwIfUnauthorized(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      throw const AuthException('Session expired. Please log in again.');
    }
  }
}
