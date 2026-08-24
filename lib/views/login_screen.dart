import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../blocs/auth_cubit.dart';
import '../config/api_config.dart';
import '../config/routes.dart';
import '../config/theme.dart';

/// Pantalla de Autenticación para Mensajeros de PulpasPro
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController(text: 'MENSAJERO-01');
  final _passwordController = TextEditingController(text: 'pulpas2026');
  bool _obscurePassword = true;
  bool _rememberSession = true;

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthCubit>().login(
            usernameOrEmail: _userController.text.trim(),
            password: _passwordController.text,
            rememberSession: _rememberSession,
          );
    }
  }

  void _showServerConfigModal() {
    final baseUrlCtrl = TextEditingController(text: ApiConfig.baseUrl);
    final wsUrlCtrl = TextEditingController(text: ApiConfig.wsUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.settings_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Conexión de Servidor'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configura las IPs del backend y WebSocket según tu entorno:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            const Text('URL REST API:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextFormField(
              controller: baseUrlCtrl,
              decoration: const InputDecoration(hintText: 'http://192.168.1.50:3000/api'),
            ),
            const SizedBox(height: 12),
            const Text('URL WebSocket:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextFormField(
              controller: wsUrlCtrl,
              decoration: const InputDecoration(hintText: 'ws://192.168.1.50:3000/ws'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ApiConfig.resetDefaults();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Restablecer', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              await ApiConfig.setCustomUrls(
                baseUrl: baseUrlCtrl.text.trim(),
                wsUrl: wsUrlCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.home);
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo & Branding Hero
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            FontAwesomeIcons.motorcycle,
                            color: Colors.black,
                            size: 38,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Center(
                        child: Text(
                          'PulpasPro Domicilios',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Center(
                        child: Text(
                          'Portal Móvil de Mensajeros & Despachos',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Input Usuario
                      const Text(
                        'Usuario o ID de Mensajero',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _userController,
                        decoration: const InputDecoration(
                          hintText: 'Ej. MENSAJERO-01',
                          prefixIcon: Icon(Icons.person_rounded),
                        ),
                        validator: (val) =>
                            val == null || val.trim().isEmpty ? 'Ingresa tu usuario o correo' : null,
                      ),

                      const SizedBox(height: 18),

                      // Input Contraseña
                      const Text(
                        'Contraseña',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Ingresa tu contraseña' : null,
                      ),

                      const SizedBox(height: 12),

                      // Remember Session Checkbox
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _rememberSession,
                              activeColor: AppColors.primary,
                              checkColor: Colors.black,
                              onChanged: (val) {
                                setState(() {
                                  _rememberSession = val ?? true;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Recordar sesión en este dispositivo',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Botón Iniciar Sesión
                      BlocBuilder<AuthCubit, AuthState>(
                        builder: (context, state) {
                          final isLoading = state is AuthLoading;
                          return ElevatedButton(
                            onPressed: isLoading ? null : _submit,
                            child: isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Text(
                                    'Iniciar Turno',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Opciones de desarrollo / Servidor
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.tune_rounded, size: 16, color: AppColors.textMuted),
                            label: const Text(
                              'Ajustar Servidor IP',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                            onPressed: _showServerConfigModal,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
