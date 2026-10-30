import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/dashboard_header.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/order_row.dart';
import '../../widgets/quick_action.dart';
import '../../widgets/section_heading.dart';
import '../../utils/feedback.dart';

class PartnerDashboard extends StatelessWidget {
  const PartnerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final orders = state.orders;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        const DashboardHeader(
          eyebrow: 'PAINEL DO PARCEIRO',
          title: 'Cantinho da Baía',
          subtitle: 'Restaurante · Nacala-Porto',
          icon: Icons.restaurant_rounded,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: context.isDarkMode
                ? AppColors.greenSoft.withValues(alpha: 0.14)
                : AppColors.greenSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.circle, color: AppColors.green, size: 11),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Loja aberta para receber pedidos',
                  style: TextStyle(
                    color: context.isDarkMode
                        ? const Color(0xFF7ED9A6)
                        : AppColors.greenInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.isDarkMode
                    ? const Color(0xFF7ED9A6)
                    : AppColors.greenInk,
              ),
            ],
          ),
        ),
        const SizedBox(height: 19),
        const Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'Vendas hoje',
                value: '8.450 MT',
                change: '+12%',
                icon: Icons.payments_outlined,
                positive: true,
              ),
            ),
            SizedBox(width: 11),
            Expanded(
              child: MetricCard(
                label: 'Pedidos',
                value: '12',
                change: '3 novos',
                icon: Icons.receipt_long_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        const Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'Gastos',
                value: '2.100 MT',
                change: 'Esta semana',
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            SizedBox(width: 11),
            Expanded(
              child: MetricCard(
                label: 'A receber',
                value: '6.350 MT',
                change: 'Próximo repasse',
                icon: Icons.savings_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SectionHeading(title: 'Pedidos recentes', trailing: 'Ver todos'),
        const SizedBox(height: 12),
        if (orders.isNotEmpty)
          for (final order in orders.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OrderRow(
                number: order.id,
                customer: order.address,
                details: '${order.itemCount} itens · ${order.place.name}',
                amount: formatMoney(order.total),
                status: order.status.label,
                statusColor: _statusColor(context, order.status),
              ),
            )
        else ...[
          OrderRow(
            number: '#NC-1048',
            customer: 'Amélia M.',
            details: '2 itens · Frango grelhado',
            amount: '1.250 MT',
            status: OrderStatus.received.label,
            statusColor: context.accentColor,
          ),
          const SizedBox(height: 10),
          OrderRow(
            number: '#NC-1047',
            customer: 'Paulo C.',
            details: '1 item · Caril de camarão',
            amount: '980 MT',
            status: OrderStatus.preparing.label,
            statusColor: AppColors.amberInk,
          ),
          const SizedBox(height: 10),
          OrderRow(
            number: '#NC-1046',
            customer: 'Lina S.',
            details: '3 itens · Menu família',
            amount: '2.400 MT',
            status: OrderStatus.onTheWay.label,
            statusColor: AppColors.greenInk,
          ),
        ],
        const SizedBox(height: 22),
        const SectionHeading(title: 'Gestão rápida'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: QuickAction(
                icon: Icons.restaurant_menu_rounded,
                label: 'Meu menu',
                onTap: () => showMessage(context, 'Gestão do menu em breve.'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: QuickAction(
                icon: Icons.receipt_long_rounded,
                label: 'Despesas',
                onTap: () =>
                    showMessage(context, 'Registo de despesas em breve.'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: QuickAction(
                icon: Icons.storefront_rounded,
                label: 'Minha loja',
                onTap: () =>
                    showMessage(context, 'Configuração da loja em breve.'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Color _statusColor(BuildContext context, OrderStatus status) =>
      switch (status) {
        OrderStatus.received => context.accentColor,
        OrderStatus.preparing => AppColors.amberInk,
        OrderStatus.onTheWay => AppColors.greenInk,
        OrderStatus.delivered => AppColors.green,
      };
}
