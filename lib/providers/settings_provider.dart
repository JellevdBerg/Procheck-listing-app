import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_setup.dart';
import '../models/shortcut_binding.dart';
import '../models/task_priority.dart';
import '../theme/nocturne_theme.dart';

/// The 8 preset accent swatches — also doubles as the per-project color
/// palette (`Project.colorIndex` indexes into this same list), matching the
/// design handoff where a project's color and the app's accent draw from
/// one palette.
const List<Color> accentPalette = nocturneAccentPalette;

enum DateFormatOption {
  mdy,
  dmy,
  iso;

  static DateFormatOption fromIndex(int? index) {
    if (index == null || index < 0 || index >= DateFormatOption.values.length) {
      return DateFormatOption.mdy;
    }
    return DateFormatOption.values[index];
  }

  String get label => switch (this) {
    DateFormatOption.mdy => 'MM/DD/YYYY',
    DateFormatOption.dmy => 'DD/MM/YYYY',
    DateFormatOption.iso => 'YYYY-MM-DD',
  };
}

enum LandingScreenOption {
  projects,
  templates,
  lastViewed;

  static LandingScreenOption fromIndex(int? index) {
    if (index == null ||
        index < 0 ||
        index >= LandingScreenOption.values.length) {
      return LandingScreenOption.projects;
    }
    return LandingScreenOption.values[index];
  }

