import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../widgets/common.dart';

/// Apresentação da marca enquanto a sessão local é restaurada.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/login_bg.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.primary),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xAA0755E9),
                    Color(0x300755E9),
                    Color(0xA6031A43),
                    Color(0xE6031A43),
                  ],
                  stops: [0, 0.38, 0.72, 1],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 4),
                  const AppLogo(size: 88, onDark: true),
                  const SizedBox(height: 17),
                  const Text(
                    'Nacala\nEntrega',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 31,
                      height: 1.03,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    'A cidade à sua porta.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(flex: 5),
                  const SizedBox(height: 164),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 164,
              child: ClipPath(
                clipper: _SplashWaveClipper(),
                child: ColoredBox(
                  color: Colors.white,
                  child: Align(
                    alignment: const Alignment(0, -0.06),
                    child: SizedBox(
                      width: 25,
                      height: 25,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.primary,
                        semanticsLabel: 'A preparar a aplicação',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.5,
        -size.height * 0.08,
        size.width,
        size.height * 0.72,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _SplashWaveClipper oldClipper) => false;
}
