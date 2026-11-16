import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/jb.dart';

/// Lista de conversas do utilizador autenticado (cliente, parceiro ou
/// estafeta). A partir daqui o utilizador entra numa conversa existente ou
/// inicia uma nova com um parceiro/estafeta/cliente.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  Future<List<Conversation>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future == null) _reload();
  }

  void _reload() {
    setState(() {
      _future = AppScope.of(context).api.conversations();
    });
  }

  void _openConversation(Conversation conversation) {
    Navigator.of(context).pushNamed(
      '/chat',
      arguments: {
        'id': conversation.id,
        'order_id': conversation.orderId,
        'other_user_id': conversation.otherUserId,
        'other_user_name': conversation.otherUserName,
        'other_role': conversation.otherRole,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.isSignedIn) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              const JbPageHeader(title: 'Mensagens'),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Inicia sessão para conversar',
                      message:
                          'As mensagens estão disponíveis depois de entrares '
                          'na tua conta.',
                      actionLabel: 'Entrar',
                      onAction: () =>
                          Navigator.of(context).pushNamed('/login'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const JbPageHeader(title: 'Mensagens'),
            Expanded(
              child: AsyncSection<List<Conversation>>(
                future: _future,
                onRetry: _reload,
                emptyMessage: 'Ainda não tens conversas.',
                builder: (context, conversations) {
                  if (conversations.isEmpty) {
                    return EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Sem conversas ainda',
                      message:
                          'Começa uma conversa com um parceiro ou estafeta '
                          'a partir de um pedido.',
                      actionLabel: 'Ver pedidos',
                      onAction: () =>
                          Navigator.of(context).pushNamed('/orders'),
                    );
                  }
                  return ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final c = conversations[index];
                      return _ConversationTile(
                        conversation: c,
                        onTap: () => _openConversation(c),
                      );
                    },
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

/// Uma linha da lista de conversas.
class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = conversation.otherUserName ?? 'Participante';
    final roleLabel = switch (conversation.otherRole) {
      'customer' => 'Cliente',
      'partner' => 'Parceiro',
      'delivery' => 'Estafeta',
      _ => '',
    };
    final unread = conversation.unreadCount > 0;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primarySoft,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (roleLabel.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          roleLabel,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  conversation.lastBody ?? 'Sem mensagens ainda',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: context.mutedColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (conversation.lastMessageAt != null)
                Text(
                  _formatTime(conversation.lastMessageAt!),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.mutedColor),
                ),
              if (unread) ...[
                const SizedBox(height: 6),
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final d = DateTime.parse(iso);
      final now = DateTime.now();
      if (d.year == now.year &&
          d.month == now.month &&
          d.day == now.day) {
        return '${d.hour.toString().padLeft(2, '0')}:'
            '${d.minute.toString().padLeft(2, '0')}';
      }
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';
    } catch (_) {
      return iso;
    }
  }
}
