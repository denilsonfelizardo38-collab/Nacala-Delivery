import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import 'categories_screen.dart';
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

  void _openStore(String id) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => StoreScreen(establishmentId: id)));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Olá, ${state.firstName}!',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const CartButton(),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'O que deseja pedir hoje?',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.mutedColor),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 14,
                color: context.mutedColor,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  state.defaultAddress?.fullLine ??
                      'Defina a morada de entrega no checkout',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.mutedColor, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SearchField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              hintText: 'Pesquisar lojas ou produtos',
            ),
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
            future: _establishmentsFuture,
            builder: (context, snapshot) {
              final establishments = snapshot.data;
              final featured = establishments == null || establishments.isEmpty
                  ? null
                  : establishments.first;
              return _HomeHero(
                establishment: featured,
                onTap: featured == null ? null : () => _openStore(featured.id),
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
            builder: (context, categories) =>
                FutureBuilder<List<Establishment>>(
                  future: _allEstablishmentsFuture,
                  builder: (context, establishmentsSnapshot) => SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final isAll = index == 0;
                        final category = isAll ? null : categories[index - 1];
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
                ),
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
              if (establishments.isEmpty) {
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
                  for (final establishment in establishments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _HomeStoreCard(
                        establishment: establishment,
                        onTap: () => _openStore(establishment.id),
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
                  subtitle: '${result.products.length} resultado(s)',
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
                  subtitle: '${result.establishments.length} resultado(s)',
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
                  color: selected ? AppColors.primary : AppColors.primarySoft,
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
                  color: selected ? AppColors.primary : context.inkColor,
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

class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.establishment, required this.onTap});

  final Establishment? establishment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = establishment?.imageUrl;
    return AppCard(
      padding: EdgeInsets.zero,
      radius: 18,
      onTap: onTap,
      child: SizedBox(
        height: 166,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _cityImage(),
                )
              else
                _cityImage(),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xE6001F60), Color(0x18001F60)],
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
                      establishment?.name ?? 'A cidade à sua porta.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      establishment == null
                          ? 'Descubra os parceiros de Nacala-Porto'
                          : '${establishment!.categoryName} · '
                                '${establishment!.prepMinutes} min',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    if (establishment != null)
                      const Text(
                        'Ver menu  ›',
                        style: TextStyle(
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
    );
  }

  Widget _cityImage() => Image.asset(
    'assets/images/login_bg.jpg',
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.primary),
  );
}

class _HomeStoreCard extends StatelessWidget {
  const _HomeStoreCard({required this.establishment, required this.onTap});

  final Establishment establishment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = establishment.imageUrl;
    return AppCard(
      padding: EdgeInsets.zero,
      radius: 18,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 142,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: imageUrl == null || imageUrl.isEmpty
                  ? ColoredBox(
                      color: AppColors.primarySoft,
                      child: Icon(
                        categoryIconFor(establishment.categorySlug),
                        color: AppColors.primary,
                        size: 42,
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: AppColors.primarySoft,
                        child: Icon(
                          categoryIconFor(establishment.categorySlug),
                          color: AppColors.primary,
                          size: 42,
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        establishment.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
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
                      '${formatMoney(establishment.deliveryFeeCents)} '
                      '· ${establishment.prepMinutes} min',
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
            formatMoney(product.priceCents),
            style: TextStyle(
              color: context.accentColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
