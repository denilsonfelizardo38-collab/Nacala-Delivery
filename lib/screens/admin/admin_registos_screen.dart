import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/jb.dart';

/// **Gestão de Registos** (FASE 7): candidaturas de estabelecimentos e
/// entregadores recebidas pela área pública.
///
/// Lista com contagens por estado, filtros de estado e tipo, detalhe com os
/// dados completos do formulário e as três decisões do administrador:
/// aprovar, pedir correções (nota obrigatória) e recusar. As decisões usam
/// `POST /api/admin/applications/<id>/{approve,changes,reject}` — o
/// servidor valida e notifica o candidato.
class AdminRegistosScreen extends StatefulWidget {
  const AdminRegistosScreen({super.key});

  @override
  State<AdminRegistosScreen> createState() => _AdminRegistosScreenState();
}

class _AdminRegistosScreenState extends State<AdminRegistosScreen> {
  bool _initialized = false;
  String? _status;
  String? _kind;
  Future<({List<Application> applications, Map<String, int> counts})>? _future;
  List<Category> _categories = const [];
  String? _busyId;

  static const _statuses = [
    (null, 'Todas'),
    ('pending', 'Em análise'),
    ('changes_requested', 'Correções'),
    ('approved', 'Aprovadas'),
    ('rejected', 'Recusadas'),
  ];

  static const _kinds = [
    (null, 'Todos'),
    ('establishment', 'Estabelecimentos'),
    ('delivery', 'Entregadores'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _future = _load();
    _loadCategories();
  }

  Future<({List<Application> applications, Map<String, int> counts})> _load() =>
      AppScope.of(context).api.adminApplications(status: _status, kind: _kind);

  /// Categorias só para mostrar o nome amigável no detalhe.
  Future<void> _loadCategories() async {
    try {
      final categories = await AppScope.of(context).api.categories();
      if (mounted) setState(() => _categories = categories);
    } on ApiException {
      // Sem categorias o detalhe mostra o identificador — não bloqueia.
    }
  }

  void _reload() {
    final future = _load();
    setState(() {
      _future = future;
    });
  }

  void _selectStatus(String? status) {
    if (_status == status) return;
    setState(() {
      _status = status;
      _future = _load();
    });
  }

  void _selectKind(String? kind) {
    if (_kind == kind) return;
    setState(() {
      _kind = kind;
      _future = _load();
    });
  }

  String? _categoryName(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final category in _categories) {
      if (category.id == id) return category.name;
    }
    return null;
  }

  // --------------------------------------------------------------- decisões

