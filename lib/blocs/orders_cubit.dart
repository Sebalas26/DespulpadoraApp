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
  final String? errorMessage;

  const OrdersState({
    this.status = OrdersLoadingStatus.initial,
    this.orders = const [],
    this.filter = OrdersFilter.todos,
    this.activeOrderId,
    this.errorMessage,
  });

  // Métricas para el Dashboard
  int get totalCount => orders.length;

  int get deliveredCount =>
      orders.where((o) => o.estado == OrderStatus.entregado).length;

  int get pendingCount => orders.where((o) =>
      o.estado == OrderStatus.asignado ||
      o.estado == OrderStatus.enCamino ||
      o.estado == OrderStatus.enPunto).length;

  double get totalCashToCollect => orders
      .where((o) => o.requiereCobro && o.estado != OrderStatus.entregado && o.estado != OrderStatus.novedad)
      .fold(0.0, (sum, o) => sum + o.montoTotal);

  double get totalCashCollected => orders
      .where((o) => o.requiereCobro && o.estado == OrderStatus.entregado)
      .fold(0.0, (sum, o) => sum + o.montoTotal);

  List<OrderModel> get filteredOrders {
    switch (filter) {
      case OrdersFilter.pendientes:
        return orders.where((o) =>
            o.estado == OrderStatus.asignado ||
            o.estado == OrderStatus.enCamino ||
            o.estado == OrderStatus.enPunto).toList();
      case OrdersFilter.entregados:
        return orders.where((o) => o.estado == OrderStatus.entregado).toList();
      case OrdersFilter.todos:
        return orders;
    }
  }

  OrderModel? get activeOrder {
    if (activeOrderId == null) {
      // Retorna el primer pedido en ruta o en punto si existe
      try {
        return orders.firstWhere(
          (o) => o.estado == OrderStatus.enCamino || o.estado == OrderStatus.enPunto,
        );
      } catch (_) {
        return null;
      }
    }
    try {
      return orders.firstWhere((o) => o.id == activeOrderId);
    } catch (_) {
      return null;
    }
  }

  OrdersState copyWith({
    OrdersLoadingStatus? status,
    List<OrderModel>? orders,
    OrdersFilter? filter,
    String? activeOrderId,
    String? errorMessage,
  }) {
    return OrdersState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      filter: filter ?? this.filter,
      activeOrderId: activeOrderId ?? this.activeOrderId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Cubit para gestionar el ciclo de vida de los pedidos asignados
class OrdersCubit extends Cubit<OrdersState> {
  final ApiService _apiService;

  OrdersCubit({ApiService? apiService})
      : _apiService = apiService ?? ApiService(),
        super(const OrdersState());

  /// Carga los pedidos asignados
  Future<void> loadOrders({required String courierId, String? token}) async {
    emit(state.copyWith(status: OrdersLoadingStatus.loading));
    try {
      final orders = await _apiService.fetchAssignedOrders(courierId: courierId, token: token);
      
      // Encontrar si ya hay un pedido activo
      String? activeId;
      try {
        final active = orders.firstWhere(
          (o) => o.estado == OrderStatus.enCamino || o.estado == OrderStatus.enPunto,
        );
        activeId = active.id;
      } catch (_) {}

      emit(state.copyWith(
        status: OrdersLoadingStatus.success,
        orders: orders,
        activeOrderId: activeId,
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

  /// 1. Iniciar Ruta / En Camino
  Future<bool> startRoute(String orderId, {String? token}) async {
    return _updateStatusTransition(orderId, OrderStatus.enCamino, token: token);
  }

  /// 2. Llegué al Punto
  Future<bool> arrivedAtPoint(String orderId, {String? token}) async {
    return _updateStatusTransition(orderId, OrderStatus.enPunto, token: token);
  }

  /// 3. Confirmar Entrega y Cobro
  Future<bool> confirmDelivery(
    String orderId, {
    String? token,
    double? cashReceived,
    String? notes,
    String? receiverName,
  }) async {
    final success = await _updateStatusTransition(
      orderId,
      OrderStatus.entregado,
      token: token,
      extraData: {
        'cashReceived': cashReceived,
        'deliveryNotes': notes,
        'receiverName': receiverName,
      },
    );
    return success;
  }

  /// 4. Reportar Novedad / No Entregado
  Future<bool> reportNovelty(String orderId, String reason, {String? token}) async {
    try {
      await _apiService.reportNovelty(orderId: orderId, reason: reason, token: token);
      
      final updatedOrders = state.orders.map((o) {
        if (o.id == orderId) {
          return o.copyWith(
            estado: OrderStatus.novedad,
            observacionesNovedad: reason,
          );
        }
        return o;
      }).toList();

      final nextActiveId = state.activeOrderId == orderId ? null : state.activeOrderId;
      emit(state.copyWith(orders: updatedOrders, activeOrderId: nextActiveId));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _updateStatusTransition(
    String orderId,
    OrderStatus newStatus, {
    String? token,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      await _apiService.updateOrderStatus(
        orderId: orderId,
        newStatus: newStatus,
        token: token,
        extraData: extraData,
      );

      final updatedOrders = state.orders.map((o) {
        if (o.id == orderId) {
          return o.copyWith(estado: newStatus);
        }
        return o;
      }).toList();

      String? activeId = state.activeOrderId;
      if (newStatus == OrderStatus.enCamino || newStatus == OrderStatus.enPunto) {
        activeId = orderId;
      } else if (newStatus == OrderStatus.entregado || newStatus == OrderStatus.novedad) {
        if (activeId == orderId) activeId = null;
      }

      emit(state.copyWith(orders: updatedOrders, activeOrderId: activeId));
      return true;
    } catch (e) {
      return false;
    }
  }
}
