import 'dart:async';
import 'package:flutter/material.dart';
import '../models/analysis.dart';
import '../models/device.dart';
import '../services/api_service.dart';

class AnalysisScreen extends StatefulWidget {
  final String username;
  final Device device;
  final ApiService apiService;

  const AnalysisScreen({
    super.key,
    required this.username,
    required this.device,
    required this.apiService,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  Analysis? analysis;
  Timer? pollingTimer;
  bool loading = true;
  bool refreshing = false;
  String? error;
  int pollingInterval = 10;

  @override
  void initState() {
    super.initState();
    loadAnalysis();
    startPolling();
  }

  Future<void> loadAnalysis() async {
    if (refreshing) return;
    setState(() { refreshing = true; error = null; });
    try {
      final result = await widget.apiService.getLatestAnalysis(deviceId: widget.device.id);
      if (!mounted) return;
      setState(() => analysis = result);
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to load latest analysis.');
    } finally {
      if (mounted) setState(() { refreshing = false; loading = false; });
    }
  }

  void startPolling() {
    pollingTimer?.cancel();
    pollingTimer = Timer.periodic(Duration(seconds: pollingInterval), (_) => loadAnalysis());
  }

  void changePollingInterval(int seconds) {
    setState(() => pollingInterval = seconds);
    startPolling();
  }

  @override
  void dispose() {
    pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        actions: [
          IconButton(onPressed: refreshing ? null : loadAnalysis, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadAnalysis,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 30, child: Icon(Icons.mic, size: 30)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.device.name,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('ID: ${widget.device.id}', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Auto Refresh',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('Automatically fetch latest analysis every $pollingInterval seconds.',
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      initialValue: pollingInterval,
                      decoration: const InputDecoration(
                        labelText: 'Polling interval',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 5, child: Text('Every 5 seconds')),
                        DropdownMenuItem(value: 10, child: Text('Every 10 seconds')),
                        DropdownMenuItem(value: 15, child: Text('Every 15 seconds')),
                        DropdownMenuItem(value: 30, child: Text('Every 30 seconds')),
                        DropdownMenuItem(value: 60, child: Text('Every 60 seconds')),
                      ],
                      onChanged: (value) {
                        if (value != null) changePollingInterval(value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildAnalysis(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysis() {
    if (loading) {
      return const Card(child: Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      ));
    }

    if (error != null) {
      return Card(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Icon(Icons.error_outline, size: 45),
          const SizedBox(height: 12),
          Text(error!),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: loadAnalysis, child: const Text('Retry')),
        ]),
      ));
    }

    if (analysis == null) {
      return const Card(child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(children: [
          Icon(Icons.analytics_outlined, size: 50),
          SizedBox(height: 12),
          Text('No analysis available yet.', textAlign: TextAlign.center),
        ]),
      ));
    }

    final a = analysis!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.analytics),
              SizedBox(width: 10),
              Expanded(child: Text('Latest Analysis',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 20),
            if (a.filename != null) _analysisRow(Icons.audiotrack, 'File', a.filename!),
            _analysisRow(Icons.info_outline, 'Status', a.status),
            if (a.emotionalTone != null) _analysisRow(Icons.mood, 'Emotional Tone', a.emotionalTone!),
            if (a.emotionalIntensity != null) _analysisRow(Icons.bolt, 'Emotional Intensity', a.emotionalIntensity!),
            if (a.audioQuality != null) _analysisRow(Icons.high_quality, 'Audio Quality', a.audioQuality!),
            _analysisRow(Icons.volume_off, 'Background Noise',
                a.backgroundNoisePresent
                    ? (a.backgroundNoiseType?.isNotEmpty == true ? a.backgroundNoiseType! : 'Present')
                    : 'None'),
            if (a.backgroundNoiseSeverity != null)
              _analysisRow(Icons.warning_amber, 'Noise Severity', a.backgroundNoiseSeverity!),
            _analysisRow(Icons.people, 'Speaker Overlap', a.speakerOverlapPresent ? 'Present' : 'None'),
            _analysisRow(Icons.pause_circle_outline, 'Long Silence', a.longSilencePresent ? 'Present' : 'None'),
            if (a.confidence != null)
              _analysisRow(Icons.percent, 'Confidence', '${(a.confidence! * 100).toStringAsFixed(1)}%'),
            if (a.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(a.createdAt!.toLocal().toString(),
                    style: const TextStyle(color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _analysisRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
