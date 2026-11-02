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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _OrderHero(order: order, cancelled: cancelled, loading: _loading),
          if (order.status == 'on_the_way') ...[
            const SizedBox(height: 16),
            _TrackingSection(
              title: 'Acompanhe no mapa',
              eyebrow: 'ENTREGA EM TEMPO REAL',
              icon: Icons.near_me_rounded,
              child: order.addressLatitude != null &&
                      order.addressLongitude != null
                  ? LiveDeliveryMap(
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
                  : Text(
                      'Este pedido não tem um ponto de entrega no mapa. '
                      'Contacte o estafeta para confirmar a morada.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
            ),
          ],
          if (!cancelled) ...[
            const SizedBox(height: 16),
            _TrackingSection(
              title: 'Progresso do pedido',
              eyebrow: 'ESTADO DA ENCOMENDA',
              icon: Icons.route_rounded,
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
          _TrackingSection(
            title: 'Percurso da entrega',
            eyebrow: 'ORIGEM E DESTINO',
            icon: Icons.map_outlined,
            child: Column(
              children: [
                _RoutePoint(
                  icon: Icons.storefront_rounded,
                  label: 'RECOLHA',
                  title: order.establishment.name,
                  subtitle: order.establishment.address,
                  isDestination: false,
                ),
                const SizedBox(height: 10),
                _RoutePoint(
                  icon: Icons.location_on_rounded,
                  label: 'ENTREGA · ${order.addressLabel.toUpperCase()}',
                  title: order.addressLine,
                  subtitle: order.phone,
                  isDestination: true,
                ),
                if (order.delivery?.courierName != null) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.delivery_dining_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'O seu estafeta',
                              style: TextStyle(
                                color: context.mutedColor,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.delivery!.courierName!,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                      if (order.delivery!.courierPhone != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            order.delivery!.courierPhone!,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _TrackingSection(
            title: 'Resumo da encomenda',
            eyebrow: 'PRODUTOS E VALORES',
            icon: Icons.receipt_long_outlined,
            child: Column(
              children: [
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 13),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            '${item.quantity}×',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (item.note != null && item.note!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    item.note!,
                                    style: TextStyle(
                                      color: context.mutedColor,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatMoney(item.lineTotalCents),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
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
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: context.lineColor),
                    ),
                  ),
                  child: PriceLine(
                    label: 'Total',
                    cents: order.totalCents,
                    strong: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _TrackingSection(
            title: 'Pagamento',
            eyebrow: 'MÉTODO E CONFIRMAÇÃO',
            icon: Icons.payments_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.paymentLabel,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    StatusBadge(
                      status: order.paymentStatus == 'cash_on_delivery'
                          ? 'accepted'
                          : 'pending',
                      label: order.paymentStatusLabel,
                    ),
                  ],
                ),
                if (order.paymentStatus == 'pending_integration') ...[
                  const SizedBox(height: 10),
                  InfoRow(
                    icon: Icons.info_outline_rounded,
                    text:
                        'O pagamento electrónico ainda não é cobrado '
                        'automaticamente. Combine com o parceiro.',
                    color: context.warningColor,
                  ),
                ],
              ],
            ),
          ),
          if (order.note != null && order.note!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _TrackingSection(
              title: 'Nota do pedido',
              eyebrow: 'INFORMAÇÃO ADICIONAL',
              icon: Icons.sticky_note_2_outlined,
              child: Text(
                order.note!,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: context.mutedColor),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _buildActions(order),
        ],
      ),
    );
  }

  Widget _buildActions(Order order) {
    final actions = <Widget>[
      OutlinedButton.icon(
        onPressed: _actionLoading ? null : () => _reorder(order),
        icon: const Icon(Icons.replay_rounded, size: 18),
        label: const Text('Repetir pedido'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.55)),
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      if (order.canCancel)
        OutlinedButton.icon(
          onPressed: _actionLoading ? null : _cancel,
          icon: const Icon(Icons.close_rounded, size: 18),
          label: const Text('Cancelar pedido'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 50),
            foregroundColor: context.dangerColor,
            side: BorderSide(color: context.dangerColor.withValues(alpha: .4)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      if (order.canReview)
        FilledButton.icon(
          onPressed: _actionLoading ? null : _review,
          icon: const Icon(Icons.star_rounded, size: 18),
          label: const Text('Avaliar experiência'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 50),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_actionLoading) ...[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < actions.length; i++) ...[
          actions[i],
          if (i != actions.length - 1) const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _OrderHero extends StatelessWidget {
  const _OrderHero({
    required this.order,
    required this.cancelled,
    required this.loading,
  });

  final Order order;
  final bool cancelled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final accent = cancelled
        ? context.dangerColor
        : order.status == 'delivered'
        ? context.successColor
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: .82),
            const Color(0xFFB94A0A),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .2),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
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
                      'ACOMPANHAMENTO',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .78),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pedido ${order.number}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.6,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .2),
                  ),
                ),
                child: const Icon(
                  Icons.delivery_dining_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatDateTime(order.createdAt),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .85),
                    fontSize: 11,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    order.statusDescription,
                    style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            cancelled
                ? (order.rejectionReason ??
                      order.cancellationReason ??
                      'O pedido não foi concluído.')
                : order.statusDescription,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .92),
              fontSize: 12,
              height: 1.45,
            ),
          ),
          if (!order.isFinal) ...[
            const SizedBox(height: 13),
            Row(
              children: [
                const Icon(
                  Icons.autorenew_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'Actualização automática a cada 12 segundos',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .82),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackingSection extends StatelessWidget {
  const _TrackingSection({
    required this.title,
    required this.eyebrow,
    required this.icon,
    required this.child,
  });

  final String title;
  final String eyebrow;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: context.lineColor.withValues(alpha: .8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDarkMode ? .08 : .025,
            ),
            blurRadius: 15,
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
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          child,
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
    final color = done ? AppColors.primary : context.mutedColor;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: current ? 36 : 32,
                height: current ? 36 : 32,
                decoration: BoxDecoration(
                  color: done
                      ? AppColors.primarySoft
                      : context.isDarkMode
                      ? AppColors.darkElevated
                      : AppColors.bg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: current ? AppColors.primary : context.lineColor,
                    width: current ? 2 : 1,
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
                  height: 28,
                  color: done
                      ? AppColors.primary.withValues(alpha: .35)
                      : context.lineColor,
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: done ? context.inkColor : context.mutedColor,
                    fontSize: 12,
                    fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (date != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    formatDateTime(date!),
                    style: TextStyle(
                      color: context.mutedColor,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (current)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'AGORA',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
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
    required this.isDestination,
  });

  final IconData icon;
  final String label;
  final String title;
  final String subtitle;
  final bool isDestination;

  @override
  Widget build(BuildContext context) {
    final color = isDestination ? AppColors.primary : context.inkColor;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isDestination ? AppColors.primarySoft : context.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.lineColor),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDestination ? AppColors.primary : context.mutedColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.mutedColor,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
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
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comment,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Comentário (opcional)',
              alignLabelWithHint: true,
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
          style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
          child: const Text('Enviar avaliação'),
        ),
      ],
    );
  }
}
