import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../views/login_screen.dart';
import '../views/home_orders_screen.dart';
import '../views/order_detail_map_screen.dart';

/// Manejador de rutas de navegación de la aplicación
class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String orderDetail = '/order-detail';

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
      case orderDetail:
        final order = settings.arguments as OrderModel;
        return MaterialPageRoute(
          builder: (_) => OrderDetailMapScreen(order: order),
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
