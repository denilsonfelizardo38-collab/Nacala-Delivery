import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/jb.dart';

/// Registo de um parceiro real pela administração.
///
/// Cria a conta de acesso (papel `partner`) e o estabelecimento aprovado numa
/// única operação no servidor.
class AdminCreatePartnerScreen extends StatefulWidget {
  const AdminCreatePartnerScreen({super.key});

  @override
  State<AdminCreatePartnerScreen> createState() =>
      _AdminCreatePartnerScreenState();
}

class _AdminCreatePartnerScreenState extends State<AdminCreatePartnerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _establishmentName = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _establishmentPhone = TextEditingController();
  final _fee = TextEditingController(text: '80');
  final _prep = TextEditingController(text: '30');
  final _opensAt = TextEditingController(text: '08:00');
  final _closesAt = TextEditingController(text: '21:00');
  final _nuit = TextEditingController();

  /// Fotografia do estabelecimento: escolhida como ficheiro e carregada para
  /// a API (em vez de um link externo colado à mão).
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _imageFile;
  Uint8List? _imageBytes;
  String? _uploadedImageUrl;

  bool _initialized = false;
  bool _submitting = false;
  String? _error;
  String? _categoryId;
  List<Category> _categories = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await AppScope.of(context).api.categories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _categoryId ??= categories.isEmpty ? null : categories.first.id;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  /// Escolhe a fotografia do estabelecimento na galeria (ficheiro, não link).
  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageFile = image;
        _imageBytes = bytes;
        _uploadedImageUrl = null;
      });
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.message ?? 'Não foi possível abrir a galeria.',
        );
      }
    } on FileSystemException {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível ler a imagem escolhida.',
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _imageFile = null;
      _imageBytes = null;
      _uploadedImageUrl = null;
    });
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _phone,
      _password,
      _establishmentName,
      _description,
      _address,
      _establishmentPhone,
      _fee,
      _prep,
      _opensAt,
      _closesAt,
      _nuit,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_categoryId == null) {
      setState(() => _error = 'Escolha a categoria do estabelecimento.');
      return;
    }
    final fee = parseMoneyToCents(_fee.text);
    final prep = int.tryParse(_prep.text.trim());
    if (fee == null || prep == null) {
      setState(() => _error = 'Taxa de entrega ou tempo inválidos.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final api = AppScope.of(context).api;
      // Fotografia: ficheiro escolhido é carregado agora; o URL devolvido é
      // o que segue para o registo do parceiro.
      var imageUrl = _uploadedImageUrl;
      final photo = _imageFile;
      if (photo != null) {
        imageUrl = await api.adminUploadPartnerImage(photo);
      }
      await api.adminCreatePartner(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: digitsOnly(_phone.text),
        password: _password.text,
        nuit: digitsOnly(_nuit.text),
        establishmentName: _establishmentName.text.trim(),
        categoryId: _categoryId!,
        description: _description.text.trim(),
        address: _address.text.trim(),
        establishmentPhone: digitsOnly(_establishmentPhone.text),
        deliveryFeeCents: fee,
        prepMinutes: prep,
        opensAt: _opensAt.text.trim(),
        closesAt: _closesAt.text.trim(),
        imageUrl: imageUrl,
      );
      if (!mounted) return;
      showAppSnack(context, 'Parceiro registado com acesso ativo.');
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            JbPageHeader(
              title: 'Registar parceiro',
              onBack: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).maybePop()
                  : null,
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    const JbSectionHeader(title: 'Conta de acesso'),
                    _field(
                      controller: _name,
                      label: 'Nome do responsável',
                      textInputAction: TextInputAction.next,
                      validator: (value) => (value ?? '').trim().length < 2
                          ? 'Indique o nome do responsável.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _email,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(text)) {
                          return 'Indique um email válido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _phone,
                      label: 'Telemóvel',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      hint: '84 123 4567',
                      validator: (value) {
                        if (!RegExp(r'^8[2-7][0-9]{7}$')
                            .hasMatch(digitsOnly(value ?? ''))) {
                          return 'Número moçambicano inválido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _password,
                      label: 'Palavra-passe inicial',
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      helper: 'Mínimo 8 caracteres, com letras e números.',
                      validator: (value) {
                        final text = value ?? '';
                        if (text.length < 8 ||
                            !RegExp(r'[A-Za-z]').hasMatch(text) ||
                            !RegExp(r'[0-9]').hasMatch(text)) {
                          return 'Use letras e números (mínimo 8).';
                        }
                        return null;
                      },
                    ),
                    const JbSectionHeader(title: 'Estabelecimento'),
                    _field(
                      controller: _establishmentName,
                      label: 'Nome do estabelecimento',
                      textInputAction: TextInputAction.next,
                      validator: (value) => (value ?? '').trim().length < 2
                          ? 'Indique o nome do estabelecimento.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _categoryId,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: [
                        for (final category in _categories)
                          DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ),
                      ],
                      onChanged: (value) => setState(() => _categoryId = value),
                      validator: (value) =>
                          value == null ? 'Escolha uma categoria.' : null,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _description,
                      label: 'Descrição (opcional)',
                      maxLines: 2,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _address,
                      label: 'Morada',
                      textInputAction: TextInputAction.next,
                      hint: 'Bairro, rua, referência',
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Indique a morada do estabelecimento.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _establishmentPhone,
                      label: 'Telefone do estabelecimento (opcional)',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _nuit,
                      label: 'NUIT',
                      hint: '9 dígitos do contribuinte',
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      helper: 'Número Único de Identificação Tributária.',
                      validator: (value) {
                        final digits = digitsOnly(value ?? '');
                        if (!RegExp(r'^[0-9]{9}$').hasMatch(digits)) {
                          return 'NUIT inválido (9 dígitos).';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'FOTO DO ESTABELECIMENTO (OPCIONAL)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(
                            _imageFile == null
                                ? 'Escolher da galeria'
                                : 'Alterar imagem',
                          ),
                        ),
                        if (_imageFile != null || _uploadedImageUrl != null)
                          IconButton(
                            tooltip: 'Remover imagem',
                            onPressed: _removeImage,
                            icon: const Icon(Icons.close_rounded),
                          ),
                      ],
                    ),
                    if (_imageFile != null || _uploadedImageUrl != null) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _imageBytes != null
                            ? Image.memory(
                                _imageBytes!,
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                              )
                            : NetworkThumb(
                                imageUrl: _uploadedImageUrl,
                                size: 96,
                                radius: 14,
                              ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            controller: _fee,
                            label: 'Taxa de entrega (MT)',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              final cents = parseMoneyToCents(value ?? '');
                              if (cents == null || cents < 0) {
                                return 'Valor inválido.';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            controller: _prep,
                            label: 'Preparação (min)',
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              final minutes = int.tryParse(
                                (value ?? '').trim(),
                              );
                              if (minutes == null ||
                                  minutes < 5 ||
                                  minutes > 240) {
                                return 'Entre 5 e 240.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            controller: _opensAt,
                            label: 'Abre às',
                            hint: '08:00',
                            textInputAction: TextInputAction.next,
                            validator: _timeValidator,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            controller: _closesAt,
                            label: 'Fecha às',
                            hint: '21:00',
                            textInputAction: TextInputAction.done,
                            validator: _timeValidator,
                          ),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      InfoRow(
                        icon: Icons.error_outline_rounded,
                        text: _error!,
                        color: context.dangerColor,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Criar parceiro'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'A conta fica ativa de imediato. Partilhe o email e a '
                      'palavra-passe inicial com o parceiro.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.mutedColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _timeValidator(String? value) {
    final text = (value ?? '').trim();
    if (!RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$').hasMatch(text)) {
      return 'Use HH:MM.';
    }
    return null;
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? helper,
    bool obscureText = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        fillColor: AppColors.bg,
      ),
    );
  }
}
