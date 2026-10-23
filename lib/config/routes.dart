import 'package:flutter/material.dart';
import '../views/courier_route_map_screen.dart';
import '../views/login_screen.dart';
import '../views/home_orders_screen.dart';
import '../views/route_preview_map_screen.dart';

/// Manejador de rutas de navegación de la aplicación
class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String routePreviewMap = '/route-preview-map';
  static const String courierRouteMap = '/courier-route-map';

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
