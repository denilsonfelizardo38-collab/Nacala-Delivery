import 'package:flutter/material.dart';

/// Paleta oficial da Nacala Entrega — redesign global.
///
/// Identidade visual: azul vivo (#0755E9) sobre fundo branco e superfícies
/// muito claras (#F5F8FC), com texto quase preto (#202124) e texto secundário
/// neutro (#929292). Estados (sucesso, aviso, erro) usam cores semânticas
/// próximas do original, mas harmonizadas com a nova identidade.
abstract final class AppColors {
  // Identidade principal.
  static const primary = Color(0xFF0755E9); // #0755E9
  static const primaryLight = Color(0xFF3478F6); // #3478F6
  static const primaryPressed = Color(0xFF0A63E8);
  static const primarySoft = Color(0xFFEAF1FF);

  // Fundamentos.
  static const bg = Color(0xFFFFFFFF); // #FFFFFF
  static const surface = Color(0xFFF5F8FC); // #F5F8FC
  static const ink = Color(0xFF202124); // #202124
  static const muted = Color(0xFF929292); // #929292
  static const border = Color(0xFFE8E8E8);

  // Estados.
  static const success = Color(0xFF20A36B);
  static const successSoft = Color(0xFFE7F6EF);
  static const warning = Color(0xFFE99B32); // #E99B32
  static const warningSoft = Color(0xFFFCEFDD);
  static const danger = Color(0xFFDC4545);
  static const dangerSoft = Color(0xFFFBEAE9);

  /// Sombra suave usada em cartões e na barra de navegação:
  /// `0 4px 12px rgba(0, 0, 0, 0.08)`.
  static const cardShadow = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  // Superfícies do tema escuro.
  static const darkBg = Color(0xFF111111);
  static const darkCard = Color(0xFF0A2140);
  static const darkElevated = Color(0xFF0F2B4D);
  static const darkInk = Color(0xFFE9F0FA);
  static const darkMuted = Color(0xFF1C1D1D);
  static const darkBorder = Color(0xFF14161F);

  // Aliases históricos usados em ecrãs e widgets.
  static const blue = primary;
  static const surfaceAlias = bg;
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
