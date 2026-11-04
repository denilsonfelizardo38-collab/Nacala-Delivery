import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../state/app_scope.dart';

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

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
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
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível criar a conta. Tenta novamente.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
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

  Widget _brand({bool light = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.delivery_dining_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NACALA',
              style: TextStyle(
                color: light ? Colors.white : AppColors.deepNavy,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                height: 1,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'DELIVERY',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _heroPanel({required bool compact}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 22 : 28),
      child: SizedBox(
        height: compact ? 225 : 590,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/login_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.deepNavyLight, AppColors.deepNavy],
                    ),
                  ),
                );
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.deepNavy.withValues(alpha: 0.48),
                    AppColors.deepNavy.withValues(alpha: 0.72),
                    AppColors.deepNavy.withValues(alpha: 0.94),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(compact ? 20 : 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _brand(light: true),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'FAZ PARTE DA NOSSA COMUNIDADE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    compact
                        ? 'A tua cidade.\nAs tuas escolhas.'
                        : 'Tudo o que precisas,\nà tua porta.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 27 : 39,
                      height: 1.12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Descobre restaurantes, lojas e serviços '
                    'locais em Nacala-Porto.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: compact ? 12 : 14,
                      height: 1.6,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 25),
                    _benefit(
                      Icons.restaurant_outlined,
                      'Descobre opções perto de ti',
                    ),
                    const SizedBox(height: 14),
                    _benefit(
                      Icons.shopping_bag_outlined,
                      'Faz os teus pedidos facilmente',
                    ),
                    const SizedBox(height: 14),
                    _benefit(
                      Icons.location_on_outlined,
                      'Recebe onde estiveres',
                    ),
                  ],
                  if (compact) const SizedBox(height: 5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _benefit(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 21),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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

  Widget _formCard({required bool wide}) {
    return Container(
      padding: EdgeInsets.all(wide ? 32 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepNavy.withValues(alpha: 0.055),
            blurRadius: 35,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Criar conta',
                        style: TextStyle(
                          color: AppColors.deepNavy,
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Preenche os teus dados para começar.',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: AppColors.primaryPressed,
                    size: 23,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 27),

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
                if (value == null || value.trim().length < 2) {
                  return 'Indica o teu nome.';
                }
                return null;
              },
            ),

            const SizedBox(height: 19),
            _label('EMAIL'),
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
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                  return 'Indica um email válido.';
                }
                return null;
              },
            ),

            const SizedBox(height: 19),
            _label('TELEMÓVEL'),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: _decoration(
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

            const SizedBox(height: 19),
            _label('PALAVRA-PASSE'),
            TextFormField(
              controller: _password,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              decoration: _decoration(
                hint: 'Cria uma palavra-passe',
                icon: Icons.lock_outline_rounded,
                suffix: _passwordSuffix(
                  _obscurePassword,
                  () => setState(() {
                    _obscurePassword = !_obscurePassword;
                  }),
                ),
              ),
              validator: (value) {
                final text = value ?? '';
                if (text.length < 8 ||
                    !RegExp(r'[A-Za-z]').hasMatch(text) ||
                    !RegExp(r'[0-9]').hasMatch(text)) {
                  return 'Usa pelo menos 8 caracteres, com letras e números.';
                }
                return null;
              },
            ),
            const SizedBox(height: 7),
            const Text(
              'Mínimo de 8 caracteres, incluindo letras e números.',
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),

            const SizedBox(height: 19),
            _label('CONFIRMAR PALAVRA-PASSE'),
            TextFormField(
              controller: _confirm,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: _decoration(
                hint: 'Repete a palavra-passe',
                icon: Icons.lock_reset_rounded,
                suffix: _passwordSuffix(
                  _obscureConfirm,
                  () => setState(() {
                    _obscureConfirm = !_obscureConfirm;
                  }),
                ),
              ),
              validator: (value) {
                if (value != _password.text) {
                  return 'As palavras-passe não coincidem.';
                }
                return null;
              },
            ),

            if (_error != null) ...[
              const SizedBox(height: 18),
              _errorBanner(_error!),
            ],

            const SizedBox(height: 25),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.55,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Criar a minha conta'),
                          SizedBox(width: 10),
                          Icon(Icons.arrow_forward_rounded, size: 19),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 18),
            const Text.rich(
              TextSpan(
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  height: 1.6,
                ),
                children: [
                  TextSpan(text: 'Ao criar conta aceitas os '),
                  TextSpan(
                    text: 'termos e condições',
                    style: TextStyle(
                      color: AppColors.primaryPressed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: ' e a política de privacidade.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Já tens conta?',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryPressed,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
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

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.dangerBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.dangerInk,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.dangerInk,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 850;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 30 : 18,
              vertical: 22,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 28),
                            child: _heroPanel(compact: false),
                          ),
                        ),
                        Expanded(flex: 6, child: _formCard(wide: true)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _heroPanel(compact: true),
                        const SizedBox(height: 20),
                        _formCard(wide: false),
                        const SizedBox(height: 22),
                        const Text(
                          'NACALA DELIVERY  •  FEITO PARA NACALA-PORTO',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.mutedLight,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
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
