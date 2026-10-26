import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../config/api_config.dart';
import '../models/courier_model.dart';
import '../models/location_data_model.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/websocket_service.dart';

/// Estado de telemetría GPS y conexión en tiempo real del domiciliario.
class TrackingState {
  /// Indica si la captura y transmisión periódica de ubicación está activa.
  final bool isTrackingActive;

  /// Coordenada GPS actual del domiciliario.
  final LatLng? currentLocation;

  /// Velocidad actual en kilómetros por hora.
  final double speed;

  /// Rumbo actual en grados (0 a 360).
  final double heading;

  /// Nivel actual de batería del dispositivo (0 a 100).
  final int batteryLevel;

  /// Estado actual del canal WebSocket.
  final WsConnectionStatus wsStatus;

  /// Fecha y hora de la última transmisión exitosa.
  final DateTime? lastTransmission;

  /// Contador total de paquetes de telemetría enviados en la sesión.
  final int totalPacketsSent;

  /// Crea una nueva instancia de [TrackingState].
  const TrackingState({
    this.isTrackingActive = false,
    this.currentLocation,
    this.speed = 0.0,
    this.heading = 0.0,
    this.batteryLevel = 100,
    this.wsStatus = WsConnectionStatus.disconnected,
    this.lastTransmission,
    this.totalPacketsSent = 0,
  });

  /// Crea una copia de [TrackingState] reemplazando los valores indicados.
  TrackingState copyWith({
    bool? isTrackingActive,
    LatLng? currentLocation,
    double? speed,
    double? heading,
    int? batteryLevel,
    WsConnectionStatus? wsStatus,
    DateTime? lastTransmission,
    int? totalPacketsSent,
  }) {
    return TrackingState(
      isTrackingActive: isTrackingActive ?? this.isTrackingActive,
      currentLocation: currentLocation ?? this.currentLocation,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      wsStatus: wsStatus ?? this.wsStatus,
      lastTransmission: lastTransmission ?? this.lastTransmission,
      totalPacketsSent: totalPacketsSent ?? this.totalPacketsSent,
    );
  }
}

/// Cubit que coordina la lectura de GPS y su transmisión simultánea vía WebSocket y API REST.
class TrackingCubit extends Cubit<TrackingState> {
  /// Servicio de geolocalización y batería del dispositivo.
  final LocationService _locationService;

  /// Servicio de comunicación en tiempo real por WebSocket.
  final WebSocketService _wsService;

  /// Servicio REST para actualizar la ubicación persistida en el backend.
  final ApiService _apiService;

  /// Temporizador periódico de transmisión de telemetría.
  Timer? _telemetryTimer;

  /// Suscripción a cambios de estado de la conexión WebSocket.
  StreamSubscription<WsConnectionStatus>? _wsStatusSubscription;

  /// Suscripción al flujo de posiciones GPS del dispositivo.
  StreamSubscription<Position>? _positionSubscription;

  /// Perfil del domiciliario actualmente en turno.
  CourierModel? _currentCourier;

  /// Identificador de la orden activa en curso.
  String? _activeOrderId;

  /// Crea una instancia de [TrackingCubit] permitiendo inyectar sus servicios dependientes.
  TrackingCubit({
    LocationService? locationService,
    WebSocketService? wsService,
    ApiService? apiService,
  })  : _locationService = locationService ?? LocationService(),
        _wsService = wsService ?? WebSocketService(),
        _apiService = apiService ?? ApiService(),
        super(const TrackingState()) {
    _wsStatusSubscription = _wsService.connectionStatusStream.listen((status) {
      emit(state.copyWith(wsStatus: status));
    });
  }

  /// Sincroniza el inicio o detención del rastreo GPS según el estado de turno del domiciliario.
  void syncWithShiftStatus({
    required CourierModel? courier,
    required String? activeOrderId,
  }) {
    _currentCourier = courier;
    _activeOrderId = activeOrderId;

    if (courier != null && courier.isOnline) {
      startTracking();
    } else {
      stopTracking();
    }
  }

  /// Actualiza el identificador del pedido activo asociado a la telemetría.
  void updateActiveOrder(String? orderId) {
    _activeOrderId = orderId;
  }

  /// Inicia la captura de coordenadas GPS y establece la conexión WebSocket.
  Future<void> startTracking() async {
    if (state.isTrackingActive) return;

    emit(state.copyWith(isTrackingActive: true));
    try {
      _wsService.connect();

      final initialPos = await _locationService.getCurrentPosition();
      if (initialPos != null) {
        final safeLoc = LocationService.isWithinColombia(
          initialPos.latitude,
          initialPos.longitude,
        )
            ? LatLng(initialPos.latitude, initialPos.longitude)
            : LocationService.defaultLocation;
        emit(state.copyWith(
          currentLocation: safeLoc,
          speed: initialPos.speed * 3.6,
          heading: initialPos.heading,
        ));
        await _sendTelemetryPacket(initialPos);
      }

      _telemetryTimer?.cancel();
      _telemetryTimer = Timer.periodic(
        const Duration(seconds: ApiConfig.telemetryIntervalSeconds),
        (_) => _tickTelemetry(),
      );
    } catch (_) {}
  }

  /// Ejecuta un ciclo periódico de lectura y transmisión GPS.
  Future<void> _tickTelemetry() async {
    if (!state.isTrackingActive) return;
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        await _sendTelemetryPacket(position);
      }
    } catch (_) {}
  }

  /// Construye y transmite el paquete de ubicación por WebSocket y mediante `PUT /couriers/{id}/location`.
  Future<void> _sendTelemetryPacket(Position position) async {
    try {
      final battery = await _locationService.getBatteryLevel();
      final currentLatLng = LocationService.isWithinColombia(
        position.latitude,
        position.longitude,
      )
          ? LatLng(position.latitude, position.longitude)
          : LocationService.defaultLocation;

      final courierIdStr = _currentCourier?.id ?? '';
      final courierNameStr = _currentCourier?.nombre ?? '';

      final payload = CourierLocationPayload(
        courierId: courierIdStr,
        courierName: courierNameStr,
        latitude: currentLatLng.latitude,
        longitude: currentLatLng.longitude,
        speed: position.speed > 0 ? (position.speed * 3.6) : 0.0,
        heading: position.heading,
        activeOrderId: _activeOrderId,
        batteryLevel: battery,
        timestamp: DateTime.now().toUtc(),
      );

      _wsService.sendLocationUpdate(payload);

      final parsedCourierId = int.tryParse(courierIdStr) ?? 0;
      if (parsedCourierId > 0) {
        await _apiService.updateLocation(
          courierId: parsedCourierId,
          latitude: currentLatLng.latitude,
          longitude: currentLatLng.longitude,
          token: _currentCourier?.token,
        );
      }

      emit(state.copyWith(
        currentLocation: currentLatLng,
        speed: payload.speed,
        heading: payload.heading,
        batteryLevel: battery,
        lastTransmission: DateTime.now(),
        totalPacketsSent: state.totalPacketsSent + 1,
      ));
    } catch (_) {}
  }

  /// Detiene el temporizador de telemetría y cierra la conexión WebSocket.
  void stopTracking() {
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _wsService.disconnect();

    emit(state.copyWith(
      isTrackingActive: false,
      wsStatus: WsConnectionStatus.disconnected,
    ));
  }

  /// Libera los recursos asociados al Cubit al cerrarse.
  @override
  Future<void> close() {
    _telemetryTimer?.cancel();
    _wsStatusSubscription?.cancel();
    _positionSubscription?.cancel();
    _wsService.dispose();
    _locationService.dispose();
    return super.close();
  }
}
