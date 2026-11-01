import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/live_delivery_map.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  bool _initialized = false;
  Order? _order;
  bool _loading = true;
  String? _error;
  bool _actionLoading = false;
  Timer? _poll;

  static const _steps = [
    ('pending', 'Pedido recebido', Icons.receipt_long_rounded),
    ('confirmed', 'Confirmado pelo parceiro', Icons.verified_rounded),
    ('preparing', 'Em preparação', Icons.restaurant_rounded),
    ('ready', 'Pronto para recolha', Icons.inventory_2_rounded),
    ('on_the_way', 'Em entrega', Icons.delivery_dining_rounded),
    ('delivered', 'Entregue', Icons.home_rounded),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final order = await AppScope.of(context).api.order(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
        _error = null;
      });
      _schedulePoll();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  void _schedulePoll() {
    _poll?.cancel();
    final order = _order;
    if (order == null || order.isFinal) return;
    _poll = Timer(const Duration(seconds: 12), () => _load(silent: true));
  }

  Future<void> _cancel() async {
    final state = AppScope.of(context);
    final reason = await showTextPrompt(
      context,
      title: 'Cancelar pedido',
      label: 'Motivo',
      initialValue: 'Cancelado pelo cliente.',
      maxLines: 2,
      confirmLabel: 'Cancelar pedido',
    );
    if (reason == null) return;
    setState(() => _actionLoading = true);
    try {
      final order = await state.api.cancelOrder(widget.orderId, reason);
      if (!mounted) return;
      setState(() => _order = order);
      showAppSnack(context, 'Pedido cancelado.');
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _review() async {
    final state = AppScope.of(context);
    final input = await showDialog<_ReviewInput>(
      context: context,
      builder: (_) => const _ReviewDialog(),
    );
    if (input == null) return;
    setState(() => _actionLoading = true);
    try {
      await state.api.reviewOrder(widget.orderId, input.rating, input.comment);
      if (!mounted) return;
      showAppSnack(context, 'Obrigado pela sua avaliação.');
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _reorder(Order order) async {
    final state = AppScope.of(context);
    setState(() => _actionLoading = true);
    try {
      final detail = await state.api.establishment(order.establishment.id);
      if (!mounted) return;
      final store = CartStore(
        id: detail.establishment.id,
        name: detail.establishment.name,
        deliveryFeeCents: detail.establishment.deliveryFeeCents,
        imageUrl: detail.establishment.imageUrl,
      );
      if (!state.cartBelongsTo(store.id) && !state.isCartEmpty) {
        final replace = await showConfirmDialog(
          context,
          title: 'Substituir carrinho',
          message:
              'O carrinho tem produtos de outro estabelecimento. '
              'Substituir por ${store.name}?',
          confirmLabel: 'Substituir',
          destructive: true,
        );
        if (!replace || !mounted) {
          setState(() => _actionLoading = false);
          return;
        }
      }
      final available = {for (final item in detail.products) item.id: item};
      final unavailable = <String>[];
      var added = 0;
      for (final item in order.items) {
        final product = available[item.productId];
        if (product == null || !product.isAvailable) {
          unavailable.add(item.name);
          continue;
        }
        state.addToCart(product, store, quantity: item.quantity);
        added++;
      }
      if (!mounted) return;
      if (added == 0) {
        showAppSnack(
          context,
          'Nenhum dos produtos deste pedido está disponível.',
          error: true,
        );
        return;
      }
      if (unavailable.isEmpty) {
        showAppSnack(context, 'Pedido adicionado ao carrinho.');
      } else {
        showAppSnack(
          context,
          'Adicionados $added produto(s). Indisponível: '
          '${unavailable.join(', ')}.',
        );
      }
      Navigator.of(context).pushNamed('/cart');
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  DateTime? _eventDate(String status) {
    final order = _order;
    if (order == null) return null;
    for (final event in order.events) {
      if (event.status == status) return event.createdAt;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acompanhar pedido'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(top: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading && _order == null) {
      return const LoadingBlock(height: 400);
    }
    if (_error != null && _order == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ErrorState(message: _error!, onRetry: _load),
        ),
      );
    }
    final order = _order;
    if (order == null) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Pedido não encontrado',
        message: 'Não foi possível carregar este pedido.',
      );
    }

    final cancelled = order.status == 'cancelled' || order.status == 'rejected';
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pedido ${order.number}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatDateTime(order.createdAt),
                            style: TextStyle(
                              color: context.mutedColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  cancelled
                      ? (order.rejectionReason ??
                            order.cancellationReason ??
                            'O pedido não foi concluído.')
                      : order.statusDescription,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: cancelled ? context.dangerColor : null),
                ),
                if (!order.isFinal) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.autorenew_rounded,
                        size: 14,
                        color: context.mutedColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Atualiza automaticamente a cada 12 segundos',
                        style: TextStyle(
                          color: context.mutedColor,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (order.status == 'on_the_way') ...[
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Entregador a caminho',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 10),
                  if (order.addressLatitude != null &&
                      order.addressLongitude != null)
                    LiveDeliveryMap(
                      destination: LatLng(
                        order.addressLatitude!,
                        order.addressLongitude!,
                      ),
                      courier:
                          order.delivery?.latitude == null ||
                              order.delivery?.longitude == null
                          ? null
                          : LatLng(
                              order.delivery!.latitude!,
                              order.delivery!.longitude!,
                            ),
                      departedAt: order.delivery?.departedAt,
                      locationUpdatedAt: order.delivery?.locationUpdatedAt,
                    )
                  else
                    Text(
                      'Este pedido não tem um ponto de entrega no mapa. '
                      'Contacte o estafeta para confirmar a morada.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
          if (!cancelled) ...[
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < _steps.length; i++)
                    _TimelineStep(
                      label: _steps[i].$2,
                      icon: _steps[i].$3,
                      done: i <= order.step,
                      current: i == order.step && !order.isFinal,
                      date: _eventDate(_steps[i].$1),
                      isLast: i == _steps.length - 1,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Percurso da entrega',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                _RoutePoint(
                  icon: Icons.storefront_rounded,
                  label: 'Recolha',
                  title: order.establishment.name,
                  subtitle: order.establishment.address,
                ),
                Container(
                  margin: const EdgeInsets.only(left: 15),
                  height: 18,
                  width: 2,
                  color: context.lineColor,
                ),
                _RoutePoint(
                  icon: Icons.location_on_rounded,
                  label: 'Entrega · ${order.addressLabel}',
                  title: order.addressLine,
                  subtitle: order.phone,
                ),
                if (order.delivery?.courierName != null) ...[
                  const Divider(height: 24),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.delivery_dining_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estafeta',
                              style: TextStyle(
                                color: context.mutedColor,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              order.delivery!.courierName!,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                      if (order.delivery!.courierPhone != null)
                        Text(
                          order.delivery!.courierPhone!,
                          style: TextStyle(
                            color: context.accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Itens do pedido',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.quantity}×',
                          style: TextStyle(
                            color: context.mutedColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (item.note != null && item.note!.isNotEmpty)
                                Text(
                                  item.note!,
                                  style: TextStyle(
                                    color: context.mutedColor,
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          formatMoney(item.lineTotalCents),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 20),
                PriceLine(label: 'Subtotal', cents: order.subtotalCents),
                PriceLine(
                  label: 'Taxa de entrega',
                  cents: order.deliveryFeeCents,
                ),
                if (order.discountCents > 0)
                  PriceLine(
                    label: 'Desconto',
                    cents: -order.discountCents,
                    color: context.successColor,
                  ),
                const Divider(height: 20),
                PriceLine(
                  label: 'Total',
                  cents: order.totalCents,
                  strong: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Pagamento',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    StatusBadge(
                      status: order.paymentStatus == 'cash_on_delivery'
                          ? 'accepted'
                          : 'pending',
                      label: order.paymentStatusLabel,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                InfoRow(
                  icon: Icons.payments_outlined,
                  text: order.paymentLabel,
                ),
                if (order.paymentStatus == 'pending_integration')
                  InfoRow(
                    icon: Icons.info_outline_rounded,
                    text:
                        'O pagamento eletrónico ainda não é cobrado '
                        'automaticamente. Combine com o parceiro.',
                    color: context.warningColor,
                  ),
              ],
            ),
          ),
          if (order.note != null && order.note!.isNotEmpty) ...[
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nota do pedido',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    order.note!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: context.mutedColor),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _actionLoading ? null : () => _reorder(order),
            icon: const Icon(Icons.replay_rounded, size: 18),
            label: const Text('Repetir pedido'),
          ),
          const SizedBox(height: 8),
          if (order.canCancel)
            OutlinedButton.icon(
              onPressed: _actionLoading ? null : _cancel,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Cancelar pedido'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.dangerColor,
              ),
            ),
          if (order.canReview)
            FilledButton.tonalIcon(
              onPressed: _actionLoading ? null : _review,
              icon: const Icon(Icons.star_outline_rounded, size: 18),
              label: const Text('Avaliar pedido'),
            ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.icon,
    required this.done,
    required this.current,
    required this.date,
    required this.isLast,
  });

  final String label;
  final IconData icon;
  final bool done;
  final bool current;
  final DateTime? date;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = done ? context.successColor : context.mutedColor;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: done
                    ? color.withValues(alpha: 0.14)
                    : (context.isDarkMode
                          ? AppColors.darkElevated
                          : AppColors.bg),
                shape: BoxShape.circle,
                border: Border.all(
                  color: current ? color : Colors.transparent,
                  width: 1.6,
                ),
              ),
              child: Icon(
                done ? Icons.check_rounded : icon,
                size: 16,
                color: color,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 26,
                color: done ? color.withValues(alpha: 0.4) : context.lineColor,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: done ? context.inkColor : context.mutedColor,
                      fontSize: 13,
                      fontWeight: done ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (date != null)
                  Text(
                    formatDateTime(date!),
                    style: TextStyle(color: context.mutedColor, fontSize: 10),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutePoint extends StatelessWidget {
  const _RoutePoint({
    required this.icon,
    required this.label,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String label;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: context.mutedColor, fontSize: 10),
              ),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: TextStyle(color: context.mutedColor, fontSize: 11),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewInput {
  const _ReviewInput(this.rating, this.comment);
  final int rating;
  final String? comment;
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog();

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _comment = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Avaliar pedido'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i estrela(s)',
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(
                    i <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppColors.warning,
                    size: 30,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Comentário (opcional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Agora não'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _ReviewInput(
              _rating,
              _comment.text.trim().isEmpty ? null : _comment.text.trim(),
            ),
          ),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: const Text('Enviar avaliação'),
        ),
      ],
    );
  }
}
