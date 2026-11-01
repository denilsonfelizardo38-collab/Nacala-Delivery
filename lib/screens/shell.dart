import 'package:flutter/material.dart';

import '../screens/admin/admin_audit_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_orders_screen.dart';
import '../screens/admin/admin_partners_screen.dart';
import '../screens/admin/admin_users_screen.dart';
import '../screens/customer/account_screen.dart';
import '../screens/customer/categories_screen.dart';
import '../screens/customer/customer_home_screen.dart';
import '../screens/customer/orders_screen.dart';
import '../screens/delivery/delivery_screen.dart';
import '../screens/partner/partner_dashboard_screen.dart';
import '../screens/partner/partner_orders_screen.dart';
import '../screens/partner/partner_products_screen.dart';
import '../screens/partner/partner_profile_screen.dart';
import '../models/models.dart';
import '../state/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon, this.screen);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;
}

/// Estrutura principal autenticada. No telemóvel usa barra inferior; em
/// tablet/desktop usa uma barra lateral fixa.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _guestDestinations = [
    _Destination(
      'Início',
      Icons.home_outlined,
      Icons.home_rounded,
      CustomerHomeScreen(),
    ),
    _Destination(
      'Categorias',
      Icons.grid_view_outlined,
      Icons.grid_view_rounded,
      CategoriesScreen(),
    ),
    _Destination(
      'Pedidos',
      Icons.receipt_long_outlined,
      Icons.receipt_long_rounded,
      OrdersScreen(),
    ),
    _Destination(
      'Conta',
      Icons.person_outline_rounded,
      Icons.person_rounded,
      AccountScreen(),
    ),
  ];

  List<_Destination> _destinationsFor(UserAccount role) {
    if (role.isPartner) {
      return const [
        _Destination(
          'Painel',
          Icons.space_dashboard_outlined,
          Icons.space_dashboard_rounded,
          PartnerDashboardScreen(),
        ),
        _Destination(
          'Produtos',
          Icons.inventory_2_outlined,
          Icons.inventory_2_rounded,
          PartnerProductsScreen(),
        ),
        _Destination(
          'Pedidos',
          Icons.receipt_long_outlined,
          Icons.receipt_long_rounded,
          PartnerOrdersScreen(),
        ),
        _Destination(
          'Perfil',
          Icons.storefront_outlined,
          Icons.storefront_rounded,
          PartnerProfileScreen(),
        ),
      ];
    }
    if (role.isDelivery) {
      return const [
        _Destination(
          'Entregas',
          Icons.delivery_dining_outlined,
          Icons.delivery_dining_rounded,
          DeliveryScreen(),
        ),
        _Destination(
          'Conta',
          Icons.person_outline_rounded,
          Icons.person_rounded,
          AccountScreen(),
        ),
      ];
    }
    if (role.isAdmin) {
      return const [
        _Destination(
          'Painel',
          Icons.space_dashboard_outlined,
          Icons.space_dashboard_rounded,
          AdminDashboardScreen(),
        ),
        _Destination(
          'Parceiros',
          Icons.storefront_outlined,
          Icons.storefront_rounded,
          AdminPartnersScreen(),
        ),
        _Destination(
          'Pedidos',
          Icons.receipt_long_outlined,
          Icons.receipt_long_rounded,
          AdminOrdersScreen(),
        ),
        _Destination(
          'Utilizadores',
          Icons.people_outline_rounded,
          Icons.people_rounded,
          AdminUsersScreen(),
        ),
        _Destination(
          'Auditoria',
          Icons.history_rounded,
          Icons.history_rounded,
          AdminAuditScreen(),
        ),
      ];
    }
    return const [
      _Destination(
        'Início',
        Icons.home_outlined,
        Icons.home_rounded,
        CustomerHomeScreen(),
      ),
      _Destination(
        'Categorias',
        Icons.grid_view_outlined,
        Icons.grid_view_rounded,
        CategoriesScreen(),
      ),
      _Destination(
        'Pedidos',
        Icons.receipt_long_outlined,
        Icons.receipt_long_rounded,
        OrdersScreen(),
      ),
      _Destination(
        'Conta',
        Icons.person_outline_rounded,
        Icons.person_rounded,
        AccountScreen(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final role = state.user;
    if (role == null && !state.isGuest) return const SizedBox.shrink();
    final destinations = role == null
        ? _guestDestinations
        : _destinationsFor(role);
    if (_index >= destinations.length) _index = 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (!wide) {
          if (role?.isAdmin ?? false) {
            return Scaffold(
              body: Row(
                children: [
                  _AdminNavigationRail(
                    destinations: destinations,
                    index: _index,
                    onSelected: (value) => setState(() => _index = value),
                  ),
                  Expanded(child: destinations[_index].screen),
                ],
              ),
            );
          }
          return Scaffold(
            body: destinations[_index].screen,
            bottomNavigationBar: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [AppColors.cardShadow],
              ),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                destinations: [
                  for (final destination in destinations)
                    NavigationDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: destination.label,
                    ),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Sidebar(
                destinations: destinations,
                index: _index,
                onSelected: (value) => setState(() => _index = value),
              ),
              Expanded(
                child: ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: destinations[_index].screen,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminNavigationRail extends StatelessWidget {
  const _AdminNavigationRail({
    required this.destinations,
    required this.index,
    required this.onSelected,
  });

  final List<_Destination> destinations;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      color: AppColors.primary,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: AppLogo(size: 36, onDark: true),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < destinations.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Tooltip(
                  message: destinations[i].label,
                  child: Material(
                    color: i == index
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => onSelected(i),
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(
                          i == index
                              ? destinations[i].selectedIcon
                              : destinations[i].icon,
                          size: 20,
                          color: i == index ? AppColors.primary : Colors.white,
                        ),
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

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destinations,
    required this.index,
    required this.onSelected,
  });

  final List<_Destination> destinations;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.user;
    return Container(
      width: 252,
      color: context.cardColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Row(
                children: [
                  const AppLogo(size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nacala Delivery',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          user?.roleLabel ?? '',
                          style: TextStyle(
                            color: context.mutedColor,
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
            Divider(color: context.lineColor),
            const SizedBox(height: 8),
            for (var i = 0; i < destinations.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3,
                ),
                child: Material(
                  color: i == index ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelected(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            i == index
                                ? destinations[i].selectedIcon
                                : destinations[i].icon,
                            size: 20,
                            color: i == index
                                ? Theme.of(context).colorScheme.onPrimary
                                : context.mutedColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            destinations[i].label,
                            style: TextStyle(
                              color: i == index
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : context.inkColor,
                              fontSize: 13,
                              fontWeight: i == index
                                  ? FontWeight.w600
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            Divider(color: context.lineColor),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  UserAvatar(name: user?.name ?? '?', size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          user?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.mutedColor,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Terminar sessão',
                    onPressed: () async {
                      final confirmed = await showConfirmDialog(
                        context,
                        title: 'Terminar sessão',
                        message: 'Pretende sair da sua conta?',
                        confirmLabel: 'Sair',
                        destructive: true,
                      );
                      if (confirmed) await state.logout();
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
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
