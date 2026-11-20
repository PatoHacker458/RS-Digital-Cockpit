import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

/// Notifier para gestionar el Tema Dinámico (Night Stage vs Daylight Cup)
/// Cumplimiento estricto: Gestión 100% reactiva mediante Notifier de Riverpod.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const String _prefKey = 'clio_rs_theme_mode';

  @override
  ThemeMode build() {
    _loadSavedTheme();
    return ThemeMode.dark; // Por defecto inicia en Night Stage (Sagem Amber)
  }

  Future<void> _loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLight = prefs.getBool(_prefKey) ?? false;
      state = isLight ? ThemeMode.light : ThemeMode.dark;
    } catch (_) {
      // Fallback defensivo en caso de error de lectura local
    }
  }

  Future<void> toggleTheme() async {
    final nextMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = nextMode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, nextMode == ThemeMode.light);
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, mode == ThemeMode.light);
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
