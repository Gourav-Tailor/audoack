import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordingSnapshot {
  const RecordingSnapshot({
    required this.running,
    required this.state,
    this.batchId,
    this.chunkIndex = 0,
    this.error,
  });

  final bool running;
  final String state;
  final int? batchId;
  final int chunkIndex;
  final String? error;
}

class LiveRecordingService {
  LiveRecordingService({
    this.baseUrl = 'https://audoack.in',
    this.onStatus,
  });

  final String baseUrl;
  final ValueChanged<RecordingSnapshot>? onStatus;
  final AudioRecorder _recorder = AudioRecorder();

  bool _running = false;
  bool _disposed = false;
  int? _batchId;
  int _chunkIndex = 0;
  String? _deviceToken;

  void _emit(String state, {String? error}) {
    onStatus?.call(RecordingSnapshot(
      running: _running,
      state: state,
      batchId: _batchId,
      chunkIndex: _chunkIndex,
      error: error,
    ));
  }

  Future<void> start({
    required String deviceToken,
    required int intervalSeconds,
  }) async {
    if (_running) return;

    final token = deviceToken.trim();
    if (token.isEmpty) throw ArgumentError('Device token is required.');
    if (intervalSeconds < 5 || intervalSeconds % 5 != 0) {
      throw ArgumentError(
          'Recording interval must be a multiple of 5 seconds.');
    }
    if (!await _recorder.hasPermission()) {
      throw Exception('Microphone permission denied.');
    }

    _running = true;
    _deviceToken = token;
    _batchId = null;
    _chunkIndex = 0;

    try {
      _emit('creating_session');
      _batchId = await _createSession(token);
      _emit('recording');

      while (_running && !_disposed) {
        final file = await _recordFiveSeconds();

        if (!_running || _disposed) {
          await _deleteFile(file);
          break;
        }

        try {
          _emit('uploading');
          await _uploadChunk(
            token: token,
            batchId: _batchId!,
            index: _chunkIndex,
            file: file,
          );

          _chunkIndex++;
          _emit('uploaded');

          final waitSeconds = intervalSeconds - 5;
          if (waitSeconds > 0 && _running && !_disposed) {
            _emit('waiting');
            await Future.delayed(Duration(seconds: waitSeconds));
          }
        } finally {
          await _deleteFile(file);
        }
      }
    } catch (e) {
      if (_running) _emit('error', error: e.toString());
      rethrow;
    }
  }

  Future<void> stop() async {
    if (!_running) return;

    _running = false;
    _emit('stopping');

    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {}

    final batchId = _batchId;
    final token = _deviceToken;

    if (batchId != null && token != null) {
      try {
        _emit('finalizing');
        await _finalizeSession(batchId, token);
      } catch (e) {
        _emit('error', error: 'Finalize failed: $e');
        rethrow;
      }
    }

    _emit('stopped');
  }

  Future<int> _createSession(String token) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/sessions/'),
    );
    request.headers['Authorization'] = 'Token $token';
    request.fields['title'] = 'Audoack Live Recording';

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Session creation failed: ${response.statusCode} $body',
      );
    }

    final data = _decodeMap(body);
    final value = data['batch_id'];
    final id = int.tryParse(value?.toString() ?? '');

    if (id == null) {
      throw HttpException('Invalid batch_id in session response: $body');
    }

    return id;
  }

  Future<void> _uploadChunk({
    required String token,
    required int batchId,
    required int index,
    required File file,
  }) async {
    if (!await file.exists() || await file.length() == 0) {
      throw HttpException('Recording file is missing or empty.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/sessions/$batchId/chunks/'),
    );

    request.headers['Authorization'] = 'Token $token';
    request.fields['index'] = index.toString();
    request.files.add(await http.MultipartFile.fromPath(
      'chunk_data',
      file.path,
      filename: 'chunk_$index.wav',
    ));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Chunk upload failed: ${response.statusCode} $body',
      );
    }

    final data = _decodeMap(body);
    final status = data['status'];

    if (status == 'chunk_queued') return;
    if (status == 'chunk_saved' && data['duplicate'] == true) return;

    throw HttpException('Unexpected chunk response: $body');
  }

  Future<void> _finalizeSession(int batchId, String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/sessions/$batchId/finalize/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Session finalize failed: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<File> _recordFiveSeconds() async {
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/audoack_chunk_${DateTime.now().microsecondsSinceEpoch}.wav';

    final file = File(path);
    await _deleteFile(file);

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );

    _emit('recording');
    await Future.delayed(const Duration(seconds: 5));

    if (!_running || _disposed) {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
      throw _RecordingStopped();
    }

    final recordedPath = await _recorder.stop();

    if (recordedPath == null) {
      throw Exception('Recorder did not return a file.');
    }

    final recordedFile = File(recordedPath);
    if (!await recordedFile.exists() || await recordedFile.length() == 0) {
      throw Exception('Recorded WAV is missing or empty.');
    }

    return recordedFile;
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Expected JSON object.');
  }

  Future<void> _deleteFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  void dispose() {
    _disposed = true;
    _running = false;
    _recorder.dispose();
  }
}

class _RecordingStopped implements Exception {}
