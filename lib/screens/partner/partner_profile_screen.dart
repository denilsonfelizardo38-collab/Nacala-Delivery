import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/password_dialog.dart';

class PartnerProfileScreen extends StatefulWidget {
  const PartnerProfileScreen({super.key});

  @override
  State<PartnerProfileScreen> createState() => _PartnerProfileScreenState();
}

class _PartnerProfileScreenState extends State<PartnerProfileScreen> {
  bool _initialized = false;
  Future<Establishment>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _future = AppScope.of(context).api.partnerEstablishment();
  }

  void _reload() {
    setState(() {
      _future = AppScope.of(context).api.partnerEstablishment();
    });
  }

  Future<void> _editEstablishment(Establishment establishment) async {
    final api = AppScope.of(context).api;
    final input = await showDialog<_EstablishmentInput>(
      context: context,
      builder: (_) => _EstablishmentDialog(establishment: establishment),
    );
    if (input == null) return;
    try {
      await api.updatePartnerEstablishment(
        description: input.description,
        phone: digitsOnly(input.phone),
        address: input.address,
        isOpen: input.isOpen,
        opensAt: input.opensAt,
        closesAt: input.closesAt,
      );
      if (!mounted) return;
      showAppSnack(context, 'Dados do estabelecimento atualizados.');
      _reload();
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
      builder: (_) => _AccountDialog(name: user.name, phone: user.phone),
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
      message: 'Pretende sair da conta do estabelecimento?',
      confirmLabel: 'Sair',
      destructive: true,
    );
    if (confirmed) await state.logout();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil do parceiro'),
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
              AsyncSection<Establishment>(
                future: _future,
                onRetry: _reload,
                loadingHeight: 280,
                builder: (context, establishment) =>
                    _establishmentCard(establishment),
              ),
              const SizedBox(height: 24),
              const SectionTitle(title: 'Conta de acesso'),
              const SizedBox(height: 10),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: UserAvatar(name: user?.name ?? '?', size: 40),
                      title: Text(
                        user?.name ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        user?.email ?? '',
                        style: TextStyle(
                          color: context.mutedColor,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Divider(height: 1, color: context.lineColor),
                    ListTile(
                      leading: const Icon(Icons.badge_outlined, size: 20),
                      title: const Text(
                        'Papel',
                        style: TextStyle(fontSize: 13),
                      ),
                      trailing: Text(
                        user?.roleLabel ?? '',
                        style: TextStyle(
                          color: context.mutedColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Divider(height: 1, color: context.lineColor),
                    ListTile(
                      leading: const Icon(Icons.phone_outlined, size: 20),
                      title: const Text(
                        'Telemóvel',
                        style: TextStyle(fontSize: 13),
                      ),
                      trailing: Text(
                        user?.phone ?? '',
                        style: TextStyle(
                          color: context.mutedColor,
                          fontSize: 12,
                        ),
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
                      label: const Text('Editar conta'),
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
              const SectionTitle(title: 'Aplicação'),
              const SizedBox(height: 10),
              AppCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.dns_outlined, size: 20),
                  title: const Text(
                    'Servidor da API',
                    style: TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    state.apiBaseUrl,
                    style: TextStyle(color: context.mutedColor, fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(height: 20),
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

  Widget _establishmentCard(Establishment establishment) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NetworkThumb(
                imageUrl: establishment.imageUrl,
                size: 64,
                radius: 16,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      establishment.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      establishment.categoryName,
                      style: TextStyle(color: context.mutedColor, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    StatusBadge(
                      status: establishment.isOpen ? 'accepted' : 'cancelled',
                      label: establishment.isOpen ? 'Aberto' : 'Fechado',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (establishment.description.isNotEmpty)
            Text(
              establishment.description,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: context.mutedColor),
            ),
          const SizedBox(height: 10),
          InfoRow(
            icon: Icons.location_on_outlined,
            text: establishment.address,
          ),
          InfoRow(icon: Icons.phone_outlined, text: establishment.phone),
          InfoRow(
            icon: Icons.schedule_rounded,
            text: 'Horário ${establishment.opensAt}–${establishment.closesAt}',
          ),
          InfoRow(
            icon: Icons.delivery_dining_rounded,
            text:
                'Taxa de entrega ${formatMoney(establishment.deliveryFeeCents)} '
                '· preparação ${establishment.prepMinutes} min',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _editEstablishment(establishment),
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: const Text('Editar estabelecimento'),
          ),
        ],
      ),
    );
  }
}

class _EstablishmentInput {
  const _EstablishmentInput({
    required this.description,
    required this.phone,
    required this.address,
    required this.isOpen,
    required this.opensAt,
    required this.closesAt,
  });

  final String description;
  final String phone;
  final String address;
  final bool isOpen;
  final String opensAt;
  final String closesAt;
}

class _EstablishmentDialog extends StatefulWidget {
  const _EstablishmentDialog({required this.establishment});

  final Establishment establishment;

  @override
  State<_EstablishmentDialog> createState() => _EstablishmentDialogState();
}

class _EstablishmentDialogState extends State<_EstablishmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _opensAt;
  late final TextEditingController _closesAt;
  late bool _isOpen;

  @override
  void initState() {
    super.initState();
    final establishment = widget.establishment;
    _description = TextEditingController(text: establishment.description);
    _phone = TextEditingController(text: establishment.phone);
    _address = TextEditingController(text: establishment.address);
    _opensAt = TextEditingController(text: establishment.opensAt);
    _closesAt = TextEditingController(text: establishment.closesAt);
    _isOpen = establishment.isOpen;
  }

  @override
  void dispose() {
    _description.dispose();
    _phone.dispose();
    _address.dispose();
    _opensAt.dispose();
    _closesAt.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _EstablishmentInput(
        description: _description.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        isOpen: _isOpen,
        opensAt: _opensAt.text.trim(),
        closesAt: _closesAt.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar estabelecimento'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    hintText: 'O que os clientes encontram aqui',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telemóvel'),
                  validator: (value) =>
                      RegExp(r'^8[2-7][0-9]{7}$')
                          .hasMatch(digitsOnly(value ?? ''))
                      ? null
                      : 'Número inválido (9 dígitos).',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Morada'),
                  validator: (value) =>
                      (value == null || value.trim().length < 5)
                      ? 'Indique a morada.'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _opensAt,
                        decoration: const InputDecoration(
                          labelText: 'Abre às',
                          hintText: '08:00',
                        ),
                        validator: (value) =>
                            RegExp(r'^[0-2][0-9]:[0-5][0-9]$')
                                .hasMatch(value?.trim() ?? '')
                            ? null
                            : 'Formato HH:MM.',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _closesAt,
                        decoration: const InputDecoration(
                          labelText: 'Fecha às',
                          hintText: '22:00',
                        ),
                        validator: (value) =>
                            RegExp(r'^[0-2][0-9]:[0-5][0-9]$')
                                .hasMatch(value?.trim() ?? '')
                            ? null
                            : 'Formato HH:MM.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Aberto para pedidos',
                    style: TextStyle(fontSize: 13),
                  ),
                  value: _isOpen,
                  onChanged: (value) => setState(() => _isOpen = value),
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
          onPressed: _save,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({required this.name, required this.phone});

  final String name;
  final String phone;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
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
      title: const Text('Editar conta'),
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
