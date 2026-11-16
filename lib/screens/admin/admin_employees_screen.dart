import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/jb.dart';

/// **Funcionários** (FASE 10) — gestão de contas de funcionário.
///
/// Só o administrador cria/edita/desativa/elimina funcionários, definindo
/// nível (`staff`/`gestor`) e permissões (`orders`, `products`, …). As
/// permissões são validadas **no servidor** em cada rota
/// (`requirePermission`); aqui servem para montar o painel do funcionário.
class AdminEmployeesScreen extends StatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  State<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen> {
  bool _initialized = false;
  Future<List<AdminEmployee>>? _future;
  String? _busyId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _future = _load();
  }

  Future<List<AdminEmployee>> _load() =>
      AppScope.of(context).api.adminEmployees();

  void _reload() {
    final future = _load();
    setState(() {
      _future = future;
    });
  }

  // --------------------------------------------------------------- ações

  Future<void> _create() async {
    final input = await showDialog<(
      String,
      String,
      String,
      String,
      String,
      List<String>,
    )>(
      context: context,
      builder: (_) => const _EmployeeDialog(),
    );
    if (input == null || !mounted) return;
    setState(() => _busyId = 'new');
    try {
      await AppScope.of(context).api.adminCreateEmployee(
        name: input.$1,
        email: input.$2,
        phone: input.$3,
        password: input.$4,
        level: input.$5,
        permissions: input.$6,
      );
      if (!mounted) return;
      showAppSnack(
        context,
        'Funcionário criado. Já pode entrar com as permissões escolhidas.',
      );
      _reload();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _edit(AdminEmployee employee) async {
    final input = await showDialog<(
      String,
      String,
      String,
      String,
      List<String>,
    )>(
      context: context,
      builder: (_) => _EmployeeDialog(employee: employee),
    );
    if (input == null || !mounted) return;
    setState(() => _busyId = employee.id);
    try {
      await AppScope.of(context).api.adminUpdateEmployee(
        employee.id,
        level: input.$4,
        permissions: input.$5,
      );
      if (!mounted) return;
      showAppSnack(context, 'Funcionário atualizado.');
      _reload();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _toggleActive(AdminEmployee employee) async {
    if (!employee.isActive) {
      // Reativar é direto.
      setState(() => _busyId = employee.id);
      try {
        await AppScope.of(context).api.adminUpdateEmployee(
          employee.id,
          isActive: true,
        );
        if (!mounted) return;
        showAppSnack(context, 'Conta reativada.');
        _reload();
      } on ApiException catch (error) {
        if (mounted) showAppSnack(context, error.message, error: true);
      } finally {
        if (mounted) setState(() => _busyId = null);
      }
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Desativar funcionário',
      message:
          '${employee.name} deixa de entrar na plataforma e a sessão aberta '
          'é terminada.',
      confirmLabel: 'Desativar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busyId = employee.id);
    try {
      await AppScope.of(context).api.adminUpdateEmployee(
        employee.id,
        isActive: false,
      );
      if (!mounted) return;
      showAppSnack(context, 'Conta desativada.');
      _reload();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _remove(AdminEmployee employee) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar funcionário',
      message:
          'A conta de ${employee.name} e a linha de funcionário são '
          'removidas em definitivo.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busyId = employee.id);
    try {
      await AppScope.of(context).api.adminDeleteEmployee(employee.id);
      if (!mounted) return;
      showAppSnack(context, 'Funcionário eliminado.');
      _reload();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            JbPageHeader(
              title: 'Funcionários',
              subtitle: 'Contas internas com nível e permissões.',
              onBack: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).maybePop()
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Atualizar',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  IconButton(
                    tooltip: 'Novo funcionário',
                    onPressed: _busyId == null ? _create : null,
                    icon: const Icon(Icons.person_add_alt_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _reload(),
                child: AsyncSection<List<AdminEmployee>>(
                  future: _future,
                  onRetry: _reload,
                  builder: (context, employees) {
                    if (employees.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        children: const [
                          EmptyState(
                            icon: Icons.badge_outlined,
                            title: 'Sem funcionários',
                            message:
                                'Crie contas internas para delegar tarefas do '
                                'painel de administração.',
                          ),
                        ],
                      );
                    }
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      children: [
                        for (final employee in employees)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _EmployeeCard(
                              employee: employee,
                              busy: _busyId == employee.id,
                              onEdit: () => _edit(employee),
                              onToggle: () => _toggleActive(employee),
                              onDelete: () => _remove(employee),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.busy,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final AdminEmployee employee;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: employee.isActive
                      ? AppColors.primarySoft
                      : AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.badge_outlined,
                  color: employee.isActive
                      ? context.accentColor
                      : context.dangerColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${employee.email} · ${employee.phone}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.mutedColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Badge(
                label: employee.levelLabel,
                color: employee.level == 'admin'
                    ? context.accentColor
                    : context.mutedColor,
                soft: AppColors.primarySoft,
              ),
              const SizedBox(width: 6),
              _Badge(
                label: employee.isActive ? 'Ativo' : 'Inativo',
                color: employee.isActive
                    ? context.successColor
                    : context.dangerColor,
                soft: employee.isActive
                    ? AppColors.successSoft
                    : AppColors.dangerSoft,
              ),
            ],
          ),
          if (employee.permissions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final permission in employee.permissions)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: context.lineColor),
                    ),
                    child: Text(
                      employeePermissionLabels[permission] ?? permission,
                      style: TextStyle(color: context.mutedColor, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ],
          if (busy) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ] else ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Editar'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                TextButton.icon(
                  onPressed: onToggle,
                  icon: Icon(
                    employee.isActive
                        ? Icons.block_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 15,
                  ),
                  label: Text(employee.isActive ? 'Desativar' : 'Reativar'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: employee.isActive
                        ? context.dangerColor
                        : context.successColor,
                  ),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 15,
                  ),
                  label: const Text('Eliminar'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: context.dangerColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.soft,
  });

  final String label;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Dialogo de criação/edição de funcionário. O `employee == null` é
/// criação (mostra a palavra-passe); caso contrário edita nível,
/// permissões e estado. O controller pertence ao estado do dialogo e só é
/// libertado no `dispose` (depois da animação de saída).
class _EmployeeDialog extends StatefulWidget {
  const _EmployeeDialog({this.employee});

  final AdminEmployee? employee;

  @override
  State<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<_EmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _password;
  late String _level;
  late final Set<String> _permissions;

  bool get _isEdit => widget.employee != null;

  @override
  void initState() {
    super.initState();
    final employee = widget.employee;
    _name = TextEditingController(text: employee?.name ?? '');
    _email = TextEditingController(text: employee?.email ?? '');
    _phone = TextEditingController(text: employee?.phone ?? '');
    _password = TextEditingController();
    _level = employee?.level ?? 'staff';
    _permissions = {...?employee?.permissions};
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isEdit) {
      Navigator.of(context).pop((
        _name.text.trim(),
        _email.text.trim(),
        _phone.text.trim(),
        _level,
        _permissions.toList()..sort(),
      ));
    } else {
      Navigator.of(context).pop((
        _name.text.trim(),
        _email.text.trim(),
        _phone.text.trim(),
        _password.text,
        _level,
        _permissions.toList()..sort(),
      ));
    }
  }

  String? _passwordValidator(String? value) {
    final text = value ?? '';
    final hasLetter = text.contains(RegExp(r'[A-Za-z]'));
    final hasDigit = text.contains(RegExp(r'[0-9]'));
    if (text.length < 8 || !hasLetter || !hasDigit) {
      return 'Mín. 8 caracteres, com letra e número.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Editar funcionário' : 'Novo funcionário'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Nome completo'),
                  validator: (value) =>
                      (value == null || value.trim().length < 2)
                      ? 'Indique o nome.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    return !text.contains('@') || !text.contains('.')
                        ? 'E-mail inválido.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telemóvel'),
                  validator: (value) {
                    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                    return digits.length < 9 ? 'Telemóvel inválido.' : null;
                  },
                ),
                if (!_isEdit) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Palavra-passe',
                      helperText: 'Mín. 8 caracteres, com letra e número.',
                      helperMaxLines: 2,
                    ),
                    validator: _passwordValidator,
                  ),
                ],
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _level,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Nível'),
                  items: const [
                    DropdownMenuItem(value: 'staff', child: Text('Staff')),
                    DropdownMenuItem(value: 'admin', child: Text('Gestor')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _level = value);
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'Permissões',
                  style: TextStyle(
                    color: context.mutedColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final entry in employeePermissionLabels.entries)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(entry.value, style: const TextStyle(fontSize: 13)),
                    value: _permissions.contains(entry.key),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _permissions.add(entry.key);
                        } else {
                          _permissions.remove(entry.key);
                        }
                      });
                    },
                  ),
                if (_permissions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Sem permissões o funcionário só vê a conta.',
                      style: TextStyle(color: context.warningColor, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _confirm,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: Text(_isEdit ? 'Guardar' : 'Criar funcionário'),
        ),
      ],
    );
  }
}
