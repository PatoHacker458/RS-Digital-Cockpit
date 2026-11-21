import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

/// Notifier para gestionar el Tema Dinámico (Night Stage, Daylight Cup o Auto del Sistema Android)
/// Cumplimiento estricto: Gestión 100% reactiva mediante Notifier de Riverpod.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const String _legacyPrefKey = 'clio_rs_theme_mode';
  static const String _prefModeKey = 'clio_rs_theme_mode_v2';

  @override
  ThemeMode build() {
    _loadSavedTheme();
    return ThemeMode.dark;
  }

  Future<void> _loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_prefModeKey);
      if (savedMode != null) {
        switch (savedMode) {
          case 'system':
            state = ThemeMode.system;
            return;
          case 'light':
            state = ThemeMode.light;
            return;
          case 'dark':
            state = ThemeMode.dark;
            return;
        }
      }

      if (prefs.containsKey(_legacyPrefKey)) {
        final isLight = prefs.getBool(_legacyPrefKey) ?? false;
        final migrated = isLight ? ThemeMode.light : ThemeMode.dark;
        state = migrated;
        await prefs.setString(_prefModeKey, migrated.name);
      }
    } catch (_) {
      // Fallback defensivo en caso de error de lectura local
    }
  }

  Future<void> toggleTheme() async {
    final nextMode = switch (state) {
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.light => ThemeMode.system,
      ThemeMode.system => ThemeMode.dark,
    };
    await setThemeMode(nextMode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefModeKey, mode.name);
      if (mode != ThemeMode.system) {
        await prefs.setBool(_legacyPrefKey, mode == ThemeMode.light);
      }
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Notifier para el Skin de los Relojes (Sagem 2004, Ragnotti Cup, Clio V6)
class ClusterSkinNotifier extends Notifier<ClusterSkinEdition> {
  static const String _skinPrefKey = 'rs_active_cluster_skin';

  @override
  ClusterSkinEdition build() {
    _loadSavedSkin();
    return ClusterSkinEdition.sagem2004Phase2;
  }

  Future<void> _loadSavedSkin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString(_skinPrefKey);
      if (savedName != null) {
        final match = ClusterSkinEdition.values.where((s) => s.name == savedName);
        if (match.isNotEmpty) {
          state = match.first;
        }
      }
    } catch (_) {}
  }

  Future<void> selectSkin(ClusterSkinEdition skin) async {
    state = skin;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_skinPrefKey, skin.name);
    } catch (_) {}
  }
}

final clusterSkinProvider = NotifierProvider<ClusterSkinNotifier, ClusterSkinEdition>(
  ClusterSkinNotifier.new,
);
