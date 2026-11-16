import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import '../../widgets/jb.dart';

/// Página inicial no padrão Já Bazou: `hero` com marca, saudação
/// display gigante e pesquisa em cápsula; chips de filtro; pílulas de
/// categoria; e um feed de secções derivadas dos dados existentes —
/// Favoritas, Entrega grátis, Melhor avaliados, Explorar produtos e
/// Todas as lojas (linhas `srow`).
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
  Future<List<Product>>? _productsFuture;
  String? _selectedCategory; // slug
  bool _openOnly = false;
  bool _freeOnly = false;

  /// Paginação do feed ("Ver mais"): lojas e produtos de cada vez.
  int _storeLimit = 10;
  int _productLimit = 12;

  String _query = '';
  SearchResult? _searchResult;
  bool _searching = false;
  String? _searchError;

  bool get _searchMode => _query.trim().length >= 2;

  /// Feed completo: sem categoria nem filtros activos (as secções
  /// derivadas só fazem sentido nesse modo).
  bool get _fullFeed =>
      !_searchMode && _selectedCategory == null && !_openOnly && !_freeOnly;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final api = AppScope.of(context).api;
    _categoriesFuture = api.categories();
    _allEstablishmentsFuture = api.establishments();
    _productsFuture = api.products();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final api = AppScope.of(context).api;
    setState(() {
      _categoriesFuture = api.categories();
      _allEstablishmentsFuture = api.establishments();
      _productsFuture = api.products();
    });
    try {
      await Future.wait<Object>([
        _categoriesFuture!,
        _allEstablishmentsFuture!,
        _productsFuture!,
      ]);
    } on Exception {
      // O erro é apresentado pelo AsyncSection.
    }
  }

  void _selectCategory(String? slug) {
    final next = _selectedCategory == slug ? null : slug;
    setState(() {
      _selectedCategory = next;
      _storeLimit = 10;
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
      // Sem sessão: levar directamente à escolha de tipo de conta.
      Navigator.of(context).pushNamed('/roles', arguments: 'login');
      return;
    }
    Navigator.of(context).pushNamed('/notifications');
  }

  void _openStore(String id) {
    Navigator.of(context).pushNamed('/store', arguments: id);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHero(state)),
              SliverToBoxAdapter(child: _buildChipsRow()),
              SliverToBoxAdapter(child: _buildPills()),
              if (_searchMode)
                ..._buildSearchSlivers()
              else
                ..._buildFeedSlivers(state),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }

  /* ------------------------------- Hero ------------------------------- */

  Widget _buildHero(AppState state) {
    final first = state.firstName;
    final guest = !state.isSignedIn;
    final searchField = SearchField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      hintText: 'Pratos, lojas, farmácias…',
    );
    return JbHeroHeader(
      greeting: first.isEmpty
          ? 'O que vai pedir hoje?'
          : '$first, o que vai pedir hoje?',
      // Sem sessão: os dois CTA de entrada por cima da pesquisa.
      search: guest
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _HeroAuthButton(
                        label: 'Entrar',
                        primary: true,
                        onTap: () => Navigator.of(context)
                            .pushNamed('/roles', arguments: 'login'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroAuthButton(
                        label: 'Criar conta',
                        primary: false,
                        onTap: () => Navigator.of(context)
                            .pushNamed('/roles', arguments: 'register'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                searchField,
              ],
            )
          : searchField,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: AppColors.darkCard,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _openNotifications(state),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: context.inkColor,
                  size: 21,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.darkCard,
            shape: const CircleBorder(),
            child: CartButton(color: context.inkColor),
          ),
        ],
      ),
    );
  }

  /* --------------------------- Chips e pílulas ------------------------ */

  Widget _buildChipsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilterIconChip(
            icon: Icons.store_rounded,
            label: 'Só abertas',
            selected: _openOnly,
            onTap: () => setState(() {
              _openOnly = !_openOnly;
              _storeLimit = 10;
            }),
          ),
          FilterIconChip(
            icon: Icons.delivery_dining_rounded,
            label: 'Entrega grátis',
            selected: _freeOnly,
            onTap: () => setState(() {
              _freeOnly = !_freeOnly;
              _storeLimit = 10;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPills() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: AsyncSection<List<Category>>(
        future: _categoriesFuture,
        loadingHeight: 46,
        onRetry: _refresh,
        builder: (context, categories) {
          final selectedName =
              _selectedCategory == null
                  ? 'Tudo'
                  : categories
                        .where((c) => c.slug == _selectedCategory)
                        .map((c) => c.name)
                        .firstOrNull ??
                    'Tudo';
          return CategoryPills(
            items: [
              'Tudo',
              for (final category in categories)
                if (category.establishmentCount > 0) category.name,
            ],
            selected: selectedName,
            onSelected: (name) {
              if (name == 'Tudo') {
                _selectCategory(null);
                return;
              }
              final slug = categories
                  .where((c) => c.name == name)
                  .map((c) => c.slug)
                  .firstOrNull;
              if (slug != null) _selectCategory(slug);
            },
          );
        },
      ),
    );
  }

  /* -------------------------------- Feed ------------------------------ */

  List<Widget> _buildFeedSlivers(AppState state) {
    return [
      SliverToBoxAdapter(
        child: AsyncSection<List<Establishment>>(
          future: _allEstablishmentsFuture,
          onRetry: _refresh,
          loadingHeight: 260,
          builder: (context, all) => _buildFeed(context, state, all),
        ),
      ),
      if (_fullFeed)
        SliverToBoxAdapter(child: _buildProductsSection()),
    ];
  }

  Widget _buildFeed(
    BuildContext context,
    AppState state,
    List<Establishment> all,
  ) {
    // Lista principal, filtrada pela categoria e pelos chips.
    var stores = all
        .where(
          (e) =>
              _selectedCategory == null ||
              e.categorySlug == _selectedCategory,
        )
        .where((e) => !_openOnly || e.isOpen)
        .where((e) => !_freeOnly || e.deliveryFeeCents == 0)
        .toList();

    final sections = <Widget>[];

    if (_fullFeed) {
      // 1) As tuas favoritas — anéis vermelhos.
      final favorites = [
        for (final e in all)
          if (state.favoriteEstablishmentIds.contains(e.id)) e,
      ];
      if (favorites.isNotEmpty) {
        sections.addAll([
          const JbSectionHeader(title: 'As tuas favoritas'),
          _favRow(favorites),
        ]);
      }

      // 2) Entrega grátis — lojas abertas sem taxa.
      final free = [
        for (final e in all)
          if (e.isOpen && e.deliveryFeeCents == 0) e,
      ];
      if (free.isNotEmpty) {
        sections.addAll([
          const JbSectionHeader(
            title: 'Entrega grátis',
            trailing: Icon(
              Icons.delivery_dining_rounded,
              size: 17,
              color: AppColors.primary,
            ),
          ),
          _favRow(free.take(12).toList()),
        ]);
      }

      // 3) Melhor avaliados — cartões horizontais.
      final rated = [
        for (final e in all)
          if (e.rating > 0 && e.reviewCount >= 5) e,
      ]..sort((a, b) => b.rating.compareTo(a.rating));
      if (rated.isNotEmpty) {
        sections.addAll([
          const JbSectionHeader(title: 'Melhor avaliados'),
          _storeCardRow(rated.take(6).toList()),
        ]);
      }
    }

    // 4) Todas as lojas (ou a selecção activa) — linhas `srow`.
    final title = _selectedCategory != null
        ? (all
                  .where((e) => e.categorySlug == _selectedCategory)
                  .map((e) => e.categoryName)
                  .firstOrNull ??
              'Lojas')
        : _openOnly
        ? 'Só abertas'
        : _freeOnly
        ? 'Entrega grátis'
        : 'Todas as lojas';

    if (stores.isEmpty) {
      sections.add(
        const EmptyState(
          icon: Icons.storefront_outlined,
          title: 'Ainda sem lojas aqui',
          message:
              'Não encontrámos lojas com estes filtros. '
              'Experimenta desligar os filtros ou escolher outra categoria.',
        ),
      );
    } else {
      final visible = stores.take(_storeLimit).toList();
      sections.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              JbSectionHeader(title: title, count: stores.length),
              for (final establishment in visible)
                StoreRow(
                  establishment: establishment,
                  onTap: () => _openStore(establishment.id),
                  isFavorite: state.isFavoriteEstablishment(
                    establishment.id,
                  ),
                  onFavoriteToggle: () =>
                      toggleFavorite(context, establishment.id),
                ),
              if (stores.length > _storeLimit)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton(
                    onPressed: () =>
                        setState(() => _storeLimit += 10),
                    child: Text(
                      'Ver mais lojas (${stores.length - _storeLimit})',
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sections);
  }

  /// Fila horizontal de favoritas/entrega grátis (`.favrow`).
  Widget _favRow(List<Establishment> items) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final e = items[index];
          return FavChip(
            name: e.name,
            imageUrl: e.imageUrl,
            categorySlug: e.categorySlug,
            onTap: () => _openStore(e.id),
          );
        },
      ),
    );
  }

  /// Fila horizontal de cartões de loja (`.hscroll`).
  Widget _storeCardRow(List<Establishment> items) {
    return SizedBox(
      height: 186,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => StoreCardJB(
          establishment: items[index],
          onTap: () => _openStore(items[index].id),
        ),
      ),
    );
  }

  /// "Explorar produtos" (`.pgrid`): grelha 2+ colunas com "Ver mais".
  Widget _buildProductsSection() {
    return AsyncSection<List<Product>>(
      future: _productsFuture,
      onRetry: _refresh,
      loadingHeight: 160,
      builder: (context, products) {
        if (products.isEmpty) return const SizedBox.shrink();
        final visible = products.take(_productLimit).toList();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              JbSectionHeader(
                title: 'Explorar produtos',
                count: products.length,
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      ((constraints.maxWidth + 12) / 162).floor().clamp(2, 4);
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.66,
                    children: [
                      for (final product in visible)
                        ProductCardJB(
                          product: product,
                          onTap: () =>
                              _openStore(product.establishmentId),
                        ),
                    ],
                  );
                },
              ),
              if (products.length > _productLimit)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton(
                    onPressed: () =>
                        setState(() => _productLimit += 12),
                    child: Text(
                      'Ver mais produtos (${products.length - _productLimit})',
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /* ------------------------------ Pesquisa ---------------------------- */

  List<Widget> _buildSearchSlivers() {
    final result = _searchResult;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            'Resultados para "${_query.trim()}"',
            style: TextStyle(color: context.mutedColor, fontSize: 13),
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
              message:
                  'Tente outra palavra, como "frango", "farmácia" ou "mercado".',
            ),
          )
        else ...[
          if (result.products.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    JbSectionHeader(
                      title: 'Produtos',
                      count: result.products.length,
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            ((constraints.maxWidth + 12) / 162)
                                .floor()
                                .clamp(2, 4);
                        return GridView.count(
                          crossAxisCount: columns,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.66,
                          children: [
                            for (final product in result.products)
                              ProductCardJB(
                                product: product,
                                onTap: () =>
                                    _openStore(product.establishmentId),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          if (result.establishments.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    JbSectionHeader(
                      title: 'Estabelecimentos',
                      count: result.establishments.length,
                    ),
                    for (final establishment in result.establishments)
                      StoreRow(
                        establishment: establishment,
                        onTap: () => _openStore(establishment.id),
                        isFavorite: AppScope.of(
                          context,
                        ).isFavoriteEstablishment(establishment.id),
                        onFavoriteToggle: () =>
                            toggleFavorite(context, establishment.id),
                      ),
                  ],
                ),
              ),
            ),
        ],
    ];
  }
}

/// Botão de entrada na Home (convidado): pílula vermelha "Entrar" ou
/// pílula com contorno "Criar conta", altura confortável ao toque.
class _HeroAuthButton extends StatelessWidget {
  const _HeroAuthButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? AppColors.primary : AppColors.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: primary
            ? BorderSide.none
            : const BorderSide(color: AppColors.darkBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
