import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta de colores e identidad visual de DGL / PulpasPro (Sincronizada con PWA)
class AppColors {
  // Primarios DGL Forest Green (--color-primary en PWA)
  static const Color primary = Color(0xFF1E5E3A);       // Forest Green principal
  static const Color primaryDark = Color(0xFF164A2D);   // Forest Green hover/dark
  static const Color primaryLight = Color(0xFF1E5E3A);  // Acento verde legible sobre fondo claro
  static const Color primarySoft = Color(0xFFEAF5EE);   // --color-primary-light
  static const Color primaryBorder = Color(0xFFD1E7D8); // --color-primary-border
  static const Color primaryGlow = Color(0x261E5E3A);   // Sombra / resplandor suave

  // Fondos y Superficies (DGL Clean Light Aesthetic)
  static const Color background = Color(0xFFF6F8F7);      // --bg-app
  static const Color surface = Color(0xFFFFFFFF);         // --bg-card
  static const Color surfaceElevated = Color(0xFFF1F5F2); // --bg-hover / --bg-subtle
  static const Color border = Color(0xFFEEF2EF);          // --border-subtle
  static const Color borderHighlight = Color(0xFFE2E8F0); // --border-highlight

  // Textos (--text-main, --text-muted, --text-dim)
  static const Color textPrimary = Color(0xFF111827);   // Gris carbón profundo
  static const Color textSecondary = Color(0xFF6B7280); // Gris medio
  static const Color textMuted = Color(0xFF9CA3AF);     // Gris suave

  // Estados de Entrega (Sincronizados con badges de PWA)
  static const Color statusAsignado = Color(0xFF2563EB);  // Blue 600 (--status-info)
  static const Color statusEnCamino = Color(0xFFD97706);  // Amber 600 (--status-warning)
  static const Color statusEnPunto = Color(0xFF7C3AED);   // Purple 600 (--color-purple-text)
  static const Color statusEntregado = Color(0xFF1E5E3A); // DGL Forest Green (--status-success)
  static const Color statusNovedad = Color(0xFFDC2626);   // Red 600 (--status-danger)

  // Acciones y Alertas
  static const Color success = Color(0xFF1E5E3A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);
  static const Color whatsapp = Color(0xFF25D366);
  static const Color waze = Color(0xFF059669);
}

/// Definición del tema visual de la aplicación (Estilo DGL Light igual a la PWA)
class AppTheme {
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
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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

  /// Alias para mantener compatibilidad con referencias existentes
  static ThemeData get darkTheme => lightTheme;
}
