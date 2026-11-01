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
        title: 'Recusar entrega',
        message:
            'A entrega ${assignment.number} voltará a ficar disponível '
            'para outro estafeta.',
        confirmLabel: 'Recusar',
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
        'decline' => 'Entrega recusada.',
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
      appBar: AppBar(
        title: const Text('Entregas'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++) ...[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _Tab(
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
                  actions: [
                    ('accept', 'Aceitar entrega'),
                    ('decline', 'Recusar'),
                  ],
                  onAction: (action) => _act(assignment, action),
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
                  actions: assignment.orderStatus == 'on_the_way'
                      ? [
                          if (!_sharingAssignmentIds.contains(assignment.id))
                            ('resume', 'Ativar localização'),
                          ('complete', 'Concluir entrega'),
                        ]
                      : assignment.orderStatus == 'ready'
                      ? [('start', 'Iniciar entrega')]
                      : const [],
                  onAction: (action) => _act(assignment, action),
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
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.accentColor : context.cardColor,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? context.accentColor : context.lineColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : context.inkColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
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
  });

  final DeliveryAssignment assignment;
  final bool busy;
  final List<(String, String)> actions;
  final ValueChanged<String> onAction;
  final LatLng? courierLocation;

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
                              backgroundColor: AppColors.primary,
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
  });

  final IconData icon;
  final String label;
  final String title;
  final String subtitle;

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
            borderRadius: BorderRadius.circular(9),
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
      ],
    );
  }
}
