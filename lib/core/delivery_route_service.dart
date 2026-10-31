import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class DeliveryRoute {
  const DeliveryRoute({
    required this.points,
    required this.distanceMeters,
    required this.duration,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final Duration duration;
}

class DeliveryRouteService {
  const DeliveryRouteService._();

  static Future<DeliveryRoute> fetch(LatLng origin, LatLng destination) async {
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}',
      {'overview': 'full', 'geometries': 'geojson', 'steps': 'false'},
    );

    final http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const DeliveryRouteException(
        'O serviço de rotas demorou demasiado a responder.',
      );
    } on SocketException {
      throw const DeliveryRouteException(
        'Não foi possível calcular a rota. Verifique a ligação à internet.',
      );
    } on http.ClientException {
      throw const DeliveryRouteException(
        'Não foi possível calcular a rota. Verifique a ligação à internet.',
      );
    }
    if (response.statusCode != 200) {
      throw const DeliveryRouteException(
        'O serviço de rotas está temporariamente indisponível.',
      );
    }

    final Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid route response');
      }
      data = decoded;
    } on FormatException {
      throw const DeliveryRouteException(
        'Resposta inválida ao calcular a rota.',
      );
    }

    final routes = data['routes'];
    if (data['code'] != 'Ok' || routes is! List || routes.isEmpty) {
      throw const DeliveryRouteException(
        'Não foi encontrada uma rota para este destino.',
      );
    }
    final route = routes.first;
    if (route is! Map<String, dynamic>) {
      throw const DeliveryRouteException('Dados de rota inválidos.');
    }
    final geometry = route['geometry'];
    final coordinates = geometry is Map<String, dynamic>
        ? geometry['coordinates']
        : null;
    if (coordinates is! List || coordinates.isEmpty) {
      throw const DeliveryRouteException(
        'A rota não contém pontos para mostrar no mapa.',
      );
    }
    final points = <LatLng>[];
    for (final coordinate in coordinates) {
      if (coordinate is! List ||
          coordinate.length < 2 ||
          coordinate[0] is! num ||
          coordinate[1] is! num) {
        throw const DeliveryRouteException('Dados de rota inválidos.');
      }
      points.add(
        LatLng(
          (coordinate[1] as num).toDouble(),
          (coordinate[0] as num).toDouble(),
        ),
      );
    }
    if (points.isEmpty ||
        route['distance'] is! num ||
        route['duration'] is! num) {
      throw const DeliveryRouteException('Dados de rota inválidos.');
    }

    return DeliveryRoute(
      points: points,
      distanceMeters: (route['distance'] as num).toDouble(),
      duration: Duration(seconds: (route['duration'] as num).round()),
    );
  }
}

class DeliveryRouteException implements Exception {
  const DeliveryRouteException(this.message);

  final String message;

  @override
  String toString() => message;
}
