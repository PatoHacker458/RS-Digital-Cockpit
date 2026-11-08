import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta cromática y tipográfica oficial:
/// "RENAULT SPORT 2004 PHASE 2 REFORGED"
/// Inspirada en los instrumentos analógicos Sagem del Clio II RS 172 (2004).
class RenaultSportPalette {
  const RenaultSportPalette._();

  // ===========================================================================
  // MODO OSCURO: "Night Stage / Sagem Amber & Anthracite"
  // ===========================================================================
  static const Color nightCarbonBg = Color(0xFF0F1115);
  static const Color speedlineTuriniAnthracite = Color(0xFF1C2026);
  static const Color speedlineCardBorder = Color(0xFF2D333F);
  static const Color sagemAmberOrange = Color(0xFFFF6B00);
  static const Color siriusLiquidYellow = Color(0xFFFFD100);
  static const Color oemShiftGreen = Color(0xFF00FF66);
  static const Color revLimiterRed = Color(0xFFFF1E42);
  static const Color coldEngineAmber = Color(0xFFFFB000);

  // ===========================================================================
  // MODO CLARO: "Daylight Cup / Iceberg Silver & Mondial Blue"
  // ===========================================================================
  static const Color icebergSilverBg = Color(0xFFE8ECEF);
  static const Color pureCabinWhite = Color(0xFFFFFFFF);
  static const Color daylightBorder = Color(0xFFCBD5E1);
  static const Color mondialBlue = Color(0xFF0038A8);
  static const Color cupNeedleRed = Color(0xFFE11D48);
  static const Color daylightShiftGreen = Color(0xFF059669);
}

/// Skins de instrumentos desbloqueables (Plan RS Trophy Pro)
enum ClusterSkinEdition {
  sagem2004Phase2('Sagem OEM 2004 Phase 2', Color(0xFFFF6B00), Color(0xFFFFD100)),
  jeanRagnottiCup('172 Cup / Jean Ragnotti Edition', Color(0xFF0055FF), Color(0xFFFF1E42)),
  clioV6Trophy('Clio V6 255 Phase 2 Titanium', Color(0xFFFFD100), Color(0xFF00E5FF));

  final String label;
  final Color primaryDialColor;
  final Color needleColor;
  const ClusterSkinEdition(this.label, this.primaryDialColor, this.needleColor);
}

class AppTheme {
  const AppTheme._();

  /// Estilo numérico tabular obligatorio (`FontFeature.tabularFigures()`)
  /// Evita que los dígitos del tacómetro y telemetría tiemblen a 120 FPS.
  static TextStyle telemetryNumericStyle({
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = 0.8,
  }) {
    return GoogleFonts.chakraPetch(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: const <FontFeature>[
        FontFeature.tabularFigures(),
      ],
    );
  }

  /// Estilo alternativo Orbitron con dígitos tabulares para cronómetros GPS y velocímetro digital
  static TextStyle digitalDisplayStyle({
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.w800,
  }) {
    return GoogleFonts.orbitron(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const <FontFeature>[
        FontFeature.tabularFigures(),
      ],
    );
  }

  /// Cabeceras inspiradas en el emblema clásico "RENAULT SPORT" (Exo 2 Bold Italic)
  static TextStyle renaultSportHeaderStyle({
    required double fontSize,
    required Color color,
  }) {
    return GoogleFonts.exo2(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      fontStyle: FontStyle.italic,
      letterSpacing: 1.1,
      color: color,
    );
  }

  /// Tema Oscuro: "Night Stage / Sagem Amber & Anthracite"
  static ThemeData get nightStageTheme {
    final baseTextTheme = GoogleFonts.rajdhaniTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: RenaultSportPalette.nightCarbonBg,
      colorScheme: const ColorScheme.dark(
        primary: RenaultSportPalette.sagemAmberOrange,
        secondary: RenaultSportPalette.siriusLiquidYellow,
        tertiary: RenaultSportPalette.oemShiftGreen,
        surface: RenaultSportPalette.speedlineTuriniAnthracite,
        error: RenaultSportPalette.revLimiterRed,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Color(0xFFF3F4F6),
      ),
      cardTheme: CardTheme(
        color: RenaultSportPalette.speedlineTuriniAnthracite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: RenaultSportPalette.speedlineCardBorder,
            width: 1.2,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: RenaultSportPalette.nightCarbonBg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: renaultSportHeaderStyle(
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: telemetryNumericStyle(
          fontSize: 54,
          color: RenaultSportPalette.sagemAmberOrange,
        ),
        headlineMedium: renaultSportHeaderStyle(
          fontSize: 24,
          color: Colors.white,
        ),
        titleLarge: renaultSportHeaderStyle(
          fontSize: 18,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          color: const Color(0xFFE5E7EB),
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFF9CA3AF),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RenaultSportPalette.sagemAmberOrange,
          foregroundColor: Colors.black,
          textStyle: GoogleFonts.exo2(
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF14171D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RenaultSportPalette.speedlineCardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RenaultSportPalette.speedlineCardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: RenaultSportPalette.sagemAmberOrange,
            width: 2,
          ),
        ),
      ),
    );
  }

  /// Tema Claro: "Daylight Cup / Iceberg Silver & Mondial Blue"
  static ThemeData get daylightCupTheme {
    final baseTextTheme = GoogleFonts.rajdhaniTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: RenaultSportPalette.icebergSilverBg,
      colorScheme: const ColorScheme.light(
        primary: RenaultSportPalette.mondialBlue,
        secondary: RenaultSportPalette.cupNeedleRed,
        tertiary: RenaultSportPalette.daylightShiftGreen,
        surface: RenaultSportPalette.pureCabinWhite,
        error: RenaultSportPalette.cupNeedleRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF0F172A),
      ),
      cardTheme: CardTheme(
        color: RenaultSportPalette.pureCabinWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: RenaultSportPalette.daylightBorder,
            width: 1.2,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: RenaultSportPalette.icebergSilverBg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: renaultSportHeaderStyle(
          fontSize: 20,
          color: RenaultSportPalette.mondialBlue,
        ),
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: telemetryNumericStyle(
          fontSize: 54,
          color: RenaultSportPalette.mondialBlue,
        ),
        headlineMedium: renaultSportHeaderStyle(
          fontSize: 24,
          color: RenaultSportPalette.mondialBlue,
        ),
        titleLarge: renaultSportHeaderStyle(
          fontSize: 18,
          color: const Color(0xFF0F172A),
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          color: const Color(0xFF1E293B),
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFF475569),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RenaultSportPalette.mondialBlue,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.exo2(
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RenaultSportPalette.pureCabinWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RenaultSportPalette.daylightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RenaultSportPalette.daylightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: RenaultSportPalette.mondialBlue,
            width: 2,
          ),
        ),
      ),
    );
  }
}

