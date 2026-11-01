import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'partner_orders_screen.dart';

class PartnerDashboardScreen extends StatefulWidget {
  const PartnerDashboardScreen({super.key});

  @override
  State<PartnerDashboardScreen> createState() => _PartnerDashboardScreenState();
}

class _PartnerDashboardScreenState extends State<PartnerDashboardScreen> {
  bool _initialized = false;
  Future<PartnerDashboardData>? _future;
  bool _toggling = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _future = AppScope.of(context).api.partnerDashboard();
  }

  void _reload() {
    setState(() {
      _future = AppScope.of(context).api.partnerDashboard();
    });
  }

  Future<void> _toggleOpen(Establishment establishment) async {
    setState(() => _toggling = true);
    try {
      await AppScope.of(context).api.updatePartnerEstablishment(
        description: establishment.description,
        phone: establishment.phone,
        address: establishment.address,
        isOpen: !establishment.isOpen,
        opensAt: establishment.opensAt,
        closesAt: establishment.closesAt,
      );
      if (!mounted) return;
      showAppSnack(
        context,
        establishment.isOpen
            ? 'Estabelecimento marcado como fechado.'
            : 'Estabelecimento aberto para pedidos.',
      );
      _reload();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do parceiro'),
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
        child: RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              AsyncSection<PartnerDashboardData>(
                future: _future,
                onRetry: _reload,
                loadingHeight: 320,
                builder: (context, data) => _content(data),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(PartnerDashboardData data) {
    final summary = data.summary;
    final establishment = data.establishment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NetworkThumb(
                    imageUrl: establishment.imageUrl,
                    size: 56,
                    radius: 14,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          establishment.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          establishment.categoryName,
                          style: TextStyle(
                            color: context.mutedColor,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        StarRating(
                          rating: establishment.rating,
                          count: establishment.reviewCount,
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    status: establishment.isOpen ? 'accepted' : 'cancelled',
                    label: establishment.isOpen ? 'Aberto' : 'Fechado',
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          establishment.isOpen
                              ? 'Está a receber pedidos'
                              : 'Não está a receber pedidos',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Horário ${establishment.opensAt}–${establishment.closesAt}',
                          style: TextStyle(
                            color: context.mutedColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: establishment.isOpen,
                    onChanged: _toggling
                        ? null
                        : (_) => _toggleOpen(establishment),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720 ? 4 : 2;
            final spacing = 10.0;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            final tiles = [
              MetricTile(
                label: 'Pedidos hoje',
                value: '${summary.ordersToday}',
                icon: Icons.receipt_long_rounded,
              ),
              MetricTile(
                label: 'Vendas hoje',
                value: formatMoney(summary.salesTodayCents),
                icon: Icons.trending_up_rounded,
                tone: MetricTone.success,
              ),
              MetricTile(
                label: 'Pendentes',
                value: '${summary.pendingOrders}',
                icon: Icons.pending_actions_rounded,
                tone: summary.pendingOrders > 0
                    ? MetricTone.warning
                    : MetricTone.primary,
              ),
              MetricTile(
                label: 'Em curso',
                value: '${summary.activeOrders}',
                icon: Icons.local_shipping_rounded,
              ),
            ];
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final tile in tiles) SizedBox(width: width, child: tile),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: 'Pedidos totais',
                  value: '${summary.totalOrders}',
                ),
              ),
              Container(width: 1, height: 36, color: context.lineColor),
              Expanded(
                child: _SummaryStat(
                  label: 'Vendas totais',
                  value: formatMoney(summary.salesTotalCents),
                ),
              ),
              Container(width: 1, height: 36, color: context.lineColor),
              Expanded(
                child: _SummaryStat(
                  label: 'Avaliações',
                  value: '${summary.reviewCount}',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SectionTitle(
          title: 'Pedidos recentes',
          subtitle: 'Últimos pedidos recebidos neste estabelecimento',
          actionLabel: 'Ver todos',
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PartnerOrdersScreen()),
          ),
        ),
        const SizedBox(height: 10),
        if (data.recentOrders.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Ainda sem pedidos',
            message: 'Quando um cliente encomendar, o pedido aparece aqui.',
            compact: true,
          )
        else
          for (final order in data.recentOrders)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RecentOrder(order: order),
            ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PartnerOrdersScreen()),
          ),
          icon: const Icon(Icons.receipt_long_rounded, size: 18),
          label: const Text('Gerir pedidos'),
        ),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.mutedColor, fontSize: 10),
        ),
      ],
    );
  }
}

class _RecentOrder extends StatelessWidget {
  const _RecentOrder({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
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
                  '${order.itemCount} item(ns) · ${formatDateTime(order.createdAt)}',
                  style: TextStyle(color: context.mutedColor, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(order.totalCents),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              StatusBadge(status: order.status),
            ],
          ),
        ],
      ),
    );
  }
}
