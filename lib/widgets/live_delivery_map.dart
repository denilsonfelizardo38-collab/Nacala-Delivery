import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/delivery_route_service.dart';
import '../core/formatters.dart';
import '../theme/app_colors.dart';

class LiveDeliveryMap extends StatefulWidget {
  const LiveDeliveryMap({
    super.key,
    required this.destination,
    this.courier,
    this.departedAt,
    this.locationUpdatedAt,
    this.height = 270,
  });

  final LatLng destination;
  final LatLng? courier;
  final DateTime? departedAt;
  final DateTime? locationUpdatedAt;
  final double height;

  @override
  State<LiveDeliveryMap> createState() => _LiveDeliveryMapState();
}

class _LiveDeliveryMapState extends State<LiveDeliveryMap> {
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();
  Timer? _clock;
  DeliveryRoute? _route;
  String? _routeError;
  DateTime? _lastRouteRequest;
  bool _loadingRoute = false;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _loadRoute(force: true);
    if (widget.departedAt != null || widget.courier != null) {
      _clock = Timer.periodic(const Duration(minutes: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (widget.courier != null) unawaited(_loadRoute());
      });
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LiveDeliveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final destinationChanged = oldWidget.destination != widget.destination;
    final courierMoved =
        oldWidget.courier != widget.courier &&
        oldWidget.courier != null &&
        widget.courier != null &&
        _distance.as(LengthUnit.Meter, oldWidget.courier!, widget.courier!) >=
            75;
    final locationAppeared =
        oldWidget.courier == null && widget.courier != null;
    if (destinationChanged || courierMoved || locationAppeared) {
      _loadRoute(force: destinationChanged || locationAppeared);
    }
  }

  Future<void> _loadRoute({bool force = false}) async {
    final origin = widget.courier;
    if (origin == null || _loadingRoute) return;
    final lastRequest = _lastRouteRequest;
    if (!force &&
        lastRequest != null &&
        DateTime.now().difference(lastRequest) < const Duration(seconds: 45)) {
      return;
    }
    _loadingRoute = true;
    _lastRouteRequest = DateTime.now();
    try {
      final route = await DeliveryRouteService.fetch(
        origin,
        widget.destination,
      );
      if (!mounted) return;
      setState(() {
        _route = route;
        _routeError = null;
      });
      if (_mapReady && route.points.length > 1) {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: route.points,
            padding: const EdgeInsets.all(36),
          ),
        );
      }
    } on DeliveryRouteException catch (error) {
      if (!mounted) return;
      setState(() => _routeError = error.message);
    } finally {
      _loadingRoute = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = [
      if (_route != null) ..._route!.points,
      if (widget.courier != null) widget.courier!,
      widget.destination,
    ];
    final arrival = _route == null
        ? null
        : DateTime.now().add(_route!.duration);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: widget.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.courier ?? widget.destination,
                initialZoom: 14,
                onMapReady: () {
                  _mapReady = true;
                  final route = _route;
                  if (route != null && route.points.length > 1) {
                    _mapController.fitCamera(
                      CameraFit.coordinates(
                        coordinates: route.points,
                        padding: const EdgeInsets.all(36),
                      ),
                    );
                  }
                },
                initialCameraFit: points.length > 1
                    ? CameraFit.coordinates(
                        coordinates: points,
                        padding: const EdgeInsets.all(36),
                      )
                    : null,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.nacaladelivery.app',
                ),
                if (_route != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _route!.points,
                        strokeWidth: 5,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (widget.courier != null)
                      Marker(
                        point: widget.courier!,
                        width: 44,
                        height: 44,
                        child: const Icon(
                          Icons.delivery_dining_rounded,
                          color: AppColors.primary,
                          size: 34,
                        ),
                      ),
                    Marker(
                      point: widget.destination,
                      width: 44,
                      height: 48,
                      child: const Icon(
                        Icons.location_pin,
                        color: AppColors.danger,
                        size: 44,
                      ),
                    ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (widget.departedAt != null)
          Text(
            'Saiu às ${formatDateTime(widget.departedAt!)} · '
            'em rota há ${DateTime.now().difference(widget.departedAt!).inMinutes} min',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (widget.locationUpdatedAt != null)
          Text(
            'Localização atualizada às '
            '${formatDateTime(widget.locationUpdatedAt!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (_route != null && arrival != null) ...[
          const SizedBox(height: 4),
          Text(
            'Previsão: ${formatDateTime(arrival)} · '
            'cerca de ${_route!.duration.inMinutes} min',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            'Percurso: ${(_route!.distanceMeters / 1000).toStringAsFixed(1)} km',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ] else if (_loadingRoute) ...[
          const SizedBox(height: 4),
          const LinearProgressIndicator(),
          const SizedBox(height: 4),
          Text(
            'A calcular a rota e a previsão de chegada...',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ] else if (_routeError != null) ...[
          const SizedBox(height: 4),
          Text(
            _routeError!,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.danger),
          ),
          TextButton(
            onPressed: () => _loadRoute(force: true),
            child: const Text('Tentar calcular novamente'),
          ),
        ] else if (widget.courier == null) ...[
          const SizedBox(height: 4),
          Text(
            'Aguardando a localização do estafeta.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
