import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import 'cart_screen.dart';

const Color _storeOrange = Color(0xFFF47721);
const Color _storeOrangeDark = Color(0xFFE76512);
const Color _storeOrangeSoft = Color(0xFFFFF1E7);
const Color _storeInk = Color(0xFF191715);
const Color _storeMuted = Color(0xFF817B75);
const Color _storeLine = Color(0xFFECE7E2);
const Color _storeCanvas = Color(0xFFFAF8F6);

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
      if (!confirmed || !mounted) return;
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
      backgroundColor: _storeCanvas,
      appBar: AppBar(
        backgroundColor: _storeCanvas,
        title: FutureBuilder<EstablishmentDetail>(
          future: _future,
          builder: (context, snapshot) => Text(
            snapshot.data?.establishment.name ?? 'Estabelecimento',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: const [CartButton(), SizedBox(width: 8)],
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
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CartScreen()),
              ),
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
      color: _storeOrange,
      onRefresh: () async => _reload(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
        children: [
          _StoreHeader(establishment: establishment),
          const SizedBox(height: 19),
          _StoreTabStrip(
            selectedIndex: _selectedTab,
            onSelected: (index) => setState(() => _selectedTab = index),
          ),
          const SizedBox(height: 20),
          if (_selectedTab == 0 && !establishment.isOpen) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6E8),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFF2DFBD)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 19,
                    color: Color(0xFF946018),
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Este estabelecimento está encerrado. Podes consultar o menu, mas não é possível encomendar agora.',
                      style: TextStyle(
                        color: Color(0xFF805316),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 17),
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
                _MenuSectionHeading(
                  title: entry.key,
                  count: entry.value.length,
                ),
                const SizedBox(height: 11),
                for (final product in entry.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ProductCard(
                      product: product,
                      enabled: establishment.isOpen && product.isAvailable,
                      onAdd: () => _add(product, establishment),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
          ],
          if (_selectedTab == 1) ...[
            _MenuSectionHeading(
              title: 'Avaliações',
              count: detail.reviews.length,
              subtitle: detail.reviews.isEmpty
                  ? 'Ainda sem avaliações reais'
                  : 'Opiniões de clientes',
            ),
            const SizedBox(height: 12),
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
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReviewCard(review: review),
                ),
          ],
          if (_selectedTab == 2)
            _AboutCard(establishment: establishment),
        ],
      ),
    );
  }
}

