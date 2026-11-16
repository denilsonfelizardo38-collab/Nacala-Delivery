import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../widgets/jb.dart';

/// Estado da candidatura do próprio candidato (`GET /api/applications/me`).
///
/// Aparece em três sítios: depois de enviar a candidatura, quando um
/// candidato pendente inicia sessão (o painel fica bloqueado no servidor
/// até à aprovação) e sempre que alguém quer rever o estado. Quando o
/// administrador pede correções, o botão leva de volta ao formulário com
/// os dados pré-preenchidos.
class ApplicationStatusScreen extends StatefulWidget {
  const ApplicationStatusScreen({super.key});

  @override
  State<ApplicationStatusScreen> createState() =>
      _ApplicationStatusScreenState();
}

class _ApplicationStatusScreenState extends State<ApplicationStatusScreen> {
  Application? _application;
  Object? _error;
  bool _loading = true;

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `AppScope.of` (dependOnInherited…) não pode ser chamado no initState;
    // carrega a candidatura na primeira passagem por aqui.
    if (!_loaded) {
      _loaded = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final application = await AppScope.of(context).myApplication();
      if (!mounted) return;
      setState(() => _application = application);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.status == 404) {
          // A conta não tem candidatura associada (ex.: cliente que nunca
          // se candidatou) — estado vazio, não erro.
          _application = null;
          _error = null;
        } else {
          _error = error;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Correções pedidas: devolve ao formulário com os dados antigos.
  void _resubmit() {
    final application = _application;
    if (application == null) return;
    Navigator.of(context).pushNamed(
      application.kind == 'establishment'
          ? '/establishment/apply'
          : '/courier/apply',
      arguments: application,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 850;
    final horizontal = wide ? 30.0 : 18.0;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: JbPageHeader(
                  title: 'Estado da candidatura',
                  subtitle: 'Acompanha aqui a análise da equipa.',
                  padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 6),
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.of(context).maybePop()
                      : null,
                  trailing: Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.how_to_reg_rounded,
                      color: AppColors.primaryPressed,
                      size: 23,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    14,
                    horizontal,
                    22 + bottomInset,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: _body(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return _messageCard(
        icon: Icons.wifi_off_rounded,
        iconColor: AppColors.dangerInk,
        title: 'Não foi possível carregar',
        body: 'Verifica a ligação e tenta novamente.',
        actionLabel: 'Tentar novamente',
        onAction: _load,
      );
    }
    final application = _application;
    if (application == null) {
      return _messageCard(
        icon: Icons.assignment_outlined,
        title: 'Sem candidatura',
        body: 'Esta conta ainda não enviou nenhuma candidatura de '
            'estabelecimento ou entregador.',
        actionLabel: 'Criar candidatura',
        onAction: () => Navigator.of(context).pushNamed('/roles',
            arguments: 'register'),
      );
    }
    return _statusCard(application);
  }

  Widget _statusCard(Application application) {
    final (icon, color, headline) = switch (application.status) {
      'approved' => (
        Icons.verified_rounded,
        AppColors.success,
        'Candidatura aprovada!',
      ),
      'rejected' => (
        Icons.cancel_outlined,
        AppColors.dangerInk,
        'Candidatura recusada',
      ),
      'changes_requested' => (
        Icons.edit_note_rounded,
        AppColors.warning,
        'Correções solicitadas',
      ),
      _ => (
        Icons.hourglass_top_rounded,
        AppColors.primary,
        'Em análise',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x73000000),
            blurRadius: 35,
            offset: Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 18),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${application.kindLabel} • ${application.name}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _row('Estado', application.statusLabel),
                const SizedBox(height: 8),
                _row(
                  'Enviada em',
                  '${application.createdAt.day.toString().padLeft(2, '0')}/'
                      '${application.createdAt.month.toString().padLeft(2, '0')}/'
                      '${application.createdAt.year}',
                ),
                const SizedBox(height: 8),
                _row('Contacto', application.phone),
                if (application.adminNote != null &&
                    application.adminNote!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _row('Resposta da equipa', application.adminNote!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          switch (application.status) {
            'pending' => Text(
              'A equipa vai analisar os dados. Recebes a resposta aqui — '
              'o painel abre assim que for aprovado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted.withValues(alpha: .9),
                fontSize: 12.5,
                height: 1.55,
              ),
            ),
            'changes_requested' => Text(
              'O administrador pediu correções. Envia novamente o '
              'formulário corrigido para voltar à fila de análise.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted.withValues(alpha: .9),
                fontSize: 12.5,
                height: 1.55,
              ),
            ),
            'approved' => Text(
              'Conta aprovada. Já podes entrar no painel e começar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted.withValues(alpha: .9),
                fontSize: 12.5,
                height: 1.55,
              ),
            ),
            _ => Text(
              'A candidatura não foi aprovada. Podes falar com a equipa '
              'da plataforma para saber o motivo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted.withValues(alpha: .9),
                fontSize: 12.5,
                height: 1.55,
              ),
            ),
          },
          const SizedBox(height: 20),
          if (application.needsChanges) ...[
            SizedBox(
              height: 50,
              child: FilledButton(
                key: const ValueKey('resubmit-application'),
                onPressed: _resubmit,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Corrigir e reenviar',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton(
            onPressed: _load,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Atualizar estado'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Voltar à Home'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _messageCard({
    required IconData icon,
    Color iconColor = AppColors.muted,
    required String title,
    required String body,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, color: iconColor, size: 42),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
