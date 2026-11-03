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

  /// Nivel de batería en caché para no bloquear el envío en tiempo real de coordenadas GPS.
  int _cachedBatteryLevel = 100;

  /// Indica si hay una petición REST de ubicación en curso para evitar encolamiento.
  bool _isRestUpdateInFlight = false;

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

  /// Sincroniza el inicio o detención del rastreo GPS según el estado de turno y de ruta activa del domiciliario.
  void syncWithShiftStatus({
    required CourierModel? courier,
    required String? activeOrderId,
    bool isRouteInProgress = false,
  }) {
    try {
      _currentCourier = courier;
      _activeOrderId = activeOrderId;

      if (courier != null && courier.isOnline && isRouteInProgress) {
        startTracking();
      } else {
        stopTracking();
      }
    } catch (_) {
      stopTracking();
    }
  }

  /// Actualiza el identificador del pedido activo asociado a la telemetría.
  void updateActiveOrder(String? orderId) {
    _activeOrderId = orderId;
  }

  /// Inicia la captura continua de coordenadas GPS en tiempo real y establece la conexión WebSocket.
  Future<void> startTracking() async {
    if (state.isTrackingActive) return;

    emit(state.copyWith(isTrackingActive: true));
    try {
      _wsService.connect();
      _refreshBatteryCache();

      _positionSubscription?.cancel();
      _positionSubscription = _locationService
          .getPositionStream(intervalSeconds: 0)
          .listen((Position pos) {
        if (state.isTrackingActive) {
          _sendTelemetryPacket(pos);
        }
      }, onError: (_) {});

      final Position? initialPos = await _locationService.getCurrentPosition();
      if (initialPos != null) {
        final LatLng safeLoc = LocationService.isWithinColombia(
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

  /// Actualiza en segundo plano el nivel de batería en caché sin retrasar la transmisión GPS.
  Future<void> _refreshBatteryCache() async {
    try {
      final int level = await _locationService.getBatteryLevel();
      _cachedBatteryLevel = level;
    } catch (_) {}
  }

  /// Ejecuta un ciclo periódico de lectura y transmisión GPS.
  Future<void> _tickTelemetry() async {
    if (!state.isTrackingActive) return;
    try {
      _refreshBatteryCache();
      final Position? position = await _locationService.getCurrentPosition();
      if (position != null) {
        await _sendTelemetryPacket(position);
      }
    } catch (_) {}
  }

  /// Construye y transmite al instante el paquete de ubicación por WebSocket y mediante `PUT /couriers/{id}/location`.
  Future<void> _sendTelemetryPacket(Position position) async {
    try {
      final int battery = _cachedBatteryLevel;
      final LatLng currentLatLng = LocationService.isWithinColombia(
        position.latitude,
        position.longitude,
      )
          ? LatLng(position.latitude, position.longitude)
          : LocationService.defaultLocation;

      final String courierIdStr = _currentCourier?.id ?? '';
      final String courierNameStr = _currentCourier?.nombre ?? '';

      final CourierLocationPayload payload = CourierLocationPayload(
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

      emit(state.copyWith(
        currentLocation: currentLatLng,
        speed: payload.speed,
        heading: payload.heading,
        batteryLevel: battery,
        lastTransmission: DateTime.now(),
        totalPacketsSent: state.totalPacketsSent + 1,
      ));

      final int parsedCourierId = int.tryParse(courierIdStr) ?? 0;
      if (parsedCourierId > 0 && !_isRestUpdateInFlight) {
        _isRestUpdateInFlight = true;
        try {
          await _apiService.updateLocation(
            courierId: parsedCourierId,
            latitude: currentLatLng.latitude,
            longitude: currentLatLng.longitude,
            token: _currentCourier?.token,
          );
        } finally {
          _isRestUpdateInFlight = false;
        }
      }
    } catch (_) {
      _isRestUpdateInFlight = false;
    }
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
