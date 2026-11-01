import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/admin/admin_audit_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_orders_screen.dart';
import 'screens/admin/admin_partners_screen.dart';
import 'screens/admin/admin_users_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/customer/account_screen.dart';
import 'screens/customer/cart_screen.dart';
import 'screens/customer/categories_screen.dart';
import 'screens/customer/checkout_screen.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/customer/orders_screen.dart';
import 'screens/customer/store_screen.dart';
import 'screens/customer/tracking_screen.dart';
import 'screens/delivery/delivery_screen.dart';
import 'screens/partner/partner_dashboard_screen.dart';
import 'screens/partner/partner_orders_screen.dart';
import 'screens/partner/partner_products_screen.dart';
import 'screens/partner/partner_profile_screen.dart';
import 'screens/shell.dart';
import 'screens/splash_screen.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

class NacalaDeliveryApp extends StatefulWidget {
  const NacalaDeliveryApp({super.key, required this.state});

  final AppState state;

  @override
  State<NacalaDeliveryApp> createState() => _NacalaDeliveryAppState();
}

class _NacalaDeliveryAppState extends State<NacalaDeliveryApp> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await Future.wait([
      widget.state.bootstrap(),
      Future<void>.delayed(const Duration(milliseconds: 850)),
    ]);
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
      ),
      child: AppScope(
        state: widget.state,
        child: MaterialApp(
          title: 'Nacala Delivery',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          // A identidade visual é definida para o tema claro (referências).
          // O tema escuro continua disponível em `AppTheme.dark()` para uma
          // futura preferência do utilizador, mas não é aplicado
          // automaticamente pelo sistema.
          themeMode: ThemeMode.light,
          home: _RootGate(ready: _ready),
          onGenerateRoute: _generateRoute,
          onUnknownRoute: (settings) => MaterialPageRoute(
            settings: settings,
            builder: (_) => const SplashScreen(),
          ),
        ),
      ),
    );
  }
}

class _RootGate extends StatefulWidget {
  const _RootGate({required this.ready});

  final bool ready;

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  bool _showLogin = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final Widget child;
    if (!widget.ready || state.status == SessionStatus.loading) {
      child = const SplashScreen(key: ValueKey('splash'));
    } else if (state.isSignedIn) {
      child = const AppShell(key: ValueKey('shell'));
    } else if (state.isGuest) {
      child = const AppShell(key: ValueKey('guest-shell'));
    } else if (_showLogin) {
      child = LoginScreen(
        key: const ValueKey('login'),
        onBack: () => setState(() => _showLogin = false),
      );
    } else {
      child = WelcomeScreen(
        key: const ValueKey('welcome'),
        onSignIn: () => setState(() => _showLogin = true),
        onGuest: () async => state.enterGuestMode(),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: child,
    );
  }
}

Route<dynamic>? _generateRoute(RouteSettings settings) {
  Widget? page;
  switch (settings.name) {
    case '/splash':
      page = const SplashScreen();
    case '/login':
      page = const LoginScreen();
    case '/register':
      page = const RegisterScreen();
    case '/home':
      page = const CustomerHomeScreen();
    case '/categories':
      page = const CategoriesScreen();
    case '/store':
      final id = settings.arguments;
      if (id is String && id.isNotEmpty) {
        page = StoreScreen(establishmentId: id);
      }
    case '/cart':
      page = const CartScreen();
    case '/checkout':
      page = const CheckoutScreen();
    case '/tracking':
      final id = settings.arguments;
      if (id is String && id.isNotEmpty) {
        page = TrackingScreen(orderId: id);
      }
    case '/orders':
      page = const OrdersScreen();
    case '/account':
      page = const AccountScreen();
    case '/partner':
      page = const PartnerDashboardScreen();
    case '/partner/orders':
      page = const PartnerOrdersScreen();
    case '/partner/products':
      page = const PartnerProductsScreen();
    case '/partner/profile':
      page = const PartnerProfileScreen();
    case '/delivery':
      page = const DeliveryScreen();
    case '/admin':
      page = const AdminDashboardScreen();
    case '/admin/partners':
      page = const AdminPartnersScreen();
    case '/admin/users':
      page = const AdminUsersScreen();
    case '/admin/orders':
      page = const AdminOrdersScreen();
    case '/admin/audit':
      page = const AdminAuditScreen();
  }
  if (page == null) return null;
  return MaterialPageRoute(settings: settings, builder: (_) => page!);
}
