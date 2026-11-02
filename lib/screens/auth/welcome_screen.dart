
import 'package:flutter/material.dart';
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

  static const Color orange = Color(0xFFFF7900);
  static const Color navy = Color(0xFF06264B);

  @override
  Widget build(BuildContext context) {
    final startupMessage = AppScope.of(context).startupMessage;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: navy,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: navy,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Fotografia de Nacala-Porto em ecrã inteiro.
            Image.asset(
              'assets/images/login_bg.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: navy),
            ),

            // Camada escura para garantir a leitura dos textos.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x55001635),
                    Color(0x18001635),
                    Color(0xAA001A38),
                    Color(0xF0001835),
                  ],
                  stops: [0.0, 0.30, 0.62, 1.0],
                ),
              ),
            ),

            SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            28, 65, 28, 24,
                          ),
                          child: Column(
                            children: [
                              const Spacer(flex: 2),

                              // Logótipo.
                              const AppLogo(
                                size: 104,
                                onDark: true,
                              ),

                              const SizedBox(height: 14),

                              // Nome da marca.
                              RichText(
                                textAlign: TextAlign.center,
                                text: const TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Nacala',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -1.5,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Delivery',
                                      style: TextStyle(
                                        color: orange,
                                        fontSize: 36,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 8),

                              const Text(
                                'Pedido feito. Entrega garantida!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.2,
                                ),
                              ),

                              const Spacer(flex: 2),

                              // Localização.
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withValues(
                                      alpha: 0.30,
                                    ),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: orange,
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

                              const SizedBox(height: 30),

                              // Botão Entrar.
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: FilledButton(
                                  onPressed: onSignIn,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: orange,
                                    foregroundColor: Colors.white,
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(32),
                                    ),
                                  ),
                                  child: const Text(
                                    'Entrar',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Botão Criar Conta.
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const RegisterScreen(),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: orange,
                                      width: 1.7,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(32),
                                    ),
                                  ),
                                  child: const Text(
                                    'Criar Conta',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              if (startupMessage != null) ...[
                                const SizedBox(height: 15),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(
                                      alpha: 0.45,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.cloud_off_outlined,
                                        color: Colors.orange,
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

                              const Spacer(flex: 1),

                              // Acesso de convidado.
                              TextButton(
                                onPressed: onGuest,
                                child: const Text(
                                  'Explorar como convidado',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              const Text(
                                'Nacala-Porto mais perto de si!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Container(
                                width: 65,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: orange,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),

                              const SizedBox(height: 12),
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
