import 'package:flutter/material.dart';

/// Colores base de SaludCerca.
class AppColors {
  static const primario = Color(0xFF0E7C66); // verde salud
  static const secundario = Color(0xFF1565C0); // azul confianza
}

/// Colores de estado (abierto, cerrado, emergencias) que cambian según
/// el modo claro/oscuro y el alto contraste.
@immutable
class ColoresSalud extends ThemeExtension<ColoresSalud> {
  final Color abierto, abiertoFondo;
  final Color cerrado, cerradoFondo;
  final Color emergencia, emergenciaFondo;
  final Color acento; // distancia, ubicación
  final Color tarjetaBorde;
  final double grosorBorde;

  const ColoresSalud({
    required this.abierto,
    required this.abiertoFondo,
    required this.cerrado,
    required this.cerradoFondo,
    required this.emergencia,
    required this.emergenciaFondo,
    required this.acento,
    required this.tarjetaBorde,
    required this.grosorBorde,
  });

  static ColoresSalud de(BuildContext context) =>
      Theme.of(context).extension<ColoresSalud>()!;

  static const claro = ColoresSalud(
    abierto: Color(0xFF2E7D32),
    abiertoFondo: Color(0xFFE8F5E9),
    cerrado: Color(0xFFC62828),
    cerradoFondo: Color(0xFFFFEBEE),
    emergencia: Color(0xFFB34700),
    emergenciaFondo: Color(0xFFFFF3E0),
    acento: AppColors.secundario,
    tarjetaBorde: Color(0x00000000),
    grosorBorde: 0,
  );

  static const oscuro = ColoresSalud(
    abierto: Color(0xFF81C784),
    abiertoFondo: Color(0xFF1B3A1E),
    cerrado: Color(0xFFEF9A9A),
    cerradoFondo: Color(0xFF3E1A1A),
    emergencia: Color(0xFFFFB74D),
    emergenciaFondo: Color(0xFF3D2A10),
    acento: Color(0xFF90CAF9),
    tarjetaBorde: Color(0xFF2C3533),
    grosorBorde: 1,
  );

  static const claroContraste = ColoresSalud(
    abierto: Color(0xFF00450B),
    abiertoFondo: Colors.white,
    cerrado: Color(0xFF8B0000),
    cerradoFondo: Colors.white,
    emergencia: Color(0xFF6B2600),
    emergenciaFondo: Colors.white,
    acento: Color(0xFF002F6C),
    tarjetaBorde: Colors.black,
    grosorBorde: 2,
  );

  static const oscuroContraste = ColoresSalud(
    abierto: Color(0xFF9CFF9C),
    abiertoFondo: Colors.black,
    cerrado: Color(0xFFFFA8A8),
    cerradoFondo: Colors.black,
    emergencia: Color(0xFFFFD54F),
    emergenciaFondo: Colors.black,
    acento: Color(0xFFFFFF66),
    tarjetaBorde: Colors.white,
    grosorBorde: 2,
  );

  @override
  ColoresSalud copyWith() => this;

  @override
  ColoresSalud lerp(ThemeExtension<ColoresSalud>? other, double t) =>
      (other is ColoresSalud && t >= .5) ? other : this;
}

/// Tema con textos y botones grandes, pensado para adultos mayores.
/// Hay 4 variantes: claro, oscuro, claro con alto contraste y oscuro con
/// alto contraste.
class AppTheme {
  /// Tamaño mínimo de cualquier control táctil: 48 dp en Android
  /// (Material) y ≥ 44 pt en iOS (Apple HIG). En Flutter 1 dp = 1 pt lógico.
  static const tamanoMinimoToque = 48.0;

