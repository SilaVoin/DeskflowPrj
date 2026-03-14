import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_motion.dart';

class DeskflowColors {
  DeskflowColors._();

  static const Color background = Color(0xFF000000);
  static const Color backgroundBase = Color(0xFF050608);
  static const Color backgroundRaised = Color(0xFF0B0E12);
  static const Color auroraPurple = Color(0xFF7D39FF);
  static const Color auroraViolet = Color(0xFFC487FF);
  static const Color auroraBlue = Color(0xFF66B8FF);
  static const Color auroraHalo = Color(0xFFF5EEFF);

  static const Color glassSurface = Color(0x96141820);

  static const Color glassSurfaceElevated = Color(0xB61A1F28);
  static const Color shellGlassSurface = Color(0xA8181C24);
  static const Color shellGlassSurfaceFocused = Color(0xC21A1F28);

  static const Color glassBorder = Color(0x2EE2E8EF);
  static const Color glassBorderStrong = Color(0x52F5F8FC);

  static const Color glassHighlight = Color(0x52FFFFFF);
  static const Color glassGlow = Color(0x1FD8E2EC);

  static const Color modalSurface = Color(0xCC13161B);
  static const Color modalBackdrop = Color(0x7A020304);

  static const Color primary = Color(0x66DCE5F0);
  static const Color primarySolid = Color(0xFFE4EDF7);
  static const Color primaryGlow = Color(0x66C8D3DE);

  static const Color destructive = Color(0x99FF5D52);
  static const Color destructiveSolid = Color(0xFFFF3B30);

  static const Color success = Color(0x9952D18A);
  static const Color successSolid = Color(0xFF52D18A);

  static const Color warning = Color(0x99F1C77A);
  static const Color warningSolid = Color(0xFFF1C77A);

  static const Color textPrimary = Color(0xFFF6F8FB);

  static const Color textSecondary = Color(0xBFE0E5EB);

  static const Color textTertiary = Color(0x8C9CA8B3);

  static const Color textDisabled = Color(0x4C99A4AE);
}

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

class DeskflowRadius {
  DeskflowRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 100; // Capsule / stadium shape
  static const double card = 20;
  static const double field = 18;
  static const double overlay = 28;
  static const double nav = 26;
}

ThemeData buildDeskflowTheme({bool animationsEnabled = true}) {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: DeskflowColors.backgroundBase,
    colorScheme: const ColorScheme.dark(
      primary: DeskflowColors.primarySolid,
      onPrimary: DeskflowColors.textPrimary,
      secondary: DeskflowColors.primary,
      surface: DeskflowColors.backgroundRaised,
      error: DeskflowColors.destructiveSolid,
    ),
    extensions: <ThemeExtension<dynamic>>[
      DeskflowMotionTheme(animationsEnabled: animationsEnabled),
    ],
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
      backgroundColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DeskflowRadius.overlay),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: DeskflowColors.modalSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DeskflowRadius.overlay),
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
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: DeskflowColors.glassSurfaceElevated,
      foregroundColor: DeskflowColors.textPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      disabledElevation: 0,
      shape: CircleBorder(),
    ),
  );
}
