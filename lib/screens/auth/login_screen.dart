
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
      await AppScope.of(context).login(
        _identifier.text.trim(),
        _password.text,
      );
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
      backgroundColor: const Color.fromARGB(255, 252, 251, 251),

      body: Container(
        width: double.infinity,
        height: double.infinity,

        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/login_bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),

        child: Container(
          color: Colors.black.withOpacity(0.35),

          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 28,
                ),

                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,

                    children: [
                      const Center(
                        child: AppLogo(size: 68),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        'Nacala Entrega',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color.fromARGB(255, 0, 0, 0),
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 4),

                      const Text(
                        'A sua cidade, entregue à porta.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color.fromARGB(255, 0, 68, 214),
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 26),

                      Container(
                        padding: const EdgeInsets.all(20),

                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: context.lineColor,
                          ),
                        ),

                        child: Form(
                          key: _formKey,

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,

                            children: [
                              Text(
                                'Entrar na sua conta',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),

                              const SizedBox(height: 4),

                              Text(
                                'Use o email ou o telemóvel associado à conta.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: context.mutedColor,
                                    ),
                              ),

                              const SizedBox(height: 20),

                              TextFormField(
                                controller: _identifier,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,

                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                ],

                                decoration: const InputDecoration(
                                  labelText: 'Email ou telemóvel',
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                ),

                                validator: (value) =>
                                    (value == null ||
                                        value.trim().length < 3)
                                    ? 'Indique o email ou telemóvel.'
                                    : null,
                              ),

                              const SizedBox(height: 12),

                              TextFormField(
                                controller: _password,
                                obscureText: _obscure,
                                textInputAction: TextInputAction.done,

                                onFieldSubmitted: (_) => _submit(),

                                autofillHints: const [
                                  AutofillHints.password,
                                ],

                                decoration: InputDecoration(
                                  labelText: 'Palavra-passe',

                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                  ),

                                  suffixIcon: IconButton(
                                    tooltip: _obscure
                                        ? 'Mostrar palavra-passe'
                                        : 'Ocultar palavra-passe',

                                    onPressed: () {
                                      setState(() {
                                        _obscure = !_obscure;
                                      });
                                    },

                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                    ),
                                  ),
                                ),

                                validator: (value) =>
                                    (value == null || value.isEmpty)
                                    ? 'Indique a palavra-passe.'
                                    : null,
                              ),

                              if (_error != null) ...[
                                const SizedBox(height: 14),

                                _ErrorBanner(message: _error!),
                              ],

                              const SizedBox(height: 18),

                              FilledButton(
                                onPressed: _submitting ? null : _submit,

                                child: _submitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,

                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Entrar'),
                              ),

                              const SizedBox(height: 8),

                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment:
                                    WrapCrossAlignment.center,

                                children: [
                                  Text(
                                    'Ainda não tem conta?',
                                    style: TextStyle(
                                      color: context.mutedColor,
                                      fontSize: 13,
                                    ),
                                  ),

                                  TextButton(
                                    onPressed: _submitting
                                        ? null
                                        : () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const RegisterScreen(),
                                              ),
                                            );
                                          },

                                    child: const Text('Criar conta'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
