import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';

enum OrdersFilter { todos, pendientes, entregados }

enum OrdersLoadingStatus { initial, loading, success, error }

class OrdersState {
  final OrdersLoadingStatus status;
  final List<OrderModel> orders;
  final OrdersFilter filter;
  final String? activeOrderId;
  final bool isRouteActive;
  final bool hasAssignedRoute;
  final String assignedRouteCode;
  final String assignedRouteZone;
  final String? errorMessage;

  const OrdersState({
    this.status = OrdersLoadingStatus.initial,
    this.orders = const [],
    this.filter = OrdersFilter.todos,
    this.activeOrderId,
    this.isRouteActive = false,
    this.hasAssignedRoute = false,
    this.assignedRouteCode = 'RUT-2026-01',
    this.assignedRouteZone = 'Chapinero • Zona Norte',
    this.errorMessage,
  });

  // Métricas para el Dashboard
  int get totalCount => orders.length;

  int get deliveredCount =>
      orders.where((o) => o.estado == OrderStatus.entregado).length;

  int get pendingCount => orders
      .where((o) =>
          o.estado == OrderStatus.asignado ||
          o.estado == OrderStatus.enCamino ||
          o.estado == OrderStatus.enPunto)
      .length;

  double get totalCashToCollect => orders
      .where((o) =>
          o.requiereCobro &&
          o.estado != OrderStatus.entregado &&
          o.estado != OrderStatus.novedad)
      .fold(0.0, (sum, o) => sum + o.montoTotal);

  double get totalCashCollected => orders
      .where((o) => o.estado == OrderStatus.entregado)
      .fold(0.0, (sum, o) => sum + o.montoTotal);

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

