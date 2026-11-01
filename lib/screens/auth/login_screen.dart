import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: widget.onBack == null
                            ? null
                            : IconButton(
                                tooltip: 'Voltar',
                                onPressed: widget.onBack,
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                      ),
                      const AppLogo(size: 42),
                      const SizedBox(width: 10),
                      Text(
                        'Nacala Entrega',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Bem-vindo de volta!',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontSize: 27, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A tua próxima refeição está a poucos passos.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Entra na tua conta',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _identifier,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email,
                            ],
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Email ou telefone',
                              prefixIcon: Icon(
                                Icons.mail_outline_rounded,
                                color: AppColors.primary,
                                size: 19,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                            ),
                            validator: (value) =>
                                (value == null || value.trim().length < 3)
                                ? 'Indique o email ou telemóvel.'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            autofillHints: const [AutofillHints.password],
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Palavra-passe',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                                color: AppColors.primary,
                                size: 19,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _obscure
                                    ? 'Mostrar palavra-passe'
                                    : 'Ocultar palavra-passe',
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 19,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
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
                                minimumSize: const Size(44, 38),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                textStyle: const TextStyle(fontSize: 11),
                              ),
                              child: const Text('Esqueceu a palavra-passe?'),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            _ErrorBanner(message: _error!),
                          ],
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: _submitting ? null : _submit,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 19,
                                    height: 19,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Entrar'),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: Divider(color: AppColors.border)),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  'ou',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.muted),
                                ),
                              ),
                              Expanded(child: Divider(color: AppColors.border)),
                            ],
                          ),
                          const SizedBox(height: 14),
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
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      Text(
                        'Ainda não tens conta?',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.muted),
                      ),
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              ),
                        child: const Text('Criar conta'),
                      ),
                    ],
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
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 18,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              message,

              style: const TextStyle(
                color: AppColors.danger,
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
