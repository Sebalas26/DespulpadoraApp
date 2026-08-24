import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Información de la ruta por carreteras reales
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

/// Servicio gratuito de enrutamiento vehicular usando OSRM (Open Source Routing Machine / OpenStreetMap)
class RoutingService {
  final http.Client _client;

  RoutingService({http.Client? client}) : _client = client ?? http.Client();

  /// Obtiene el trazado exacto de calles y giros entre dos coordenadas
  Future<RouteData> getRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    // OSRM público espera: lng,lat;lng,lat
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
      '?overview=full&geometries=geojson',
    );

    try {
      final response = await _client.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List<dynamic>;

          // GeoJSON devuelve [longitud, latitud]
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
    } catch (e) {
      // Fallback a línea recta si no hay conexión o timeout
    }

    // Fallback básico
    final straightDistance = const Distance().as(LengthUnit.Meter, start, end);
    return RouteData(
      points: [start, end],
      distanceMeters: straightDistance,
      durationSeconds: (straightDistance / 7.0), // ~25 km/h
    );
  }
}
