import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    this.addLabel = 'Adicionar',
  });

  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    if (quantity == 0) {
      return IconButton.filledTonal(
        onPressed: onAdd,
        tooltip: addLabel,
        icon: const Icon(Icons.add_rounded, size: 20),
        style: IconButton.styleFrom(
          backgroundColor: accent.withValues(alpha: 0.12),
          foregroundColor: accent,
          minimumSize: const Size(38, 38),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: quantity == 1
                ? Icons.delete_outline_rounded
                : Icons.remove_rounded,
            onTap: onRemove,
            tooltip: quantity == 1 ? 'Remover' : 'Diminuir',
          ),
          SizedBox(
            width: 26,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.inkColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            onTap: onAdd,
            tooltip: 'Aumentar',
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      color: context.accentColor,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      visualDensity: VisualDensity.compact,
    );
  }
}
