import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../config/api_config.dart';
import '../models/courier_model.dart';
import '../models/location_data_model.dart';
import '../services/location_service.dart';
import '../services/websocket_service.dart';

class TrackingState {
  final bool isTrackingActive;
  final LatLng? currentLocation;
  final double speed;
  final double heading;
  final int batteryLevel;
  final WsConnectionStatus wsStatus;
  final DateTime? lastTransmission;
  final int totalPacketsSent;

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

/// Cubit que orquesta la captura GPS y el envío continuo al WebSocket
class TrackingCubit extends Cubit<TrackingState> {
  final LocationService _locationService;
  final WebSocketService _wsService;

  Timer? _telemetryTimer;
  StreamSubscription<WsConnectionStatus>? _wsStatusSubscription;
  StreamSubscription<Position>? _positionSubscription;

  CourierModel? _currentCourier;
  String? _activeOrderId;

  TrackingCubit({
    LocationService? locationService,
    WebSocketService? wsService,
  })  : _locationService = locationService ?? LocationService(),
        _wsService = wsService ?? WebSocketService(),
        super(const TrackingState()) {
    // Escuchar el estado de conexión del WebSocket
    _wsStatusSubscription = _wsService.connectionStatusStream.listen((status) {
      emit(state.copyWith(wsStatus: status));
    });
  }

  /// Inicializa o detiene el rastreo según el estado "En Turno" del mensajero
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

  /// Actualiza el ID de la orden activa en el payload
  void updateActiveOrder(String? orderId) {
    _activeOrderId = orderId;
  }

  /// Inicia el servicio de telemetría GPS y conecta el WebSocket
  Future<void> startTracking() async {
    if (state.isTrackingActive) return;

    emit(state.copyWith(isTrackingActive: true));
    _wsService.connect();

    // Obtener primera posición inmediata
    final initialPos = await _locationService.getCurrentPosition();
    if (initialPos != null) {
      emit(state.copyWith(
        currentLocation: LatLng(initialPos.latitude, initialPos.longitude),
        speed: initialPos.speed * 3.6, // m/s a km/h
        heading: initialPos.heading,
      ));
      _sendTelemetryPacket(initialPos);
    }

    // Timer periódico de telemetría cada N segundos (5s por defecto)
    _telemetryTimer?.cancel();
    _telemetryTimer = Timer.periodic(
      const Duration(seconds: ApiConfig.telemetryIntervalSeconds),
      (_) => _tickTelemetry(),
    );
  }

  Future<void> _tickTelemetry() async {
    if (!state.isTrackingActive) return;

    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      await _sendTelemetryPacket(position);
    }
  }

  Future<void> _sendTelemetryPacket(Position position) async {
    final battery = await _locationService.getBatteryLevel();
    final currentLatLng = LatLng(position.latitude, position.longitude);

    final payload = CourierLocationPayload(
      courierId: _currentCourier?.id ?? 'MENSAJERO-01',
      courierName: _currentCourier?.nombre ?? 'Carlos Mendoza',
      latitude: position.latitude,
      longitude: position.longitude,
      speed: position.speed > 0 ? (position.speed * 3.6) : 0.0,
      heading: position.heading,
      activeOrderId: _activeOrderId,
      batteryLevel: battery,
      timestamp: DateTime.now().toUtc(),
    );

    _wsService.sendLocationUpdate(payload);

    emit(state.copyWith(
      currentLocation: currentLatLng,
      speed: payload.speed,
      heading: payload.heading,
      batteryLevel: battery,
      lastTransmission: DateTime.now(),
      totalPacketsSent: state.totalPacketsSent + 1,
    ));
  }

  /// Detiene la transmisión GPS y desconecta el WebSocket
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
