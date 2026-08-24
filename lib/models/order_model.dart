import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';

/// Posibles estados de una orden de entrega
enum OrderStatus {
  asignado,   // Pedido asignado en bodega / pendiente de salida
  enCamino,   // Mensajero en ruta hacia la dirección del cliente
  enPunto,    // Mensajero llegó a la portería/puerta del cliente
  entregado,  // Pedido entregado y cobro confirmado
  novedad,    // Novedad reportada (no entregado, cliente no responde, etc.)
}

/// Item de producto dentro del pedido (Pulpas de Frutas)
class OrderItem {
  final String nombre;
  final String presentacion; // ej. "140g", "1000g / 1Kg", "Pack x10"
  final int cantidad;
  final double precioUnitario;

  OrderItem({
    required this.nombre,
    required this.presentacion,
    required this.cantidad,
    required this.precioUnitario,
  });

  double get subtotal => cantidad * precioUnitario;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      nombre: json['nombre'] ?? json['productName'] ?? '',
      presentacion: json['presentacion'] ?? json['presentation'] ?? '140g',
      cantidad: (json['cantidad'] ?? json['quantity'] ?? 1) as int,
      precioUnitario: (json['precioUnitario'] ?? json['unitPrice'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'presentacion': presentacion,
      'cantidad': cantidad,
      'precioUnitario': precioUnitario,
    };
  }
}

/// Modelo completo de la orden de despacho para el mensajero
class OrderModel {
  final String id;
  final String clienteNombre;
  final String clienteTelefono;
  final String direccion;
  final String barrio;
  final String ciudad;
  final double latitud;
  final double longitud;
  final double montoTotal;
  final String metodoPago; // ej. "Efectivo Contraentrega", "Transferencia", "Pagado"
  final bool requiereCobro;
  final OrderStatus estado;
  final List<OrderItem> items;
  final String? notasEntrega;
  final String? observacionesNovedad;
  final DateTime fecha;
  final int prioridad; // 1 = Urgente, 2 = Normal, 3 = Flexible

  OrderModel({
    required this.id,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.direccion,
    required this.barrio,
    this.ciudad = 'Bogotá',
    required this.latitud,
    required this.longitud,
    required this.montoTotal,
    required this.metodoPago,
    this.requiereCobro = true,
    this.estado = OrderStatus.asignado,
    required this.items,
    this.notasEntrega,
    this.observacionesNovedad,
    DateTime? fecha,
    this.prioridad = 2,
  }) : fecha = fecha ?? DateTime.now();

  static OrderStatus _parseStatus(String? statusStr) {
    switch (statusStr?.toLowerCase().trim()) {
      case 'en_camino':
      case 'en camino':
      case 'in_transit':
      case 'en_ruta':
        return OrderStatus.enCamino;
      case 'en_punto':
      case 'en punto':
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
      default:
        return OrderStatus.asignado;
    }
  }

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

  String get montoFormatted {
    final currencyFormatter = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );
    return '${currencyFormatter.format(montoTotal)} COP';
  }

  int get totalUnidades => items.fold(0, (sum, item) => sum + item.cantidad);

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>? ?? [])
        .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
        .toList();

    return OrderModel(
      id: json['id'] ?? json['orderId'] ?? '',
      clienteNombre: json['clienteNombre'] ?? json['customerName'] ?? 'Cliente PulpasPro',
      clienteTelefono: json['clienteTelefono'] ?? json['customerPhone'] ?? '',
      direccion: json['direccion'] ?? json['deliveryAddress'] ?? '',
      barrio: json['barrio'] ?? json['neighborhood'] ?? '',
      ciudad: json['ciudad'] ?? json['city'] ?? 'Bogotá',
      latitud: (json['latitud'] ?? json['latitude'] ?? 4.60971).toDouble(),
      longitud: (json['longitud'] ?? json['longitude'] ?? -74.08175).toDouble(),
      montoTotal: (json['montoTotal'] ?? json['totalAmount'] ?? 0).toDouble(),
      metodoPago: json['metodoPago'] ?? json['paymentMethod'] ?? 'Efectivo Contraentrega',
      requiereCobro: json['requiereCobro'] ?? json['requiresCollection'] ?? true,
      estado: _parseStatus(json['estado'] ?? json['status']),
      items: itemsList,
      notasEntrega: json['notasEntrega'] ?? json['notes'],
      observacionesNovedad: json['observacionesNovedad'] ?? json['noveltyReason'],
      fecha: json['fecha'] != null ? DateTime.tryParse(json['fecha']) : null,
      prioridad: json['prioridad'] ?? 2,
    );
  }

  Map<String, dynamic> toJson() {
    return {
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

  OrderModel copyWith({
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
