import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Ecrãs informativos da conta: métodos de pagamento (estado real da
/// integração), ajuda e suporte, termos e política de privacidade.
///
/// Todo o conteúdo é descritivo — não se inventam números de apoio,
/// credenciais nem estados de pagamento não integrados.
class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InfoScaffold(
      title: 'Métodos de pagamento',
      icon: Icons.payments_outlined,
      children: [
        _OptionRow(
          icon: Icons.phone_android_rounded,
          title: 'M-Pesa',
          subtitle: 'Preparado para integração · cobrança automática pendente',
          tone: _RowTone.pending,
        ),
        SizedBox(height: 10),
        _OptionRow(
          icon: Icons.account_balance_wallet_outlined,
          title: 'e-Mola',
          subtitle: 'Preparado para integração · cobrança automática pendente',
          tone: _RowTone.pending,
        ),
        SizedBox(height: 10),
        _OptionRow(
          icon: Icons.payments_outlined,
          title: 'Dinheiro na entrega',
          subtitle: 'Ativo · pagas ao estafeta ao receber o pedido',
          tone: _RowTone.active,
        ),
        SizedBox(height: 16),
        _InfoParagraph(
          title: 'Como fica um pedido suspenso na integração',
          body:
              'Enquanto a cobrança automática M-Pesa/e-Mola não estiver '
              'ativa, um pedido pago por telemóvel é registado com '
              '"pagamento pendente de integração". O estabelecimento '
              'confirma o pedido e o pagamento é combinado na entrega. '
              'O app nunca marca um pedido como pago sem confirmação da '
              'operadora.',
        ),
      ],
    );
  }
}

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InfoScaffold(
      title: 'Ajuda e suporte',
      icon: Icons.support_agent_rounded,
      children: [
        _InfoParagraph(
          title: 'Contacto da plataforma',
          body:
              'Problemas com um pedido, conta ou parceiro? Escreve à '
              'equipa Nacala Delivery. Guardamos sempre o número do '
              'pedido para agilizar a resposta.',
        ),
        SizedBox(height: 10),
        _SupportEmailRow(),
        SizedBox(height: 16),
        _FaqRow(
          question: 'Como faço um pedido?',
          answer:
              'Escolhe um estabelecimento, adiciona produtos ao carrinho, '
              'confirma a morada (o GPS preenche por ti) e finaliza o '
              'pedido. O parceiro aceita e prepara.',
        ),
        _FaqRow(
          question: 'Como acompanho a entrega?',
          answer:
              'No "Pedidos", toca no pedido: a linha temporal mostra o '
              'estado real. Quando o estafeta partir, a posição aparece '
              'no mapa enquanto a partilha GPS estiver ativa.',
        ),
        _FaqRow(
          question: 'Posso cancelar um pedido?',
          answer:
              'Sim, enquanto estiver no estado "recebido" ou '
              '"confirmado". Depois da preparação avançar, contacta o '
              'estabelecimento.',
        ),
        _FaqRow(
          question: 'Não recebi o meu pedido',
          answer:
              'Confirma o estado em "Pedidos". Se algo estiver errado, '
              'usa o contacto desta página referindo o número do pedido.',
        ),
      ],
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InfoScaffold(
      title: 'Termos e condições',
      icon: Icons.article_outlined,
      children: [
        _InfoParagraph(
          title: 'Utilização da aplicação',
          body:
              'A Nacala Delivery intermedeia pedidos entre clientes e '
              'parceiros de Nacala-Porto. O utilizador compromete-se a '
              'fornecer dados verdadeiros e a usar a plataforma para '
              'pedidos de boa-fé.',
        ),
        _InfoParagraph(
          title: 'Responsabilidade dos parceiros',
          body:
              'Preços, disponibilidade e preparação dos produtos são da '
              'responsabilidade de cada parceiro. Os totais dos pedidos '
              'são verificados no servidor no momento da confirmação.',
        ),
        _InfoParagraph(
          title: 'Entregas',
          body:
              'Cada entrega tem taxa própria, mostrada antes de '
              'finalizar. Atribuição e pagamento ao estafeta são '
              'processados pela plataforma.',
        ),
        _InfoParagraph(
          title: 'Cancelamentos e reembolsos',
          body:
              'Pedidos podem ser cancelados pelo cliente enquanto não '
              'saem para preparação, ou pelo parceiro com justificação. '
              'Valores obtidos por integrações de pagamento seguem a '
              'política da operadora após aprovação do cancelamento.',
        ),
      ],
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InfoScaffold(
      title: 'Política de privacidade',
      icon: Icons.shield_outlined,
      children: [
        _InfoParagraph(
          title: 'Dados que recolhemos',
          body:
              'Nome, email e telemóvel da conta, moradas de entrega '
              '(com coordenadas para o rastreamento) e histórico de '
              'pedidos. As palavras-passe são guardadas com hash e salt, '
              'nunca em texto simples.',
        ),
        _InfoParagraph(
          title: 'Localização',
          body:
              'O GPS é usado apenas quando pedes o preenchimento '
              'automático da morada ou quando o estafeta partilha a '
              'posição numa entrega ativa. A câmara/galeria só é '
              'lida quando escolhes uma fotografia de perfil.',
        ),
        _InfoParagraph(
          title: 'Partilha de dados',
          body:
              'Os parceiros só veem os dados necessários para '
              'executar o teu pedido (nome, morada e contacto do '
              'pedido). O estafeta vê apenas as entregas que lhe '
              'foram atribuídas com os dados necessários à entrega.',
        ),
        _InfoParagraph(
          title: 'Os seus dados no ecrã da conta',
          body:
              'Email e telemóvel aparecem mascarados por omissão; '
              'revelá-los é uma ação intencional sua.',
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// Componentes partilhados destes ecrãs.
// --------------------------------------------------------------------------

enum _RowTone { active, pending }

class _InfoScaffold extends StatelessWidget {
  const _InfoScaffold({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 16),
            ...children,
            const SizedBox(height: 24),
            Text(
              'NACALA DELIVERY · pedido feito, entrega garantida',
              style: TextStyle(
                color: context.mutedColor.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _RowTone tone;

  @override
  Widget build(BuildContext context) {
    final isInDark = context.isDarkMode;
    final (bg, fg, badge) = switch (tone) {
      _RowTone.active => (
        isInDark ? AppColors.darkElevated : AppColors.successSoft,
        context.successColor,
        'ATIVO',
      ),
      _RowTone.pending => (
        context.primarySoftColor,
        context.accentColor,
        'EM BREVE',
      ),
    };
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isInDark ? AppColors.darkCard : Colors.white,
        border: Border.all(color: context.lineColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: fg, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      badge,
                      style: TextStyle(
                        color: fg,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.mutedColor,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoParagraph extends StatelessWidget {
  const _InfoParagraph({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border.all(color: context.lineColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: context.mutedColor,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqRow extends StatelessWidget {
  const _FaqRow({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return _InfoParagraph(title: question, body: answer);
  }
}

class _SupportEmailRow extends StatelessWidget {
  const _SupportEmailRow();

  static const _contact = 'admin@nacala.co.mz';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.alternate_email_rounded,
            color: AppColors.primaryPressed,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Suporte Nacala Delivery',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const Text(
                  _contact,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: _contact));
              if (context.mounted) {
                showAppSnack(context, 'Contacto copiado.');
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copiar'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryPressed,
            ),
          ),
        ],
      ),
    );
  }
}
