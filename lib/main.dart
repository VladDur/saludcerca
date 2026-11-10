import 'package:flutter/material.dart';

import 'models/centro_salud.dart';
import 'screens/detalle_centro_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const SaludCercaApp());
}

/// Nombres de las rutas de la app.
class Rutas {
  static const login = '/';
  static const inicio = '/inicio';
  static const detalle = '/detalle';
}

class SaludCercaApp extends StatelessWidget {
  const SaludCercaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SaludCerca',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      initialRoute: Rutas.login,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case Rutas.inicio:
            final nombre = settings.arguments as String? ?? 'Usuario';
            return MaterialPageRoute(
              builder: (_) => HomeScreen(nombreUsuario: nombre),
              settings: settings,
            );
          case Rutas.detalle:
            final centro = settings.arguments as CentroSalud;
            return MaterialPageRoute(
              builder: (_) => DetalleCentroScreen(centro: centro),
              settings: settings,
            );
          case Rutas.login:
          default:
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
              settings: settings,
            );
        }
      },
    );
  }
}
