# Historial de Cambios — DespulpadoraApp (Flutter Mobile)

## [2026-10-25] — Sincronización Fast-Forward, Reglas Corporativas `AGENTS.md`, Cero Datos Quemados, Conexión a `/api/mobile/...` y Pruebas Unitarias al 100%

### 1. Control de Versiones y Gobernanza
- **Sincronización con `origin/Dev`**: Se verificó y sincronizó el árbol local en modo fast-forward (`git merge --ff-only origin/Dev`) sobre el commit `afdbea8`.
- **Actualización de `AGENTS.md`**: Se expandió el archivo de reglas globales con los lineamientos corporativos de arquitectura limpia BLoC/Cubit, flujo con agentes de verificación y auditoría, documentación superior `///` obligatoria, prohibición de comentarios internos `//`, manejo estricto `try-catch` sin retornos simulados, prohibición absoluta de datos quemados o mocks en producción, pruebas unitarias al 100% y registro en `HISTORIAL_CAMBIOS.md`.

### 2. Conexión Desacoplada a `/api/mobile/...` (`lib/config/api_config.dart`)
- Se actualizó `defaultBaseUrl` a `https://apidevdespulpadora.parking-flow.com/api/mobile` y `defaultWsUrl` a `wss://apidevdespulpadora.parking-flow.com/ws`.
- Se definieron las constantes de endpoints desacoplados:
  - `loginEndpoint = '/auth/login'`
  - `ordersEndpoint = '/orders'`
  - `assignedOrdersEndpoint = '/orders/assigned'`
  - `confirmReceptionEndpoint = '/orders/confirm-reception'`
  - `updateStatusEndpoint = '/orders'`
  - `confirmDeliveryEndpoint = '/orders'`
  - `noveltyEndpoint = '/orders'`
  - `couriersEndpoint = '/couriers'`

### 3. Eliminación Total de Mocks y Datos Quemados (`lib/services/api_service.dart`, `lib/models/...`, `lib/blocs/...`, `lib/views/...`)
- **`lib/services/api_service.dart`**:
  - Se eliminaron por completo `mockCourier` y `getMockOrders()`.
  - Se implementó `fetchAssignedRoute`, `fetchAssignedOrders`, `confirmRouteReception`, `updateOrderStatus` (incluyendo confirmación de entrega en `/orders/{id}/confirm-delivery` con `extraData`), `reportNovelty`, `updateLocation` y `updateShiftStatus` con soporte de inyección `http.Client` y retorno seguro (`false` o lista vacía en caso de fallo, sin simular éxito).
- **`lib/models/order_model.dart` y `lib/models/courier_model.dart`**:
  - Se agregó `databaseId` y el getter `apiOrderId` en `OrderModel` para utilizar siempre el ID numérico de base de datos en las llamadas REST mientras la UI exhibe el código de orden (`ORD-XXXX`).
  - Se agregó soporte en `OrderItem.fromJson` para `sizeKey` y en `_parseStatus` para estados en `snake_case` y `PascalCase` (`EnRuta`, `EnPunto`, `Asignado`, `Entregado`, `Novedad`).
  - Se eliminaron todos los valores quemados de respaldo (`'Cliente PulpasPro'`, `'Bogotá'`, `4.60971`, `-74.08175`, `'Efectivo Contraentrega'`, `'Pulpa'`, `'140g'`, `'XYZ-789'`, `'+57 312 456 7890'`).
- **Cubits y Vistas (`lib/blocs/...`, `lib/views/...`)**:
  - Se eliminaron las credenciales prellenadas en `LoginScreen` (`'MENSAJERO-01'`, `'pulpas2026'`) y se actualizaron los placeholders de configuración de servidor.
  - Se eliminaron los códigos de ruta quemados (`'RUT-2026-01'`, `'Chapinero • Zona Norte'`) en `OrdersState`, los nombres/placas ficticios (`'Carlos Mendoza'`, `'Mensajero PulpasPro'`, `'XYZ-123'`, `'XYZ-789'`) y los botones de simulación de ruta en `HomeOrdersScreen`, reemplazándolos por sincronización real con el backend.
  - Se conectó `TrackingCubit` con `ApiService.updateLocation` y `AuthCubit.toggleShiftStatus` con `ApiService.updateShiftStatus`.
  - Se añadieron comentarios de documentación `///` en todas las clases, enumeraciones y métodos, y se eliminaron el 100% de los comentarios internos `//` en `lib/` y `test/`.

### 4. Pruebas Unitarias y Análisis Estático (`test/widget_test.dart`)
- Se implementó la suite de pruebas unitarias con `MockClient` validando modelos, `ApiService`, `AuthCubit` y `OrdersCubit` (incluyendo bloqueo secuencial estricto y uso de `apiOrderId`).
- Resultado de `flutter analyze`: **0 errores**.
- Resultado de `flutter test`: **100% de pruebas aprobadas**.
