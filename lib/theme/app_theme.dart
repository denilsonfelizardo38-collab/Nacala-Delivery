import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema Material 3 da Nacala Delivery, claro e escuro.
///
/// Identidade visual: laranja vivo `#FF7900` para ícones e destaques,
/// laranja de leitura `#D95F00` para texto e botões em fundo claro
/// (contraste AA), fundo `#F7F7F9` e cartões brancos. Tipografia Inter
/// com hierarquia consistente
/// (títulos SemiBold/Bold, corpo Regular, subtítulos Medium).
abstract final class AppTheme {
  static const String fontFamily = 'Inter';

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
    final primary = isDark ? const Color(0xFFFF9E45) : AppColors.textOrange;
    final scheme = isDark
        ? const ColorScheme.dark(
            primary: Color(0xFFFF9E45),
            onPrimary: Color(0xFF2B1500),
            secondary: Color(0xFF6FA8F2),
            onSecondary: Color(0xFF04182E),
            surface: AppColors.darkBg,
            onSurface: AppColors.darkInk,
            error: Color(0xFFFF8A80),
            onError: Color(0xFF2B0509),
            outline: AppColors.darkBorder,
          )
        : const ColorScheme.light(
            // O laranja de leitura (#D95F00) garante contraste de texto
            // e botões sobre fundos claros; o laranja vivo (#FF7900)
            // fica reservado a ícones e destaque.
            primary: AppColors.textOrange,
            onPrimary: Colors.white,
            secondary: AppColors.secondary,
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
        .apply(fontFamily: fontFamily)
        .copyWith(
          displaySmall: style(
            ink,
            30,
            fontWeight: FontWeight.w700,
            height: 1.12,
            letterSpacing: -0.6,
          ),
          headlineSmall: style(
            ink,
            25,
            fontWeight: FontWeight.w700,
            height: 1.16,
            letterSpacing: -0.4,
          ),
          titleLarge: style(
            ink,
            22,
            fontWeight: FontWeight.w700,
            height: 1.24,
            letterSpacing: -0.3,
          ),
          titleMedium: style(
            ink,
            17,
            fontWeight: FontWeight.w600,
            height: 1.32,
          ),
          titleSmall: style(ink, 15, fontWeight: FontWeight.w600, height: 1.35),
          bodyLarge: style(ink, 16, height: 1.5),
          bodyMedium: style(ink, 14, height: 1.5),
          bodySmall: style(muted, 13, height: 1.5),
          labelLarge: style(ink, 14, fontWeight: FontWeight.w600, height: 1.35),
          labelSmall: style(
            muted,
            11,
            fontWeight: FontWeight.w600,
            height: 1.35,
            letterSpacing: 0.3,
          ),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
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
          20,
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
            fontFamily: fontFamily,
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
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.9),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          // O esquema de cores resolve: laranja de leitura em claro,
          // laranja claro em escuro — nunca o azul, fora da identidade.
          foregroundColor: primary,
          minimumSize: const Size(44, 48),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
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
          fontFamily: fontFamily,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkElevated : AppColors.ink,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: fontFamily,
        ),
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
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          fontFamily: fontFamily,
        ),
        contentTextStyle: TextStyle(
          color: muted,
          fontSize: 14,
          height: 1.45,
          fontFamily: fontFamily,
        ),
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
              : (isDark ? AppColors.darkMuted : AppColors.mutedLight),
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

  Color get primarySoftColor =>
      isDarkMode ? AppColors.darkPrimarySoft : AppColors.primarySoft;

  Color get primarySoftStrongColor =>
      isDarkMode
          ? AppColors.darkPrimarySoftStrong
          : AppColors.primarySoftStrong;

  Color get accentColor => Theme.of(this).colorScheme.primary;

  Color get secondaryColor => Theme.of(this).colorScheme.secondary;

  Color get successColor =>
      isDarkMode ? const Color(0xFF4ED6A0) : AppColors.success;

  Color get dangerColor =>
      isDarkMode ? const Color(0xFFFF8A80) : AppColors.danger;

  Color get warningColor =>
      isDarkMode ? const Color(0xFFFFC45C) : AppColors.warning;
}
