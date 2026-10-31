import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/location_service.dart';
import '../theme/app_colors.dart';
import 'common.dart';

const nacalaCenter = LatLng(-14.5428, 40.6729);

Future<LatLng?> showLocationPicker(
  BuildContext context, {
  LatLng? initialLocation,
}) {
  return showDialog<LatLng>(
    context: context,
    builder: (_) => _LocationPickerDialog(initialLocation: initialLocation),
  );
}

class _LocationPickerDialog extends StatefulWidget {
  const _LocationPickerDialog({this.initialLocation});

  final LatLng? initialLocation;

  @override
  State<_LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<_LocationPickerDialog> {
  late final MapController _mapController;
  late LatLng _center;
  LatLng? _selection;
  bool _mapReady = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _center = widget.initialLocation ?? nacalaCenter;
    _selection = widget.initialLocation;
  }

  Future<void> _locateMe() async {
    setState(() => _locating = true);
    try {
      final position = await LocationService.currentPosition();
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        _center = point;
        _selection = point;
      });
      if (_mapReady) _mapController.move(point, 16);
    } on LocationException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ponto de entrega'),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: widget.initialLocation == null ? 13 : 16,
                    onMapReady: () => _mapReady = true,
                    onTap: (_, point) {
                      setState(() {
                        _center = point;
                        _selection = point;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.nacaladelivery.app',
                    ),
                    if (_selection != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selection!,
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
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selection == null
                        ? 'Toque no mapa para marcar o destino.'
                        : 'Ponto selecionado. Ajuste tocando no mapa.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Usar localização atual',
                  onPressed: _locating ? null : _locateMe,
                  icon: _locating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _selection == null
              ? null
              : () => Navigator.of(context).pop(_selection),
          child: const Text('Confirmar ponto'),
        ),
      ],
    );
  }
}
