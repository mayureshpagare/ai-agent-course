import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/session_controller.dart';

/// System, light or dark. Follows the system until the user picks one.
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.values.asNameMap()[ref.read(settingsStoreProvider).themeMode] ?? ThemeMode.system;

  void set(ThemeMode mode) {
    state = mode;
    ref.read(settingsStoreProvider).setThemeMode(mode.name).ignore();
  }
}
