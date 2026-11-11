import 'package:flutter/material.dart';

class PlantPalColors {
  PlantPalColors._();

  static const Color forest = Color(0xFF315F43);
  static const Color sage = Color(0xFF83AD8A);
  static const Color mint = Color(0xFFE0EBDD);

  static const Color lightBackground = Color(0xFFF6F8F2);
  static const Color lightCard = Colors.white;
  static const Color lightText = Color(0xFF24372A);
  static const Color lightSecondary = Color(0xFF526557);

  static const Color darkBackground = Color(0xFF111B16);
  static const Color darkCard = Color(0xFF223329);
  static const Color darkText = Color(0xFFEDF4EE);
  static const Color darkSecondary = Color(0xFFC5D3C8);
  static const Color darkAccent = Color(0xFF9BD5AD);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      isDark(context) ? darkBackground : lightBackground;

  static Color card(BuildContext context) =>
      isDark(context) ? darkCard : lightCard;

  static Color text(BuildContext context) =>
      isDark(context) ? darkText : lightText;

  static Color secondaryText(BuildContext context) =>
      isDark(context) ? darkSecondary : lightSecondary;

  static Color accent(BuildContext context) =>
      isDark(context) ? darkAccent : forest;

  static Color border(BuildContext context) =>
      isDark(context) ? const Color(0xFF3A5444) : mint;

  static Color softBackground(BuildContext context) =>
      isDark(context) ? const Color(0xFF304737) : const Color(0xFFE0EBDD);
}
