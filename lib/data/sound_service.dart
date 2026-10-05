import 'package:audioplayers/audioplayers.dart';

/// Plays short, one-off UI sound effects. A completed task has nothing to
/// cancel or clean up, so unlike [NotificationService] this has no
/// initialize/dispose lifecycle beyond the player itself.
class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  final _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  /// The quick "ding-ding" played when a task (or, via its subtasks, a
  /// task's last remaining subtask) is checked off. Swallows errors —
  /// a missing/blocked audio output shouldn't ever stop a checkbox from
  /// toggling — and replays from the start if it's still finishing from a
  /// rapid previous check-off, rather than queuing or being dropped.
  Future<void> playCheckoff() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/checkoff_chime.wav'), volume: 0.35);
    } catch (_) {
      // Best-effort: no audio output, unsupported platform, etc.
    }
  }
}
