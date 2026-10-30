import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../models/place.dart';
import '../../state/app_scope.dart';
import '../../theme/app_theme.dart';
import '../../utils/feedback.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/place_card.dart';
import '../../widgets/promo_banner.dart';
import '../../widgets/section_heading.dart';
import 'cart_screen.dart';
import 'store_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final _searchController = TextEditingController();
  String _category = 'Todos';
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Place> get _visiblePlaces {
    final term = _search.toLowerCase();
    return mockPlaces.where((place) {
      final matchesCategory =
          _category == 'Todos' || place.category == _category;
      final matchesSearch =
          term.isEmpty ||
          place.name.toLowerCase().contains(term) ||
          place.category.toLowerCase().contains(term) ||
          place.description.toLowerCase().contains(term);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _openCart() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const CartScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final places = _visiblePlaces;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Row(
          children: [
            Icon(
              Icons.location_on_rounded,
              color: context.accentColor,
              size: 20,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ENTREGAR EM',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(
                    state.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.inkColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Notificações',
              onPressed: () => showMessage(context, 'Sem novas notificações'),
              style: IconButton.styleFrom(
                backgroundColor: context.cardColor,
                foregroundColor: context.inkColor,
                minimumSize: const Size(44, 44),
              ),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            const SizedBox(width: 8),
            CartButton(onTap: _openCart),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Olá, vizinho 👋',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'O que vamos pedir hoje?',
          style: TextStyle(color: context.mutedColor, fontSize: 13),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _search = value.trim()),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Restaurante, loja ou prato',
            prefixIcon: Icon(Icons.search_rounded, color: context.mutedColor),
            suffixIcon: _search.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar pesquisa',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _search = '');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        const PromoBanner(),
        const SizedBox(height: 25),
        const SectionHeading(title: 'Explore por categoria'),
        const SizedBox(height: 13),
        SizedBox(
          height: 91,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final filter in categoryFilters)
                CategoryChip(
                  label: filter.label,
                  icon: filter.icon,
                  selected: _category == filter.value,
                  onTap: () => setState(() => _category = filter.value),
                ),
            ],
          ),
        ),
        const SizedBox(height: 23),
        SectionHeading(
          title: _search.isEmpty ? 'Perto de si' : 'Resultados',
          trailing: '${places.length} locais',
        ),
        const SizedBox(height: 12),
        if (places.isEmpty)
          const EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Não encontrámos resultados',
            subtitle: 'Experimente outro nome ou categoria.',
          )
        else
          for (final place in places)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PlaceCard(
                place: place,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StoreScreen(place: place),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
