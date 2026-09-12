import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/courier_model.dart';
import '../models/order_model.dart';

/// Servicio de comunicación REST API para autenticación y gestión de pedidos
class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Mock Data para pruebas locales y modo demo cuando el backend esté inaccesible
  static final CourierModel mockCourier = CourierModel(
    id: '1',
    nombre: 'Carlos Mendoza (Operador Cava)',
    placaVehiculo: 'XYZ-789 (Yamaha FZ)',
    telefono: '+57 312 456 7890',
    email: 'admin@pulpaspro.com',
    token: 'jwt_token_demo_courier_01',
    isOnline: true,
  );

  static List<OrderModel> getMockOrders() {
    return [
      OrderModel(
        id: 'ORD-2026-001',
        clienteNombre: 'Restaurante & Frutería El Oasis',
        clienteTelefono: '+57 315 889 4432',
        direccion: 'Calle 72 # 11-45',
        barrio: 'Chapinero Norte',
        ciudad: 'Bogotá',
        latitud: 4.65685,
        longitud: -74.05928,
        montoTotal: 148000,
        metodoPago: 'Efectivo Contraentrega',
        requiereCobro: true,
        estado: OrderStatus.asignado,
        prioridad: 1,
        notasEntrega: 'Entregar en la cocina, preguntar por Don Mario. Traer cambio de \$200.000.',
        items: [
          OrderItem(nombre: 'Pulpa Maracuyá', presentacion: '1000g / 1Kg', cantidad: 10, precioUnitario: 8500),
          OrderItem(nombre: 'Pulpa Mango Tommy', presentacion: '1000g / 1Kg', cantidad: 5, precioUnitario: 7600),
          OrderItem(nombre: 'Pulpa Lulo', presentacion: '1000g / 1Kg', cantidad: 3, precioUnitario: 8333),
        ],
      ),
      OrderModel(
        id: 'ORD-2026-002',
        clienteNombre: 'Plaza Mercado Las Ferias',
        clienteTelefono: '+57 310 234 5678',
        direccion: 'Av. 70 #74-52',
        barrio: 'Antiguo Country',
        ciudad: 'Bogotá',
        latitud: 4.68637,
        longitud: -74.08943,
        montoTotal: 84000,
        metodoPago: 'Transferencia Nequi (Verificado)',
        requiereCobro: false,
        estado: OrderStatus.enCamino,
        prioridad: 2,
        notasEntrega: 'Pago previo verificado por administración. Solo entregar y firmar remisión.',
        items: [
          OrderItem(nombre: 'Pulpa Guanábana', presentacion: '140g (Porción)', cantidad: 20, precioUnitario: 2200),
          OrderItem(nombre: 'Pulpa Fresa', presentacion: '140g (Porción)', cantidad: 20, precioUnitario: 2000),
        ],
      ),
      OrderModel(
        id: 'ORD-2026-003',
        clienteNombre: 'Heladería Artesanal Frutos del Bosque',
        clienteTelefono: '+57 320 998 1122',
        direccion: 'Calle 93B # 13-24',
        barrio: 'Chicó',
        ciudad: 'Bogotá',
        latitud: 4.67845,
        longitud: -74.05312,
        montoTotal: 215000,
        metodoPago: 'Efectivo Contraentrega',
        requiereCobro: true,
        estado: OrderStatus.asignado,
        prioridad: 2,
        notasEntrega: 'Timbrar en portería y solicitar acceso a parqueadero de descargue.',
        items: [
          OrderItem(nombre: 'Pulpa Mora de Castilla', presentacion: '1000g / 1Kg', cantidad: 12, precioUnitario: 7500),
          OrderItem(nombre: 'Pulpa Feijoa', presentacion: '1000g / 1Kg', cantidad: 8, precioUnitario: 8800),
          OrderItem(nombre: 'Pulpa Piña Oro Miel', presentacion: '1000g / 1Kg', cantidad: 6, precioUnitario: 9100),
        ],
      )
    ];
  }

  /// Autenticación de mensajero conectada a ApiDespulpadora (/auth/login-mobile)
  Future<CourierModel> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}');
    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': usernameOrEmail.trim(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final userData = data['user'] as Map<String, dynamic>? ?? {};
        final token = data['accessToken'] as String?;

        return CourierModel(
          id: userData['id']?.toString() ?? '1',
          nombre: userData['fullName'] ?? userData['username'] ?? 'Mensajero',
          placaVehiculo: 'XYZ-789',
          telefono: userData['phone'] ?? '+57 312 456 7890',
          email: userData['email'] ?? usernameOrEmail,
          token: token,
          isOnline: true,
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Credenciales incorrectas');
      }
    } catch (e) {
      // Fallback a login local / demo si el servidor está apagado
      if (usernameOrEmail.isNotEmpty) {
        return mockCourier.copyWith(
          nombre: usernameOrEmail.contains('@') 
              ? usernameOrEmail.split('@')[0].toUpperCase() 
              : 'Mensajero $usernameOrEmail',
          email: usernameOrEmail.contains('@') ? usernameOrEmail : 'courier@pulpaspro.com',
        );
      }
      rethrow;
    }
  }

  /// Obtiene la lista de pedidos asignados al mensajero desde la API
  Future<List<OrderModel>> fetchAssignedOrders({required String courierId, String? token}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.ordersEndpoint}?courierId=$courierId');
    try {
      final response = await _client.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        final List<dynamic> list = data is List ? data : (data['orders'] ?? data['data'] ?? []);
        if (list.isNotEmpty) {
          return list.map((json) => OrderModel.fromJson(json as Map<String, dynamic>)).toList();
        }
        return getMockOrders();
      } else {
        return getMockOrders();
      }
    } catch (e) {
      // Retorna pedidos de prueba si falla la conexión
      return getMockOrders();
    }
  }

  /// Actualiza el estado de una orden (asignado -> en_ruta -> entregado)
  Future<bool> updateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    String? token,
    Map<String, dynamic>? extraData,
  }) async {
    final statusStr = newStatus == OrderStatus.enCamino
        ? 'en_ruta'
        : newStatus == OrderStatus.enPunto
            ? 'en_punto'
            : newStatus == OrderStatus.entregado
                ? 'entregado'
                : newStatus == OrderStatus.novedad
                    ? 'novedad'
                    : 'asignado';

    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.updateStatusEndpoint}/$orderId/status');
    try {
      final response = await _client.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'status': statusStr,
        }),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return true;
    }
  }

  /// Reporta una novedad o motivo de no entrega
  Future<bool> reportNovelty({
    required String orderId,
    required String reason,
    String? token,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.noveltyEndpoint}/$orderId/novelty');
    try {
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'noveltyNotes': reason,
          'newStatus': 'novedad',
        }),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return true;
    }
  }

  /// Envía telemetría GPS del repartidor a la API Central
  Future<bool> updateLocation({
    required int courierId,
    required double latitude,
    required double longitude,
    String? token,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.couriersEndpoint}/$courierId/location');
    try {
      final response = await _client.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
        }),
      ).timeout(const Duration(seconds: 4));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  /// Actualiza el estado de turno del repartidor (disponible, en_ruta, fuera_turno)
  Future<bool> updateShiftStatus({
    required int courierId,
    required String status,
    String? token,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.couriersEndpoint}/$courierId/shift-status');
    try {
      final response = await _client.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'status': status,
        }),
      ).timeout(const Duration(seconds: 4));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }
}
