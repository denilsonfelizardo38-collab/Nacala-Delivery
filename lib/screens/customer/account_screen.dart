import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_colors.dart';

import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/address_dialog.dart';
import '../../widgets/common.dart';
import '../../widgets/password_dialog.dart';
import 'favorites_screen.dart';
import 'notifications_screen.dart';
import 'support_info_screen.dart';

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

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  /// Explica que as áreas de parceiro, estafeta e administração usam
  /// contas próprias e permite sair da sessão atual para trocar.
  Future<void> _openAreaExchange() async {
    final state = AppScope.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Trocar de área',
      message:
          'As áreas de parceiro, estafeta e administração usam contas '
          'próprias. Termina esta sessão e, no ecrã de entrada, toca em '
          '«Contas para explorar» para entrar com uma dessas contas.',
      confirmLabel: 'Terminar sessão',
      destructive: true,
    );
    if (!confirmed) return;
    await state.logout();
  }

  Future<void> _editProfile() async {
    final state = AppScope.of(context);
    final user = state.user;
    if (user == null) return;

    final input = await showDialog<_ProfileInput>(
      context: context,
      builder: (_) => _ProfileDialog(
        name: user.name,
        phone: user.phone,
        email: user.email,
        avatarUrl: user.avatarUrl,
      ),
    );

    if (input == null) return;

    try {
      final picked = input.pickedImage;
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final mimeType = _mimeTypeFor(picked);
        if (mimeType == null) {
          if (mounted) {
            showAppSnack(
              context,
              'Escolha uma imagem JPEG, PNG ou WebP.',
              error: true,
            );
          }
          return;
        }
        await state.uploadAvatar(
          mimeType: mimeType,
          dataBase64: base64Encode(bytes),
        );
      }
      await state.updateProfile(
        name: input.name,
        phone: digitsOnly(input.phone),
        email: input.email,
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

  String? _mimeTypeFor(XFile file) {
    final ext = file.name.toLowerCase().split('.').lastOrNull;
    final mime = file.mimeType?.toLowerCase();
    if (mime != null &&
        const {'image/jpeg', 'image/png', 'image/webp'}.contains(mime)) {
      return mime;
    }
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
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
    final input = await showAddressDialog(context, initial: address);

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

  /// Escolha do tema (sistema, claro ou escuro) numa folha inferior; a
  /// alteração aplica-se imediatamente e fica guardada no dispositivo.
  Future<void> _openThemePicker() async {
    final state = AppScope.of(context);
    final current = state.themeSetting;
    final selected = await showModalBottomSheet<ThemeSetting>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Tema da aplicação',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final option in ThemeSetting.values)
              ListTile(
                leading: Icon(
                  switch (option) {
                    ThemeSetting.system => Icons.brightness_auto_rounded,
                    ThemeSetting.light => Icons.light_mode_outlined,
                    ThemeSetting.dark => Icons.dark_mode_outlined,
                  },
                ),
                title: Text(
                  switch (option) {
                    ThemeSetting.system => 'Sistema',
                    ThemeSetting.light => 'Claro',
                    ThemeSetting.dark => 'Escuro',
                  },
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  switch (option) {
                    ThemeSetting.system => 'Segue a definição do telemóvel',
                    ThemeSetting.light => 'Fundo claro em todas as áreas',
                    ThemeSetting.dark => 'Conforto à noite e poupança de bateria',
                  },
                  style: TextStyle(fontSize: 11, color: sheetContext.mutedColor),
                ),
                trailing:
                    option == current
                        ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.primary,
                        )
                        : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) state.setThemeSetting(selected);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.user;

    if (user == null) {
      if (state.isGuest) {
        return _buildGuestView(context);
      }

      return const Scaffold(body: Center(child: LoadingBlock()));
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
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
            children: [
              _ProfileHeader(
                name: user.name,
                email: user.email,
                phone: user.phone,
                roleLabel: user.roleLabel,
                avatarUrl: user.avatarUrl,
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

              _LinkCard(
                icon: Icons.favorite_rounded,
                title: 'Favoritos',
                subtitle: 'Restaurantes que guardaste',
                onTap: () => _open(const FavoritesScreen()),
              ),

              const SizedBox(height: 22),

              SectionTitle(
                title: 'Preferências e ajuda',
                subtitle: 'Tema, notificações e informação útil',
              ),

              const SizedBox(height: 12),

              _LinkCard(
                icon: Icons.contrast_rounded,
                title: 'Tema da aplicação',
                subtitle: switch (state.themeSetting) {
                  ThemeSetting.system => 'Sistema — segue o telemóvel',
                  ThemeSetting.light => 'Claro',
                  ThemeSetting.dark => 'Escuro',
                },
                onTap: _openThemePicker,
              ),
              const SizedBox(height: 10),
              _LinkCard(
                icon: Icons.notifications_none_rounded,
                title: 'Notificações',
                subtitle: 'O que aconteceu nos teus pedidos',
                onTap: () => _open(const NotificationsScreen()),
              ),
              const SizedBox(height: 10),
              _LinkCard(
                icon: Icons.payments_outlined,
                title: 'Métodos de pagamento',
                subtitle: 'M-Pesa, e-Mola e dinheiro na entrega',
                onTap: () => _open(const PaymentMethodsScreen()),
              ),
              const SizedBox(height: 10),
              _LinkCard(
                icon: Icons.help_outline_rounded,
                title: 'Ajuda e suporte',
                subtitle: 'Perguntas frequentes e contacto',
                onTap: () => _open(const HelpSupportScreen()),
              ),
              const SizedBox(height: 10),
              _LinkCard(
                icon: Icons.article_outlined,
                title: 'Termos e condições',
                subtitle: 'Regras de uso da plataforma',
                onTap: () => _open(const TermsScreen()),
              ),
              const SizedBox(height: 10),
              _LinkCard(
                icon: Icons.shield_outlined,
                title: 'Política de privacidade',
                subtitle: 'Como tratamos os teus dados',
                onTap: () => _open(const PrivacyScreen()),
              ),
              const SizedBox(height: 18),
              _LinkCard(
                icon: Icons.switch_account_rounded,
                title: 'Área de parceiro, estafeta ou administração',
                subtitle: 'Entra com a conta própria da tua área',
                onTap: _openAreaExchange,
              ),

              const SizedBox(height: 22),

              const SectionTitle(title: 'Aplicação'),

              const SizedBox(height: 12),

              _AppInfoCard(),

              const SizedBox(height: 24),

              OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Terminar sessão'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
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
                    fontWeight: FontWeight.w700,
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
      appBar: AppBar(title: const Text('A tua conta')),
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
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.primary,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Estás a explorar como convidado',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Podes descobrir lojas e produtos. Para fazer pedidos '
                    'e acompanhar entregas, entra ou cria uma conta.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: context.mutedColor, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _leaveGuestMode,
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Entrar ou criar conta'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
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

class _ProfileHeader extends StatefulWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.phone,
    required this.roleLabel,
    this.avatarUrl,
  });

  final String name;
  final String email;
  final String phone;
  final String roleLabel;
  final String? avatarUrl;

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final email = _revealed ? widget.email : maskEmail(widget.email);
    final phone = _revealed ? widget.phone : maskPhone(widget.phone);
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          UserAvatar(name: widget.name, size: 62, avatarUrl: widget.avatarUrl),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.mutedColor, fontSize: 12),
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
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        widget.roleLabel,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
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
          IconButton(
            tooltip: _revealed
                ? 'Ocultar dados pessoais'
                : 'Mostrar dados pessoais',
            onPressed: () => setState(() => _revealed = !_revealed),
            icon: Icon(
              _revealed
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: context.mutedColor,
              size: 21,
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
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        side: BorderSide(color: context.lineColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
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
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              isWork ? Icons.work_outline_rounded : Icons.home_outlined,
              color: AppColors.primary,
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
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (address.isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'PREDEFINIDA',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
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
  const _AppInfoCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
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
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(appVersion, style: TextStyle(fontSize: 11)),
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(13),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: context.mutedColor, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _ProfileInput {
  const _ProfileInput({
    required this.name,
    required this.phone,
    required this.email,
    this.pickedImage,
  });

  final String name;
  final String phone;
  final String email;
  final XFile? pickedImage;
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({
    required this.name,
    required this.phone,
    required this.email,
    this.avatarUrl,
  });

  final String name;
  final String phone;
  final String email;
  final String? avatarUrl;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  XFile? _pickedImage;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name);
    _phone = TextEditingController(text: widget.phone);
    _email = TextEditingController(text: widget.email);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (image == null || !mounted) return;
      setState(() => _pickedImage = image);
    } on PlatformException catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          error.message ?? 'Não foi possível abrir a imagem.',
          error: true,
        );
      }
    }
  }

  Future<void> _chooseSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Text(
                'Fotografia de perfil',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeria'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Câmara'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    await _pickImage(source);
  }

  @override
  Widget build(BuildContext context) {
    final picked = _pickedImage;

    return AlertDialog(
      title: const Text('Editar perfil'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ProfileSectionLabel('Fotografia'),
                Center(
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          picked != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(26),
                                  child: Image.file(
                                    File(picked.path),
                                    width: 88,
                                    height: 88,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : UserAvatar(
                                  name: _name.text.isEmpty ? 'N' : _name.text,
                                  size: 88,
                                  avatarUrl: widget.avatarUrl,
                                ),
                          Positioned(
                            right: -6,
                            bottom: -6,
                            child: Material(
                              color: AppColors.primary,
                              shape: const CircleBorder(),
                              elevation: 2,
                              child: IconButton(
                                tooltip: 'Alterar fotografia',
                                onPressed: _chooseSource,
                                icon: const Icon(
                                  Icons.photo_camera_rounded,
                                  color: Colors.white,
                                  size: 17,
                                ),
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(34, 34),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _chooseSource,
                        child: Text(
                          picked == null
                              ? 'Tocar para escolher da galeria ou câmara'
                              : 'Tocar para escolher outra fotografia',
                          style: TextStyle(
                            color: context.mutedColor,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                const _ProfileSectionLabel('Dados pessoais'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().length < 2)
                      ? 'Indique o seu nome.'
                      : null,
                ),

                const SizedBox(height: 16),
                const _ProfileSectionLabel('Contactos'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 9,
                  decoration: const InputDecoration(
                    labelText: 'Telemóvel',
                    counterText: '',
                    prefixIcon: Icon(Icons.phone_outlined),
                    helperText:
                        'O estafeta liga para este número em cada entrega.',
                    helperMaxLines: 2,
                  ),
                  validator: (value) =>
                      RegExp(r'^8[2-7][0-9]{7}$')
                          .hasMatch(digitsOnly(value ?? ''))
                      ? null
                      : 'Número inválido (8x, 9 dígitos).',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                    helperText: 'Serve para entrar na sua conta.',
                    helperMaxLines: 2,
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                      return 'Indique um email válido.';
                    }
                    return null;
                  },
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
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) {
              return;
            }
            Navigator.of(context).pop(
              _ProfileInput(
                name: _name.text.trim(),
                phone: _phone.text.trim(),
                email: _email.text.trim(),
                pickedImage: _pickedImage,
              ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 44),
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _ProfileSectionLabel extends StatelessWidget {
  const _ProfileSectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: context.mutedColor,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}
