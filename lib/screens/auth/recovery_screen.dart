import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/recovery_code.dart';
import '../../state/app_scope.dart';

/// Recuperação da palavra-passe com o **código de recuperação** gerado no
/// registo (a plataforma não envia emails nem SMS — não há SMTP/SMS
/// configurados, por isso o código é mostrado uma vez no registo e guardado
/// pelo utilizador).
///
/// Rota: `/recover`. Em caso de sucesso o servidor valida o código, troca a
/// palavra-passe, rotação do código e devolve uma sessão nova (auto-login);
/// o ecrã mostra o novo código (única vez) e recua até à Home já autenticado.
class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
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
      final newCode = await AppScope.of(context).recoverPassword(
        identifier: _identifier.text.trim(),
        code: _code.text.trim(),
        password: _password.text,
      );

      if (!mounted) return;
      // Código rotacionado no servidor: mostrar uma única vez.
      if (newCode != null && newCode.isNotEmpty) {
        await showRecoveryCodeDialog(
          context,
          title: 'Nova palavra-passe definida',
          message:
              'A tua palavra-passe foi alterada e a sessão já está aberta. '
              'Este é o novo código de recuperação — guarda-o, substitui o '
              'anterior e não volta a ser mostrado.',
          code: newCode,
        );
      }
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível recuperar a conta. Tenta novamente.';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _topBar(),
                  const SizedBox(height: 28),
                  const Text(
                    'Recuperar palavra-passe',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      height: 1.1,
                      letterSpacing: -0.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Usa o código de recuperação que recebeste ao criar a '
                    'conta. Ao concluir, o código é substituído por um novo '
                    '(mostrado uma única vez).',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label('EMAIL OU TELEMÓVEL'),
                          TextFormField(
                            controller: _identifier,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            style: const TextStyle(color: Colors.white),
                            decoration: _decoration(
                              hint: 'exemplo@email.com ou 84 123 4567',
                              icon: Icons.person_outline_rounded,
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.length < 3) {
                                return 'Indica o email ou telemóvel da conta.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _label('CÓDIGO DE RECUPERAÇÃO'),
                          TextFormField(
                            controller: _code,
                            textCapitalization: TextCapitalization.characters,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            enableSuggestions: false,
                            style: const TextStyle(
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                            decoration: _decoration(
                              hint: 'XXXXX-XXXXX',
                              icon: Icons.password_rounded,
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.length < 6) {
                                return 'Indica o código de recuperação.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _label('NOVA PALAVRA-PASSE'),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            enableSuggestions: false,
                            style: const TextStyle(color: Colors.white),
                            decoration: _decoration(
                              hint: 'Nova palavra-passe',
                              icon: Icons.lock_outline_rounded,
                              suffix: IconButton(
                                tooltip: _obscure
                                    ? 'Mostrar palavra-passe'
                                    : 'Ocultar palavra-passe',
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
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
                              final text = value ?? '';
                              if (text.length < 8 ||
                                  !RegExp(r'[A-Za-z]').hasMatch(text) ||
                                  !RegExp(r'[0-9]').hasMatch(text)) {
                                return 'Usa pelo menos 8 caracteres, com '
                                    'letras e números.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _label('CONFIRMAR NOVA PALAVRA-PASSE'),
                          TextFormField(
                            controller: _confirm,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            autocorrect: false,
                            enableSuggestions: false,
                            style: const TextStyle(color: Colors.white),
                            decoration: _decoration(
                              hint: 'Repete a nova palavra-passe',
                              icon: Icons.lock_reset_rounded,
                            ),
                            validator: (value) {
                              if (value != _password.text) {
                                return 'As palavras-passe não coincidem.';
                              }
                              return null;
                            },
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.dangerInk.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.dangerInk.withValues(
                                    alpha: 0.5,
                                  ),
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
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 54,
                            child: FilledButton(
                              onPressed: _submitting ? null : _submit,
                              style: FilledButton.styleFrom(
                                disabledBackgroundColor: AppColors.primary
                                    .withValues(alpha: 0.5),
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
                                  : const Text(
                                      'Recuperar e entrar',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryPressed,
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Voltar ao início de sessão'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Perdeste o código? Entra na tua conta e gera um novo em '
                    '"Código de recuperação", ou contacta a equipa da '
                    'plataforma.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11.5,
                      height: 1.5,
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

  /// Cabeçalho de auth: botão circular de voltar + lockup da marca
  /// (mesmo padrão do LoginScreen e da seleção de tipo).
  Widget _topBar() {
    return Row(
      children: [
        if (Navigator.of(context).canPop()) ...[
          Material(
            color: AppColors.darkCard,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Voltar',
              onPressed: () => Navigator.of(context).maybePop(),
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
            borderRadius: BorderRadius.circular(14),
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
}
