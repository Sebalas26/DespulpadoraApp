import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import '../models/location_data_model.dart';

/// Estado de la conexión WebSocket
enum WsConnectionStatus { disconnected, connecting, connected }

/// Servicio para la transmisión de telemetría GPS en vivo vía WebSockets
class WebSocketService {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _isManualDisconnect = false;

  final _connectionStatusController = StreamController<WsConnectionStatus>.broadcast();
  Stream<WsConnectionStatus> get connectionStatusStream => _connectionStatusController.stream;
  WsConnectionStatus _currentStatus = WsConnectionStatus.disconnected;
  WsConnectionStatus get currentStatus => _currentStatus;

  final _incomingMessagesController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get incomingMessagesStream => _incomingMessagesController.stream;

  /// Inicia la conexión con el servidor WebSocket
  void connect() {
    _isManualDisconnect = false;
    _establishConnection();
  }

  void _updateStatus(WsConnectionStatus status) {
    _currentStatus = status;
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(status);
    }
  }

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

  void _startPingHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_currentStatus == WsConnectionStatus.connected) {
        sendEvent('ping', {'timestamp': DateTime.now().toUtc().toIso8601String()});
      }
    });
  }

  void _handleDisconnection() {
    _pingTimer?.cancel();
    _updateStatus(WsConnectionStatus.disconnected);

    if (!_isManualDisconnect) {
      dev.log('[WebSocket] Reintentando conexión en 5 segundos...', name: 'PulpasProWS');
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 5), () {
        _establishConnection();
      });
    }
  }

  /// Envía un evento genérico en formato JSON
  bool sendEvent(String eventName, Map<String, dynamic> data) {
    final payload = {
      'event': eventName,
      'data': data,
    };
    return sendRawJson(payload);
  }

  /// Envía la telemetría GPS del mensajero en el formato solicitado
  bool sendLocationUpdate(CourierLocationPayload payload) {
    return sendRawJson(payload.toWebSocketEvent());
  }

  /// Serializa y envía un mapa JSON por el canal
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

  /// Desconecta manualmente el socket (ej. al salir de turno o cerrar sesión)
  void disconnect() {
    _isManualDisconnect = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _updateStatus(WsConnectionStatus.disconnected);
    dev.log('[WebSocket] Desconectado por el usuario', name: 'PulpasProWS');
  }

  void dispose() {
    disconnect();
    _connectionStatusController.close();
    _incomingMessagesController.close();
  }
}
