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
    _establishmentsFuture = api.establishments();
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
    final establishments = api.establishments(category: _selectedCategory);
    setState(() {
      _categoriesFuture = categories;
      _establishmentsFuture = establishments;
    });
    try {
      await Future.wait<Object>([categories, establishments]);
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
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Olá, ${state.firstName}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: context.mutedColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            state.defaultAddress?.fullLine ??
                                'Defina a morada de entrega no checkout',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.mutedColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const CartButton(),
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
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: AsyncSection<List<Category>>(
            future: _categoriesFuture,
            loadingHeight: 48,
            onRetry: _refresh,
            builder: (context, categories) {
              return SizedBox(
                height: 42,
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
                      selected: selected,
                      onTap: () =>
                          _selectCategory(isAll ? null : category!.slug),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.navy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Entregas em Nacala-Porto',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Peça nos parceiros locais e acompanhe cada etapa '
                        'do seu pedido.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.delivery_dining_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ],
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
                      child: EstablishmentTile(
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
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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
      color: selected
          ? AppColors.primary
          : (context.isDarkMode ? AppColors.darkElevated : Colors.white),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary : context.lineColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : context.inkColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
