import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import 'tracking_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _initialized = false;
  String _status = 'in_progress';
  Future<List<Order>>? _future;

  static const _filters = [
    ('in_progress', 'Em curso'),
    ('completed', 'Entregues'),
    ('all', 'Todos'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final state = AppScope.of(context);
    if (!state.isGuest) _future = state.api.orders(status: _status);
  }

  void _leaveGuestMode() {
    AppScope.of(context).exitGuestMode();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _reload() {
    setState(() {
      _future = AppScope.of(context).api.orders(status: _status);
    });
  }

  void _select(String status) {
    if (_status == status) return;
    setState(() {
      _status = status;
      _future = AppScope.of(context).api.orders(status: status);
    });
  }

  Future<void> _open(Order order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TrackingScreen(orderId: order.id)),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (AppScope.of(context).isGuest) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meus pedidos')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Os pedidos são da tua conta',
              message:
                  'Explora o catálogo como convidado. Para acompanhar pedidos, '
                  'entra ou cria uma conta.',
              actionLabel: 'Entrar ou criar conta',
              onAction: _leaveGuestMode,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus pedidos'),
        actions: const [CartButton(), SizedBox(width: 4)],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Acompanhe o estado e os detalhes das suas encomendas.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.mutedColor),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  for (final filter in _filters) ...[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: filter.$2,
                          selected: _status == filter.$1,
                          onTap: () => _select(filter.$1),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    AsyncSection<List<Order>>(
                      future: _future,
                      onRetry: _reload,
                      builder: (context, orders) {
                        if (orders.isEmpty) {
                          return EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: _status == 'in_progress'
                                ? 'Sem pedidos em curso'
                                : 'Sem pedidos para mostrar',
                            message: _status == 'in_progress'
                                ? 'Quando fizer um pedido, poderá acompanhá-lo '
                                      'aqui em tempo real.'
                                : 'Os pedidos aparecem aqui depois de criados.',
                          );
                        }
                        return Column(
                          children: [
                            for (final order in orders)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _OrderCard(
                                  order: order,
                                  onTap: () => _open(order),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.accentColor : context.cardColor,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? context.accentColor : context.lineColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : context.inkColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.number,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    StatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  order.establishment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.mutedColor, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 14,
                      color: context.mutedColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${order.itemCount} item(ns)',
                      style: TextStyle(color: context.mutedColor, fontSize: 11),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: context.mutedColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        formatDateTime(order.createdAt),
                        style: TextStyle(
                          color: context.mutedColor,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      formatMoney(order.totalCents),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
