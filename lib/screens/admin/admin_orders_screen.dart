import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  bool _initialized = false;
  String? _status;
  Future<List<Order>>? _future;

  static const _filters = [
    (null, 'Todos'),
    ('pending', 'Pendentes'),
    ('preparing', 'A preparar'),
    ('on_the_way', 'Em entrega'),
    ('delivered', 'Entregues'),
    ('cancelled', 'Cancelados'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _future = AppScope.of(context).api.adminOrders();
  }

  void _reload() {
    setState(() {
      _future = AppScope.of(context).api.adminOrders(status: _status);
    });
  }

  void _select(String? status) {
    if (_status == status) return;
    setState(() {
      _status = status;
      _future = AppScope.of(context).api.adminOrders(status: status);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos da plataforma'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final entry = _filters[index];
                  final selected = _status == entry.$1;
                  return _OrderFilter(
                    label: entry.$2,
                    selected: selected,
                    onTap: () => _select(entry.$1),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
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
                          return const EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'Sem pedidos',
                            message: 'Não há pedidos neste filtro.',
                          );
                        }
                        return Column(
                          children: [
                            for (final order in orders)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _OrderAdminCard(order: order),
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

class _OrderFilter extends StatelessWidget {
  const _OrderFilter({
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
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
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderAdminCard extends StatelessWidget {
  const _OrderAdminCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const NetworkThumb(
                imageUrl: null,
                icon: Icons.restaurant_rounded,
                size: 46,
                radius: 12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.number,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDateTime(order.createdAt),
                      style: TextStyle(color: context.mutedColor, fontSize: 10),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 8),
          InfoRow(
            icon: Icons.storefront_rounded,
            text: order.establishment.name,
          ),
          InfoRow(
            icon: Icons.person_outline_rounded,
            text: order.customerName ?? 'Cliente',
          ),
          InfoRow(
            icon: Icons.location_on_outlined,
            text: '${order.addressLabel} · ${order.addressLine}',
          ),
          if (order.delivery?.courierName != null)
            InfoRow(
              icon: Icons.delivery_dining_rounded,
              text: 'Estafeta: ${order.delivery!.courierName}',
            ),
          if (order.cancellationReason != null)
            InfoRow(
              icon: Icons.info_outline_rounded,
              text: order.cancellationReason!,
              color: context.dangerColor,
            ),
          if (order.rejectionReason != null)
            InfoRow(
              icon: Icons.info_outline_rounded,
              text: order.rejectionReason!,
              color: context.dangerColor,
            ),
          const Divider(height: 20),
          Row(
            children: [
              Text(
                '${order.itemCount} item(ns)',
                style: TextStyle(color: context.mutedColor, fontSize: 11),
              ),
              const Spacer(),
              Text(
                formatMoney(order.totalCents),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
