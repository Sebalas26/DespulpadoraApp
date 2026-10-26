# Reglas Globales de Ingeniería y Gobernanza — DespulpadoraApp (Flutter Mobile)

> **MANDATO CRÍTICO:** Todo agente o asistente de IA que interactúe con este repositorio **DEBE** leer, acatar y verificar el cumplimiento del 100% de las directrices descritas en este documento antes, durante y después de cualquier intervención en el código.

---

## 1. Flujo de Trabajo con Agentes de Verificación y Auditoría

1. **Planificación Previa (`implementation_plan.md`)**:
   - Antes de modificar código productivo, se debe estructurar un plan de implementación detallando los archivos afectados, contratos de API REST (`/api/mobile/...`), cambios de estado en Cubits/BLoCs y estrategia de pruebas unitarias.
2. **Agentes de Verificación y Auditoría**:
   - Ninguna tarea se considera finalizada hasta que se ejecuten y aprueben sin errores las herramientas de análisis estático (`flutter analyze`) y la suite completa de pruebas (`flutter test`).
   - Se debe auditar explícitamente la ausencia de datos quemados (hardcoded), mocks en código productivo y comentarios internos (`//`).

---

## 2. Arquitectura Limpia BLoC / Cubit

- **Separación de Responsabilidades**:
  - `lib/config/`: Configuración centralizada de endpoints REST (`/api/mobile`), WebSockets (`/ws`), rutas de navegación y temas visuales.
  - `lib/models/`: Modelos de dominio inmutables con serialización `fromJson`, `toJson` y `copyWith`.
  - `lib/services/`: Servicios de infraestructura (`ApiService`, `LocationService`, `RoutingService`, `WebSocketService`) con soporte para inyección de dependencias (`http.Client`, etc.) que facilite pruebas unitarias aisladas.
  - `lib/blocs/`: Gestión de estado reactiva mediante `Cubit` (`AuthCubit`, `OrdersCubit`, `TrackingCubit`). Las vistas nunca deben realizar llamadas HTTP directas.
  - `lib/views/`: Pantallas y widgets desacoplados de la lógica de red, consumiendo estados mediante `BlocBuilder`, `BlocListener` y `BlocConsumer`.

---

## 3. Estándares de Documentación y Comentarios

- **Documentación Superior Obligatoria (`///`)**:
  - Toda clase, `enum`, método público/privado, propiedad relevante y constructor debe contar con comentarios de documentación Dart (`///`) en la parte superior explicando su propósito.
- **CERO Comentarios Internos (`//`)**:
  - Está **estrictamente prohibido** dejar comentarios de línea (`//`) dentro del cuerpo de métodos, constructores, clases o bloques `build`.
  - El código debe ser autoexplicativo; toda documentación debe residir exclusivamente en cabeceras `///`.

---

## 4. Manejo Estricto de Errores (`try-catch`) y Prohibición de Fallbacks Falsos

- **Bloques `try-catch` Obligatorios**:
  - Todo método asíncrono en servicios (`ApiService`, `LocationService`, `RoutingService`, `WebSocketService`) y Cubits (`AuthCubit`, `OrdersCubit`, `TrackingCubit`) debe estar protegido con bloques `try-catch`.
- **Prohibición de Retornos Falsos en Caso de Error**:
  - En caso de excepción o error HTTP, **NUNCA** se debe retornar `true` simulando éxito ni retornar listas o perfiles mockeados (`mockCourier`, `getMockOrders()`).
  - Los métodos booleanos de mutación deben retornar `false` ante fallos de red o códigos HTTP distintos de `200`/`204`, y los métodos de autenticación deben propagar una excepción clara para que el Cubit emita el estado de error correspondiente.

---

## 5. Prohibición Absoluta de Datos Quemados (Hardcoded Data) y Mocks

- **CERO Datos de Negocio Quemados**:
  - Prohibido incluir credenciales prellenadas en controladores de login (ej. `'MENSAJERO-01'`, `'pulpas2026'`).
  - Prohibido incluir objetos `mockCourier`, `getMockOrders()`, nombres ficticios (`'Carlos Mendoza'`, `'Cliente PulpasPro'`, `'Mensajero PulpasPro'`), placas falsas (`'XYZ-789'`, `'XYZ-123'`), teléfonos falsos (`'+57 312 456 7890'`), códigos de ruta quemados (`'RUT-2026-01'`, `'Chapinero • Zona Norte'`) o botones de simulación en la interfaz.
  - Toda información mostrada al domiciliario debe provenir del backend real (`https://apidevdespulpadora.parking-flow.com/api/mobile`) o de valores vacíos/neutros (`''`, `0.0`, `'Sin placa'`) cuando un campo opcional no esté presente.

---

## 6. Pruebas Unitarias Obligatorias al 100% (`flutter test`)

- **Cobertura y Ejecución**:
  - Todo cambio en modelos, servicios REST (`ApiService` mediante `MockClient`) y lógica de estado (`AuthCubit`, `OrdersCubit`) debe estar respaldado por pruebas unitarias en `test/widget_test.dart`.
  - Es requisito indispensable que `flutter analyze` reporte **0 errores** y `flutter test` apruebe el **100% de los tests** antes de entregar cualquier tarea.

---

## 7. Control de Versiones (Git) — REGLA ESTRICTA

- **PROHIBIDO hacer `git commit` automáticamente**: El asistente nunca debe crear commits por su cuenta.
- **PROHIBIDO hacer `git push` o `git reset`**: El asistente nunca debe enviar cambios al repositorio remoto ni alterar el historial de Git.
- **Excepción**: Únicamente cuando el usuario ordene de forma expresa y explícita: *"haz commit de esto"* o *"haz push a la rama X"*.
- **Flujo habitual**: Modificar los archivos localmente, validar con `flutter analyze` y `flutter test`, registrar en `HISTORIAL_CAMBIOS.md` e informar al usuario.

---

## 8. Registro Obligatorio en `HISTORIAL_CAMBIOS.md`

- Toda intervención técnica, refactorización, ajuste de endpoints o corrección de errores debe documentarse detalladamente en el archivo `HISTORIAL_CAMBIOS.md` en la raíz del proyecto, indicando fecha, alcance, archivos modificados y resultados de validación.
