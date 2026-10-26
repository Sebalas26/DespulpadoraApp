import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import '../models/location_data_model.dart';

/// Estados posibles de la conexión con el servidor WebSocket.
enum WsConnectionStatus {
  /// Canal desconectado o cerrado.
  disconnected,

  /// Intentando establecer conexión con el servidor.
  connecting,

  /// Canal conectado y listo para transmitir telemetría.
  connected,
}

/// Servicio para la transmisión bidireccional de telemetría GPS en tiempo real vía WebSockets.
class WebSocketService {
  /// Canal de comunicación WebSocket activo.
  WebSocketChannel? _channel;

  /// Temporizador de reconexión automática ante caídas de red.
  Timer? _reconnectTimer;

  /// Temporizador de latido (`ping`) para mantener viva la conexión.
  Timer? _pingTimer;

  /// Indica si la desconexión fue solicitada explícitamente por el usuario.
  bool _isManualDisconnect = false;

  /// Controlador de flujo para emitir cambios en el estado de conexión.
  final _connectionStatusController =
      StreamController<WsConnectionStatus>.broadcast();

  /// Flujo reactivo del estado de conexión WebSocket.
  Stream<WsConnectionStatus> get connectionStatusStream =>
      _connectionStatusController.stream;

  /// Estado actual de la conexión WebSocket.
  WsConnectionStatus _currentStatus = WsConnectionStatus.disconnected;

  /// Obtiene el estado actual de la conexión WebSocket.
  WsConnectionStatus get currentStatus => _currentStatus;

  /// Controlador de flujo para mensajes JSON entrantes desde el servidor.
  final _incomingMessagesController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Flujo reactivo de mensajes entrantes desde el servidor WebSocket.
  Stream<Map<String, dynamic>> get incomingMessagesStream =>
      _incomingMessagesController.stream;

  /// Inicia la conexión con el servidor WebSocket configurado en [ApiConfig.wsUrl].
  void connect() {
    _isManualDisconnect = false;
    _establishConnection();
  }

  /// Actualiza el estado interno y notifica a los suscriptores del flujo.
  void _updateStatus(WsConnectionStatus status) {
    _currentStatus = status;
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(status);
    }
  }

  /// Establece el canal WebSocket y configura los manejadores de eventos y errores.
  void _establishConnection() {
    if (_isManualDisconnect) return;
    if (_currentStatus == WsConnectionStatus.connected) return;

    _updateStatus(WsConnectionStatus.connecting);
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();

    try {
      final wsUri = Uri.parse(ApiConfig.wsUrl);
      dev.log('[WebSocket] Conectando a $wsUri...', name: 'PulpasProWS');

      final channel = WebSocketChannel.connect(wsUri);
      _channel = channel;

      channel.ready.then((_) {
        if (!_isManualDisconnect) {
          _updateStatus(WsConnectionStatus.connected);
          dev.log('[WebSocket] Conectado exitosamente', name: 'PulpasProWS');
          _startPingHeartbeat();
        }
      }).catchError((dynamic error) {
        dev.log('[WebSocket Error Handled] $error', name: 'PulpasProWS');
        _handleDisconnection();
      });

      channel.stream.listen(
        (dynamic message) {
          if (_currentStatus != WsConnectionStatus.connected) {
            _updateStatus(WsConnectionStatus.connected);
            _startPingHeartbeat();
          }

          try {
            if (message is String) {
              final decoded = jsonDecode(message);
              if (decoded is Map<String, dynamic>) {
                _incomingMessagesController.add(decoded);
              }
            }
          } catch (_) {}
        },
        onDone: () {
          dev.log('[WebSocket] Conexión cerrada', name: 'PulpasProWS');
          _handleDisconnection();
        },
        onError: (dynamic error) {
          dev.log('[WebSocket Stream Error] $error', name: 'PulpasProWS');
          _handleDisconnection();
        },
        cancelOnError: true,
      );
    } catch (e) {
      dev.log('[WebSocket Excepción Inicial] $e', name: 'PulpasProWS');
      _handleDisconnection();
    }
  }

  /// Inicia el envío periódico de paquetes `ping` para preservar la sesión activa.
  void _startPingHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_currentStatus == WsConnectionStatus.connected) {
        sendEvent(
          'ping',
          {'timestamp': DateTime.now().toUtc().toIso8601String()},
        );
      }
    });
  }

  /// Gestiona la caída de conexión programando un reintento automático si procede.
  void _handleDisconnection() {
    _pingTimer?.cancel();
    _updateStatus(WsConnectionStatus.disconnected);

    if (!_isManualDisconnect) {
      dev.log(
        '[WebSocket] Reintentando conexión en 5 segundos...',
        name: 'PulpasProWS',
      );
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 5), () {
        _establishConnection();
      });
    }
  }

  /// Envía un evento con nombre y carga de datos en formato JSON a través del WebSocket.
  bool sendEvent(String eventName, Map<String, dynamic> data) {
    final payload = {
      'event': eventName,
      'data': data,
    };
    return sendRawJson(payload);
  }

  /// Envía una actualización de ubicación del domiciliario utilizando el contrato de evento WebSocket.
  bool sendLocationUpdate(CourierLocationPayload payload) {
    return sendRawJson(payload.toWebSocketEvent());
  }

  /// Serializa y transmite un mapa JSON por el canal WebSocket activo.
  bool sendRawJson(Map<String, dynamic> jsonMap) {
    if (_channel != null) {
      try {
        final message = jsonEncode(jsonMap);
        _channel?.sink.add(message);
        dev.log('[WebSocket TX] $message', name: 'PulpasProWS');
        return true;
      } catch (e) {
        dev.log('[WebSocket TX Error] $e', name: 'PulpasProWS');
        _handleDisconnection();
        return false;
      }
    }
    return false;
  }

  /// Cierra manualmente la conexión WebSocket y detiene los temporizadores de reconexión.
  void disconnect() {
    _isManualDisconnect = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _updateStatus(WsConnectionStatus.disconnected);
    dev.log('[WebSocket] Desconectado por el usuario', name: 'PulpasProWS');
  }

  /// Libera todos los flujos y recursos del servicio WebSocket.
  void dispose() {
    disconnect();
    _connectionStatusController.close();
    _incomingMessagesController.close();
  }
}
