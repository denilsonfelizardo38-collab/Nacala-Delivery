import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Arranque da marca: fundo preto absoluto, logótipo a saltar (com brilho
/// vermelho), wordmark a subir letra a letra, três riscos vermelhos a
/// atravessar o ecrã, **mota de entrega com o entregador a passar da
/// direita para a esquerda** e saída em "wipe" da esquerda para a
/// direita — revelando a aplicação por baixo.
///
/// Tempo total: 1,85 s (o gate da aplicação mantém este ecrã durante a
/// animação; quem desligar as animações do sistema vê uma versão estática).
/// A animação corre uma única vez por arranque frio — voltar à Home não
/// repete a passagem da mota.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// Duração total do arranque, em segundos — o gate da aplicação (`app.dart`)
/// mantém o ecrã exactamente durante este tempo.
const double _splashSeconds = 1.85;

/// Valor de uma fase [from]..[to] (em segundos, base 1,85 s) aplicando
/// a curva indicada — sem depender de `CurvedAnimation` transitório.
///
/// O progresso do controlador (0–1) é convertido para segundos antes de
/// ser comparado com as janelas em segundos das fases.
double _phase(AnimationController c, double from, double to, Curve curve) {
  final seconds = c.value * _splashSeconds;
  final t = ((seconds - from) / (to - from)).clamp(0.0, 1.0).toDouble();
  return curve.transform(t);
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1850),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Com as animações desactivadas no sistema: versão estática, breve.
    if (MediaQuery.disableAnimationsOf(context)) {
      return const _StaticSplash();
    }
    final width = MediaQuery.sizeOf(context).width;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        // O conteúdo vive DENTRO do builder: cada "tick" reconstrói as
        // fases (logo, wordmark, riscos, mota). Passar o Stack como
        // `child:` do AnimatedBabylder congelaria tudo no valor inicial.
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // Wipe final: a área visível encolhe da esquerda para a
            // direita (`clip-path: inset(0 0 0 X%)` do referencial).
            final wipe = _phase(
              _controller,
              1.3,
              1.8,
              const Cubic(0.7, 0, 0.3, 1),
            );
            return ClipRect(
              clipper: _WipeClipper(wipe),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Logo(controller: _controller),
                        const SizedBox(height: 18),
                        _Wordmark(controller: _controller),
                        const SizedBox(height: 26),
                        // Indicador suave durante a restauração da sessão.
                        _Pulse(controller: _controller),
                      ],
                    ),
                  ),
                  for (var i = 0; i < 3; i++)
                    _Streak(controller: _controller, index: i, width: width),
                  _Moto(controller: _controller),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Logótipo: entrada em "pop" elástico e saída para a direita.
