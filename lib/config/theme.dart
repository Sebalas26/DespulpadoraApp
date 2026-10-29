import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta de colores corporativa e identidad visual de DGL Despulpadora.
class AppColors {
  /// Color verde bosque principal de la marca.
  static const Color primary = Color(0xFF1E5E3A);

  /// Variación oscura del color primario para estados activos.
  static const Color primaryDark = Color(0xFF164A2D);

  /// Acento verde legible sobre superficies claras.
  static const Color primaryLight = Color(0xFF1E5E3A);

  /// Fondo verde suave para contenedores destacados.
  static const Color primarySoft = Color(0xFFEAF5EE);

  /// Borde verde suave para tarjetas y etiquetas activas.
  static const Color primaryBorder = Color(0xFFD1E7D8);

  /// Resplandor translúcido del color primario.
  static const Color primaryGlow = Color(0x261E5E3A);

  /// Color de fondo general de la aplicación.
  static const Color background = Color(0xFFF6F8F7);

  /// Color de superficie para tarjetas y modales.
  static const Color surface = Color(0xFFFFFFFF);

  /// Color de superficie elevada o secundaria.
  static const Color surfaceElevated = Color(0xFFF1F5F2);

  /// Color de borde sutil para divisores y contenedores.
  static const Color border = Color(0xFFEEF2EF);

  /// Color de borde resaltado para controles interactivos.
  static const Color borderHighlight = Color(0xFFE2E8F0);

  /// Color de texto principal de alto contraste.
  static const Color textPrimary = Color(0xFF111827);

  /// Color de texto secundario para subtítulos.
  static const Color textSecondary = Color(0xFF6B7280);

  /// Color de texto atenuado para pistas y metadatos.
  static const Color textMuted = Color(0xFF9CA3AF);

  /// Color identificador del estado Asignado.
  static const Color statusAsignado = Color(0xFF2563EB);

  /// Color identificador del estado En Camino.
  static const Color statusEnCamino = Color(0xFFD97706);

  /// Color identificador del estado En el Punto.
  static const Color statusEnPunto = Color(0xFF7C3AED);

  /// Color identificador del estado Entregado.
  static const Color statusEntregado = Color(0xFF1E5E3A);

  /// Color identificador del estado Novedad.
  static const Color statusNovedad = Color(0xFFDC2626);

  /// Color semántico de éxito.
  static const Color success = Color(0xFF1E5E3A);

  /// Color semántico de advertencia.
  static const Color warning = Color(0xFFD97706);

  /// Color semántico de error o peligro en tono coral/terracota suave.
  static const Color error = Color(0xFFC85A56);

  /// Fondo crema-rosado suave para alertas y notificaciones de error.
  static const Color errorSoftBg = Color(0xFFFDF2F2);

  /// Borde pastel delicado para contenedores de alerta y campos con error.
  static const Color errorSoftBorder = Color(0xFFF3C6C6);

  /// Fondo circular suave para íconos dentro de alertas de error.
  static const Color errorIconBg = Color(0xFFFCE4E4);

  /// Color de texto principal en tono vino oscuro suave para títulos de error.
  static const Color errorTextPrimary = Color(0xFF7F2D2B);

  /// Color de texto secundario para descripciones de error y validaciones.
  static const Color errorTextSecondary = Color(0xFF9E4744);

  /// Color semántico informativo.
  static const Color info = Color(0xFF2563EB);

  /// Color oficial para acciones de WhatsApp.
  static const Color whatsapp = Color(0xFF25D366);

  /// Color para integración con navegación Waze.
  static const Color waze = Color(0xFF059669);
}

/// Definición del tema visual Material 3 de la aplicación.
class AppTheme {
  /// Construye y retorna el tema claro corporativo.
  static ThemeData get lightTheme {
    final baseTextTheme = ThemeData.light().textTheme;
    final textTheme = GoogleFonts.latoTextTheme(baseTextTheme).copyWith(
      displayLarge: GoogleFonts.lato(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w900,
        fontSize: 28,
      ),
      titleLarge: GoogleFonts.lato(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
      titleMedium: GoogleFonts.lato(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
      bodyLarge: GoogleFonts.lato(
        color: AppColors.textPrimary,
        fontSize: 15,
      ),
      bodyMedium: GoogleFonts.lato(
        color: AppColors.textSecondary,
        fontSize: 13,
      ),
      labelLarge: GoogleFonts.lato(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      fontFamily: GoogleFonts.lato().fontFamily,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
        titleTextStyle: GoogleFonts.lato(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.lato(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.borderHighlight, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.lato(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        prefixIconColor: AppColors.primary,
        suffixIconColor: AppColors.textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderHighlight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderHighlight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        errorStyle: const TextStyle(
          color: AppColors.errorTextSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
    );
  }

  /// Alias de compatibilidad que retorna el tema visual principal.
  static ThemeData get darkTheme => lightTheme;
}
