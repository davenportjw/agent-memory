import 'package:flutter_test/flutter_test.dart';
import '../lib/services/audio_feedback_service.dart';

void main() {
  group('AudioFeedbackService Suite', () {
    late AudioFeedbackService audioService;

    setUp(() {
      audioService = AudioFeedbackService.instance;
      audioService.isMuted = false;
      audioService.resetHistory();
    });

    test('Initializes with sound unmuted by default', () {
      expect(audioService.isMuted, isFalse);
      expect(audioService.cueHistory, isEmpty);
    });

    test('Plays chime and records to cueHistory', () async {
      await audioService.playChime();
      expect(audioService.cueHistory.length, equals(1));
      expect(audioService.cueHistory.first, equals(SoundCue.bootChime));
    });

    test('Plays tactile click and records to cueHistory', () async {
      await audioService.playClick();
      expect(audioService.cueHistory.length, equals(1));
      expect(audioService.cueHistory.first, equals(SoundCue.tactileClick));
    });

    test('Plays eviction pulse and records to cueHistory', () async {
      await audioService.playEvictPulse();
      expect(audioService.cueHistory.length, equals(1));
      expect(audioService.cueHistory.first, equals(SoundCue.evictPulse));
    });

    test('Plays milestone fanfare and records to cueHistory', () async {
      await audioService.playMilestone();
      expect(audioService.cueHistory.length, equals(1));
      expect(audioService.cueHistory.first, equals(SoundCue.milestoneChime));
    });

    test('Toggles mute state correctly', () async {
      audioService.toggleMute();
      expect(audioService.isMuted, isTrue);

      // When muted, triggers do not log cues
      await audioService.playClick();
      expect(audioService.cueHistory, isEmpty);

      audioService.toggleMute();
      expect(audioService.isMuted, isFalse);

      await audioService.playClick();
      expect(audioService.cueHistory.length, equals(1));
      expect(audioService.cueHistory.first, equals(SoundCue.tactileClick));
    });

    test('resetHistory purges recent cues', () async {
      await audioService.playClick();
      await audioService.playChime();
      expect(audioService.cueHistory.length, equals(2));

      audioService.resetHistory();
      expect(audioService.cueHistory, isEmpty);
    });
  });
}
