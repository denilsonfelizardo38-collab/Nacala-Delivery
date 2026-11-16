import 'package:flutter/material.dart';

import '../screens/admin/admin_audit_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_employees_screen.dart';
import '../screens/admin/admin_orders_screen.dart';
import '../screens/admin/admin_partners_screen.dart';
import '../screens/admin/admin_registos_screen.dart';
import '../screens/admin/admin_users_screen.dart';
import '../screens/auth/application_status_screen.dart';
import '../screens/chat/chat_list_screen.dart';
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

  /// Tabs já visitadas: ficam montadas (guardando scroll/filtros) mas as
  /// restantes só são construídas na primeira visita.
  final Set<int> _openedTabs = {0};
  Object? _tabsOwner;

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
    // Candidatura ainda por aprovar: o servidor bloqueia o painel
    // (`requireApprovedRole`), por isso mostra-se o estado da candidatura
    // em vez de um painel que devolveria 403 em toda a parte.
    if (role.isPendingApproval) {
      return const [
        _Destination(
          'Candidatura',
          Icons.how_to_reg_outlined,
          Icons.how_to_reg_rounded,
          ApplicationStatusScreen(),
        ),
        _Destination(
          'Conta',
          Icons.person_outline_rounded,
          Icons.person_rounded,
          AccountScreen(),
        ),
      ];
    }
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
          'Mensagens',
          Icons.message_outlined,
          Icons.message_rounded,
          ChatListScreen(),
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
          'Mensagens',
          Icons.message_outlined,
          Icons.message_rounded,
          ChatListScreen(),
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
          'Registos',
          Icons.how_to_reg_outlined,
          Icons.how_to_reg_rounded,
          AdminRegistosScreen(),
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
          'Funcionários',
          Icons.badge_outlined,
          Icons.badge_rounded,
          AdminEmployeesScreen(),
        ),
        _Destination(
          'Auditoria',
          Icons.history_rounded,
          Icons.history_rounded,
          AdminAuditScreen(),
        ),
      ];
    }
    // Funcionário: só vê os separadores correspondentes às permissões da
    // conta (`employees.permissions`). O servidor continua a validar cada
    // rota — aqui é apenas filtragem da navegação.
    if (role.isEmployee) {
      final permissions = role.permissions.toSet();
      return [
        if (permissions.contains('orders'))
          _Destination(
            'Pedidos',
            Icons.receipt_long_outlined,
            Icons.receipt_long_rounded,
            AdminOrdersScreen(),
          ),
        if (permissions.contains('establishments'))
          _Destination(
            'Parceiros',
            Icons.storefront_outlined,
            Icons.storefront_rounded,
            AdminPartnersScreen(),
          ),
        if (permissions.contains('customers'))
          _Destination(
            'Utilizadores',
            Icons.people_outline_rounded,
            Icons.people_rounded,
            AdminUsersScreen(),
          ),
        if (permissions.contains('applications'))
          _Destination(
            'Registos',
            Icons.how_to_reg_outlined,
            Icons.how_to_reg_rounded,
            AdminRegistosScreen(),
          ),
        _Destination(
          'Conta',
          Icons.person_outline_rounded,
          Icons.person_rounded,
          AccountScreen(),
        ),
      ];
    }
    // Clientes (e convidados) usam a navegação de cliente.
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
        'Mensagens',
        Icons.message_outlined,
        Icons.message_rounded,
        ChatListScreen(),
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
    // Sem papel autenticado (convidado ou sessão terminada) a navegação é
    // sempre a de cliente — nunca um ecrã em branco.
    final destinations = role == null
        ? _guestDestinations
        : _destinationsFor(role);
    // Troca de papel (convidado → cliente → parceiro…) reinicia as tabs.
    final owner = role?.email ?? (state.isGuest ? 'guest' : 'anon');
    if (_tabsOwner != owner) {
      _tabsOwner = owner;
      _index = 0;
      _openedTabs
        ..clear()
        ..add(0);
    }
    if (_index >= destinations.length) _index = 0;

    void select(int value) => setState(() {
      _index = value;
      _openedTabs.add(value);
    });

    // Mantém as tabs já visitadas montadas: trocar de separador preserva
    // scroll, filtros e estado de carregamento; as demais só carregam na
    // primeira visita (sem 5 arranques de dados em simultâneo).
    Widget stack() => IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < destinations.length; i++)
          if (_openedTabs.contains(i))
            destinations[i].screen
          else
            const SizedBox.shrink(),
      ],
    );

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
                    onSelected: select,
                  ),
                  Expanded(child: stack()),
                ],
              ),
            );
          }
          return Scaffold(
            body: stack(),
            bottomNavigationBar: _AppBottomBar(
              destinations: destinations,
              index: _index,
              onSelected: select,
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
                onSelected: select,
              ),
              Expanded(
                child: ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: stack(),
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
                        ? Colors.black
                        : Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => onSelected(i),
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(
                          i == index
                              ? destinations[i].selectedIcon
                              : destinations[i].icon,
                          size: 20,
                          color: Colors.white,
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
      width: 260,
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.darkBorder)),
      ),
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
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            fontFamily: AppTheme.displayFontFamily,
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
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
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
                                  ? Colors.white
                                  : context.mutedColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
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

/// Barra de navegação inferior do Nacala Delivery: cápsula vermelha com o
/// item ativo num selo preto, tipografia consistente com os cartões e
/// semas discretas — o mesmo padrão estrutural da navegação flutuante
/// moderna e igualmente leve em Android de gama baixa.
class _AppBottomBar extends StatelessWidget {
  const _AppBottomBar({
    required this.destinations,
    required this.index,
    required this.onSelected,
  });

  final List<_Destination> destinations;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Center(
            // Encolhe na vertical (a barra mede a cápsula, não a tela)
            // e centra a cápsula na horizontal.
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      Expanded(
                        child: _BottomBarItem(
                          destination: destinations[i],
                          selected: i == index,
                          onTap: () => onSelected(i),
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

class _BottomBarItem extends StatelessWidget {
  const _BottomBarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final idle = Colors.white.withValues(alpha: 0.72);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 210),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: selected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 23,
                color: selected ? Colors.white : idle,
              ),
              const SizedBox(height: 2),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : idle,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
