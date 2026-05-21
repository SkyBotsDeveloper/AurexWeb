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
    background: Color(0xFF07080D),
    backgroundSecondary: Color(0xFF10131B),
    surface: Color(0xFF11141C),
    surfaceElevated: Color(0xFF181D27),
    surfaceBright: Color(0xFF232A36),
    surfaceMuted: Color(0xFF202734),
    surfaceInset: Color(0xFF121722),
    border: Color(0xFF2D3442),
    accent: Color(0xFFFF4D8D),
    accentStrong: Color(0xFF38BDF8),
    accentSoft: Color(0x33FF4D8D),
    glow: Color(0x45FF4D8D),
    textPrimary: Color(0xFFF7F8FC),
    textSecondary: Color(0xFFB2B8C8),
    success: Color(0xFF34D399),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    shadow: Color(0x66000000),
    panelTop: Color(0xF21B2230),
    panelMid: Color(0xEA171B25),
    panelBottom: Color(0xE60F121A),
    navTop: Color(0xF21C2330),
    navBottom: Color(0xEE111620),
    tileTop: Color(0xFF202735),
    tileBottom: Color(0xFF151A24),
    ambientTopGlow: Color(0x22FF4D8D),
    ambientRightGlow: Color(0x1F38BDF8),
    ambientBottomGlow: Color(0x1FF59E0B),
  );

  static const light = AurexPalette(
    background: Color(0xFFF7F8FB),
    backgroundSecondary: Color(0xFFEFEFF7),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFBFCFF),
    surfaceBright: Color(0xFFE8EAF3),
    surfaceMuted: Color(0xFFE2E6EF),
    surfaceInset: Color(0xFFF1F3F8),
    border: Color(0xFFD9DEEA),
    accent: Color(0xFFD6336C),
    accentStrong: Color(0xFF2563EB),
    accentSoft: Color(0x24D6336C),
    glow: Color(0x2ED6336C),
    textPrimary: Color(0xFF121722),
    textSecondary: Color(0xFF5E6472),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    shadow: Color(0x1F1F2937),
    panelTop: Color(0xFFFFFFFF),
    panelMid: Color(0xFFFAFBFF),
    panelBottom: Color(0xFFF0F2F8),
    navTop: Color(0xFFFFFFFF),
    navBottom: Color(0xFFF0F2F8),
    tileTop: Color(0xFFFFFFFF),
    tileBottom: Color(0xFFF0F2F8),
    ambientTopGlow: Color(0x20D6336C),
    ambientRightGlow: Color(0x1F2563EB),
    ambientBottomGlow: Color(0x1AF59E0B),
  );

  static AurexPalette of(BuildContext context) {
    return Theme.of(context).extension<AurexPalette>() ?? dark;
  }
}
