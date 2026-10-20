import 'package:flutter/material.dart';

/// Every color the app uses, for light and dark. Widgets read these through
/// `context.palette` or the `ColorScheme` built from them, never as literals.
///
/// A cool, blue-first palette. Changed from the design brief to reach 4.5:1
/// text contrast in light mode: secondary #0EA5E9 → #0369A1, tertiary
/// #0D9488 → #0F766E and muted #64748B → #5B6B80.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.tertiary,
    required this.onTertiary,
    required this.background,
    required this.surface,
    required this.drawer,
    required this.userBubble,
    required this.inputFill,
    required this.border,
    required this.text,
    required this.muted,
    required this.warning,
    required this.warningBackground,
    required this.error,
    required this.onError,
    required this.codeBackground,
    required this.codeText,
  });

  static const light = AppPalette(
    primary: Color(0xFF2563EB),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF0369A1),
    onSecondary: Color(0xFFFFFFFF),
    tertiary: Color(0xFF0F766E),
    onTertiary: Color(0xFFFFFFFF),
    background: Color(0xFFF7F9FC),
    surface: Color(0xFFFFFFFF),
    drawer: Color(0xFFEEF2F8),
    userBubble: Color(0xFFE3ECFB),
    inputFill: Color(0xFFEEF2F8),
    border: Color(0xFFDCE3EE),
    text: Color(0xFF0F172A),
    muted: Color(0xFF5B6B80),
    warning: Color(0xFFB45309),
    warningBackground: Color(0xFFFFF7E6),
    error: Color(0xFFDC2626),
    onError: Color(0xFFFFFFFF),
    codeBackground: Color(0xFF0F172A),
    codeText: Color(0xFFE2E8F0),
  );

  static const dark = AppPalette(
    primary: Color(0xFF60A5FA),
    onPrimary: Color(0xFF0B1220),
    secondary: Color(0xFF38BDF8),
    onSecondary: Color(0xFF0B1220),
    tertiary: Color(0xFF2DD4BF),
    onTertiary: Color(0xFF0B1220),
    background: Color(0xFF0B1220),
    surface: Color(0xFF111A2E),
    drawer: Color(0xFF0E1626),
    userBubble: Color(0xFF1C2B4A),
    inputFill: Color(0xFF1A2338),
    border: Color(0xFF24314D),
    text: Color(0xFFE2E8F0),
    muted: Color(0xFF94A3B8),
    warning: Color(0xFFFBBF24),
    warningBackground: Color(0xFF2A2212),
    error: Color(0xFFF87171),
    onError: Color(0xFF0B1220),
    codeBackground: Color(0xFF0A0F1C),
    codeText: Color(0xFFE2E8F0),
  );

  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;

  /// Success and the Approve button.
  final Color tertiary;
  final Color onTertiary;
  final Color background;
  final Color surface;
  final Color drawer;
  final Color userBubble;
  final Color inputFill;
  final Color border;
  final Color text;
  final Color muted;

  /// Approval prompts: [warning] text on [warningBackground].
  final Color warning;
  final Color warningBackground;

  /// Errors and the Deny button.
  final Color error;
  final Color onError;
  final Color codeBackground;
  final Color codeText;

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      secondary: mix(secondary, other.secondary),
      onSecondary: mix(onSecondary, other.onSecondary),
      tertiary: mix(tertiary, other.tertiary),
      onTertiary: mix(onTertiary, other.onTertiary),
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      drawer: mix(drawer, other.drawer),
      userBubble: mix(userBubble, other.userBubble),
      inputFill: mix(inputFill, other.inputFill),
      border: mix(border, other.border),
      text: mix(text, other.text),
      muted: mix(muted, other.muted),
      warning: mix(warning, other.warning),
      warningBackground: mix(warningBackground, other.warningBackground),
      error: mix(error, other.error),
      onError: mix(onError, other.onError),
      codeBackground: mix(codeBackground, other.codeBackground),
      codeText: mix(codeText, other.codeText),
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