  /// Dialogo de decisão com nota (obrigatória em "pedir correções").
  Future<void> _review(Application application, String action) async {
    final requiresNote = action == 'changes';
    final (title, confirmLabel, danger) = switch (action) {
      'approve' => ('Aprovar candidatura', 'APROVAR', false),
      'changes' => ('Pedir correções', 'ENVIAR PEDIDO', false),
      _ => ('Recusar candidatura', 'RECUSAR', true),
    };

    final result = await showDialog<(bool, String)>(
      context: context,
      builder: (_) => _ReviewDialog(
        title: title,
        subtitle: '${application.kindLabel} • ${application.name}',
        confirmLabel: confirmLabel,
        danger: danger,
        requiresNote: requiresNote,
      ),
    );
    if (result == null || !result.$1 || !mounted) return;
    final note = result.$2;

    setState(() => _busyId = application.id);
    try {
      final api = AppScope.of(context).api;
      switch (action) {
        case 'approve':
          await api.adminApproveApplication(application.id, note: note);
        case 'changes':
          await api.adminRequestApplicationChanges(application.id, note: note);
        default:
          await api.adminRejectApplication(application.id, note: note);
      }
      if (!mounted) return;
      showAppSnack(context, switch (action) {
        'approve' => 'Candidatura aprovada. Conta e painel desbloqueados.',
        'changes' => 'Correções pedidas ao candidato.',
        _ => 'Candidatura recusada.',
      });
      _reload();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            JbPageHeader(
              title: 'Gestão de Registos',
              subtitle: 'Candidaturas de estabelecimentos e entregadores.',
              onBack: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).maybePop()
                  : null,
              trailing: IconButton(
                tooltip: 'Atualizar',
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    // Contagens por estado (vêm do servidor em todas as
                    // consultas — os filtros não escondem os totais).
                    SizedBox(
                      height: 40,
                      child: FutureBuilder(
                        future: _future,
                        builder: (context, snapshot) {
                          final counts =
                              snapshot.data?.counts ?? const <String, int>{};
                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _statuses.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final entry = _statuses[index];
                              final count = entry.$1 == null
                                  ? counts.values.fold<int>(0, (a, b) => a + b)
                                  : counts[entry.$1] ?? 0;
                              return FilterChipPill(
                                label: '${entry.$2} · $count',
                                selected: _status == entry.$1,
                                selectedColor: AppColors.primary,
                                onTap: () => _selectStatus(entry.$1),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _kinds.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final entry = _kinds[index];
                          return FilterChipPill(
                            label: entry.$2,
                            selected: _kind == entry.$1,
                            selectedColor: AppColors.deepNavy,
                            onTap: () => _selectKind(entry.$1),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    AsyncSection<
                      ({
                        List<Application> applications,
                        Map<String, int> counts,
                      })
                    >(
                      future: _future,
                      onRetry: _reload,
                      builder: (context, page) {
                        final applications = page.applications;
                        if (applications.isEmpty) {
                          return EmptyState(
                            icon: Icons.how_to_reg_outlined,
                            title: 'Sem candidaturas',
                            message: _status == null && _kind == null
                                ? 'Ainda não há candidaturas por rever.'
                                : 'Nenhuma candidatura corresponde aos '
                                      'filtros escolhidos.',
                          );
                        }
                        return Column(
                          children: [
                            for (final application in applications)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _ApplicationCard(
                                  application: application,
                                  categoryName: _categoryName(
                                    application.payload['category_id']
                                        as String?,
                                  ),
                                  busy: _busyId == application.id,
                                  onOpen: () => _openDetail(application),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Detalhe da candidatura com os dados do formulário e as decisões.
  Future<void> _openDetail(Application application) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            20 + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          child: _DetailSheet(
            application: application,
            categoryName: _categoryName(
              application.payload['category_id'] as String?,
            ),
            busy: _busyId == application.id,
            onReview: (action) async {
              Navigator.of(sheetContext).pop();
              await _review(application, action);
            },
          ),
        ),
      ),
    );
    // A lista é recarregada por `_review` depois de cada decisão.
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    required this.categoryName,
    required this.busy,
    required this.onOpen,
  });

  final Application application;
  final String? categoryName;
  final bool busy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final status = application.status;
    final (statusColor, statusSoft) = switch (status) {
      'approved' => (context.successColor, AppColors.successSoft),
      'rejected' => (context.dangerColor, AppColors.dangerSoft),
      'changes_requested' => (context.warningColor, AppColors.warningSoft),
      _ => (context.accentColor, AppColors.primarySoft),
    };

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  application.kind == 'establishment'
                      ? Icons.storefront_outlined
                      : Icons.two_wheeler_rounded,
                  color: context.accentColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${application.kindLabel}'
                      '${categoryName == null ? '' : ' • $categoryName'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.mutedColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  application.statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.phone_outlined, size: 13, color: context.mutedColor),
              const SizedBox(width: 5),
              Text(
                application.phone,
                style: TextStyle(color: context.mutedColor, fontSize: 11.5),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Enviada ${formatDate(application.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(color: context.mutedColor, fontSize: 11),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.mutedColor,
              ),
            ],
          ),
          if (busy) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({
    required this.application,
    required this.categoryName,
    required this.busy,
    required this.onReview,
  });

  final Application application;
  final String? categoryName;
  final bool busy;
  final ValueChanged<String> onReview;

  Widget _row(BuildContext context, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: TextStyle(color: context.mutedColor, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: context.inkColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Documentos fotografados pelo candidato a entregador: selfie, B.I
  /// (frente e verso) e carta de condução, com pré-visualização ampliada.
  Widget _documents(BuildContext context, Object? raw) {
    if (raw is! Map || raw.isEmpty) return const SizedBox.shrink();
    const labels = {
      'selfie': 'Selfie',
      'bi_front': 'B.I — frente',
      'bi_back': 'B.I — verso',
      'license': 'Carta de condução',
    };
    final client = AppScope.of(context).api.client;
    final entries = [
      for (final label in labels.entries)
        if (raw[label.key] is String &&
            (raw[label.key] as String).isNotEmpty)
          (label.value, raw[label.key] as String),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Documentos',
            style: TextStyle(color: context.mutedColor, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (label, path) in entries)
                _documentThumb(context, client, label, path),
            ],
          ),
        ],
      ),
    );
  }

  Widget _documentThumb(
    BuildContext context,
    ApiClient client,
    String label,
    String path,
  ) {
    final url = client.resolveUri(path).toString();
    const missing = SizedBox(
      width: 84,
      height: 84,
      child: Icon(Icons.broken_image_outlined, color: AppColors.muted),
    );
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 14),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: InteractiveViewer(
                    child: Image.network(
                      url,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined, size: 64),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              width: 84,
              height: 84,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => missing,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 92,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.mutedColor, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  static String _feeLabel(Object? cents) {
    final value = ((cents as num?) ?? 0) / 100;
    return '${value.toStringAsFixed(0)} MZN';
  }

  @override
  Widget build(BuildContext context) {
    final payload = application.payload;
    final reviewing = application.isPending || application.needsChanges;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                application.kind == 'establishment'
                    ? Icons.storefront_outlined
                    : Icons.two_wheeler_rounded,
                color: context.accentColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    application.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${application.kindLabel} • ${application.statusLabel}',
                    style: TextStyle(color: context.mutedColor, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (application.adminNote != null &&
            application.adminNote!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.warningColor),
            ),
            child: Text(
              'Nota anterior: ${application.adminNote}',
              style: TextStyle(
                color: context.inkColor,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        _row(context, 'Nome completo', application.name),
        _row(context, 'Telemóvel', application.phone),
        _row(context, 'WhatsApp', application.whatsapp ?? ''),
        _row(context, 'Email', application.email),
        _row(context, 'NUIT', '${payload['nuit'] ?? ''}'),
        _row(context, 'Enviada em', formatDateTime(application.createdAt)),
        const Divider(height: 22),
        if (application.kind == 'establishment') ...[
          _row(
            context,
            'Estabelecimento',
            '${payload['establishment_name'] ?? ''}',
          ),
          _row(
            context,
            'Categoria',
            categoryName ?? '${payload['category_id'] ?? ''}',
          ),
          _row(context, 'Morada', '${payload['address'] ?? ''}'),
          _row(context, 'Descrição', '${payload['description'] ?? ''}'),
          _row(
            context,
            'Horário',
            '${payload['opens_at'] ?? ''} – ${payload['closes_at'] ?? ''}',
          ),
          _row(
            context,
            'Taxa de entrega',
            _feeLabel(payload['delivery_fee_cents']),
          ),
          _row(context, 'Preparação', '${payload['prep_minutes'] ?? ''} min'),
          _row(
            context,
            'Coordenadas',
            payload['latitude'] == null
                ? ''
                : '${(payload['latitude'] as num).toStringAsFixed(5)}, '
                      '${(payload['longitude'] as num).toStringAsFixed(5)}',
          ),
        ] else ...[
          _row(context, 'Veículo', '${payload['vehicle_type'] ?? ''}'),
          _row(context, 'Zona de cobertura', '${payload['address'] ?? ''}'),
          _row(context, 'Notas', '${payload['notes'] ?? ''}'),
          _row(
            context,
            'Coordenadas',
            payload['latitude'] == null
                ? ''
                : '${(payload['latitude'] as num).toStringAsFixed(5)}, '
                      '${(payload['longitude'] as num).toStringAsFixed(5)}',
          ),
          _documents(context, payload['documents']),
        ],
        const SizedBox(height: 10),
        if (busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (reviewing) ...[
          SizedBox(
            height: 48,
            child: FilledButton(
              key: const ValueKey('review-approve'),
              onPressed: () => onReview('approve'),
              style: FilledButton.styleFrom(
                backgroundColor: context.successColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'APROVAR',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 46,
            child: OutlinedButton(
              key: const ValueKey('review-changes'),
              onPressed: () => onReview('changes'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Pedir correções'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 46,
            child: OutlinedButton(
              key: const ValueKey('review-reject'),
              onPressed: () => onReview('reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.dangerColor,
                side: BorderSide(color: context.dangerColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Recusar'),
            ),
          ),
        ] else
          Text(
            application.isApproved
                ? 'Candidatura aprovada — sem ações pendentes.'
                : 'Candidatura recusada — sem ações pendentes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedColor, fontSize: 12.5),
          ),
      ],
    );
  }
}

/// Dialogo de decisão de uma candidatura. O `TextEditingController` pertence
/// ao estado do dialogo e só é libertado no `dispose` — depois de a animação
/// de saída terminar (libertar antes rebenta com o TextField em baixo).
class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.danger,
    required this.requiresNote,
  });

  final String title;
  final String subtitle;
  final String confirmLabel;
  final bool danger;
  final bool requiresNote;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _note = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _confirm() {
    final note = _note.text.trim();
    if (widget.requiresNote && note.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop((true, note));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.subtitle,
            style: TextStyle(
              color: context.mutedColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            autofocus: widget.requiresNote,
            maxLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: widget.requiresNote
                  ? 'O que deve ser corrigido? (obrigatório)'
                  : 'Nota para o candidato (opcional)',
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_showError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Indica o que o candidato deve corrigir.',
                style: TextStyle(color: context.dangerColor, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop((false, '')),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor:
                widget.danger ? context.dangerColor : AppColors.primary,
          ),
          onPressed: _confirm,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
