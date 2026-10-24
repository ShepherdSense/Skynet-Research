import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A hue-rotate color matrix (the SVG feColorMatrix hueRotate
/// approximation) for use with [ColorFilter.matrix]. Rotating by
/// 0° is the identity. Used to re-hue the banner drone artwork so
/// it follows the user's colorway: at the default hue the rotation
/// is zero and the artwork shows exactly as designed.
List<double> hueRotateMatrix(double degrees) {
  final rad = degrees * math.pi / 180;
  final c = math.cos(rad);
  final s = math.sin(rad);
  return <double>[
    0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715,
    0.072 - c * 0.072 + s * 0.928, 0, 0,
    0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140,
    0.072 - c * 0.072 - s * 0.283, 0, 0,
    0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715,
    0.072 + c * 0.928 + s * 0.072, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// Draco's house style: super-clean, minimal, dark, purple accents.
/// The accent family is hue-driven: the default hue (262°) is the
/// violet of the light trail streaming off the banner drone,
/// sampled from the artwork; users can re-hue the whole app from
/// the color slider at the bottom of the landing page
/// (Draco, 2026-10-23).
class PlainRegsTheme {
  /// Current colorway hue, 0–360. Set by [ThemeHueController].
  static double hueDeg = 262;

  static Color get accent => HSLColor.fromAHSL(1, hueDeg, 0.85, 0.72).toColor();
  static const Color background = Color(0xFF121016);
  static const Color surface = Color(0xFF1C1924);
  static const Color surfaceHigh = Color(0xFF272233);

  /// The button color everywhere: the colorway hue, transparent.
  static Color get buttonPurple =>
      HSLColor.fromAHSL(0.55, hueDeg, 0.55, 0.64).toColor();
  static Color get buttonPurpleSoft =>
      HSLColor.fromAHSL(0.38, hueDeg, 0.55, 0.64).toColor();

  /// Pale tint of the colorway, for text on outlined buttons.
  static Color get accentTint =>
      HSLColor.fromAHSL(1, hueDeg, 0.9, 0.87).toColor();

  /// Hue rotation that carries the banner drone's trail (violet at
  /// the default hue) to the user's chosen colorway. Identity at
  /// the default, so the artwork is untouched until the user
  /// actually moves the slider.
  static List<double> get droneHueMatrix =>
      hueRotateMatrix(hueDeg - ThemeHueController.defaultHue);

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: surface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: buttonPurple,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: buttonPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentTint,
          side: BorderSide(color: buttonPurple),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: buttonPurpleSoft,
        selectedColor: buttonPurple,
        labelStyle: const TextStyle(color: Colors.white),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? buttonPurple
                : surfaceHigh,
          ),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
        ),
      ),
      // Smooth, cool transitions on every push (Draco, 2026-10-23).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SmoothPageTransitionsBuilder(),
          TargetPlatform.iOS: _SmoothPageTransitionsBuilder(),
          TargetPlatform.windows: _SmoothPageTransitionsBuilder(),
          TargetPlatform.macOS: _SmoothPageTransitionsBuilder(),
          TargetPlatform.linux: _SmoothPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _SmoothPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Owns the user's colorway hue: loads/saves it and notifies the
/// app shell so the whole theme re-hues live.
class ThemeHueController extends ChangeNotifier {
  static const String _key = 'ui_hue_v1';

  /// The banner drone's trail violet — the default colorway.
  static const double defaultHue = 262;

  double hue = defaultHue;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_key);
    if (saved != null && saved != hue) {
      hue = saved.clamp(0, 360);
      notifyListeners();
    }
  }

  void setHue(double value, {bool save = true}) {
    hue = value.clamp(0, 360);
    notifyListeners();
    if (save) {
      SharedPreferences.getInstance().then((p) => p.setDouble(_key, hue));
    }
  }
}

/// Fade + gentle rise — the app's standard page transition.
class _SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
