import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../blocs/auth_cubit.dart';
import '../config/api_config.dart';
import '../config/routes.dart';
import '../config/theme.dart';

/// Pantalla de autenticación para domiciliarios de DGL Despulpadora.
class LoginScreen extends StatefulWidget {
  /// Crea una nueva instancia de [LoginScreen].
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// Estado del formulario de autenticación y configuración de servidor en [LoginScreen].
class _LoginScreenState extends State<LoginScreen> {
  /// Clave global para validación del formulario de credenciales.
  final _formKey = GlobalKey<FormState>();

  /// Controlador de texto para el nombre de usuario o correo electrónico.
  final _userController = TextEditingController(text: '');

  /// Controlador de texto para la contraseña del domiciliario.
  final _passwordController = TextEditingController(text: '');

  /// Indica si la contraseña se muestra oculta en el campo de texto.
  bool _obscurePassword = true;

  /// Indica si se debe persistir la sesión en el dispositivo.
  bool _rememberSession = true;

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Valida el formulario e inicia la petición de autenticación en [AuthCubit].
  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthCubit>().login(
            usernameOrEmail: _userController.text.trim(),
            password: _passwordController.text,
            rememberSession: _rememberSession,
          );
    }
  }

  /// Muestra el diálogo modal para ajustar las URLs del servidor REST y WebSocket.
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
              'Configura los endpoints del backend y WebSocket según tu entorno:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            const Text(
              'URL REST API:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: baseUrlCtrl,
              decoration: const InputDecoration(
                hintText:
                    'https://apidevdespulpadora.parking-flow.com/api/mobile',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'URL WebSocket:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: wsUrlCtrl,
              decoration: const InputDecoration(
                hintText: 'wss://apidevdespulpadora.parking-flow.com/ws',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ApiConfig.resetDefaults();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text(
              'Restablecer',
              style: TextStyle(color: AppColors.textMuted),
            ),
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
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF1B4D2E),
            image: DecorationImage(
              image: AssetImage('assets/images/auth-hero-bg.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 34,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0x0A000000)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.32),
                          blurRadius: 36,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 64,
                              height: 64,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: const Color(0xFFECEEF0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/images/logo-dgl.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              'DGL DESPULPADORA',
                              style: GoogleFonts.lato(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: const Color(0xFF1B5133),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: Text(
                              'DGL Domiciliarios',
                              style: GoogleFonts.lato(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                                color: const Color(0xFF0F291E),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: Text(
                              'Ingresa tus credenciales para acceder a la plataforma',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.lato(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Usuario o ID de Mensajero',
                            style: GoogleFonts.lato(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _userController,
                            style: GoogleFonts.lato(
                              fontSize: 14.5,
                              color: const Color(0xFF111827),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Ingresa tu usuario o ID',
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                                color: Color(0xFF9CA3AF),
                                size: 20,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF1B5133),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                    ? 'Ingresa tu usuario o correo'
                                    : null,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Contraseña',
                            style: GoogleFonts.lato(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(
                              fontSize: 14.5,
                              color: Color(0xFF111827),
                            ),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                                color: Color(0xFF9CA3AF),
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: const Color(0xFF9CA3AF),
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF1B5133),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            validator: (val) => val == null || val.isEmpty
                                ? 'Ingresa tu contraseña'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              SizedBox(
                                height: 22,
                                width: 22,
                                child: Checkbox(
                                  value: _rememberSession,
                                  activeColor: const Color(0xFF1B5133),
                                  checkColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      _rememberSession = val ?? true;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Recordar mi sesión en este dispositivo',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          BlocBuilder<AuthCubit, AuthState>(
                            builder: (context, state) {
                              final isLoading = state is AuthLoading;
                              return ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1B5133),
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  shadowColor: const Color(0x401B5133),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                    horizontal: 20,
                                  ),
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: isLoading ? null : _submit,
                                child: isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Iniciar Turno',
                                            style: GoogleFonts.lato(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                              );
                            },
                          ),
                          const SizedBox(height: 22),
                          const Divider(color: Color(0xFFE5E7EB), height: 1),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(
                                Icons.tune_rounded,
                                size: 15,
                                color: Color(0xFF6B7280),
                              ),
                              label: const Text(
                                'Ajustar Servidor IP',
                                style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 12,
                                ),
                              ),
                              onPressed: _showServerConfigModal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Center(
                            child: Text(
                              'DGL Despulpadora · v2.0 Flutter · 2026',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
