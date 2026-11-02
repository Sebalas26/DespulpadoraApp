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

  /// Último nombre del domiciliario autenticado para cruce de respaldo en rutas asignadas.
  String _lastAuthenticatedCourierName = '';

  /// Último userId del domiciliario autenticado para cruce de respaldo cuando difiere de courierId.
  String _lastAuthenticatedUserId = '';

  /// Crea una instancia de [ApiService] permitiendo inyectar un [http.Client] personalizado.
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Traduce y normaliza al español los mensajes de error provenientes del backend o de la red.
  static String localizeErrorMessage(String rawMessage, {int? statusCode}) {
    final cleaned = rawMessage.replaceAll('Exception: ', '').trim();
    final lower = cleaned.toLowerCase();

    if (lower.contains('invalid credentials or inactive account')) {
      return 'Credenciales incorrectas o cuenta inactiva. Verifica tu usuario y contraseña.';
    }
    if (lower.contains('invalid credentials') ||
        lower.contains('invalid username or password') ||
        lower.contains('wrong password') ||
        lower.contains('bad credentials') ||
        lower.contains('incorrect password')) {
      return 'Usuario o contraseña incorrectos. Verifica tus datos e intenta nuevamente.';
    }
    if (lower.contains('inactive account') ||
        lower.contains('account is inactive') ||
        lower.contains('user is inactive') ||
        lower.contains('account disabled')) {
      return 'Tu cuenta de domiciliario se encuentra inactiva. Contacta al administrador.';
    }
    if (lower.contains('user not found') ||
        lower.contains('courier not found') ||
        lower.contains('account not found')) {
      return 'No se encontró una cuenta asociada a este usuario.';
    }
    if (lower == 'unauthorized' ||
        lower == 'forbidden' ||
        lower.contains('access denied') ||
        lower.contains('not authorized')) {
      return 'No tienes autorización para acceder con estas credenciales.';
    }
    if (lower.contains('timeoutexception') ||
        lower.contains('timed out') ||
        lower.contains('future not completed')) {
      return 'El servidor tardó demasiado en responder. Verifica tu conexión a internet.';
    }
    if (lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable')) {
      return 'No se pudo conectar con el servidor. Revisa tu conexión a internet.';
    }
    if (lower.contains('internal server error') ||
        lower.contains('server error') ||
        (statusCode != null && statusCode >= 500)) {
      return 'El servidor presenta un inconveniente temporal. Intenta de nuevo en unos momentos.';
    }
    if (cleaned.isEmpty) {
      return 'Credenciales incorrectas o acceso no autorizado.';
    }
    return cleaned;
  }

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
        final resolvedName = (userData['fullName'] ??
                userData['nombre'] ??
                userData['courierName'] ??
                userData['username'] ??
                '')
            .toString();
        _lastAuthenticatedCourierName = resolvedName.trim();
        _lastAuthenticatedUserId =
            (userData['userId'] ?? userData['id'] ?? '').toString().trim();

        return CourierModel(
          id: rawId != null ? rawId.toString() : '',
          nombre: resolvedName,
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
        String errorMessage = 'Credenciales incorrectas o acceso no autorizado';
        if (response.body.isNotEmpty) {
          try {
            final Map<String, dynamic> errorData =
                jsonDecode(response.body) as Map<String, dynamic>;
            errorMessage =
                (errorData['message'] ?? errorData['error'] ?? errorMessage)
                    .toString();
          } catch (_) {}
        }
        throw Exception(
          localizeErrorMessage(errorMessage, statusCode: response.statusCode),
        );
      }
    } catch (e) {
      throw Exception(localizeErrorMessage(e.toString()));
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
          if (orders.isNotEmpty) {
            final anyStarted =
                orders.any((o) => o.estado != OrderStatus.asignado);
            return AssignedRouteResponse(
              orders: orders,
              hasAssignedRoute: orders.isNotEmpty,
              isRouteReceived: anyStarted,
            );
          }
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

          if (orders.isNotEmpty || hasRoute) {
            return AssignedRouteResponse(
              orders: orders,
              hasAssignedRoute: hasRoute,
              isRouteReceived: isReceived,
              assignedRouteCode: routeCode,
              assignedRouteZone: routeZone,
            );
          }
        }
      }
      return await _fetchFallbackAssignedOrdersFromOrdersEndpoint(
        courierId: courierId,
        token: token,
      );
    } catch (_) {
      return await _fetchFallbackAssignedOrdersFromOrdersEndpoint(
        courierId: courierId,
        token: token,
      );
    }
  }

  /// Consulta `/api/orders` como respaldo cuando el pedido fue despachado con `userId` o `courierName`.
  Future<AssignedRouteResponse> _fetchFallbackAssignedOrdersFromOrdersEndpoint({
    required String courierId,
    String? token,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/orders');
      final response = await _client
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200 || response.body.isEmpty) {
        return const AssignedRouteResponse(orders: []);
      }

      final dynamic decoded = jsonDecode(response.body);
      final List<dynamic> rawList = decoded is List
          ? decoded
          : (decoded is Map<String, dynamic>
              ? ((decoded['data'] ?? decoded['orders'] ?? []) as List<dynamic>)
              : <dynamic>[]);

      final String targetId = courierId.trim();
      final String targetUserId = _lastAuthenticatedUserId.trim();
      final String targetName = _lastAuthenticatedCourierName.trim().toLowerCase();

      final List<OrderModel> matchedOrders = <OrderModel>[];
      String detectedRouteCode = '';

      for (final dynamic item in rawList) {
        if (item is! Map<String, dynamic>) continue;
        final String statusRaw =
            (item['status'] ?? item['estado'] ?? '').toString().toUpperCase();
        if (statusRaw == 'CANCELLED' ||
            statusRaw == 'CANCELADO' ||
            statusRaw == 'PENDING' ||
            statusRaw == 'PENDIENTE' ||
            statusRaw == 'PICKING') {
          continue;
        }

        final String itemCourierId =
            (item['courierId'] ?? '').toString().trim();
        final String itemCourierName =
            (item['courierName'] ?? '').toString().trim().toLowerCase();

        final bool matchesById =
            targetId.isNotEmpty && itemCourierId == targetId;
        final bool matchesByUserId =
            targetUserId.isNotEmpty && itemCourierId == targetUserId;
        final bool matchesByName =
            targetName.isNotEmpty && itemCourierName == targetName;

        if (matchesById || matchesByUserId || matchesByName) {
          matchedOrders.add(OrderModel.fromJson(item));
          if (detectedRouteCode.isEmpty && item['routeCode'] != null) {
            detectedRouteCode = item['routeCode'].toString();
          }
        }
      }

      final bool anyStarted =
          matchedOrders.any((o) => o.estado != OrderStatus.asignado);
      return AssignedRouteResponse(
        orders: matchedOrders,
        hasAssignedRoute: matchedOrders.isNotEmpty,
        isRouteReceived: anyStarted,
        assignedRouteCode: detectedRouteCode,
      );
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
              'routeCode': ?routeCode,
              'photoTimestamp': ?photoTimestamp,
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

  /// Obtiene los métodos de pago activos configurados en el sistema desde `/api/payment-methods`.
  Future<List<Map<String, dynamic>>> fetchActivePaymentMethods({
    String? token,
  }) async {
    final baseRoot = ApiConfig.baseUrl.replaceAll(RegExp(r'/api/mobile/?$'), '');
    final url = Uri.parse('$baseRoot/api/payment-methods');
    try {
      final response = await _client
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .where((m) => (m['isActive'] ?? true) == true)
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Envía un mensaje automático de WhatsApp a través del Gateway auto-alojado vinculado por QR.
  Future<bool> sendWhatsAppNotification({
    required String phone,
    required String message,
  }) async {
    final trimmedPhone = phone.trim();
    final trimmedMessage = message.trim();
    if (trimmedPhone.isEmpty || trimmedMessage.isEmpty) {
      return false;
    }

    for (final baseGatewayUrl in ApiConfig.whatsappGatewayFallbackUrls) {
      try {
        final url = Uri.parse('$baseGatewayUrl/send');
        final response = await _client
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'phone': trimmedPhone,
                'message': trimmedMessage,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }
}
