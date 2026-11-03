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

  /// Identifica si una coordenada corresponde al punto de referencia por defecto de Planta Matriz (4.7125, -74.1420).
  static bool isPlantaMatrizDefault(double lat, double lng) {
    return (lat - defaultLocation.latitude).abs() < 0.0001 &&
        (lng - defaultLocation.longitude).abs() < 0.0001;
  }

  /// Verifica si un pedido cuenta con una coordenada específica propia en Colombia (distinta de cero y distinta del fallback de Planta Matriz).
  static bool hasSpecificOrderCoordinate(double lat, double lng) {
    return isWithinColombia(lat, lng) && !isPlantaMatrizDefault(lat, lng);
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

  /// Normaliza abreviaturas y cruces viales colombianos para mejorar la precisión del geocodificador.
  static String normalizeColombianAddress(String rawAddress) {
    String s = rawAddress.trim();
    s = s.replaceAll(
      RegExp(r'\b(?:av\.?|avenida)\s+(?:cl\.?|cll\.?|calle)\b', caseSensitive: false),
      'Calle',
    );
    s = s.replaceAll(
      RegExp(r'\b(?:av\.?|avenida)\s+(?:kr\.?|cra\.?|carrera)\b', caseSensitive: false),
      'Carrera',
    );
    s = s.replaceAll(RegExp(r'\b(?:kr|cra|k)\.?\s*', caseSensitive: false), 'Carrera ');
    s = s.replaceAll(RegExp(r'\b(?:cl|cll)\.?\s*', caseSensitive: false), 'Calle ');
    s = s.replaceAll(RegExp(r'\b(?:dg|diag)\.?\s*', caseSensitive: false), 'Diagonal ');
    s = s.replaceAll(RegExp(r'\b(?:tv|transv|tr)\.?\s*', caseSensitive: false), 'Transversal ');
    s = s.replaceAllMapped(
      RegExp(
        r'\b(Calle|Carrera|Diagonal|Transversal|Avenida)\s+(\d+[A-Za-z]?(?:\s+Bis)?)\s+(?!#|No\.?|N°)(\d+[A-Za-z]?(?:\s*-\s*\d+)?)',
        caseSensitive: false,
      ),
      (Match m) => '${m[1]} ${m[2]} # ${m[3]}',
    );
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Extrae el barrio candidato desde una dirección separada por comas o desde el parámetro [neighborhood].
  static String? _extractCandidateNeighborhood(
    String rawAddress,
    String? explicitNeighborhood,
  ) {
    final String cleanExplicit = (explicitNeighborhood ?? '').trim();
    if (cleanExplicit.length >= 3 &&
        !cleanExplicit.toLowerCase().contains('bogot') &&
        !cleanExplicit.toLowerCase().contains('general')) {
      return cleanExplicit;
    }
    final List<String> parts = rawAddress
        .split(',')
        .map((String p) => p.trim())
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      final String second = parts[1];
      if (second.length >= 3 &&
          !second.toLowerCase().contains('bogot') &&
          !second.toLowerCase().contains('colombia') &&
          !second.toLowerCase().contains('distrito') &&
          !RegExp(r'^\d+$').hasMatch(second)) {
        return second;
      }
    }
    return null;
  }

  /// Consulta ArcGIS World Geocoder acotado a Colombia/Bogotá para resolver nomenclatura vial colombiana.
  static Future<LatLng?> _queryArcGisColombia(
    String queryText,
    http.Client httpClient,
  ) async {
    try {
      final Uri arcGisUri = Uri.https(
        'geocode.arcgis.com',
        '/arcgis/rest/services/World/GeocodeServer/findAddressCandidates',
        <String, String>{
          'f': 'json',
          'SingleLine': queryText,
          'countryCode': 'COL',
          'searchExtent': '-74.35,4.45,-73.95,4.90',
          'maxLocations': '1',
          'outFields': 'Match_addr,Addr_type',
        },
      );
      final http.Response response = await httpClient
          .get(
            arcGisUri,
            headers: const <String, String>{
              'Accept': 'application/json',
              'User-Agent': 'DespulpadoraApp/1.0',
            },
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['candidates'] is List) {
          final List<dynamic> candidates = decoded['candidates'] as List<dynamic>;
          if (candidates.isNotEmpty && candidates.first is Map) {
            final Map<dynamic, dynamic> first =
                candidates.first as Map<dynamic, dynamic>;
            final dynamic loc = first['location'];
            if (loc is Map) {
              final double? lat = double.tryParse(loc['y']?.toString() ?? '');
              final double? lon = double.tryParse(loc['x']?.toString() ?? '');
              if (lat != null &&
                  lon != null &&
                  hasSpecificOrderCoordinate(lat, lon)) {
                return LatLng(lat, lon);
              }
            }
          }
        }
        if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
          final Map<dynamic, dynamic> first =
              decoded.first as Map<dynamic, dynamic>;
          final double? lat = double.tryParse(first['lat']?.toString() ?? '');
          final double? lon = double.tryParse(first['lon']?.toString() ?? '');
          if (lat != null &&
              lon != null &&
              hasSpecificOrderCoordinate(lat, lon)) {
            return LatLng(lat, lon);
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Consulta Nominatim OpenStreetMap acotado a Colombia.
  static Future<LatLng?> _queryNominatimColombia(
    String queryText,
    http.Client httpClient,
  ) async {
    try {
      final Uri uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        <String, String>{
          'format': 'json',
          'limit': '1',
          'countrycodes': 'co',
          'q': queryText,
        },
      );
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
            if (lat != null &&
                lon != null &&
                hasSpecificOrderCoordinate(lat, lon)) {
              return LatLng(lat, lon);
            }
          }
        }
        if (decoded is Map && decoded['candidates'] is List) {
          final List<dynamic> candidates = decoded['candidates'] as List<dynamic>;
          if (candidates.isNotEmpty && candidates.first is Map) {
            final dynamic loc = (candidates.first as Map)['location'];
            if (loc is Map) {
              final double? lat = double.tryParse(loc['y']?.toString() ?? '');
              final double? lon = double.tryParse(loc['x']?.toString() ?? '');
              if (lat != null &&
                  lon != null &&
                  hasSpecificOrderCoordinate(lat, lon)) {
                return LatLng(lat, lon);
              }
            }
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Geocodifica una dirección física en Bogotá/Colombia usando ArcGIS + Nominatim con normalización vial y caché en memoria.
  static Future<LatLng?> geocodeColombiaAddress(
    String rawAddress, {
    String? neighborhood,
    http.Client? client,
  }) async {
    try {
      final String trimmed = rawAddress.trim();
      if (trimmed.length < 4) {
        return null;
      }

      final String cleanNeighborhood = (neighborhood ?? '').trim();
      final String cacheKey =
          '${trimmed.toLowerCase()}|${cleanNeighborhood.toLowerCase()}';
      final LatLng? cached = _geocodedAddressCache[cacheKey] ??
          _geocodedAddressCache[trimmed.toLowerCase()];
      if (cached != null) {
        return cached;
      }

      final http.Client httpClient = client ?? http.Client();
      final String? candidateNeighborhood =
          _extractCandidateNeighborhood(trimmed, cleanNeighborhood);

      String buildBogotaQuery(String baseText) {
        final String lower = baseText.toLowerCase();
        final String withNeighborhood = (candidateNeighborhood != null &&
                !lower.contains(candidateNeighborhood.toLowerCase()))
            ? '$baseText, $candidateNeighborhood'
            : baseText;
        if (withNeighborhood.toLowerCase().contains('bogot') ||
            withNeighborhood.toLowerCase().contains('colombia')) {
          return withNeighborhood;
        }
        return '$withNeighborhood, Bogotá, Colombia';
      }

      final String normalized = normalizeColombianAddress(trimmed);
      final List<String> candidateQueries = <String>[
        buildBogotaQuery(normalized),
        if (normalized != trimmed) buildBogotaQuery(trimmed),
      ];

      for (final String q in candidateQueries) {
        final LatLng? arcGisResult = await _queryArcGisColombia(q, httpClient);
        if (arcGisResult != null) {
          _geocodedAddressCache[cacheKey] = arcGisResult;
          _geocodedAddressCache[trimmed.toLowerCase()] = arcGisResult;
          return arcGisResult;
        }
        final LatLng? nominatimResult =
            await _queryNominatimColombia(q, httpClient);
        if (nominatimResult != null) {
          _geocodedAddressCache[cacheKey] = nominatimResult;
          _geocodedAddressCache[trimmed.toLowerCase()] = nominatimResult;
          return nominatimResult;
        }
      }

      if (candidateNeighborhood != null) {
        final String neighborhoodQuery =
            '$candidateNeighborhood, Bogotá, Colombia';
        final LatLng? neighborhoodGeo =
            await _queryNominatimColombia(neighborhoodQuery, httpClient) ??
                await _queryArcGisColombia(neighborhoodQuery, httpClient);
        if (neighborhoodGeo != null) {
          _geocodedAddressCache[cacheKey] = neighborhoodGeo;
          _geocodedAddressCache[trimmed.toLowerCase()] = neighborhoodGeo;
          return neighborhoodGeo;
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
