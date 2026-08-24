/// Modelo de telemetría GPS para transmisión en tiempo real vía WebSocket
class CourierLocationPayload {
  final String courierId;
  final String courierName;
  final double latitude;
  final double longitude;
  final double speed;        // Velocidad en km/h
  final double heading;      // Dirección/rumbo en grados (0-360)
  final String? activeOrderId; // ID del pedido en curso (o null si solo patrulla/libre)
  final int batteryLevel;    // Nivel de batería en porcentaje (0-100)
  final DateTime timestamp;

  CourierLocationPayload({
    required this.courierId,
    required this.courierName,
    required this.latitude,
    required this.longitude,
    this.speed = 0.0,
    this.heading = 0.0,
    this.activeOrderId,
    this.batteryLevel = 100,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toUtc();

  /// Convierte al formato exacto requerido por el WebSocket
  Map<String, dynamic> toWebSocketEvent() {
    return {
      "event": "courier_location_update",
      "data": {
        "courierId": courierId,
        "courierName": courierName,
        "latitude": double.parse(latitude.toStringAsFixed(6)),
        "longitude": double.parse(longitude.toStringAsFixed(6)),
        "speed": double.parse(speed.toStringAsFixed(1)),
        "heading": double.parse(heading.toStringAsFixed(1)),
        "activeOrderId": activeOrderId,
        "batteryLevel": batteryLevel,
        "timestamp": timestamp.toIso8601String(),
      }
    };
  }

  factory CourierLocationPayload.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return CourierLocationPayload(
      courierId: data['courierId'] ?? '',
      courierName: data['courierName'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      speed: (data['speed'] ?? 0).toDouble(),
      heading: (data['heading'] ?? 0).toDouble(),
      activeOrderId: data['activeOrderId'],
      batteryLevel: (data['batteryLevel'] ?? 100) as int,
      timestamp: data['timestamp'] != null
          ? DateTime.tryParse(data['timestamp'])?.toUtc()
          : null,
    );
  }
}
