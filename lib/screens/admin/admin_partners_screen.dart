import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'admin_create_partner_screen.dart';

class AdminPartnersScreen extends StatefulWidget {
  const AdminPartnersScreen({super.key});

  @override
  State<AdminPartnersScreen> createState() => _AdminPartnersScreenState();
}

class _AdminPartnersScreenState extends State<AdminPartnersScreen> {
  bool _initialized = false;
  Future<List<Establishment>>? _future;
  final _search = TextEditingController();
  String _query = '';
  String? _busyId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _future = AppScope.of(context).api.adminPartners();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = AppScope.of(context).api.adminPartners();
    });
  }

  Future<void> _createPartner() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AdminCreatePartnerScreen()),
    );
    if (created == true) _reload();
  }

  Future<void> _action(Establishment establishment, bool approve) async {
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
      _reload();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parceiros'),
        actions: [
          IconButton(
            tooltip: 'Registar parceiro',
            onPressed: _createPartner,
            icon: const Icon(Icons.add_business_rounded),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              FilledButton.icon(
                onPressed: _createPartner,
                icon: const Icon(Icons.add_business_rounded, size: 18),
                label: const Text('Registar parceiro'),
              ),
              const SizedBox(height: 14),
              SearchField(
                controller: _search,
                hintText: 'Pesquisar parceiros',
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
              const SizedBox(height: 14),
              AsyncSection<List<Establishment>>(
                future: _future,
                onRetry: _reload,
                builder: (context, partners) {
                  final filtered = _query.isEmpty
                      ? partners
                      : partners
                            .where(
                              (partner) =>
                                  partner.name.toLowerCase().contains(
                                    _query.toLowerCase(),
                                  ) ||
                                  partner.categoryName.toLowerCase().contains(
                                    _query.toLowerCase(),
                                  ),
                            )
                            .toList();
                  if (partners.isEmpty) {
                    return EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Sem parceiros',
                      message:
                          'Ainda não existem estabelecimentos registados. '
                          'Registe o primeiro parceiro para abrir o catálogo.',
                      actionLabel: 'Registar parceiro',
                      onAction: _createPartner,
                    );
                  }
                  if (filtered.isEmpty) {
                    return const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Sem resultados',
                      message: 'Nenhum parceiro corresponde à pesquisa.',
                      compact: true,
                    );
                  }
                  return Column(
                    children: [
                      for (final partner in filtered)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PartnerAdminCard(
                            partner: partner,
                            busy: _busyId == partner.id,
                            onApprove: () => _action(partner, true),
                            onSuspend: () => _action(partner, false),
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

class _PartnerAdminCard extends StatelessWidget {
  const _PartnerAdminCard({
    required this.partner,
    required this.busy,
    required this.onApprove,
    required this.onSuspend,
  });

  final Establishment partner;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onSuspend;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NetworkThumb(imageUrl: partner.imageUrl, size: 52, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            partner.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        StatusBadge(
                          status: partner.isApproved ? 'accepted' : 'pending',
                          label: partner.isApproved ? 'Aprovado' : 'Pendente',
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${partner.categoryName} · ${partner.productCount} produto(s)',
                      style: TextStyle(color: context.mutedColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InfoRow(icon: Icons.location_on_outlined, text: partner.address),
          InfoRow(icon: Icons.phone_outlined, text: partner.phone),
          InfoRow(
            icon: Icons.delivery_dining_rounded,
            text:
                'Entrega ${formatMoney(partner.deliveryFeeCents)} · '
                '${partner.prepMinutes} min',
          ),
          if (partner.isApproved)
            InfoRow(
              icon: partner.isOpen
                  ? Icons.lock_open_rounded
                  : Icons.lock_outline_rounded,
              text: partner.isOpen ? 'Aberto' : 'Fechado',
              color: partner.isOpen ? context.successColor : context.mutedColor,
            ),
          const SizedBox(height: 10),
          if (busy)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (!partner.isApproved)
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
                    onPressed: onSuspend,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: context.dangerColor,
                      side: BorderSide(color: context.dangerColor),
                    ),
                    child: const Text('Recusar'),
                  ),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: onSuspend,
              icon: const Icon(Icons.block_rounded, size: 16),
              label: const Text('Suspender'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.dangerColor,
                side: BorderSide(color: context.dangerColor),
              ),
            ),
        ],
      ),
    );
  }
}
