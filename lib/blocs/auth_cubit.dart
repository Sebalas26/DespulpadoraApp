import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/courier_model.dart';
import '../services/api_service.dart';

/// Estados de autenticación
abstract class AuthState {}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final CourierModel courier;
  AuthAuthenticated({required this.courier});
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

/// Cubit para gestionar el inicio de sesión, perfil y persistencia de token JWT
class AuthCubit extends Cubit<AuthState> {
  final ApiService _apiService;

  AuthCubit({ApiService? apiService})
      : _apiService = apiService ?? ApiService(),
        super(AuthInitial());

  CourierModel? get currentCourier {
    if (state is AuthAuthenticated) {
      return (state as AuthAuthenticated).courier;
    }
    return null;
  }

  /// Verifica si existe una sesión guardada en SharedPreferences al iniciar la app
  Future<void> checkStoredSession() async {
    emit(AuthLoading());
    try {
      final prefs = await SharedPreferences.getInstance();
      final courierDataStr = prefs.getString(ApiConfig.keyCourierData);
      final isOnShift = prefs.getBool(ApiConfig.keyIsOnShift) ?? false;

      if (courierDataStr != null) {
        final Map<String, dynamic> json = jsonDecode(courierDataStr);
        final courier = CourierModel.fromJson(json).copyWith(isOnline: isOnShift);
        emit(AuthAuthenticated(courier: courier));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthUnauthenticated());
    }
  }

  /// Inicio de sesión con validación de credenciales
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
        await prefs.setString(ApiConfig.keyCourierData, jsonEncode(courier.toJson()));
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

  /// Cambia el estado del mensajero entre "En Turno / Disponible" vs "Desconectado"
  Future<void> toggleShiftStatus(bool isOnShift) async {
    if (state is AuthAuthenticated) {
      final courier = (state as AuthAuthenticated).courier;
      final updated = courier.copyWith(isOnline: isOnShift);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(ApiConfig.keyIsOnShift, isOnShift);

      emit(AuthAuthenticated(courier: updated));
    }
  }

  /// Cierre de sesión y limpieza de credenciales locales
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