class _StoreTabStrip extends StatelessWidget {
  const _StoreTabStrip({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _tabs = [
    ('Menu', Icons.restaurant_menu_rounded),
    ('Avaliações', Icons.star_outline_rounded),
    ('Sobre', Icons.info_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0ECE8),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          for (var index = 0; index < _tabs.length; index++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: selectedIndex == index
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: selectedIndex == index
                        ? [
                            BoxShadow(
                              color: _storeInk.withValues(alpha: 0.07),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _tabs[index].$2,
                        size: 15,
                        color: selectedIndex == index
                            ? _storeOrangeDark
                            : _storeMuted,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _tabs[index].$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selectedIndex == index
                                ? _storeInk
                                : _storeMuted,
                            fontSize: 11,
                            fontWeight: selectedIndex == index
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 205,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _storeOrangeSoft,
            borderRadius: BorderRadius.circular(23),
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
                    colors: [
                      Color(0x12000000),
                      Colors.transparent,
                      Color(0xC9000000),
                    ],
                    stops: [0, 0.38, 1],
                  ),
                ),
              ),
              Positioned(
                top: 13,
                left: 13,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFC247),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        establishment.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (establishment.reviewCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '· ${establishment.reviewCount} avaliações',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 13,
                bottom: 13,
                child: StatusBadge(
                  status: establishment.isOpen ? 'accepted' : 'cancelled',
                  label: establishment.isOpen ? 'Aberto agora' : 'Fechado',
                ),
              ),
              Positioned(
                left: 16,
                right: 110,
                bottom: 15,
                child: Text(
                  establishment.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    shadows: [
                      Shadow(
                        color: Color(0x88000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: _storeLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (establishment.description.isNotEmpty) ...[
                Text(
                  establishment.description,
                  style: const TextStyle(
                    color: _storeMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 15),
              ],
              Row(
                children: [
                  Expanded(
                    child: _HeaderMeta(
                      icon: Icons.delivery_dining_rounded,
                      label: 'Entrega',
                      value: formatMoney(establishment.deliveryFeeCents),
                    ),
                  ),
                  Container(width: 1, height: 32, color: _storeLine),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 13),
                      child: _HeaderMeta(
                        icon: Icons.timelapse_rounded,
                        label: 'Preparação',
                        value: '${establishment.prepMinutes} min',
                      ),
                    ),
                  ),
                  Container(width: 1, height: 32, color: _storeLine),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 13),
                      child: _HeaderMeta(
                        icon: Icons.schedule_rounded,
                        label: 'Horário',
                        value:
                            '${establishment.opensAt}–${establishment.closesAt}',
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: _storeLine),
              ),
              InfoRow(
                icon: Icons.location_on_outlined,
                text: establishment.address,
              ),
              InfoRow(
                icon: Icons.phone_outlined,
                text: establishment.phone,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _storeImageFallback() => const ColoredBox(
    color: _storeOrangeSoft,
    child: Center(
      child: Icon(
        Icons.storefront_rounded,
        color: _storeOrange,
        size: 58,
      ),
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
          children: [
            Icon(icon, size: 13, color: _storeOrangeDark),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _storeMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _storeInk,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _MenuSectionHeading extends StatelessWidget {
  const _MenuSectionHeading({
    required this.title,
    required this.count,
    this.subtitle,
  });

  final String title;
  final int count;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _storeInk,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: _storeMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (count > 0)
          Text(
            '$count ${count == 1 ? 'opção' : 'opções'}',
            style: const TextStyle(
              color: _storeMuted,
              fontSize: 10,
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _storeLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NetworkThumb(
            imageUrl: product.imageUrl,
            icon: Icons.restaurant_rounded,
            size: 94,
            radius: 15,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          color: _storeInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (!product.isAvailable)
                      const StatusBadge(
                        status: 'cancelled',
                        label: 'Indisponível',
                      )
                    else if (product.stock != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: Text(
                          '${product.stock} un.',
                          style: const TextStyle(
                            color: _storeMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                if (product.description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _storeMuted,
                      fontSize: 10,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatMoney(product.priceCents),
                        style: const TextStyle(
                          color: _storeOrangeDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
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
                      SizedBox(
                        height: 38,
                        child: FilledButton.icon(
                          onPressed: enabled ? onAdd : null,
                          icon: const Icon(Icons.add_rounded, size: 17),
                          label: const Text('Adicionar'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _storeOrange,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFE8E3DE),
                            disabledForegroundColor: _storeMuted,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
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
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _storeLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StarRating(rating: review.rating.toDouble()),
              const Spacer(),
              Text(
                formatDate(review.createdAt),
                style: const TextStyle(
                  color: _storeMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment,
              style: const TextStyle(
                color: _storeInk,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const CircleAvatar(
                radius: 13,
                backgroundColor: _storeOrangeSoft,
                child: Icon(
                  Icons.person_rounded,
                  size: 15,
                  color: _storeOrangeDark,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                review.customerName,
                style: const TextStyle(
                  color: _storeMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.establishment});

  final Establishment establishment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _storeLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sobre ${establishment.name}',
            style: const TextStyle(
              color: _storeInk,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (establishment.description.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              establishment.description,
              style: const TextStyle(
                color: _storeMuted,
                fontSize: 12,
                height: 1.55,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _AboutInfoRow(
            icon: Icons.location_on_outlined,
            title: 'Endereço',
            value: establishment.address,
          ),
          const SizedBox(height: 14),
          _AboutInfoRow(
            icon: Icons.phone_outlined,
            title: 'Contacto',
            value: establishment.phone,
          ),
          const SizedBox(height: 14),
          _AboutInfoRow(
            icon: Icons.schedule_rounded,
            title: 'Horário de funcionamento',
            value: '${establishment.opensAt}–${establishment.closesAt}',
          ),
        ],
      ),
    );
  }
}

class _AboutInfoRow extends StatelessWidget {
  const _AboutInfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: _storeOrangeSoft,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: _storeOrangeDark, size: 17),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _storeMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: _storeInk,
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: _storeLine)),
        boxShadow: [
          BoxShadow(
            color: _storeInk.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(19, 11, 19, 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$itemCount ${itemCount == 1 ? 'item' : 'itens'} no carrinho',
                      style: const TextStyle(
                        color: _storeMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formatMoney(totalCents),
                      style: const TextStyle(
                        color: _storeInk,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 158,
                height: 49,
                child: FilledButton.icon(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: _storeOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: const Icon(Icons.shopping_bag_outlined, size: 17),
                  label: const Text('Ver carrinho'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
