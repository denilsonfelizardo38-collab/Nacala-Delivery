import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema Material 3 da Nacala Delivery — tema escuro único.
///
/// Identidade visual escura "dark-first": fundo preto `#000000`, cartões
/// `#141414`, elevações `#1F1F1F`, destaque vermelho `#F2151C`, texto
/// `#FFFFFF` / `#B9B9B9` / `#858585`. Tipografia **Bricolage Grotesque**
/// nos títulos (display) e **Figtree** no corpo, com hierarquia
/// consistente (títulos Bold/ExtraBold, corpo Regular, subtítulos Medium).
///
/// Raios do sistema: 10 (sm) · 14 (md) · 20 (lg) · 28 (xl) · pill.
abstract final class AppTheme {
  /// Corpo da aplicação.
  static const String fontFamily = 'Figtree';

  /// Títulos e destaques (display).
  static const String displayFontFamily = 'Bricolage Grotesque';

  static ThemeData dark() => _build();

  static ThemeData _build() {
    const surface = AppColors.darkBg;
    const card = AppColors.darkCard;
    const ink = AppColors.darkInk;
    const muted = AppColors.darkMuted;
    const border = AppColors.darkBorder;
    const primary = AppColors.primary;

    final scheme = const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Color(0xFF04182E),
      surface: AppColors.darkBg,
      onSurface: AppColors.darkInk,
      error: AppColors.danger,
      onError: Colors.white,
      outline: AppColors.darkBorder,
    );

    final typography = Typography.material2021();
    final base = typography.white;

    TextStyle style(
      Color color,
      double? fontSize, {
      FontWeight? fontWeight,
      double height = 1.45,
      double? letterSpacing,
      String? fontFamily,
    }) => TextStyle(
      color: color,
      fontSize: fontSize ?? 14,
      fontWeight: fontWeight ?? FontWeight.w400,
      height: height,
      letterSpacing: letterSpacing,
      fontFamily: fontFamily ?? AppTheme.fontFamily,
    );

    TextStyle display(
      Color color,
      double fontSize, {
      FontWeight fontWeight = FontWeight.w700,
      double height = 1.15,
      double? letterSpacing,
    }) => style(
      color,
      fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      fontFamily: AppTheme.displayFontFamily,
    );

    final textTheme = base
        .apply(fontFamily: fontFamily)
        .copyWith(
          displaySmall: display(
            ink,
            30,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: -0.6,
          ),
          headlineSmall: display(
            ink,
            25,
            fontWeight: FontWeight.w800,
            height: 1.14,
            letterSpacing: -0.4,
          ),
          titleLarge: display(
            ink,
            22,
            fontWeight: FontWeight.w700,
            height: 1.2,
            letterSpacing: -0.3,
          ),
          titleMedium: display(
            ink,
            17,
            fontWeight: FontWeight.w600,
            height: 1.28,
          ),
          titleSmall: display(
            ink,
            15,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          bodyLarge: style(ink, 16, height: 1.5),
          bodyMedium: style(ink, 14, height: 1.5),
          bodySmall: style(muted, 13, height: 1.5),
          labelLarge: style(ink, 14, fontWeight: FontWeight.w700, height: 1.35),
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
      brightness: Brightness.dark,
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
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: display(
          ink,
          20,
          fontWeight: FontWeight.w700,
          height: 1.22,
          letterSpacing: -0.2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkElevated,
        hintStyle: style(muted, 14),
        labelStyle: style(muted, 13, fontWeight: FontWeight.w500),
        floatingLabelStyle: style(primary, 13, fontWeight: FontWeight.w600),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
        errorStyle: const TextStyle(color: AppColors.danger, fontSize: 12),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkElevated,
        indicatorColor: AppColors.primary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 74,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
            color: states.contains(WidgetState.selected) ? Colors.white : muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected) ? Colors.white : muted,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.85),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            fontFamily: fontFamily,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.darkElevatedHigh),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
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
          foregroundColor: AppColors.primarySecondary,
          minimumSize: const Size(44, 48),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
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
        backgroundColor: AppColors.darkElevated,
        selectedColor: AppColors.darkPrimarySoft,
        side: const BorderSide(color: AppColors.darkElevatedHigh),
        labelStyle: TextStyle(
          color: ink,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkElevatedHigh,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: fontFamily,
        ),
        actionTextColor: Colors.white,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          fontFamily: displayFontFamily,
        ),
        contentTextStyle: TextStyle(
          color: muted,
          fontSize: 14,
          height: 1.45,
          fontFamily: fontFamily,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.darkCard,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.darkElevated),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.darkMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : AppColors.darkElevatedHigh,
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

  Color get inkColor => AppColors.darkInk;

  Color get mutedColor => AppColors.darkMuted;

  Color get lineColor => AppColors.darkBorder;

  Color get primarySoftColor => AppColors.darkPrimarySoft;

  Color get primarySoftStrongColor => AppColors.darkPrimarySoftStrong;

  Color get accentColor => Theme.of(this).colorScheme.primary;

  Color get secondaryColor => Theme.of(this).colorScheme.secondary;

  Color get successColor => AppColors.success;

  Color get dangerColor => AppColors.dangerInk;

  Color get warningColor => AppColors.warning;
}
