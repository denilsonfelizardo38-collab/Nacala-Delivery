import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

enum AppRole { customer, partner, admin }

/// Barra de troca de perfil. Só é apresentada no modo demonstração.
class RoleSwitcher extends StatelessWidget {
  const RoleSwitcher({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final AppRole selected;
  final ValueChanged<AppRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.cardColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text(
                'N',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Modo demonstração',
              style: TextStyle(
                color: context.mutedColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            _RoleButton(
              label: 'Cliente',
              selected: selected == AppRole.customer,
              onTap: () => onChanged(AppRole.customer),
            ),
            _RoleButton(
              label: 'Parceiro',
              selected: selected == AppRole.partner,
              onTap: () => onChanged(AppRole.partner),
            ),
            _RoleButton(
              label: 'Admin',
              selected: selected == AppRole.admin,
              onTap: () => onChanged(AppRole.admin),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? (context.isDarkMode
                      ? context.accentColor.withValues(alpha: 0.18)
                      : AppColors.paleBlue)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? context.accentColor : context.mutedColor,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
