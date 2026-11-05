import 'package:flutter/material.dart';

/// Paleta oficial da Nacala Delivery.
///
/// Identidade visual única em toda a aplicação:
/// laranja vivo `#FF7900` para ícones e destaques, laranja de leitura
/// `#D95F00` para texto e botões sobre fundo claro (contraste AA), texto
/// `#17191F`, fundo `#F7F7F9`, cartões `#FFFFFF` e texto secundário
/// `#747982`. Estados usam cores semânticas (#16A36A, #E53935)
/// harmonizadas com a identidade.
abstract final class AppColors {
  // ---------------------------------------------------------------
  // Identidade principal — laranja Nacala.
  // ---------------------------------------------------------------
  static const primary = Color(0xFFFF7900); // #FF7900 — ícones e destaques
  static const primarySecondary = Color(0xFFFF9A3D); // #FF9A3D
  static const primaryPressed = Color(0xFFE85D00); // #E85D00

  /// Laranja de leitura: texto e botões sobre fundos claros. O laranja vivo
  /// (#FF7900) tem ~3:1 sobre branco, abaixo de 4.5:1 (AA); #D95F00 garante
  /// contraste suficiente sem perder a identidade.
  static const textOrange = Color(0xFFD95F00); // #D95F00
  static const primarySoft = Color(0xFFFFF0E5); // fundo suave de destaque
  static const primarySoftStrong = Color(0xFFFFE3CF); // chips / selecções

  // ---------------------------------------------------------------
  // Secundário — azul Nacala.
  // ---------------------------------------------------------------
  static const secondary = Color(0xFF1260D8); // #1260D8
  static const secondaryPressed = Color(0xFF0F51B8); // #0F51B8
  static const secondarySoft = Color(0xFFE9F0FC); // fundo suave azul

  // ---------------------------------------------------------------
  // Fundamentos.
  // ---------------------------------------------------------------
  static const bg = Color(0xFFFFFFFF); // #FFFFFF — cartões e superfícies
  static const surface = Color(0xFFF7F7F9); // #F7F7F9 — fundo da aplicação
  static const ink = Color(0xFF17191F); // #17191F — texto principal
  static const muted = Color(0xFF747982); // #747982 — texto secundário
  static const mutedLight = Color(0xFF8A929C); // dicas e placeholders
  static const border = Color(0xFFE8E8EC); // #E8E8EC — linhas e contornos

  // ---------------------------------------------------------------
  // Estados.
  // ---------------------------------------------------------------
  static const success = Color(0xFF16A36A); // #16A36A
  static const successSoft = Color(0xFFE7F6EF);
  static const warning = Color(0xFFE99B32);
  static const warningSoft = Color(0xFFFCEFDD);
  static const danger = Color(0xFFE53935); // #E53935
  static const dangerSoft = Color(0xFFFBEAE9);
  static const dangerBorder = Color(0xFFF0C6C3);
  static const dangerInk = Color(0xFFB42318);

  /// Fundo profundo usado nas telas de autenticação sobre a fotografia.
  static const deepNavy = Color(0xFF06264B);
  static const deepNavyLight = Color(0xFF103B68);

  /// Sombra suave usada em cartões e na barra de navegação:
  /// `0 4px 12px rgba(0, 0, 0, 0.08)`.
  static const cardShadow = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  // ---------------------------------------------------------------
  // Superfícies do tema escuro.
  // ---------------------------------------------------------------
  static const darkBg = Color(0xFF14161A);
  static const darkCard = Color(0xFF1D2026);
  static const darkElevated = Color(0xFF262A32);
  static const darkInk = Color(0xFFE8EAED);
  static const darkMuted = Color(0xFF9AA3AF);
  static const darkBorder = Color(0xFF2B2F37);
  static const darkPrimarySoft = Color(0xFF3A2413); // sobressalto laranja
  static const darkPrimarySoftStrong = Color(0xFF4D3019);

  // ---------------------------------------------------------------
  // Aliases históricos usados em ecrãs e widgets.
  // ---------------------------------------------------------------
  static const blue = secondary;
  static const surfaceAlias = bg;
  static const line = border;
  static const paleBlue = secondarySoft;
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
  static const primaryLight = primaryPressed;
  static const primaryText = textOrange;
}
