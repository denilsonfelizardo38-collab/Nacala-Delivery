import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../state/app_scope.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';
import 'order_tracking_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final orders = state.orders;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Text('Pedidos', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          orders.isEmpty
              ? 'Acompanhe aqui as suas entregas.'
              : '${orders.length} ${orders.length == 1 ? 'pedido' : 'pedidos'} registados',
          style: TextStyle(color: context.mutedColor, fontSize: 13),
        ),
        const SizedBox(height: 18),
        if (orders.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Ainda não tem pedidos',
            subtitle:
                'Quando fizer um pedido, poderá acompanhar tudo por aqui.',
            action: FilledButton(
              onPressed: () => state.selectTab(0),
              child: const Text('Explorar locais'),
            ),
          )
        else
          for (final order in orders)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OrderCard(
                order: order,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OrderTrackingScreen(orderId: order.id),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: order.place.tint,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      order.place.icon,
                      color: context.accentColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${order.id} · ${order.place.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.inkColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${order.itemCount} itens · ${formatDateTime(order.createdAt)}',
                          style: TextStyle(
                            color: context.mutedColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatMoney(order.total),
                    style: TextStyle(
                      color: context.inkColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  StatusChip(status: order.status),
                  const Spacer(),
                  Text(
                    'Ver detalhes',
                    style: TextStyle(
                      color: context.accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: context.accentColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
