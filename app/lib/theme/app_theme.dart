import 'package:flutter/material.dart';

/// One source of truth for the game's visual language.
abstract final class GameColors {
  static const background = Color(0xFF090F18);
  static const backgroundRaised = Color(0xFF101B29);
  static const surface = Color(0xFF172536);
  static const surfaceRaised = Color(0xFF203248);
  static const border = Color(0xFF3B5060);
  static const text = Color(0xFFF5F0E8);
  static const muted = Color(0xFFB8C8D0);
  static const gold = Color(0xFFE9BD75);
  static const health = Color(0xFFF0787A);
  static const energy = Color(0xFF6BDAD4);
  static const ultimate = Color(0xFFC7A8FF);
  static const success = Color(0xFF83D9AD);
  static const warning = Color(0xFFFFC47E);
  static const danger = Color(0xFFFF8489);

  static Color forClass(String id) => switch (id) {
    'warrior' => const Color(0xFFE7B16A),
    'mage' => const Color(0xFF90C9FF),
    'rogue' => const Color(0xFF93DBA5),
    'hunter' => const Color(0xFFDCC381),
    _ => gold,
  };

  static Color forElement(String id) => switch (id) {
    'fire' => const Color(0xFFFF9B70),
    'ice' => const Color(0xFF9DDCF3),
    'earth' => const Color(0xFFB5D49A),
    'electric' => const Color(0xFFF9DB80),
    _ => muted,
  };
}

abstract final class GameLayout {
  static const compact = 600.0;
  static const wide = 960.0;
  static const maxContent = 1180.0;
  static const radius = 20.0;
  static const gap = 16.0;
}

abstract final class GameVisual {
  static String className(String id) => switch (id) {
    'warrior' => 'Guerreiro',
    'mage' => 'Mago',
    'rogue' => 'Ladino',
    'hunter' => 'Hunter',
    _ => id,
  };

  static IconData classIcon(String id) => switch (id) {
    'warrior' => Icons.shield_outlined,
    'mage' => Icons.auto_awesome,
    'rogue' => Icons.bolt_outlined,
    'hunter' => Icons.adjust,
    _ => Icons.person_outline,
  };

  static String elementName(String id) => switch (id) {
    'fire' => 'Fogo',
    'ice' => 'Gelo',
    'earth' => 'Terra',
    'electric' => 'Elétrico',
    _ => 'Neutro',
  };

  static IconData elementIcon(String id) => switch (id) {
    'fire' => Icons.local_fire_department_outlined,
    'ice' => Icons.ac_unit,
    'earth' => Icons.terrain,
    'electric' => Icons.flash_on_outlined,
    _ => Icons.circle_outlined,
  };

  static String statusName(String id) => switch (id) {
    'burn' => 'Queimadura',
    'chilled' => 'Resfriado',
    'shield' => 'Escudo',
    'wet' => 'Encharcado',
    'focused' => 'Concentrado',
    'frozen' => 'Congelado',
    'dodge' => 'Esquiva',
    'prepared' => 'Preparado',
    'poison' => 'Veneno',
    'bleed' => 'Sangramento',
    'marked' => 'Marcado',
    'rooted' => 'Imobilizado',
    'stunned' => 'Atordoado',
    'vulnerable' => 'Vulnerável',
    'counterStance' => 'Contra-ataque',
    'guard' => 'Guarda',
    'taunted' => 'Provocado',
    _ => id,
  };

  static IconData statusIcon(String id) => switch (id) {
    'burn' => Icons.local_fire_department_outlined,
    'frozen' || 'chilled' => Icons.ac_unit,
    'wet' => Icons.water_drop_outlined,
    'bleed' => Icons.bloodtype_outlined,
    'poison' => Icons.science_outlined,
    'guard' || 'shield' => Icons.shield_outlined,
    'marked' => Icons.gps_fixed,
    'dodge' => Icons.directions_run,
    'stunned' => Icons.flash_on_outlined,
    _ => Icons.auto_awesome,
  };

  static Color statusColor(String id) => switch (id) {
    'burn' || 'bleed' => GameColors.health,
    'frozen' || 'chilled' || 'wet' => GameColors.energy,
    'poison' => GameColors.forClass('rogue'),
    'marked' || 'prepared' => GameColors.gold,
    'stunned' || 'vulnerable' => GameColors.warning,
    _ => GameColors.ultimate,
  };

  static String statusDescription(String id) => switch (id) {
    'burn' || 'poison' || 'bleed' => 'Causa dano no início do turno do alvo.',
    'frozen' || 'stunned' => 'Impede a próxima oportunidade de ação.',
    'wet' => 'Interage com ataques de gelo e eletricidade.',
    'dodge' => 'Evita o próximo ataque.',
    'prepared' => 'Habilita críticos condicionais.',
    'marked' => 'Habilita ataques precisos do Hunter.',
    'guard' => 'Reduz o dano recebido.',
    'shield' => 'Absorve dano antes da vida.',
    _ => 'Condição temporária de batalha.',
  };
}

abstract final class GameTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: GameColors.gold,
          brightness: Brightness.dark,
          surface: GameColors.surface,
        ).copyWith(
          primary: GameColors.gold,
          onPrimary: GameColors.background,
          secondary: GameColors.energy,
          onSecondary: GameColors.background,
          error: GameColors.danger,
          onSurface: GameColors.text,
          outline: GameColors.border,
        );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: GameColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: GameColors.background,
        foregroundColor: GameColors.text,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: GameColors.text,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: GameColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: GameColors.border, width: 0.8),
          borderRadius: BorderRadius.circular(GameLayout.radius),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          color: GameColors.text,
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
        headlineMedium: const TextStyle(
          color: GameColors.text,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        headlineSmall: const TextStyle(
          color: GameColors.text,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: const TextStyle(
          color: GameColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: const TextStyle(
          color: GameColors.text,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: const TextStyle(
          color: GameColors.text,
          fontSize: 16,
          height: 1.4,
        ),
        bodyMedium: const TextStyle(
          color: GameColors.muted,
          fontSize: 14,
          height: 1.4,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GameColors.gold,
          foregroundColor: GameColors.background,
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: GameColors.text,
          side: const BorderSide(color: GameColors.border),
          minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: GameColors.gold,
          minimumSize: const Size(48, 48),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GameColors.backgroundRaised,
        labelStyle: const TextStyle(color: GameColors.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GameColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GameColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GameColors.gold, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: GameColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GameLayout.radius),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: GameColors.surfaceRaised,
        contentTextStyle: const TextStyle(color: GameColors.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: GameColors.gold,
        linearTrackColor: GameColors.backgroundRaised,
        circularTrackColor: GameColors.backgroundRaised,
      ),
      dividerColor: GameColors.border,
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: GameColors.surfaceRaised,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: GameColors.text),
      ),
    );
  }
}
