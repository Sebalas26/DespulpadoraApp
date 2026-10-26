import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';

/// Estados posibles dentro del ciclo de vida de entrega de un pedido.
enum OrderStatus {
  /// Pedido asignado al domiciliario y pendiente de iniciar desplazamiento.
  asignado,

  /// Domiciliario en desplazamiento hacia la dirección del cliente.
  enCamino,

  /// Domiciliario ubicado en el punto de entrega del cliente.
  enPunto,

  /// Pedido entregado satisfactoriamente y recaudo confirmado.
  entregado,

  /// Incidencia o novedad reportada que impide la entrega.
  novedad,
}

/// Ítem de producto incluido dentro de una orden de entrega.
class OrderItem {
  /// Nombre de la fruta o producto.
  final String nombre;

  /// Presentación o gramaje del producto.
  final String presentacion;

  /// Cantidad de unidades solicitadas.
  final int cantidad;

  /// Precio unitario en pesos colombianos.
  final double precioUnitario;

  /// Crea una nueva instancia de [OrderItem].
  OrderItem({
    required this.nombre,
    required this.presentacion,
    required this.cantidad,
    required this.precioUnitario,
  });

  /// Calcula el subtotal monetario de la línea de producto.
  double get subtotal => cantidad * precioUnitario;

  /// Construye una instancia de [OrderItem] a partir de un mapa JSON del backend.
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      nombre:
          (json['fruitName'] ?? json['nombre'] ?? json['productName'] ?? '')
              .toString(),
      presentacion: (json['sizeLabel'] ??
              json['sizeKey'] ??
              json['presentacion'] ??
              json['presentation'] ??
              '')
          .toString(),
      cantidad: ((json['quantity'] ?? json['cantidad'] ?? 0) as num).toInt(),
      precioUnitario:
          ((json['unitPrice'] ?? json['precioUnitario'] ?? 0) as num)
              .toDouble(),
    );
  }

  /// Convierte el [OrderItem] a un mapa JSON serializable.
  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'presentacion': presentacion,
      'cantidad': cantidad,
      'precioUnitario': precioUnitario,
    };
  }
}

/// Modelo de dominio que representa una orden de despacho asignada al domiciliario.
class OrderModel {
  /// Identificador numérico en base de datos para invocaciones REST.
  final int? databaseId;

  /// Código visible del pedido (ej. `ORD-0001`).
  final String id;

  /// Nombre del cliente destinatario.
  final String clienteNombre;

  /// Teléfono de contacto del cliente destinatario.
  final String clienteTelefono;

  /// Dirección física de entrega.
  final String direccion;

  /// Barrio, localidad o zona de entrega.
  final String barrio;

  /// Ciudad de entrega.
  final String ciudad;

  /// Latitud geográfica del punto de entrega.
  final double latitud;

  /// Longitud geográfica del punto de entrega.
  final double longitud;

  /// Valor monetario total del pedido.
  final double montoTotal;

  /// Método de pago estipulado para la orden.
  final String metodoPago;

  /// Indica si el domiciliario debe realizar cobro al entregar.
  final bool requiereCobro;

  /// Estado operativo actual del pedido.
  final OrderStatus estado;

  /// Lista de productos que componen el pedido.
  final List<OrderItem> items;

  /// Notas o instrucciones de entrega proporcionadas.
  final String? notasEntrega;

  /// Descripción de la novedad reportada, en caso de existir.
  final String? observacionesNovedad;

  /// Fecha de registro o programación de la orden.
  final DateTime fecha;

  /// Nivel de prioridad de entrega.
  final int prioridad;

  /// Crea una nueva instancia de [OrderModel].
  OrderModel({
    this.databaseId,
    required this.id,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.direccion,
    required this.barrio,
    this.ciudad = '',
    required this.latitud,
    required this.longitud,
    required this.montoTotal,
    this.metodoPago = '',
    this.requiereCobro = true,
    this.estado = OrderStatus.asignado,
    required this.items,
    this.notasEntrega,
    this.observacionesNovedad,
    DateTime? fecha,
    this.prioridad = 2,
  }) : fecha = fecha ?? DateTime.now();

