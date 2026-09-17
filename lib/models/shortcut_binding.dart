import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A global app-level keyboard shortcut that can be rebound from
/// Settings > Keyboard Shortcuts.
enum ShortcutAction {
  newProject('New project'),
  newTask('New task'),
  undo('Undo');

  const ShortcutAction(this.label);

  final String label;
}

/// One key combination. [cmdOrCtrl] binds both the Control and Command
/// variants at once (matching how this app's shortcuts have always worked
/// across platforms) rather than tracking Control/Meta as separate
/// modifiers a user would have to pick between.
class ShortcutBinding {
  const ShortcutBinding({
    required this.key,
    this.cmdOrCtrl = false,
    this.shift = false,
    this.alt = false,
  });

  final LogicalKeyboardKey key;
  final bool cmdOrCtrl;
  final bool shift;
  final bool alt;

  static const Map<ShortcutAction, ShortcutBinding> defaults = {
    ShortcutAction.newProject: ShortcutBinding(
      key: LogicalKeyboardKey.keyP,
      cmdOrCtrl: true,
    ),
    ShortcutAction.newTask: ShortcutBinding(
      key: LogicalKeyboardKey.keyT,
      cmdOrCtrl: true,
    ),
    ShortcutAction.undo: ShortcutBinding(
      key: LogicalKeyboardKey.keyZ,
      cmdOrCtrl: true,
    ),
  };

  /// One or two [SingleActivator]s (Control and/or Command variants) to
  /// register in a `CallbackShortcuts.bindings` map.
  List<SingleActivator> toActivators() {
    if (!cmdOrCtrl) {
      return [SingleActivator(key, shift: shift, alt: alt)];
    }
    return [
      SingleActivator(key, control: true, shift: shift, alt: alt),
      SingleActivator(key, meta: true, shift: shift, alt: alt),
    ];
  }

  bool sameCombo(ShortcutBinding other) =>
      key == other.key &&
      cmdOrCtrl == other.cmdOrCtrl &&
      shift == other.shift &&
      alt == other.alt;

  String get displayLabel {
    final parts = <String>[
      if (cmdOrCtrl) 'Ctrl/Cmd',
      if (alt) 'Alt',
      if (shift) 'Shift',
      _keyLabel(key),
    ];
    return parts.join(' + ');
  }

  static String _keyLabel(LogicalKeyboardKey key) {
    final label = key.keyLabel;
    return label.isEmpty ? key.debugName ?? key.keyId.toString() : label;
  }
}
