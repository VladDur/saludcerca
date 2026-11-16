import 'package:flutter/material.dart';

import 'core/app_scope.dart';
import 'data/repositorios.dart';
import 'screens/auth/login_screen.dart';
import 'screens/shell_screen.dart';
import 'settings/ajustes_controller.dart';
import 'theme/app_theme.dart';

/// Raíz de la app: aplica tema (claro/oscuro/sistema), alto contraste y
/// texto grande en TODAS las pantallas, y decide qué mostrar según la sesión.
class SaludCercaApp extends StatelessWidget {
  final Dependencias dependencias;

  const SaludCercaApp({super.key, required this.dependencias});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      dependencias: dependencias,
      child: _AppConTema(
        ajustes: dependencias.ajustes,
        home: AuthGate(auth: dependencias.auth),
      ),
    );
  }
}

class _AppConTema extends StatelessWidget {
  final AjustesController ajustes;
  final Widget home;

  const _AppConTema({required this.ajustes, required this.home});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ajustes,
      builder: (context, _) => MaterialApp(
        title: 'SaludCerca',
        debugShowCheckedModeBanner: false,
        themeMode: ajustes.modoTema,
        theme: AppTheme.construir(
            brillo: Brightness.light, altoContraste: ajustes.altoContraste),
        darkTheme: AppTheme.construir(
            brillo: Brightness.dark, altoContraste: ajustes.altoContraste),
        // Texto grande: multiplica el tamaño elegido en el sistema.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          if (!ajustes.textoGrande) return child!;
          final base = mq.textScaler.scale(1);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(
                  (base * AjustesController.escalaTextoGrande).clamp(1.0, 2.0)),
            ),
            child: child!,
          );
        },
        home: home,
      ),
    );
  }
}

/// Protección de pantallas: sin sesión solo se ve el inicio de sesión.
class AuthGate extends StatefulWidget {
  final AuthRepositorio auth;

  const AuthGate({super.key, required this.auth});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<UsuarioActual?> _cambios = widget.auth.cambios;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UsuarioActual?>(
      stream: _cambios,
      initialData: widget.auth.usuarioActual,
      builder: (context, snap) {
        final usuario = snap.data;
        return usuario == null
            ? const LoginScreen()
            : ShellScreen(key: ValueKey(usuario.id), usuario: usuario);
      },
    );
  }
}

/// Se muestra si la app se compiló sin las variables de Supabase.
class ConfiguracionFaltanteApp extends StatelessWidget {
  final AjustesController ajustes;

  const ConfiguracionFaltanteApp({super.key, required this.ajustes});

  @override
  Widget build(BuildContext context) {
    return _AppConTema(
      ajustes: ajustes,
      home: Scaffold(
        appBar: AppBar(title: const Text('SaludCerca')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Falta configurar Supabase.\n\n'
            'Copia env.example.json como env.json, escribe la URL y la anon key '
            'de tu proyecto y ejecuta:\n\n'
            'flutter run --dart-define-from-file=env.json',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
