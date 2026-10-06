import 'package:flutter/material.dart';

/// Academic / Sepia Design System for Antigravity Edge-to-Cloud UI
class SepiaTheme {
  // Core Palette
  static const Color canvas = Color(0xFFFAF7F2);        // #faf7f2 parchment canvas
  static const Color paper = Color(0xFFFFFFFF);         // #ffffff pure sheet
  static const Color paperElevated = Color(0xFFFFFFFF); // #ffffff elevated card sheet
  static const Color paperSubtle = Color(0xFFF7F4EE);   // #f7f4ee tinted surface
  static const Color ink = Color(0xFF1C1917);           // #1c1917 warm ink
  static const Color inkSecondary = Color(0xFF44403C);  // #44403c secondary text
  static const Color inkMuted = Color(0xFF78716C);      // #78716c muted labels
  static const Color border = Color(0xFFE6DFD5);        // #e6dfd5 divider & card border
  static const Color borderSubtle = Color(0xFFF0EBE1);  // #f0ebe1 inner border

  // Semantic Accents
  // Sage Olive - Edge execution, local privacy, zero egress
  static const Color sage = Color(0xFF3F6212);          // #3f6212
  static const Color sageBg = Color(0xFFECFCCB);        // #ecfccb
  static const Color sageBorder = Color(0xFFD9F99D);    // #d9f99d

  // Warm Amber - Cloud execution, Gemini 3.8 Flash, synthesis
  static const Color amber = Color(0xFFB45309);         // #b45309
  static const Color amberBg = Color(0xFFFEF3C7);       // #fef3c7
  static const Color amberBorder = Color(0xFFFDE68A);   // #fde68a

  // Terracotta - Warning, offline fallback, circuit breaker
  static const Color terracotta = Color(0xFFC2410C);    // #c2410c
  static const Color terracottaBg = Color(0xFFFFEDD5);  // #ffedd5
  static const Color terracottaBorder = Color(0xFFFED7AA);

  // Slate Stone - Local fast edge single-turn
  static const Color slate = Color(0xFF57534E);         // #57534e
  static const Color slateBg = Color(0xFFF4EFE6);       // #f4efe6
  static const Color slateBorder = Color(0xFFE7E5E4);

  // Violet - Feature synthesis sandbox
  static const Color violet = Color(0xFF7C3AED);
  static const Color violetBg = Color(0xFFF5F3FF);
  static const Color violetBorder = Color(0xFFDDD6FE);

  // Azure Indigo - Cloud escalation, Nano Banana 2 Lite visual synthesis
  static const Color azure = Color(0xFF1565C0);
  static const Color azureBg = Color(0xFFEFF6FF);
  static const Color azureBorder = Color(0xFFBFDBFE);

  // Fonts
  static const String fontSans = 'DM Sans';
  static const String fontMono = 'JetBrains Mono';

  static TextStyle sans({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = ink,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
  }) {
    return TextStyle(
      fontFamily: fontSans,
      fontFamilyFallback: const ['Inter', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'sans-serif'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
    );
  }

  static TextStyle mono({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w400,
    Color color = inkSecondary,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
  }) {
    return TextStyle(
      fontFamily: fontMono,
      fontFamilyFallback: const ['Fira Code', 'Menlo', 'Monaco', 'Consolas', 'monospace'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
    );
  }

  static TextStyle serif({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = ink,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
  }) {
    return TextStyle(
      fontFamily: 'Lora',
      fontFamilyFallback: const ['Georgia', 'Cambria', 'Times New Roman', 'serif'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
    );
  }

  /// Quiet Typography Helpers (eliminates false affordance pill boxes)
  static Widget quietLabel(String text, {Color? color}) {
    return Text(
      text.toUpperCase(),
      style: mono(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: color ?? inkMuted,
        letterSpacing: 0.5,
      ),
    );
  }

  static Widget statusDot(Color dotColor, String label, {Color? textColor, double fontSize = 11}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: sans(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: textColor ?? inkSecondary,
          ),
        ),
      ],
    );
  }

  static Widget metricText(String label, String value, {Color? valueColor}) {
    return RichText(
      text: TextSpan(
        style: mono(fontSize: 11, color: inkMuted),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: mono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: valueColor ?? inkSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: canvas,
      primaryColor: ink,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: ink,
        onPrimary: canvas,
        secondary: sage,
        onSecondary: Colors.white,
        error: terracotta,
        onError: Colors.white,
        surface: paper,
        onSurface: ink,
        outline: border,
      ),
      dividerColor: border,
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: paper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: sans(fontSize: 16, fontWeight: FontWeight.w600, color: ink),
        iconTheme: const IconThemeData(color: ink),
        shape: const Border(bottom: BorderSide(color: border, width: 1)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: ink,
          foregroundColor: canvas,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: sans(fontSize: 13, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: border, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: sans(fontSize: 13, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ink, width: 1.5),
        ),
        hintStyle: sans(fontSize: 14, color: inkMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
