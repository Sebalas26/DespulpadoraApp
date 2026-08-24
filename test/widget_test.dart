import 'package:flutter_test/flutter_test.dart';
import 'package:despulpadora_app/models/courier_model.dart';
import 'package:despulpadora_app/models/location_data_model.dart';
import 'package:despulpadora_app/models/order_model.dart';
import 'package:despulpadora_app/blocs/orders_cubit.dart';

void main() {
  group('PulpasPro Models & WebSocket Telemetry Tests', () {
    test('CourierLocationPayload should generate exact WebSocket event format', () {
      final now = DateTime.utc(2026, 8, 23, 11, 30, 0);
      final payload = CourierLocationPayload(
        courierId: 'MENSAJERO-01',
        courierName: 'Carlos Mendoza',
        latitude: 4.67812,
        longitude: -74.05834,
        speed: 28.5,
        heading: 180.2,
        activeOrderId: 'PED-2026-089',
        batteryLevel: 85,
        timestamp: now,
      );

      final wsEvent = payload.toWebSocketEvent();

      expect(wsEvent['event'], equals('courier_location_update'));
      expect(wsEvent['data']['courierId'], equals('MENSAJERO-01'));
      expect(wsEvent['data']['courierName'], equals('Carlos Mendoza'));
      expect(wsEvent['data']['latitude'], equals(4.67812));
      expect(wsEvent['data']['longitude'], equals(-74.05834));
      expect(wsEvent['data']['speed'], equals(28.5));
      expect(wsEvent['data']['heading'], equals(180.2));
      expect(wsEvent['data']['activeOrderId'], equals('PED-2026-089'));
      expect(wsEvent['data']['batteryLevel'], equals(85));
      expect(wsEvent['data']['timestamp'], equals('2026-08-23T11:30:00.000Z'));
    });

    test('OrderModel calculations and items total', () {
      final order = OrderModel(
        id: 'PED-2026-089',
        clienteNombre: 'Restaurante El Oasis',
        clienteTelefono: '+57 315 889 4432',
        direccion: 'Calle 72 # 11-45',
        barrio: 'Chapinero',
        latitud: 4.65685,
        longitud: -74.05928,
        montoTotal: 148000,
        metodoPago: 'Efectivo Contraentrega',
        items: [
          OrderItem(nombre: 'Pulpa Maracuyá', presentacion: '1000g', cantidad: 10, precioUnitario: 8500),
          OrderItem(nombre: 'Pulpa Mango', presentacion: '1000g', cantidad: 5, precioUnitario: 7600),
        ],
      );

      expect(order.totalUnidades, equals(15));
      expect(order.estado, equals(OrderStatus.asignado));
      expect(order.montoFormatted, contains('148.000'));
    });

    test('CourierModel JSON serialization', () {
      final courier = CourierModel(
        id: 'MENSAJERO-01',
        nombre: 'Carlos Mendoza',
        placaVehiculo: 'XYZ-789',
        telefono: '+57 312 456 7890',
        email: 'carlos.mendoza@pulpaspro.com',
        isOnline: true,
      );

      final json = courier.toJson();
      expect(json['id'], equals('MENSAJERO-01'));
      expect(json['isOnline'], isTrue);

      final restored = CourierModel.fromJson(json);
      expect(restored.nombre, equals('Carlos Mendoza'));
      expect(restored.placaVehiculo, equals('XYZ-789'));
    });

    test('OrdersCubit filtering and state transitions', () async {
      final cubit = OrdersCubit();
      await cubit.loadOrders(courierId: 'MENSAJERO-01');

      expect(cubit.state.orders.isNotEmpty, isTrue);
      expect(cubit.state.totalCount, greaterThan(0));

      final firstOrder = cubit.state.orders.first;
      final startSuccess = await cubit.startRoute(firstOrder.id);
      expect(startSuccess, isTrue);
      expect(cubit.state.activeOrderId, equals(firstOrder.id));

      final arrivedSuccess = await cubit.arrivedAtPoint(firstOrder.id);
      expect(arrivedSuccess, isTrue);

      final deliveredSuccess = await cubit.confirmDelivery(
        firstOrder.id,
        cashReceived: firstOrder.montoTotal,
      );
      expect(deliveredSuccess, isTrue);
    });
  });
}
