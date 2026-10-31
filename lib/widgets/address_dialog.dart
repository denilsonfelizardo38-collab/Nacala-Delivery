import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import 'location_picker.dart';

class AddressInput {
  const AddressInput({
    required this.label,
    required this.line,
    this.reference,
    this.isDefault = false,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final String line;
  final String? reference;
  final bool isDefault;
  final double latitude;
  final double longitude;
}

/// Formulário de morada reutilizado no checkout e na conta.
Future<AddressInput?> showAddressDialog(
  BuildContext context, {
  Address? initial,
}) {
  return showDialog<AddressInput>(
    context: context,
    builder: (_) => _AddressDialog(initial: initial),
  );
}

class _AddressDialog extends StatefulWidget {
  const _AddressDialog({this.initial});
  final Address? initial;

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _line;
  late final TextEditingController _reference;
  late bool _isDefault;
  double? _latitude;
  double? _longitude;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.initial?.label ?? 'Casa');
    _line = TextEditingController(text: widget.initial?.line ?? '');
    _reference = TextEditingController(text: widget.initial?.reference ?? '');
    _isDefault = widget.initial?.isDefault ?? false;
    _latitude = widget.initial?.latitude;
    _longitude = widget.initial?.longitude;
  }

  Future<void> _selectLocation() async {
    final latitude = _latitude;
    final longitude = _longitude;
    final location = await showLocationPicker(
      context,
      initialLocation: latitude == null || longitude == null
          ? null
          : LatLng(latitude, longitude),
    );
    if (location == null || !mounted) return;
    setState(() {
      _latitude = location.latitude;
      _longitude = location.longitude;
      _locationError = null;
    });
  }

  @override
  void dispose() {
    _label.dispose();
    _line.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nova morada' : 'Editar morada'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _label,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Rótulo',
                    hintText: 'Casa, Trabalho...',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Indique um rótulo.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _line,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Morada',
                    hintText: 'Bairro, rua, número da casa',
                  ),
                  validator: (value) =>
                      (value == null || value.trim().length < 5)
                      ? 'Indique a morada completa.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reference,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Referência (opcional)',
                    hintText: 'Ponto de referência',
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _selectLocation,
                    icon: const Icon(Icons.map_outlined),
                    label: Text(
                      _latitude == null
                          ? 'Marcar ponto no mapa'
                          : 'Alterar ponto no mapa',
                    ),
                  ),
                ),
                if (_locationError != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _locationError!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Usar como morada predefinida',
                    style: TextStyle(fontSize: 13),
                  ),
                  value: _isDefault,
                  onChanged: (value) => setState(() => _isDefault = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            if (_latitude == null || _longitude == null) {
              setState(
                () => _locationError = 'Marque o ponto de entrega no mapa para permitir o rastreamento.',
              );
              return;
            }
            Navigator.of(context).pop(
              AddressInput(
                label: _label.text.trim(),
                line: _line.text.trim(),
                reference: _reference.text.trim().isEmpty
                    ? null
                    : _reference.text.trim(),
                isDefault: _isDefault,
                latitude: _latitude!,
                longitude: _longitude!,
              ),
            );
          },
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
