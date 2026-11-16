import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'common.dart';

const _defaultMessage =
    'Este código substitui a recuperação por email/SMS: anota-o ou copia-o '
    'agora, porque não volta a ser mostrado. É a tua forma de repor a '
    'palavra-passe se um dia a esqueceres.';

/// Mostra o código de recuperação de palavra-passe (devolvido pelo servidor
/// uma única vez, no registo ou na rotação).
///
/// A plataforma não envia emails nem SMS (não há SMTP/SMS configurados), por
/// isso o diálogo obriga a uma confirmação explícita de que o utilizador
/// guardou o código antes de avançar. Devolve `true` quando confirmado.
Future<bool> showRecoveryCodeDialog(
  BuildContext context, {
  required String code,
  String title = 'Guarda o teu código de recuperação',
  String message = _defaultMessage,
  String confirmLabel = 'Já guardei o código',
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: .45)),
            ),
            child: SelectableText(
              code,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                letterSpacing: 3,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (dialogContext.mounted) {
                  showAppSnack(dialogContext, 'Código copiado.');
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 17),
              label: const Text('Copiar código'),
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
