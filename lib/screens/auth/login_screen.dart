import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../state/app_scope.dart';
import '../../widgets/common.dart';
import 'register_screen.dart';

const Color _loginOrange = Color(0xFFFF6B00);
const Color _loginOrangeDark = Color(0xFFE85D00);
const Color _loginOrangeSoft = Color(0xFFFFF0E5);
const Color _loginInk = Color(0xFF171717);
const Color _loginMuted = Color(0xFF777777);
const Color _loginBorder = Color(0xFFECECEC);
const Color _loginCanvas = Color(0xFFFAF9F7);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await AppScope.of(context).login(
        _identifier.text.trim(),
        _password.text,
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openRegister() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const RegisterScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: _loginCanvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 32 : 22,
                  vertical: 22,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: wide
                      ? _buildWideLayout(context)
                      : _buildMobileLayout(context),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopBar(context),
        const SizedBox(height: 28),
        _buildWelcomePanel(context, compact: true),
        const SizedBox(height: 22),
        _buildLoginCard(context),
        const SizedBox(height: 20),
        _buildRegisterPrompt(context),
        const SizedBox(height: 12),
        _buildFooter(context),
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 38, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(context, showBack: false),
                const SizedBox(height: 58),
                _buildWelcomePanel(context, compact: false),
                const SizedBox(height: 30),
                _buildFooter(context),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 420,
          child: _buildLoginCard(context),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context, {bool showBack = true}) {
    return Row(
      children: [
        if (showBack && widget.onBack != null) ...[
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Voltar',
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _loginOrange,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: _loginOrange.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
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
            const Text(
              'NACALA',
              style: TextStyle(
                color: _loginInk,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                height: 1.1,
              ),
            ),
            Text(
              'DELIVERY',
              style: TextStyle(
                color: _loginOrangeDark,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWelcomePanel(BuildContext context, {required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: _loginOrangeSoft,
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.waving_hand_rounded, color: _loginOrangeDark, size: 15),
              SizedBox(width: 7),
              Text(
                'É bom ter-te de volta',
                style: TextStyle(
                  color: _loginOrangeDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Bem-vindo de volta!',
          style: TextStyle(
            color: _loginInk,
            fontSize: compact ? 34 : 46,
            height: 1.04,
            letterSpacing: compact ? -1.1 : -1.8,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: const Text(
            'A tua próxima refeição está a poucos passos. Entra na tua conta e deixa o resto connosco.',
            style: TextStyle(
              color: _loginMuted,
              fontSize: 14,
              height: 1.65,
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 28),
          Row(
            children: [
              _BenefitIcon(icon: Icons.restaurant_rounded, label: 'Os teus\\nrestaurantes'),
              const SizedBox(width: 22),
              _BenefitIcon(icon: Icons.bolt_rounded, label: 'Pedido\\nsimples'),
              const SizedBox(width: 22),
              _BenefitIcon(icon: Icons.location_on_rounded, label: 'Entrega\\nlocal'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _loginBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _loginOrangeSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.lock_open_rounded,
                color: _loginOrangeDark,
                size: 21,
              ),
            ),
            const SizedBox(height: 17),
            const Text(
              'Entra na tua conta',
              style: TextStyle(
                color: _loginInk,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.45,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Usa os teus dados de acesso para continuar.',
              style: TextStyle(
                color: _loginMuted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            const _FieldLabel('EMAIL OU TELEFONE'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _identifier,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              style: const TextStyle(
                color: _loginInk,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: _inputDecoration(
                hint: 'Email ou telefone',
                icon: Icons.person_outline_rounded,
              ),
              validator: (value) =>
                  (value == null || value.trim().length < 3)
                  ? 'Indique o email ou telemóvel.'
                  : null,
            ),
            const SizedBox(height: 17),
            const _FieldLabel('PALAVRA-PASSE'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              autofillHints: const [AutofillHints.password],
              style: const TextStyle(
                color: _loginInk,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: _inputDecoration(
                hint: 'A tua palavra-passe',
                icon: Icons.lock_outline_rounded,
              ).copyWith(
                suffixIcon: IconButton(
                  tooltip: _obscure
                      ? 'Mostrar palavra-passe'
                      : 'Ocultar palavra-passe',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: _loginMuted,
                    size: 19,
                  ),
                ),
              ),
              validator: (value) =>
                  (value == null || value.isEmpty)
                  ? 'Indique a palavra-passe.'
                  : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _submitting
                    ? null
                    : () => showAppSnack(
                        context,
                        'A recuperação de palavra-passe não está '
                        'disponível nesta versão.',
                      ),
                style: TextButton.styleFrom(
                  foregroundColor: _loginOrangeDark,
                  minimumSize: const Size(44, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Esqueceu a palavra-passe?'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 5),
              _ErrorBanner(message: _error!),
            ],
            const SizedBox(height: 9),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _loginOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _loginOrange.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Entrar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 9),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 19),
            Row(
              children: [
                const Expanded(child: Divider(color: _loginBorder)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'ou continua com',
                    style: TextStyle(
                      color: _loginMuted.withValues(alpha: 0.9),
                      fontSize: 10,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: _loginBorder)),
              ],
            ),
            const SizedBox(height: 16),
            GoogleSignInButton(
              onPressed: _submitting
                  ? null
                  : () => showAppSnack(
                      context,
                      'A entrada com Google ainda não está '
                      'ativa. Falta configurar o OAuth do Google '
                      'e a validação segura no servidor.',
                    ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFFAAAAAA),
        fontSize: 13,
      ),
      prefixIcon: Icon(icon, color: _loginOrangeDark, size: 19),
      filled: true,
      fillColor: const Color(0xFFFCFCFC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 16,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _loginBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _loginOrange, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFD94343)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFD94343), width: 1.4),
      ),
    );
  }

  Widget _buildRegisterPrompt(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 3,
      children: [
        const Text(
          'Ainda não tens conta?',
          style: TextStyle(color: _loginMuted, fontSize: 12),
        ),
        TextButton(
          onPressed: _submitting ? null : _openRegister,
          style: TextButton.styleFrom(
            foregroundColor: _loginOrangeDark,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: const Text('Criar conta'),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.location_on_outlined,
          color: _loginOrange,
          size: 14,
        ),
        const SizedBox(width: 5),
        Text(
          'Feito para Nacala-Porto',
          style: TextStyle(
            color: _loginMuted.withValues(alpha: 0.85),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _loginInk,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _BenefitIcon extends StatelessWidget {
  const _BenefitIcon({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _loginOrangeSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _loginOrangeDark, size: 19),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: _loginInk,
            fontSize: 10,
            height: 1.35,
            fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF4CCCC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFC62828),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFC62828),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