  /// Identificador prioritario para llamadas a endpoints REST (`/orders/$apiOrderId/...`).
  String get apiOrderId =>
      (databaseId != null && databaseId! > 0) ? databaseId.toString() : id;

  /// Convierte una cadena de estado (snake_case o PascalCase) en su valor [OrderStatus].
  static OrderStatus _parseStatus(String? statusStr) {
    switch (statusStr?.toLowerCase().trim()) {
      case 'en_camino':
      case 'en camino':
      case 'encamino':
      case 'in_transit':
      case 'en_ruta':
      case 'enruta':
      case 'en ruta':
        return OrderStatus.enCamino;
      case 'en_punto':
      case 'en punto':
      case 'enpunto':
      case 'arrived':
        return OrderStatus.enPunto;
      case 'entregado':
      case 'delivered':
        return OrderStatus.entregado;
      case 'novedad':
      case 'failed':
      case 'cancelled':
        return OrderStatus.novedad;
      case 'asignado':
      case 'assigned':
      case 'nuevo':
      case 'alistamiento':
      case 'empacado':
      default:
        return OrderStatus.asignado;
    }
  }

  /// Convierte un valor de [OrderStatus] a su representación de cadena snake_case.
  static String _statusToString(OrderStatus status) {
    switch (status) {
      case OrderStatus.asignado:
        return 'asignado';
      case OrderStatus.enCamino:
        return 'en_camino';
      case OrderStatus.enPunto:
        return 'en_punto';
      case OrderStatus.entregado:
        return 'entregado';
      case OrderStatus.novedad:
        return 'novedad';
    }
  }

  /// Etiqueta legible del estado actual para mostrar en la interfaz.
  String get estadoLabel {
    switch (estado) {
      case OrderStatus.asignado:
        return 'Asignado';
      case OrderStatus.enCamino:
        return 'En Camino';
      case OrderStatus.enPunto:
        return 'En el Punto';
      case OrderStatus.entregado:
        return 'Entregado';
      case OrderStatus.novedad:
        return 'Novedad';
    }
  }

  /// Color semántico asociado al estado actual del pedido.
  Color get estadoColor {
    switch (estado) {
      case OrderStatus.asignado:
        return AppColors.statusAsignado;
      case OrderStatus.enCamino:
        return AppColors.statusEnCamino;
      case OrderStatus.enPunto:
        return AppColors.statusEnPunto;
      case OrderStatus.entregado:
        return AppColors.statusEntregado;
      case OrderStatus.novedad:
        return AppColors.statusNovedad;
    }
  }

