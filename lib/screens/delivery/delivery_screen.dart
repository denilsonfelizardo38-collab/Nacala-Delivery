import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/location_service.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/jb.dart';
import '../../widgets/live_delivery_map.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  bool _initialized = false;
  int _tab = 0;
  Future<List<DeliveryAssignment>>? _availableFuture;
  Future<List<DeliveryAssignment>>? _historyFuture;
  String? _busyId;
  StreamSubscription<Position>? _positionSubscription;
  final Set<String> _sharingAssignmentIds = {};
  String? _lastLocationError;
  final Map<String, LatLng> _courierLocations = {};

  static const _tabs = ['Disponíveis', 'Em curso', 'Histórico'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _load();
  }

  void _load() {
    final api = AppScope.of(context).api;
    final assignments = api.deliveryAssignments();
    setState(() {
      _availableFuture = assignments;
      _historyFuture = api.deliveryHistory();
    });
    unawaited(_resumeLocationSharing(assignments));
  }

  /// Abre o chat com o cliente da entrega.
  Future<void> _openChatWithCustomer(
    BuildContext context,
    DeliveryAssignment assignment,
  ) async {
    if (assignment.customerId == null) {
      showAppSnack(context, 'Não foi possível iniciar a conversa.');
      return;
    }
    final api = AppScope.of(context).api;
    try {
      final conversation = await api.createConversation(
        otherUserId: assignment.customerId!,
        orderId: assignment.orderId,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamed(
        '/chat',
        arguments: {
          'id': conversation.id,
          'order_id': assignment.orderId,
          'other_user_id': assignment.customerId,
          'other_user_name': 'Cliente',
          'other_role': 'customer',
        },
      );
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  /// Abre o chat com o parceiro (dono do estabelecimento) da entrega.
  Future<void> _openChatWithPartner(
    BuildContext context,
    DeliveryAssignment assignment,
  ) async {
    if (assignment.establishmentOwnerId == null) {
      showAppSnack(context, 'Não foi possível iniciar a conversa.');
      return;
    }
    final api = AppScope.of(context).api;
    try {
      final conversation = await api.createConversation(
        otherUserId: assignment.establishmentOwnerId!,
        orderId: assignment.orderId,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamed(
        '/chat',
        arguments: {
          'id': conversation.id,
          'order_id': assignment.orderId,
          'other_user_id': assignment.establishmentOwnerId,
          'other_user_name': assignment.establishmentName,
          'other_role': 'partner',
        },
      );
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  Future<void> _resumeLocationSharing(
    Future<List<DeliveryAssignment>> assignmentsFuture,
  ) async {
    try {
      final assignments = await assignmentsFuture;
      final active = assignments
          .where(
            (assignment) =>
                assignment.status == 'accepted' &&
                assignment.orderStatus == 'on_the_way',
          )
          .toList();
      final activeIds = {for (final assignment in active) assignment.id};
      _sharingAssignmentIds.retainAll(activeIds);
      if (active.isEmpty) {
        await _stopLocationSharing();
        return;
      }
      if (activeIds.every(_sharingAssignmentIds.contains) ||
          !await LocationService.hasPermission()) {
        return;
      }
      if (!mounted) return;
      final position = await LocationService.currentPosition();
      if (!mounted) return;
      setState(() {
        for (final assignment in active) {
          _courierLocations[assignment.id] = LatLng(
            position.latitude,
            position.longitude,
          );
        }
      });
      for (final assignment in active) {
        await _publishLocation(assignment.id, position);
      }
      if (mounted) _watchLocation(activeIds);
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } on LocationException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  void _watchLocation(Iterable<String> assignmentIds) {
    _sharingAssignmentIds.addAll(assignmentIds);
    if (_positionSubscription != null) return;
    _lastLocationError = null;
    _positionSubscription = LocationService.watchPosition().listen(
      (position) {
        if (!mounted || _sharingAssignmentIds.isEmpty) return;
        final activeIds = _sharingAssignmentIds.toList();
        setState(() {
          for (final id in activeIds) {
            _courierLocations[id] = LatLng(
              position.latitude,
              position.longitude,
            );
          }
        });
        for (final id in activeIds) {
          unawaited(_publishLocation(id, position));
        }
      },
      onError: (Object error) {
        if (!mounted || _lastLocationError != null) return;
        _lastLocationError = error.toString();
        showAppSnack(
          context,
          'A localização deixou de ser partilhada. Verifique o GPS.',
          error: true,
        );
      },
    );
  }

  Future<void> _publishLocation(String assignmentId, Position position) async {
    if (!mounted) return;
    try {
      await AppScope.of(context).api.updateDeliveryLocation(
        assignmentId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on ApiException catch (error) {
      if (!mounted || _lastLocationError == error.message) return;
      _lastLocationError = error.message;
      showAppSnack(context, error.message, error: true);
    }
  }

  Future<void> _stopLocationSharing([String? assignmentId]) async {
    if (assignmentId != null) {
      _sharingAssignmentIds.remove(assignmentId);
      if (_sharingAssignmentIds.isNotEmpty) return;
    } else {
      _sharingAssignmentIds.clear();
    }
    final subscription = _positionSubscription;
    _positionSubscription = null;
    await subscription?.cancel();
  }

  @override
  void dispose() {
    unawaited(_positionSubscription?.cancel());
    super.dispose();
  }

  Future<void> _act(DeliveryAssignment assignment, String action) async {
    if (action == 'decline') {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Desistir da entrega',
        message:
            'A entrega ${assignment.number} voltará a ficar disponível '
            'para outro estafeta.',
        confirmLabel: 'Desistir',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }
    if (action == 'complete') {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Concluir entrega',
        message:
            'Confirma que entregou o pedido ${assignment.number} ao '
            'cliente?',
        confirmLabel: 'Concluir',
      );
      if (!confirmed || !mounted) return;
    }
    Position? initialPosition;
    if (action == 'start' || action == 'resume') {
      try {
        initialPosition = await LocationService.currentPosition();
      } on LocationException catch (error) {
        if (mounted) showAppSnack(context, error.message, error: true);
        return;
      }
      if (!mounted) return;
    }
    setState(() => _busyId = assignment.id);
    try {
      final api = AppScope.of(context).api;
      if (action != 'resume') {
        await api.deliveryAction(assignment.id, action);
      }
      if (!mounted) return;
      if (initialPosition != null) {
        final position = initialPosition;
        if (action == 'start') {
          setState(() {
            _courierLocations[assignment.id] = LatLng(
              position.latitude,
              position.longitude,
            );
          });
        }
        await _publishLocation(assignment.id, position);
        _watchLocation([assignment.id]);
      }
      if (!mounted) return;
      if (action == 'complete' || action == 'decline') {
        await _stopLocationSharing(assignment.id);
      }
      if (!mounted) return;
      showAppSnack(context, switch (action) {
        'accept' => 'Entrega aceite. Recolha o pedido no parceiro.',
        'start' => 'Entrega iniciada. A sua localização está a ser partilhada.',
        'resume' => 'Partilha da localização retomada.',
        'decline' => 'Desistiu da entrega. Ela voltou a ficar disponível.',
        'complete' => 'Entrega concluída.',
        _ => 'Entrega atualizada.',
      });
      _load();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            JbPageHeader(
              title: 'Entregas',
              onBack: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).maybePop()
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Atualizar',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    for (var i = 0; i < _tabs.length; i++) ...[
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChipPill(
                            label: _tabs[i],
                            selected: _tab == i,
                            onTap: () => setState(() => _tab = i),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _load(),
                child: _tab == 2
                    ? _buildHistory()
                    : _tab == 1
                    ? _buildAccepted()
                    : _buildAvailable(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailable() {
    return AsyncSection<List<DeliveryAssignment>>(
      future: _availableFuture,
      onRetry: _load,
      builder: (context, assignments) {
        final available = assignments
            .where((assignment) => assignment.isAvailable)
            .toList();
        if (available.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: const [
              EmptyState(
                icon: Icons.delivery_dining_outlined,
                title: 'Sem entregas disponíveis',
                message:
                    'Quando um parceiro marcar um pedido como pronto, a '
                    'entrega aparece aqui.',
              ),
            ],
          );
        }
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            for (final assignment in available)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AssignmentCard(
                  assignment: assignment,
                  busy: _busyId == assignment.id,
                  // Só se pode "desistir" de uma entrega já aceite — o
                  // backend exige `courier_id = me` no decline.
                  actions: const [('accept', 'Aceitar entrega')],
                  onAction: (action) => _act(assignment, action),
                  onChatWithCustomer: assignment.customerId != null
                      ? () => _openChatWithCustomer(context, assignment)
                      : null,
                  onChatWithPartner: assignment.establishmentOwnerId != null
                      ? () => _openChatWithPartner(context, assignment)
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAccepted() {
    return AsyncSection<List<DeliveryAssignment>>(
      future: _availableFuture,
      onRetry: _load,
      builder: (context, assignments) {
        final accepted = assignments
            .where((assignment) => assignment.status == 'accepted')
            .toList();
        if (accepted.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: const [
              EmptyState(
                icon: Icons.route_outlined,
                title: 'Nenhuma entrega em curso',
                message: 'Aceite uma entrega disponível para começar.',
              ),
            ],
          );
        }
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            for (final assignment in accepted)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AssignmentCard(
                  assignment: assignment,
                  busy: _busyId == assignment.id,
                  courierLocation:
                      _courierLocations[assignment.id] ??
                      (assignment.courierLatitude == null ||
                              assignment.courierLongitude == null
                          ? null
                          : LatLng(
                              assignment.courierLatitude!,
                              assignment.courierLongitude!,
                            )),
                  actions: [
                    if (assignment.orderStatus == 'on_the_way') ...[
                      if (!_sharingAssignmentIds.contains(assignment.id))
                        ('resume', 'Ativar localização'),
                      ('complete', 'Concluir entrega'),
                    ] else if (assignment.orderStatus == 'ready')
                      ('start', 'Iniciar entrega'),
                    // Desistir devolve a entrega ao pool e, se já estava
                    // a caminho, recoloca o pedido como "pronto".
                    ('decline', 'Desistir'),
                  ],
                  onAction: (action) => _act(assignment, action),
                  onChatWithCustomer: assignment.customerId != null
                      ? () => _openChatWithCustomer(context, assignment)
                      : null,
                  onChatWithPartner: assignment.establishmentOwnerId != null
                      ? () => _openChatWithPartner(context, assignment)
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHistory() {
    return AsyncSection<List<DeliveryAssignment>>(
      future: _historyFuture,
      onRetry: _load,
      builder: (context, assignments) {
        final finished = assignments
            .where(
              (assignment) =>
                  assignment.status == 'completed' ||
                  assignment.status == 'declined',
            )
            .toList();
        if (finished.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: const [
              EmptyState(
                icon: Icons.history_rounded,
                title: 'Sem histórico',
                message: 'As entregas concluídas ou recusadas aparecem aqui.',
              ),
            ],
          );
        }
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            for (final assignment in finished)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AssignmentCard(
                  assignment: assignment,
                  busy: false,
                  actions: const [],
                  onAction: (_) {},
                  onChatWithCustomer: assignment.customerId != null
                      ? () => _openChatWithCustomer(context, assignment)
                      : null,
                  onChatWithPartner: assignment.establishmentOwnerId != null
                      ? () => _openChatWithPartner(context, assignment)
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.assignment,
    required this.busy,
    required this.actions,
    required this.onAction,
    this.courierLocation,
    this.onChatWithCustomer,
    this.onChatWithPartner,
  });

  final DeliveryAssignment assignment;
  final bool busy;
  final List<(String, String)> actions;
  final ValueChanged<String> onAction;
  final LatLng? courierLocation;
  final VoidCallback? onChatWithCustomer;
  final VoidCallback? onChatWithPartner;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  assignment.number,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StatusBadge(
                status: switch (assignment.status) {
                  'available' => 'pending',
                  'accepted' => 'on_the_way',
                  'completed' => 'delivered',
                  'declined' => 'declined',
                  _ => assignment.status,
                },
                label: switch (assignment.status) {
                  'available' => 'Disponível',
                  'accepted' => 'Em curso',
                  'completed' => 'Concluída',
                  'declined' => 'Recusada',
                  _ => assignment.status,
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          _RouteRow(
            icon: Icons.storefront_rounded,
            label: 'Recolha',
            title: assignment.establishmentName,
            subtitle: assignment.establishmentAddress ?? '',
            phone: assignment.establishmentPhone,
            whatsappMessage:
                'Olá! Falo sobre a recolha do pedido ${assignment.number}.',
          ),
          Container(
            margin: const EdgeInsets.only(left: 15),
            height: 16,
            width: 2,
            color: context.lineColor,
          ),
          _RouteRow(
            icon: Icons.location_on_rounded,
            label: 'Entrega · ${assignment.addressLabel ?? 'Cliente'}',
            title: assignment.addressLine,
            subtitle: assignment.customerPhone ?? '',
            phone: assignment.customerPhone,
            whatsappMessage:
                'Olá! Falo sobre a entrega do pedido ${assignment.number}.',
          ),
          if (assignment.orderStatus == 'on_the_way' &&
              assignment.addressLatitude != null &&
              assignment.addressLongitude != null) ...[
            const SizedBox(height: 12),
            LiveDeliveryMap(
              destination: LatLng(
                assignment.addressLatitude!,
                assignment.addressLongitude!,
              ),
              courier: courierLocation,
              departedAt: assignment.departedAt,
              locationUpdatedAt: assignment.locationUpdatedAt,
            ),
          ],
          if (assignment.note != null && assignment.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            InfoRow(
              icon: Icons.sticky_note_2_outlined,
              text: assignment.note!,
              color: context.warningColor,
            ),
          ],
          const Divider(height: 20),
          Row(
            children: [
              Text(
                'Valor a cobrar',
                style: TextStyle(color: context.mutedColor, fontSize: 12),
              ),
              const Spacer(),
              Text(
                formatMoney(assignment.totalCents),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (assignment.customerId != null && onChatWithCustomer != null)
                OutlinedButton.icon(
                  onPressed: onChatWithCustomer,
                  icon: const Icon(Icons.message_rounded, size: 18),
                  label: const Text('Cliente'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              if (assignment.establishmentOwnerId != null && onChatWithPartner != null)
                OutlinedButton.icon(
                  onPressed: onChatWithPartner,
                  icon: const Icon(Icons.storefront_rounded, size: 18),
                  label: const Text('Parceiro'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: AppColors.success,
                    side: const BorderSide(color: AppColors.success),
                  ),
                ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            if (busy)
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final action in actions)
                    action.$1 == 'decline'
                        ? OutlinedButton(
                            onPressed: () => onAction(action.$1),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              foregroundColor: context.dangerColor,
                              side: BorderSide(color: context.dangerColor),
                            ),
                            child: Text(action.$2),
                          )
                        : FilledButton(
                            onPressed: () => onAction(action.$1),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 44),
                            ),
                            child: Text(action.$2),
                          ),
                ],
              ),
          ],
          if (assignment.status == 'completed' &&
              assignment.completedAt != null) ...[
            const SizedBox(height: 8),
            InfoRow(
              icon: Icons.check_circle_outline_rounded,
              text: 'Concluída em ${formatDateTime(assignment.completedAt!)}',
              color: context.successColor,
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.icon,
    required this.label,
    required this.title,
    required this.subtitle,
    this.phone,
    this.whatsappMessage,
  });

  final IconData icon;
  final String label;
  final String title;
  final String subtitle;

  /// Quando definido, mostra as ações de ligação (telefone + WhatsApp)
  /// para este contacto — o número deixa de ser apenas texto.
  final String? phone;
  final String? whatsappMessage;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: context.mutedColor, fontSize: 10),
              ),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: TextStyle(color: context.mutedColor, fontSize: 11),
                ),
            ],
          ),
        ),
        if (phone != null && phone!.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Ligar',
                onPressed: () => launchCall(context, phone: phone!),
                icon: const Icon(
                  Icons.call_rounded,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
              IconButton(
                tooltip: 'WhatsApp',
                onPressed: () => launchWhatsApp(
                  context,
                  phone: phone!,
                  message: whatsappMessage,
                ),
                icon: const Icon(
                  Icons.chat_rounded,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
