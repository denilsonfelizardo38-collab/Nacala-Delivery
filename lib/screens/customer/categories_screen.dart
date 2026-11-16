import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../theme/app_colors.dart';

import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import '../../widgets/jb.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _initialized = false;

  Future<List<Category>>? _categoriesFuture;
  Future<List<Establishment>>? _allEstablishmentsFuture;
  Future<List<Establishment>>? _establishmentsFuture;

  String? _selectedSlug;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;
    _initialized = true;

    final api = AppScope.of(context).api;

    _categoriesFuture = api.categories();
    _allEstablishmentsFuture = api.establishments();
    _establishmentsFuture = api.establishments();
  }

  Future<void> _refresh() async {
    final api = AppScope.of(context).api;

    final categories = api.categories();
    final allEstablishments = api.establishments();
    final establishments = api.establishments(category: _selectedSlug);

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
      // Os erros são apresentados pelos respetivos AsyncSection.
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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            JbPageHeader(
              title: 'Categorias',
              trailing: Material(
                color: AppColors.darkCard,
                shape: const CircleBorder(),
                child: CartButton(color: context.inkColor),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.primary,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                  children: [
                    Text(
                      'Explore por categoria',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      'Escolha o tipo de parceiro e veja quem está disponível.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: context.mutedColor, height: 1.5),
                    ),

                    const SizedBox(height: 20),

                    AsyncSection<List<Category>>(
                      future: _categoriesFuture,
                      onRetry: _refresh,
                      builder: (context, categories) {
                        return FutureBuilder<List<Establishment>>(
                          future: _allEstablishmentsFuture,
                          builder: (context, establishmentsSnapshot) {
                            if (establishmentsSnapshot.hasError) {
                              return ErrorState(
                                message: messageForError(
                                  establishmentsSnapshot.error,
                                ),
                                onRetry: _refresh,
                              );
                            }

                            final establishments =
                                establishmentsSnapshot.data ?? [];

                            if (categories.isEmpty) {
                              return const EmptyState(
                                icon: Icons.category_outlined,
                                title: 'Sem categorias',
                                message: 'Ainda não existem categorias configuradas.',
                              );
                            }

                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = constraints.maxWidth >= 760
                                    ? 4
                                    : 2;

                                const spacing = 12.0;

                                final width =
                                    (constraints.maxWidth -
                                        spacing * (columns - 1)) /
                                    columns;

                                final visible = [
                                  for (final category in categories)
                                    if (category.establishmentCount > 0)
                                      category,
                                ];

                                if (visible.isEmpty) {
                                  return const EmptyState(
                                    icon: Icons.category_outlined,
                                    title: 'Sem categorias com parceiros',
                                    message:
                                        'Ainda não há estabelecimentos disponíveis. '
                                        'As categorias aparecem quando um parceiro é aprovado.',
                                  );
                                }

                                return Wrap(
                                  spacing: spacing,
                                  runSpacing: spacing,
                                  children: [
                                    for (final category in visible)
                                      SizedBox(
                                        width: width,
                                        child: _CategoryCard(
                                          category: category,
                                          imageUrl: _imageFor(
                                            category,
                                            establishments,
                                          ),
                                          selected:
                                              _selectedSlug == category.slug,
                                          onTap: () => _select(category),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    ),

                    JbSectionHeader(
                      title: _selectedSlug == null
                          ? 'Todos os parceiros'
                          : 'Parceiros na categoria',
                      actionLabel: _selectedSlug == null
                          ? null
                          : 'Limpar filtro',
                      onAction: _selectedSlug == null
                          ? null
                          : () {
                              setState(() {
                                _selectedSlug = null;
                                _establishmentsFuture = AppScope.of(context).api
                                    .establishments();
                              });
                            },
                    ),

                    AsyncSection<List<Establishment>>(
                      future: _establishmentsFuture,
                      onRetry: _refresh,
                      builder: (context, establishments) {
                        if (establishments.isEmpty) {
                          return const EmptyState(
                            icon: Icons.storefront_outlined,
                            title: 'Sem parceiros',
                            message: 'Não há estabelecimentos aprovados nesta categoria.',
                          );
                        }

                        return Column(
                          children: [
                            for (final establishment in establishments)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: StoreRow(
                                  establishment: establishment,
                                  isFavorite: AppScope.of(
                                    context,
                                  ).isFavoriteEstablishment(establishment.id),
                                  onFavoriteToggle: () =>
                                      toggleFavorite(context, establishment.id),
                                  onTap: () => Navigator.of(context).pushNamed(
                                    '/store',
                                    arguments: establishment.id,
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
          ],
        ),
      ),
    );
  }

  String? _imageFor(Category category, List<Establishment> establishments) {
    if (category.imageUrl != null && category.imageUrl!.isNotEmpty) {
      return category.imageUrl;
    }
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

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.imageUrl,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final String? imageUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: selected ? AppColors.primarySoft : null,
      borderColor: selected ? AppColors.primary : null,
      padding: const EdgeInsets.all(9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            height: 105,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CoverImage(
                    imageUrl: imageUrl,
                    logicalWidth: 340,
                    fallback: _imageFallback(),
                  ),

                  if (imageUrl != null)
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0x70000000), Colors.transparent],
                        ),
                      ),
                    ),

                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${category.establishmentCount}',
                          style: TextStyle(
                            color: context.accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (selected)
                    const Positioned(
                      top: 7,
                      right: 7,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.textOrange,
                        child: Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          Text(
            category.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.textOrange : null,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            '${category.establishmentCount} '
            '${plural(category.establishmentCount, 'parceiro')}',
            style: TextStyle(color: context.mutedColor, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _imageFallback() {
    return BrandedCover(categorySlug: category.slug, iconSize: 38);
  }
}
