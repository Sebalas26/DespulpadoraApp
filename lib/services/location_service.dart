import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Servicio para obtener coordenadas GPS, calcular distancias y nivel de batería
class LocationService {
  final Battery _battery = Battery();
  StreamSubscription<Position>? _positionSubscription;

  /// Coordenada inicial por defecto (Bogotá Centro - Norte)
  static const LatLng defaultLocation = LatLng(4.67812, -74.05834);

  /// Verifica y solicita permisos de ubicación
  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si el GPS está habilitado en el dispositivo
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Servicio deshabilitado
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Obtiene la posición actual inmediata del dispositivo
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) {
        // Fallback a posición simulada si no hay permisos (útil para emuladores)
        return Position(
          latitude: defaultLocation.latitude,
          longitude: defaultLocation.longitude,
          timestamp: DateTime.now(),
          altitude: 2600.0,
          altitudeAccuracy: 5.0,
          accuracy: 5.0,
          heading: 180.0,
          headingAccuracy: 5.0,
          speed: 25.0,
          speedAccuracy: 1.0,
        );
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      // Retorna posición por defecto en caso de error/timeout
      return Position(
        latitude: defaultLocation.latitude,
        longitude: defaultLocation.longitude,
        timestamp: DateTime.now(),
        altitude: 2600.0,
        altitudeAccuracy: 5.0,
        accuracy: 5.0,
        heading: 180.0,
        headingAccuracy: 5.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }
  }

  /// Inicia el stream continuo de ubicación
  Stream<Position> getPositionStream({int intervalSeconds = 5}) {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Cada 5 metros o por tiempo
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  /// Obtiene el porcentaje de batería del dispositivo de forma segura
  Future<int> getBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (e) {
      return 85; // Fallback razonable si el emulador no soporta lectura
    }
  }

  /// Calcula la distancia en metros o kilómetros entre dos coordenadas
  double calculateDistanceInMeters(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  /// Formatea la distancia para la UI (ej. "450 m" o "3.2 km")
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toInt()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Estima el tiempo de llegada en minutos a velocidad promedio de moto en ciudad (25 km/h)
  int estimateEtaMinutes(double meters) {
    const double avgSpeedKmh = 25.0;
    const double avgSpeedMpm = (avgSpeedKmh * 1000) / 60; // ~416 metros/min
    final minutes = (meters / avgSpeedMpm).ceil();
    return minutes < 1 ? 1 : minutes;
  }

  void dispose() {
    _positionSubscription?.cancel();
  }
}
