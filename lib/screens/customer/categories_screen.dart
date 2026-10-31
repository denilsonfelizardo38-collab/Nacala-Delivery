import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import 'store_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _initialized = false;
  Future<List<Category>>? _categoriesFuture;
  Future<List<Establishment>>? _establishmentsFuture;
  String? _selectedSlug;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final api = AppScope.of(context).api;
    _categoriesFuture = api.categories();
    _establishmentsFuture = api.establishments();
  }

  Future<void> _refresh() async {
    final api = AppScope.of(context).api;
    final categories = api.categories();
    final establishments = api.establishments(category: _selectedSlug);
    setState(() {
      _categoriesFuture = categories;
      _establishmentsFuture = establishments;
    });
    try {
      await Future.wait<Object>([categories, establishments]);
    } on Exception {
      // Tratado pelo AsyncSection.
    }
  }

  void _select(Category category) {
    final slug = _selectedSlug == category.slug ? null : category.slug;
    setState(() {
      _selectedSlug = slug;
      _establishmentsFuture = AppScope.of(context).api
          .establishments(category: slug);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorias'),
        actions: const [CartButton(), SizedBox(width: 4)],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Text(
                'Explore por categoria',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Escolha o tipo de parceiro e veja quem está disponível.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: context.mutedColor),
              ),
              const SizedBox(height: 16),
              AsyncSection<List<Category>>(
                future: _categoriesFuture,
                onRetry: _refresh,
                builder: (context, categories) {
                  if (categories.isEmpty) {
                    return const EmptyState(
                      icon: Icons.category_outlined,
                      title: 'Sem categorias',
                      message: 'Ainda não existem categorias configuradas.',
                    );
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 760 ? 4 : 2;
                      final spacing = 10.0;
                      final width =
                          (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (final category in categories)
                            SizedBox(
                              width: width,
                              child: _CategoryCard(
                                category: category,
                                selected: _selectedSlug == category.slug,
                                onTap: () => _select(category),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 26),
              SectionTitle(
                title: _selectedSlug == null
                    ? 'Todos os parceiros'
                    : 'Parceiros na categoria',
                subtitle: 'Toque num estabelecimento para ver o menu',
              ),
              const SizedBox(height: 12),
              AsyncSection<List<Establishment>>(
                future: _establishmentsFuture,
                onRetry: _refresh,
                builder: (context, establishments) {
                  if (establishments.isEmpty) {
                    return const EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Sem parceiros',
                      message:
                          'Não há estabelecimentos aprovados nesta categoria.',
                    );
                  }
                  return Column(
                    children: [
                      for (final establishment in establishments)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: EstablishmentTile(
                            establishment: establishment,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => StoreScreen(
                                  establishmentId: establishment.id,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  static IconData iconFor(String icon) => switch (icon) {
    'restaurant' => Icons.restaurant_rounded,
    'basket' => Icons.shopping_basket_rounded,
    'pharmacy' => Icons.local_pharmacy_rounded,
    'store' => Icons.storefront_rounded,
    _ => Icons.category_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: selected ? AppColors.primarySoft : null,
      borderColor: selected ? AppColors.primary : null,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              iconFor(category.icon),
              size: 21,
              color: selected ? Colors.white : AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            category.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            '${category.establishmentCount} parceiro(s)',
            style: TextStyle(color: context.mutedColor, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