  static ThemeData construir(
      {required Brightness brillo, required bool altoContraste}) {
    final oscuro = brillo == Brightness.dark;
    final ColorScheme esquema;
    final ColoresSalud estados;

    if (altoContraste && oscuro) {
      esquema = const ColorScheme.dark(
        primary: Color(0xFFFFFF66),
        onPrimary: Colors.black,
        secondary: Color(0xFF66FFFF),
        onSecondary: Colors.black,
        secondaryContainer: Color(0xFF00474D),
        onSecondaryContainer: Colors.white,
        surface: Colors.black,
        onSurface: Colors.white,
        onSurfaceVariant: Colors.white,
        surfaceContainerHighest: Color(0xFF1A1A1A),
        primaryContainer: Color(0xFF000000),
        onPrimaryContainer: Color(0xFFFFFF66),
        outline: Colors.white,
        error: Color(0xFFFF8A80),
        onError: Colors.black,
      );
      estados = ColoresSalud.oscuroContraste;
    } else if (altoContraste) {
      esquema = const ColorScheme.light(
        primary: Color(0xFF003D32),
        onPrimary: Colors.white,
        secondary: Color(0xFF002F6C),
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFCCE5FF),
        onSecondaryContainer: Colors.black,
        surface: Colors.white,
        onSurface: Colors.black,
        onSurfaceVariant: Colors.black,
        surfaceContainerHighest: Color(0xFFF0F0F0),
        primaryContainer: Colors.white,
        onPrimaryContainer: Color(0xFF003D32),
        outline: Colors.black,
        error: Color(0xFF8B0000),
        onError: Colors.white,
      );
      estados = ColoresSalud.claroContraste;
    } else if (oscuro) {
      esquema = ColorScheme.fromSeed(
        seedColor: AppColors.primario,
        brightness: Brightness.dark,
      );
      estados = ColoresSalud.oscuro;
    } else {
      esquema = ColorScheme.fromSeed(
        seedColor: AppColors.primario,
        primary: AppColors.primario,
        secondary: AppColors.secundario,
      );
      estados = ColoresSalud.claro;
    }

    final fondo = altoContraste
        ? esquema.surface
        : (oscuro ? const Color(0xFF101514) : const Color(0xFFF7F9F8));
    final tarjeta = altoContraste
        ? esquema.surface
        : (oscuro ? const Color(0xFF1A2120) : Colors.white);
    final texto = esquema.onSurface;
    final textoSuave = altoContraste
        ? esquema.onSurface
        : (oscuro ? const Color(0xFFB7C2BF) : const Color(0xFF55605D));
    final borde = BorderSide(
        color: altoContraste ? esquema.outline : esquema.outlineVariant,
        width: altoContraste ? 2 : 1);
    const minimo = Size(tamanoMinimoToque, tamanoMinimoToque);
    final forma =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

    return ThemeData(
      useMaterial3: true,
      brightness: brillo,
      colorScheme: esquema,
      scaffoldBackgroundColor: fondo,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [estados],
      textTheme: TextTheme(
        headlineMedium:
            TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: texto),
        titleLarge:
            TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: texto),
        titleMedium:
            TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: texto),
        bodyLarge: TextStyle(fontSize: 18, color: texto),
        bodyMedium: TextStyle(fontSize: 16, color: textoSuave),
        labelLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: altoContraste
            ? esquema.surface
            : (oscuro ? const Color(0xFF14322B) : AppColors.primario),
        foregroundColor: altoContraste ? esquema.onSurface : Colors.white,
        centerTitle: false,
        shape: altoContraste
            ? Border(bottom: BorderSide(color: esquema.outline, width: 2))
            : null,
        titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: altoContraste ? esquema.onSurface : Colors.white),
      ),
      cardTheme: CardThemeData(
        color: tarjeta,
        elevation: altoContraste || oscuro ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: estados.grosorBorde > 0
              ? BorderSide(
                  color: estados.tarjetaBorde, width: estados.grosorBorde)
              : BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tarjeta,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        labelStyle: TextStyle(fontSize: 18, color: textoSuave),
        hintStyle: TextStyle(fontSize: 18, color: textoSuave),
        errorStyle: const TextStyle(fontSize: 15),
        errorMaxLines: 2,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: borde),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: borde),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(tamanoMinimoToque, 56),
          textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          shape: forma,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(tamanoMinimoToque, 56),
          textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          side: BorderSide(
              color: altoContraste ? esquema.outline : esquema.primary,
              width: altoContraste ? 2 : 1.2),
          shape: forma,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: minimo,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: minimo),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: minimo,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          side: borde,
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: TextStyle(fontSize: 16, color: texto),
        side: borde,
        backgroundColor: tarjeta,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        extendedTextStyle:
            const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: altoContraste
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: esquema.outline, width: 2))
            : null,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: altoContraste ? esquema.surface : null,
        indicatorColor: altoContraste ? esquema.primary : null,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            size: 28,
            color: altoContraste && s.contains(WidgetState.selected)
                ? esquema.onPrimary
                : null)),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 14,
            color: texto,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.bold
                : FontWeight.w500)),
      ),
      switchTheme: altoContraste
          ? SwitchThemeData(
              trackOutlineColor: WidgetStatePropertyAll(esquema.outline),
              trackOutlineWidth: const WidgetStatePropertyAll(2))
          : null,
      dividerTheme: DividerThemeData(
          color: altoContraste ? esquema.outline : null,
          thickness: altoContraste ? 1.5 : null),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: TextStyle(fontSize: 17),
      ),
    );
  }
}
