import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

import '../../core/api_client.dart';
import '../../state/app_scope.dart';
import '../../widgets/common.dart';
import 'register_screen.dart';

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
      await AppScope.of(context).login(_identifier.text.trim(), _password.text);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _openRegister() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const RegisterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fotografia usada também na WelcomeScreen.
          Image.asset(
            'assets/images/login_bg.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) {
              return const ColoredBox(color: AppColors.deepNavy);
            },
          ),

          // Gradiente azul-marinho para integrar o formulário
          // com a fotografia.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x88001635),
                  Color(0x66001635),
                  Color(0xAA001A38),
                  Color(0xF5001835),
                ],
                stops: [0.0, 0.30, 0.62, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;

                return Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 32 : 22,
                      vertical: 22,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1050),
                      child: wide
                          ? _buildWideLayout(context)
                          : _buildMobileLayout(context),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // LAYOUT MOBILE
  // --------------------------------------------------

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopBar(context),
        const SizedBox(height: 28),
        _buildWelcomePanel(compact: true),
        const SizedBox(height: 25),
        _buildLoginCard(context),
        const SizedBox(height: 15),
        _buildRegisterPrompt(),
        const SizedBox(height: 12),
        _buildFooter(),
      ],
    );
  }

  // --------------------------------------------------
  // LAYOUT DESKTOP / TABLET
  // --------------------------------------------------

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 42, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(context, showBack: false),
                const SizedBox(height: 65),
                _buildWelcomePanel(compact: false),
                const SizedBox(height: 35),
                _buildFooter(),
              ],
            ),
          ),
        ),
        SizedBox(width: 430, child: _buildLoginCard(context)),
      ],
    );
  }

  // --------------------------------------------------
  // CABEÇALHO
  // --------------------------------------------------

  Widget _buildTopBar(BuildContext context, {bool showBack = true}) {
    return Row(
      children: [
        if (showBack && widget.onBack != null) ...[
          Material(
            color: Colors.white.withValues(alpha: 0.13),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Voltar',
              onPressed: widget.onBack,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],

        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.30),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.delivery_dining_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),

        const SizedBox(width: 11),

        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NACALA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                height: 1.1,
              ),
            ),
            Text(
              'DELIVERY',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --------------------------------------------------
  // APRESENTAÇÃO
  // --------------------------------------------------

  Widget _buildWelcomePanel({required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.waving_hand_rounded,
                color: AppColors.primary,
                size: 16,
              ),
              SizedBox(width: 7),
              Text(
                'É bom ter-te de volta',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 19),

        Text(
          'Bem-vindo de volta!',
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 36 : 49,
            height: 1.04,
            letterSpacing: -1.5,
            fontWeight: FontWeight.w700,
            shadows: const [
              Shadow(
                color: Colors.black45,
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
        ),

        const SizedBox(height: 13),

        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 370),
          child: Text(
            'A tua próxima refeição está a poucos passos. '
            'Entra na tua conta e deixa o resto connosco.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.90),
              fontSize: 14,
              height: 1.7,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 32),
          Row(
            children: [
              _BenefitIcon(
                icon: Icons.restaurant_rounded,
                label: 'Os teus\nrestaurantes',
              ),
              const SizedBox(width: 20),
              _BenefitIcon(icon: Icons.bolt_rounded, label: 'Pedido\nsimples'),
              const SizedBox(width: 20),
              _BenefitIcon(
                icon: Icons.location_on_rounded,
                label: 'Entrega\nlocal',
              ),
            ],
          ),
        ],
      ],
    );
  }

  // --------------------------------------------------
  // CARTÃO DE LOGIN
  // --------------------------------------------------

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
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
            // ÍCONE DO LOGIN.
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.lock_open_rounded,
                color: AppColors.primaryPressed,
                size: 23,
              ),
            ),

            const SizedBox(height: 17),

            const Text(
              'Entra na tua conta',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Usa os teus dados de acesso para continuar.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 25),

            // EMAIL OU TELEFONE.
            const _FieldLabel('EMAIL OU TELEFONE'),

            const SizedBox(height: 9),

            TextFormField(
              controller: _identifier,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: _inputDecoration(
                hint: 'Email ou telefone',
                icon: Icons.person_outline_rounded,
              ),
              validator: (value) {
                if (value == null || value.trim().length < 3) {
                  return 'Indique o email ou telemóvel.';
                }
                return null;
              },
            ),

            const SizedBox(height: 18),

            // PALAVRA-PASSE.
            const _FieldLabel('PALAVRA-PASSE'),

            const SizedBox(height: 9),

            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              autofillHints: const [AutofillHints.password],
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration:
                  _inputDecoration(
                    hint: 'A tua palavra-passe',
                    icon: Icons.lock_outline_rounded,
                  ).copyWith(
                    suffixIcon: IconButton(
                      tooltip: _obscure
                          ? 'Mostrar palavra-passe'
                          : 'Ocultar palavra-passe',
                      onPressed: () {
                        setState(() => _obscure = !_obscure);
                      },
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.muted,
                        size: 19,
                      ),
                    ),
                  ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Indique a palavra-passe.';
                }
                return null;
              },
            ),

            // RECUPERAÇÃO DA PALAVRA-PASSE.
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _submitting
                    ? null
                    : () {
                        showAppSnack(
                          context,
                          'A recuperação de palavra-passe não está '
                          'disponível nesta versão.',
                        );
                      },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryPressed,
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

            // ERRO DE AUTENTICAÇÃO.
            if (_error != null) ...[
              const SizedBox(height: 5),
              _ErrorBanner(message: _error!),
            ],

            const SizedBox(height: 10),

            // BOTÃO ENTRAR.
            SizedBox(
              height: 55,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 3,
                  shadowColor: AppColors.primary.withValues(alpha: 0.25),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 21,
                        height: 21,
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
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 9),
                          Icon(Icons.arrow_forward_rounded, size: 19),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 21),

            // SEPARADOR.
            Row(
              children: [
                const Expanded(child: Divider(color: AppColors.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'ou continua com',
                    style: TextStyle(
                      color: AppColors.muted.withValues(alpha: 0.9),
                      fontSize: 10,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: AppColors.border)),
              ],
            ),

            const SizedBox(height: 17),

            // GOOGLE.
            GoogleSignInButton(
              onPressed: _submitting
                  ? null
                  : () {
                      showAppSnack(
                        context,
                        'A entrada com Google ainda não está '
                        'ativa. Falta configurar o OAuth do Google '
                        'e a validação segura no servidor.',
                      );
                    },
            ),

            const SizedBox(height: 12),

            // CONTAS DE EXPLORAÇÃO (cliente, parceiro, estafeta, admin).
            _buildDemoAccountsEntry(),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // CONTAS DE DEMONSTRAÇÃO
  // --------------------------------------------------

  Widget _buildDemoAccountsEntry() {
    return TextButton.icon(
      onPressed: _submitting ? null : _showDemoAccountsSheet,
      icon: const Icon(Icons.explore_outlined, size: 16),
      label: const Text('Contas para explorar'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.muted,
        minimumSize: const Size(44, 40),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  /// Folha com as contas semeada pelo servidor. Tocar em «Usar» preenche
  /// o formulário e entra — assim o utilizador descobre as áreas de
  /// parceiro, estafeta e administração que existem na plataforma.
  Future<void> _showDemoAccountsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Contas para explorar',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'O servidor cria estas contas de demonstração. Toca em '
                '«Usar» para preencher o formulário e entrar.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              for (final account in _demoAccounts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(11, 9, 5, 9),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: AppColors.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            account.icon,
                            color: AppColors.primary,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.roleLabel,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                account.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _identifier.text = account.email;
                              _password.text = account.password;
                              _error = null;
                            });
                            Navigator.of(sheetContext).pop();
                            _submit();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryPressed,
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('Usar'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              const Text(
                'No plano gratuito do Render, os dados de demonstração são '
                'repostos a cada reinício do serviço.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 9.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // ESTILO DOS CAMPOS
  // --------------------------------------------------

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.mutedLight, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.primaryPressed, size: 19),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
      ),
    );
  }

  // --------------------------------------------------
  // REGISTO
  // --------------------------------------------------

  Widget _buildRegisterPrompt() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 3,
      children: [
        const Text(
          'Ainda não tens conta?',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
        TextButton(
          onPressed: _submitting ? null : _openRegister,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Criar conta'),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // RODAPÉ
  // --------------------------------------------------

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.location_on_outlined,
          color: AppColors.primary,
          size: 15,
        ),
        const SizedBox(width: 5),
        Text(
          'Feito para Nacala-Porto',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------
// RÓTULO DOS CAMPOS
// --------------------------------------------------

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

// --------------------------------------------------
// BENEFÍCIOS
// --------------------------------------------------

class _BenefitIcon extends StatelessWidget {
  const _BenefitIcon({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------
// MENSAGEM DE ERRO
// --------------------------------------------------

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dangerBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.dangerInk,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.dangerInk,
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

/// Contas de demonstração criadas pelo seed do servidor (dados oficiais
/// da plataforma para testar cada área com um toque).
class _DemoAccount {
  const _DemoAccount(this.roleLabel, this.email, this.password, this.icon);

  final String roleLabel;
  final String email;
  final String password;
  final IconData icon;
}

const _demoAccounts = [
  _DemoAccount(
    'Cliente',
    'cliente@nacala.co.mz',
    'Cliente@1234',
    Icons.person_rounded,
  ),
  _DemoAccount(
    'Parceiro · Cantinho da Baía',
    'cantinho@nacala.co.mz',
    'Parceiro@1234',
    Icons.storefront_rounded,
  ),
  _DemoAccount(
    'Estafeta',
    'estafeta@nacala.co.mz',
    'Estafeta@1234',
    Icons.delivery_dining_rounded,
  ),
  _DemoAccount(
    'Administração',
    'admin@nacala.co.mz',
    'Admin@1234',
    Icons.shield_rounded,
  ),
];