  /// Retorna el índice 1-based de la parada dentro del enrutado total
  int getStopSequenceNumber(String orderId) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    return idx >= 0 ? idx + 1 : 1;
  }

  /// Primera parada pendiente en estricto orden secuencial (#1 -> #2 -> #3 -> #4).
  /// No se permite entregar ni avanzar la 2da, 3ra o 4ta parada sin haber confirmado
  /// (Entregado o Novedad) la que está actualmente en turno.
  OrderModel? get currentTurnOrder {
    for (final order in orders) {
      if (order.estado != OrderStatus.entregado &&
          order.estado != OrderStatus.novedad) {
        return order;
      }
    }
    return null;
  }

  /// Indica si una parada específica está habilitada para gestionarse/entregarse
  bool isOrderUnlocked(String orderId) {
    final turn = currentTurnOrder;
    if (turn == null) return false;
    return turn.id == orderId;
  }

  OrderModel? get activeOrder {
    if (activeOrderId != null) {
      try {
        return orders.firstWhere((o) => o.id == activeOrderId);
      } catch (_) {}
    }
    return currentTurnOrder ?? (orders.isNotEmpty ? orders.last : null);
  }

  OrdersState copyWith({
    OrdersLoadingStatus? status,
    List<OrderModel>? orders,
    OrdersFilter? filter,
    String? activeOrderId,
    bool? isRouteActive,
    bool? hasAssignedRoute,
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
      assignedRouteCode: assignedRouteCode ?? this.assignedRouteCode,
      assignedRouteZone: assignedRouteZone ?? this.assignedRouteZone,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Cubit para gestionar el ciclo de vida secuencial de los pedidos asignados
class OrdersCubit extends Cubit<OrdersState> {
  final ApiService _apiService;

  OrdersCubit({ApiService? apiService})
      : _apiService = apiService ?? ApiService(),
        super(const OrdersState());

  /// Carga los pedidos asignados
  Future<void> loadOrders({required String courierId, String? token}) async {
    emit(state.copyWith(status: OrdersLoadingStatus.loading));
    try {
      final orders = await _apiService.fetchAssignedOrders(
        courierId: courierId,
        token: token,
      );

      // La parada activa por defecto es siempre la primera pendiente en orden secuencial
      String? turnId;
      bool routeAlreadyActive = state.isRouteActive;
      for (final o in orders) {
        if (o.estado != OrderStatus.entregado &&
            o.estado != OrderStatus.novedad) {
          turnId = o.id;
          if (o.estado == OrderStatus.enCamino ||
              o.estado == OrderStatus.enPunto) {
            routeAlreadyActive = true;
          }
          break;
        }
      }

      emit(state.copyWith(
        status: OrdersLoadingStatus.success,
        orders: orders,
        activeOrderId: turnId ?? (orders.isNotEmpty ? orders.first.id : null),
        isRouteActive: routeAlreadyActive,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: OrdersLoadingStatus.error,
        errorMessage: 'No se pudieron cargar los pedidos: $e',
      ));
    }
  }

  /// Cambia el filtro de la lista
  void setFilter(OrdersFilter filter) {
    emit(state.copyWith(filter: filter));
  }

  /// Activa o desactiva la asignación de ruta enviada desde la PWA
  void setRouteAssignment(
    bool assigned, {
    String? routeCode,
    String? routeZone,
  }) {
    emit(state.copyWith(
      hasAssignedRoute: assigned,
      assignedRouteCode: routeCode ?? state.assignedRouteCode,
      assignedRouteZone: routeZone ?? state.assignedRouteZone,
    ));
  }

  /// Selecciona una parada en el mapa para visualizar su información
  void selectStop(String orderId) {
    emit(state.copyWith(activeOrderId: orderId));
  }

  /// Enfoca directamente la parada en turno actual
  void focusCurrentTurnStop() {
    final turn = state.currentTurnOrder;
    if (turn != null) {
      emit(state.copyWith(activeOrderId: turn.id));
    }
  }

  /// Inicia el enrutado en vivo del domiciliario (activa estrictamente la parada en turno)
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

  /// 1. Iniciar Ruta / En Camino (solo permitido para la parada en turno)
  Future<bool> startRoute(String orderId, {String? token}) async {
    if (!state.isOrderUnlocked(orderId)) return false;
    return _updateStatusTransition(orderId, OrderStatus.enCamino, token: token);
  }

  /// 2. Llegué al Punto (solo permitido para la parada en turno)
  Future<bool> arrivedAtPoint(String orderId, {String? token}) async {
    if (!state.isOrderUnlocked(orderId)) return false;
    return _updateStatusTransition(orderId, OrderStatus.enPunto, token: token);
  }

  /// 3. Confirmar Entrega y Cobro (solo permitido para la parada en turno)
  Future<bool> confirmDelivery(
    String orderId, {
    String? token,
    double? cashReceived,
    String? paymentMethod,
    String? notes,
    String? receiverName,
  }) async {
    if (!state.isOrderUnlocked(orderId)) return false;
    final success = await _updateStatusTransition(
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
    return success;
  }

  /// 4. Reportar Novedad / No Entregado (solo permitido para la parada en turno)
  Future<bool> reportNovelty(
    String orderId,
    String reason, {
    String? token,
  }) async {
    if (!state.isOrderUnlocked(orderId)) return false;
    try {
      await _apiService.reportNovelty(
        orderId: orderId,
        reason: reason,
        token: token,
      );

      final updatedOrders = state.orders.map((o) {
        if (o.id == orderId) {
          return o.copyWith(
            estado: OrderStatus.novedad,
            observacionesNovedad: reason,
          );
        }
        return o;
      }).toList();

      final nextActiveId = _findNextSequentialOrderId(updatedOrders);

      emit(state.copyWith(
        orders: updatedOrders,
        activeOrderId: nextActiveId,
      ));
      return true;
    } catch (e) {
      return false;
    }
  }

  String? _findNextSequentialOrderId(List<OrderModel> ordersList) {
    for (final o in ordersList) {
      if (o.estado != OrderStatus.entregado &&
          o.estado != OrderStatus.novedad) {
        return o.id;
      }
    }
    return ordersList.isNotEmpty ? ordersList.last.id : null;
  }

  Future<bool> _updateStatusTransition(
    String orderId,
    OrderStatus newStatus, {
    String? token,
    String? paymentMethod,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      await _apiService.updateOrderStatus(
        orderId: orderId,
        newStatus: newStatus,
        token: token,
        extraData: extraData,
      );

      List<OrderModel> updatedOrders = state.orders.map((o) {
        if (o.id == orderId) {
          return o.copyWith(
            estado: newStatus,
            metodoPago: paymentMethod ?? o.metodoPago,
          );
        }
        return o;
      }).toList();

      String? activeId = orderId;
      bool routeActive = state.isRouteActive;

      if (newStatus == OrderStatus.enCamino ||
          newStatus == OrderStatus.enPunto) {
        activeId = orderId;
        routeActive = true;
      } else if (newStatus == OrderStatus.entregado ||
          newStatus == OrderStatus.novedad) {
        // Al finalizar la parada actual, avanzar automáticamente a la siguiente parada en orden
        activeId = _findNextSequentialOrderId(updatedOrders);
        if (activeId != null && routeActive) {
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
    } catch (e) {
      return false;
    }
  }
}
