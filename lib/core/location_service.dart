import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  const LocationService._();

  static Future<bool> hasPermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } on PlatformException {
      return false;
    }
  }

  static Future<Position> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationException(
          'Ative a localização do telemóvel para continuar.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const LocationException(
          'Permita o acesso à localização nas definições do telemóvel.',
        );
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } on TimeoutException {
      throw const LocationException(
        'Não foi possível obter a localização. Verifique o sinal de GPS.',
      );
    } on PlatformException {
      throw const LocationException(
        'Não foi possível aceder ao GPS. Verifique as permissões do telemóvel.',
      );
    }
  }

  static Stream<Position> watchPosition() {
    return Geolocator.getPositionStream(
      locationSettings: switch (defaultTargetPlatform) {
        TargetPlatform.android => AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
          intervalDuration: const Duration(seconds: 10),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Nacala Entrega',
            notificationText:
                'A sua localização está a ser partilhada com o cliente.',
            enableWakeLock: true,
            setOngoing: true,
          ),
        ),
        TargetPlatform.iOS => AppleSettings(
          accuracy: LocationAccuracy.high,
          activityType: ActivityType.fitness,
          distanceFilter: 15,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
        ),
        _ => const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
        ),
      },
    );
  }
}

class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}
