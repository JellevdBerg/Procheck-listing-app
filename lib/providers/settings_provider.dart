import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../data/hive_setup.dart';

/// A small curated palette so the accent picker is a handful of good-looking
/// swatches rather than a full color wheel.
const List<Color> accentPalette = [
  Color(0xFF3D5AFE), // indigo (default)
  Color(0xFF2979FF), // blue
  Color(0xFF00BFA5), // teal
  Color(0xFF00C853), // green
  Color(0xFFFF6D00), // orange
  Color(0xFFFF3D71), // pink
  Color(0xFFD500F9), // purple
  Color(0xFF6D4C41), // brown
];

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.accentIndex,
    required this.reduceMotion,
  });

  final ThemeMode themeMode;
  final int accentIndex;
  final bool reduceMotion;

  Color get accentColor => accentPalette[accentIndex];

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? accentIndex,
    bool? reduceMotion,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accentIndex: accentIndex ?? this.accentIndex,
      reduceMotion: reduceMotion ?? this.reduceMotion,
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  return SettingsNotifier();
});

/// Persistence to Hive is fire-and-forget, matching the rest of the app.
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(_load());

  static Box get _box => Hive.box(settingsBoxName);

  static AppSettings _load() {
    final themeModeIndex =
        _box.get('themeMode', defaultValue: ThemeMode.system.index) as int;
    final accentIndex = _box.get('accentIndex', defaultValue: 0) as int;
    final reduceMotion = _box.get('reduceMotion', defaultValue: false) as bool;
    return AppSettings(
      themeMode: ThemeMode.values[themeModeIndex],
      accentIndex: accentIndex.clamp(0, accentPalette.length - 1),
      reduceMotion: reduceMotion,
    );
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    unawaited(_box.put('themeMode', mode.index));
  }

  void setAccentIndex(int index) {
    state = state.copyWith(accentIndex: index);
    unawaited(_box.put('accentIndex', index));
  }

  void setReduceMotion(bool value) {
    state = state.copyWith(reduceMotion: value);
    unawaited(_box.put('reduceMotion', value));
  }
}
