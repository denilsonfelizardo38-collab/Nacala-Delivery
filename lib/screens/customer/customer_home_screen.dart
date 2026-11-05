import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/address_dialog.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import 'categories_screen.dart';
import 'notifications_screen.dart';
import 'store_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _initialized = false;

  Future<List<Category>>? _categoriesFuture;
  Future<List<Establishment>>? _allEstablishmentsFuture;
  Future<List<Establishment>>? _establishmentsFuture;
  String? _selectedCategory;

  String _query = '';
  SearchResult? _searchResult;
  bool _searching = false;
  String? _searchError;

  bool get _searchMode => _query.trim().length >= 2;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final api = AppScope.of(context).api;
    _categoriesFuture = api.categories();
    final establishments = api.establishments();
    _allEstablishmentsFuture = establishments;
    _establishmentsFuture = establishments;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final api = AppScope.of(context).api;
    final categories = api.categories();
    final allEstablishments = api.establishments();
    final establishments = _selectedCategory == null
        ? allEstablishments
        : api.establishments(category: _selectedCategory);
    setState(() {
      _categoriesFuture = categories;
      _allEstablishmentsFuture = allEstablishments;
      _establishmentsFuture = establishments;
    });
    try {
      await Future.wait<Object>([
        categories,
        allEstablishments,
        establishments,
      ]);
    } on Exception {
      // O erro é apresentado pelo AsyncSection.
    }
  }

  void _selectCategory(String? slug) {
    if (_selectedCategory == slug) return;
    setState(() {
      _selectedCategory = slug;
      _establishmentsFuture = AppScope.of(context).api
          .establishments(category: slug);
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    setState(() {
      _query = value;
      _searchError = null;
      if (query.length < 2) {
        _searchResult = null;
        _searching = false;
      } else {
        _searching = true;
      }
    });
    if (query.length < 2) return;
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _runSearch(query),
    );
  }

  Future<void> _runSearch(String query) async {
    try {
      final result = await AppScope.of(context).api.search(query);
      if (!mounted || _searchController.text.trim() != query) return;
      setState(() {
        _searchResult = result;
        _searching = false;
      });
    } on ApiException catch (error) {
      if (!mounted || _searchController.text.trim() != query) return;
      setState(() {
        _searchError = error.message;
        _searching = false;
      });
    }
  }

  void _openNotifications(AppState state) {
    if (state.isGuest || !state.isSignedIn) {
      showAppSnack(
        context,
        'Entra ou cria uma conta para ver as tuas notificações.',
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
  }

  void _openStore(String id) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => StoreScreen(establishmentId: id)));
  }

  /// A morada define a disponibilidade e a taxa antes do checkout, por isso
  /// pede-se aqui, no início — não apenas no finalizar pedido.
  Future<void> _setDeliveryLocation() async {
    final state = AppScope.of(context);
    if (state.isGuest || !state.isSignedIn) {
      showAppSnack(
        context,
        'Entra ou cria uma conta para guardar a morada de entrega.',
      );
      return;
    }
    final input = await showAddressDialog(context);
    if (input == null || !mounted) return;
    try {
      await state.addAddress(
        label: input.label,
        line: input.line,
        reference: input.reference,
        isDefault: input.isDefault,
        latitude: input.latitude,
        longitude: input.longitude,
      );
      if (!mounted) return;
      setState(() {});
      showAppSnack(context, 'Morada adicionada.');
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(state)),
              if (_searchMode)
                ..._buildSearchSlivers()
              else
                ..._buildHomeSlivers(),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 14),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
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
                    const Text(
                      'NACALA DELIVERY',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Olá, ${state.firstName}!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'O que deseja pedir hoje?',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Notificações',
                      onPressed: () => _openNotifications(state),
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const CartButton(color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 17),
          Material(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: _setDeliveryLocation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        state.defaultAddress?.fullLine ??
                            'Defina a morada de entrega',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 17),
          SearchField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            hintText: 'Pesquisar lojas ou produtos...',
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHomeSlivers() {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: FutureBuilder<List<Establishment>>(
            future: _allEstablishmentsFuture,
            builder: (context, snapshot) {
              final establishments = snapshot.data ?? const <Establishment>[];
              return _PromoCarousel(
                establishments: establishments.take(3).toList(),
                onOpenStore: _openStore,
              );
            },
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: SectionTitle(
            title: 'Categorias',
            actionLabel: 'Ver todas',
            onAction: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CategoriesScreen())),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: AsyncSection<List<Category>>(
            future: _categoriesFuture,
            loadingHeight: 48,
            onRetry: _refresh,
            builder: (context, categories) {
              final visible = [
                for (final category in categories)
                  if (category.establishmentCount > 0) category,
              ];
              return FutureBuilder<List<Establishment>>(
                future: _allEstablishmentsFuture,
                builder: (context, establishmentsSnapshot) => SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: visible.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final isAll = index == 0;
                      final category = isAll ? null : visible[index - 1];
                      final selected = isAll
                          ? _selectedCategory == null
                          : _selectedCategory == category!.slug;
                      return _CategoryChip(
                        label: isAll ? 'Todas' : category!.name,
                        icon: isAll
                            ? Icons.grid_view_rounded
                            : categoryIconFor(category!.icon),
                        imageUrl: isAll
                            ? null
                            : _categoryImage(
                                category!,
                                establishmentsSnapshot.data ?? const [],
                              ),
                        selected: selected,
                        onTap: () =>
                            _selectCategory(isAll ? null : category!.slug),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: FutureBuilder<List<Establishment>>(
            future: _allEstablishmentsFuture,
            builder: (context, snapshot) {
              // Exige pelo menos 5 avaliações: evitar que "5,0" com uma
              // única avaliação apareça como "mais bem avaliado".
              final all = snapshot.data ?? const <Establishment>[];
              final promoIds = {
                for (final e in all.take(3)) e.id,
              };
              final rated = [
                for (final e in all)
                  if (e.rating > 0 &&
                      e.reviewCount >= 5 &&
                      !promoIds.contains(e.id))
                    e,
              ]..sort((a, b) => b.rating.compareTo(a.rating));
              if (rated.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(
                    title: 'Mais bem avaliados',
                    subtitle: 'Ordenados pelas avaliações reais dos clientes',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 206,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.zero,
                      itemCount: rated.length.clamp(0, 6),
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) => _PopularCard(
                        establishment: rated[index],
                        onTap: () => _openStore(rated[index].id),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: SectionTitle(
            title: _selectedCategory == null
                ? 'Perto de si'
                : 'Parceiros nesta categoria',
            subtitle: 'Estabelecimentos aprovados e disponíveis hoje',
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AsyncSection<List<Establishment>>(
            future: _establishmentsFuture,
            onRetry: _refresh,
            builder: (context, establishments) {
              // Sem categoria: os destaques do carrossel ficam por contas
              // para evitar repetir a mesma loja em secções seguidas.
              final promoOverlapping =
                  _selectedCategory == null && establishments.length > 3;
              final listed = promoOverlapping
                  ? establishments.skip(3).toList()
                  : establishments;
              if (listed.isEmpty) {
                return const EmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'Ainda sem parceiros',
                  message:
                      'Não encontrámos estabelecimentos nesta categoria. '
                      'Experimente outra categoria.',
                );
              }
              return Column(
                children: [
                  for (final establishment in listed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _HomeStoreCard(
                        establishment: establishment,
                        onTap: () => _openStore(establishment.id),
                        isFavorite: AppScope.of(context)
                            .isFavoriteEstablishment(establishment.id),
                        onFavoriteToggle: () =>
                            toggleFavorite(context, establishment.id),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildSearchSlivers() {
    final result = _searchResult;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            'Resultados para "${_query.trim()}"',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.mutedColor),
          ),
        ),
      ),
      if (_searching)
        const SliverToBoxAdapter(child: LoadingBlock(height: 120))
      else if (_searchError != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ErrorState(
              message: _searchError!,
              onRetry: () => _runSearch(_query.trim()),
            ),
          ),
        )
      else if (result != null)
        if (result.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Sem resultados',
              message: 'Tente outra palavra, como "frango", "farmácia" ou "mercado".',
            ),
          )
        else ...[
          if (result.products.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: SectionTitle(
                  title: 'Produtos',
                  subtitle:
                      '${result.products.length} ${plural(result.products.length, 'resultado')}',
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    for (final product in result.products)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ProductResultTile(
                          product: product,
                          onTap: () => _openStore(product.establishmentId),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (result.establishments.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: SectionTitle(
                  title: 'Estabelecimentos',
                  subtitle:
                      '${result.establishments.length} ${plural(result.establishments.length, 'estabelecimento')}',
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    for (final establishment in result.establishments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: EstablishmentTile(
                          establishment: establishment,
                          onTap: () => _openStore(establishment.id),
                          isFavorite: AppScope.of(context)
                              .isFavoriteEstablishment(establishment.id),
                          onFavoriteToggle: () =>
                              toggleFavorite(context, establishment.id),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
    ];
  }

  String? _categoryImage(
    Category category,
    List<Establishment> establishments,
  ) {
    for (final establishment in establishments) {
      if (establishment.categorySlug == category.slug &&
          establishment.imageUrl != null &&
          establishment.imageUrl!.isNotEmpty) {
        return establishment.imageUrl;
      }
    }
    return null;
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.imageUrl,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String? imageUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : AppColors.primarySoftStrong,
                  shape: BoxShape.circle,
                ),
                child: imageUrl == null
                    ? Icon(
                        icon,
                        color: selected ? Colors.white : AppColors.primary,
                        size: 23,
                      )
                    : ClipOval(
                        child: Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            icon,
                            color: selected ? Colors.white : AppColors.primary,
                            size: 23,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? AppColors.textOrange : context.inkColor,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carrossel de promoções e destaques da página inicial. O primeiro painel
/// é a marca; seguem-se até três parceiros em destaque (em vez de fixar um
/// único restaurante numa entrada estática).
class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel({
    required this.establishments,
    required this.onOpenStore,
  });

  final List<Establishment> establishments;
  final void Function(String establishmentId) onOpenStore;

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void didUpdateWidget(covariant _PromoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_page >= widget.establishments.length + 1) {
      _page = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = <_PromoSlide>[
      const _PromoSlide.brand(),
      for (final establishment in widget.establishments)
        _PromoSlide(establishment: establishment),
    ];
    return Column(
      children: [
        ClipRect(
          child: SizedBox(
            height: 184,
            child: PageView.builder(
              controller: _controller,
              itemCount: slides.length,
              onPageChanged: (index) => setState(() => _page = index),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemBuilder: (context, index) {
                final slide = slides[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: _PromoCard(
                    slide: slide,
                    onTap: slide.establishment == null
                        ? null
                        : () => widget.onOpenStore(slide.establishment!.id),
                  ),
                );
              },
            ),
          ),
        ),
        if (slides.length > 1) ...[
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (
                var index = 0;
                index < slides.length;
                index++
              )
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: index == _page ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: index == _page
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PromoSlide {
  const _PromoSlide({this.establishment});

  /// Painel da marca, sem parceiro associado.
  const _PromoSlide.brand() : establishment = null;

  final Establishment? establishment;

  bool get isBrand => establishment == null;
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.slide, required this.onTap});

  final _PromoSlide slide;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final establishment = slide.establishment;
    final name = establishment?.name ?? 'A cidade à sua porta.';
    final subtitle = establishment == null
        ? 'Descubra os parceiros de Nacala-Porto'
        : '${establishment.categoryName} · ${establishment.prepMinutes} min';
    final imageUrl = establishment?.imageUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: AppCard(
        padding: EdgeInsets.zero,
        radius: 22,
        onTap: onTap,
        child: SizedBox(
          height: 184,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (establishment == null)
                  // Painel da marca: a fotografia da cidade com selo claro.
                  Image.asset(
                    'assets/images/login_bg.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: AppColors.ink),
                  )
                else if (imageUrl != null && imageUrl.isNotEmpty)
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    cacheWidth: imageCacheWidthFor(context, 360),
                    errorBuilder: (_, _, _) => BrandedCover(
                      categorySlug: establishment.categorySlug,
                      iconSize: 38,
                    ),
                  )
                else
                  BrandedCover(
                    categorySlug: establishment.categorySlug,
                    iconSize: 38,
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0x80002244),
                        Color(0x22002244),
                        Color(0xE6051C36),
                      ],
                      stops: [0, 0.45, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        establishment == null ? 'Destaques de Nacala' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        establishment == null ? 'Explorar parceiros ›' : 'Ver menu  ›',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeStoreCard extends StatelessWidget {
  const _HomeStoreCard({
    required this.establishment,
    required this.onTap,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  final Establishment establishment;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final imageUrl = establishment.imageUrl;
    return AppCard(
      padding: EdgeInsets.zero,
      radius: 21,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 140,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(21),
              ),
              child: imageUrl == null || imageUrl.isEmpty
                  ? BrandedCover(
                      categorySlug: establishment.categorySlug,
                      iconSize: 42,
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      cacheWidth: imageCacheWidthFor(context, 320),
                      errorBuilder: (_, _, _) => BrandedCover(
                        categorySlug: establishment.categorySlug,
                        iconSize: 42,
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 12, 15, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        establishment.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(height: 1.25),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(
                      status: establishment.isOpen ? 'accepted' : 'cancelled',
                      label: establishment.isOpen ? 'Aberto' : 'Fechado',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  establishment.categoryName,
                  style: TextStyle(color: context.mutedColor, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  establishment.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.mutedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    StarRating(
                      rating: establishment.rating,
                      count: establishment.reviewCount,
                    ),
                    Text(
                      'Entrega ${formatMoneyCompact(establishment.deliveryFeeCents)}'
                      ' · ${establishment.prepMinutes} min',
                      style: TextStyle(color: context.mutedColor, fontSize: 11),
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

class _ProductResultTile extends StatelessWidget {
  const _ProductResultTile({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          NetworkThumb(
            imageUrl: product.imageUrl,
            icon: Icons.restaurant_rounded,
            size: 46,
            radius: 12,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  product.establishmentName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.mutedColor, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatMoneyCompact(product.priceCents),
            style: TextStyle(
              color: context.accentColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cartão compacto horizontal da secção "Mais bem avaliados". Mostra
/// apenas dados que existem no servidor (avaliação e taxa de entrega).
class _PopularCard extends StatelessWidget {
  const _PopularCard({required this.establishment, required this.onTap});

  final Establishment establishment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = establishment.imageUrl;
    return AppCard(
      padding: EdgeInsets.zero,
      radius: 20,
      onTap: onTap,
      child: SizedBox(
        width: 196,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 104,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: imageUrl == null || imageUrl.isEmpty
                    ? BrandedCover(
                        categorySlug: establishment.categorySlug,
                        iconSize: 34,
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        cacheWidth: imageCacheWidthFor(context, 196),
                        errorBuilder: (_, _, _) => BrandedCover(
                          categorySlug: establishment.categorySlug,
                          iconSize: 34,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    establishment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    establishment.categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.mutedColor, fontSize: 10),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      StarRating(rating: establishment.rating, size: 12),
                      const Spacer(),
                      Text(
                        'Entrega ${formatMoneyCompact(establishment.deliveryFeeCents)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.mutedColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
    );
  }
}
