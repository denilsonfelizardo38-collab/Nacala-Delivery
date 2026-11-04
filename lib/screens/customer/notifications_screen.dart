import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import 'tracking_screen.dart';

/// Central de notificações do cliente: lista os eventos reais dos pedidos
/// (estado, confirmação, preparação, entrega...) por ordem cronológica.
/// Não há contagem de "não lidas" — mostra apenas o que aconteceu de facto.
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
    final api = AppScope.of(context).api;
    final orders = await api.orders();
    final items = <_NotificationItem>[
      for (final order in orders)
        for (final event in order.events)
          _NotificationItem(order: order, event: event),
    ]..sort((a, b) => b.event.createdAt.compareTo(a.event.createdAt));
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
    final isGuest = AppScope.of(context).isGuest;
    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: SafeArea(
        top: false,
        child: isGuest
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 48),
                  EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'As notificações são da tua conta',
                    message:
                        'Entra ou cria uma conta para receber atualizações '
                        'sobre os teus pedidos.',
                    actionLabel: 'Entrar ou criar conta',
                    onAction: AppScope.of(context).exitGuestMode,
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
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _NotificationTile(item: items[index]),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _NotificationItem {
  const _NotificationItem({required this.order, required this.event});

  final Order order;
  final OrderEvent event;
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
    'cancelled' => Icons.cancel_rounded,
    'rejected' => Icons.cancel_rounded,
    _ => Icons.notifications_rounded,
  };

  (Color, Color) _colorsFor(String status) {
    switch (status) {
      case 'delivered' || 'completed' || 'accepted':
        return (AppColors.successSoft, AppColors.greenInk);
      case 'cancelled' || 'rejected' || 'declined':
        return (AppColors.dangerSoft, AppColors.dangerInk);
      case 'pending' || 'preparing' || 'ready':
        return (AppColors.warningSoft, AppColors.amberInk);
      default:
        return (AppColors.primarySoft, AppColors.primaryPressed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = item.event;
    final order = item.order;
    final (background, foreground) = _colorsFor(event.status);
    final note = event.note?.trim() ?? '';
    final description = note.isNotEmpty
        ? note
        : (event.status == order.status ? order.statusDescription : '');

    return Material(
      color: AppColors.bg,
      borderRadius: BorderRadius.circular(18),
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
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(13),
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
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          color: AppColors.muted,
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
                style: const TextStyle(
                  color: AppColors.muted,
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
}
