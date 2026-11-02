import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import 'tracking_screen.dart';

const Color _ordersOrange = Color(0xFFF47721);
const Color _ordersOrangeDark = Color(0xFFE76512);
const Color _ordersOrangeSoft = Color(0xFFFFF1E7);
const Color _ordersInk = Color(0xFF191715);
const Color _ordersMuted = Color(0xFF817B75);
const Color _ordersLine = Color(0xFFECE7E2);
const Color _ordersCanvas = Color(0xFFFAF8F6);

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
        backgroundColor: _ordersCanvas,
        appBar: AppBar(
          backgroundColor: _ordersCanvas,
          title: const Text('Meus pedidos'),
        ),
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
      backgroundColor: _ordersCanvas,
      appBar: AppBar(
        backgroundColor: _ordersCanvas,
        title: const Text('Meus pedidos'),
        actions: const [CartButton(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildIntro(context),
            _buildFilters(),
            Expanded(
              child: RefreshIndicator(
                color: _ordersOrange,
                onRefresh: () async => _reload(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 5, 20, 28),
                  children: [
                    AsyncSection<List<Order>>(
                      future: _future,
                      onRetry: _reload,
                      builder: (context, orders) {
                        if (orders.isEmpty) {
                          return _buildEmptyState();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 13),
                              child: Text(
                                '${orders.length} ${orders.length == 1 ? 'pedido encontrado' : 'pedidos encontrados'}',
                                style: const TextStyle(
                                  color: _ordersMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            for (final order in orders)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 13),
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

  Widget _buildIntro(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 19),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 17, 16, 17),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_ordersOrange, _ordersOrangeDark],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _ordersOrange.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'As tuas encomendas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Consulta o estado e acompanha cada entrega.',
                    style: TextStyle(
                      color: Color(0xFFFFF4EC),
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.17),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                color: Colors.white,
                size: 25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          for (final filter in _filters)
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
      ),
    );
  }

  Widget _buildEmptyState() {
    final inProgress = _status == 'in_progress';
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _ordersLine),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: _ordersOrangeSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: _ordersOrangeDark,
              size: 32,
            ),
          ),
          const SizedBox(height: 17),
          Text(
            inProgress ? 'Ainda não tens pedidos em curso' : 'Nada por aqui',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ordersInk,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            inProgress
                ? 'Quando fizeres um pedido, poderás acompanhar o progresso e a entrega nesta página.'
                : 'Os teus pedidos vão aparecer aqui assim que forem criados.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ordersMuted,
              fontSize: 12,
              height: 1.55,
            ),
          ),
        ],
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
      color: selected ? _ordersInk : Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? _ordersInk : _ordersLine,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : _ordersMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: _ordersLine),
            boxShadow: [
              BoxShadow(
                color: _ordersInk.withValues(alpha: 0.025),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: _ordersOrangeSoft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: _ordersOrangeDark,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.number,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ordersInk,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          order.establishment.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ordersMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: order.status),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: _ordersLine),
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
                  const Text(
                    'Total do pedido',
                    style: TextStyle(
                      color: _ordersMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatMoney(order.totalCents),
                    style: const TextStyle(
                      color: _ordersInk,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: _ordersOrangeDark,
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
        Icon(icon, size: 14, color: _ordersOrangeDark),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ordersMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
