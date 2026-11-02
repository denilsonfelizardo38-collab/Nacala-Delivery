import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema Material 3 da Nacala Entrega, claro e escuro — redesign global.
///
/// Identidade visual: azul vivo (#0755E9), fundos brancos e superfícies
/// claras (#F5F8FC), tipografia Poppins (títulos SemiBold, subtítulos Medium,
/// textos Regular, valores importantes SemiBold).
abstract final class AppTheme {
  /// Stack tipográfico estilo iPhone (SF Pro / system).
  static const String _iosFontStack =
      '-apple-system, BlinkMacSystemFont, SF Pro Display, SF Pro Text, '
      'Helvetica Neue, Arial, sans-serif';

  static ThemeData light() => _build(
    brightness: Brightness.light,
    surface: AppColors.surface,
    card: AppColors.bg,
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
            secondary: AppColors.primaryLight,
            onSecondary: Colors.white,
            surface: AppColors.bg,
            onSurface: AppColors.ink,
            error: AppColors.danger,
            onError: Colors.white,
            outline: AppColors.border,
          );

    final typography = Typography.material2021();
    final base = isDark ? typography.white : typography.black;

    TextStyle style(
      Color color,
      double? fontSize, {
      FontWeight? fontWeight,
      double height = 1.45,
      double? letterSpacing,
    }) => TextStyle(
      color: color,
      fontSize: fontSize ?? 14,
      fontWeight: fontWeight ?? FontWeight.w400,
      height: height,
      letterSpacing: letterSpacing,
    );

    final textTheme = base
        .apply(fontFamily: _iosFontStack)
        .copyWith(
          displaySmall: style(
            ink,
            32,
            fontWeight: FontWeight.w800,
            height: 1.08,
            letterSpacing: -0.8,
          ),
          headlineSmall: style(
            ink,
            27,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.5,
          ),
          titleLarge: style(ink, 24, fontWeight: FontWeight.w800, height: 1.25, letterSpacing: -0.3),
          titleMedium: style(
            ink,
            18,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          titleSmall: style(ink, 17, fontWeight: FontWeight.w700, height: 1.3),
          bodyLarge: style(ink, 16, height: 1.5),
          bodyMedium: style(ink, 15, height: 1.5),
          bodySmall: style(muted, 13, height: 1.5),
          labelLarge: style(ink, 14, fontWeight: FontWeight.w700, height: 1.35),
          labelSmall: style(
            muted,
            12,
            fontWeight: FontWeight.w600,
            height: 1.35,
            letterSpacing: 0.2,
          ),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: _iosFontStack,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      canvasColor: surface,
      cardColor: card,
      dividerColor: border,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: style(
          ink,
          22,
          fontWeight: FontWeight.w600,
          height: 1.25,
          letterSpacing: -0.2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        hintStyle: style(muted, 14),
        labelStyle: style(muted, 13, fontWeight: FontWeight.w500),
        floatingLabelStyle: style(primary, 13, fontWeight: FontWeight.w500),
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
          borderSide: BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.danger, width: 1.6),
        ),
        errorStyle: const TextStyle(color: AppColors.danger, fontSize: 12),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: isDark ? AppColors.darkElevated : AppColors.primarySoft,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
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
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: isDark ? const Color(0xFF04152B) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
        backgroundColor: isDark ? AppColors.darkElevated : AppColors.primary,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        actionTextColor: Colors.white,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
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
          borderRadius: BorderRadius.circular(20),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
