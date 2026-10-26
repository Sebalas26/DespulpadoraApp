import 'package:flutter/material.dart';
import '../views/courier_route_map_screen.dart';
import '../views/login_screen.dart';
import '../views/home_orders_screen.dart';
import '../views/route_preview_map_screen.dart';

/// Manejador centralizado de rutas de navegación de la aplicación.
class AppRoutes {
  /// Ruta de la pantalla de inicio de sesión.
  static const String login = '/login';

  /// Ruta del panel principal de pedidos y estado de ruta.
  static const String home = '/home';

  /// Ruta de la vista previa cartográfica de puntos de entrega.
  static const String routePreviewMap = '/route-preview-map';

  /// Ruta de la pantalla de enrutado activo en vivo.
  static const String courierRouteMap = '/courier-route-map';

  /// Genera la ruta de navegación correspondiente a la configuración recibida.
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      case home:
        return MaterialPageRoute(
          builder: (_) => const HomeOrdersScreen(),
          settings: settings,
        );
      case routePreviewMap:
        return MaterialPageRoute(
          builder: (_) => const RoutePreviewMapScreen(),
          settings: settings,
        );
      case courierRouteMap:
        return MaterialPageRoute(
          builder: (_) => const CourierRouteMapScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
    }
  }
}
