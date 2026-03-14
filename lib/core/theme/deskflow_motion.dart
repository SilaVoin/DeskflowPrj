import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class DeskflowMotionTheme extends ThemeExtension<DeskflowMotionTheme> {
  const DeskflowMotionTheme({
    required this.animationsEnabled,
    this.microDuration = DeskflowMotion.microDuration,
    this.regularDuration = DeskflowMotion.regularDuration,
    this.overlayDuration = DeskflowMotion.overlayDuration,
    this.emphasizedCurve = Curves.easeOutCubic,
    this.standardCurve = Curves.easeOut,
  });

  final bool animationsEnabled;
  final Duration microDuration;
  final Duration regularDuration;
  final Duration overlayDuration;
  final Curve emphasizedCurve;
  final Curve standardCurve;

  Duration durationFor(Duration normal) {
    return DeskflowMotion.effectiveDuration(
      enabled: animationsEnabled,
      normal: normal,
    );
  }

  static DeskflowMotionTheme of(BuildContext context) {
    return Theme.of(context).extension<DeskflowMotionTheme>() ??
        const DeskflowMotionTheme(animationsEnabled: true);
  }

  @override
  ThemeExtension<DeskflowMotionTheme> copyWith({
    bool? animationsEnabled,
    Duration? microDuration,
    Duration? regularDuration,
    Duration? overlayDuration,
    Curve? emphasizedCurve,
    Curve? standardCurve,
  }) {
    return DeskflowMotionTheme(
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      microDuration: microDuration ?? this.microDuration,
      regularDuration: regularDuration ?? this.regularDuration,
      overlayDuration: overlayDuration ?? this.overlayDuration,
      emphasizedCurve: emphasizedCurve ?? this.emphasizedCurve,
      standardCurve: standardCurve ?? this.standardCurve,
    );
  }

  @override
  ThemeExtension<DeskflowMotionTheme> lerp(
    covariant ThemeExtension<DeskflowMotionTheme>? other,
    double t,
  ) {
    if (other is! DeskflowMotionTheme) {
      return this;
    }

    return DeskflowMotionTheme(
      animationsEnabled: t < 0.5 ? animationsEnabled : other.animationsEnabled,
      microDuration: _lerpDuration(microDuration, other.microDuration, t),
      regularDuration: _lerpDuration(
        regularDuration,
        other.regularDuration,
        t,
      ),
      overlayDuration: _lerpDuration(
        overlayDuration,
        other.overlayDuration,
        t,
      ),
      emphasizedCurve: t < 0.5 ? emphasizedCurve : other.emphasizedCurve,
      standardCurve: t < 0.5 ? standardCurve : other.standardCurve,
    );
  }

  static Duration _lerpDuration(Duration a, Duration b, double t) {
    return Duration(
      microseconds: lerpDouble(
        a.inMicroseconds.toDouble(),
        b.inMicroseconds.toDouble(),
        t,
      )!
          .round(),
    );
  }
}

class DeskflowMotion {
  DeskflowMotion._();

  static const Duration microDuration = Duration(milliseconds: 180);
  static const Duration regularDuration = Duration(milliseconds: 220);
  static const Duration overlayDuration = Duration(milliseconds: 260);

  static bool resolveAnimationsEnabled({
    required bool platformDisableAnimations,
    required bool userDisableAnimations,
  }) {
    return !platformDisableAnimations && !userDisableAnimations;
  }

  static Duration effectiveDuration({
    required bool enabled,
    required Duration normal,
  }) {
    return enabled ? normal : Duration.zero;
  }
}
