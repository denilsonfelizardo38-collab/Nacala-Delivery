import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../utils/feedback.dart';
import '../../utils/formatters.dart';
import '../../widgets/dashboard_header.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/partner_row.dart';
import '../../widgets/quick_action.dart';
import '../../widgets/section_heading.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final pendingPartners = mockPartners
        .where((partner) => partner.pending)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        const DashboardHeader(
          eyebrow: 'ADMINISTRAÇÃO',
          title: 'Visão geral',
          subtitle: 'Operação Nacala-Porto',
          icon: Icons.dashboard_rounded,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MOVIMENTO DE HOJE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '48.650 MT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${state.orders.length} pedidos na app · +8,4% esta semana',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'Parceiros ativos',
                value: '${mockPlaces.length}',
                change: '${mockPlaces.length - pendingPartners} aprovados',
                icon: Icons.storefront_outlined,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: MetricCard(
                label: 'A aguardar',
                value: '$pendingPartners',
                change: 'Aprovação',
                icon: Icons.pending_actions_rounded,
              ),
            ),
          ],
        ),
        if (state.orders.isNotEmpty) ...[
          const SizedBox(height: 11),
          MetricCard(
            label: 'Receita registada na app',
            value: formatMoney(
              state.orders.fold(0, (sum, order) => sum + order.total),
            ),
            change: '${state.orders.length} pedidos locais',
            icon: Icons.trending_up_rounded,
            positive: true,
          ),
        ],
        const SizedBox(height: 23),
        const SectionHeading(
          title: 'Parceiros registados',
          trailing: 'Gerir todos',
        ),
        const SizedBox(height: 12),
        for (final partner in mockPartners)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PartnerRow(partner: partner),
          ),
        const SizedBox(height: 12),
        const SectionHeading(title: 'Acesso rápido'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: QuickAction(
                icon: Icons.approval_rounded,
                label: 'Aprovações',
                onTap: () => showMessage(context, 'Aprovações em breve.'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: QuickAction(
                icon: Icons.delivery_dining_rounded,
                label: 'Entregas',
                onTap: () =>
                    showMessage(context, 'Gestão de entregas em breve.'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: QuickAction(
                icon: Icons.bar_chart_rounded,
                label: 'Relatórios',
                onTap: () => showMessage(context, 'Relatórios em breve.'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
