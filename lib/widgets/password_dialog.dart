import 'package:flutter/material.dart';

/// Pede a palavra-passe atual e a nova, com validação local.
///
/// Devolve `(atual, nova)` ou `null` se o utilizador cancelar.
Future<(String, String)?> showPasswordDialog(BuildContext context) {
  return showDialog<(String, String)>(
    context: context,
    builder: (_) => const PasswordDialog(),
  );
}

class PasswordDialog extends StatefulWidget {
  const PasswordDialog({super.key});

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Alterar palavra-passe'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Palavra-passe atual',
              ),
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Indique a palavra-passe atual.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _next,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nova palavra-passe',
              ),
              validator: (value) {
                final text = value ?? '';
                if (text.length < 8 ||
                    !RegExp(r'[A-Za-z]').hasMatch(text) ||
                    !RegExp(r'[0-9]').hasMatch(text)) {
                  return 'Mínimo 8 caracteres, com letras e números.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Repetir nova palavra-passe',
              ),
              validator: (value) =>
                  value != _next.text ? 'Não coincidem.' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop((_current.text, _next.text));
          },
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: const Text('Alterar'),
        ),
      ],
    );
  }
}
