import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/courier_model.dart';
import '../models/order_model.dart';

/// Respuesta estructurada con la información de ruta y pedidos asignados al domiciliario.
class AssignedRouteResponse {
  /// Lista de pedidos asignados en orden secuencial de entrega.
  final List<OrderModel> orders;

  /// Indica si el domiciliario cuenta con una ruta asignada activa.
  final bool hasAssignedRoute;

  /// Indica si el domiciliario ya confirmó la recepción física del cargue.
  final bool isRouteReceived;

  /// Código identificador de la ruta asignada.
  final String assignedRouteCode;

  /// Zona o sector geográfico de la ruta asignada.
  final String assignedRouteZone;

  /// Crea una nueva instancia de [AssignedRouteResponse].
  const AssignedRouteResponse({
    required this.orders,
    this.hasAssignedRoute = false,
    this.isRouteReceived = false,
    this.assignedRouteCode = '',
    this.assignedRouteZone = '',
  });
}

/// Servicio de comunicación HTTP REST contra los endpoints móviles (`/api/mobile`) de ApiDespulpadora.
class ApiService {
  /// Cliente HTTP inyectable para facilitar pruebas unitarias y peticiones reales.
  final http.Client _client;

  /// Crea una instancia de [ApiService] permitiendo inyectar un [http.Client] personalizado.
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Autentica al domiciliario contra el endpoint `/api/mobile/auth/login`.
  Future<CourierModel> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}');
    try {
      final trimmedUser = usernameOrEmail.trim();
      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': trimmedUser,
              'usernameOrEmail': trimmedUser,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final Map<String, dynamic> userData =
            (data['courier'] as Map<String, dynamic>?) ??
                (data['user'] as Map<String, dynamic>?) ??
                data;
        final String? token =
            (data['accessToken'] ?? data['token'] ?? userData['accessToken'])
                ?.toString();

        final rawId = userData['courierId'] ?? userData['id'];
        return CourierModel(
          id: rawId != null ? rawId.toString() : '',
          nombre: (userData['fullName'] ??
                  userData['nombre'] ??
                  userData['courierName'] ??
                  userData['username'] ??
                  '')
              .toString(),
          placaVehiculo:
              (userData['vehiclePlate'] ?? userData['placaVehiculo'] ?? '')
                  .toString(),
          telefono:
              (userData['phone'] ?? userData['telefono'] ?? '').toString(),
          email: (userData['email'] ?? trimmedUser).toString(),
          token: token,
          isOnline: (userData['isOnline'] ?? true) == true,
        );
      } else {
        String errorMessage = 'Credenciales inválidas o acceso no autorizado';
        if (response.body.isNotEmpty) {
          try {
            final Map<String, dynamic> errorData =
                jsonDecode(response.body) as Map<String, dynamic>;
            errorMessage =
                (errorData['message'] ?? errorData['error'] ?? errorMessage)
                    .toString();
          } catch (_) {}
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Error de conexión al autenticar domiciliario: $e');
    }
  }

  /// Consulta la ruta activa y la lista de pedidos asignados al domiciliario en `/api/mobile/orders/assigned`.
  Future<AssignedRouteResponse> fetchAssignedRoute({
    required String courierId,
    String? token,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.assignedOrdersEndpoint}?courierId=$courierId',
    );
    try {
      final response = await _client
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          final orders = decoded
              .map((json) => OrderModel.fromJson(json as Map<String, dynamic>))
              .toList();
          final anyStarted = orders.any((o) => o.estado != OrderStatus.asignado);
          return AssignedRouteResponse(
            orders: orders,
            hasAssignedRoute: orders.isNotEmpty,
            isRouteReceived: anyStarted,
          );
        } else if (decoded is Map<String, dynamic>) {
          final List<dynamic> list =
              (decoded['orders'] ?? decoded['data'] ?? []) as List<dynamic>;
          final orders = list
              .map((json) => OrderModel.fromJson(json as Map<String, dynamic>))
              .toList();
          final anyStarted = orders.any((o) => o.estado != OrderStatus.asignado);
          final bool hasRoute =
              (decoded['hasAssignedRoute'] as bool?) ?? orders.isNotEmpty;
          final bool isReceived =
              (decoded['isRouteReceived'] as bool?) ?? anyStarted;
          final String routeCode =
              (decoded['assignedRouteCode'] ?? decoded['routeCode'] ?? '')
                  .toString();
          final String routeZone =
              (decoded['assignedRouteZone'] ?? decoded['routeZone'] ?? '')
                  .toString();

          return AssignedRouteResponse(
            orders: orders,
            hasAssignedRoute: hasRoute,
            isRouteReceived: isReceived,
            assignedRouteCode: routeCode,
            assignedRouteZone: routeZone,
          );
        }
      }
      return const AssignedRouteResponse(orders: []);
    } catch (_) {
      return const AssignedRouteResponse(orders: []);
    }
  }

  /// Obtiene únicamente la lista de pedidos asignados al domiciliario desde la API.
  Future<List<OrderModel>> fetchAssignedOrders({
    required String courierId,
    String? token,
  }) async {
    try {
      final routeResponse = await fetchAssignedRoute(
        courierId: courierId,
        token: token,
      );
      return routeResponse.orders;
    } catch (_) {
      return [];
    }
  }

  /// Confirma la recepción física de la ruta asignada en `/api/mobile/orders/confirm-reception`.
  Future<bool> confirmRouteReception({
    required String courierId,
    String? routeCode,
    String? photoTimestamp,
    String? token,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.confirmReceptionEndpoint}',
    );
    try {
      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'courierId': int.tryParse(courierId) ?? courierId,
              if (routeCode != null) 'routeCode': routeCode,
              if (photoTimestamp != null) 'photoTimestamp': photoTimestamp,
            }),
          )
          .timeout(const Duration(seconds: 6));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Actualiza el estado operativo de un pedido o confirma su entrega y recaudo.
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

    try {
      if (newStatus == OrderStatus.entregado) {
        final url = Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.confirmDeliveryEndpoint}/$orderId/confirm-delivery',
        );
        final response = await _client
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                if (token != null) 'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'status': statusStr,
                ...?extraData,
              }),
            )
            .timeout(const Duration(seconds: 6));

        return response.statusCode == 200 || response.statusCode == 204;
      }

      final url = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.updateStatusEndpoint}/$orderId/status',
      );
      final response = await _client
          .put(
            url,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'status': statusStr,
              ...?extraData,
            }),
          )
          .timeout(const Duration(seconds: 6));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Registra una novedad o motivo de no entrega en `/api/mobile/orders/{id}/novelty`.
  Future<bool> reportNovelty({
    required String orderId,
    required String reason,
    String? token,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.noveltyEndpoint}/$orderId/novelty',
    );
    try {
      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'noveltyNotes': reason,
              'reason': reason,
              'newStatus': 'novedad',
            }),
          )
          .timeout(const Duration(seconds: 6));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Envía la ubicación GPS actual del domiciliario a `/api/mobile/couriers/{id}/location`.
  Future<bool> updateLocation({
    required int courierId,
    required double latitude,
    required double longitude,
    String? token,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.couriersEndpoint}/$courierId/location',
    );
    try {
      final response = await _client
          .put(
            url,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'latitude': latitude,
              'longitude': longitude,
            }),
          )
          .timeout(const Duration(seconds: 4));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Actualiza el estado de turno del domiciliario en `/api/mobile/couriers/{id}/shift-status`.
  Future<bool> updateShiftStatus({
    required int courierId,
    required String status,
    String? token,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.couriersEndpoint}/$courierId/shift-status',
    );
    try {
      final response = await _client
          .put(
            url,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'status': status,
            }),
          )
          .timeout(const Duration(seconds: 4));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }
}
