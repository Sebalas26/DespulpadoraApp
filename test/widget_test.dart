import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:despulpadora_app/blocs/auth_cubit.dart';
import 'package:despulpadora_app/blocs/orders_cubit.dart';
import 'package:despulpadora_app/config/api_config.dart';
import 'package:despulpadora_app/models/courier_model.dart';
import 'package:despulpadora_app/models/location_data_model.dart';
import 'package:despulpadora_app/models/order_model.dart';
import 'package:despulpadora_app/services/api_service.dart';

/// Suite integral de pruebas unitarias para modelos, servicios REST (`/api/mobile`) y Cubits.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiConfig.resetDefaults();
  });

  group('Modelos de Dominio y Telemetría WebSocket', () {
    test(
      'CourierLocationPayload serializa y deserializa el evento WebSocket correctamente',
      () {
        final now = DateTime.utc(2026, 8, 23, 11, 30, 0);
        final payload = CourierLocationPayload(
          courierId: '10',
          courierName: 'Domiciliario Ruta Norte',
          latitude: 4.67812,
          longitude: -74.05834,
          speed: 28.5,
          heading: 180.2,
          activeOrderId: 'ORD-0001',
          batteryLevel: 85,
          timestamp: now,
        );

        final wsEvent = payload.toWebSocketEvent();

        expect(wsEvent['event'], equals('courier_location_update'));
        expect(wsEvent['data']['courierId'], equals('10'));
        expect(wsEvent['data']['courierName'], equals('Domiciliario Ruta Norte'));
        expect(wsEvent['data']['latitude'], equals(4.67812));
        expect(wsEvent['data']['longitude'], equals(-74.05834));
        expect(wsEvent['data']['speed'], equals(28.5));
        expect(wsEvent['data']['heading'], equals(180.2));
        expect(wsEvent['data']['activeOrderId'], equals('ORD-0001'));
        expect(wsEvent['data']['batteryLevel'], equals(85));
        expect(wsEvent['data']['timestamp'], equals('2026-08-23T11:30:00.000Z'));

        final restored = CourierLocationPayload.fromJson(wsEvent);
        expect(restored.courierId, equals('10'));
        expect(restored.activeOrderId, equals('ORD-0001'));
      },
    );

    test(
      'OrderModel calcula totales, soporta sizeKey, apiOrderId y estados PascalCase/snake_case sin fallbacks quemados',
      () {
        final orderFromJson = OrderModel.fromJson({
          'id': 45,
          'orderCode': 'ORD-0045',
          'clientName': 'Comercializadora Frutal',
          'clientPhone': '3001112233',
          'clientAddress': 'Carrera 15 # 85-10',
          'clientZone': 'Zona Norte',
          'city': 'Bogotá',
          'latitude': 4.668,
          'longitude': -74.055,
          'total': 95000,
          'paymentMethod': 'Efectivo',
          'requiresCashCollection': true,
          'status': 'EnRuta',
          'items': [
            {
              'fruitName': 'Mora',
              'sizeKey': '1000g',
              'quantity': 5,
              'unitPrice': 10000,
            },
            {
              'fruitName': 'Lulo',
              'sizeLabel': '500g',
              'quantity': 9,
              'unitPrice': 5000,
            },
          ],
        });

        expect(orderFromJson.id, equals('ORD-0045'));
        expect(orderFromJson.databaseId, equals(45));
        expect(orderFromJson.apiOrderId, equals('45'));
        expect(orderFromJson.estado, equals(OrderStatus.enCamino));
        expect(orderFromJson.totalUnidades, equals(14));
        expect(orderFromJson.items.first.presentacion, equals('1000g'));
        expect(orderFromJson.items.first.subtotal, equals(50000));
        expect(orderFromJson.montoFormatted, contains('95.000'));

        final enPuntoOrder = OrderModel.fromJson({'status': 'EnPunto'});
        expect(enPuntoOrder.estado, equals(OrderStatus.enPunto));
        expect(enPuntoOrder.clienteNombre, isEmpty);
        expect(enPuntoOrder.ciudad, isEmpty);
        expect(enPuntoOrder.latitud, equals(0.0));
        expect(enPuntoOrder.longitud, equals(0.0));
        expect(enPuntoOrder.metodoPago, isEmpty);

        final snakeDelivered = OrderModel.fromJson({'status': 'entregado'});
        expect(snakeDelivered.estado, equals(OrderStatus.entregado));

        final noveltyOrder = OrderModel.fromJson({'status': 'Novedad'});
        expect(noveltyOrder.estado, equals(OrderStatus.novedad));
      },
    );

    test(
      'CourierModel mapea campos del backend sin valores quemados',
      () {
        final courier = CourierModel.fromJson({
          'courierId': 7,
          'fullName': 'Andrés Gómez',
          'vehiclePlate': 'ABC-12D',
          'phone': '3105556677',
          'email': 'andres@dgl.com',
          'accessToken': 'jwt_real_token',
          'isOnline': true,
        });

        expect(courier.id, equals('7'));
        expect(courier.nombre, equals('Andrés Gómez'));
        expect(courier.placaVehiculo, equals('ABC-12D'));
        expect(courier.telefono, equals('3105556677'));
        expect(courier.token, equals('jwt_real_token'));
        expect(courier.isOnline, isTrue);

        final emptyCourier = CourierModel.fromJson({});
        expect(emptyCourier.id, isEmpty);
        expect(emptyCourier.placaVehiculo, isEmpty);
        expect(emptyCourier.telefono, isEmpty);
      },
    );
  });

  group('ApiService contra /api/mobile/... y Manejo de Errores Cero Mocks', () {
    test(
      'ApiConfig apunta por defecto al endpoint desacoplado /api/mobile',
      () {
        expect(
          ApiConfig.defaultBaseUrl,
          equals('https://apidevdespulpadora.parking-flow.com/api/mobile'),
        );
        expect(
          ApiConfig.defaultWsUrl,
          equals('wss://apidevdespulpadora.parking-flow.com/ws'),
        );
        expect(ApiConfig.loginEndpoint, equals('/auth/login'));
        expect(ApiConfig.assignedOrdersEndpoint, equals('/orders/assigned'));
        expect(
          ApiConfig.confirmReceptionEndpoint,
          equals('/orders/confirm-reception'),
        );
      },
    );

    test(
      'login exitoso retorna CourierModel real y en fallo propaga excepción sin datos simulados',
      () async {
        final successClient = MockClient((request) async {
          expect(request.url.path, endsWith('/api/mobile/auth/login'));
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['username'], equals('domi01'));
          expect(body['usernameOrEmail'], equals('domi01'));
          return http.Response(
            jsonEncode({
              'accessToken': 'token_123',
              'courier': {
                'courierId': 12,
                'fullName': 'Juan Pérez',
                'vehiclePlate': 'KLM-45F',
                'phone': '3201112233',
                'email': 'juan@dgl.com',
              },
            }),
            200,
          );
        });

        final apiSuccess = ApiService(client: successClient);
        final courier = await apiSuccess.login(
          usernameOrEmail: 'domi01',
          password: 'secret',
        );
        expect(courier.id, equals('12'));
        expect(courier.nombre, equals('Juan Pérez'));
        expect(courier.placaVehiculo, equals('KLM-45F'));
        expect(courier.token, equals('token_123'));

        final failClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Usuario no autorizado'}),
            401,
          );
        });

        final apiFail = ApiService(client: failClient);
        await expectLater(
          () => apiFail.login(usernameOrEmail: 'domi01', password: 'bad'),
          throwsA(isA<Exception>()),
        );
      },
    );

    test(
      'fetchAssignedRoute y fetchAssignedOrders consultan /orders/assigned y retornan vacío ante error',
      () async {
        final routeClient = MockClient((request) async {
          expect(request.url.path, endsWith('/api/mobile/orders/assigned'));
          expect(request.url.queryParameters['courierId'], equals('12'));
          return http.Response(
            jsonEncode({
              'hasAssignedRoute': true,
              'isRouteReceived': false,
              'assignedRouteCode': 'RUT-101',
              'assignedRouteZone': 'Sector Industrial',
              'orders': [
                {
                  'id': 99,
                  'orderCode': 'ORD-0099',
                  'clientName': 'Cliente Uno',
                  'clientAddress': 'Calle 10 # 20-30',
                  'total': 50000,
                  'status': 'Asignado',
                  'items': [],
                },
              ],
            }),
            200,
          );
        });

        final api = ApiService(client: routeClient);
        final routeResp = await api.fetchAssignedRoute(
          courierId: '12',
          token: 'jwt',
        );
        expect(routeResp.hasAssignedRoute, isTrue);
        expect(routeResp.isRouteReceived, isFalse);
        expect(routeResp.assignedRouteCode, equals('RUT-101'));
        expect(routeResp.assignedRouteZone, equals('Sector Industrial'));
        expect(routeResp.orders.length, equals(1));
        expect(routeResp.orders.first.apiOrderId, equals('99'));

        final errorClient = MockClient((_) async => http.Response('Error', 500));
        final apiError = ApiService(client: errorClient);
        final emptyOrders = await apiError.fetchAssignedOrders(courierId: '12');
        expect(emptyOrders, isEmpty);
      },
    );

    test(
      'confirmRouteReception, updateOrderStatus, reportNovelty, updateLocation y updateShiftStatus retornan false en error',
      () async {
        final okClient = MockClient((request) async {
          return http.Response(jsonEncode({'ok': true}), 200);
        });

        final apiOk = ApiService(client: okClient);
        expect(
          await apiOk.confirmRouteReception(
            courierId: '12',
            routeCode: 'RUT-101',
            photoTimestamp: '25/10/2026',
          ),
          isTrue,
        );
        expect(
          await apiOk.updateOrderStatus(
            orderId: '99',
            newStatus: OrderStatus.enCamino,
          ),
          isTrue,
        );
        expect(
          await apiOk.updateOrderStatus(
            orderId: '99',
            newStatus: OrderStatus.entregado,
            extraData: {
              'paymentMethod': 'Efectivo',
              'cashReceived': 50000.0,
            },
          ),
          isTrue,
        );
        expect(
          await apiOk.reportNovelty(orderId: '99', reason: 'Cerrado'),
          isTrue,
        );
        expect(
          await apiOk.updateLocation(
            courierId: 12,
            latitude: 4.65,
            longitude: -74.08,
          ),
          isTrue,
        );
        expect(
          await apiOk.updateShiftStatus(courierId: 12, status: 'disponible'),
          isTrue,
        );

        final failClient = MockClient((_) async => http.Response('Error', 500));
        final apiFail = ApiService(client: failClient);
        expect(
          await apiFail.confirmRouteReception(courierId: '12'),
          isFalse,
        );
        expect(
          await apiFail.updateOrderStatus(
            orderId: '99',
            newStatus: OrderStatus.enCamino,
          ),
          isFalse,
        );
        expect(
          await apiFail.reportNovelty(orderId: '99', reason: 'Cerrado'),
          isFalse,
        );
        expect(
          await apiFail.updateLocation(
            courierId: 12,
            latitude: 4.65,
            longitude: -74.08,
          ),
          isFalse,
        );
        expect(
          await apiFail.updateShiftStatus(courierId: 12, status: 'disponible'),
          isFalse,
        );
      },
    );
  });

  group('AuthCubit y OrdersCubit Flujo Completo', () {
    test(
      'AuthCubit gestiona login, toggleShiftStatus y logout',
      () async {
        bool shiftUpdated = false;
        final mockClient = MockClient((request) async {
          if (request.url.path.endsWith('/auth/login')) {
            return http.Response(
              jsonEncode({
                'accessToken': 'jwt_abc',
                'courier': {
                  'courierId': 5,
                  'fullName': 'Laura Méndez',
                  'vehiclePlate': 'TXY-99A',
                  'phone': '3150001122',
                  'email': 'laura@dgl.com',
                },
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/couriers/5/shift-status')) {
            shiftUpdated = true;
            return http.Response('{}', 200);
          }
          return http.Response('{}', 200);
        });

        final authCubit = AuthCubit(apiService: ApiService(client: mockClient));
        await authCubit.login(
          usernameOrEmail: 'laura@dgl.com',
          password: 'pass',
        );

        expect(authCubit.state, isA<AuthAuthenticated>());
        expect(authCubit.currentCourier?.id, equals('5'));
        expect(authCubit.currentCourier?.placaVehiculo, equals('TXY-99A'));

        await authCubit.toggleShiftStatus(false);
        expect(shiftUpdated, isTrue);
        expect(authCubit.currentCourier?.isOnline, isFalse);

        await authCubit.logout();
        expect(authCubit.state, isA<AuthUnauthenticated>());
        await authCubit.close();
      },
    );

    test(
      'OrdersCubit respeta bloqueo secuencial estricto, usa apiOrderId y aplica filtros',
      () async {
        final List<String> requestedPaths = [];
        final mockClient = MockClient((request) async {
          requestedPaths.add(request.url.path);
          if (request.url.path.endsWith('/orders/assigned')) {
            return http.Response(
              jsonEncode({
                'hasAssignedRoute': true,
                'isRouteReceived': true,
                'assignedRouteCode': 'RUT-500',
                'assignedRouteZone': 'Zona Industrial',
                'orders': [
                  {
                    'id': 101,
                    'orderCode': 'ORD-0101',
                    'clientName': 'Parada Uno',
                    'clientAddress': 'Dir 1',
                    'total': 40000,
                    'status': 'Asignado',
                    'items': [
                      {
                        'fruitName': 'Mango',
                        'sizeKey': '500g',
                        'quantity': 4,
                        'unitPrice': 10000,
                      },
                    ],
                  },
                  {
                    'id': 102,
                    'orderCode': 'ORD-0102',
                    'clientName': 'Parada Dos',
                    'clientAddress': 'Dir 2',
                    'total': 60000,
                    'status': 'Asignado',
                    'items': [],
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'ok': true}), 200);
        });

        final cubit = OrdersCubit(apiService: ApiService(client: mockClient));
        await cubit.loadOrders(courierId: '5', token: 'jwt_abc');

        expect(cubit.state.orders.length, equals(2));
        expect(cubit.state.hasAssignedRoute, isTrue);
        expect(cubit.state.isRouteReceived, isTrue);
        expect(cubit.state.assignedRouteCode, equals('RUT-500'));
        expect(cubit.state.isOrderUnlocked('ORD-0101'), isTrue);
        expect(cubit.state.isOrderUnlocked('ORD-0102'), isFalse);

        final blockedAttempt = await cubit.startRoute('ORD-0102');
        expect(blockedAttempt, isFalse);

        final startedOrder = await cubit.startFullCourierRoute();
        expect(startedOrder?.id, equals('ORD-0101'));
        expect(
          requestedPaths.any((p) => p.endsWith('/orders/101/status')),
          isTrue,
        );

        final arrivedOk = await cubit.arrivedAtPoint('ORD-0101');
        expect(arrivedOk, isTrue);

        final deliveredOk = await cubit.confirmDelivery(
          'ORD-0101',
          cashReceived: 40000,
          paymentMethod: 'Efectivo',
        );
        expect(deliveredOk, isTrue);
        expect(
          requestedPaths.any((p) => p.endsWith('/orders/101/confirm-delivery')),
          isTrue,
        );

        expect(cubit.state.isOrderUnlocked('ORD-0102'), isTrue);

        cubit.setFilter(OrdersFilter.entregados);
        expect(cubit.state.filteredOrders.length, equals(1));

        cubit.setFilter(OrdersFilter.pendientes);
        expect(cubit.state.filteredOrders.length, equals(1));

        final noveltyOk = await cubit.reportNovelty(
          'ORD-0102',
          'Cliente ausente',
        );
        expect(noveltyOk, isTrue);
        expect(
          requestedPaths.any((p) => p.endsWith('/orders/102/novelty')),
          isTrue,
        );
        expect(cubit.state.pendingCount, equals(0));
        await cubit.close();
      },
    );
  });
}
