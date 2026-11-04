import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
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
  final _menuSearch = TextEditingController();
  String _menuQuery = '';
  String? _menuCategory;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _future = AppScope.of(context).api.establishment(widget.establishmentId);
  }

  @override
  void dispose() {
    _menuSearch.dispose();
    super.dispose();
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: FutureBuilder<EstablishmentDetail>(
          future: _future,
          builder: (context, snapshot) => Text(
            snapshot.data?.establishment.name ?? 'Estabelecimento',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          FavoriteIconButton(
            isFavorite: AppScope.of(context)
                .isFavoriteEstablishment(widget.establishmentId),
            onPressed: () => toggleFavorite(context, widget.establishmentId),
          ),
          const SizedBox(width: 2),
          const CartButton(),
          const SizedBox(width: 8),
        ],
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
    final query = _menuQuery.toLowerCase();
    final groups = <String, List<Product>>{};
    for (final product in detail.products) {
      if (query.isNotEmpty &&
          !(product.name.toLowerCase().contains(query) ||
              product.description.toLowerCase().contains(query))) {
        continue;
      }
      if (_menuCategory != null && product.category != _menuCategory) {
        continue;
      }
      groups.putIfAbsent(product.category, () => []).add(product);
    }
    final categories = {
      for (final product in detail.products) product.category,
    }.toList()..sort();

    return RefreshIndicator(
      color: AppColors.primary,
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
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.35),
                ),
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
            else ...[
              SearchField(
                controller: _menuSearch,
                hintText: 'Pesquisar neste menu...',
                onChanged: (value) => setState(() => _menuQuery = value.trim()),
              ),
              const SizedBox(height: 12),
              if (categories.length > 1)
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final isAll = index == 0;
                      final category = isAll ? null : categories[index - 1];
                      final selected = isAll
                          ? _menuCategory == null
                          : _menuCategory == category;
                      return _MenuChip(
                        label: isAll ? 'Todos' : category!,
                        selected: selected,
                        onTap: () => setState(
                          () => _menuCategory = isAll ? null : category,
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 14),
              if (groups.isEmpty)
                const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Sem resultados',
                  message: 'Nenhum produto corresponde à pesquisa ou filtro.',
                  compact: true,
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
                        disabledNotice: !product.isAvailable
                            ? 'Este produto está indisponível neste momento.'
                            : !establishment.isOpen
                            ? '${establishment.name} está '
                                  'encerrado (${establishment.opensAt}–'
                                  '${establishment.closesAt}). Volte mais tarde.'
                            : null,
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
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
          if (_selectedTab == 2) _AboutCard(establishment: establishment),
        ],
      ),
    );
  }
}

class _StoreTabStrip extends StatelessWidget {
  const _StoreTabStrip({required this.selectedIndex, required this.onSelected});

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
        color: context.isDarkMode ? AppColors.darkElevated : AppColors.surface,
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
                        ? (context.isDarkMode ? AppColors.darkCard : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: selectedIndex == index
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: context.isDarkMode ? 0.3 : 0.07,
                              ),
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
                            ? context.accentColor
                            : context.mutedColor,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _tabs[index].$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selectedIndex == index
                                ? context.inkColor
                                : context.mutedColor,
                            fontSize: 11,
                            fontWeight: selectedIndex == index
                                ? FontWeight.w700
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
            color: AppColors.primarySoft,
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
                          fontWeight: FontWeight.w700,
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
                    fontWeight: FontWeight.w700,
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
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (establishment.description.isNotEmpty) ...[
                Text(
                  establishment.description,
                  style: const TextStyle(
                    color: AppColors.muted,
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
                  Container(width: 1, height: 32, color: AppColors.border),
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
                  Container(width: 1, height: 32, color: AppColors.border),
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
                child: Divider(height: 1, color: AppColors.border),
              ),
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

  Widget _storeImageFallback() =>
      BrandedCover(categorySlug: establishment.categorySlug, iconSize: 58);
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
            Icon(icon, size: 13, color: AppColors.primaryPressed),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
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
            color: AppColors.ink,
            fontSize: 11,
            fontWeight: FontWeight.w700,
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
                  color: AppColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        if (count > 0)
          Text(
            '$count ${count == 1 ? 'opção' : 'opções'}',
            style: const TextStyle(
              color: AppColors.muted,
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
    this.disabledNotice,
  });

  final Product product;
  final bool enabled;
  final VoidCallback onAdd;

  /// Mostrado como snackbar quando o utilizador toca num produto que não
  /// pode ser adicionado (encerrado ou indisponível), em vez de ficar
  /// sem qualquer resposta.
  final String? disabledNotice;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final quantity = state.quantityOf(product.id);
    final notice = disabledNotice;

    return AppCard(
      onTap: enabled
          ? onAdd
          : () => showAppSnack(
              context,
              notice ?? 'Indisponível agora.',
              error: true,
            ),
      padding: const EdgeInsets.all(12),
      radius: 18,
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
                          color: AppColors.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
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
                            color: AppColors.muted,
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
                      color: AppColors.muted,
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
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primaryPressed,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOut,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.92,
                            end: 1,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: quantity > 0
                          ? QuantityStepper(
                              key: const ValueKey('stepper'),
                              quantity: quantity,
                              onIncrement: () => state.increment(product.id),
                              onDecrement: () => state.decrement(product.id),
                            )
                          : SizedBox(
                              key: const ValueKey('add-button'),
                              height: 44,
                              child: FilledButton.icon(
                                onPressed: enabled
                                    ? onAdd
                                    : () => showAppSnack(
                                        context,
                                        notice ?? 'Indisponível agora.',
                                        error: true,
                                      ),
                                icon: const Icon(Icons.add_rounded, size: 17),
                                label: const Text('Adicionar'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: AppColors.border,
                                  disabledForegroundColor: AppColors.muted,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                  ),
                                  minimumSize: const Size(0, 44),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
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
        border: Border.all(color: AppColors.border),
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
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment,
              style: const TextStyle(
                color: AppColors.ink,
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
                backgroundColor: AppColors.primarySoft,
                child: Icon(
                  Icons.person_rounded,
                  size: 15,
                  color: AppColors.primaryPressed,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                review.customerName,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
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
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sobre ${establishment.name}',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (establishment.description.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              establishment.description,
              style: const TextStyle(
                color: AppColors.muted,
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
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: AppColors.primaryPressed, size: 17),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.ink,
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
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
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
                        color: AppColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formatMoney(totalCents),
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
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
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

/// Chip de filtro das secções do menu (Horizontal). Selecionado usa o
/// laranja da marca, tal como os chips de categoria da página inicial.
class _MenuChip extends StatelessWidget {
  const _MenuChip({
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
      color: selected ? AppColors.primary : context.cardColor,
      borderRadius: BorderRadius.circular(999),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.primary : context.lineColor,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: selected ? Colors.white : context.mutedColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
