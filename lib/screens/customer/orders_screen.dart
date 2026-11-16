import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import '../../widgets/jb.dart';

/// Pedidos no padrão Já Bazou: `page-head` com título display e duas
/// secções — "A decorrer" (pedidos activos) e "Anteriores" (entregues,
/// cancelados e rejeitados), em vez de filtros separados.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _initialized = false;
  Future<List<Order>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final state = AppScope.of(context);
    if (state.isSignedIn) _future = state.api.orders(status: 'all');
  }

  /// Convidado: escolher tipo de conta para entrar e ver os pedidos.
  void _openRoles() {
    Navigator.of(context).pushNamed('/roles', arguments: 'login');
  }

  void _reload() {
    setState(() {
      _future = AppScope.of(context).api.orders(status: 'all');
    });
  }

  Future<void> _open(Order order) async {
    await Navigator.of(context).pushNamed('/tracking', arguments: order.id);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppScope.of(context).isSignedIn) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              const JbPageHeader(title: 'Meus pedidos'),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Os pedidos são da tua conta',
                      message:
                          'Explora o catálogo como convidado. Para acompanhar pedidos, '
                          'entra ou cria uma conta.',
                      actionLabel: 'Entrar ou criar conta',
                      onAction: _openRoles,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            JbPageHeader(
              title: 'Meus pedidos',
              trailing: Material(
                color: AppColors.darkCard,
                shape: const CircleBorder(),
                child: CartButton(color: context.inkColor),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async => _reload(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  children: [
                    AsyncSection<List<Order>>(
                      future: _future,
                      onRetry: _reload,
                      builder: (context, orders) {
                        if (orders.isEmpty) return _buildEmptyState();
                        // Divisão do referencial: activos vs. histórico.
                        final active = [
                          for (final order in orders)
                            if (!order.isFinal) order,
                        ];
                        final past = [
                          for (final order in orders)
                            if (order.isFinal) order,
                        ];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (active.isNotEmpty) ...[
                              JbSectionHeader(
                                title: 'A decorrer',
                                count: active.length,
                                margin: const EdgeInsets.only(
                                  top: 6,
                                  bottom: 8,
                                ),
                              ),
                              for (final order in active)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 13),
                                  child: _OrderCard(
                                    order: order,
                                    onTap: () => _open(order),
                                  ),
                                ),
                            ],
                            if (past.isNotEmpty) ...[
                              JbSectionHeader(
                                title: 'Anteriores',
                                count: past.length,
                                margin: const EdgeInsets.only(
                                  top: 18,
                                  bottom: 8,
                                ),
                              ),
                              for (final order in past)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 13),
                                  child: _OrderCard(
                                    order: order,
                                    onTap: () => _open(order),
                                  ),
                                ),
                            ],
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

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 28),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.lineColor),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.primarySoftColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              color: context.accentColor,
              size: 32,
            ),
          ),
          const SizedBox(height: 17),
          Text(
            'Ainda não tens pedidos',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.inkColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Os teus pedidos vão aparecer aqui assim que forem criados.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.mutedColor,
              fontSize: 12,
              height: 1.55,
            ),
          ),
        ],
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
    return Material(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.lineColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OrderCardHeader(
                title: order.number,
                subtitle: order.establishment.name,
                status: order.status,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: context.lineColor),
              ),
              Row(
                children: [
                  _OrderMeta(
                    icon: Icons.shopping_bag_outlined,
                    label: '${order.itemCount} item(ns)',
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _OrderMeta(
                      icon: Icons.schedule_rounded,
                      label: formatDateTime(order.createdAt),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Text(
                    'Total do pedido',
                    style: TextStyle(
                      color: context.mutedColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatMoney(order.totalCents),
                    style: TextStyle(
                      color: context.inkColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: context.accentColor,
                    size: 13,
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

class _OrderMeta extends StatelessWidget {
  const _OrderMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: context.accentColor),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.mutedColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
