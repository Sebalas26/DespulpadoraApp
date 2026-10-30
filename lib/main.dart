import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/auth_cubit.dart';
import 'blocs/orders_cubit.dart';
import 'blocs/tracking_cubit.dart';
import 'config/api_config.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'services/api_service.dart';
import 'services/location_service.dart';
import 'services/websocket_service.dart';
import 'views/home_orders_screen.dart';
import 'views/login_screen.dart';

/// Punto de entrada principal de la aplicación móvil DespulpadoraApp.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await ApiConfig.init();

  runApp(const PulpasProApp());
}

/// Widget raíz que inicializa los proveedores de estado BLoC/Cubit y la configuración de navegación.
class PulpasProApp extends StatefulWidget {
  /// Crea una nueva instancia de [PulpasProApp].
  const PulpasProApp({super.key});

  @override
  State<PulpasProApp> createState() => _PulpasProAppState();
}

/// Estado interno de [PulpasProApp] que administra las instancias de servicios principales.
class _PulpasProAppState extends State<PulpasProApp> {
  /// Servicio de comunicación HTTP REST.
  late final ApiService _apiService;

  /// Servicio de comunicación en tiempo real vía WebSocket.
  late final WebSocketService _wsService;

  /// Servicio de geolocalización GPS y lectura de batería.
  late final LocationService _locationService;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _wsService = WebSocketService();
    _locationService = LocationService();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (_) =>
              AuthCubit(apiService: _apiService)..checkStoredSession(),
        ),
        BlocProvider<OrdersCubit>(
          create: (_) => OrdersCubit(apiService: _apiService),
        ),
        BlocProvider<TrackingCubit>(
          create: (_) => TrackingCubit(
            locationService: _locationService,
            wsService: _wsService,
            apiService: _apiService,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Dgl Domi',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        onGenerateRoute: AppRoutes.generateRoute,
        home: const AuthGate(),
      ),
    );
  }
}

/// Compuerta de navegación que dirige a la vista correspondiente según el estado de autenticación.
class AuthGate extends StatelessWidget {
  /// Crea una nueva instancia de [AuthGate].
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is AuthInitial) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (state is AuthAuthenticated) {
          return const HomeOrdersScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
