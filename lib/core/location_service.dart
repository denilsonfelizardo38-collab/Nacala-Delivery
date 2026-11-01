import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:geocoding/geocoding.dart';
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

  static Future<String?> addressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await Geocoding(locale: const Locale('pt', 'MZ'))
          .placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;
      return formatPlacemark(placemarks.first);
    } on PlatformException {
      throw const LocationException(
        'Não foi possível identificar a morada desta localização. '
        'Pode preenchê-la manualmente.',
      );
    }
  }

  static String? formatPlacemark(Placemark placemark) {
    final street = placemark.street?.trim().isNotEmpty == true
        ? placemark.street!.trim()
        : [
            placemark.subThoroughfare?.trim(),
            placemark.thoroughfare?.trim(),
          ].where((part) => part?.isNotEmpty == true).join(' ');
    final parts = [
      street,
      placemark.subLocality?.trim(),
      placemark.locality?.trim(),
      placemark.subAdministrativeArea?.trim(),
      placemark.administrativeArea?.trim(),
    ].where((part) => part?.isNotEmpty == true).cast<String>();
    final uniqueParts = <String>[];
    final seen = <String>{};
    for (final part in parts) {
      if (seen.add(part.toLowerCase())) uniqueParts.add(part);
    }
    return uniqueParts.isEmpty ? null : uniqueParts.join(', ');
  }

  static Stream<Position> watchPosition() {
    return Geolocator.getPositionStream(
      locationSettings: switch (defaultTargetPlatform) {
        TargetPlatform.android => AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
          intervalDuration: const Duration(seconds: 10),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Nacala Delivery',
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
