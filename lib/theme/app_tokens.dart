import 'package:flutter/material.dart';

/// Tokens centrais de espaçamento da Nacala Delivery.
///
/// Escala: 4 · 8 · 12 · 16 · 20 · 24 · 32.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double huge = 32;

  /// Padding horizontal padrão das páginas.
  static const double page = 20;

  static const pagePadding = EdgeInsets.symmetric(horizontal: page);
  static const sectionGap = SizedBox(height: xl);
}

/// Raios de borda da aplicação.
abstract final class AppRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 999;
}

/// Alturas e dimensões padrão de componentes interativos.
abstract final class AppSizes {
  /// Altura padrão dos campos de formulário e botões primários.
  static const double input = 52;
  static const double button = 52;

  /// Área mínima de toque acessível (Material).
  static const double touchTarget = 44;

  /// Altura da barra de navegação inferior.
  static const double navBar = 70;
}

/// Durações padrão das animações.
abstract final class AppDuration {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 400);
}

/// Estilos de sombra reutilizáveis.
abstract final class AppShadows {
  /// Sombra suave padrão de cartões.
  static const card = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  /// Sombra de elementos flutuantes (diálogos, folhas inferiores).
  static const elevated = BoxShadow(
    color: Color(0x1F000000),
    blurRadius: 24,
    offset: Offset(0, 8),
  );
}
