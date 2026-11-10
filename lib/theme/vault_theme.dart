import 'package:flutter/material.dart';

abstract final class VaultColors {
  static const ink = Color(0xFF2E1848);
  static const pink = Color(0xFFFF4F93);
  static const pinkDeep = Color(0xFFE4377C);
  static const blush = Color(0xFFFFD0E4);
  static const cyan = Color(0xFF2AD4FF);
  static const lemon = Color(0xFFFFE566);
  static const grape = Color(0xFF7C5CFF);
  static const cream = Color(0xFFFFF4FB);
  static const card = Color(0xFFFFFFFF);
}

ThemeData buildVaultTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: VaultColors.cream,
    colorScheme: ColorScheme.fromSeed(
      seedColor: VaultColors.pink,
      primary: VaultColors.pink,
      onPrimary: Colors.white,
      secondary: VaultColors.cyan,
      surface: VaultColors.cream,
    ),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: 'Fredoka',
      bodyColor: VaultColors.ink,
      displayColor: VaultColors.ink,
    ),
    splashColor: VaultColors.blush,
    dialogTheme: DialogThemeData(
      backgroundColor: VaultColors.card,
      titleTextStyle: const TextStyle(
        fontFamily: 'Fredoka',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: VaultColors.ink,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: 'Fredoka',
        fontSize: 16,
        height: 1.35,
        color: VaultColors.ink,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: VaultColors.ink, width: 3),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: VaultColors.ink,
      contentTextStyle: const TextStyle(
        fontFamily: 'Fredoka',
        fontSize: 15,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return VaultColors.pink;
        return const Color(0xFFE7D7E6);
      }),
      trackOutlineColor: WidgetStateProperty.all(VaultColors.ink),
    ),
  );
}
