import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_theme.dart';
import '../../widgets/address_dialog.dart';
import '../../widgets/common.dart';
import '../../widgets/password_dialog.dart';

const Color _orange = Color(0xFFFF6B00);
const Color _orangeLight = Color(0xFFFFF0E5);
const Color _black = Color(0xFF171717);
const Color _white = Color(0xFFFFFFFF);

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
      if (mounted) {
        showAppSnack(context, error.message, error: true);
      }
    }
  }

  Future<void> _editProfile() async {
    final state = AppScope.of(context);
    final user = state.user;
    if (user == null) return;

    final input = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _ProfileDialog(
        name: user.name,
        phone: user.phone,
      ),
    );

    if (input == null) return;

    try {
      await state.updateProfile(
        name: input.$1,
        phone: digitsOnly(input.$2),
      );

      if (mounted) {
        showAppSnack(context, 'Perfil atualizado.');
      }
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnack(context, error.message, error: true);
      }
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

      if (mounted) {
        showAppSnack(context, 'Palavra-passe alterada.');
      }
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnack(context, error.message, error: true);
      }
    }
  }

  Future<void> _addAddress() async {
    final state = AppScope.of(context);
    final input = await showAddressDialog(context);

    if (input == null) return;

    try {
      await state.addAddress(
        label: input.label,
        line: input.line,
        reference: input.reference,
        isDefault: input.isDefault,
        latitude: input.latitude,
        longitude: input.longitude,
      );

      if (mounted) {
        showAppSnack(context, 'Morada adicionada.');
      }
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnack(context, error.message, error: true);
      }
    }
  }

  Future<void> _editAddress(Address address) async {
    final state = AppScope.of(context);
    final input = await showAddressDialog(
      context,
      initial: address,
    );

    if (input == null) return;

    try {
      await state.updateAddress(
        address.id,
        label: input.label,
        line: input.line,
        reference: input.reference,
        isDefault: input.isDefault,
        latitude: input.latitude,
        longitude: input.longitude,
      );

      if (mounted) {
        showAppSnack(context, 'Morada atualizada.');
      }
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnack(context, error.message, error: true);
      }
    }
  }

  Future<void> _deleteAddress(Address address) async {
    final state = AppScope.of(context);

    final confirmed = await showConfirmDialog(
      context,
      title: 'Remover morada',
      message: 'A morada "${address.label}" será removida da sua conta.',
      confirmLabel: 'Remover',
      destructive: true,
    );

    if (!confirmed) return;

    try {
      await state.deleteAddress(address.id);

      if (mounted) {
        showAppSnack(context, 'Morada removida.');
      }
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnack(context, error.message, error: true);
      }
    }
  }

  Future<void> _logout() async {
    final state = AppScope.of(context);

    final confirmed = await showConfirmDialog(
      context,
      title: 'Terminar sessão',
      message: 'Pretende sair da sua conta neste dispositivo?',
      confirmLabel: 'Sair',
      destructive: true,
    );

    if (confirmed) {
      await state.logout();
    }
  }

  void _leaveGuestMode() {
    AppScope.of(context).exitGuestMode();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.user;

    if (user == null) {
      if (state.isGuest) {
        return _buildGuestView(context);
      }

      return const Scaffold(
        body: Center(child: LoadingBlock()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('A minha conta'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: _orange,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
            children: [
              _ProfileHeader(
                name: user.name,
                email: user.email,
                phone: user.phone,
                roleLabel: user.roleLabel,
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.edit_outlined,
                      label: 'Editar perfil',
                      onTap: _editProfile,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.lock_outline_rounded,
                      label: 'Palavra-passe',
                      onTap: _changePassword,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              SectionTitle(
                title: 'As minhas moradas',
                subtitle: 'Locais guardados para as entregas',
                actionLabel: 'Adicionar',
                onAction: _addAddress,
              ),

              const SizedBox(height: 12),

              if (state.addresses.isEmpty)
                EmptyState(
                  icon: Icons.location_off_outlined,
                  title: 'Ainda não tens moradas',
                  message:
                      'Adiciona uma morada para facilitar os próximos pedidos.',
                  actionLabel: 'Adicionar morada',
                  onAction: _addAddress,
                )
              else
                for (final address in state.addresses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AddressCard(
                      address: address,
                      onEdit: () => _editAddress(address),
                      onDelete: () => _deleteAddress(address),
                    ),
                  ),

              const SizedBox(height: 22),

              const SectionTitle(title: 'Aplicação'),

              const SizedBox(height: 12),

              _AppInfoCard(apiBaseUrl: state.apiBaseUrl),

              const SizedBox(height: 24),

              OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Terminar sessão'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _orange,
                  side: const BorderSide(color: _orange),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: Text(
                  'NACALA DELIVERY',
                  style: TextStyle(
                    color: context.mutedColor.withValues(alpha: 0.65),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuestView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('A tua conta'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AppCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: _orangeLight,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: _orange,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Estás a explorar como convidado',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Podes descobrir lojas e produtos. Para fazer pedidos '
                    'e acompanhar entregas, entra ou cria uma conta.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.mutedColor,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _leaveGuestMode,
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Entrar ou criar conta'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _orange,
                        foregroundColor: _white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.phone,
    required this.roleLabel,
  });

  final String name;
  final String email;
  final String phone;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          UserAvatar(name: name, size: 62),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.mutedColor,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _orangeLight,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        roleLabel,
                        style: const TextStyle(
                          color: _orange,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      phone,
                      style: TextStyle(
                        color: context.mutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: _black,
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        side: BorderSide(color: context.lineColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
  });

  final Address address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isWork = address.label.toLowerCase().contains('trabalho');

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _orangeLight,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              isWork ? Icons.work_outline_rounded : Icons.home_outlined,
              color: _orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 7,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      address.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (address.isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _orangeLight,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'PREDEFINIDA',
                          style: TextStyle(
                            color: _orange,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  address.fullLine,
                  style: TextStyle(
                    color: context.mutedColor,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opções da morada',
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Editar'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Remover'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppInfoCard extends StatelessWidget {
  const _AppInfoCard({required this.apiBaseUrl});

  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _orangeLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.dns_outlined,
                color: _orange,
                size: 19,
              ),
            ),
            title: const Text(
              'Servidor da API',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              apiBaseUrl,
              style: TextStyle(
                color: context.mutedColor,
                fontSize: 11,
              ),
            ),
          ),
          Divider(height: 1, color: context.lineColor),
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: context.mutedColor,
                size: 19,
              ),
            ),
            title: const Text(
              'Versão da aplicação',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: const Text(
              appVersion,
              style: TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({
    required this.name,
    required this.phone,
  });

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
              decoration: const InputDecoration(
                labelText: 'Nome',
              ),
              validator: (value) =>
                  (value == null || value.trim().length < 2)
                      ? 'Indique o seu nome.'
                      : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telemóvel',
              ),
              validator: (value) =>
                  RegExp(r'^8[2-7][0-9]{7}$').hasMatch(
                    digitsOnly(value ?? ''),
                  )
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
            if (!(_formKey.currentState?.validate() ?? false)) {
              return;
            }

            Navigator.of(context).pop(
              (_name.text.trim(), _phone.text.trim()),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: _orange,
            foregroundColor: _white,
            minimumSize: const Size(0, 44),
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}