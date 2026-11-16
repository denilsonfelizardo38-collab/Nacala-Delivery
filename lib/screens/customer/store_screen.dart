import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

import '../../core/formatters.dart';
import '../../core/location_service.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import '../../widgets/jb.dart';

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

  /// Distância até à loja (FASE 11). `null` = ainda não calculada; o
  /// cartão "Distância" aparece no grid de factos quando a loja tem ponto
  /// no mapa e o utilizador autoriza o GPS (opcional, pedido com autorização).
  String? _distanceLabel;
  bool _distanceLoading = false;
  bool _distanceAttempted = false;

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
      _distanceAttempted = false;
      _distanceLabel = null;
    });
  }

  /// Tenta calcular a distância sem pedir permissão nova (se o utilizador já
  /// autorizou o GPS antes). Se não houver autorização, o cartão fica com a
  /// ação "Ver distância", que pede o GPS ao ser tocado.
  Future<void> _autoDistance(Establishment establishment) async {
    if (_distanceAttempted || !establishment.hasLocation) return;
    _distanceAttempted = true;
    try {
      if (!await LocationService.hasPermission()) return;
      await _computeDistance(establishment);
    } on Exception {
      // Caminho silencioso (já havia permissão): sem GPS ou sem canais
      // nativos (testes) deixa o cartão com a ação "Ver distância".
    }
  }

  /// Calcula a distância real por GPS. Se o utilizador ainda não autorizou,
  /// o sistema pede a permissão (recusar deixa o cartão como estava).
  Future<void> _computeDistance(Establishment establishment) async {
    if (_distanceLoading || !establishment.hasLocation) return;
    setState(() => _distanceLoading = true);
    try {
      final position = await LocationService.currentPosition();
      final meters = const Distance().as(
        LengthUnit.Meter,
        LatLng(position.latitude, position.longitude),
        LatLng(establishment.latitude!, establishment.longitude!),
      );
      if (!mounted) return;
      setState(() {
        _distanceLabel = meters < 1000
            ? '${meters.round()} m'
            : '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
      });
    } on LocationException catch (error) {
      // GPS recusado/indisponível: honesto — mostra a mensagem do sistema.
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _distanceLoading = false);
    }
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

    final isFavorite = state.isFavoriteEstablishment(widget.establishmentId);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Capa full-bleed no topo (`.store-head`) com controlos flutuantes
      // por cima (`.float-back` / `.float-actions`) — sem AppBar.
      body: Stack(
        children: [
          AsyncSection<EstablishmentDetail>(
            future: _future,
            onRetry: _reload,
            loadingHeight: 320,
            builder: (context, detail) => _buildContent(detail),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 6,
            left: 14,
            right: 14,
            child: Row(
              children: [
                _FloatCircleBtn(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                Material(
                  color: const Color(0x99000000),
                  shape: const CircleBorder(),
                  child: FavoriteIconButton(
                    isFavorite: isFavorite,
                    onPressed: () =>
                        toggleFavorite(context, widget.establishmentId),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: const Color(0x99000000),
                  shape: const CircleBorder(),
                  child: CartButton(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: showCartBar
          ? _CartBar(
              itemCount: state.cartItemCount,
              totalCents: state.cartTotalCents,
              onTap: () => Navigator.of(context).pushNamed('/cart'),
            )
          : null,
    );
  }

  Widget _buildContent(EstablishmentDetail detail) {
    final establishment = detail.establishment;
    // Distância até à loja quando o GPS já está autorizado (sem pedir de novo).
    _autoDistance(establishment);
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
        padding: EdgeInsets.zero,
        children: [
          _StoreHeader(
            establishment: establishment,
            distanceLabel: _distanceLabel,
            distanceLoading: _distanceLoading,
            onDistanceTap: establishment.hasLocation
                ? () => _computeDistance(establishment)
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StoreTabStrip(
                  selectedIndex: _selectedTab,
                  onSelected: (index) => setState(() => _selectedTab = index),
                ),
                const SizedBox(height: 18),
          if (_selectedTab == 0 && !establishment.isOpen) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                // `.notice` do referencial: fundo âmbar escuro, texto quente.
                color: const Color(0xFF221A0B),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 19,
                    color: Color(0xFFFFD58A),
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Este estabelecimento está encerrado. Podes consultar o menu, mas não é possível encomendar agora.',
                      style: TextStyle(
                        color: Color(0xFFFFD58A),
                        fontSize: 13,
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
                      return FilterChipPill(
                        label: isAll ? 'Todos' : category!,
                        selected: selected,
                        selectedColor: AppColors.primary,
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
                  JbSectionHeader(
                    title: entry.key,
                    count: entry.value.length,
                    margin: const EdgeInsets.only(top: 18, bottom: 2),
                  ),
                  for (final product in entry.value)
                    _ProductCard(
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
                ],
            ],
          ],
          if (_selectedTab == 1) ...[
            JbSectionHeader(
              title: 'Avaliações',
              count: detail.reviews.length,
              margin: const EdgeInsets.only(top: 18, bottom: 4),
            ),
            if (detail.reviews.isEmpty)
              const EmptyState(
                icon: Icons.rate_review_outlined,
                title: 'Sem avaliações',
                message:
                    'As avaliações aparecem aqui depois de pedidos entregues.',
              )
            else
              for (final review in detail.reviews)
                _ReviewCard(review: review),
          ],
                if (_selectedTab == 2) _AboutCard(establishment: establishment),
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

  static const _tabs = [
    'Menu',
    'Avaliações',
    'Sobre',
  ];

  @override
  Widget build(BuildContext context) {
    // `.tabs` do referencial: texto sobre linha de fundo, activa com
    // sublinhado vermelho de 2,5 px.
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.darkCard, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // Em ecrãs estreitos (360 px) ou com texto ampliado, as tabs
        // deslizam em vez de transbordarem a Row.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < _tabs.length; index++)
              Semantics(
                button: true,
                selected: selectedIndex == index,
                label: _tabs[index],
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 13),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: selectedIndex == index
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Text(
                      _tabs[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selectedIndex == index
                            ? Colors.white
                            : AppColors.muted,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({
    required this.establishment,
    this.distanceLabel,
    this.distanceLoading = false,
    this.onDistanceTap,
  });

  final Establishment establishment;

  /// Distância calculada ("1,2 km") ou `null` quando ainda não há GPS.
  final String? distanceLabel;
  final bool distanceLoading;

  /// Torna-se não-nulo só quando a loja tem ponto no mapa.
  final VoidCallback? onDistanceTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Capa full-bleed (`.store-cover`): 190 px com gradiente a preto.
        SizedBox(
          height: 190,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              if (establishment.imageUrl != null &&
                  establishment.imageUrl!.isNotEmpty)
                CoverImage(
                  imageUrl: establishment.imageUrl,
                  logicalWidth: 400,
                  fallback: _storeImageFallback(),
                )
              else
                _storeImageFallback(),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x8A000000),
                      Color(0xFF000000),
                    ],
                    stops: [0, 0.55, 1],
                  ),
                ),
              ),
              // `.store-id`: logo de 84 px com borda preta que sobrepõe
              // a capa, nome em display e meta (avaliação, selo, categoria).
              Positioned(
                left: 16,
                right: 16,
                bottom: -38,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppColors.darkElevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black, width: 3),
                      ),
                      child: establishment.imageUrl != null &&
                              establishment.imageUrl!.isNotEmpty
                          ? CoverImage(
                              imageUrl: establishment.imageUrl,
                              logicalWidth: 84,
                              fallback: _storeImageFallback(),
                            )
                          : _storeImageFallback(),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            establishment.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTheme.displayFontFamily,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                              letterSpacing: -0.6,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              RatingChip(
                                rating: establishment.rating,
                                count: establishment.reviewCount,
                              ),
                              OpenBadge(isOpen: establishment.isOpen),
                              Text(
                                establishment.categoryName,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 50),
        // `.store-desc`
        if (establishment.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(
              establishment.description,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        // `.store-facts`: grelha de cartões `--s1` com ícone vermelho,
        // rótulo pequeno e valor forte (horário, entrega, preparação,
        // morada com ligação ao mapa, distância quando há GPS).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _buildFacts(context),
        ),
      ],
    );
  }

  Widget _buildFacts(BuildContext context) {
    final facts = [
      (
        Icons.schedule_rounded,
        'Horário',
        '${establishment.opensAt}–${establishment.closesAt}',
        null,
      ),
      (
        Icons.delivery_dining_rounded,
        'Entrega',
        establishment.deliveryFeeCents == 0
            ? 'grátis'
            : formatMoneyCompact(establishment.deliveryFeeCents),
        null,
      ),
      (
        Icons.timelapse_rounded,
        'Preparação',
        '${establishment.prepMinutes} min',
        null,
      ),
      (
        Icons.location_on_outlined,
        'Morada',
        establishment.address,
        () => openStoreMap(
          context,
          address: establishment.address,
          latitude: establishment.latitude,
          longitude: establishment.longitude,
        ),
      ),
      if (onDistanceTap != null)
        (
          Icons.near_me_rounded,
          'Distância',
          distanceLoading
              ? 'A calcular…'
              : distanceLabel ?? 'Ver distância',
          distanceLabel == null && !distanceLoading ? onDistanceTap : null,
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final columns =
            ((constraints.maxWidth + gap) / 160).floor().clamp(2, 3);
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (icon, label, value, onTap) in facts)
              SizedBox(
                width: cardWidth,
                child: _FactCard(
                  icon: icon,
                  label: label,
                  value: value,
                  onTap: onTap,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _storeImageFallback() =>
      BrandedCover(categorySlug: establishment.categorySlug, iconSize: 58);
}

/// Cartão de facto no padrão `.store-facts > div`: fundo `--s1`, raio 14,
/// ícone vermelho à esquerda, rótulo pequeno e valor forte.
class _FactCard extends StatelessWidget {
  const _FactCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primarySecondary),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.muted,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: card,
      ),
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

    // `.mitem` do referencial: texto à esquerda (nome, descrição com
    // duas linhas, rodapé com preço/stock/stepper) e imagem de 108 px à
    // direita com o FAB vermelho de adicionar sobreposto.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled
            ? onAdd
            : () => showAppSnack(
                context,
                notice ?? 'Indisponível agora.',
                error: true,
              ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.darkCard, width: 1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),
                        if (!product.isAvailable)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: StatusBadge(
                              status: 'cancelled',
                              label: 'Indisponível',
                            ),
                          )
                        else if (product.stock != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              '${product.stock} un.',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (product.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        product.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Preço flexível: em ecrãs estreitos comprime-se com
                        // reticências em vez de rebentar o `Row` contra o
                        // stepper (o `Spacer` anterior dividia o espaço e
                        // ainda por cima deixava o preço sem restrição).
                        Expanded(
                          child: Text(
                            formatMoneyCompact(product.priceCents),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (product.isAvailable &&
                            product.stock != null &&
                            product.stock! <= 5) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Só ${product.stock}!',
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOut,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
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
                                  onIncrement: () =>
                                      state.increment(product.id),
                                  onDecrement: () =>
                                      state.decrement(product.id),
                                )
                              : const SizedBox(key: ValueKey('add-button')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 108,
                height: 108,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: NetworkThumb(
                        imageUrl: product.imageUrl,
                        icon: Icons.restaurant_rounded,
                        size: 108,
                        radius: 14,
                      ),
                    ),
                    // `.add-fab`: círculo vermelho com borda preta de 3 px
                    // que salta para fora da imagem.
                    if (enabled && quantity == 0)
                      Positioned(
                        right: -6,
                        bottom: -6,
                        child: Material(
                          color: AppColors.primary,
                          shape: const CircleBorder(
                            side: BorderSide(color: Colors.black, width: 3),
                          ),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onAdd,
                            child: const SizedBox(
                              width: 38,
                              height: 38,
                              child: Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    // `.comment` do referencial: avatar à esquerda, cabeçalho em fluxo
    // (nome, estrelas, data) e texto — separados por linha de 1 px.
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.darkCard, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.darkElevated,
            child: Icon(
              Icons.person_rounded,
              size: 18,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      review.customerName,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    StarRating(rating: review.rating.toDouble()),
                    Text(
                      formatDate(review.createdAt),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (review.comment.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    review.comment,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
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
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(20),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      launchCall(context, phone: establishment.phone),
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: const Text('Ligar'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    foregroundColor: AppColors.textOrange,
                    side: const BorderSide(color: AppColors.border),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openStoreMap(
                    context,
                    address: establishment.address,
                    latitude: establishment.latitude,
                    longitude: establishment.longitude,
                  ),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Ver no mapa'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    foregroundColor: AppColors.textOrange,
                    side: const BorderSide(color: AppColors.border),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
              ),
            ],
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
            borderRadius: BorderRadius.circular(10),
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
    // `.cartbar` do referencial: cápsula vermelha flutuante com o número
    // de itens, "Ver carrinho" e o total.
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      // heightFactor explícito: sem ele o `Center` expande-se até ao máximo
      // das constraints do `bottomNavigationBar` (tela toda) e esmaga o
      // corpo do ecrã para zero quando o carrinho fica não-vazio.
      child: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 728),
          child: Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(999),
            clipBehavior: Clip.antiAlias,
            elevation: 8,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      // Largura/altura fixas: um `Container` com `alignment`
                      // (Align) expande-se às constraints recebidas e, dentro
                      // do `Row`, inflacionaria a cápsula para a altura toda
                      // do `bottomNavigationBar` (esmagando o corpo do ecrã).
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$itemCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ver carrinho',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        formatMoney(totalCents),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão circular translúcido flutuante sobre a capa (`.float-back` /
/// `.float-actions`): fundo preto 60 % e ícone branco.
class _FloatCircleBtn extends StatelessWidget {
  const _FloatCircleBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x99000000),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 21, color: Colors.white),
        ),
      ),
    );
  }
}
