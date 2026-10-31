import 'package:flutter/material.dart';

import '../core/api_config.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

/// Ecrã de arranque. Não simula progresso: mostra apenas a identidade da
/// marca enquanto a sessão é restaurada.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.darkBg, AppColors.navy],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size: 92),
                const SizedBox(height: 22),
                const Text(
                  'Nacala Entrega',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Entregas locais em Nacala-Porto',
                  style: TextStyle(color: Color(0xFF9DB6D4), fontSize: 14),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Color(0xFF5AA0F5),
                  ),
                ),
                const Spacer(),
                Text(
                  'versão $appVersion',
                  style: const TextStyle(
                    color: Color(0xFF6C87A8),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
