import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Servicio para obtener coordenadas GPS, calcular distancias y nivel de batería
class LocationService {
  final Battery _battery = Battery();
  StreamSubscription<Position>? _positionSubscription;

  /// Coordenada inicial por defecto en Bogotá (Sector Calle 80 / Av. Boyacá - Salida Cava)
  static const LatLng defaultLocation = LatLng(4.69680, -74.09250);

  /// Verifica si una coordenada GPS está dentro de Colombia (evita que el emulador Android/iOS
  /// envíe la coordenada por defecto de California 37.42, -122.084 que rompe el enrutamiento vial)
  static bool isWithinColombia(double lat, double lng) {
    return lat >= -4.5 && lat <= 13.5 && lng >= -80.0 && lng <= -66.5;
  }

  /// Normaliza una posición para garantizar que en emuladores fuera de Colombia use Bogotá
  Position _normalizePositionForBogota(Position pos) {
    if (isWithinColombia(pos.latitude, pos.longitude)) {
      return pos;
    }
    return Position(
      latitude: defaultLocation.latitude,
      longitude: defaultLocation.longitude,
      timestamp: DateTime.now(),
      altitude: 2600.0,
      altitudeAccuracy: 5.0,
      accuracy: 5.0,
      heading: pos.heading,
      headingAccuracy: 5.0,
      speed: pos.speed > 0 ? pos.speed : 7.5,
      speedAccuracy: 1.0,
    );
  }

  Position _buildDefaultBogotaPosition() {
    return Position(
      latitude: defaultLocation.latitude,
      longitude: defaultLocation.longitude,
      timestamp: DateTime.now(),
      altitude: 2600.0,
      altitudeAccuracy: 5.0,
      accuracy: 5.0,
      heading: 180.0,
      headingAccuracy: 5.0,
      speed: 7.5,
      speedAccuracy: 1.0,
    );
  }

  /// Verifica y solicita permisos de ubicación
  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si el GPS está habilitado en el dispositivo
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
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

  /// Obtiene la posición actual inmediata del dispositivo (normalizada a Bogotá si es emulador en USA)
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) {
        return _buildDefaultBogotaPosition();
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      return _normalizePositionForBogota(pos);
    } catch (e) {
      return _buildDefaultBogotaPosition();
    }
  }

  /// Inicia el stream continuo de ubicación
  Stream<Position> getPositionStream({int intervalSeconds = 5}) {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Cada 5 metros o por tiempo
    );

    return Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).map(_normalizePositionForBogota);
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
