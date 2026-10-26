import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/courier_model.dart';
import '../services/api_service.dart';

/// Clase base para los estados de autenticación del domiciliario.
abstract class AuthState {}

/// Estado inicial antes de verificar la sesión almacenada.
class AuthInitial extends AuthState {}

/// Estado de carga durante la verificación o inicio de sesión.
class AuthLoading extends AuthState {}

/// Estado que representa a un domiciliario autenticado con sesión activa.
class AuthAuthenticated extends AuthState {
  /// Información de perfil y credenciales del domiciliario autenticado.
  final CourierModel courier;

  /// Crea una nueva instancia de [AuthAuthenticated].
  AuthAuthenticated({required this.courier});
}

/// Estado que indica ausencia de sesión activa.
class AuthUnauthenticated extends AuthState {}

/// Estado que representa un error durante el proceso de autenticación.
class AuthError extends AuthState {
  /// Mensaje descriptivo del error ocurrido.
  final String message;

  /// Crea una nueva instancia de [AuthError].
  AuthError(this.message);
}

/// Cubit encargado de gestionar la autenticación, sesión local y estado de turno del domiciliario.
class AuthCubit extends Cubit<AuthState> {
  /// Servicio de comunicación con el backend REST.
  final ApiService _apiService;

  /// Crea una instancia de [AuthCubit] con inyección opcional de [ApiService].
  AuthCubit({ApiService? apiService})
      : _apiService = apiService ?? ApiService(),
        super(AuthInitial());

  /// Retorna el domiciliario actualmente autenticado o `null` si no hay sesión activa.
  CourierModel? get currentCourier {
    if (state is AuthAuthenticated) {
      return (state as AuthAuthenticated).courier;
    }
    return null;
  }

  /// Verifica si existe una sesión persistida en `SharedPreferences` al iniciar la aplicación.
  Future<void> checkStoredSession() async {
    emit(AuthLoading());
    try {
      final prefs = await SharedPreferences.getInstance();
      final courierDataStr = prefs.getString(ApiConfig.keyCourierData);
      final isOnShift = prefs.getBool(ApiConfig.keyIsOnShift) ?? false;

      if (courierDataStr != null && courierDataStr.isNotEmpty) {
        final Map<String, dynamic> json =
            jsonDecode(courierDataStr) as Map<String, dynamic>;
        final courier =
            CourierModel.fromJson(json).copyWith(isOnline: isOnShift);
        emit(AuthAuthenticated(courier: courier));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (_) {
      emit(AuthUnauthenticated());
    }
  }

  /// Autentica al domiciliario con sus credenciales y persiste la sesión si se solicita.
  Future<void> login({
    required String usernameOrEmail,
    required String password,
    bool rememberSession = true,
  }) async {
    emit(AuthLoading());
    try {
      final courier = await _apiService.login(
        usernameOrEmail: usernameOrEmail,
        password: password,
      );

      final prefs = await SharedPreferences.getInstance();
      if (rememberSession) {
        await prefs.setString(
          ApiConfig.keyCourierData,
          jsonEncode(courier.toJson()),
        );
        if (courier.token != null) {
          await prefs.setString(ApiConfig.keyAuthToken, courier.token!);
        }
      }

      final isOnShift = prefs.getBool(ApiConfig.keyIsOnShift) ?? true;
      final activeCourier = courier.copyWith(isOnline: isOnShift);

      emit(AuthAuthenticated(courier: activeCourier));
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Cambia el estado de turno del domiciliario y lo sincroniza con el backend y preferencias locales.
  Future<void> toggleShiftStatus(bool isOnShift) async {
    if (state is AuthAuthenticated) {
      try {
        final courier = (state as AuthAuthenticated).courier;
        final parsedId = int.tryParse(courier.id) ?? 0;
        await _apiService.updateShiftStatus(
          courierId: parsedId,
          status: isOnShift ? 'disponible' : 'fuera_turno',
          token: courier.token,
        );

        final updated = courier.copyWith(isOnline: isOnShift);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(ApiConfig.keyIsOnShift, isOnShift);

        emit(AuthAuthenticated(courier: updated));
      } catch (_) {}
    }
  }

  /// Cierra la sesión actual y elimina los datos de autenticación almacenados localmente.
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ApiConfig.keyAuthToken);
      await prefs.remove(ApiConfig.keyCourierData);
      await prefs.remove(ApiConfig.keyIsOnShift);
    } catch (_) {}
    emit(AuthUnauthenticated());
  }
}
