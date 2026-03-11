import 'package:flutter/material.dart';

@immutable
class AurexPalette extends ThemeExtension<AurexPalette> {
  const AurexPalette({
    required this.background,
    required this.backgroundSecondary,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceBright,
    required this.surfaceMuted,
    required this.surfaceInset,
    required this.border,
    required this.accent,
    required this.accentStrong,
    required this.accentSoft,
    required this.glow,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.shadow,
    required this.panelTop,
    required this.panelMid,
    required this.panelBottom,
    required this.navTop,
    required this.navBottom,
    required this.tileTop,
    required this.tileBottom,
    required this.ambientTopGlow,
    required this.ambientRightGlow,
    required this.ambientBottomGlow,
  });

  final Color background;
  final Color backgroundSecondary;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceBright;
  final Color surfaceMuted;
  final Color surfaceInset;
  final Color border;
  final Color accent;
  final Color accentStrong;
  final Color accentSoft;
  final Color glow;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color shadow;
  final Color panelTop;
  final Color panelMid;
  final Color panelBottom;
  final Color navTop;
  final Color navBottom;
  final Color tileTop;
  final Color tileBottom;
  final Color ambientTopGlow;
  final Color ambientRightGlow;
  final Color ambientBottomGlow;

  LinearGradient get backgroundGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, backgroundSecondary, background],
  );

  LinearGradient get panelGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [panelTop, panelMid, panelBottom],
  );

  LinearGradient get navGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [navTop, navBottom],
  );

  LinearGradient get tileGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tileTop, tileBottom],
  );

  @override
  AurexPalette copyWith({
    Color? background,
    Color? backgroundSecondary,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceBright,
    Color? surfaceMuted,
    Color? surfaceInset,
    Color? border,
    Color? accent,
    Color? accentStrong,
    Color? accentSoft,
    Color? glow,
    Color? textPrimary,
    Color? textSecondary,
    Color? success,
    Color? warning,
    Color? danger,
    Color? shadow,
    Color? panelTop,
    Color? panelMid,
    Color? panelBottom,
    Color? navTop,
    Color? navBottom,
    Color? tileTop,
    Color? tileBottom,
    Color? ambientTopGlow,
    Color? ambientRightGlow,
    Color? ambientBottomGlow,
  }) {
    return AurexPalette(
      background: background ?? this.background,
      backgroundSecondary: backgroundSecondary ?? this.backgroundSecondary,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceBright: surfaceBright ?? this.surfaceBright,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceInset: surfaceInset ?? this.surfaceInset,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      accentStrong: accentStrong ?? this.accentStrong,
      accentSoft: accentSoft ?? this.accentSoft,
      glow: glow ?? this.glow,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      shadow: shadow ?? this.shadow,
      panelTop: panelTop ?? this.panelTop,
      panelMid: panelMid ?? this.panelMid,
      panelBottom: panelBottom ?? this.panelBottom,
      navTop: navTop ?? this.navTop,
      navBottom: navBottom ?? this.navBottom,
      tileTop: tileTop ?? this.tileTop,
      tileBottom: tileBottom ?? this.tileBottom,
      ambientTopGlow: ambientTopGlow ?? this.ambientTopGlow,
      ambientRightGlow: ambientRightGlow ?? this.ambientRightGlow,
      ambientBottomGlow: ambientBottomGlow ?? this.ambientBottomGlow,
    );
  }

  @override
  AurexPalette lerp(ThemeExtension<AurexPalette>? other, double t) {
    if (other is! AurexPalette) {
      return this;
    }
    return AurexPalette(
      background: Color.lerp(background, other.background, t)!,
      backgroundSecondary: Color.lerp(
        backgroundSecondary,
        other.backgroundSecondary,
        t,
      )!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceBright: Color.lerp(surfaceBright, other.surfaceBright, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceInset: Color.lerp(surfaceInset, other.surfaceInset, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      panelTop: Color.lerp(panelTop, other.panelTop, t)!,
      panelMid: Color.lerp(panelMid, other.panelMid, t)!,
      panelBottom: Color.lerp(panelBottom, other.panelBottom, t)!,
      navTop: Color.lerp(navTop, other.navTop, t)!,
      navBottom: Color.lerp(navBottom, other.navBottom, t)!,
      tileTop: Color.lerp(tileTop, other.tileTop, t)!,
      tileBottom: Color.lerp(tileBottom, other.tileBottom, t)!,
      ambientTopGlow: Color.lerp(ambientTopGlow, other.ambientTopGlow, t)!,
      ambientRightGlow: Color.lerp(
        ambientRightGlow,
        other.ambientRightGlow,
        t,
      )!,
      ambientBottomGlow: Color.lerp(
        ambientBottomGlow,
        other.ambientBottomGlow,
        t,
      )!,
    );
  }
}

class AppColors {
  static const dark = AurexPalette(
    background: Color(0xFF05070A),
    backgroundSecondary: Color(0xFF081019),
    surface: Color(0xFF0B1016),
    surfaceElevated: Color(0xFF121A24),
    surfaceBright: Color(0xFF182434),
    surfaceMuted: Color(0xFF1A2430),
    surfaceInset: Color(0xFF0F1620),
    border: Color(0xFF223040),
    accent: Color(0xFF7DD3FC),
    accentStrong: Color(0xFF38BDF8),
    accentSoft: Color(0x3327B4F5),
    glow: Color(0x6638BDF8),
    textPrimary: Color(0xFFF5F7FA),
    textSecondary: Color(0xFF9FB0C2),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFFB7185),
    shadow: Color(0x66000000),
    panelTop: Color(0xF0182434),
    panelMid: Color(0xE0121A24),
    panelBottom: Color(0xE60C1118),
    navTop: Color(0xF2192533),
    navBottom: Color(0xEE0F1620),
    tileTop: Color(0xFF182434),
    tileBottom: Color(0xFF111A24),
    ambientTopGlow: Color(0x3D38BDF8),
    ambientRightGlow: Color(0x1E7DD3FC),
    ambientBottomGlow: Color(0x1827B4F5),
  );

  static const light = AurexPalette(
    background: Color(0xFFF5F8FC),
    backgroundSecondary: Color(0xFFEAF1F8),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF7FBFF),
    surfaceBright: Color(0xFFE3EEF8),
    surfaceMuted: Color(0xFFDDE9F5),
    surfaceInset: Color(0xFFF0F5FA),
    border: Color(0xFFD2DFEC),
    accent: Color(0xFF3BA7F6),
    accentStrong: Color(0xFF1F8FE4),
    accentSoft: Color(0x1F2D9CDB),
    glow: Color(0x403BA7F6),
    textPrimary: Color(0xFF0E1726),
    textSecondary: Color(0xFF5D6B7D),
    success: Color(0xFF22C55E),
    warning: Color(0xFFD97706),
    danger: Color(0xFFE11D48),
    shadow: Color(0x1A23405C),
    panelTop: Color(0xFFFFFFFF),
    panelMid: Color(0xFFF7FBFF),
    panelBottom: Color(0xFFEAF2F9),
    navTop: Color(0xFFF8FBFF),
    navBottom: Color(0xFFEAF2F8),
    tileTop: Color(0xFFF9FCFF),
    tileBottom: Color(0xFFEAF2F8),
    ambientTopGlow: Color(0x334FB7F7),
    ambientRightGlow: Color(0x224CB3F6),
    ambientBottomGlow: Color(0x183BA7F6),
  );

  static AurexPalette of(BuildContext context) {
    return Theme.of(context).extension<AurexPalette>() ?? dark;
  }
}
