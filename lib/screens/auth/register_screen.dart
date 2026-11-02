import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../state/app_scope.dart';

const Color _registerOrange = Color(0xFFF47721);
const Color _registerOrangeDark = Color(0xFFE76512);
const Color _registerOrangeSoft = Color(0xFFFFF1E7);
const Color _registerInk = Color(0xFF171717);
const Color _registerMuted = Color(0xFF77736F);
const Color _registerBorder = Color(0xFFEAE6E2);
const Color _registerCanvas = Color(0xFFFAF8F6);
const Color _registerDanger = Color(0xFFB42318);
const Color _registerDangerSoft = Color(0xFFFFF0EF);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await AppScope.of(context).register(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: digitsOnly(_phone.text),
        password: _password.text,
      );
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
    String? helper,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      prefixIcon: Icon(icon, color: _registerMuted, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFFFFEFD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      labelStyle: const TextStyle(
        color: _registerMuted,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(color: Color(0xFFB5AFA9), fontSize: 13),
      helperStyle: const TextStyle(
        color: _registerMuted,
        fontSize: 11,
        height: 1.35,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _registerBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _registerBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _registerOrange, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _registerDanger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _registerDanger, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 760;

    return Scaffold(
      backgroundColor: _registerCanvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 32 : 22,
              vertical: 22,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: isWide ? _buildWideLayout(context) : _buildCompactLayout(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopBar(context),
        const SizedBox(height: 22),
        _buildFormCard(context, wide: false),
        const SizedBox(height: 22),
        _buildFooter(context),
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 42, 20),
            child: _buildWelcomePanel(context),
          ),
        ),
        Expanded(
          flex: 6,
          child: _buildFormCard(context, wide: true),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _registerOrange,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: _registerOrange.withValues(alpha: 0.22),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: const Icon(
            Icons.delivery_dining_rounded,
            color: Colors.white,
            size: 29,
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NACALA',
              style: TextStyle(
                color: _registerInk,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.1,
                height: 1,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'DELIVERY',
              style: TextStyle(
                color: _registerOrangeDark,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.8,
              ),
            ),
          ],
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 17),
          label: const Text('Voltar'),
          style: TextButton.styleFrom(
            foregroundColor: _registerInk,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomePanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTopBar(context),
        const SizedBox(height: 62),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: _registerOrangeSoft,
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.waving_hand_rounded, color: _registerOrangeDark, size: 16),
              SizedBox(width: 7),
              Text(
                'BEM-VINDO À COMUNIDADE',
                style: TextStyle(
                  color: _registerOrangeDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Tudo o que\\nprecisas, à tua\\nporta.',
          style: TextStyle(
            color: _registerInk,
            fontSize: 43,
            height: 1.08,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.7,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Cria a tua conta e começa a descobrir restaurantes, lojas e serviços em Nacala-Porto.',
          style: TextStyle(
            color: _registerMuted,
            fontSize: 15,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 34),
        _WelcomeBenefit(
          icon: Icons.explore_outlined,
          title: 'Descobre opções perto de ti',
          description: 'Encontra lojas e restaurantes locais.',
        ),
        const SizedBox(height: 20),
        _WelcomeBenefit(
          icon: Icons.shopping_bag_outlined,
          title: 'Pede de forma simples',
          description: 'Acompanha os teus pedidos num só lugar.',
        ),
        const SizedBox(height: 20),
        _WelcomeBenefit(
          icon: Icons.location_on_outlined,
          title: 'Recebe onde estiveres',
          description: 'Indica o teu contacto e local de entrega.',
        ),
      ],
    );
  }

  Widget _buildFormCard(BuildContext context, {required bool wide}) {
    return Container(
      padding: EdgeInsets.all(wide ? 30 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _registerBorder),
        boxShadow: [
          BoxShadow(
            color: _registerInk.withValues(alpha: 0.055),
            blurRadius: 35,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!wide) ...[
              _buildTopBar(context),
              const SizedBox(height: 28),
            ],
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Criar conta',
                        style: TextStyle(
                          color: _registerInk,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Preenche os teus dados para começar.',
                        style: TextStyle(
                          color: _registerMuted,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _registerOrangeSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: _registerOrangeDark,
                    size: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            _fieldLabel('Nome completo'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                label: 'Como te chamas?',
                icon: Icons.person_outline_rounded,
              ),
              validator: (value) =>
                  (value == null || value.trim().length < 2)
                      ? 'Indique o seu nome.'
                      : null,
            ),
            const SizedBox(height: 17),
            _fieldLabel('Email'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: _inputDecoration(
                label: 'exemplo@email.com',
                icon: Icons.mail_outline_rounded,
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                  return 'Indique um email válido.';
                }
                return null;
              },
            ),
            const SizedBox(height: 17),
            _fieldLabel('Telemóvel'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                label: 'Número de Moçambique',
                hint: '84 123 4567',
                icon: Icons.phone_outlined,
              ),
              validator: (value) {
                final digits = digitsOnly(value ?? '');
                if (!RegExp(r'^8[2-7][0-9]{7}$').hasMatch(digits)) {
                  return 'Número moçambicano inválido (9 dígitos).';
                }
                return null;
              },
            ),
            const SizedBox(height: 17),
            _fieldLabel('Palavra-passe'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              decoration: _inputDecoration(
                label: 'Cria uma palavra-passe',
                icon: Icons.lock_outline_rounded,
                helper: 'Mínimo 8 caracteres, com letras e números.',
                suffix: IconButton(
                  tooltip: _obscure
                      ? 'Mostrar palavra-passe'
                      : 'Ocultar palavra-passe',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: _registerMuted,
                    size: 20,
                  ),
                ),
              ),
              validator: (value) {
                final text = value ?? '';
                if (text.length < 8 ||
                    !RegExp(r'[A-Za-z]').hasMatch(text) ||
                    !RegExp(r'[0-9]').hasMatch(text)) {
                  return 'Use pelo menos 8 caracteres com letras e números.';
                }
                return null;
              },
            ),
            const SizedBox(height: 17),
            _fieldLabel('Confirmar palavra-passe'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: _inputDecoration(
                label: 'Repete a palavra-passe',
                icon: Icons.lock_reset_rounded,
              ),
              validator: (value) => value != _password.text
                  ? 'As palavras-passe não coincidem.'
                  : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 17),
              _ErrorBanner(message: _error!),
            ],
            const SizedBox(height: 23),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _registerOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _registerOrange.withValues(alpha: 0.55),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Criar a minha conta'),
                          SizedBox(width: 9),
                          Icon(Icons.arrow_forward_rounded, size: 19),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 19),
            Text.rich(
              TextSpan(
                text: 'Ao criar conta aceitas os ',
                style: const TextStyle(
                  color: _registerMuted,
                  fontSize: 11,
                  height: 1.55,
                ),
                children: const [
                  TextSpan(
                    text: 'termos e condições',
                    style: TextStyle(
                      color: _registerOrangeDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(text: ' e a política de privacidade.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Já tens conta?',
                  style: TextStyle(color: _registerMuted, fontSize: 13),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: TextButton.styleFrom(
                    foregroundColor: _registerOrangeDark,
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  child: const Text('Entrar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: _registerInk,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return const Text(
      'NACALA DELIVERY  •  FEITO PARA NACALA-PORTO',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Color(0xFFA49D96),
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _WelcomeBenefit extends StatelessWidget {
  const _WelcomeBenefit({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _registerBorder),
          ),
          child: Icon(icon, color: _registerOrangeDark, size: 21),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _registerInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  color: _registerMuted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _registerDangerSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF5D0CC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: _registerDanger,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _registerDanger,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
