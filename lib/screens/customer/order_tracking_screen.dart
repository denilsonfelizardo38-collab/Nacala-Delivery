import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';

class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final order = state.orderById(orderId);

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pedido')),
        body: const Center(
          child: EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Pedido não encontrado',
            subtitle: 'Este pedido já não está disponível.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(order.id)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [AppColors.navy, Color(0xFF1D66B2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.delivery_dining_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatDateTime(order.createdAt),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  order.status.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.status.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _Pill(label: order.payment.label),
                    const SizedBox(width: 8),
                    _Pill(label: '${order.itemCount} itens'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Section(
            title: 'Estado da entrega',
            child: _Timeline(status: order.status),
          ),
          if (state.demoMode && order.status != OrderStatus.delivered) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => state.advanceOrder(order.id),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Simular próximo estado (demo)'),
            ),
          ],
          const SizedBox(height: 18),
          _Section(
            title: 'Resumo do pedido',
            child: Column(
              children: [
                for (final line in order.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text(
                          '${line.quantity}×',
                          style: TextStyle(
                            color: context.mutedColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            line.product.name,
                            style: TextStyle(
                              color: context.inkColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          formatMoney(line.total),
                          style: TextStyle(
                            color: context.inkColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                Divider(color: context.lineColor, height: 20),
                _Row(label: 'Subtotal', value: formatMoney(order.subtotal)),
                const SizedBox(height: 6),
                _Row(label: 'Entrega', value: formatMoney(order.deliveryFee)),
                const SizedBox(height: 10),
                _Row(
                  label: 'Total',
                  value: formatMoney(order.total),
                  emphasized: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Entrega',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Detail(icon: Icons.location_on_outlined, label: order.address),
                const SizedBox(height: 10),
                _Detail(
                  icon: order.payment.icon,
                  label: order.phone == null
                      ? order.payment.label
                      : '${order.payment.label} · +258 ${order.phone}',
                ),
                if (order.note != null) ...[
                  const SizedBox(height: 10),
                  _Detail(
                    icon: Icons.sticky_note_2_outlined,
                    label: order.note!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.inkColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final steps = OrderStatus.values;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineStep(
            status: steps[i],
            done: i < status.index,
            current: i == status.index,
            last: i == steps.length - 1,
          ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.status,
    required this.done,
    required this.current,
    required this.last,
  });

  final OrderStatus status;
  final bool done;
  final bool current;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    final active = done || current;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? accent : Colors.transparent,
                border: Border.all(
                  color: active ? accent : context.lineColor,
                  width: 2,
                ),
              ),
              child: done
                  ? const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: Colors.white,
                    )
                  : current
                  ? const Icon(Icons.circle, size: 7, color: Colors.white)
                  : null,
            ),
            if (!last)
              Container(
                width: 2,
                height: 30,
                color: done ? accent : context.lineColor,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.label,
                  style: TextStyle(
                    color: active ? context.inkColor : context.mutedColor,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status.description,
                  style: TextStyle(color: context.mutedColor, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: context.accentColor),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: context.inkColor, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasized ? context.inkColor : context.mutedColor,
              fontSize: emphasized ? 14 : 12,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: context.inkColor,
            fontSize: emphasized ? 15 : 12,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
