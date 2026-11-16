import 'package:flutter/widgets.dart';

import '../data/repositorios.dart';
import '../settings/ajustes_controller.dart';

/// Dependencias de la app (repositorios y ajustes) disponibles para
/// cualquier pantalla con `AppScope.de(context)`.
class Dependencias {
  final AuthRepositorio auth;
  final CentrosRepositorio centros;
  final FavoritosRepositorio favoritos;
  final RecordatoriosRepositorio recordatorios;
  final PerfilRepositorio perfil;
  final AjustesController ajustes;

  const Dependencias({
    required this.auth,
    required this.centros,
    required this.favoritos,
    required this.recordatorios,
    required this.perfil,
    required this.ajustes,
  });
}

class AppScope extends InheritedWidget {
  final Dependencias dependencias;

  const AppScope({super.key, required this.dependencias, required super.child});

  static Dependencias de(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.dependencias;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      dependencias != oldWidget.dependencias;
}
