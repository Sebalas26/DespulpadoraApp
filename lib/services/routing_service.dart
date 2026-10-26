import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'location_service.dart';

/// Información geométrica y métrica de un tramo vial individual entre dos puntos.
class RouteData {
  /// Lista de coordenadas que conforman la polilínea vial del tramo.
  final List<LatLng> points;

  /// Distancia total del tramo en metros.
  final double distanceMeters;

  /// Duración estimada del tramo en segundos.
  final double durationSeconds;

  /// Crea una nueva instancia de [RouteData].
  RouteData({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  /// Distancia del tramo formateada en metros o kilómetros.
  String get distanceFormatted {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toInt()} m';
    } else {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Duración estimada del tramo redondeada en minutos.
  int get durationMinutes {
    final mins = (durationSeconds / 60).round();
    return mins < 1 ? 1 : mins;
  }
}

/// Información consolidada del enrutado multiparada completo del domiciliario.
class MultiStopRouteData {
  /// Polilínea completa continua de todas las paradas de la ruta.
  final List<LatLng> fullPoints;

  /// Lista de polilíneas desglosada por cada tramo entre paradas.
  final List<List<LatLng>> legPoints;

  /// Distancias en metros correspondientes a cada tramo individual.
  final List<double> legDistancesMeters;

  /// Duraciones en segundos correspondientes a cada tramo individual.
  final List<double> legDurationsSeconds;

  /// Distancia total acumulada del circuito en metros.
  final double totalDistanceMeters;

  /// Duración total acumulada del circuito en segundos.
  final double totalDurationSeconds;

  /// Crea una nueva instancia de [MultiStopRouteData].
  MultiStopRouteData({
    required this.fullPoints,
    required this.legPoints,
    required this.legDistancesMeters,
    required this.legDurationsSeconds,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
  });

  /// Distancia total del circuito formateada en metros o kilómetros.
  String get totalDistanceFormatted {
    if (totalDistanceMeters < 1000) {
      return '${totalDistanceMeters.toInt()} m';
    } else {
      return '${(totalDistanceMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Duración total estimada del circuito en minutos.
  int get totalDurationMinutes {
    final mins = (totalDurationSeconds / 60).round();
    return mins < 1 ? 1 : mins;
  }
}

/// Servicio de cálculo de rutas viales calle por calle mediante motores OpenStreetMap (Valhalla y OSRM).
class RoutingService {
  /// Cliente HTTP para realizar consultas a los motores de enrutamiento.
  final http.Client _client;

  /// Caché en memoria de segmentos viales previamente calculados.
  static final Map<String, RouteData> _segmentCache = {};

  /// Cabeceras HTTP estándar para peticiones a servidores cartográficos.
  static const Map<String, String> _defaultHeaders = {
    'User-Agent': 'PulpasProApp/1.0 (com.pulpaspro.despulpadora_app)',
    'Accept': 'application/json',
  };

  /// Crea una instancia de [RoutingService] permitiendo inyectar un [http.Client].
  RoutingService({http.Client? client}) : _client = client ?? http.Client();

  /// Asegura que la coordenada se encuentre dentro de los límites geográficos válidos.
  LatLng _ensureColombiaCoord(LatLng pt) {
    if (LocationService.isWithinColombia(pt.latitude, pt.longitude)) {
      return pt;
    }
    return LocationService.defaultLocation;
  }

  /// Obtiene el trazado vial entre una coordenada de origen y una de destino.
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

    try {
      final valhallaRoute = await _fetchValhallaSingleRoute(safeStart, safeEnd);
      if (valhallaRoute != null && valhallaRoute.points.length > 2) {
        _segmentCache[cacheKey] = valhallaRoute;
        return valhallaRoute;
      }

      final osrmRoute = await _fetchOsrmSingleRoute(
        'https://router.project-osrm.org/route/v1/driving',
        safeStart,
        safeEnd,
      );
      if (osrmRoute != null && osrmRoute.points.length > 2) {
        _segmentCache[cacheKey] = osrmRoute;
        return osrmRoute;
      }

      final osmDeRoute = await _fetchOsrmSingleRoute(
        'https://routing.openstreetmap.de/routed-car/route/v1/driving',
        safeStart,
        safeEnd,
      );
      if (osmDeRoute != null && osmDeRoute.points.length > 2) {
        _segmentCache[cacheKey] = osmDeRoute;
        return osmDeRoute;
      }
    } catch (_) {}

    final straightDistance =
        const Distance().as(LengthUnit.Meter, safeStart, safeEnd);
    return RouteData(
      points: [safeStart, safeEnd],
      distanceMeters: straightDistance,
      durationSeconds: (straightDistance / 7.2),
    );
  }

  /// Calcula el circuito vial completo secuencial para una lista de paradas.
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

    try {
      final valhallaMulti = await _fetchValhallaMultiRoute(safeWaypoints);
      if (valhallaMulti != null && valhallaMulti.fullPoints.length > 5) {
        return valhallaMulti;
      }

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
    } catch (_) {}

    final List<LatLng> fullRoadPath = [];
    final List<List<LatLng>> legs = [];
    final List<double> legDistances = [];
    final List<double> legDurations = [];
    double totalDist = 0;
    double totalDur = 0;

    for (int i = 0; i < safeWaypoints.length - 1; i++) {
      final seg = await getRoute(
        start: safeWaypoints[i],
        end: safeWaypoints[i + 1],
      );
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

  /// Consulta el motor Valhalla OpenStreetMap para un tramo individual.
  Future<RouteData?> _fetchValhallaSingleRoute(LatLng start, LatLng end) async {
    try {
      final url = Uri.parse('https://valhalla1.openstreetmap.de/route');
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
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
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

  /// Consulta el motor Valhalla OpenStreetMap para un circuito multiparada.
  Future<MultiStopRouteData?> _fetchValhallaMultiRoute(
    List<LatLng> waypoints,
  ) async {
    try {
      final url = Uri.parse('https://valhalla1.openstreetmap.de/route');
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
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
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

  /// Consulta un servidor compatible con OSRM para un tramo individual.
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
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0] as Map<String, dynamic>;
          final geometry = route['geometry'] as Map<String, dynamic>;
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

  /// Consulta un servidor compatible con OSRM para un circuito multiparada.
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
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0] as Map<String, dynamic>;
          final geometry = route['geometry'] as Map<String, dynamic>;
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

  /// Decodifica una cadena en formato Polyline6 a una lista de coordenadas [LatLng].
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
