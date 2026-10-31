import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/websocket_service.dart';

/// Categorías de filtrado de pedidos en la pantalla principal.
enum OrdersFilter {
  /// Muestra todos los pedidos asignados a la ruta.
  todos,

  /// Muestra únicamente los pedidos pendientes de entrega.
  pendientes,

  /// Muestra únicamente los pedidos ya entregados.
  entregados,
}

/// Estados de carga de las operaciones de pedidos.
enum OrdersLoadingStatus {
  /// Estado inicial sin carga previa.
  initial,

  /// Petición en curso hacia el servidor.
  loading,

  /// Datos sincronizados exitosamente.
  success,

  /// Error al consultar o actualizar pedidos.
  error,
}

/// Estado inmutable que contiene los pedidos, métricas y progreso de la ruta del domiciliario.
class OrdersState {
  /// Estado actual de carga de la información.
  final OrdersLoadingStatus status;

  /// Lista completa de pedidos asignados en orden secuencial.
  final List<OrderModel> orders;

  /// Filtro activo seleccionado por el usuario.
  final OrdersFilter filter;

  /// Identificador visible de la parada actualmente seleccionada o en curso.
  final String? activeOrderId;

  /// Indica si el recorrido activo en calle se encuentra en ejecución.
  final bool isRouteActive;

  /// Indica si el domiciliario tiene una ruta asignada desde el sistema central.
  final bool hasAssignedRoute;

  /// Indica si el domiciliario confirmó la recepción física del cargue.
  final bool isRouteReceived;

  /// Marca de tiempo de la fotografía de recepción de ruta.
  final String? receptionPhotoTime;

  /// Código identificador de la ruta asignada.
  final String assignedRouteCode;

  /// Zona o sector geográfico de la ruta asignada.
  final String assignedRouteZone;

  /// Mensaje de error en caso de fallo de comunicación.
  final String? errorMessage;

  /// Crea una nueva instancia de [OrdersState].
  const OrdersState({
    this.status = OrdersLoadingStatus.initial,
    this.orders = const [],
    this.filter = OrdersFilter.todos,
    this.activeOrderId,
    this.isRouteActive = false,
    this.hasAssignedRoute = false,
    this.isRouteReceived = false,
    this.receptionPhotoTime,
    this.assignedRouteCode = '',
    this.assignedRouteZone = '',
    this.errorMessage,
  });

  /// Número total de pedidos en la ruta actual.
  int get totalCount => orders.length;

  /// Suma total de unidades de producto en todos los pedidos de la ruta.
  int get totalUnitsInRoute =>
      orders.fold(0, (sum, o) => sum + o.totalUnidades);

  /// Valor monetario total de todos los pedidos de la ruta.
  double get totalRouteAmount =>
      orders.fold(0.0, (sum, o) => sum + o.montoTotal);

  /// Cantidad de pedidos que ya fueron entregados.
  int get deliveredCount =>
      orders.where((o) => o.estado == OrderStatus.entregado).length;

  /// Cantidad de pedidos pendientes por gestionar.
  int get pendingCount => orders
      .where((o) =>
          o.estado == OrderStatus.asignado ||
          o.estado == OrderStatus.enCamino ||
          o.estado == OrderStatus.enPunto)
      .length;

  /// Indica si el domiciliario tiene una ruta iniciada con paradas aún en proceso de entrega.
  bool get isDeliveringInRoute => isRouteActive && pendingCount > 0;

  /// Monto total pendiente por recaudar en efectivo.
  double get totalCashToCollect => orders
      .where((o) =>
          o.requiereCobro &&
          o.estado != OrderStatus.entregado &&
          o.estado != OrderStatus.novedad)
      .fold(0.0, (sum, o) => sum + o.montoTotal);

  /// Monto total ya recaudado en los pedidos entregados.
  double get totalCashCollected => orders
      .where((o) => o.estado == OrderStatus.entregado)
      .fold(0.0, (sum, o) => sum + o.montoTotal);

  /// Lista de pedidos filtrada según la pestaña activa en el panel principal.
  List<OrderModel> get filteredOrders {
    switch (filter) {
      case OrdersFilter.pendientes:
        return orders
            .where((o) =>
                o.estado == OrderStatus.asignado ||
                o.estado == OrderStatus.enCamino ||
                o.estado == OrderStatus.enPunto)
            .toList();
      case OrdersFilter.entregados:
        return orders.where((o) => o.estado == OrderStatus.entregado).toList();
      case OrdersFilter.todos:
        return orders;
    }
  }

