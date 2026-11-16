import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/jb.dart';

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

  /// Abre o chat com o cliente de uma ordem específica.
  Future<void> _openChatWithCustomer(Order order) async {
    if (order.customerId == null) {
      showAppSnack(context, 'Não foi possível iniciar a conversa.');
      return;
    }
    final api = AppScope.of(context).api;
    try {
      final conversation = await api.createConversation(
        otherUserId: order.customerId!,
        orderId: order.id,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamed(
        '/chat',
        arguments: {
          'id': conversation.id,
          'order_id': order.id,
          'other_user_id': order.customerId,
          'other_user_name': order.customerName,
          'other_role': 'customer',
        },
      );
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            JbPageHeader(
              title: 'Pedidos do parceiro',
              onBack: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).maybePop()
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Atualizar',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    for (final filter in _filters) ...[
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChipPill(
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
                                  onChatWithCustomer: order.customerId != null
                                      ? () => _openChatWithCustomer(order)
                                      : null,
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

class _PartnerOrderCard extends StatelessWidget {
  const _PartnerOrderCard({
    required this.order,
    required this.busy,
    required this.onAction,
    this.onChatWithCustomer,
  });

  final Order order;
  final bool busy;
  final ValueChanged<String> onAction;
  final VoidCallback? onChatWithCustomer;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrderCardHeader(
            title: order.number,
            subtitle: formatDateTime(order.createdAt),
            status: order.status,
          ),
          const Divider(height: 20),
          if (order.customerName != null)
            InfoRow(
              icon: Icons.person_outline_rounded,
              text: order.customerName!,
            ),
          Row(
            children: [
              Expanded(
                child: InfoRow(
                  icon: Icons.phone_outlined,
                  text: order.phone,
                ),
              ),
              IconButton(
                tooltip: 'Ligar ao cliente',
                onPressed: () => launchCall(context, phone: order.phone),
                icon: const Icon(
                  Icons.call_rounded,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
              IconButton(
                tooltip: 'Falar por WhatsApp',
                onPressed: () => launchWhatsApp(
                  context,
                  phone: order.phone,
                  message: 'Olá! Falo sobre o pedido ${order.number}.',
                ),
                icon: const Icon(
                  Icons.chat_rounded,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
              IconButton(
                tooltip: 'Mensagem no app',
                onPressed: onChatWithCustomer,
                icon: const Icon(
                  Icons.message_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ],
          ),
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
      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
      child: label,
    );
  }
}
