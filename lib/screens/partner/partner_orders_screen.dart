import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class PartnerOrdersScreen extends StatefulWidget {
  const PartnerOrdersScreen({super.key});

  @override
  State<PartnerOrdersScreen> createState() => _PartnerOrdersScreenState();
}

class _PartnerOrdersScreenState extends State<PartnerOrdersScreen> {
  bool _initialized = false;
  String _status = 'in_progress';
  Future<List<Order>>? _future;
  String? _busyOrderId;

  static const _filters = [
    ('in_progress', 'Em curso'),
    ('completed', 'Concluídos'),
    ('all', 'Todos'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _future = AppScope.of(context).api.partnerOrders(status: _status);
  }

  void _reload() {
    setState(() {
      _future = AppScope.of(context).api.partnerOrders(status: _status);
    });
  }

  void _select(String status) {
    if (_status == status) return;
    setState(() {
      _status = status;
      _future = AppScope.of(context).api.partnerOrders(status: status);
    });
  }

  Future<void> _act(Order order, String action) async {
    final api = AppScope.of(context).api;
    String? reason;
    if (action == 'reject') {
      reason = await showTextPrompt(
        context,
        title: 'Rejeitar pedido',
        label: 'Motivo',
        hint: 'Ex.: produto esgotado',
        maxLines: 2,
        confirmLabel: 'Rejeitar',
      );
      if (reason == null) return;
    }
    setState(() => _busyOrderId = order.id);
    try {
      await api.partnerAction(order.id, action, reason: reason);
      if (!mounted) return;
      showAppSnack(context, _messageFor(action));
      _reload();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busyOrderId = null);
    }
  }

  String _messageFor(String action) => switch (action) {
    'accept' => 'Pedido aceite.',
    'reject' => 'Pedido rejeitado.',
    'preparing' => 'Preparação iniciada.',
    'ready' => 'Pedido marcado como pronto.',
    _ => 'Pedido atualizado.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos do parceiro'),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  for (final filter in _filters) ...[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterTab(
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
                                ? 'Os novos pedidos dos clientes aparecem aqui.'
                                : 'Ainda não há pedidos neste filtro.',
                          );
                        }
                        return Column(
                          children: [
                            for (final order in orders)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _PartnerOrderCard(
                                  order: order,
                                  busy: _busyOrderId == order.id,
                                  onAction: (action) => _act(order, action),
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

class _FilterTab extends StatelessWidget {
  const _FilterTab({
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

class _PartnerOrderCard extends StatelessWidget {
  const _PartnerOrderCard({
    required this.order,
    required this.busy,
    required this.onAction,
  });

  final Order order;
  final bool busy;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.number,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDateTime(order.createdAt),
                      style: TextStyle(color: context.mutedColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: order.status),
            ],
          ),
          const Divider(height: 20),
          if (order.customerName != null)
            InfoRow(
              icon: Icons.person_outline_rounded,
              text: order.customerName!,
            ),
          InfoRow(icon: Icons.phone_outlined, text: order.phone),
          InfoRow(
            icon: Icons.location_on_outlined,
            text: '${order.addressLabel} · ${order.addressLine}',
          ),
          if (order.note != null && order.note!.isNotEmpty)
            InfoRow(
              icon: Icons.sticky_note_2_outlined,
              text: order.note!,
              color: context.warningColor,
            ),
          const SizedBox(height: 10),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Text(
                    '${item.quantity}×',
                    style: TextStyle(
                      color: context.mutedColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.name,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    formatMoney(item.lineTotalCents),
                    style: TextStyle(color: context.mutedColor, fontSize: 11),
                  ),
                ],
              ),
            ),
          const Divider(height: 18),
          Row(
            children: [
              Text(
                'Total',
                style: TextStyle(color: context.mutedColor, fontSize: 12),
              ),
              const Spacer(),
              Text(
                formatMoney(order.totalCents),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (_actionsFor(order).isNotEmpty) ...[
            const SizedBox(height: 12),
            if (busy)
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final action in _actionsFor(order))
                    _ActionButton(
                      action: action,
                      onPressed: () => onAction(action.$1),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  List<(String, String)> _actionsFor(Order order) {
    return switch (order.status) {
      'pending' => [('accept', 'Aceitar'), ('reject', 'Rejeitar')],
      'confirmed' => [('preparing', 'Iniciar preparação')],
      'preparing' => [('ready', 'Marcar pronto')],
      _ => const [],
    };
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.onPressed});

  final (String, String) action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final destructive = action.$1 == 'reject';
    final label = Text(action.$2);
    if (destructive) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          foregroundColor: context.dangerColor,
          side: BorderSide(color: context.dangerColor),
        ),
        child: label,
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        backgroundColor: AppColors.primary,
      ),
      child: label,
    );
  }
}