  /// Retorna el número de secuencia 1-based de una parada dentro de la ruta.
  int getStopSequenceNumber(String orderId) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    return idx >= 0 ? idx + 1 : 1;
  }

  /// Retorna la primera parada pendiente en estricto orden secuencial.
  OrderModel? get currentTurnOrder {
    for (final order in orders) {
      if (order.estado != OrderStatus.entregado &&
          order.estado != OrderStatus.novedad) {
        return order;
      }
    }
    return null;
  }

  /// Indica si una parada específica se encuentra desbloqueada para gestión inmediata.
  bool isOrderUnlocked(String orderId) {
    final turn = currentTurnOrder;
    if (turn == null) return false;
    return turn.id == orderId || turn.apiOrderId == orderId;
  }

  /// Retorna el pedido actualmente enfocado en el mapa o el pedido en turno.
  OrderModel? get activeOrder {
    if (activeOrderId != null) {
      try {
        return orders.firstWhere((o) => o.id == activeOrderId);
      } catch (_) {}
    }
    return currentTurnOrder ?? (orders.isNotEmpty ? orders.last : null);
  }

  /// Crea una copia de [OrdersState] actualizando las propiedades especificadas.
  OrdersState copyWith({
    OrdersLoadingStatus? status,
    List<OrderModel>? orders,
    OrdersFilter? filter,
    String? activeOrderId,
    bool? isRouteActive,
    bool? hasAssignedRoute,
    bool? isRouteReceived,
    String? receptionPhotoTime,
    String? assignedRouteCode,
    String? assignedRouteZone,
    String? errorMessage,
  }) {
    return OrdersState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      filter: filter ?? this.filter,
      activeOrderId: activeOrderId ?? this.activeOrderId,
      isRouteActive: isRouteActive ?? this.isRouteActive,
      hasAssignedRoute: hasAssignedRoute ?? this.hasAssignedRoute,
      isRouteReceived: isRouteReceived ?? this.isRouteReceived,
      receptionPhotoTime: receptionPhotoTime ?? this.receptionPhotoTime,
      assignedRouteCode: assignedRouteCode ?? this.assignedRouteCode,
      assignedRouteZone: assignedRouteZone ?? this.assignedRouteZone,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Cubit encargado de gestionar el ciclo de vida secuencial de la ruta y entregas del domiciliario.
class OrdersCubit extends Cubit<OrdersState> {
  /// Servicio de comunicación HTTP con el backend.
  final ApiService _apiService;

  /// Servicio opcional de WebSocket para recibir actualizaciones en vivo de rutas y pedidos.
  final WebSocketService? _wsService;

  /// Suscripción al flujo de mensajes entrantes del WebSocket.
  StreamSubscription<Map<String, dynamic>>? _wsMessagesSubscription;

  /// Temporizador de sincronización silenciosa periódica en segundo plano.
  Timer? _liveSyncTimer;

  /// Temporizador de verificación diferida tras evento WebSocket.
  Timer? _followUpSyncTimer;

  /// Último identificador de domiciliario utilizado en la carga de ruta.
  String? _lastCourierId;

  /// Último token JWT utilizado en las peticiones autenticadas.
  String? _lastToken;

  /// Caché de coordenadas geocodificadas por identificador de pedido.
  final Map<String, LatLng> _resolvedOrderCoords = <String, LatLng>{};

  /// Crea una instancia de [OrdersCubit] con inyección opcional de [ApiService] y [WebSocketService].
  OrdersCubit({ApiService? apiService, WebSocketService? wsService})
      : _apiService = apiService ?? ApiService(),
        _wsService = wsService,
        super(const OrdersState()) {
    _wsMessagesSubscription =
        _wsService?.incomingMessagesStream.listen(_handleIncomingWsMessage);
  }

  /// Procesa los eventos WebSocket entrantes para refrescar la ruta y pedidos en vivo.
  void _handleIncomingWsMessage(Map<String, dynamic> message) {
    try {
      final String eventName =
          (message['event'] ?? message['type'] ?? '').toString().toLowerCase();
      if (eventName.isEmpty ||
          eventName == 'pong' ||
          eventName == 'ping' ||
          eventName == 'location_ack' ||
          eventName == 'courier_location_update') {
        return;
      }

      refreshOrdersLive();
      _followUpSyncTimer?.cancel();
      _followUpSyncTimer = Timer(const Duration(milliseconds: 750), () {
        refreshOrdersLive();
      });
    } catch (_) {
      return;
    }
  }

  /// Inicia la sincronización periódica silenciosa en segundo plano mientras exista sesión activa.
  void _ensureLiveSyncActive() {
    try {
      _wsService?.connect();
      if (_liveSyncTimer != null && _liveSyncTimer!.isActive) return;
      _liveSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        refreshOrdersLive();
      });
    } catch (_) {
      return;
    }
  }

  /// Consulta la ruta y los pedidos asignados al domiciliario desde `/api/mobile/orders/assigned`.
  Future<void> loadOrders({required String courierId, String? token}) async {
    try {
      _lastCourierId = courierId;
      _lastToken = token ?? _lastToken;
      _ensureLiveSyncActive();
      emit(state.copyWith(status: OrdersLoadingStatus.loading));
      await _fetchAndApplyOrders(courierId: courierId, isSilent: false);
    } catch (e) {
      emit(state.copyWith(
        status: OrdersLoadingStatus.error,
        errorMessage: 'No se pudieron cargar los pedidos: $e',
      ));
    }
  }

  /// Refresca silenciosamente en vivo la ruta y los pedidos asignados sin mostrar pantalla de carga.
  Future<void> refreshOrdersLive({String? courierId, String? token}) async {
    try {
      final String? effectiveCourierId = courierId ?? _lastCourierId;
      if (effectiveCourierId == null || effectiveCourierId.isEmpty) return;
      if (token != null) {
        _lastToken = token;
      }
      await _fetchAndApplyOrders(courierId: effectiveCourierId, isSilent: true);
    } catch (_) {
      return;
    }
  }

  /// Obtiene la ruta asignada del backend y actualiza el estado preservando el progreso en vivo.
  Future<void> _fetchAndApplyOrders({
    required String courierId,
    required bool isSilent,
  }) async {
    try {
      final AssignedRouteResponse routeResponse =
          await _apiService.fetchAssignedRoute(
        courierId: courierId,
        token: _lastToken,
      );
      final List<OrderModel> rawOrders = routeResponse.orders;
      final List<OrderModel> orders = rawOrders.map((OrderModel o) {
        if (LocationService.isWithinColombia(o.latitud, o.longitud)) {
          _resolvedOrderCoords[o.id] = LatLng(o.latitud, o.longitud);
          return o;
        }
        final LatLng fallback =
            _resolvedOrderCoords[o.id] ?? LocationService.defaultLocation;
        return o.copyWith(
          latitud: fallback.latitude,
          longitud: fallback.longitude,
        );
      }).toList();

      String? turnId;
      bool routeAlreadyActive = state.isRouteActive;
      bool anyProgress = false;
      for (final OrderModel o in orders) {
        if (o.estado != OrderStatus.asignado) {
          anyProgress = true;
        }
        if (turnId == null &&
            o.estado != OrderStatus.entregado &&
            o.estado != OrderStatus.novedad) {
          turnId = o.id;
          if (o.estado == OrderStatus.enCamino ||
              o.estado == OrderStatus.enPunto) {
            routeAlreadyActive = true;
          }
        }
      }

      final bool hasRoute = routeResponse.hasAssignedRoute || orders.isNotEmpty;
      final bool hasPendingOrders = orders.any(
        (OrderModel o) =>
            o.estado != OrderStatus.entregado &&
            o.estado != OrderStatus.novedad,
      );
      final bool isReceived = hasRoute &&
          (routeResponse.isRouteReceived ||
              state.isRouteReceived ||
              anyProgress);

      emit(state.copyWith(
        status: OrdersLoadingStatus.success,
        orders: orders,
        activeOrderId: turnId ?? (orders.isNotEmpty ? orders.first.id : null),
        isRouteActive:
            (hasRoute && hasPendingOrders) ? routeAlreadyActive : false,
        hasAssignedRoute: hasRoute,
        isRouteReceived: isReceived,
        assignedRouteCode: routeResponse.assignedRouteCode.isNotEmpty
            ? routeResponse.assignedRouteCode
            : state.assignedRouteCode,
        assignedRouteZone: routeResponse.assignedRouteZone.isNotEmpty
            ? routeResponse.assignedRouteZone
            : state.assignedRouteZone,
      ));

      unawaited(_geocodeMissingOrders(rawOrders));
    } catch (e) {
      if (!isSilent) {
        emit(state.copyWith(
          status: OrdersLoadingStatus.error,
          errorMessage: 'No se pudieron cargar los pedidos: $e',
        ));
      }
    }
  }

  /// Geocodifica en segundo plano las paradas cuyas coordenadas originales no estaban registradas en Colombia.
  Future<void> _geocodeMissingOrders(List<OrderModel> rawOrders) async {
    try {
      bool anyUpdated = false;
      for (final OrderModel raw in rawOrders) {
        if (LocationService.isWithinColombia(raw.latitud, raw.longitud)) {
          continue;
        }
        if (_resolvedOrderCoords.containsKey(raw.id)) {
          continue;
        }
        if (raw.direccion.trim().length < 4) {
          continue;
        }

        final LatLng? geocoded =
            await LocationService.geocodeColombiaAddress(raw.direccion);
        if (geocoded != null && !isClosed) {
          _resolvedOrderCoords[raw.id] = geocoded;
          anyUpdated = true;
        }
      }

      if (anyUpdated && !isClosed) {
        final List<OrderModel> updatedList =
            state.orders.map((OrderModel existing) {
          final LatLng? resolved = _resolvedOrderCoords[existing.id];
          if (resolved != null) {
            return existing.copyWith(
              latitud: resolved.latitude,
              longitud: resolved.longitude,
            );
          }
          return existing;
        }).toList();
        emit(state.copyWith(orders: updatedList));
      }
    } catch (_) {
      return;
    }
  }

  /// Actualiza el filtro de visualización de la lista de pedidos.
  void setFilter(OrdersFilter filter) {
    emit(state.copyWith(filter: filter));
  }

  /// Establece el estado de asignación de ruta recibido desde el servidor.
  void setRouteAssignment(
    bool assigned, {
    bool received = false,
    String? routeCode,
    String? routeZone,
  }) {
    emit(state.copyWith(
      hasAssignedRoute: assigned,
      isRouteReceived: assigned ? received : false,
      isRouteActive: assigned ? state.isRouteActive : false,
      assignedRouteCode: routeCode ?? state.assignedRouteCode,
      assignedRouteZone: routeZone ?? state.assignedRouteZone,
    ));
  }

  /// Confirma la recepción física del cargue en planta y notifica al backend.
  Future<bool> confirmRouteReception({
    required String photoTimestamp,
    String? courierId,
    String? token,
  }) async {
    try {
      final effectiveCourierId = courierId ?? _lastCourierId ?? '';
      final effectiveToken = token ?? _lastToken;
      if (effectiveCourierId.isNotEmpty) {
        await _apiService.confirmRouteReception(
          courierId: effectiveCourierId,
          routeCode: state.assignedRouteCode.isNotEmpty
              ? state.assignedRouteCode
              : null,
          photoTimestamp: photoTimestamp,
          token: effectiveToken,
        );
      }
      emit(state.copyWith(
        hasAssignedRoute: true,
        isRouteReceived: true,
        receptionPhotoTime: photoTimestamp,
      ));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Selecciona una parada específica para enfocarla en el mapa.
  void selectStop(String orderId) {
    emit(state.copyWith(activeOrderId: orderId));
  }

  /// Enfoca automáticamente la parada que se encuentra en turno actual.
  void focusCurrentTurnStop() {
    final turn = state.currentTurnOrder;
    if (turn != null) {
      emit(state.copyWith(activeOrderId: turn.id));
    }
  }

  /// Inicia el recorrido completo del domiciliario activando la primera parada en turno.
  Future<OrderModel?> startFullCourierRoute({String? token}) async {
    if (state.orders.isEmpty) return null;

    final targetStop = state.currentTurnOrder;
    if (targetStop == null) {
      return state.orders.last;
    }

    if (targetStop.estado == OrderStatus.asignado) {
      await startRoute(targetStop.id, token: token);
    }

    final updatedActive = state.orders.firstWhere(
      (o) => o.id == targetStop.id,
      orElse: () => targetStop,
    );

    emit(state.copyWith(
      isRouteActive: true,
      activeOrderId: updatedActive.id,
    ));

    return updatedActive;
  }

  /// Cambia el estado de la parada en turno a [OrderStatus.enCamino].
  Future<bool> startRoute(String orderId, {String? token}) async {
    if (!state.isOrderUnlocked(orderId)) return false;
    return _updateStatusTransition(orderId, OrderStatus.enCamino, token: token);
  }

  /// Cambia el estado de la parada en turno a [OrderStatus.enPunto].
  Future<bool> arrivedAtPoint(String orderId, {String? token}) async {
    if (!state.isOrderUnlocked(orderId)) return false;
    return _updateStatusTransition(orderId, OrderStatus.enPunto, token: token);
  }

  /// Confirma la entrega y recaudo de la parada en turno ante el backend.
  Future<bool> confirmDelivery(
    String orderId, {
    String? token,
    double? cashReceived,
    String? paymentMethod,
    String? notes,
    String? receiverName,
  }) async {
    if (!state.isOrderUnlocked(orderId)) return false;
    return _updateStatusTransition(
      orderId,
      OrderStatus.entregado,
      token: token,
      paymentMethod: paymentMethod,
      extraData: {
        'cashReceived': cashReceived,
        'paymentMethod': paymentMethod,
        'deliveryNotes': notes,
        'receiverName': receiverName,
      },
    );
  }

  /// Reporta una novedad en la parada en turno y avanza a la siguiente parada secuencial.
  Future<bool> reportNovelty(
    String orderId,
    String reason, {
    String? token,
  }) async {
    if (!state.isOrderUnlocked(orderId)) return false;
    try {
      final targetOrder = _findOrderById(orderId);
      final apiId = targetOrder?.apiOrderId ?? orderId;

      final success = await _apiService.reportNovelty(
        orderId: apiId,
        reason: reason,
        token: token ?? _lastToken,
      );
      if (!success) return false;

      final updatedOrders = state.orders.map((o) {
        if (o.id == orderId || o.apiOrderId == orderId) {
          return o.copyWith(
            estado: OrderStatus.novedad,
            observacionesNovedad: reason,
          );
        }
        return o;
      }).toList();

      final nextActiveId = _findNextSequentialOrderId(updatedOrders);
      final bool hasRemainingPending = updatedOrders.any(
        (OrderModel o) =>
            o.estado != OrderStatus.entregado &&
            o.estado != OrderStatus.novedad,
      );

      emit(state.copyWith(
        orders: updatedOrders,
        activeOrderId: nextActiveId,
        isRouteActive: hasRemainingPending ? state.isRouteActive : false,
      ));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Busca un pedido en el estado actual por su código visible o su ID numérico de base de datos.
  OrderModel? _findOrderById(String orderId) {
    for (final o in state.orders) {
      if (o.id == orderId || o.apiOrderId == orderId) {
        return o;
      }
    }
    return null;
  }

  /// Obtiene el identificador de la siguiente parada pendiente en orden secuencial.
  String? _findNextSequentialOrderId(List<OrderModel> ordersList) {
    for (final o in ordersList) {
      if (o.estado != OrderStatus.entregado &&
          o.estado != OrderStatus.novedad) {
        return o.id;
      }
    }
    return ordersList.isNotEmpty ? ordersList.last.id : null;
  }

  /// Ejecuta la transición de estado de un pedido sincronizándola con la API REST.
  Future<bool> _updateStatusTransition(
    String orderId,
    OrderStatus newStatus, {
    String? token,
    String? paymentMethod,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final targetOrder = _findOrderById(orderId);
      final apiId = targetOrder?.apiOrderId ?? orderId;

      final success = await _apiService.updateOrderStatus(
        orderId: apiId,
        newStatus: newStatus,
        token: token ?? _lastToken,
        extraData: extraData,
      );
      if (!success) return false;

      List<OrderModel> updatedOrders = state.orders.map((o) {
        if (o.id == orderId || o.apiOrderId == orderId) {
          return o.copyWith(
            estado: newStatus,
            metodoPago: paymentMethod ?? o.metodoPago,
          );
        }
        return o;
      }).toList();

      String? activeId = targetOrder?.id ?? orderId;
      bool routeActive = state.isRouteActive;

      if (newStatus == OrderStatus.enCamino ||
          newStatus == OrderStatus.enPunto) {
        activeId = targetOrder?.id ?? orderId;
        routeActive = true;
      } else if (newStatus == OrderStatus.entregado ||
          newStatus == OrderStatus.novedad) {
        activeId = _findNextSequentialOrderId(updatedOrders);
        final bool hasRemainingPending = updatedOrders.any(
          (OrderModel o) =>
              o.estado != OrderStatus.entregado &&
              o.estado != OrderStatus.novedad,
        );
        if (!hasRemainingPending) {
          routeActive = false;
        } else if (activeId != null && routeActive) {
          updatedOrders = updatedOrders.map((o) {
            if (o.id == activeId && o.estado == OrderStatus.asignado) {
              return o.copyWith(estado: OrderStatus.enCamino);
            }
            return o;
          }).toList();
        }
      }

      emit(state.copyWith(
        orders: updatedOrders,
        activeOrderId: activeId,
        isRouteActive: routeActive,
      ));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Libera las suscripciones y temporizadores de sincronización en vivo al cerrar el Cubit.
  @override
  Future<void> close() {
    try {
      _wsMessagesSubscription?.cancel();
      _liveSyncTimer?.cancel();
      _followUpSyncTimer?.cancel();
    } catch (_) {}
    return super.close();
  }
}
