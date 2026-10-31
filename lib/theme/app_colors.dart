import 'package:flutter/material.dart';

/// Paleta oficial da Nacala Entrega.
///
/// Identidade de alto contraste: fundo branco puro, azul royal saturado e
/// tipografia quase preta. As variantes `dark*` mantêm-se apenas para o tema
/// escuro opcional (não aplicado automaticamente).
abstract final class AppColors {
  static const primary = Color.fromARGB(255, 0, 66, 248);
  static const primaryPressed = Color.fromARGB(255, 5, 100, 243);
  static const primarySoft = Color.fromARGB(255, 255, 255, 255);

  static const navy = Color.fromARGB(255, 6, 88, 219);
  static const darkBg = Color.fromARGB(255, 17, 17, 17);

  static const bg = Color(0xFFFFFFFF);
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const border = Color.fromARGB(255, 255, 255, 255);

  static const success = Color(0xFF12B76A);
  static const successSoft = Color.fromARGB(255, 252, 253, 253);
  static const warning = Color(0xFFF79009);
  static const warningSoft = Color.fromARGB(255, 255, 255, 255);
  static const danger = Color(0xFFF04438);
  static const dangerSoft = Color.fromARGB(255, 252, 252, 252);

  /// Sombra suave usada em cartões e na barra de navegação:
  /// `0 4px 12px rgba(0, 0, 0, 0.08)`.
  static const cardShadow = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  // Superfícies do tema escuro.
  static const darkCard = Color(0xFF0A2140);
  static const darkElevated = Color(0xFF0F2B4D);
  static const darkInk = Color(0xFFE9F0FA);
  static const darkMuted = Color.fromARGB(255, 28, 29, 29);
  static const darkBorder = Color.fromARGB(255, 20, 20, 20);

  // Aliases históricos usados em ecrãs e widgets.
  static const blue = primary;
  static const surface = bg;
  static const line = border;
  static const paleBlue = primarySoft;
  static const green = success;
  static const greenSoft = successSoft;
  static const greenInk = Color(0xFF067647);
  static const amber = warning;
  static const amberSoft = warningSoft;
  static const amberInk = Color(0xFFB54708);
  static const red = danger;
  static const redSoft = dangerSoft;
  static const darkSurface = darkBg;
  static const darkLine = darkBorder;
}