  /// Monto total formateado en moneda colombiana (COP).
  String get montoFormatted {
    final currencyFormatter = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );
    return '${currencyFormatter.format(montoTotal)} COP';
  }

  /// Suma total de unidades de producto en la orden.
  int get totalUnidades => items.fold(0, (sum, item) => sum + item.cantidad);

  /// Construye una instancia de [OrderModel] a partir de un mapa JSON del backend.
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>? ?? [])
        .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
        .toList();

    final dynamic rawDbId = json['databaseId'] ?? json['id'];
    final int? parsedDbId = rawDbId is int
        ? rawDbId
        : (rawDbId != null ? int.tryParse(rawDbId.toString()) : null);

    return OrderModel(
      databaseId: parsedDbId,
      id: (json['orderCode'] ?? json['id'] ?? json['orderId'] ?? '').toString(),
      clienteNombre:
          (json['clientName'] ?? json['clienteNombre'] ?? json['customerName'] ?? '')
              .toString(),
      clienteTelefono:
          (json['clientPhone'] ?? json['clienteTelefono'] ?? json['customerPhone'] ?? '')
              .toString(),
      direccion:
          (json['clientAddress'] ?? json['direccion'] ?? json['deliveryAddress'] ?? '')
              .toString(),
      barrio:
          (json['clientZone'] ?? json['barrio'] ?? json['neighborhood'] ?? '')
              .toString(),
      ciudad: (json['city'] ?? json['ciudad'] ?? '').toString(),
      latitud: ((json['latitude'] ?? json['latitud'] ?? 0.0) as num).toDouble(),
      longitud:
          ((json['longitude'] ?? json['longitud'] ?? 0.0) as num).toDouble(),
      montoTotal: ((json['total'] ??
                  json['montoTotal'] ??
                  json['totalAmount'] ??
                  0.0) as num)
              .toDouble(),
      metodoPago:
          (json['paymentMethod'] ?? json['metodoPago'] ?? '').toString(),
      requiereCobro: (json['requiresCashCollection'] ??
              json['requiereCobro'] ??
              json['requiresCollection'] ??
              true) ==
          true,
      estado: _parseStatus(
        (json['status'] ?? json['estado'])?.toString(),
      ),
      items: itemsList,
      notasEntrega: (json['notes'] ?? json['notasEntrega'])?.toString(),
      observacionesNovedad:
          (json['observacionesNovedad'] ?? json['noveltyReason'])?.toString(),
      fecha: json['orderDate'] != null
          ? DateTime.tryParse(json['orderDate'].toString())
          : (json['fecha'] != null
              ? DateTime.tryParse(json['fecha'].toString())
              : null),
      prioridad: ((json['prioridad'] ?? (json['isPriority'] == true ? 1 : 2)) as num)
          .toInt(),
    );
  }

  /// Convierte el [OrderModel] a un mapa JSON serializable.
  Map<String, dynamic> toJson() {
    return {
      if (databaseId != null) 'databaseId': databaseId,
      'id': id,
      'clienteNombre': clienteNombre,
      'clienteTelefono': clienteTelefono,
      'direccion': direccion,
      'barrio': barrio,
      'ciudad': ciudad,
      'latitud': latitud,
      'longitud': longitud,
      'montoTotal': montoTotal,
      'metodoPago': metodoPago,
      'requiereCobro': requiereCobro,
      'estado': _statusToString(estado),
      'items': items.map((i) => i.toJson()).toList(),
      'notasEntrega': notasEntrega,
      'observacionesNovedad': observacionesNovedad,
      'fecha': fecha.toIso8601String(),
      'prioridad': prioridad,
    };
  }

  /// Crea una copia de este [OrderModel] reemplazando los atributos especificados.
  OrderModel copyWith({
    int? databaseId,
    String? id,
    String? clienteNombre,
    String? clienteTelefono,
    String? direccion,
    String? barrio,
    String? ciudad,
    double? latitud,
    double? longitud,
    double? montoTotal,
    String? metodoPago,
    bool? requiereCobro,
    OrderStatus? estado,
    List<OrderItem>? items,
    String? notasEntrega,
    String? observacionesNovedad,
    DateTime? fecha,
    int? prioridad,
  }) {
    return OrderModel(
      databaseId: databaseId ?? this.databaseId,
      id: id ?? this.id,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteTelefono: clienteTelefono ?? this.clienteTelefono,
      direccion: direccion ?? this.direccion,
      barrio: barrio ?? this.barrio,
      ciudad: ciudad ?? this.ciudad,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      montoTotal: montoTotal ?? this.montoTotal,
      metodoPago: metodoPago ?? this.metodoPago,
      requiereCobro: requiereCobro ?? this.requiereCobro,
      estado: estado ?? this.estado,
      items: items ?? this.items,
      notasEntrega: notasEntrega ?? this.notasEntrega,
      observacionesNovedad: observacionesNovedad ?? this.observacionesNovedad,
      fecha: fecha ?? this.fecha,
      prioridad: prioridad ?? this.prioridad,
    );
  }
}
