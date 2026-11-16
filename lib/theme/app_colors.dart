import 'package:flutter/material.dart';

/// Paleta oficial da Nacala Delivery — tema escuro único.
///
/// Identidade visual escura "dark-first":
/// fundo preto `#000000`, superfícies elevadas `#141414` · `#1F1F1F` ·
/// `#2B2B2B`, destaque vermelho vivo `#F2151C` (pressed `#C10D13`,
/// tinta de destaque `#FF4A50`), texto `#FFFFFF` / `#B9B9B9` / `#858585`.
/// Estados usam verde `#2BD46F`, âmbar `#FFA41B` e ouro `#FFB81C` sobre
/// fundos escuros próprios (`#0D2417`, `#2A0709`, `#241704`).
///
/// Todos os nomes históricos (aliases) são preservados para os ecrãs;
/// o que muda é o valor por trás de cada um.
abstract final class AppColors {
  // ---------------------------------------------------------------
  // Identidade principal — vermelho Nacala.
  // ---------------------------------------------------------------
  static const primary = Color(0xFFF2151C); // #F2151C — destaque e botões
  static const primarySecondary = Color(0xFFFF4A50); // #FF4A50 — tinta viva
  static const primaryPressed = Color(0xFFC10D13); // #C10D13 — pressionado

  /// Tinta vermelha legível sobre superfícies escuras (links, ícones
  /// seleccionados, texto de destaque).
  static const textOrange = Color(0xFFFF4A50); // #FF4A50

  /// Vermelho suave (14% sobre preto) para fundos de destaque.
  static const primarySoft = Color(0x24F2151C); // rgba(242,21,28,.14)
  static const primarySoftStrong = Color(0x3DF2151C); // rgba(242,21,28,.24)

  // ---------------------------------------------------------------
  // Secundário — azul de apoio (chips e estados accionados).
  // ---------------------------------------------------------------
  static const secondary = Color(0xFF6CB8FF); // #6CB8FF
  static const secondaryPressed = Color(0xFF3E93F0); // #3E93F0
  static const secondarySoft = Color(0xFF0F1F2E); // #0F1F2E

  // ---------------------------------------------------------------
  // Fundamentos (tema escuro).
  // ---------------------------------------------------------------
  static const bg = Color(0xFF141414); // #141414 — cartões e superfícies
  static const surface = Color(0xFF000000); // #000000 — fundo da aplicação
  static const ink = Color(0xFFFFFFFF); // #FFFFFF — texto principal
  static const muted = Color(0xFFB9B9B9); // #B9B9B9 — texto secundário
  static const mutedLight = Color(0xFF858585); // #858585 — dicas e placeholders
  static const border = Color(0xFF1F1F1F); // #1F1F1F — linhas e contornos

  // ---------------------------------------------------------------
  // Estados.
  // ---------------------------------------------------------------
  static const success = Color(0xFF2BD46F); // #2BD46F
  static const successSoft = Color(0xFF0D2417); // fundo de badge "aberto"
  static const warning = Color(0xFFFFA41B); // #FFA41B
  static const warningSoft = Color(0xFF241704); // âmbar a 14% sobre preto
  static const danger = Color(0xFFF2151C); // #F2151C — erros e destrutivo
  static const dangerSoft = Color(0xFF2A0709); // fundo de aviso de erro
  static const dangerBorder = Color(0xFF5A1014); // contorno de erro
  static const dangerInk = Color(0xFFFF4A50); // texto de erro sobre escuro

  /// Tinta escura usada apenas nos selos "sólidos" (fundo branco puro,
  /// pousados sobre fotografias).
  static const solidInk = Color(0xFF17191F);
  static const solidSuccessInk = Color(0xFF067647);
  static const solidWarningInk = Color(0xFFB54708);
  static const solidDangerInk = Color(0xFFB42318);

  /// Fundo profundo usado nas telas de autenticação sobre a fotografia:
  /// sobreposição a preto puro, como no referencial escuro.
  static const deepNavy = Color(0xFF000000);
  static const deepNavyLight = Color(0xFF141414);

  /// Barra lateral fixa (tablet/desktop).
  static const sidebar = Color(0xFF0B0B0B);

  /// Sombra usada em cartões e na barra de navegação.
  static const cardShadow = BoxShadow(
    color: Color(0x99000000),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  // ---------------------------------------------------------------
  // Superfícies do tema escuro (equivalente directo dos tokens).
  // ---------------------------------------------------------------
  static const darkBg = Color(0xFF000000); // --bg
  static const darkCard = Color(0xFF141414); // --s1
  static const darkElevated = Color(0xFF1F1F1F); // --s2
  static const darkElevatedHigh = Color(0xFF2B2B2B); // --s3
  static const darkInk = Color(0xFFFFFFFF); // --tx
  static const darkMuted = Color(0xFFB9B9B9); // --tx2
  static const darkBorder = Color(0xFF2B2B2B); // --s3
  static const darkPrimarySoft = Color(0x24F2151C); // --red-soft
  static const darkPrimarySoftStrong = Color(0x3DF2151C);

  // ---------------------------------------------------------------
  // Aliases históricos usados em ecrãs e widgets.
  // ---------------------------------------------------------------
  static const blue = secondary;
  static const surfaceAlias = bg;
  static const line = border;
  static const paleBlue = secondarySoft;
  static const green = success;
  static const greenSoft = successSoft;
  static const greenInk = success;
  static const amber = warning;
  static const amberSoft = warningSoft;
  static const amberInk = warning;
  static const red = danger;
  static const redSoft = dangerSoft;
  static const darkSurface = darkBg;
  static const darkLine = darkBorder;
  static const primaryLight = primaryPressed;
  static const primaryText = textOrange;
}
