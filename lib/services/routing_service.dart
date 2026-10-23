import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/api_config.dart';
import 'location_service.dart';

/// Información de un tramo o ruta por carreteras reales
class RouteData {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  RouteData({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  String get distanceFormatted {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toInt()} m';
    } else {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  int get durationMinutes {
    final mins = (durationSeconds / 60).round();
    return mins < 1 ? 1 : mins;
  }
}

/// Información del enrutado completo multiparada del domiciliario (Igual a PWA)
class MultiStopRouteData {
  final List<LatLng> fullPoints;
  final List<List<LatLng>> legPoints;
  final List<double> legDistancesMeters;
  final List<double> legDurationsSeconds;
  final double totalDistanceMeters;
  final double totalDurationSeconds;

  MultiStopRouteData({
    required this.fullPoints,
    required this.legPoints,
    required this.legDistancesMeters,
    required this.legDurationsSeconds,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
  });

  String get totalDistanceFormatted {
    if (totalDistanceMeters < 1000) {
      return '${totalDistanceMeters.toInt()} m';
    } else {
      return '${(totalDistanceMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  int get totalDurationMinutes {
    final mins = (totalDurationSeconds / 60).round();
    return mins < 1 ? 1 : mins;
  }
}

/// Servicio de enrutamiento vehicular exacto calle por calle (Stadia Maps Valhalla + OSRM + OSM.de)
class RoutingService {
  final http.Client _client;
  static final Map<String, RouteData> _segmentCache = {};

  static const Map<String, String> _defaultHeaders = {
    'User-Agent': 'PulpasProApp/1.0 (com.pulpaspro.despulpadora_app)',
    'Accept': 'application/json',
  };

  RoutingService({http.Client? client}) : _client = client ?? http.Client();

  LatLng _ensureColombiaCoord(LatLng pt) {
    if (LocationService.isWithinColombia(pt.latitude, pt.longitude)) {
      return pt;
    }
    return LocationService.defaultLocation;
  }

  /// Obtiene el trazado exacto calle por calle entre dos coordenadas
  Future<RouteData> getRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    final safeStart = _ensureColombiaCoord(start);
    final safeEnd = _ensureColombiaCoord(end);

    final cacheKey =
        '${safeStart.latitude.toStringAsFixed(4)},${safeStart.longitude.toStringAsFixed(4)}_'
        '${safeEnd.latitude.toStringAsFixed(4)},${safeEnd.longitude.toStringAsFixed(4)}';

    final cached = _segmentCache[cacheKey];
    if (cached != null && cached.points.length > 5) {
      return cached;
    }

    // 1. Motor Primario: Stadia Maps Valhalla Routing API (Alta disponibilidad con API Key de la PWA)
    final stadiaRoute = await _fetchStadiaValhallaSingleRoute(safeStart, safeEnd);
    if (stadiaRoute != null && stadiaRoute.points.length > 2) {
      _segmentCache[cacheKey] = stadiaRoute;
      return stadiaRoute;
    }

    // 2. Motor Secundario: OSRM Oficial (router.project-osrm.org)
    final osrmRoute = await _fetchOsrmSingleRoute(
      'https://router.project-osrm.org/route/v1/driving',
      safeStart,
      safeEnd,
    );
    if (osrmRoute != null && osrmRoute.points.length > 2) {
      _segmentCache[cacheKey] = osrmRoute;
      return osrmRoute;
    }

    // 3. Motor Terciario: OpenStreetMap.de Car Router
    final osmDeRoute = await _fetchOsrmSingleRoute(
      'https://routing.openstreetmap.de/routed-car/route/v1/driving',
      safeStart,
      safeEnd,
    );
    if (osmDeRoute != null && osmDeRoute.points.length > 2) {
      _segmentCache[cacheKey] = osmDeRoute;
      return osmDeRoute;
    }

    // Fallback final solo si no hay internet en absoluto (NO se guarda en caché para reintentar)
    final straightDistance = const Distance().as(LengthUnit.Meter, safeStart, safeEnd);
    return RouteData(
      points: [safeStart, safeEnd],
      distanceMeters: straightDistance,
      durationSeconds: (straightDistance / 7.2),
    );
  }

  /// Construye el enrutado completo secuencial calle por calle para todas las paradas del domiciliario
  Future<MultiStopRouteData> getMultiStopRoute({
    required List<LatLng> waypoints,
  }) async {
    final safeWaypoints = waypoints.map(_ensureColombiaCoord).toList();

    if (safeWaypoints.length < 2) {
      return MultiStopRouteData(
        fullPoints: safeWaypoints,
        legPoints: [],
        legDistancesMeters: [],
        legDurationsSeconds: [],
        totalDistanceMeters: 0,
        totalDurationSeconds: 0,
      );
    }

    // 1. Intentar obtener todo el circuito multiparada en una sola petición a Stadia Maps Valhalla
    final stadiaMulti = await _fetchStadiaValhallaMultiRoute(safeWaypoints);
    if (stadiaMulti != null && stadiaMulti.fullPoints.length > 5) {
      return stadiaMulti;
    }

    // 2. Intentar obtener todo el circuito multiparada en una sola petición a OSRM / OSM.de
    final osrmMulti = await _fetchOsrmMultiRoute(
      'https://router.project-osrm.org/route/v1/driving',
      safeWaypoints,
    );
    if (osrmMulti != null && osrmMulti.fullPoints.length > 5) {
      return osrmMulti;
    }

    final osmDeMulti = await _fetchOsrmMultiRoute(
      'https://routing.openstreetmap.de/routed-car/route/v1/driving',
      safeWaypoints,
    );
    if (osmDeMulti != null && osmDeMulti.fullPoints.length > 5) {
      return osmDeMulti;
    }

    // 3. Respaldo tramo por tramo usando getRoute
    final List<LatLng> fullRoadPath = [];
    final List<List<LatLng>> legs = [];
    final List<double> legDistances = [];
    final List<double> legDurations = [];
    double totalDist = 0;
    double totalDur = 0;

    for (int i = 0; i < safeWaypoints.length - 1; i++) {
      final seg = await getRoute(start: safeWaypoints[i], end: safeWaypoints[i + 1]);
      legs.add(seg.points);
      legDistances.add(seg.distanceMeters);
      legDurations.add(seg.durationSeconds);
      totalDist += seg.distanceMeters;
      totalDur += seg.durationSeconds;

      if (fullRoadPath.isNotEmpty && seg.points.isNotEmpty) {
        fullRoadPath.addAll(seg.points.skip(1));
      } else {
        fullRoadPath.addAll(seg.points);
      }
    }

    return MultiStopRouteData(
      fullPoints: fullRoadPath,
      legPoints: legs,
      legDistancesMeters: legDistances,
      legDurationsSeconds: legDurations,
      totalDistanceMeters: totalDist,
      totalDurationSeconds: totalDur,
    );
  }

  /// Consulta Stadia Maps Valhalla para un tramo individual calle por calle
  Future<RouteData?> _fetchStadiaValhallaSingleRoute(LatLng start, LatLng end) async {
    try {
      final url = Uri.parse(
        'https://api.stadiamaps.com/route/v1?api_key=${ApiConfig.stadiaApiKey}',
      );
      final body = jsonEncode({
        'locations': [
          {'lat': start.latitude, 'lon': start.longitude},
          {'lat': end.latitude, 'lon': end.longitude},
        ],
        'costing': 'auto',
        'directions_options': {'units': 'kilometers'},
      });

      final response = await _client
          .post(
            url,
            headers: {..._defaultHeaders, 'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final trip = data['trip'] as Map<String, dynamic>?;
        final legs = trip?['legs'] as List<dynamic>?;
        if (legs != null && legs.isNotEmpty) {
          final leg = legs.first as Map<String, dynamic>;
          final shape = leg['shape'] as String?;
          final summary = leg['summary'] as Map<String, dynamic>?;
          if (shape != null && shape.isNotEmpty) {
            final points = _decodePolyline6(shape);
            final distKm = (summary?['length'] as num?)?.toDouble() ?? 0.0;
            final timeSec = (summary?['time'] as num?)?.toDouble() ?? 0.0;
            return RouteData(
              points: points,
              distanceMeters: distKm * 1000.0,
              durationSeconds: timeSec,
            );
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Consulta Stadia Maps Valhalla para todo el circuito multiparada en una sola petición
  Future<MultiStopRouteData?> _fetchStadiaValhallaMultiRoute(
    List<LatLng> waypoints,
  ) async {
    try {
      final url = Uri.parse(
        'https://api.stadiamaps.com/route/v1?api_key=${ApiConfig.stadiaApiKey}',
      );
      final body = jsonEncode({
        'locations': waypoints
            .map((pt) => {'lat': pt.latitude, 'lon': pt.longitude})
            .toList(),
        'costing': 'auto',
        'directions_options': {'units': 'kilometers'},
      });

      final response = await _client
          .post(
            url,
            headers: {..._defaultHeaders, 'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final trip = data['trip'] as Map<String, dynamic>?;
        final legsList = trip?['legs'] as List<dynamic>?;
        if (legsList != null && legsList.isNotEmpty) {
          final List<LatLng> fullPoints = [];
          final List<List<LatLng>> legPoints = [];
          final List<double> legDistances = [];
          final List<double> legDurations = [];
          double totalDistMeters = 0;
          double totalDurSeconds = 0;

          for (int i = 0; i < legsList.length; i++) {
            final leg = legsList[i] as Map<String, dynamic>;
            final shape = leg['shape'] as String? ?? '';
            final summary = leg['summary'] as Map<String, dynamic>?;
            final pts = _decodePolyline6(shape);
            final distMeters =
                ((summary?['length'] as num?)?.toDouble() ?? 0.0) * 1000.0;
            final durSec = (summary?['time'] as num?)?.toDouble() ?? 0.0;

            legPoints.add(pts);
            legDistances.add(distMeters);
            legDurations.add(durSec);
            totalDistMeters += distMeters;
            totalDurSeconds += durSec;

            if (fullPoints.isNotEmpty && pts.isNotEmpty) {
              fullPoints.addAll(pts.skip(1));
            } else {
              fullPoints.addAll(pts);
            }

            // Guardar cada tramo en caché para uso inmediato
            if (i + 1 < waypoints.length && pts.length > 2) {
              final s = waypoints[i];
              final e = waypoints[i + 1];
              final key =
                  '${s.latitude.toStringAsFixed(4)},${s.longitude.toStringAsFixed(4)}_'
                  '${e.latitude.toStringAsFixed(4)},${e.longitude.toStringAsFixed(4)}';
              _segmentCache[key] = RouteData(
                points: pts,
                distanceMeters: distMeters,
                durationSeconds: durSec,
              );
            }
          }

          if (fullPoints.length > 2) {
            return MultiStopRouteData(
              fullPoints: fullPoints,
              legPoints: legPoints,
              legDistancesMeters: legDistances,
              legDurationsSeconds: legDurations,
              totalDistanceMeters: totalDistMeters,
              totalDurationSeconds: totalDurSeconds,
            );
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Consulta un servidor compatible con OSRM para un tramo individual
  Future<RouteData?> _fetchOsrmSingleRoute(
    String baseUrl,
    LatLng start,
    LatLng end,
  ) async {
    try {
      final url = Uri.parse(
        '$baseUrl/'
        '${start.longitude.toStringAsFixed(5)},${start.latitude.toStringAsFixed(5)};'
        '${end.longitude.toStringAsFixed(5)},${end.latitude.toStringAsFixed(5)}'
        '?overview=full&geometries=geojson',
      );

      final response = await _client
          .get(url, headers: _defaultHeaders)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List<dynamic>;

          final points = coordinates.map<LatLng>((coord) {
            final list = coord as List<dynamic>;
            return LatLng(
              (list[1] as num).toDouble(),
              (list[0] as num).toDouble(),
            );
          }).toList();

          final distance = (route['distance'] as num).toDouble();
          final duration = (route['duration'] as num).toDouble();

          return RouteData(
            points: points,
            distanceMeters: distance,
            durationSeconds: duration,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Consulta un servidor compatible con OSRM para todo el circuito multiparada en una sola llamada
  Future<MultiStopRouteData?> _fetchOsrmMultiRoute(
    String baseUrl,
    List<LatLng> waypoints,
  ) async {
    try {
      final coordsParam = waypoints
          .map(
            (pt) =>
                '${pt.longitude.toStringAsFixed(5)},${pt.latitude.toStringAsFixed(5)}',
          )
          .join(';');

      final url = Uri.parse(
        '$baseUrl/$coordsParam?overview=full&geometries=geojson',
      );

      final response = await _client
          .get(url, headers: _defaultHeaders)
          .timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List<dynamic>;

          final fullPoints = coordinates.map<LatLng>((coord) {
            final list = coord as List<dynamic>;
            return LatLng(
              (list[1] as num).toDouble(),
              (list[0] as num).toDouble(),
            );
          }).toList();

          final legsJson = (route['legs'] as List<dynamic>? ?? []);
          final List<double> legDistances = [];
          final List<double> legDurations = [];
          for (final l in legsJson) {
            final legMap = l as Map<String, dynamic>;
            legDistances.add((legMap['distance'] as num?)?.toDouble() ?? 0.0);
            legDurations.add((legMap['duration'] as num?)?.toDouble() ?? 0.0);
          }

          final totalDistance = (route['distance'] as num).toDouble();
          final totalDuration = (route['duration'] as num).toDouble();

          return MultiStopRouteData(
            fullPoints: fullPoints,
            legPoints: [fullPoints],
            legDistancesMeters: legDistances,
            legDurationsSeconds: legDurations,
            totalDistanceMeters: totalDistance,
            totalDurationSeconds: totalDuration,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Decodificador de geometría vial Valhalla Polyline6 (precisión 1e-6)
  List<LatLng> _decodePolyline6(String encoded) {
    const double inv = 1.0 / 1e6;
    final List<LatLng> decoded = [];
    int prevLat = 0;
    int prevLon = 0;
    int i = 0;
    final int len = encoded.length;

    while (i < len) {
      int shift = 0;
      int result = 0;
      int byte;
      do {
        if (i >= len) break;
        byte = encoded.codeUnitAt(i++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final int dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      prevLat += dLat;

      shift = 0;
      result = 0;
      do {
        if (i >= len) break;
        byte = encoded.codeUnitAt(i++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final int dLon = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      prevLon += dLon;

      decoded.add(LatLng(prevLat * inv, prevLon * inv));
    }

    return decoded;
  }
}
