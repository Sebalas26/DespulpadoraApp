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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuración de barra de estado transparente y estilo claro DGL
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Inicializar almacenamiento de configuración
  await ApiConfig.init();

  runApp(const PulpasProApp());
}

class PulpasProApp extends StatefulWidget {
  const PulpasProApp({super.key});

  @override
  State<PulpasProApp> createState() => _PulpasProAppState();
}

class _PulpasProAppState extends State<PulpasProApp> {
  late final ApiService _apiService;
  late final WebSocketService _wsService;
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
          create: (_) => AuthCubit(apiService: _apiService)..checkStoredSession(),
        ),
        BlocProvider<OrdersCubit>(
          create: (_) => OrdersCubit(apiService: _apiService),
        ),
        BlocProvider<TrackingCubit>(
          create: (_) => TrackingCubit(
            locationService: _locationService,
            wsService: _wsService,
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

/// Controla la pantalla inicial según el estado de la sesión guardada
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is AuthInitial || state is AuthLoading) {
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
