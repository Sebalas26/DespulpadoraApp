/// Modelo de telemetría GPS para transmisión en tiempo real vía WebSocket y API REST.
class CourierLocationPayload {
  /// Identificador único del domiciliario que transmite su ubicación.
  final String courierId;

  /// Nombre completo del domiciliario.
  final String courierName;

  /// Latitud geográfica actual en grados decimales.
  final double latitude;

  /// Longitud geográfica actual en grados decimales.
  final double longitude;

  /// Velocidad de desplazamiento en kilómetros por hora.
  final double speed;

  /// Rumbo o dirección en grados sexagesimales (0 a 360).
  final double heading;

  /// Identificador del pedido activo en curso, si existe.
  final String? activeOrderId;

  /// Nivel de batería del dispositivo móvil en porcentaje (0 a 100).
  final int batteryLevel;

  /// Marca de tiempo UTC de la lectura GPS.
  final DateTime timestamp;

  /// Crea una nueva instancia de [CourierLocationPayload].
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

  /// Convierte el payload al formato de evento requerido por el servidor WebSocket.
  Map<String, dynamic> toWebSocketEvent() {
    return {
      'event': 'courier_location_update',
      'data': {
        'courierId': courierId,
        'courierName': courierName,
        'latitude': double.parse(latitude.toStringAsFixed(6)),
        'longitude': double.parse(longitude.toStringAsFixed(6)),
        'speed': double.parse(speed.toStringAsFixed(1)),
        'heading': double.parse(heading.toStringAsFixed(1)),
        'activeOrderId': activeOrderId,
        'batteryLevel': batteryLevel,
        'timestamp': timestamp.toIso8601String(),
      },
    };
  }

  /// Construye una instancia de [CourierLocationPayload] a partir de un mapa JSON.
  factory CourierLocationPayload.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return CourierLocationPayload(
      courierId: (data['courierId'] ?? '').toString(),
      courierName: (data['courierName'] ?? '').toString(),
      latitude: ((data['latitude'] ?? 0) as num).toDouble(),
      longitude: ((data['longitude'] ?? 0) as num).toDouble(),
      speed: ((data['speed'] ?? 0) as num).toDouble(),
      heading: ((data['heading'] ?? 0) as num).toDouble(),
      activeOrderId: data['activeOrderId']?.toString(),
      batteryLevel: ((data['batteryLevel'] ?? 100) as num).toInt(),
      timestamp: data['timestamp'] != null
          ? DateTime.tryParse(data['timestamp'].toString())?.toUtc()
          : null,
    );
  }
}
