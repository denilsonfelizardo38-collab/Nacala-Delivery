import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/jb.dart';
import 'tracking_screen.dart';

/// Central de notificações: lista as notificações persistentes do servidor
/// (candidaturas, decisões, novos pedidos, mensagens de chat, mudanças de
/// estado) e, para clientes, complementa com os eventos reais dos pedidos.
/// Ao abrir, marca as notificações exibidas como lidas — nada fica apenas
/// numa mensagem temporária no ecrã.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Future<List<_NotificationItem>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<_NotificationItem>> _load() async {
    final scope = AppScope.of(context);
    // Convidado: o ecrã mostra o convite a entrar — sem chamadas à rede.
    if (!scope.isSignedIn) return const [];
    final api = scope.api;

    // 1) Notificações persistentes (qualquer papel autenticado).
    final notifications = await api.notifications();
    final unread = [
      for (final item in notifications)
        if (!item.isRead) item.id,
    ];
    if (unread.isNotEmpty) {
      try {
        await api.markNotificationsRead(ids: unread);
      } on ApiException {
        // Sem ligação a marcar: as notificações continuam visíveis e ficam
        // por ler para a próxima tentativa.
      }
    }

    // 2) Eventos dos pedidos do cliente (contexto com o nº do pedido).
    final items = <_NotificationItem>[];
    final covered = <String>{};
    if (scope.user?.isCustomer ?? false) {
      final orders = await api.orders();
      for (final order in orders) {
        for (final event in order.events) {
          // Uma mudança de estado já coberta pela notificação persistente
          // não aparece duas vezes.
          covered.add('${order.id}:${event.status}');
          items.add(_NotificationItem.event(order: order, event: event));
        }
      }
    }

    // 3) Notificações sem evento equivalente (candidaturas, chat, etc.).
    for (final item in notifications) {
      final orderId = item.data['order_id'];
      final status = item.data['status'];
      if (orderId is String && status is String) {
        if (covered.contains('$orderId:$status')) continue;
      }
      items.add(_NotificationItem.push(item));
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items.take(60).toList();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    try {
      await future;
    } on Exception {
      // O erro é apresentado pelo AsyncSection.
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsAuth = !AppScope.of(context).isSignedIn;
    final onBack = Navigator.of(context).canPop()
        ? () => Navigator.of(context).maybePop()
        : null;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            JbPageHeader(title: 'Notificações', onBack: onBack),
            Expanded(
              child: needsAuth
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 24),
                        EmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'As notificações são da tua conta',
                          message:
                              'Entra ou cria uma conta para receber atualizações '
                              'sobre os teus pedidos.',
                          actionLabel: 'Entrar ou criar conta',
                          onAction: () => Navigator.of(context)
                              .pushNamed('/roles', arguments: 'login'),
                        ),
                      ],
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _refresh,
                      child: AsyncSection<List<_NotificationItem>>(
                        future: _future,
                        onRetry: _refresh,
                        builder: (context, items) {
                          if (items.isEmpty) {
                            return ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                EmptyState(
                                  icon: Icons.notifications_none_rounded,
                                  title: 'Sem novidades',
                                  message:
                                      'Quando o teu pedido mudar de estado, '
                                      'avisamos-te aqui.',
                                ),
                              ],
                            );
                          }
                          return ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) =>
                                _NotificationTile(item: items[index]),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Item da lista: um evento real de pedido ou uma notificação persistente.
class _NotificationItem {
  const _NotificationItem.event({required this.order, required this.event})
    : notification = null;

  const _NotificationItem.push(this.notification)
    : order = null,
      event = null;

  /// Evento de pedido (cliente): tem nº do pedido e ligação ao tracking.
  final Order? order;
  final OrderEvent? event;

  /// Notificação persistente do servidor (candidaturas, chat, decisões…).
  final AppNotification? notification;

  bool get isPush => notification != null;

  DateTime get createdAt =>
      notification?.createdAt ?? event?.createdAt ?? DateTime(1970);
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final _NotificationItem item;

  IconData _iconFor(String status) => switch (status) {
    'pending' => Icons.receipt_long_rounded,
    'confirmed' => Icons.verified_rounded,
    'preparing' => Icons.restaurant_rounded,
    'ready' => Icons.inventory_2_rounded,
    'on_the_way' => Icons.delivery_dining_rounded,
    'delivered' => Icons.home_rounded,
    'cancelled' || 'rejected' => Icons.cancel_rounded,
    _ => Icons.notifications_rounded,
  };

  /// Ícone de uma notificação persistente pelo seu `kind`.
  IconData _pushIcon(String kind) => switch (kind) {
    'application_new' => Icons.how_to_reg_outlined,
    'application_approved' => Icons.verified_rounded,
    'application_rejected' || 'application_changes' => Icons.gavel_outlined,
    'new_order' => Icons.receipt_long_rounded,
    'chat_message' => Icons.chat_bubble_outline_rounded,
    _ => Icons.notifications_rounded,
  };

  (Color, Color) _colorsFor(BuildContext context, String status) {
    switch (status) {
      case 'delivered' || 'completed' || 'accepted':
        return (
          context.isDarkMode ? AppColors.darkElevated : AppColors.successSoft,
          context.successColor,
        );
      case 'cancelled' || 'rejected' || 'declined':
        return (
          context.isDarkMode ? AppColors.darkElevated : AppColors.dangerSoft,
          context.dangerColor,
        );
      case 'pending' || 'preparing' || 'ready':
        return (
          context.isDarkMode ? AppColors.darkElevated : AppColors.warningSoft,
          context.warningColor,
        );
      default:
        return (context.primarySoftColor, context.accentColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notification = item.notification;
    if (notification != null) return _pushTile(context, notification);

    final event = item.event!;
    final order = item.order!;
    final (background, foreground) = _colorsFor(context, event.status);
    final note = event.note?.trim() ?? '';
    final description = note.isNotEmpty
        ? note
        : (event.status == order.status ? order.statusDescription : '');

    return Material(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TrackingScreen(orderId: order.id),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            border: Border.all(color: context.lineColor),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _iconFor(event.status),
                  color: foreground,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order.number} · ${StatusBadge.labelFor(event.status)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      order.establishment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.mutedColor, fontSize: 11),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: context.mutedColor,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatDateTime(event.createdAt),
                style: TextStyle(
                  color: context.mutedColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Notificação persistente do servidor (candidaturas, decisões, chat…).
  ///
  /// Toca para o destino real quando a notificação aponta para um pedido;
  /// nos restantes casos (candidaturas, etc.) é apenas informativa — nunca
  /// abre um botão morto.
  Widget _pushTile(BuildContext context, AppNotification notification) {
    final orderId = notification.data['order_id'];
    final status = (notification.data['status'] as String?) ?? '';
    final (background, foreground) = status.isEmpty
        ? (context.primarySoftColor, context.accentColor)
        : _colorsFor(context, status);
    final canOpen = orderId is String && orderId.isNotEmpty;

    final tile = Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        border: Border.all(color: context.lineColor),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_pushIcon(notification.kind), color: foreground, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  notification.body,
                  style: TextStyle(
                    color: context.mutedColor,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatDateTime(notification.createdAt),
            style: TextStyle(
              color: context.mutedColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (!canOpen) return tile;
    return Material(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TrackingScreen(orderId: orderId),
          ),
        ),
        child: tile,
      ),
    );
  }
}
