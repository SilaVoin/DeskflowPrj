import 'package:flutter/material.dart';

/// Deskflow Liquid Glass color palette.
///
/// All colors are designed for AMOLED dark backgrounds (#000000)
/// with translucent glass overlays.
class DeskflowColors {
  DeskflowColors._();

  // ─── Backgrounds ──────────────────────────────────────────
  /// Pure black AMOLED background.
  static const Color background = Color(0xFF000000);

  // ─── Glass surfaces ───────────────────────────────────────
  /// Default glass surface fill.
  static const Color glassSurface = Color(0x14FFFFFF); // rgba(255,255,255,0.08)

  /// Glass surface — elevated (modals, sheets).
  static const Color glassSurfaceElevated = Color(0x1FFFFFFF); // ~0.12

  /// Glass border color.
  static const Color glassBorder = Color(0x26FFFFFF); // rgba(255,255,255,0.15)

  /// Glass specular highlight (top edge).
  static const Color glassHighlight = Color(0x33FFFFFF); // ~0.20

  /// Modal / bottom sheet surface — nearly opaque dark to prevent text bleed-through.
  ///
  /// Uses Apple UIKit dark-mode sheet color (#1C1C1E) at 96% opacity.
  static const Color modalSurface = Color(0xF51C1C1E);

  // ─── Actions ──────────────────────────────────────────────
  /// Primary action blue glass.
  static const Color primary = Color(0x99007AFF); // rgba(0,122,255,0.6)
  static const Color primarySolid = Color(0xFF007AFF);

  /// Destructive red glass.
  static const Color destructive = Color(0x99FF3B30); // rgba(255,59,48,0.6)
  static const Color destructiveSolid = Color(0xFFFF3B30);

  /// Success green glass.
  static const Color success = Color(0x9934C759); // rgba(52,199,89,0.6)
  static const Color successSolid = Color(0xFF34C759);

  /// Warning yellow glass.
  static const Color warning = Color(0x99FFCC00); // rgba(255,204,0,0.6)
  static const Color warningSolid = Color(0xFFFFCC00);

  // ─── Text ─────────────────────────────────────────────────
  /// Primary text — white.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Secondary text — light gray.
  static const Color textSecondary = Color(0x99FFFFFF); // rgba(255,255,255,0.6)

  /// Tertiary text — dim gray.
  static const Color textTertiary = Color(0x59FFFFFF); // rgba(255,255,255,0.35)

  /// Disabled text.
  static const Color textDisabled = Color(0x33FFFFFF); // ~0.20
}

/// Deskflow Liquid Glass text styles.
///
/// Uses system font (SF Pro on iOS, Roboto on Android)
/// as specified in the design spec.
class DeskflowTypography {
  DeskflowTypography._();

  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: DeskflowColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: DeskflowColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: DeskflowColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: DeskflowColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: DeskflowColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: DeskflowColors.textTertiary,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: DeskflowColors.textPrimary,
  );

  static const TextStyle badge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: DeskflowColors.textPrimary,
  );
}

/// Deskflow spacing constants.
class DeskflowSpacing {
  DeskflowSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Deskflow border radius constants.
///
/// Uses continuous curvature (squircle-like) via [borderRadius].
class DeskflowRadius {
  DeskflowRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 100; // Capsule / stadium shape
}

/// Builds the Deskflow Liquid Glass [ThemeData].
ThemeData buildDeskflowTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: DeskflowColors.background,
    colorScheme: const ColorScheme.dark(
      primary: DeskflowColors.primarySolid,
      onPrimary: DeskflowColors.textPrimary,
      secondary: DeskflowColors.primary,
      surface: DeskflowColors.background,
      error: DeskflowColors.destructiveSolid,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: DeskflowTypography.h3,
      iconTheme: IconThemeData(color: DeskflowColors.textPrimary),
    ),
    textTheme: const TextTheme(
      headlineLarge: DeskflowTypography.h1,
      headlineMedium: DeskflowTypography.h2,
      headlineSmall: DeskflowTypography.h3,
      bodyLarge: DeskflowTypography.body,
      bodyMedium: DeskflowTypography.bodySmall,
      bodySmall: DeskflowTypography.caption,
      labelLarge: DeskflowTypography.button,
      labelSmall: DeskflowTypography.badge,
    ),
    dividerTheme: const DividerThemeData(
      color: DeskflowColors.glassBorder,
      thickness: 0.5,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      // [FIX] Use modalSurface (opaque dark) to prevent background bleed-through.
      backgroundColor: DeskflowColors.modalSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DeskflowRadius.xl),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      // [FIX] Use modalSurface for dialogs too.
      backgroundColor: DeskflowColors.modalSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DeskflowRadius.lg),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: DeskflowColors.glassSurfaceElevated,
      contentTextStyle: DeskflowTypography.bodySmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DeskflowRadius.md),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
