import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/address_dialog.dart';
import '../../widgets/common.dart';
import '../../widgets/password_dialog.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Future<void> _refresh() async {
    try {
      await AppScope.of(context).refreshMe();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  Future<void> _editProfile() async {
    final state = AppScope.of(context);
    final user = state.user;
    if (user == null) return;
    final input = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _ProfileDialog(name: user.name, phone: user.phone),
    );
    if (input == null) return;
    try {
      await state.updateProfile(name: input.$1, phone: digitsOnly(input.$2));
      if (mounted) showAppSnack(context, 'Perfil atualizado.');
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  Future<void> _changePassword() async {
    final input = await showPasswordDialog(context);
    if (input == null) return;
    try {
      await AppScope.of(context)
          .changePassword(currentPassword: input.$1, newPassword: input.$2);
      if (mounted) showAppSnack(context, 'Palavra-passe alterada.');
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  Future<void> _addAddress() async {
    final input = await showAddressDialog(context);
    if (input == null) return;
    try {
      await AppScope.of(context).addAddress(
        label: input.label,
        line: input.line,
        reference: input.reference,
        isDefault: input.isDefault,
        latitude: input.latitude,
        longitude: input.longitude,
      );
      if (mounted) showAppSnack(context, 'Morada adicionada.');
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  Future<void> _editAddress(Address address) async {
    final input = await showAddressDialog(context, initial: address);
    if (input == null) return;
    try {
      await AppScope.of(context).updateAddress(
        address.id,
        label: input.label,
        line: input.line,
        reference: input.reference,
        isDefault: input.isDefault,
        latitude: input.latitude,
        longitude: input.longitude,
      );
      if (mounted) showAppSnack(context, 'Morada atualizada.');
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  Future<void> _deleteAddress(Address address) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remover morada',
      message: 'A morada "${address.label}" será removida da sua conta.',
      confirmLabel: 'Remover',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await AppScope.of(context).deleteAddress(address.id);
      if (mounted) showAppSnack(context, 'Morada removida.');
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Terminar sessão',
      message: 'Pretende sair da sua conta neste dispositivo?',
      confirmLabel: 'Sair',
      destructive: true,
    );
    if (confirmed) await AppScope.of(context).logout();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('A sua conta')),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              AppCard(
                child: Row(
                  children: [
                    UserAvatar(name: user.name, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.email,
                            style: TextStyle(
                              color: context.mutedColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
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
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                user.phone,
                                style: TextStyle(
                                  color: context.mutedColor,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _editProfile,
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: const Text('Editar perfil'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _changePassword,
                      icon: const Icon(Icons.lock_outline_rounded, size: 17),
                      label: const Text('Palavra-passe'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SectionTitle(
                title: 'Moradas',
                subtitle: 'Usadas no checkout para entregas',
                actionLabel: 'Adicionar',
                onAction: _addAddress,
              ),
              const SizedBox(height: 10),
              if (state.addresses.isEmpty)
                AppCard(
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_off_outlined,
                        color: context.mutedColor,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ainda não guardou nenhuma morada.',
                          style: TextStyle(
                            color: context.mutedColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final address in state.addresses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
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
                            child: Icon(
                              address.label.toLowerCase().contains('trabalho')
                                  ? Icons.work_outline_rounded
                                  : Icons.home_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      address.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    if (address.isDefault) ...[
                                      const SizedBox(width: 6),
                                      const Text(
                                        '· predefinida',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  address.fullLine,
                                  style: TextStyle(
                                    color: context.mutedColor,
                                    fontSize: 11,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Opções da morada',
                            onSelected: (value) {
                              if (value == 'edit') _editAddress(address);
                              if (value == 'delete') _deleteAddress(address);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Remover'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 24),
              const SectionTitle(title: 'Aplicação'),
              const SizedBox(height: 10),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.dns_outlined, size: 20),
                      title: const Text(
                        'Servidor da API',
                        style: TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        state.apiBaseUrl,
                        style: TextStyle(
                          color: context.mutedColor,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Divider(height: 1, color: context.lineColor),
                    const ListTile(
                      leading: Icon(Icons.info_outline_rounded, size: 20),
                      title: Text(
                        'Versão da aplicação',
                        style: TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        appVersion,
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Terminar sessão'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.dangerColor,
                  side: BorderSide(color: context.dangerColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({required this.name, required this.phone});

  final String name;
  final String phone;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name);
    _phone = TextEditingController(text: widget.phone);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar perfil'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: (value) => (value == null || value.trim().length < 2)
                  ? 'Indique o seu nome.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telemóvel'),
              validator: (value) =>
                  RegExp(r'^8[2-7][0-9]{7}$').hasMatch(digitsOnly(value ?? ''))
                  ? null
                  : 'Número inválido (9 dígitos).',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop((_name.text.trim(), _phone.text.trim()));
          },
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
