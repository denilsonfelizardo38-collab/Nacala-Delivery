import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema Material 3 da Nacala Entrega, claro e escuro.
abstract final class AppTheme {
  static ThemeData light() => _build(
    brightness: Brightness.light,
    surface: AppColors.bg,
    card: Colors.white,
    ink: AppColors.ink,
    muted: AppColors.muted,
    border: AppColors.border,
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    surface: AppColors.darkBg,
    card: AppColors.darkCard,
    ink: AppColors.darkInk,
    muted: AppColors.darkMuted,
    border: AppColors.darkBorder,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color surface,
    required Color card,
    required Color ink,
    required Color muted,
    required Color border,
  }) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? const Color(0xFF5AA0F5) : AppColors.primary;
    final scheme = isDark
        ? const ColorScheme.dark(
            primary: Color(0xFF5AA0F5),
            onPrimary: Color(0xFF04152B),
            secondary: Color(0xFF8FC0FA),
            onSecondary: Color(0xFF04152B),
            surface: AppColors.darkBg,
            onSurface: AppColors.darkInk,
            error: Color(0xFFFF7A85),
            onError: Color(0xFF2B0509),
            outline: AppColors.darkBorder,
          )
        : const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            secondary: AppColors.navy,
            onSecondary: Colors.white,
            surface: AppColors.bg,
            onSurface: AppColors.ink,
            error: AppColors.danger,
            onError: Colors.white,
            outline: AppColors.border,
          );

    final typography = Typography.material2021();
    final baseText = isDark ? typography.white : typography.black;

    final textTheme = baseText
        .copyWith(
          displaySmall: TextStyle(
            color: ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            height: 1.25,
          ),
          headlineSmall: TextStyle(
            color: ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            height: 1.25,
          ),
          titleLarge: TextStyle(
            color: ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          titleSmall: TextStyle(
            color: ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: TextStyle(color: ink, fontSize: 14, height: 1.45),
          bodyMedium: TextStyle(color: ink, fontSize: 14, height: 1.45),
          bodySmall: TextStyle(
            color: muted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
          labelLarge: TextStyle(
            color: ink,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          labelSmall: TextStyle(
            color: muted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        )
        .apply(fontFamily: 'Inter');

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Inter',
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      canvasColor: surface,
      cardColor: card,
      dividerColor: border,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        hintStyle: TextStyle(color: muted, fontSize: 14),
        labelStyle: TextStyle(
          color: muted,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: primary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
        errorStyle: const TextStyle(color: AppColors.danger, fontSize: 12),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        // Ícone ativo preenchido a azul royal, sem "pílula" de fundo.
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.selected) ? primary : muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected) ? primary : muted,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: isDark ? const Color(0xFF04152B) : Colors.white,
          disabledBackgroundColor: primary.withValues(alpha: 0.4),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(44, 44),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: AppColors.primarySoft,
        side: BorderSide(color: border),
        labelStyle: TextStyle(
          color: ink,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkElevated : AppColors.navy,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        actionTextColor: const Color(0xFF8FC0FA),
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: muted, fontSize: 14, height: 1.45),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : (isDark ? AppColors.darkMuted : AppColors.muted),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : border,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: ink,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

/// Cores dependentes do tema atual.
extension AppThemeContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get cardColor => Theme.of(this).cardColor;

  Color get inkColor => isDarkMode ? AppColors.darkInk : AppColors.ink;

  Color get mutedColor => isDarkMode ? AppColors.darkMuted : AppColors.muted;

  Color get lineColor => isDarkMode ? AppColors.darkBorder : AppColors.border;

  Color get accentColor => Theme.of(this).colorScheme.primary;

  Color get successColor =>
      isDarkMode ? const Color(0xFF4ED6A0) : AppColors.success;

  Color get dangerColor =>
      isDarkMode ? const Color(0xFFFF7A85) : AppColors.danger;

  Color get warningColor =>
      isDarkMode ? const Color(0xFFFFC45C) : AppColors.warning;
}