  String get label => switch (this) {
    LandingScreenOption.projects => 'Projects',
    LandingScreenOption.templates => 'Templates',
    LandingScreenOption.lastViewed => 'Last viewed',
  };
}

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.accentIndex,
    required this.reduceMotion,
    this.customAccentValue,
    this.defaultPriorityIndex = 0,
    this.dateFormat = DateFormatOption.mdy,
    this.defaultLanding = LandingScreenOption.projects,
    this.sidebarExpanded = true,
    this.workspaceIndex = 0,
    this.lastViewedScreenIndex = 0,
    this.shortcutOverrides = const {},
    this.workspaceNames = const ['Personal'],
    this.workspaceIds = const [_defaultWorkspaceId],
  });

  final ThemeMode themeMode;
  final int accentIndex;
  final bool reduceMotion;

  /// When set, overrides [accentIndex] — a user-picked custom color from
  /// Settings > Appearance rather than one of the [accentPalette] presets.
  final int? customAccentValue;

  final int defaultPriorityIndex;
  final DateFormatOption dateFormat;
  final LandingScreenOption defaultLanding;

  /// Persisted so the sidebar stays collapsed/expanded across restarts.
  final bool sidebarExpanded;

  /// Which of [workspaceNames]/[workspaceIds] is active — see the design
  /// handoff's workspace switcher. Each workspace is a fully separate data
  /// silo: [workspaceIds] carries the stable id (never shown to the user,
  /// never reused) that Project/Task/TaskTemplate.workspaceId is tagged
  /// with, since [workspaceNames] alone can't survive a rename.
  final int workspaceIndex;

  /// User-managed list of workspace names (Add/Edit/Remove via the
  /// sidebar's workspace row context menu). A fresh install seeds exactly
  /// one, "Personal" — always at least one, since [removeWorkspace] refuses
  /// to drop the last remaining name.
  final List<String> workspaceNames;

  /// Stable ids parallel to [workspaceNames] (same length, same order) —
  /// see [workspaceIndex].
  final List<String> workspaceIds;

  String get currentWorkspaceName =>
      workspaceNames[workspaceIndex.clamp(0, workspaceNames.length - 1)];

  String get currentWorkspaceId =>
      workspaceIds[workspaceIndex.clamp(0, workspaceIds.length - 1)];

  /// [AppScreen.index] of whichever screen was showing when the app last
  /// closed — used when [defaultLanding] is [LandingScreenOption.lastViewed].
  final int lastViewedScreenIndex;

  /// User-rebound shortcuts, keyed by action. An action missing here still
  /// uses [ShortcutBinding.defaults].
  final Map<ShortcutAction, ShortcutBinding> shortcutOverrides;

  ShortcutBinding shortcutFor(ShortcutAction action) =>
      shortcutOverrides[action] ?? ShortcutBinding.defaults[action]!;

  Color get accentColor =>
      customAccentValue != null ? Color(customAccentValue!) : accentPalette[accentIndex];

  TaskPriority get defaultPriority => TaskPriority.fromIndex(defaultPriorityIndex);

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? accentIndex,
    bool? reduceMotion,
    int? customAccentValue,
    bool clearCustomAccent = false,
    int? defaultPriorityIndex,
    DateFormatOption? dateFormat,
    LandingScreenOption? defaultLanding,
    bool? sidebarExpanded,
    int? workspaceIndex,
    int? lastViewedScreenIndex,
    Map<ShortcutAction, ShortcutBinding>? shortcutOverrides,
    List<String>? workspaceNames,
    List<String>? workspaceIds,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accentIndex: accentIndex ?? this.accentIndex,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      customAccentValue: clearCustomAccent
          ? null
          : (customAccentValue ?? this.customAccentValue),
      defaultPriorityIndex: defaultPriorityIndex ?? this.defaultPriorityIndex,
      dateFormat: dateFormat ?? this.dateFormat,
      defaultLanding: defaultLanding ?? this.defaultLanding,
      sidebarExpanded: sidebarExpanded ?? this.sidebarExpanded,
      workspaceIndex: workspaceIndex ?? this.workspaceIndex,
      lastViewedScreenIndex:
          lastViewedScreenIndex ?? this.lastViewedScreenIndex,
      shortcutOverrides: shortcutOverrides ?? this.shortcutOverrides,
      workspaceNames: workspaceNames ?? this.workspaceNames,
      workspaceIds: workspaceIds ?? this.workspaceIds,
    );
  }

  static Map<String, dynamic> _shortcutToJson(ShortcutBinding binding) => {
    'keyId': binding.key.keyId,
    'cmdOrCtrl': binding.cmdOrCtrl,
    'shift': binding.shift,
    'alt': binding.alt,
  };

  static ShortcutBinding? _shortcutFromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return null;
    final keyId = json['keyId'] as int?;
    if (keyId == null) return null;
    final key = LogicalKeyboardKey.findKeyByKeyId(keyId);
    if (key == null) return null;
    return ShortcutBinding(
      key: key,
      cmdOrCtrl: json['cmdOrCtrl'] as bool? ?? false,
      shift: json['shift'] as bool? ?? false,
      alt: json['alt'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> _shortcutOverridesToJson(
    Map<ShortcutAction, ShortcutBinding> overrides,
  ) => {
    for (final entry in overrides.entries)
      entry.key.name: _shortcutToJson(entry.value),
  };

  static Map<ShortcutAction, ShortcutBinding> _shortcutOverridesFromJson(
    Map<dynamic, dynamic>? json,
  ) {
    if (json == null) return const {};
    final result = <ShortcutAction, ShortcutBinding>{};
    for (final action in ShortcutAction.values) {
      final binding = _shortcutFromJson(
        json[action.name] as Map<dynamic, dynamic>?,
      );
      if (binding != null) result[action] = binding;
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.index,
    'accentIndex': accentIndex,
    'reduceMotion': reduceMotion,
    'customAccentValue': customAccentValue,
    'defaultPriorityIndex': defaultPriorityIndex,
    'dateFormat': dateFormat.index,
    'defaultLanding': defaultLanding.index,
    'sidebarExpanded': sidebarExpanded,
    'workspaceIndex': workspaceIndex,
    'lastViewedScreenIndex': lastViewedScreenIndex,
    'shortcutOverrides': _shortcutOverridesToJson(shortcutOverrides),
    'workspaceNames': workspaceNames,
    'workspaceIds': workspaceIds,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final accentIndex = json['accentIndex'] as int? ?? 0;
    final workspaceNames = _nonEmptyWorkspaceNames(
      (json['workspaceNames'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
    return AppSettings(
      themeMode: ThemeMode
          .values[(json['themeMode'] as int?) ?? ThemeMode.system.index],
      accentIndex: accentIndex.clamp(0, accentPalette.length - 1),
      reduceMotion: json['reduceMotion'] as bool? ?? false,
      customAccentValue: json['customAccentValue'] as int?,
      defaultPriorityIndex: json['defaultPriorityIndex'] as int? ?? 0,
      dateFormat: DateFormatOption.fromIndex(json['dateFormat'] as int?),
      defaultLanding: LandingScreenOption.fromIndex(
        json['defaultLanding'] as int?,
      ),
      sidebarExpanded: json['sidebarExpanded'] as bool? ?? true,
      workspaceIndex: json['workspaceIndex'] as int? ?? 0,
      lastViewedScreenIndex: json['lastViewedScreenIndex'] as int? ?? 0,
      shortcutOverrides: _shortcutOverridesFromJson(
        json['shortcutOverrides'] as Map<dynamic, dynamic>?,
      ),
      workspaceNames: workspaceNames,
      workspaceIds: _matchedWorkspaceIds(
        workspaceNames,
        json['workspaceIds'] as List<dynamic>?,
      ),
    );
  }
}

/// The first-ever workspace's id — a fixed, non-random value so it can be
/// used as a compile-time default (see [AppSettings]'s constructor).
/// Every workspace added afterward gets a real random id instead.
const _defaultWorkspaceId = 'personal';

/// Never lets the app end up with zero workspace names, however a backup
/// happened to be shaped — same guarantee [SettingsNotifier.removeWorkspace]
/// enforces during normal use.
List<String> _nonEmptyWorkspaceNames(List<String>? names) =>
    (names == null || names.isEmpty) ? const ['Personal'] : names;

/// Keeps the ids list the same length as [names], generating a fresh id for
/// any slot missing one — a fresh install (no ids persisted yet), an old
/// backup saved before this field existed, or a name added without a
/// matching id turning up somehow.
List<String> _matchedWorkspaceIds(List<String> names, List<dynamic>? rawIds) {
  final ids = rawIds?.map((e) => e as String).toList() ?? const <String>[];
  return [
    for (var i = 0; i < names.length; i++)
      i < ids.length ? ids[i] : (i == 0 ? _defaultWorkspaceId : const Uuid().v4()),
  ];
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
      customAccentValue: _box.get('customAccentValue') as int?,
      defaultPriorityIndex:
          _box.get('defaultPriorityIndex', defaultValue: 0) as int,
      dateFormat: DateFormatOption.fromIndex(
        _box.get('dateFormat') as int?,
      ),
      defaultLanding: LandingScreenOption.fromIndex(
        _box.get('defaultLanding') as int?,
      ),
      sidebarExpanded: _box.get('sidebarExpanded', defaultValue: true) as bool,
      workspaceIndex: _box.get('workspaceIndex', defaultValue: 0) as int,
      lastViewedScreenIndex:
          _box.get('lastViewedScreenIndex', defaultValue: 0) as int,
      shortcutOverrides: _loadShortcutOverrides(),
      workspaceNames: _loadWorkspaceNames(),
      workspaceIds: _matchedWorkspaceIds(
        _loadWorkspaceNames(),
        _box.get('workspaceIds') as List<dynamic>?,
      ),
    );
  }

  static List<String> _loadWorkspaceNames() => _nonEmptyWorkspaceNames(
    (_box.get('workspaceNames') as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
  );

  static Map<ShortcutAction, ShortcutBinding> _loadShortcutOverrides() {
    final result = <ShortcutAction, ShortcutBinding>{};
    for (final action in ShortcutAction.values) {
      final keyId = _box.get('shortcut_${action.name}_keyId') as int?;
      if (keyId == null) continue;
      final key = LogicalKeyboardKey.findKeyByKeyId(keyId);
      if (key == null) continue;
      result[action] = ShortcutBinding(
        key: key,
        cmdOrCtrl:
            _box.get('shortcut_${action.name}_cmdOrCtrl', defaultValue: false)
                as bool,
        shift:
            _box.get('shortcut_${action.name}_shift', defaultValue: false)
                as bool,
        alt: _box.get('shortcut_${action.name}_alt', defaultValue: false)
            as bool,
      );
    }
    return result;
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    unawaited(_box.put('themeMode', mode.index));
  }

  void setAccentIndex(int index) {
    state = state.copyWith(accentIndex: index, clearCustomAccent: true);
    unawaited(_box.put('accentIndex', index));
    unawaited(_box.delete('customAccentValue'));
  }

  void setCustomAccentColor(Color color) {
    final value = color.toARGB32();
    state = state.copyWith(customAccentValue: value);
    unawaited(_box.put('customAccentValue', value));
  }

  void setReduceMotion(bool value) {
    state = state.copyWith(reduceMotion: value);
    unawaited(_box.put('reduceMotion', value));
  }

  void setDefaultPriority(TaskPriority priority) {
    state = state.copyWith(defaultPriorityIndex: priority.index);
    unawaited(_box.put('defaultPriorityIndex', priority.index));
  }

  void setDateFormat(DateFormatOption format) {
    state = state.copyWith(dateFormat: format);
    unawaited(_box.put('dateFormat', format.index));
  }

  void setDefaultLanding(LandingScreenOption option) {
    state = state.copyWith(defaultLanding: option);
    unawaited(_box.put('defaultLanding', option.index));
  }

  void setSidebarExpanded(bool expanded) {
    state = state.copyWith(sidebarExpanded: expanded);
    unawaited(_box.put('sidebarExpanded', expanded));
  }

  /// Cycles to the next workspace — see [AppSettings.workspaceIndex].
  void cycleWorkspace() {
    final next = (state.workspaceIndex + 1) % state.workspaceNames.length;
    state = state.copyWith(workspaceIndex: next);
    unawaited(_box.put('workspaceIndex', next));
  }

  void _saveWorkspaces(List<String> names, List<String> ids, int index) {
    state = state.copyWith(
      workspaceNames: names,
      workspaceIds: ids,
      workspaceIndex: index,
    );
    unawaited(_box.put('workspaceNames', names));
    unawaited(_box.put('workspaceIds', ids));
    unawaited(_box.put('workspaceIndex', index));
  }

  /// Adds a new workspace named [name] — a fresh, empty data silo — and
  /// switches to it.
  void addWorkspace(String name) {
    final names = [...state.workspaceNames, name];
    final ids = [...state.workspaceIds, const Uuid().v4()];
    _saveWorkspaces(names, ids, names.length - 1);
  }

  /// Renames the workspace at [index]. Its id (and so its data) is
  /// untouched.
  void renameWorkspace(int index, String name) {
    if (index < 0 || index >= state.workspaceNames.length) return;
    final names = [...state.workspaceNames];
    names[index] = name;
    _saveWorkspaces(names, state.workspaceIds, state.workspaceIndex);
  }

  /// Removes the workspace at [index]. Refuses to drop the last remaining
  /// one — returns false when that guard blocked the removal, true once it
  /// actually happened, so the caller can surface a message either way.
  ///
  /// This only removes the workspace's name/id from these lists — deleting
  /// its projects/tasks/templates is the caller's job (see the sidebar's
  /// workspace context menu), done *before* calling this, while the id is
  /// still around to delete by.
  bool removeWorkspace(int index) {
    if (state.workspaceNames.length <= 1) return false;
    if (index < 0 || index >= state.workspaceNames.length) return false;
    final names = [...state.workspaceNames]..removeAt(index);
    final ids = [...state.workspaceIds]..removeAt(index);
    final newIndex = state.workspaceIndex >= names.length
        ? names.length - 1
        : (state.workspaceIndex > index
              ? state.workspaceIndex - 1
              : state.workspaceIndex);
    _saveWorkspaces(names, ids, newIndex);
    return true;
  }

  /// Rebinds [action] to [binding]. Callers are expected to have already
  /// checked [AppSettings.shortcutOverrides] (via [AppSettings.shortcutFor])
  /// for a duplicate against the app's other shortcuts before calling this —
  /// this method itself doesn't validate, so it can also be used to restore
  /// a backup that (in principle) recorded a conflict.
  void setShortcutBinding(ShortcutAction action, ShortcutBinding binding) {
    state = state.copyWith(
      shortcutOverrides: {...state.shortcutOverrides, action: binding},
    );
    unawaited(_box.put('shortcut_${action.name}_keyId', binding.key.keyId));
    unawaited(
      _box.put('shortcut_${action.name}_cmdOrCtrl', binding.cmdOrCtrl),
    );
    unawaited(_box.put('shortcut_${action.name}_shift', binding.shift));
    unawaited(_box.put('shortcut_${action.name}_alt', binding.alt));
  }

  /// Reverts [action] back to [ShortcutBinding.defaults].
  void resetShortcutBinding(ShortcutAction action) {
    final overrides = {...state.shortcutOverrides}..remove(action);
    state = state.copyWith(shortcutOverrides: overrides);
    unawaited(_box.delete('shortcut_${action.name}_keyId'));
    unawaited(_box.delete('shortcut_${action.name}_cmdOrCtrl'));
    unawaited(_box.delete('shortcut_${action.name}_shift'));
    unawaited(_box.delete('shortcut_${action.name}_alt'));
  }

  /// Records the current screen so a "Last viewed" landing preference can
  /// return to it next launch. Not exposed as user-visible state, so it
  /// updates the box directly without touching [state]/notifying listeners.
  void recordLastViewedScreen(int screenIndex) {
    unawaited(_box.put('lastViewedScreenIndex', screenIndex));
  }

  /// Resets settings to their defaults. Used by Settings > Wipe All Data.
  void resetToDefaults() {
    unawaited(_box.clear());
    state = const AppSettings(
      themeMode: ThemeMode.system,
      accentIndex: 0,
      reduceMotion: false,
    );
  }

  /// Replaces all settings at once. Used when restoring from a backup.
  void restoreAll(AppSettings settings) {
    unawaited(_box.put('themeMode', settings.themeMode.index));
    unawaited(_box.put('accentIndex', settings.accentIndex));
    unawaited(_box.put('reduceMotion', settings.reduceMotion));
    if (settings.customAccentValue != null) {
      unawaited(_box.put('customAccentValue', settings.customAccentValue));
    } else {
      unawaited(_box.delete('customAccentValue'));
    }
    unawaited(
      _box.put('defaultPriorityIndex', settings.defaultPriorityIndex),
    );
    unawaited(_box.put('dateFormat', settings.dateFormat.index));
    unawaited(_box.put('defaultLanding', settings.defaultLanding.index));
    unawaited(_box.put('sidebarExpanded', settings.sidebarExpanded));
    unawaited(_box.put('workspaceIndex', settings.workspaceIndex));
    unawaited(_box.put('workspaceNames', settings.workspaceNames));
    unawaited(_box.put('workspaceIds', settings.workspaceIds));
    unawaited(
      _box.put('lastViewedScreenIndex', settings.lastViewedScreenIndex),
    );
    for (final action in ShortcutAction.values) {
      unawaited(_box.delete('shortcut_${action.name}_keyId'));
      unawaited(_box.delete('shortcut_${action.name}_cmdOrCtrl'));
      unawaited(_box.delete('shortcut_${action.name}_shift'));
      unawaited(_box.delete('shortcut_${action.name}_alt'));
    }
    for (final entry in settings.shortcutOverrides.entries) {
      final binding = entry.value;
      unawaited(
        _box.put('shortcut_${entry.key.name}_keyId', binding.key.keyId),
      );
      unawaited(
        _box.put(
          'shortcut_${entry.key.name}_cmdOrCtrl',
          binding.cmdOrCtrl,
        ),
      );
      unawaited(
        _box.put('shortcut_${entry.key.name}_shift', binding.shift),
      );
      unawaited(_box.put('shortcut_${entry.key.name}_alt', binding.alt));
    }
    state = settings;
  }
}
