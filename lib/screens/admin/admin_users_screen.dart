import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _initialized = false;
  String? _role;
  Future<List<AdminUser>>? _future;
  final _search = TextEditingController();
  String _query = '';
  String? _busyId;

  static const _roles = [
    (null, 'Todos'),
    ('customer', 'Clientes'),
    ('partner', 'Parceiros'),
    ('delivery', 'Estafetas'),
    ('admin', 'Admins'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _future = AppScope.of(context).api.adminUsers();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = AppScope.of(context).api.adminUsers(role: _role);
    });
  }

  void _selectRole(String? role) {
    if (_role == role) return;
    setState(() {
      _role = role;
      _future = AppScope.of(context).api.adminUsers(role: role);
    });
  }

  Future<void> _changeRole(AdminUser user, String role) async {
    final api = AppScope.of(context).api;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Alterar papel',
      message:
          '${user.name} passará a ter o papel de ${_roleLabel(role)}. '
          'A sessão atual do utilizador será terminada.',
      confirmLabel: 'Alterar',
    );
    if (!confirmed) return;
    setState(() => _busyId = user.id);
    try {
      await api.adminUpdateUser(user.id, role: role);
      if (!mounted) return;
      showAppSnack(context, 'Papel atualizado.');
      _reload();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _toggleActive(AdminUser user, bool active) async {
    setState(() => _busyId = user.id);
    try {
      await AppScope.of(context).api.adminUpdateUser(user.id, isActive: active);
      if (!mounted) return;
      showAppSnack(context, active ? 'Conta ativada.' : 'Conta desativada.');
      _reload();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  static String _roleLabel(String role) => switch (role) {
    'customer' => 'Cliente',
    'partner' => 'Parceiro',
    'delivery' => 'Estafeta',
    'admin' => 'Administrador',
    _ => role,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Utilizadores'),
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
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _roles.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final entry = _roles[index];
                    final selected = _role == entry.$1;
                    return _RoleChip(
                      label: entry.$2,
                      selected: selected,
                      onTap: () => _selectRole(entry.$1),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SearchField(
                controller: _search,
                hintText: 'Pesquisar por nome, email ou telemóvel',
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
              const SizedBox(height: 14),
              AsyncSection<List<AdminUser>>(
                future: _future,
                onRetry: _reload,
                builder: (context, users) {
                  final query = _query.toLowerCase();
                  final filtered = query.isEmpty
                      ? users
                      : users
                            .where(
                              (user) =>
                                  user.name.toLowerCase().contains(query) ||
                                  user.email.toLowerCase().contains(query) ||
                                  user.phone.contains(query),
                            )
                            .toList();
                  if (users.isEmpty) {
                    return const EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'Sem utilizadores',
                      message: 'Não há contas neste filtro.',
                    );
                  }
                  if (filtered.isEmpty) {
                    return const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Sem resultados',
                      message: 'Nenhuma conta corresponde à pesquisa.',
                      compact: true,
                    );
                  }
                  return Column(
                    children: [
                      for (final user in filtered)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _UserCard(
                            user: user,
                            busy: _busyId == user.id,
                            onRole: (role) => _changeRole(user, role),
                            onActive: (active) => _toggleActive(user, active),
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

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : context.cardColor,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary : context.lineColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : context.inkColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.busy,
    required this.onRole,
    required this.onActive,
  });

  final AdminUser user;
  final bool busy;
  final ValueChanged<String> onRole;
  final ValueChanged<bool> onActive;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              UserAvatar(name: user.name, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user.roleLabel,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.mutedColor, fontSize: 11),
                    ),
                    Text(
                      '${user.phone} · desde ${formatDate(user.createdAt)}',
                      style: TextStyle(color: context.mutedColor, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          if (busy)
            const SizedBox(
              height: 24,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Row(
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Alterar papel',
                  onSelected: onRole,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'customer', child: Text('Cliente')),
                    PopupMenuItem(value: 'partner', child: Text('Parceiro')),
                    PopupMenuItem(value: 'delivery', child: Text('Estafeta')),
                    PopupMenuItem(value: 'admin', child: Text('Administrador')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.lineColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.manage_accounts_outlined,
                          size: 16,
                          color: context.mutedColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Alterar papel',
                          style: TextStyle(
                            color: context.inkColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  user.isActive ? 'Ativa' : 'Inativa',
                  style: TextStyle(
                    color: user.isActive
                        ? context.successColor
                        : context.dangerColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Switch(value: user.isActive, onChanged: onActive),
              ],
            ),
        ],
      ),
    );
  }
}
