import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/admin/admin_audit_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_orders_screen.dart';
import 'screens/admin/admin_partners_screen.dart';
import 'screens/admin/admin_users_screen.dart';
import 'screens/auth/application_screen.dart';
import 'screens/auth/application_status_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/recovery_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/customer/account_screen.dart';
import 'screens/customer/cart_screen.dart';
import 'screens/customer/categories_screen.dart';
import 'screens/customer/checkout_screen.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/customer/orders_screen.dart';
import 'screens/customer/notifications_screen.dart';
import 'screens/customer/store_screen.dart';
import 'screens/customer/tracking_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/delivery/delivery_screen.dart';
import 'screens/partner/partner_dashboard_screen.dart';
import 'screens/partner/partner_orders_screen.dart';
import 'screens/partner/partner_products_screen.dart';
import 'screens/partner/partner_profile_screen.dart';
import 'screens/shell.dart';
import 'screens/splash_screen.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart';
import 'widgets/offline_banner.dart';

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
      // Duração mínima do splash: a animação de marca (logo + wordmark +
      // riscos + wipe) completa em 1,85 s — largar antes corta a sequência.
      Future<void>.delayed(const Duration(milliseconds: 1850)),
    ]);
    // Sem sessão guardada (ou sessão expirada), a app arranca em modo
    // convidado: o fluxo é Splash → Home sempre, com os botões ENTRAR /
    // CRIAR CONTA para quem quiser entrar.
    if (!widget.state.isSignedIn) {
      await widget.state.enterGuestMode();
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    // A aplicação é escura por omissão e por opção: a identidade visual
    // (fundo preto, destaque vermelho) só existe no tema escuro.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.darkBg,
      ),
      child: AppScope(
        state: widget.state,
        child: MaterialApp(
          title: 'Nacala Delivery',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          // Limita a escala de texto extremas do sistema (acessibilidade)
          // para os ecrãs não partirem o layout; 1.4 continua generoso.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            final scale = mq.textScaler.scale(1);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: scale > 1.4
                    ? const TextScaler.linear(1.4)
                    : mq.textScaler,
              ),
              child: NetworkBanner(child: child ?? const SizedBox.shrink()),
            );
          },
          home: _RootGate(ready: _ready),
          onGenerateRoute: _generateRoute,
          // Rota desconhecida ou sem argumentos: nunca um beco sem saída
          // (antes caía no SplashScreen sem forma de voltar).
          onUnknownRoute: (settings) => _routeError(
            settings,
            'O ecrã pedido não existe ou não tem os '
            'dados necessários.',
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
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    // Sem sessão iniciada a app mostra a Home em modo convidado (o próprio
    // shell decide os separadores de cliente). Com sessão, o shell abre o
    // painel do papel autenticado — o tipo de conta é identificado depois
    // do login, sem passar por um "welcome" obrigatório.
    final Widget child;
    if (!widget.ready || state.status == SessionStatus.loading) {
      child = const SplashScreen(key: ValueKey('splash'));
    } else if (state.isSignedIn) {
      child = const AppShell(key: ValueKey('shell'));
    } else {
      child = const AppShell(key: ValueKey('guest-shell'));
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
    case '/recover':
      page = const RecoveryScreen();
    case '/register':
      page = const RegisterScreen();
    case '/roles':
      page = RoleSelectionScreen(
        intent: RoleSelectionScreen.intentFromArguments(settings.arguments),
      );
    case '/establishment/apply':
      page = const ApplicationScreen(kind: 'establishment');
    case '/courier/apply':
      page = const ApplicationScreen(kind: 'delivery');
    case '/application/status':
      page = const ApplicationStatusScreen();
    case '/home':
      page = const CustomerHomeScreen();
    case '/categories':
      page = const CategoriesScreen();
    case '/store':
      final id = settings.arguments;
      if (id is String && id.isNotEmpty) {
        page = StoreScreen(establishmentId: id);
      } else {
        return _routeError(
          settings,
          'Falta o identificador do estabelecimento.',
        );
      }
    case '/cart':
      page = const CartScreen();
    case '/notifications':
      page = const NotificationsScreen();
    case '/chat/list':
      page = const ChatListScreen();
    case '/chat':
      page = const ChatScreen();
    case '/checkout':
      page = const CheckoutScreen();
    case '/tracking':
      final id = settings.arguments;
      if (id is String && id.isNotEmpty) {
        page = TrackingScreen(orderId: id);
      } else {
        return _routeError(settings, 'Falta o identificador do pedido.');
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

/// Ecrã de erro para rotas desconhecidas ou argumentos inválidos: explica o
/// problema e oferece saída (voltar ou início), em vez de prender o utilizador.
Route<dynamic> _routeError(RouteSettings settings, String message) {
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (context) => Scaffold(
      appBar: AppBar(title: const Text('Ecrã indisponível')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ErrorState(message: message),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () {
                  final navigator = Navigator.of(context);
                  if (navigator.canPop()) {
                    navigator.pop();
                  } else {
                    navigator.pushNamedAndRemoveUntil('/home', (_) => false);
                  }
                },
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Voltar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
