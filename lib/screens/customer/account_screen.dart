import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/feedback.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _editAddress(BuildContext context, AppState state) async {
    final controller = TextEditingController(text: state.address);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Morada de entrega'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Bairro, rua, casa e referência',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.trim().length >= 5) {
      state.setAddress(result);
    }
  }

  void _showInfo(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text('A sua conta', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 18),
        Material(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showInfo(
              context,
              title: 'Entrar na conta',
              message:
                  'A autenticação por número de telemóvel chega na próxima '
                  'versão. Por agora pode explorar a app como convidado.',
            ),
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: context.isDarkMode
                        ? context.accentColor.withValues(alpha: 0.2)
                        : AppColors.paleBlue,
                    child: Icon(
                      Icons.person_rounded,
                      color: context.accentColor,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bem-vindo a Nacala',
                          style: TextStyle(
                            color: context.inkColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Entre para gerir a sua conta',
                          style: TextStyle(
                            color: context.mutedColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: context.mutedColor),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 13),
        _AccountOption(
          icon: Icons.location_on_outlined,
          title: 'Morada de entrega',
          subtitle: state.address,
          onTap: () => _editAddress(context, state),
        ),
        const SizedBox(height: 9),
        _AccountOption(
          icon: Icons.help_outline_rounded,
          title: 'Ajuda e suporte',
          onTap: () => _showInfo(
            context,
            title: 'Ajuda e suporte',
            message:
                'Fale connosco em apoio@nacalaentrega.co.mz ou pelo número '
                '+258 84 000 0000, todos os dias das 07h às 21h.',
          ),
        ),
        const SizedBox(height: 9),
        _AccountOption(
          icon: Icons.info_outline_rounded,
          title: 'Sobre a Nacala Entrega',
          onTap: () => _showInfo(
            context,
            title: 'Nacala Entrega',
            message:
                'Versão 1.0.0\n\nEntregas locais em Nacala-Porto, Nampula. '
                'Ligamos clientes, restaurantes, mercados, farmácias e lojas '
                'de bairro.',
          ),
        ),
        const SizedBox(height: 22),
        Text('DEMONSTRAÇÃO', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        Material(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(15),
          child: SwitchListTile.adaptive(
            value: state.demoMode,
            onChanged: state.setDemoMode,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Text(
              'Modo demonstração',
              style: TextStyle(
                color: context.inkColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              'Mostra os painéis de parceiro e administração.',
              style: TextStyle(color: context.mutedColor, fontSize: 11),
            ),
          ),
        ),
        if (state.demoMode && state.orders.isNotEmpty) ...[
          const SizedBox(height: 9),
          _AccountOption(
            icon: Icons.delete_sweep_outlined,
            title: 'Limpar histórico de pedidos',
            onTap: () {
              state.clearOrders();
              showMessage(context, 'Histórico de pedidos limpo.');
            },
          ),
        ],
        const SizedBox(height: 22),
        Center(
          child: Text(
            'Nacala Entrega · v1.0.0',
            style: TextStyle(color: context.mutedColor, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _AccountOption extends StatelessWidget {
  const _AccountOption({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          child: Row(
            children: [
              Icon(icon, color: context.accentColor, size: 21),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.inkColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.mutedColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.mutedColor),
            ],
          ),
        ),
      ),
    );
  }
}
