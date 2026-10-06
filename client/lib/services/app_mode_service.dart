import 'package:flutter/foundation.dart';

enum AppDisplayMode {
  /// Simple Mode (Showcase): Laser-focused on Edge vs Cloud AI, Memories, and State.
  /// Hides superfluous developer panels, raw telemetry dialogs, cheat steppers, and rater rubrics.
  simple,

  /// Everything Mode (Deep-Dive): Unlocks all 8 navigation destinations, raw frame budget
  /// telemetry dialogs, LLM-as-a-rater rubrics, policy matrices, and sandbox generators.
  everything,
}

class AppModeService extends ChangeNotifier {
  static final AppModeService _instance = AppModeService._internal();

  factory AppModeService() => _instance;

  AppModeService._internal();

  AppDisplayMode _mode = AppDisplayMode.simple;

  AppDisplayMode get mode => _mode;

  bool get isSimple => _mode == AppDisplayMode.simple;

  bool get isEverything => _mode == AppDisplayMode.everything;

  void setMode(AppDisplayMode newMode) {
    if (_mode == newMode) return;
    _mode = newMode;
    notifyListeners();
  }

  void toggleMode() {
    setMode(isSimple ? AppDisplayMode.everything : AppDisplayMode.simple);
  }
}
