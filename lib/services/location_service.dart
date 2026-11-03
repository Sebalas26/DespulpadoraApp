import 'dart:async';
import 'dart:convert';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/api_config.dart';

/// Servicio para obtener coordenadas GPS del dispositivo, calcular distancias y consultar el nivel de batería.
class LocationService {
  /// Instancia del lector de estado de batería del dispositivo.
  final Battery _battery = Battery();

  /// Suscripción opcional al flujo continuo de ubicación.
  StreamSubscription<Position>? _positionSubscription;

  /// Última posición real del hardware GPS verificada en la sesión.
  Position? _lastValidPosition;

  /// Caché en memoria de direcciones geocodificadas dentro de Colombia.
  static final Map<String, LatLng> _geocodedAddressCache = <String, LatLng>{};

  /// Coordenada de referencia visual de la planta cuando el dispositivo aún no reporta señal GPS.
  static const LatLng defaultLocation = LatLng(
    ApiConfig.plantaMatrizLat,
    ApiConfig.plantaMatrizLng,
  );

  /// Identifica si una coordenada corresponde al antiguo punto quemado de prueba (4.69680, -74.09250).
  static bool isLegacyHardcodedFallback(double lat, double lng) {
    return (lat - 4.69680).abs() < 0.00025 && (lng - (-74.09250)).abs() < 0.00025;
  }

  /// Verifica si una coordenada proviene de una lectura GPS real y válida (no cero ni quemada).
  static bool isValidRealGpsCoordinate(double lat, double lng) {
    return lat.isFinite &&
        lng.isFinite &&
        lat.abs() > 0.0001 &&
        lng.abs() > 0.0001 &&
        !isLegacyHardcodedFallback(lat, lng);
  }

  /// Verifica si una coordenada GPS se encuentra dentro de los límites geográficos de Colombia.
  static bool isWithinColombia(double lat, double lng) {
    return lat >= -4.5 &&
        lat <= 13.5 &&
        lng >= -80.0 &&
        lng <= -66.5 &&
        !isLegacyHardcodedFallback(lat, lng);
  }

  /// Garantiza que un par de coordenadas se encuentre dentro de Colombia o retorna [defaultLocation].
  static LatLng ensureColombiaCoordinate(double lat, double lng) {
    try {
      if (isWithinColombia(lat, lng)) {
        return LatLng(lat, lng);
      }
      return defaultLocation;
    } catch (_) {
      return defaultLocation;
    }
  }

  /// Geocodifica una dirección física en Bogotá/Colombia usando Nominatim con caché en memoria.
  static Future<LatLng?> geocodeColombiaAddress(
    String rawAddress, {
    http.Client? client,
  }) async {
    try {
      final String trimmed = rawAddress.trim();
      if (trimmed.length < 4) {
        return null;
      }

      final String cacheKey = trimmed.toLowerCase();
      final LatLng? cached = _geocodedAddressCache[cacheKey];
      if (cached != null) {
        return cached;
      }

      final String query = trimmed.toLowerCase().contains('bogot') ||
              trimmed.toLowerCase().contains('colombia')
          ? trimmed
          : '$trimmed, Bogotá, Colombia';

      final Uri uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        <String, String>{
          'format': 'json',
          'limit': '1',
          'countrycodes': 'co',
          'q': query,
        },
      );

      final http.Client httpClient = client ?? http.Client();
      final http.Response response = await httpClient
          .get(
            uri,
            headers: const <String, String>{
              'Accept': 'application/json',
              'User-Agent': 'DespulpadoraApp/1.0',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          final dynamic first = decoded.first;
          if (first is Map) {
            final double? lat = double.tryParse(first['lat']?.toString() ?? '');
            final double? lon = double.tryParse(first['lon']?.toString() ?? '');
            if (lat != null && lon != null && isWithinColombia(lat, lon)) {
              final LatLng resolved = LatLng(lat, lon);
              _geocodedAddressCache[cacheKey] = resolved;
              return resolved;
            }
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Retorna la última posición GPS real verificada en memoria, si existe.
  Position? get lastValidPosition => _lastValidPosition;

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

  /// Obtiene la posición GPS real del dispositivo sin inventar coordenadas quemadas en caso de timeout.
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) {
        return _lastValidPosition;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (isValidRealGpsCoordinate(pos.latitude, pos.longitude)) {
        _lastValidPosition = pos;
        return pos;
      }
      return _lastValidPosition;
    } catch (_) {
      try {
        final Position? lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null &&
            isValidRealGpsCoordinate(lastKnown.latitude, lastKnown.longitude)) {
          _lastValidPosition = lastKnown;
          return lastKnown;
        }
      } catch (_) {}
      return _lastValidPosition;
    }
  }

  /// Retorna un flujo continuo de actualizaciones de posición GPS reales sin filtro de distancia ni segundos de demora.
  Stream<Position> getPositionStream({int intervalSeconds = 0}) {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    return Geolocator.getPositionStream(
      locationSettings: locationSettings,
    )
        .where(
          (Position pos) =>
              isValidRealGpsCoordinate(pos.latitude, pos.longitude),
        )
        .map((Position pos) {
      _lastValidPosition = pos;
      return pos;
    });
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
