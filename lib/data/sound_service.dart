import 'package:audioplayers/audioplayers.dart';

/// Plays short, one-off UI sound effects. A completed task has nothing to
/// cancel or clean up, so unlike [NotificationService] this has no
/// initialize/dispose lifecycle beyond the player itself.
class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  AudioPlayer? _player;

  /// The quick "ding-ding" played when a task (or, via its subtasks, a
  /// task's last remaining subtask) is checked off. Swallows errors —
  /// a missing/blocked audio output shouldn't ever stop a checkbox from
  /// toggling — and replays from the start if it's still finishing from a
  /// rapid previous check-off, rather than queuing or being dropped.
  ///
  /// The player is built lazily, on first use, rather than as an eager
  /// field initializer: [AudioPlayer]'s constructor itself reaches for a
  /// platform channel (via `ServicesBinding.instance`), so building it
  /// eagerly meant a binding that isn't ready yet — e.g. a plain
  /// `ProviderContainer`-based test with no `TestWidgetsFlutterBinding`
  /// initialized — crashed on the first access to [instance], before
  /// this method's own try/catch ever got a chance to catch anything.
  Future<void> playCheckoff() async {
    try {
      final player = _player ??= AudioPlayer()
        ..setReleaseMode(ReleaseMode.stop);
      await player.stop();
      await player.play(AssetSource('sounds/checkoff_chime.wav'), volume: 0.35);
    } catch (_) {
      // Best-effort: no audio output, unsupported platform, etc.
    }
  }
}
