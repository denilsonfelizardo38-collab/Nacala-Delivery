import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Passo seguinte aos botões ENTRAR / CRIAR CONTA da Home: o utilizador
/// escolhe o tipo de conta — CLIENTE, ESTABELECIMENTO ou ENTREGADOR — e
/// segue para o processo próprio de cada tipo (login ou candidatura).
///
/// Administradores e funcionários não aparecem aqui: as contas desses papéis
/// são criadas internamente pelo administrador, nunca pela área pública.
///
/// A rota `/roles` recebe `arguments` como string:
///  * `'login'`    → os cartões abrem o login do tipo escolhido;
///  * `'register'` → os cartões abrem o registo/candidatura do tipo escolhido.
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key, this.intent = 'login'});

  final String intent;

  /// Converte os argumentos da rota num intento válido.
  static const allowedIntents = {'login', 'register'};

  static String intentFromArguments(Object? arguments) =>
      allowedIntents.contains(arguments) ? arguments! as String : 'login';

  bool get _registering => intent == 'register';

  @override
  Widget build(BuildContext context) {
    final options = <_RoleOption>[
      _RoleOption(
        key: 'cliente',
        title: 'CLIENTE',
        icon: Icons.person_rounded,
        description: 'Faz pedidos, guarda favoritos e acompanha as entregas.',
        actionLabel: _registering ? 'Criar conta de cliente' : 'Entrar',
        destination: _registering ? '/register' : '/login',
      ),
      _RoleOption(
        key: 'estabelecimento',
        title: 'ESTABELECIMENTO',
        icon: Icons.storefront_rounded,
        description:
            'Publica os teus produtos, recebe pedidos e cresce em Nacala.',
        actionLabel: _registering
            ? 'Registar o meu estabelecimento'
            : 'Entrar',
        destination: _registering ? '/establishment/apply' : '/login',
      ),
      _RoleOption(
        key: 'entregador',
        title: 'ENTREGADOR',
        icon: Icons.two_wheeler_rounded,
        description: 'Aceita entregas e ganha dinheiro na plataforma.',
        actionLabel: _registering ? 'Quero ser entregador' : 'Entrar',
        destination: _registering ? '/courier/apply' : '/login',
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            return Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 32 : 22,
                  vertical: 22,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(onBack: Navigator.of(context).maybePop),
                      const SizedBox(height: 30),
                      Text(
                        _registering
                            ? 'Cria a tua conta'
                            : 'Entra no Nacala Delivery',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          height: 1.08,
                          letterSpacing: -1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _registering
                            ? 'Escolhe o tipo de conta que queres criar. '
                                'Cada tipo tem o seu próprio processo de registo.'
                            : 'Escolhe o tipo de conta com o queres entrar. '
                                'Depois do login, o sistema identifica '
                                'automaticamente o teu perfil e abre o painel '
                                'certo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 13.5,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 26),
                      for (final option in options) ...[
                        _RoleCard(
                          option: option,
                          onTap: () => Navigator.of(context)
                              .pushNamed(option.destination),
                        ),
                        const SizedBox(height: 14),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'As contas de administrador e funcionário são criadas '
                        'pela equipa interna da plataforma.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RoleOption {
  const _RoleOption({
    required this.key,
    required this.title,
    required this.icon,
    required this.description,
    required this.actionLabel,
    required this.destination,
  });

  final String key;
  final String title;
  final IconData icon;
  final String description;
  final String actionLabel;
  final String destination;
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.option, required this.onTap});

  final _RoleOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.darkCard,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        key: ValueKey('role-${option.key}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(option.icon, color: AppColors.primary, size: 27),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            option.actionLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.primary,
                          size: 15,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.45),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho de auth: botão circular de voltar + lockup da marca
/// (mesmo padrão do LoginScreen).
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (Navigator.of(context).canPop()) ...[
          Material(
            color: AppColors.darkCard,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Voltar',
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.30),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.delivery_dining_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(width: 11),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NACALA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                height: 1.1,
              ),
            ),
            Text(
              'DELIVERY',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
