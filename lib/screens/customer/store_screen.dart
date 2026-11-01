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
  int _selectedTab = 0;
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
        title: FutureBuilder<EstablishmentDetail>(
          future: _future,
          builder: (context, snapshot) => Text(
            snapshot.data?.establishment.name ?? 'Estabelecimento',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
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
          const SizedBox(height: 14),
          _StoreTabStrip(
            selectedIndex: _selectedTab,
            onSelected: (index) => setState(() => _selectedTab = index),
          ),
          const SizedBox(height: 16),
          if (_selectedTab == 0 && !establishment.isOpen) ...[
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
          if (_selectedTab == 0) ...[
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
          ],
          if (_selectedTab == 1) ...[
            SectionTitle(
              title: 'Avaliações',
              subtitle: detail.reviews.isEmpty
                  ? 'Ainda sem avaliações reais'
                  : '${detail.reviews.length} avaliação(ões) de clientes',
            ),
            const SizedBox(height: 10),
            if (detail.reviews.isEmpty)
              const EmptyState(
                icon: Icons.rate_review_outlined,
                title: 'Sem avaliações',
                message:
                    'As avaliações aparecem aqui depois de pedidos entregues.',
              )
            else
              for (final review in detail.reviews)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ReviewCard(review: review),
                ),
          ],
          if (_selectedTab == 2)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sobre ${establishment.name}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (establishment.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      establishment.description,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: context.mutedColor),
                    ),
                  ],
                  const SizedBox(height: 12),
                  InfoRow(
                    icon: Icons.location_on_outlined,
                    text: establishment.address,
                  ),
                  InfoRow(
                    icon: Icons.phone_outlined,
                    text: establishment.phone,
                  ),
                  InfoRow(
                    icon: Icons.schedule_rounded,
                    text:
                        'Horário: ${establishment.opensAt}–${establishment.closesAt}',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StoreTabStrip extends StatelessWidget {
  const _StoreTabStrip({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _tabs = ['Menu', 'Avaliações', 'Sobre'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < _tabs.length; index++)
          Expanded(
            child: InkWell(
              onTap: () => onSelected(index),
              child: Column(
                children: [
                  Text(
                    _tabs[index],
                    style: TextStyle(
                      color: selectedIndex == index
                          ? AppColors.primary
                          : context.mutedColor,
                      fontSize: 12,
                      fontWeight: selectedIndex == index
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 2,
                    decoration: BoxDecoration(
                      color: selectedIndex == index
                          ? AppColors.primary
                          : context.lineColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.establishment});
  final Establishment establishment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 170,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (establishment.imageUrl != null &&
                  establishment.imageUrl!.isNotEmpty)
                Image.network(
                  establishment.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _storeImageFallback(),
                )
              else
                _storeImageFallback(),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xB3000000)],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                bottom: 14,
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFC247),
                      size: 18,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      establishment.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (establishment.reviewCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(${establishment.reviewCount} avaliações)',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: StatusBadge(
                  status: establishment.isOpen ? 'accepted' : 'cancelled',
                  label: establishment.isOpen ? 'Aberto' : 'Fechado',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                establishment.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (establishment.description.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  establishment.description,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.mutedColor),
                ),
              ],
              const SizedBox(height: 14),
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
              const SizedBox(height: 8),
              InfoRow(
                icon: Icons.location_on_outlined,
                text: establishment.address,
              ),
              InfoRow(icon: Icons.phone_outlined, text: establishment.phone),
            ],
          ),
        ),
      ],
    );
  }

  Widget _storeImageFallback() => const ColoredBox(
    color: AppColors.primarySoft,
    child: Center(
      child: Icon(Icons.storefront_rounded, color: AppColors.primary, size: 56),
    ),
  );
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
            fontWeight: FontWeight.w600,
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
            size: 84,
            radius: 14,
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
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 8,
                  children: [
                    Text(
                      formatMoney(product.priceCents),
                      style: TextStyle(
                        color: context.accentColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (quantity > 0)
                      QuantityStepper(
                        quantity: quantity,
                        onIncrement: () => state.increment(product.id),
                        onDecrement: () => state.decrement(product.id),
                      )
                    else
                      FilledButton.icon(
                        onPressed: enabled ? onAdd : null,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Adicionar'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
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
      elevation: 0,
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 154,
                child: FilledButton.icon(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                  label: const Text('Pedir agora'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
