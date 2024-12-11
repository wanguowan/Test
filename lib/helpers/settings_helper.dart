import 'package:shared_preferences/shared_preferences.dart';

class SettingsHelper {
  static const String _pomodoroTimeKey = 'pomodoro_time';
  static const int defaultPomodoroMinutes = 25;

  static final SettingsHelper instance = SettingsHelper._privateConstructor();
  SettingsHelper._privateConstructor();

  Future<void> setPomodoroTime(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pomodoroTimeKey, minutes);
  }

  Future<int> getPomodoroTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pomodoroTimeKey) ?? defaultPomodoroMinutes;
  }
} 