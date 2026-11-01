import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
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
      ),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final heroHeight = (constraints.maxHeight * 0.48).clamp(
                270.0,
                480.0,
              );
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      SizedBox(height: heroHeight, child: _CityHero()),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(26, 32, 26, 20),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'O sabor de Nacala,\nà tua porta.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontSize: 27,
                                      height: 1.18,
                                      letterSpacing: -0.6,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Descobre restaurantes e lojas perto de ti. '
                                'Escolhe o que gostas e recebe em casa.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppColors.muted,
                                      height: 1.55,
                                    ),
                              ),
                              if (startupMessage != null) ...[
                                const SizedBox(height: 14),
                                InfoRow(
                                  icon: Icons.cloud_off_outlined,
                                  text: startupMessage,
                                  color: AppColors.danger,
                                ),
                              ],
                              const SizedBox(height: 24),
                              FilledButton(
                                onPressed: onSignIn,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text('Entrar'),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(
                                    color: AppColors.primary,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text('Criar conta'),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(color: AppColors.border),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      'ou',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.muted),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(color: AppColors.border),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              GoogleSignInButton(
                                onPressed: () => showAppSnack(
                                  context,
                                  'A entrada com Google ainda não está ativa. '
                                  'Falta configurar o OAuth do Google e a '
                                  'validação segura no servidor.',
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: onGuest,
                                child: const Text('Explorar como convidado'),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Entrega local, feita com cuidado.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: AppColors.muted,
                                      letterSpacing: 0.1,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CityHero extends StatelessWidget {
  const _CityHero();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
      child: Stack(
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
                  Color(0x50031A43),
                  Color(0x08031A43),
                  Color(0xDD031A43),
                ],
                stops: [0, 0.4, 1],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppLogo(size: 42, onDark: true),
                      const SizedBox(width: 11),
                      const Expanded(
                        child: Text(
                          'Nacala Entrega',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Nacala',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.near_me_outlined,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'A CIDADE À SUA PORTA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 11),
                  const Text(
                    'Os teus favoritos\ncomeçam aqui.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 29,
                      height: 1.17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Restaurantes e lojas da tua cidade, num só lugar.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
