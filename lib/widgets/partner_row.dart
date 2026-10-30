import 'package:flutter/material.dart';

import '../models/partner.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class PartnerRow extends StatelessWidget {
  const PartnerRow({super.key, required this.partner});

  final Partner partner;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: partner.tint,
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: Text(
              partner.initials,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partner.name,
                  style: TextStyle(
                    color: context.inkColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  partner.type,
                  style: TextStyle(color: context.mutedColor, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: partner.pending
                  ? AppColors.amberSoft
                  : AppColors.greenSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              partner.status,
              style: TextStyle(
                color: partner.pending
                    ? AppColors.amberInk
                    : AppColors.greenInk,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
