import 'package:flutter/material.dart';

import 'ai/audio.dart';
import 'ai/brain.dart';
import 'ai/engines.dart';
import 'ai/model_files.dart';
import 'ai/speech.dart';
import 'explore/plant_eyes.dart';
import 'explore/plants.dart';
import 'game/progress.dart';

/// Shared, long-lived objects. Filled in by the setup screen.
class Services {
  Services._();
  static final instance = Services._();

  final progress = Progress();
  late ModelFiles files;
  late Speech speech;
  late Brain brain;
  late Audio audio;
  late Ears ears;
  late Mouth mouth;
  late PlantEyes plantEyes;
  late PlantCatalog plants;
}

Services get services => Services.instance;

abstract final class Palette {
  static const cream = Color(0xFFFFF6E5);
  static const celeste = Color(0xFF74ACDF);
  static const celesteDark = Color(0xFF3F7FBF);
  static const caramel = Color(0xFFC68642);
  static const coral = Color(0xFFFF7F6B);
  static const leaf = Color(0xFF5DB075);
  static const ink = Color(0xFF3B2A1E);
  static const sun = Color(0xFFFFC94D);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Palette.celeste,
      primary: Palette.celesteDark,
      secondary: Palette.coral,
      surface: Palette.cream,
    ),
    scaffoldBackgroundColor: Palette.cream,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: Palette.ink,
      displayColor: Palette.ink,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
  );
}

/// White rounded card with a soft shadow, used all over the game.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    // Material so ListTiles and ink splashes inside the card render.
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class Stars extends StatelessWidget {
  const Stars(this.count, {super.key, this.size = 22});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 3; i++)
        Icon(
          i < count ? Icons.star_rounded : Icons.star_outline_rounded,
          color: i < count ? Palette.sun : Colors.black26,
          size: size,
        ),
    ],
  );
}
