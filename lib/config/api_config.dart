import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// Opción de estilo cartográfico sincronizada con el catálogo visual de la plataforma.
class MapStyleOption {
  /// Identificador único del estilo de mapa.
  final String id;

  /// Nombre descriptivo completo del estilo.
  final String name;

  /// Nombre corto para visualización compacta.
  final String shortName;

  /// Etiqueta distintiva del proveedor cartográfico.
  final String badge;

  /// Plantilla URL del servidor de teselas.
  final String url;

  /// Nivel máximo de zoom soportado por el estilo.
  final double maxZoom;

  /// Indica si el estilo corresponde a un tema oscuro.
  final bool isDark;

  /// Crea una nueva instancia de [MapStyleOption].
  const MapStyleOption({
    required this.id,
    required this.name,
    required this.shortName,
    required this.badge,
    required this.url,
    this.maxZoom = 20,
    this.isDark = false,
  });
}

/// Configuración central de endpoints REST (`/api/mobile`) y WebSockets para DespulpadoraApp.
class ApiConfig {
  /// URL base por defecto del módulo móvil desacoplado en el backend.
  static const String defaultBaseUrl =
      'https://apidevdespulpadora.parking-flow.com/api/mobile';

  /// URL por defecto del servidor WebSocket para telemetría en tiempo real.
  static const String defaultWsUrl =
      'wss://apidevdespulpadora.parking-flow.com/ws';

  /// Latitud de la planta matriz de despacho.
  static const double plantaMatrizLat = 4.7125;

  /// Longitud de la planta matriz de despacho.
  static const double plantaMatrizLng = -74.1420;

  /// Servidor de teselas ArcGIS World Topographic White Minimalist.
  static const String arcgisWhiteMinimalTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}';

  /// Servidor de teselas Esri World Light Gray Canvas.
  static const String esriGrayTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}';

  /// Servidor de teselas OpenStreetMap estándar.
  static const String osmStandardTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Servidor de teselas predeterminado de la aplicación.
  static const String osmTileUrl = arcgisWhiteMinimalTileUrl;

  /// Identificador de paquete para las peticiones de teselas cartográficas.
  static const String userAgentPackageName = 'com.pulpaspro.despulpadora_app';

  /// Catálogo de estilos de mapa disponibles en la aplicación.
  static const List<MapStyleOption> mapStyles = [
    MapStyleOption(
      id: 'arcgis-white',
      name: 'ArcGIS White Minimalist',
      shortName: 'ArcGIS White',
      badge: '100% GRATIS',
      url: arcgisWhiteMinimalTileUrl,
      maxZoom: 19,
      isDark: false,
    ),
    MapStyleOption(
      id: 'esri-gray',
      name: 'Esri World Gray Canvas',
      shortName: 'Esri Canvas',
      badge: 'ARCGIS',
      url: esriGrayTileUrl,
      maxZoom: 19,
      isDark: false,
    ),
    MapStyleOption(
      id: 'osm-standard',
      name: 'OpenStreetMap Clásico',
      shortName: 'Color Estándar',
      badge: 'ESTÁNDAR',
      url: osmStandardTileUrl,
      maxZoom: 19,
      isDark: false,
    ),
  ];

  /// Endpoint de inicio de sesión móvil.
  static const String loginEndpoint = '/auth/login';

  /// Endpoint base de pedidos móviles.
  static const String ordersEndpoint = '/orders';

  /// Endpoint para consultar la ruta y pedidos asignados al domiciliario.
  static const String assignedOrdersEndpoint = '/orders/assigned';

  /// Endpoint para confirmar la recepción física de la ruta asignada.
  static const String confirmReceptionEndpoint = '/orders/confirm-reception';

  /// Endpoint base para actualización de estado de un pedido.
  static const String updateStatusEndpoint = '/orders';

  /// Endpoint base para confirmación de entrega y recaudo de un pedido.
  static const String confirmDeliveryEndpoint = '/orders';

  /// Endpoint base para reporte de novedades de entrega.
  static const String noveltyEndpoint = '/orders';

  /// Endpoint base de domiciliarios para telemetría GPS y estado de turno.
  static const String couriersEndpoint = '/couriers';

  /// Intervalo en segundos para la transmisión de telemetría GPS.
  static const int telemetryIntervalSeconds = 5;

  /// Clave de persistencia local para la URL base REST.
  static const String keyBaseUrl = 'config_base_url';

  /// Clave de persistencia local para la URL de WebSocket.
  static const String keyWsUrl = 'config_ws_url';

  /// Clave de persistencia local para el token JWT de autenticación.
  static const String keyAuthToken = 'auth_token';

  /// Clave de persistencia local para los datos del perfil del domiciliario.
  static const String keyCourierData = 'courier_profile_data';

  /// Clave de persistencia local para el indicador de turno activo.
  static const String keyIsOnShift = 'courier_is_on_shift';

  /// URL base REST activa en memoria.
  static String _currentBaseUrl = defaultBaseUrl;

  /// URL de WebSocket activa en memoria.
  static String _currentWsUrl = defaultWsUrl;

  /// Versión de la aplicación sincronizada desde el archivo `pubspec.yaml`.
  static String _appVersion = '1.0.0';

  /// Obtiene la URL base REST actualmente configurada.
  static String get baseUrl => _currentBaseUrl;

  /// Obtiene la URL de WebSocket actualmente configurada.
  static String get wsUrl => _currentWsUrl;

  /// Obtiene la versión activa de la aplicación leída desde `pubspec.yaml`.
  static String get appVersion => _appVersion;

  /// Extrae el número de versión semántica a partir del contenido de un archivo `pubspec.yaml`.
  static String parseVersionFromPubspec(String yamlContent) {
    final match = RegExp(
      r'^version:\s*([^\s+#]+)',
      multiLine: true,
    ).firstMatch(yamlContent);
    if (match != null) {
      final parsed = match.group(1)?.trim() ?? '';
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }
    return _appVersion;
  }

  /// Carga y actualiza la versión de la aplicación leyendo el asset `pubspec.yaml`.
  static Future<String> loadAppVersion() async {
    try {
      final yamlContent = await rootBundle.loadString('pubspec.yaml');
      _appVersion = parseVersionFromPubspec(yamlContent);
    } catch (_) {}
    return _appVersion;
  }

  /// Inicializa las configuraciones de conexión almacenadas en preferencias locales y la versión de la app.
  static Future<void> init() async {
    await loadAppVersion();
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentBaseUrl = prefs.getString(keyBaseUrl) ?? defaultBaseUrl;
      _currentWsUrl = prefs.getString(keyWsUrl) ?? defaultWsUrl;
    } catch (_) {
      _currentBaseUrl = defaultBaseUrl;
      _currentWsUrl = defaultWsUrl;
    }
  }

  /// Actualiza dinámicamente las URLs del servidor REST y WebSocket.
  static Future<void> setCustomUrls({
    required String baseUrl,
    required String wsUrl,
  }) async {
    _currentBaseUrl = baseUrl;
    _currentWsUrl = wsUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyBaseUrl, baseUrl);
      await prefs.setString(keyWsUrl, wsUrl);
    } catch (_) {}
  }

  /// Restablece las URLs de conexión a los valores predeterminados de producción/desarrollo.
  static Future<void> resetDefaults() async {
    _currentBaseUrl = defaultBaseUrl;
    _currentWsUrl = defaultWsUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyBaseUrl);
      await prefs.remove(keyWsUrl);
    } catch (_) {}
  }
}
