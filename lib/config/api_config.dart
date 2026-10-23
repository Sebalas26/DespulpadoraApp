import 'package:shared_preferences/shared_preferences.dart';

/// Opción de estilo cartográfico (Sincronizado con MAP_STYLES de la PWA)
class MapStyleOption {
  final String id;
  final String name;
  final String shortName;
  final String badge;
  final String url;
  final double maxZoom;
  final bool isDark;

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

/// Configuración central de endpoints de API REST para PulpasPro Domicilios (ApiDespulpadora)
class ApiConfig {
  // URLs por defecto (ASP.NET Core Web API en puerto 5000)
  // Para emulador Android usar http://10.0.2.2:5000/api o IP LAN de la máquina de desarrollo
  static const String defaultBaseUrl = 'http://localhost:5000/api';
  static const String defaultWsUrl = 'ws://localhost:5000/ws';

  // Coordenadas de Planta Cava Matriz Cundinamarca (Parque Industrial Calle 80 / Cota) - Igual a PWA
  static const double plantaMatrizLat = 4.7125;
  static const double plantaMatrizLng = -74.1420;

  // Stadia Maps Vector Retina & Estilos Cartográficos de la PWA
  static const String stadiaApiKey = '28312715-2030-4d54-ad98-458156a468d2';

  static const String stadiaSmoothTileUrl =
      'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}@2x.png?api_key=$stadiaApiKey';
  static const String stadiaDarkTileUrl =
      'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}@2x.png?api_key=$stadiaApiKey';
  static const String esriGrayTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}';
  static const String osmStandardTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // Tile Server por defecto: Stadia Maps Alidade Smooth (idéntico a la PWA)
  static const String osmTileUrl = stadiaSmoothTileUrl;
  static const String userAgentPackageName = 'com.pulpaspro.despulpadora_app';

  // Catálogo de estilos de mapa idéntico a la PWA
  static const List<MapStyleOption> mapStyles = [
    MapStyleOption(
      id: 'stadia-smooth',
      name: 'Stadia Maps Alidade Smooth',
      shortName: 'Stadia Smooth',
      badge: 'VECTOR RETINA',
      url: stadiaSmoothTileUrl,
      maxZoom: 20,
      isDark: false,
    ),
    MapStyleOption(
      id: 'stadia-dark',
      name: 'Stadia Maps Alidade Smooth Dark',
      shortName: 'Stadia Dark',
      badge: 'MODO NOCHE',
      url: stadiaDarkTileUrl,
      maxZoom: 20,
      isDark: true,
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

  // Rutas REST conectadas a ApiDespulpadora
  static const String loginEndpoint = '/auth/login-mobile';
  static const String ordersEndpoint = '/orders';
  static const String updateStatusEndpoint = '/orders'; // /orders/{id}/status
  static const String noveltyEndpoint = '/orders';     // /orders/{id}/novelty
  static const String couriersEndpoint = '/couriers';   // /couriers/{id}/location

  // Intervalo de telemetría GPS (segundos)
  static const int telemetryIntervalSeconds = 5;

  // Claves de SharedPreferences
  static const String keyBaseUrl = 'config_base_url';
  static const String keyWsUrl = 'config_ws_url';
  static const String keyAuthToken = 'auth_token';
  static const String keyCourierData = 'courier_profile_data';
  static const String keyIsOnShift = 'courier_is_on_shift';

  static String _currentBaseUrl = defaultBaseUrl;
  static String _currentWsUrl = defaultWsUrl;

  static String get baseUrl => _currentBaseUrl;
  static String get wsUrl => _currentWsUrl;

  /// Inicializa configuraciones guardadas
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentBaseUrl = prefs.getString(keyBaseUrl) ?? defaultBaseUrl;
    _currentWsUrl = prefs.getString(keyWsUrl) ?? defaultWsUrl;
  }

  /// Permite cambiar las URLs dinámicamente desde la app para pruebas de campo
  static Future<void> setCustomUrls({required String baseUrl, required String wsUrl}) async {
    _currentBaseUrl = baseUrl;
    _currentWsUrl = wsUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyBaseUrl, baseUrl);
    await prefs.setString(keyWsUrl, wsUrl);
  }

  /// Restablece URLs por defecto
  static Future<void> resetDefaults() async {
    _currentBaseUrl = defaultBaseUrl;
    _currentWsUrl = defaultWsUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyBaseUrl);
    await prefs.remove(keyWsUrl);
  }
}
