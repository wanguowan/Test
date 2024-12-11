import 'package:flutter/material.dart';
import '../helpers/settings_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsHelper = SettingsHelper.instance;
  final _pomodoroController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final minutes = await _settingsHelper.getPomodoroTime();
    if (mounted) {
      setState(() {
        _pomodoroController.text = minutes.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('番茄钟时长（分钟）：'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pomodoroController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final minutes = int.tryParse(_pomodoroController.text);
                      if (minutes != null && minutes > 0) {
                        await _settingsHelper.setPomodoroTime(minutes);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('设置已保存')),
                          );
                          Navigator.pop(context);
                        }
                      }
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _pomodoroController.dispose();
    super.dispose();
  }
} 