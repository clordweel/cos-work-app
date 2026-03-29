import 'package:flutter/material.dart';

import 'ui/cos_shell_tokens.dart';

/// 与 COS 站点协调的深蓝主色（Material 3 seed）
const Color kCosBrandBlue = Color(0xFF1565C0);

ThemeData buildCosWorkTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: kCosBrandBlue,
    brightness: Brightness.light,
  );
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    extensions: const <ThemeExtension<dynamic>>[
      CosShellTokens.light,
    ],
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: true,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: colorScheme.surfaceTint,
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
      linearTrackColor: colorScheme.surfaceContainerHighest,
    ),
  );
}

ThemeData buildCosWorkDarkTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: kCosBrandBlue,
    brightness: Brightness.dark,
  );
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    extensions: const <ThemeExtension<dynamic>>[
      CosShellTokens.dark,
    ],
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: true,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: colorScheme.surfaceTint,
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
      linearTrackColor: colorScheme.surfaceContainerHighest,
    ),
  );
}
