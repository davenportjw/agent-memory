import 'package:flutter/services.dart';

/// Sound and acoustic feedback cues for edge runtime events.
enum SoundCue {
  bootChime,
  tactileClick,
  evictPulse,
  milestoneChime,
  toggleClick,
}

/// Zero-dependency audio-haptic feedback service providing tactile sensory cues
/// for edge memory lifecycle transitions, context evictions, and tactical milestones.
class AudioFeedbackService {
  static final AudioFeedbackService instance = AudioFeedbackService._internal();
  AudioFeedbackService._internal();

  factory AudioFeedbackService() => instance;

  bool _isMuted = false;
  bool get isMuted => _isMuted;
  set isMuted(bool value) => _isMuted = value;

  final List<SoundCue> _cueHistory = [];
  List<SoundCue> get cueHistory => List.unmodifiable(_cueHistory);

  void toggleMute() {
    _isMuted = !_isMuted;
  }

  void resetHistory() {
    _cueHistory.clear();
  }

  /// Plays a subtle ascending chime for boot initialization and 3 AM dream consolidation.
  Future<void> playChime() async {
    if (_isMuted) return;
    _cueHistory.add(SoundCue.bootChime);
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // Graceful fallback in environments without audio support
    }
  }

  /// Plays a light tactile click for JIT fetches, toggle taps, and dynamic card choices.
  Future<void> playClick() async {
    if (_isMuted) return;
    _cueHistory.add(SoundCue.tactileClick);
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.selectionClick();
    } catch (_) {
      // Graceful fallback
    }
  }

  /// Plays a low resonant pulse for task-bound context eviction.
  Future<void> playEvictPulse() async {
    if (_isMuted) return;
    _cueHistory.add(SoundCue.evictPulse);
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // Graceful fallback
    }
  }

  /// Plays an uplifting milestone cue when an objective is completed.
  Future<void> playMilestone() async {
    if (_isMuted) return;
    _cueHistory.add(SoundCue.milestoneChime);
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // Graceful fallback
    }
  }
}
