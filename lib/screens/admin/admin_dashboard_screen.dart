import 'package:flutter/material.dart';

import '../../data/api_service.dart';
import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/password_dialog.dart';
import 'admin_audit_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_partners_screen.dart';
import 'admin_users_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _initialized = false;
  Future<(AdminSummary, List<Category>)>? _future;
  String? _busyId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _load();
  }

  void _load() {
    final api = AppScope.of(context).api;
    setState(() {
      _future = _fetch(api);
    });
  }

  Future<(AdminSummary, List<Category>)> _fetch(NacalaApi api) async {
    final results = await Future.wait<Object>([
      api.adminSummary() as Future<Object>,
      api.categories() as Future<Object>,
    ]);
    return (results[0] as AdminSummary, results[1] as List<Category>);
  }

  Future<void> _partnerAction(Establishment establishment, bool approve) async {
    final api = AppScope.of(context).api;
    final confirmed = await showConfirmDialog(
      context,
      title: approve ? 'Aprovar parceiro' : 'Suspender parceiro',
      message: approve
          ? '${establishment.name} ficará visível para os clientes.'
          : '${establishment.name} deixará de receber pedidos.',
      confirmLabel: approve ? 'Aprovar' : 'Suspender',
      destructive: !approve,
    );
    if (!confirmed) return;
    setState(() => _busyId = establishment.id);
    try {
      await api.adminPartnerAction(
        establishment.id,
        approve ? 'approve' : 'reject',
      );
      if (!mounted) return;
      showAppSnack(
        context,
        approve ? 'Parceiro aprovado.' : 'Parceiro suspenso.',
      );
      _load();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _createCategory() async {
    if (!mounted) return;
    final api = AppScope.of(context).api;
    final name = await showTextPrompt(
      context,
      title: 'Nova categoria',
      label: 'Nome',
      hint: 'Ex.: Padaria',
      confirmLabel: 'Continuar',
    );
    if (name == null || !mounted) return;
    final imageUrl = await showTextPrompt(
      context,
      title: 'Foto da categoria',
      label: 'URL da imagem',
      hint: 'https://exemplo.com/foto.jpg',
      confirmLabel: 'Criar',
      allowEmpty: true,
    );
    if (!mounted) return;
    try {
      await api.createCategory(
        name,
        imageUrl: (imageUrl ?? '').trim().isEmpty ? null : imageUrl!.trim(),
      );
      if (!mounted) return;
      showAppSnack(context, 'Categoria criada.');
      _load();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  Future<void> _deleteCategory(Category category) async {
    final api = AppScope.of(context).api;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar categoria',
      message:
          'A categoria "${category.name}" só pode ser eliminada se não tiver '
          'parceiros associados.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await api.deleteCategory(category.id);
      if (!mounted) return;
      showAppSnack(context, 'Categoria eliminada.');
      _load();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  Future<void> _changePassword() async {
    final state = AppScope.of(context);
    final input = await showPasswordDialog(context);
    if (input == null) return;
    try {
      await state.changePassword(
        currentPassword: input.$1,
        newPassword: input.$2,
      );
      if (mounted) showAppSnack(context, 'Palavra-passe alterada.');
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  Future<void> _logout() async {
    final state = AppScope.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Terminar sessão',
      message: 'Pretende sair da conta de administração?',
      confirmLabel: 'Sair',
      destructive: true,
    );
    if (confirmed) await state.logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel de administração'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Conta',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              if (value == 'password') {
                _changePassword();
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'password',
                child: Text('Alterar palavra-passe'),
              ),
              PopupMenuItem(value: 'logout', child: Text('Terminar sessão')),
            ],
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async => _load(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              AsyncSection<(AdminSummary, List<Category>)>(
                future: _future,
                onRetry: _load,
                loadingHeight: 360,
                builder: (context, data) => _content(data.$1, data.$2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(AdminSummary summary, List<Category> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 620
                ? 3
                : 2;
            final spacing = 10.0;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            final tiles = [
              MetricTile(
                label: 'Clientes',
                value: '${summary.customers}',
                icon: Icons.people_outline_rounded,
              ),
              MetricTile(
                label: 'Parceiros ativos',
                value: '${summary.activePartners}',
                icon: Icons.storefront_rounded,
                tone: MetricTone.success,
              ),
              MetricTile(
                label: 'Estafetas',
                value: '${summary.couriers}',
                icon: Icons.delivery_dining_rounded,
              ),
              MetricTile(
                label: 'Pedidos em curso',
                value: '${summary.ordersInProgress}',
                icon: Icons.pending_actions_rounded,
                tone: summary.ordersInProgress > 0
                    ? MetricTone.warning
                    : MetricTone.primary,
              ),
              MetricTile(
                label: 'Vendas hoje',
                value: formatMoney(summary.salesTodayCents),
                icon: Icons.today_rounded,
                tone: MetricTone.success,
              ),
              MetricTile(
                label: 'Vendas totais',
                value: formatMoney(summary.salesTotalCents),
                icon: Icons.account_balance_wallet_outlined,
              ),
              MetricTile(
                label: 'Pedidos hoje',
                value: '${summary.ordersToday}',
                icon: Icons.receipt_long_rounded,
              ),
              MetricTile(
                label: 'Pedidos totais',
                value: '${summary.totalOrders}',
                icon: Icons.analytics_outlined,
              ),
            ];
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final tile in tiles) SizedBox(width: width, child: tile),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        SectionTitle(
          title: 'Aprovações pendentes',
          subtitle: summary.pendingEstablishments.isEmpty
              ? 'Nenhum parceiro à espera de aprovação'
              : '${summary.pendingEstablishments.length} parceiro(s) por aprovar',
          actionLabel: 'Ver parceiros',
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AdminPartnersScreen()),
          ),
        ),
        const SizedBox(height: 10),
        if (summary.pendingEstablishments.isEmpty)
          AppCard(
            child: Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  color: context.successColor,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Todos os parceiros registados estão aprovados.',
                    style: TextStyle(color: context.mutedColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else
          for (final establishment in summary.pendingEstablishments)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PendingPartnerCard(
                establishment: establishment,
                busy: _busyId == establishment.id,
                onApprove: () => _partnerAction(establishment, true),
                onReject: () => _partnerAction(establishment, false),
              ),
            ),
        const SizedBox(height: 24),
        SectionTitle(
          title: 'Pedidos recentes',
          subtitle: 'Últimos 10 pedidos da plataforma',
          actionLabel: 'Ver todos',
          onAction: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AdminOrdersScreen())),
        ),
        const SizedBox(height: 10),
        if (summary.recentOrders.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Sem pedidos',
            message: 'A plataforma ainda não registou pedidos.',
            compact: true,
          )
        else
          for (final order in summary.recentOrders)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AdminOrderRow(order: order),
            ),
        const SizedBox(height: 24),
        SectionTitle(
          title: 'Categorias',
          subtitle: '${categories.length} categoria(s) no catálogo',
          actionLabel: 'Adicionar',
          onAction: _createCategory,
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < categories.length; i++) ...[
                ListTile(
                  leading: NetworkThumb(
                    imageUrl: categories[i].imageUrl,
                    icon: Icons.category_outlined,
                    size: 40,
                    radius: 10,
                  ),
                  title: Text(
                    categories[i].name,
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    '${categories[i].establishmentCount} parceiro(s)',
                    style: TextStyle(color: context.mutedColor, fontSize: 11),
                  ),
                  trailing: IconButton(
                    tooltip: 'Eliminar categoria',
                    onPressed: () => _deleteCategory(categories[i]),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  ),
                ),
                if (i != categories.length - 1)
                  Divider(height: 1, color: context.lineColor),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
                ),
                icon: const Icon(Icons.people_outline_rounded, size: 18),
                label: const Text('Utilizadores'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminAuditScreen()),
                ),
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('Auditoria'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PendingPartnerCard extends StatelessWidget {
  const _PendingPartnerCard({
    required this.establishment,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final Establishment establishment;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NetworkThumb(
                imageUrl: establishment.imageUrl,
                size: 44,
                radius: 12,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      establishment.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      establishment.categoryName,
                      style: TextStyle(color: context.mutedColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InfoRow(
            icon: Icons.location_on_outlined,
            text: establishment.address,
          ),
          InfoRow(icon: Icons.phone_outlined, text: establishment.phone),
          const SizedBox(height: 8),
          if (busy)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onApprove,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      backgroundColor: AppColors.success,
                    ),
                    child: const Text('Aprovar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: context.dangerColor,
                      side: BorderSide(color: context.dangerColor),
                    ),
                    child: const Text('Recusar'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AdminOrderRow extends StatelessWidget {
  const _AdminOrderRow({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.number,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.establishment.name} · '
                  '${formatDateTime(order.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.mutedColor, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(order.totalCents),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              StatusBadge(status: order.status),
            ],
          ),
        ],
      ),
    );
  }
}
