import 'package:flutter/material.dart';

/// Colores de SaludCerca.
class AppColors {
  static const primario = Color(0xFF0E7C66); // verde salud
  static const primarioClaro = Color(0xFFE3F4EF);
  static const secundario = Color(0xFF1565C0); // azul confianza
  static const abierto = Color(0xFF2E7D32);
  static const abiertoFondo = Color(0xFFE8F5E9);
  static const cerrado = Color(0xFFC62828);
  static const cerradoFondo = Color(0xFFFFEBEE);
  static const emergencia = Color(0xFFE65100);
  static const emergenciaFondo = Color(0xFFFFF3E0);
  static const fondo = Color(0xFFF7F9F8);
  static const texto = Color(0xFF1B1F1E);
  static const textoSuave = Color(0xFF55605D);
}

/// Tema con textos y botones grandes, pensado para adultos mayores.
class AppTheme {
  static ThemeData get claro {
    final esquema = ColorScheme.fromSeed(
      seedColor: AppColors.primario,
      primary: AppColors.primario,
      secondary: AppColors.secundario,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: AppColors.fondo,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
            fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.texto),
        titleLarge: TextStyle(
            fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.texto),
        titleMedium: TextStyle(
            fontSize: 19, fontWeight: FontWeight.w600, color: AppColors.texto),
        bodyLarge: TextStyle(fontSize: 18, color: AppColors.texto),
        bodyMedium: TextStyle(fontSize: 16, color: AppColors.textoSuave),
        labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primario,
        foregroundColor: Colors.white,
        centerTitle: false,
        titleTextStyle: TextStyle(
            fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        labelStyle: const TextStyle(fontSize: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