class _Logo extends StatelessWidget {
  const _Logo({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final pop = _phase(controller, 0, 0.65, Curves.elasticOut);
    final fly = _phase(controller, 1.05, 1.6, Curves.easeInCubic);
    final screenWidth = MediaQuery.sizeOf(context).width;
    return Opacity(
      opacity: _phase(controller, 0, 0.3, Curves.easeOut).clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(screenWidth * 0.75 * fly, 0),
        child: Transform.rotate(
          angle: (-10 + 10 * pop + 4 * fly) * 3.14159265 / 180,
          child: Transform.scale(
            scale: 0.35 + 0.65 * pop,
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x80F2151C),
                    blurRadius: 60,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: const Icon(
                Icons.delivery_dining_rounded,
                color: Colors.white,
                size: 52,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wordmark em duas palavras: sobem em cascata e desvanecem para a
/// esquerda quando os riscos entram.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final out = _phase(controller, 1.05, 1.3, Curves.easeIn);
    return Opacity(
      opacity: (1 - out).clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(-12 * out, 0),
        // FittedBox: o wordmark encolhe em ecrãs estreitos (320–390 px)
        // e com escala de texto ampliada, sem transbordar a Row.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _span('Nacala', 0.28),
              const SizedBox(width: 10),
              _span('Delivery', 0.4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _span(String text, double delay) {
    final rise = _phase(controller, delay, delay + 0.5, Curves.easeOutCubic);
    return Transform.translate(
      offset: Offset(0, 20 * (1 - rise)),
      child: Opacity(
        opacity: rise.clamp(0.0, 1.0),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: AppTheme.displayFontFamily,
            fontSize: 36,
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: -1.3,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Indicador circular discreto que aparece por baixo do wordmark.
class _Pulse extends StatelessWidget {
  const _Pulse({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final show = _phase(controller, 0.85, 1.15, Curves.easeOut);
    return Opacity(
      opacity: show.clamp(0.0, 1.0),
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: AppColors.primary,
          semanticsLabel: 'A preparar a aplicação',
        ),
      ),
    );
  }
}

/// Risco vermelho que atravessa o ecrã (`.sp-streak`): entra pela
/// esquerda, acende ao meio da passagem e some à direita.
class _Streak extends StatelessWidget {
  const _Streak({
    required this.controller,
    required this.index,
    required this.width,
  });

  final AnimationController controller;
  final int index;
  final double width;

  @override
  Widget build(BuildContext context) {
    final start = 1.02 + index * 0.06;
    final v = _phase(controller, start, start + 0.5, Curves.linear);
    // Opacidade: sobe até 25 % da passagem e cai até ao fim.
    final opacity = v <= 0.25
        ? v / 0.25
        : ((1 - v) / 0.75).clamp(0.0, 1.0);
    final top = [0.46, 0.50, 0.54][index];
    final height = index == 1 ? 5.0 : 3.0;
    return Positioned(
      top: MediaQuery.sizeOf(context).height * top,
      left: -width * 0.45,
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(width * 1.5 * v, 0),
          child: Container(
            width: width * 0.45,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: const LinearGradient(
                colors: [Colors.transparent, AppColors.primary],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mota de entrega com o entregador: entra pela direita, atravessa o
/// ecrã por baixo da marca e desaparece completamente pelo lado
/// esquerdo antes do "wipe" final.
///
/// Janela da passagem: 0,62 s → 1,42 s (base 1,85 s). A velocidade é
/// constante (uma mota a passar), com um ligeiro "salto" da suspensão
/// e as rodas a rodar em função da distância percorrida.
class _Moto extends StatelessWidget {
  const _Moto({required this.controller});

  final AnimationController controller;

  /// Início e fim da passagem, em segundos.
  static const double _from = 0.62;
  static const double _to = 1.42;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // 0 antes do início, 1 depois do fim — fora do ecrã em ambos os casos.
    final v = _phase(controller, _from, _to, Curves.linear);
    final motoW = (size.width * 0.46).clamp(156.0, 220.0);
    final motoH = motoW * 0.55;
    // Centro por baixo da coluna da marca, com folga para ecrãs curtos.
    final centerY = math.min(
      size.height - motoH / 2 - 12,
      size.height / 2 + 119 + motoH / 2,
    );
    // Da direita (fora do ecrã) até sair totalmente pela esquerda.
    final left = (size.width + motoW) - (size.width + motoW * 2) * v;
    final bob = math.sin(v * math.pi * 5) * 1.5;
    final turn = v * math.pi * 12;
    return Positioned(
      left: left,
      top: centerY - motoH / 2 + bob,
      width: motoW,
      height: motoH,
      child: CustomPaint(painter: _MotoPainter(turn: turn)),
    );
  }
}

/// Desenho da mota (caixa de desenho 200 × 110, voltada para a
/// direita e espelhada para viajar da direita para a esquerda).
class _MotoPainter extends CustomPainter {
  const _MotoPainter({required this.turn});

  /// Rotação das rodas (radianos), proporcional à distância percorrida.
  final double turn;

  static const Color _red = AppColors.primary;
  static const Color _white = Colors.white;
  static const Color _grey = Color(0xFFB9B9B9);
  static const Color _dim = Color(0xFF858585);
  static const Color _dark = Color(0xFF2B2B2B);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 200;
    canvas.save();
    canvas.scale(s, s);
    canvas.translate(200, 0);
    canvas.scale(-1, 1);

    // Brilho vermelho suave por trás da mota.
    canvas.drawCircle(
      const Offset(110, 66),
      96,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x2AF2151C), Color(0x00F2151C)],
        ).createShader(Rect.fromCircle(center: Offset(110, 66), radius: 96)),
    );

    _trail(canvas);
    _wheel(canvas, const Offset(76, 74));
    _wheel(canvas, const Offset(172, 74));
    _bike(canvas);
    _rider(canvas);

    canvas.restore();
  }

  /// Rastos de velocidade atrás da mota (lado direito do desenho).
  void _trail(Canvas canvas) {
    const ys = [22.0, 50.0, 84.0];
    const lengths = [34.0, 24.0, 30.0];
    for (var i = 0; i < ys.length; i++) {
      final rect = Rect.fromLTWH(4, ys[i], lengths[i], 4);
      canvas.drawLine(
        rect.topLeft,
        rect.topRight,
        Paint()
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..shader = const LinearGradient(
            colors: [Colors.transparent, _red],
          ).createShader(rect),
      );
    }
  }

  /// Roda com pneu, aro, raios a rodar e cubo vermelho.
  void _wheel(Canvas canvas, Offset c) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.drawCircle(
      Offset.zero,
      24,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = _grey,
    );
    canvas.save();
    canvas.rotate(turn);
    final spoke = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = _dim;
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * math.pi / 5;
      canvas.drawLine(
        Offset.fromDirection(a, 7),
        Offset.fromDirection(a, 15),
        spoke,
      );
    }
    canvas.restore();
    canvas.drawCircle(
      Offset.zero,
      15.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _white,
    );
    canvas.drawCircle(Offset.zero, 5, Paint()..color = _red);
    canvas.restore();
  }

  /// Chassi, caixa de entrega, banco, tanque, motor e para-choques.
  void _bike(Canvas canvas) {
    final stroke = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Linha de chão (apoiu visual).
    canvas.drawLine(
      const Offset(48, 100),
      const Offset(196, 100),
      stroke
        ..strokeWidth = 3
        ..color = _white.withValues(alpha: 0.12),
    );

    // Suporte da caixa e caixa de entrega.
    canvas.drawLine(
      const Offset(50, 44),
      const Offset(106, 44),
      stroke..strokeWidth = 3..color = _grey,
    );
    canvas.drawLine(
      const Offset(78, 44),
      const Offset(76, 58),
      stroke..strokeWidth = 4..color = _white,
    );
    final box = RRect.fromRectAndRadius(
      const Rect.fromLTWH(46, 10, 46, 30),
      const Radius.circular(6),
    );
    canvas.drawRRect(box, Paint()..color = _red);
    canvas.drawRRect(
      box,
      stroke..strokeWidth = 2.5..color = _white,
    );
    canvas.drawLine(
      const Offset(46, 24),
      const Offset(92, 24),
      stroke..strokeWidth = 3..color = _white,
    );

    // Braço da suspensão / chassi.
    canvas.drawLine(
      const Offset(76, 74),
      const Offset(128, 68),
      stroke..strokeWidth = 6..color = _white,
    );

    // Banco.
    final seat = RRect.fromRectAndRadius(
      const Rect.fromLTWH(94, 50, 40, 12),
      const Radius.circular(5),
    );
    canvas.drawRRect(seat, Paint()..color = _dark);
    canvas.drawRRect(seat, stroke..strokeWidth = 2..color = _white);

    // Tanque vermelho.
    final tank = Path()
      ..moveTo(132, 50)
      ..lineTo(164, 52)
      ..lineTo(166, 64)
      ..lineTo(132, 64)
      ..close();
    canvas.drawPath(tank, Paint()..color = _red);
    canvas.drawPath(tank, stroke..strokeWidth = 2..color = _white);

    // Motor e escape.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(124, 64, 32, 16),
        const Radius.circular(4),
      ),
      Paint()..color = _dim,
    );
    canvas.drawPath(
      Path()
        ..moveTo(130, 82)
        ..quadraticBezierTo(106, 92, 86, 88),
      stroke..strokeWidth = 5..color = _grey,
    );

    // Forca dianteira, guidão e farol.
    canvas.drawLine(
      const Offset(166, 48),
      const Offset(172, 74),
      stroke..strokeWidth = 6..color = _white,
    );
    canvas.drawLine(
      const Offset(160, 42),
      const Offset(182, 37),
      stroke..strokeWidth = 5..color = _white,
    );
    canvas.drawCircle(const Offset(180, 58), 6, Paint()..color = _white);

    // Para-lamas dianteiro (vermelho).
    canvas.drawArc(
      Rect.fromCircle(center: Offset(172, 74), radius: 29),
      1.15 * math.pi,
      0.7 * math.pi,
      false,
      stroke..strokeWidth = 5..color = _red,
    );
  }

  /// Entregador inclinado: casco branco com viseira vermelha, corpo de
  /// entrega vermelho e pernas/bracos brancos.
  void _rider(Canvas canvas) {
    final stroke = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Pernas (por cima do motor).
    canvas.drawPath(
      Path()
        ..moveTo(110, 52)
        ..lineTo(140, 66)
        ..lineTo(132, 80),
      stroke..strokeWidth = 9..color = _white,
    );
    canvas.drawCircle(const Offset(132, 81), 5, Paint()..color = _dark);

    // Corpo (uniforme vermelho).
    canvas.drawLine(
      const Offset(136, 40),
      const Offset(110, 50),
      stroke..strokeWidth = 16..color = _red,
    );

    // Braço até ao guidão.
    canvas.drawPath(
      Path()
        ..moveTo(136, 42)
        ..lineTo(158, 46)
        ..lineTo(170, 44),
      stroke..strokeWidth = 7..color = _white,
    );
    canvas.drawCircle(const Offset(170, 44), 4.5, Paint()..color = _dark);

    // Casco.
    canvas.drawCircle(const Offset(148, 24), 13, Paint()..color = _white);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(148, 24), radius: 10.5),
      -0.75,
      1.5,
      false,
      stroke..strokeWidth = 5..color = _red,
    );
  }

  @override
  bool shouldRepaint(covariant _MotoPainter old) => old.turn != turn;
}

/// Recorta o splash conforme o progresso do wipe final.
class _WipeClipper extends CustomClipper<Rect> {
  const _WipeClipper(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(size.width * progress, 0, size.width * (1 - progress), size.height);

  @override
  bool shouldReclip(covariant _WipeClipper old) => old.progress != progress;
}

/// Versão estática (animações do sistema desligadas).
class _StaticSplash extends StatelessWidget {
  const _StaticSplash();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(
                  Icons.delivery_dining_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),
              const SizedBox(height: 18),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: const Text(
                  'Nacala Delivery',
                  style: TextStyle(
                    fontFamily: AppTheme.displayFontFamily,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
