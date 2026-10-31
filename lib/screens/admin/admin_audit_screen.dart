import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class AdminAuditScreen extends StatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  State<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends State<AdminAuditScreen> {
  bool _initialized = false;
  Future<List<AuditLog>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _future = AppScope.of(context).api.adminAudit();
  }

  void _reload() {
    setState(() {
      _future = AppScope.of(context).api.adminAudit();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditoria'),
        actions: [
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
              Text(
                'Registo de ações administrativas e de negócio. '
                'Os registos são apenas de leitura.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: context.mutedColor),
              ),
              const SizedBox(height: 14),
              AsyncSection<List<AuditLog>>(
                future: _future,
                onRetry: _reload,
                builder: (context, logs) {
                  if (logs.isEmpty) {
                    return const EmptyState(
                      icon: Icons.history_rounded,
                      title: 'Sem registos',
                      message: 'Ainda não há ações registadas.',
                    );
                  }
                  return Column(
                    children: [
                      for (final log in logs)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _AuditTile(log: log),
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

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.log});

  final AuditLog log;

  static String _label(String action) => switch (action) {
    'login' => 'Início de sessão',
    'logout' => 'Fim de sessão',
    'register' => 'Novo registo',
    'order.created' => 'Pedido criado',
    'order.accept' => 'Pedido aceite',
    'order.reject' => 'Pedido rejeitado',
    'order.preparing' => 'Preparação iniciada',
    'order.ready' => 'Pedido pronto',
    'order.cancelled' => 'Pedido cancelado',
    'order.delivered' => 'Pedido entregue',
    'order.reviewed' => 'Pedido avaliado',
    'delivery.accepted' => 'Entrega aceite',
    'delivery.declined' => 'Entrega recusada',
    'delivery.completed' => 'Entrega concluída',
    'partner.approved' => 'Parceiro aprovado',
    'partner.rejected' => 'Parceiro suspenso',
    'user.role_changed' => 'Papel alterado',
    'user.activation_changed' => 'Estado da conta alterado',
    'category.created' => 'Categoria criada',
    'category.updated' => 'Categoria atualizada',
    'category.deleted' => 'Categoria eliminada',
    _ => action,
  };

  static IconData _icon(String action) {
    if (action.startsWith('order')) return Icons.receipt_long_rounded;
    if (action.startsWith('delivery')) return Icons.delivery_dining_rounded;
    if (action.startsWith('partner')) return Icons.storefront_rounded;
    if (action.startsWith('user')) return Icons.people_rounded;
    if (action.startsWith('category')) return Icons.category_rounded;
    return Icons.history_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon(log.action), size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label(log.action),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${log.actor ?? 'Sistema'} · ${log.entity}'
                  '${log.entityId == null ? '' : ' ${log.entityId!.substring(0, log.entityId!.length.clamp(0, 8))}'}',
                  style: TextStyle(color: context.mutedColor, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatDateTime(log.createdAt),
            style: TextStyle(color: context.mutedColor, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
