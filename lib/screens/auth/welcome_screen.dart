import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

import 'package:flutter/services.dart';

import '../../state/app_scope.dart';
import '../../widgets/common.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onSignIn,
    required this.onGuest,
  });

  final VoidCallback onSignIn;
  final VoidCallback onGuest;

  @override
  Widget build(BuildContext context) {
    final startupMessage = AppScope.of(context).startupMessage;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.deepNavy,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.deepNavy,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Fotografia do motociclista.
            Image.asset(
              'assets/images/login_bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (context, error, stackTrace) {
                return const ColoredBox(color: AppColors.deepNavy);
              },
            ),

            // Gradiente para melhorar a leitura dos elementos.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x55001635),
                    Color(0x18001635),
                    Color(0x44001635),
                    Color(0xBB001A38),
                    Color(0xF5001835),
                  ],
                  stops: [0.0, 0.28, 0.52, 0.76, 1.0],
                ),
              ),
            ),

            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(26, 24, 26, 12),
                          child: Column(
                            children: [
                              const Spacer(flex: 2),

                              // LOGÓTIPO.
                              const AppLogo(size: 104, onDark: true),

                              const SizedBox(height: 12),

                              // NOME DA MARCA.
                              RichText(
                                textAlign: TextAlign.center,
                                text: const TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Nacala',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 35,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -1.5,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Delivery',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 35,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 7),

                              const Text(
                                'Pedido feito. Entrega garantida!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),

                              const Spacer(flex: 3),

                              // LOCALIZAÇÃO.
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 17,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.deepNavy.withValues(
                                    alpha: 0.45,
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: AppColors.primary,
                                      size: 21,
                                    ),
                                    SizedBox(width: 7),
                                    Text(
                                      'Nacala-Porto',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 5),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Colors.white,
                                      size: 19,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 25),

                              // BOTÃO ENTRAR.
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: FilledButton(
                                  onPressed: onSignIn,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 5,
                                    shadowColor: Colors.black45,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(32),
                                    ),
                                  ),
                                  child: const Text(
                                    'Entrar',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // BOTÃO CRIAR CONTA.
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const RegisterScreen(),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: AppColors.primary,
                                      width: 1.8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(32),
                                    ),
                                  ),
                                  child: const Text(
                                    'Criar Conta',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              // CONTINUAR COMO CONVIDADO.
                              TextButton(
                                onPressed: onGuest,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white.withValues(
                                    alpha: 0.9,
                                  ),
                                  minimumSize: const Size.fromHeight(46),
                                  textStyle: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                child: const Text('Explorar como convidado'),
                              ),

                              // MENSAGEM DE INICIALIZAÇÃO.
                              if (startupMessage != null) ...[
                                const SizedBox(height: 13),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.cloud_off_outlined,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Text(
                                          startupMessage,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 10),

                              const SizedBox(height: 5),

                              const SizedBox(height: 15),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
