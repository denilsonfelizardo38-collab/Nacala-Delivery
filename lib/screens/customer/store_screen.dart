import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import 'cart_screen.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, required this.establishmentId});

  final String establishmentId;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  bool _initialized = false;
  Future<EstablishmentDetail>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _future = AppScope.of(context).api.establishment(widget.establishmentId);
  }

  void _reload() {
    setState(() {
      _future = AppScope.of(context).api.establishment(widget.establishmentId);
    });
  }

  Future<void> _add(Product product, Establishment establishment) async {
    final state = AppScope.of(context);
    if (!state.cartBelongsTo(establishment.id)) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Substituir carrinho?',
        message:
            'O seu carrinho tem produtos de ${state.cartStore?.name ?? 'outro estabelecimento'}. '
            'Ao adicionar este produto, o carrinho atual será esvaziado.',
        confirmLabel: 'Substituir',
        destructive: true,
      );
      if (!confirmed) return;
      state.clearCart();
    }
    state.addToCart(product, CartStore.fromEstablishment(establishment));
    if (!mounted) return;
    showAppSnack(context, '${product.name} adicionado ao carrinho.');
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final showCartBar =
        !state.isCartEmpty && state.cartBelongsTo(widget.establishmentId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estabelecimento'),
        actions: const [CartButton(), SizedBox(width: 4)],
      ),
      body: AsyncSection<EstablishmentDetail>(
        future: _future,
        onRetry: _reload,
        loadingHeight: 320,
        builder: (context, detail) => _buildContent(detail),
      ),
      bottomNavigationBar: showCartBar
          ? _CartBar(
              itemCount: state.cartItemCount,
              totalCents: state.cartTotalCents,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const CartScreen())),
            )
          : null,
    );
  }

  Widget _buildContent(EstablishmentDetail detail) {
    final establishment = detail.establishment;
    final groups = <String, List<Product>>{};
    for (final product in detail.products) {
      groups.putIfAbsent(product.category, () => []).add(product);
    }

    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          _StoreHeader(establishment: establishment),
          if (!establishment.isOpen) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 18,
                    color: AppColors.amberInk,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Este estabelecimento está encerrado. Pode consultar o '
                      'menu, mas não é possível encomendar agora.',
                      style: TextStyle(
                        color: AppColors.amberInk,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          if (detail.products.isEmpty)
            const EmptyState(
              icon: Icons.restaurant_menu_rounded,
              title: 'Menu em preparação',
              message: 'Este parceiro ainda não publicou produtos.',
            )
          else
            for (final entry in groups.entries) ...[
              SectionTitle(title: entry.key),
              const SizedBox(height: 10),
              for (final product in entry.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ProductCard(
                    product: product,
                    enabled: establishment.isOpen && product.isAvailable,
                    onAdd: () => _add(product, establishment),
                  ),
                ),
              const SizedBox(height: 14),
            ],
          const SizedBox(height: 6),
          SectionTitle(
            title: 'Avaliações',
            subtitle: detail.reviews.isEmpty
                ? 'Ainda sem avaliações reais'
                : '${detail.reviews.length} avaliação(ões) de clientes',
          ),
          const SizedBox(height: 10),
          if (detail.reviews.isEmpty)
            AppCard(
              child: Row(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    color: context.mutedColor,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'As avaliações aparecem aqui depois de pedidos entregues.',
                      style: TextStyle(color: context.mutedColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final review in detail.reviews)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ReviewCard(review: review),
              ),
        ],
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.establishment});
  final Establishment establishment;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NetworkThumb(
                imageUrl: establishment.imageUrl,
                size: 72,
                radius: 16,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      establishment.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      establishment.description,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: context.mutedColor),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StarRating(
                          rating: establishment.rating,
                          count: establishment.reviewCount,
                        ),
                        StatusBadge(
                          status: establishment.isOpen
                              ? 'accepted'
                              : 'cancelled',
                          label: establishment.isOpen ? 'Aberto' : 'Fechado',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: context.lineColor),
          const SizedBox(height: 8),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _HeaderMeta(
                icon: Icons.delivery_dining_rounded,
                label: 'Entrega',
                value: formatMoney(establishment.deliveryFeeCents),
              ),
              _HeaderMeta(
                icon: Icons.schedule_rounded,
                label: 'Preparação',
                value: '${establishment.prepMinutes} min',
              ),
              _HeaderMeta(
                icon: Icons.storefront_rounded,
                label: 'Horário',
                value: '${establishment.opensAt}–${establishment.closesAt}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          InfoRow(
            icon: Icons.location_on_outlined,
            text: establishment.address,
          ),
          InfoRow(icon: Icons.phone_outlined, text: establishment.phone),
        ],
      ),
    );
  }
}

class _HeaderMeta extends StatelessWidget {
  const _HeaderMeta({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: context.mutedColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: context.mutedColor, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: context.inkColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.enabled,
    required this.onAdd,
  });

  final Product product;
  final bool enabled;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final quantity = state.quantityOf(product.id);
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NetworkThumb(
            imageUrl: product.imageUrl,
            icon: Icons.restaurant_rounded,
            size: 54,
            radius: 12,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (!product.isAvailable)
                      const StatusBadge(
                        status: 'cancelled',
                        label: 'Indisponível',
                      )
                    else if (product.stock != null)
                      Text(
                        '${product.stock} em stock',
                        style: TextStyle(
                          color: context.mutedColor,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
                if (product.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: context.mutedColor),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatMoney(product.priceCents),
                        style: TextStyle(
                          color: context.accentColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (quantity > 0)
                      QuantityStepper(
                        quantity: quantity,
                        onIncrement: () => state.increment(product.id),
                        onDecrement: () => state.decrement(product.id),
                      )
                    else
                      IconButton.filled(
                        tooltip: 'Adicionar ${product.name}',
                        onPressed: enabled ? onAdd : null,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(44, 44),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final Review review;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StarRating(rating: review.rating.toDouble()),
              const Spacer(),
              Text(
                formatDate(review.createdAt),
                style: TextStyle(color: context.mutedColor, fontSize: 10),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.comment,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: context.inkColor),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            review.customerName,
            style: TextStyle(
              color: context.mutedColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({
    required this.itemCount,
    required this.totalCents,
    required this.onTap,
  });

  final int itemCount;
  final int totalCents;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cardColor,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$itemCount ${itemCount == 1 ? 'item' : 'itens'}',
                      style: TextStyle(color: context.mutedColor, fontSize: 11),
                    ),
                    Text(
                      formatMoney(totalCents),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(minimumSize: const Size(170, 48)),
                child: const Text('Ver carrinho'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
