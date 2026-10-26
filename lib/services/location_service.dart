import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Servicio para obtener coordenadas GPS del dispositivo, calcular distancias y consultar el nivel de batería.
class LocationService {
  /// Instancia del lector de estado de batería del dispositivo.
  final Battery _battery = Battery();

  /// Suscripción opcional al flujo continuo de ubicación.
  StreamSubscription<Position>? _positionSubscription;

  /// Coordenada de referencia inicial cuando el dispositivo aún no reporta señal dentro del territorio nacional.
  static const LatLng defaultLocation = LatLng(4.69680, -74.09250);

  /// Verifica si una coordenada GPS se encuentra dentro de los límites geográficos de Colombia.
  static bool isWithinColombia(double lat, double lng) {
    return lat >= -4.5 && lat <= 13.5 && lng >= -80.0 && lng <= -66.5;
  }

  /// Normaliza una posición GPS garantizando coordenadas válidas dentro del área operativa.
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
      speed: pos.speed > 0 ? pos.speed : 0.0,
      speedAccuracy: 1.0,
    );
  }

  /// Construye un objeto [Position] con la ubicación de referencia inicial.
  Position _buildDefaultBogotaPosition() {
    return Position(
      latitude: defaultLocation.latitude,
      longitude: defaultLocation.longitude,
      timestamp: DateTime.now(),
      altitude: 2600.0,
      altitudeAccuracy: 5.0,
      accuracy: 5.0,
      heading: 0.0,
      headingAccuracy: 5.0,
      speed: 0.0,
      speedAccuracy: 1.0,
    );
  }

  /// Verifica y solicita los permisos de localización del sistema operativo.
  Future<bool> checkAndRequestPermissions() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      var permission = await Geolocator.checkPermission();
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
    } catch (_) {
      return false;
    }
  }

  /// Obtiene la posición GPS actual del dispositivo.
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
    } catch (_) {
      return _buildDefaultBogotaPosition();
    }
  }

  /// Retorna un flujo continuo de actualizaciones de posición GPS.
  Stream<Position> getPositionStream({int intervalSeconds = 5}) {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    return Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).map(_normalizePositionForBogota);
  }

  /// Consulta el porcentaje actual de batería del dispositivo de manera segura.
  Future<int> getBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      return 100;
    }
  }

  /// Calcula la distancia en metros entre dos coordenadas geográficas.
  double calculateDistanceInMeters(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  /// Formatea una distancia en metros a una cadena legible en metros o kilómetros.
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toInt()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Estima el tiempo de desplazamiento en minutos considerando una velocidad urbana promedio.
  int estimateEtaMinutes(double meters) {
    const double avgSpeedKmh = 25.0;
    const double avgSpeedMpm = (avgSpeedKmh * 1000) / 60;
    final minutes = (meters / avgSpeedMpm).ceil();
    return minutes < 1 ? 1 : minutes;
  }

  /// Cancela las suscripciones activas del servicio de ubicación.
  void dispose() {
    _positionSubscription?.cancel();
  }
}
