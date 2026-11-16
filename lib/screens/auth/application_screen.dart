import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/location_service.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../widgets/jb.dart';
import '../../widgets/location_picker.dart';

/// Candidatura pública de **ESTABELECIMENTO** ou **ENTREGADOR**
/// (`POST /api/applications`), acessível a partir da seleção de tipo de
/// conta (`/roles`).
///
/// * `kind = 'establishment'` → `/establishment/apply`: formulário completo
///   (categorias, morada, horários, taxa, localização no mapa) e envio para
///   aprovação do administrador.
/// * `kind = 'delivery'` → `/courier/apply`: dados do candidato, veículo e
///   zona de cobertura.
///
/// Após o envio a candidatura fica `pending`: quem não tem conta recebe
/// também uma conta de candidatura para poder entrar e consultar o estado
/// em `/application/status` (o painel fica bloqueado no servidor até à
/// aprovação).
class ApplicationScreen extends StatefulWidget {
  const ApplicationScreen({super.key, required this.kind})
    : assert(kind == 'establishment' || kind == 'delivery');

  final String kind;

  bool get isEstablishment => kind == 'establishment';

  @override
  State<ApplicationScreen> createState() => _ApplicationScreenState();
}

class _ApplicationScreenState extends State<ApplicationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Conta / candidato.
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  // Estabelecimento.
  final _establishmentName = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();
  final _deliveryFee = TextEditingController();
  final _prepMinutes = TextEditingController();

  // Entregador.
  final _vehicleType = TextEditingController();
  final _notes = TextEditingController();

  // Contribuinte (NUIT): obrigatório em candidaturas de parceiro e de
  // entregador — clientes (compradores) não são contribuintes.
  final _nuit = TextEditingController();

  // Documentos do entregador: selfie, B.I (frente e verso) e carta de
  // condução, fotografados aqui e carregados antes do envio.
  final ImagePicker _imagePicker = ImagePicker();
  final Map<String, XFile> _documentFiles = {};
  final Map<String, Uint8List> _documentBytes = {};
  final Map<String, String> _documentUrls = {};

  /// Chave, rótulo e ícone de cada documento obrigatório do entregador.
  static const _documentSpecs = <(String, String, IconData)>[
    ('selfie', 'Selfie', Icons.camera_alt_outlined),
    ('bi_front', 'B.I — frente', Icons.badge_outlined),
    ('bi_back', 'B.I — verso', Icons.badge_outlined),
    ('license', 'Carta de condução', Icons.credit_card_outlined),
  ];

  List<Category> _categories = const [];
  bool _loadingCategories = false;
  String? _categoryId;
  TimeOfDay _opensAt = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _closesAt = const TimeOfDay(hour: 21, minute: 0);
  LatLng? _location;

  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  /// Guardada depois do envio: troca o formulário pelo painel de sucesso.
  Application? _submitted;

  bool get _signedIn => AppScope.of(context).isSignedIn;

  bool _categoriesLoaded = false;

  @override
  void initState() {
    super.initState();
    // Reenvio de correções pedidas pelo administrador: mantém a sessão e
    // pré-preenche o que já tinha sido enviado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final existing = ModalRoute.of(context)?.settings.arguments;
      if (existing is Application && mounted) _prefill(existing);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `AppScope.of` só pode ser usado depois do initState; as categorias
    // são carregadas uma única vez aqui.
    if (!_categoriesLoaded) {
      _categoriesLoaded = true;
      _loadCategories();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _establishmentName.dispose();
    _address.dispose();
    _description.dispose();
    _deliveryFee.dispose();
    _prepMinutes.dispose();
    _vehicleType.dispose();
    _notes.dispose();
    _nuit.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    if (!widget.isEstablishment) return;
    setState(() => _loadingCategories = true);
    try {
      final categories = await AppScope.of(context).api.categories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        // Pré-seleciona a única categoria quando só existe uma.
        if (_categoryId == null && categories.length == 1) {
          _categoryId = categories.first.id;
        }
      });
    } on ApiException {
      // Sem categorias o formulário continua utilizável: o campo é
      // validado como obrigatório e o erro aparece ao enviar.
    } finally {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  void _prefill(Application application) {
    final payload = application.payload;
    setState(() {
      _name.text = application.name;
      _phone.text = application.phone;
      _whatsapp.text = application.whatsapp ?? '';
      _email.text = application.email;
      _nuit.text = '${payload['nuit'] ?? ''}';
      if (widget.isEstablishment) {
        _establishmentName.text =
            '${payload['establishment_name'] ?? ''}';
        _categoryId = payload['category_id'] as String? ?? _categoryId;
        _address.text = '${payload['address'] ?? ''}';
        _description.text = '${payload['description'] ?? ''}';
        _deliveryFee.text =
            '${((payload['delivery_fee_cents'] as num?) ?? 0) ~/ 100}';
        _prepMinutes.text = '${payload['prep_minutes'] ?? 30}';
        final latitude = payload['latitude'] as double?;
        final longitude = payload['longitude'] as double?;
        if (latitude != null && longitude != null) {
          _location = LatLng(latitude, longitude);
        }
        _opensAt = _parseTime(payload['opens_at']) ?? _opensAt;
        _closesAt = _parseTime(payload['closes_at']) ?? _closesAt;
      } else {
        _vehicleType.text = '${payload['vehicle_type'] ?? ''}';
        _address.text = '${payload['address'] ?? ''}';
        _notes.text = '${payload['notes'] ?? ''}';
        // Documentos já enviados numa tentativa anterior continuam válidos.
        final sent = payload['documents'];
        if (sent is Map) {
          for (final spec in _documentSpecs) {
            final url = sent[spec.$1];
            if (url is String && url.isNotEmpty) {
              // Caminho guardado no servidor → URL para a pré-visualização.
              _documentUrls[spec.$1] = AppScope.of(
                context,
              ).api.client.resolveUri(url).toString();
            }
          }
        }
      }
      // A palavra-passe nunca volta do servidor: é preciso definir uma
      // nova no reenvio (o servidor sincroniza a conta do candidato).
    });
  }

  static TimeOfDay? _parseTime(Object? raw) {
    final text = '$raw';
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text);
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime({required bool opens}) async {
    final initial = opens ? _opensAt : _closesAt;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (opens) {
        _opensAt = picked;
      } else {
        _closesAt = picked;
      }
    });
  }

  Future<void> _pickLocation() async {
    final picked = await showLocationPicker(
      context,
      initialLocation: _location,
      title: widget.isEstablishment
          ? 'Localização do estabelecimento'
          : 'Zona de cobertura',
      hint: widget.isEstablishment
          ? 'Toque no mapa para marcar o local do estabelecimento.'
          : 'Toque no mapa para marcar a tua zona de trabalho.',
    );
    if (picked == null || !mounted) return;
    setState(() => _location = picked);
    // "Guardar o endereço apresentado": se a morada ainda não foi escrita,
    // deriva-a do ponto confirmado (não sobrescreve o que já existe).
    if (widget.isEstablishment && _address.text.trim().isEmpty) {
      try {
        final address = await LocationService.addressFromCoordinates(
          picked.latitude,
          picked.longitude,
        );
        if (address != null && address.isNotEmpty && mounted) {
          setState(() => _address.text = address);
        }
      } on LocationException {
        // Sem geocoding (ex.: sem rede): o candidato escreve a morada à mão.
      }
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final state = AppScope.of(context);
    if (!widget.isEstablishment) {
      // Validação dos documentos ANTES de assinalar o envio: senão o botão
      // ficava preso no spinner (a verificação estava fora do try/finally).
      final missing = _missingDocuments();
      if (missing.isNotEmpty) {
        setState(
          () => _error = 'Falta fotografar: ${missing.join(', ')}.',
        );
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final Map<String, dynamic> payload;
    if (widget.isEstablishment) {
      final feeText = _deliveryFee.text.trim().replaceAll(',', '.');
      final fee = double.tryParse(feeText) ?? 0;
      payload = {
        'establishment_name': _establishmentName.text.trim(),
        'category_id': _categoryId,
        'nuit': digitsOnly(_nuit.text),
        'description': _description.text.trim(),
        'address': _address.text.trim(),
        'phone': digitsOnly(_phone.text),
        if (_whatsapp.text.trim().isNotEmpty)
          'whatsapp': digitsOnly(_whatsapp.text),
        if (_location != null) ...{
          'latitude': _location!.latitude,
          'longitude': _location!.longitude,
        },
        'delivery_fee_cents': (fee * 100).round(),
        'prep_minutes': int.tryParse(_prepMinutes.text.trim()) ?? 30,
        'opens_at': _formatTime(_opensAt),
        'closes_at': _formatTime(_closesAt),
      };
    } else {
      payload = {
        'vehicle_type': _vehicleType.text.trim(),
        'nuit': digitsOnly(_nuit.text),
        'address': _address.text.trim(),
        'notes': _notes.text.trim(),
        if (_location != null) ...{
          'latitude': _location!.latitude,
          'longitude': _location!.longitude,
        },
      };
    }

    try {
      if (!widget.isEstablishment) {
        // Documentos: mantém os já enviados e carrega os novos.
        final documents = <String, String>{
          for (final spec in _documentSpecs)
            if (_documentUrls.containsKey(spec.$1))
              spec.$1: _uploadPath(_documentUrls[spec.$1]!),
        };
        for (final entry in _documentFiles.entries) {
          documents[entry.key] = _uploadPath(
            await state.api.uploadApplicationImage(entry.value),
          );
        }
        payload['documents'] = documents;
      }
      final application = await state.submitApplication(
        kind: widget.kind,
        name: _name.text.trim(),
        phone: digitsOnly(_phone.text),
        whatsapp: digitsOnly(_whatsapp.text),
        email: _email.text.trim(),
        password: _password.text,
        payload: payload,
      );
      if (!mounted) return;
      setState(() => _submitted = application);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível enviar a candidatura. Tenta novamente.';
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.muted, size: 21),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      hintStyle: const TextStyle(color: AppColors.mutedLight, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.dangerInk),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.dangerInk, width: 1.5),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 14),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordSuffix(bool obscure, VoidCallback onPressed) {
    return IconButton(
      onPressed: onPressed,
      tooltip: obscure ? 'Mostrar palavra-passe' : 'Ocultar palavra-passe',
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: AppColors.muted,
        size: 20,
      ),
    );
  }

  String? _phoneValidator(String? value) {
    final digits = digitsOnly(value ?? '');
    return RegExp(r'^8[2-7][0-9]{7}$').hasMatch(digits)
        ? null
        : 'Número moçambicano inválido (9 dígitos).';
  }

  String? _optionalPhoneValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return _phoneValidator(value);
  }

  String? _passwordValidator(String? value) {
    final text = value ?? '';
    if (text.length < 8 ||
        !RegExp(r'[A-Za-z]').hasMatch(text) ||
        !RegExp(r'[0-9]').hasMatch(text)) {
      return 'Usa pelo menos 8 caracteres, com letras e números.';
    }
    return null;
  }

  String? _nuitValidator(String? value) {
    final digits = digitsOnly(value ?? '');
    return RegExp(r'^[0-9]{9}$').hasMatch(digits)
        ? null
        : 'NUIT inválido (9 dígitos).';
  }

  bool _hasDocument(String key) =>
      _documentFiles.containsKey(key) || _documentUrls.containsKey(key);

  /// Rótulos dos documentos obrigatórios ainda sem fotografia.
  List<String> _missingDocuments() => [
        for (final spec in _documentSpecs)
          if (!_hasDocument(spec.$1)) spec.$2,
      ];

  /// Escolhe a origem (galeria ou câmara) de uma fotografia de documento.
  Future<void> _chooseDocumentSource(String key, String label) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar fotografia'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    await _pickDocument(key, source);
  }

  Future<void> _pickDocument(String key, ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1400,
        maxHeight: 1400,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _documentFiles[key] = image;
        _documentBytes[key] = bytes;
        // A nova fotografia substitui a enviada em tentativa anterior.
        _documentUrls.remove(key);
      });
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _error =
              error.message ?? 'Não foi possível abrir a câmara ou a galeria.',
        );
      }
    } on FileSystemException {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível ler a fotografia escolhida.',
        );
      }
    }
  }

  /// Cartão de um documento: pré-visualização quando já existe fotografia,
  /// senão o ícone a convidar a tirar/escolher a imagem.
  Widget _documentTile(String key, String label, IconData icon) {
    final bytes = _documentBytes[key];
    final url = _documentUrls[key];
    final provided = bytes != null || url != null;
    return SizedBox(
      width: 150,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _chooseDocumentSource(key, label),
        child: Container(
          height: 134,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: provided ? AppColors.primary : AppColors.border,
              width: provided ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: bytes != null
                      ? Image.memory(bytes, fit: BoxFit.cover)
                      : url != null
                      ? Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              Icon(icon, color: AppColors.muted, size: 30),
                        )
                      : Icon(icon, color: AppColors.muted, size: 30),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                provided ? '$label ✓' : label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: provided ? AppColors.primary : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// URL devolvido pelo upload → caminho canónico `/uploads/…` que o
  /// servidor aceita e guarda no `payload` da candidatura.
  static String _uploadPath(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    return uri.hasScheme || uri.host.isNotEmpty ? uri.path : url;
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    if (_submitted != null) return _successPanel(_submitted!);

    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 850;
    final horizontal = wide ? 30.0 : 18.0;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final establishing = widget.isEstablishment;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: JbPageHeader(
                  title: establishing
                      ? 'Registar estabelecimento'
                      : 'Ser entregador',
                  subtitle: establishing
                      ? 'Publica os teus produtos em Nacala — depois de '
                          'aprovado pela equipa, o painel abre.'
                      : 'Candidata-te a entregador — a equipa analisa os '
                          'dados e responde na app.',
                  padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 6),
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.of(context).maybePop()
                      : null,
                  trailing: Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      establishing
                          ? Icons.storefront_rounded
                          : Icons.two_wheeler_rounded,
                      color: AppColors.primaryPressed,
                      size: 23,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    14,
                    horizontal,
                    22 + bottomInset,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: _formCard(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formCard() {
    final establishing = widget.isEstablishment;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x73000000),
            blurRadius: 35,
            offset: Offset(0, 15),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(
              establishing ? 'O ESTABELECIMENTO' : 'OS TEUS DADOS',
            ),

            if (establishing) ...[
              _label('NOME DO ESTABELECIMENTO'),
              TextFormField(
                controller: _establishmentName,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: _decoration(
                  hint: 'ex.: Cantinho da Baía',
                  icon: Icons.storefront_outlined,
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.length < 2) return 'Indica o nome do estabelecimento.';
                  if (text.length > 80) return 'Nome demasiado longo.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _label('NUIT'),
              TextFormField(
                controller: _nuit,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: _decoration(
                  hint: '9 dígitos do contribuinte',
                  icon: Icons.receipt_long_outlined,
                ),
                validator: _nuitValidator,
              ),
              const SizedBox(height: 16),
              _label('CATEGORIA'),
              if (_loadingCategories)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  hint: const Text('Escolhe a categoria'),
                  isExpanded: true,
                  items: [
                    for (final category in _categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _categoryId = value),
                  decoration: _decoration(
                    hint: 'Escolhe a categoria',
                    icon: Icons.category_outlined,
                  ).copyWith(hintText: null),
                  validator: (value) => value == null
                      ? 'Escolhe a categoria do estabelecimento.'
                      : null,
                ),
              const SizedBox(height: 16),
              _label('MORADA'),
              TextFormField(
                controller: _address,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: _decoration(
                  hint: 'Bairro, rua, ponto de referência',
                  icon: Icons.location_on_outlined,
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Indica a morada do estabelecimento.';
                  if (text.length > 200) return 'Morada demasiado longa.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _label('DESCRIÇÃO (OPCIONAL)'),
              TextFormField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                maxLength: 500,
                decoration: _decoration(
                  hint: 'O que servem? Especialidades, ambiente…',
                  icon: Icons.notes_rounded,
                ).copyWith(counterText: ''),
                validator: (value) =>
                    (value?.length ?? 0) > 500 ? 'Descrição demasiado longa.' : null,
              ),
              const SizedBox(height: 6),
              _label('LOCALIZAÇÃO NO MAPA (RECOMENDADO)'),
              _locationTile(
                empty: 'Marca o ponto exato do estabelecimento.',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label('ABRE ÀS'),
                        InkWell(
                          key: const ValueKey('pick-opens'),
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _pickTime(opens: true),
                          child: InputDecorator(
                            decoration: _decoration(
                              hint: '08:00',
                              icon: Icons.access_time_rounded,
                            ),
                            child: Text(
                              _formatTime(_opensAt),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label('FECHA ÀS'),
                        InkWell(
                          key: const ValueKey('pick-closes'),
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _pickTime(opens: false),
                          child: InputDecorator(
                            decoration: _decoration(
                              hint: '21:00',
                              icon: Icons.access_time_rounded,
                            ),
                            child: Text(
                              _formatTime(_closesAt),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label('TAXA DE ENTREGA (MZN)'),
                        TextFormField(
                          controller: _deliveryFee,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.next,
                          decoration: _decoration(
                            hint: 'ex.: 150',
                            icon: Icons.payments_outlined,
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return null;
                            final fee = double.tryParse(
                              text.replaceAll(',', '.'),
                            );
                            if (fee == null || fee < 0 || fee > 10000) {
                              return 'Valor inválido (0–10000).';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label('PREPARAÇÃO (MIN)'),
                        TextFormField(
                          controller: _prepMinutes,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: _decoration(
                            hint: '30',
                            icon: Icons.timer_outlined,
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return null;
                            final minutes = int.tryParse(text);
                            if (minutes == null ||
                                minutes < 5 ||
                                minutes > 240) {
                              return '5–240 min.';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              _label('NUIT'),
              TextFormField(
                controller: _nuit,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: _decoration(
                  hint: '9 dígitos do contribuinte',
                  icon: Icons.receipt_long_outlined,
                ),
                validator: _nuitValidator,
              ),
              const SizedBox(height: 16),
              _label('TIPO DE VEÍCULO'),
              DropdownButtonFormField<String>(
                initialValue: _vehicleType.text.isEmpty
                    ? null
                    : _vehicleType.text,
                hint: const Text('Como fazes as entregas?'),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'Mota', child: Text('Mota')),
                  DropdownMenuItem(
                    value: 'Bicicleta',
                    child: Text('Bicicleta'),
                  ),
                  DropdownMenuItem(value: 'Carro', child: Text('Carro')),
                  DropdownMenuItem(value: 'A pé', child: Text('A pé')),
                ],
                onChanged: (value) =>
                    setState(() => _vehicleType.text = value ?? ''),
                decoration: _decoration(
                  hint: 'Como fazes as entregas?',
                  icon: Icons.two_wheeler_rounded,
                ).copyWith(hintText: null),
                validator: (value) =>
                    (value == null || value.isEmpty)
                        ? 'Escolhe o tipo de veículo.'
                        : null,
              ),
              const SizedBox(height: 16),
              _label('ZONA DE COBERTURA / MORADA'),
              TextFormField(
                controller: _address,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: _decoration(
                  hint: 'Bairros onde costumas entregar',
                  icon: Icons.location_on_outlined,
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Indica a tua zona de cobertura.';
                  if (text.length > 200) return 'Morada demasiado longa.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _label('LOCALIZAÇÃO ATUAL (OPCIONAL)'),
              _locationTile(
                empty: 'Marca o teu ponto de partida habitual.',
              ),
              const SizedBox(height: 16),
              _label('NOTAS (OPCIONAL)'),
              TextFormField(
                controller: _notes,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                maxLength: 500,
                decoration: _decoration(
                  hint: 'Ex.: experiência, disponibilidade horária…',
                  icon: Icons.notes_rounded,
                ).copyWith(counterText: ''),
                validator: (value) =>
                    (value?.length ?? 0) > 500 ? 'Notas demasiado longas.' : null,
              ),
              const SizedBox(height: 22),
              _sectionTitle('DOCUMENTOS (OBRIGATÓRIOS)'),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Selfie, B.I (frente e verso) e carta de condução — '
                  'tira ou escolhe a fotografia em cada cartão.',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final spec in _documentSpecs)
                    _documentTile(spec.$1, spec.$2, spec.$3),
                ],
              ),
            ],

            const SizedBox(height: 22),
            _sectionTitle('DADOS DE CONTACTO E CONTA'),

            _label('NOME COMPLETO'),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: _decoration(
                hint: 'Como te chamas?',
                icon: Icons.person_outline_rounded,
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.length < 2) return 'Indica o teu nome.';
                if (text.length > 80) return 'Nome demasiado longo.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _label('TELEMÓVEL'),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: _decoration(
                hint: '84 123 4567',
                icon: Icons.phone_outlined,
              ),
              validator: _phoneValidator,
            ),
            const SizedBox(height: 16),
            _label('WHATSAPP (OPCIONAL)'),
            TextFormField(
              controller: _whatsapp,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: _decoration(
                hint: 'Diferente do telemóvel, se quiseres',
                icon: Icons.chat_outlined,
              ),
              validator: _optionalPhoneValidator,
            ),
            const SizedBox(height: 16),
            _label('EMAIL (OPCIONAL)'),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: _decoration(
                hint: 'exemplo@email.com',
                icon: Icons.mail_outline_rounded,
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                  return 'Indica um email válido ou deixa o campo vazio.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _label('PALAVRA-PASSE'),
            TextFormField(
              controller: _password,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              decoration: _decoration(
                hint: 'Mínimo 8 caracteres, letras e números',
                icon: Icons.lock_outline_rounded,
                suffix: _passwordSuffix(
                  _obscurePassword,
                  () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: _passwordValidator,
            ),
            const SizedBox(height: 16),
            _label('CONFIRMAR PALAVRA-PASSE'),
            TextFormField(
              controller: _confirm,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              autocorrect: false,
              enableSuggestions: false,
              decoration: _decoration(
                hint: 'Repete a palavra-passe',
                icon: Icons.lock_reset_rounded,
              ),
              validator: (value) => value != _password.text
                  ? 'As palavras-passe não coincidem.'
                  : null,
            ),

            if (_error != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerInk.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.dangerInk.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.dangerInk,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 22),
            SizedBox(
              height: 54,
              child: FilledButton(
                key: const ValueKey('submit-application'),
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.isEstablishment
                            ? 'ENVIAR PARA APROVAÇÃO'
                            : 'CANDIDATAR-ME A ENTREGADOR',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A equipa analisa a candidatura e responde através da app. '
              'Até lá a conta fica em espera — podes entrar para '
              'acompanhar o estado.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.mutedLight,
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationTile({required String empty}) {
    final location = _location;
    final hasLocation = location != null;
    final selected = hasLocation
        ? 'Lat ${location.latitude.toStringAsFixed(5)}, '
            'Lng ${location.longitude.toStringAsFixed(5)}'
        : empty;
    return InkWell(
      key: const ValueKey('pick-location'),
      borderRadius: BorderRadius.circular(14),
      onTap: _pickLocation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasLocation ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasLocation ? Icons.map_rounded : Icons.add_location_alt_outlined,
              color: hasLocation ? AppColors.primary : AppColors.muted,
              size: 21,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasLocation ? selected : empty,
                style: TextStyle(
                  color: hasLocation ? AppColors.ink : AppColors.mutedLight,
                  fontSize: 13,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Painel mostrado depois do envio bem-sucedido: estado `pending` e
  /// como acompanhar a candidatura.
  Widget _successPanel(Application application) {
    final establishing = widget.isEstablishment;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x73000000),
                      blurRadius: 35,
                      offset: Offset(0, 15),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        color: AppColors.primaryPressed,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Candidatura enviada!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      establishing
                          ? 'Recebemos os dados do teu estabelecimento. '
                              'A equipa vai analisar e aprovar (ou pedir '
                              'correções) através da app.'
                          : 'Recebemos a tua candidatura. A equipa vai '
                              'analisar os dados e responder através da app.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13.5,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _infoRow('Estado', application.statusLabel),
                          const SizedBox(height: 8),
                          _infoRow(
                            'Referência',
                            application.id.length > 12
                                ? application.id.substring(0, 12).toUpperCase()
                                : application.id.toUpperCase(),
                          ),
                          const SizedBox(height: 8),
                          _infoRow('Contacto', application.phone),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_signedIn) ...[
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          key: const ValueKey('goto-status'),
                          onPressed: () => Navigator.of(context).pushNamed(
                            '/application/status',
                          ),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Ver estado da candidatura',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () =>
                            Navigator.of(context).popUntil((r) => r.isFirst),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Voltar à Home'),
                      ),
                    ] else ...[
                      Text(
                        'Entra na tua conta (telemóvel + palavra-passe que '
                        'acabaste de definir) para acompanhar o estado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.muted.withValues(alpha: .9),
                          fontSize: 12.5,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          key: const ValueKey('goto-login'),
                          onPressed: () => Navigator.of(context).pushNamed(
                            '/login',
                          ),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Entrar para acompanhar',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () =>
                            Navigator.of(context).popUntil((r) => r.isFirst),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Voltar à Home'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
