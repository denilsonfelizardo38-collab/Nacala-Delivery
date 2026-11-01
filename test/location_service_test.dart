import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:nacala_derivery/core/location_service.dart';

void main() {
  test('formata a morada a partir dos detalhes da localização', () {
    final address = LocationService.formatPlacemark(
      const Placemark(
        street: 'Rua da Marginal',
        subLocality: 'Bairro Central',
        locality: 'Nacala-Porto',
        subAdministrativeArea: 'Nacala',
        administrativeArea: 'Nampula',
      ),
    );

    expect(
      address,
      'Rua da Marginal, Bairro Central, Nacala-Porto, Nacala, Nampula',
    );
  });

  test('remove partes repetidas e devolve nulo sem morada', () {
    expect(
      LocationService.formatPlacemark(
        const Placemark(street: 'Nacala-Porto', locality: 'Nacala-Porto'),
      ),
      'Nacala-Porto',
    );
    expect(LocationService.formatPlacemark(const Placemark()), isNull);
  });
}
