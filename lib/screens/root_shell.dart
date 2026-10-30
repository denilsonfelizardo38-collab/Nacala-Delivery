import 'package:flutter/material.dart';

import '../models/order.dart';
import '../state/app_scope.dart';
import '../widgets/role_switcher.dart';
import 'admin/admin_dashboard.dart';
import 'customer/account_screen.dart';
import 'customer/customer_home_screen.dart';
import 'customer/orders_screen.dart';
import 'partner/partner_dashboard.dart';

/// Estrutura principal: navegação do cliente e, em modo demonstração,
/// os painéis de parceiro e administração.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  AppRole _role = AppRole.customer;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final role = state.demoMode ? _role : AppRole.customer;
    final isCustomer = role == AppRole.customer;
    final hasActiveOrders = state.orders.any(
      (order) => order.status != OrderStatus.delivered,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (state.demoMode)
              RoleSwitcher(
                selected: _role,
                onChanged: (value) => setState(() => _role = value),
              ),
            Expanded(
              child: switch (role) {
                AppRole.customer => IndexedStack(
                  index: state.tabIndex,
                  children: const [
                    CustomerHomeScreen(),
                    OrdersScreen(),
                    AccountScreen(),
                  ],
                ),
                AppRole.partner => const PartnerDashboard(),
                AppRole.admin => const AdminDashboard(),
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: isCustomer
          ? NavigationBar(
              selectedIndex: state.tabIndex,
              onDestinationSelected: state.selectTab,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Início',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: hasActiveOrders,
                    child: const Icon(Icons.receipt_long_outlined),
                  ),
                  selectedIcon: const Icon(Icons.receipt_long_rounded),
                  label: 'Pedidos',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Conta',
                ),
              ],
            )
          : null,
    );
  }
}
