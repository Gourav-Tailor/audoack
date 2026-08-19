import 'package:flutter/material.dart';

import '../models/device.dart';
import '../services/api_service.dart';
import '../services/live_recording_service.dart';
import 'analysis_screen.dart';
import 'login_screen.dart';

class DevicesScreen extends StatefulWidget {
  final String username;
  final ApiService apiService;

  const DevicesScreen({
    super.key,
    required this.username,
    required this.apiService,
  });

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  List<Device> devices = [];
  bool loading = true;
  String? error;

  final tokenController = TextEditingController();
  int selectedInterval = 10;
  LiveRecordingService? recordingService;
  bool recording = false;
  String recordingState = 'stopped';
  int? batchId;
  int chunkIndex = 0;
  String? recordingError;

  static const intervals = <int>[5, 10, 15, 20, 25, 30, 60, 120, 300];

  @override
  void initState() {
    super.initState();
    loadDevices();
    loadStoredRecordingToken();
  }

  Future<void> loadStoredRecordingToken() async {
    final token = await widget.apiService.getRecordingDeviceToken();
    if (!mounted || token == null) return;
    tokenController.text = token;
  }

  Future<void> loadDevices() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await widget.apiService.getDevices();
      if (!mounted) return;
      setState(() => devices = result);
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to load devices.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> configureToken() async {
    final token = tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the device token first.')),
      );
      return;
    }

    await widget.apiService.setRecordingDeviceToken(token);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Device token saved securely.')),
    );
  }

  Future<void> startRecording() async {
    final token = tokenController.text.trim();

    if (token.isEmpty) {
      setState(() {
        recordingError = 'Enter and save a device token first.';
      });
      return;
    }

    await widget.apiService.setRecordingDeviceToken(token);

    final service = LiveRecordingService(
      onStatus: (snapshot) {
        if (!mounted) return;

        setState(() {
          recording = snapshot.running;
          recordingState = snapshot.state;
          batchId = snapshot.batchId;
          chunkIndex = snapshot.chunkIndex;
          recordingError = snapshot.error;
        });
      },
    );

    recordingService = service;

    setState(() {
      recording = true;
      recordingError = null;
      batchId = null;
      chunkIndex = 0;
    });

    try {
      await service.start(
        deviceToken: token,
        intervalSeconds: selectedInterval,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          recording = false;
          recordingState = 'error';
          recordingError = e.toString();
        });
      }
      service.dispose();
      recordingService = null;
    }
  }

  Future<void> stopRecording() async {
    try {
      await recordingService?.stop();
    } catch (e) {
      if (mounted) {
        setState(() {
          recordingError = e.toString();
          recordingState = 'error';
        });
      }
    } finally {
      recordingService?.dispose();
      recordingService = null;
    }

    if (!mounted) return;

    setState(() {
      recording = false;
      recordingState = 'stopped';
    });
  }

  void logout() {
    widget.apiService.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(apiService: widget.apiService),
      ),
      (_) => false,
    );
  }

  @override
  void dispose() {
    recordingService?.dispose();
    tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Devices'),
        actions: [
          IconButton(onPressed: loadDevices, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: loadDevices,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadDevices,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildRecorderCard(),
          const SizedBox(height: 20),
          if (devices.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: Text('No devices found.')),
            )
          else
            ...devices.map(_buildDeviceCard),
        ],
      ),
    );
  }

  Widget _buildRecorderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Audio Recording',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Records 5-second WAV chunks and uploads them to the Audoack session API.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tokenController,
              obscureText: true,
              enabled: !recording,
              decoration: InputDecoration(
                labelText: 'Device token',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: recording ? null : configureToken,
                  icon: const Icon(Icons.save),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: selectedInterval,
              decoration: const InputDecoration(
                labelText: 'Recording interval',
                helperText: 'Start a new 5-second recording every N seconds.',
                border: OutlineInputBorder(),
              ),
              items: intervals.map((seconds) {
                return DropdownMenuItem(
                  value: seconds,
                  child: Text('Every $seconds seconds'),
                );
              }).toList(),
              onChanged: recording
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          selectedInterval = value;
                        });
                      }
                    },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: recording ? null : startRecording,
                    icon: const Icon(Icons.mic),
                    label: const Text('Start'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: recording ? stopRecording : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _statusRow('State', recordingState),
            _statusRow('Batch', batchId?.toString() ?? '-'),
            _statusRow('Next chunk', chunkIndex.toString()),
            if (recordingError != null) ...[
              const SizedBox(height: 8),
              Text(recordingError!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(Device device) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: const CircleAvatar(
            radius: 25,
            child: Icon(Icons.mic),
          ),
          title: Text(
            device.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('Device ID: ${device.id}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AnalysisScreen(
                  username: widget.username,
                  device: device,
                  apiService: widget.apiService,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
