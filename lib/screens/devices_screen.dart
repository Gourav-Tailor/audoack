import 'package:flutter/material.dart';

import '../models/device.dart';
import '../services/api_service.dart';
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

  @override
  void initState() {
    super.initState();
    loadDevices();
  }

  Future<void> loadDevices() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await widget.apiService.getDevices();

      if (!mounted) return;

      setState(() {
        devices = result;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Unable to load devices.';
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(apiService: widget.apiService),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Devices'),
        actions: [
          IconButton(
            onPressed: loadDevices,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

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

    if (devices.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadDevices,
        child: ListView(
          children: const [
            SizedBox(height: 200),
            Center(child: Text('No devices found.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadDevices,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: devices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final device = devices[index];

          return Card(
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
          );
        },
      ),
    );
  }
}
