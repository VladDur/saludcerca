import 'package:flutter/widgets.dart';

import '../data/repositorios.dart';
import '../services/calidad_aire_servicio.dart';
import '../services/clima_servicio.dart';
import '../services/geocodificacion_servicio.dart';
import '../services/ubicacion_servicio.dart';
import '../services/voz_servicio.dart';
import '../services/whatsapp_servicio.dart';
import '../settings/ajustes_controller.dart';

/// Dependencias de la app (repositorios y ajustes) disponibles para
/// cualquier pantalla con `AppScope.de(context)`.
class Dependencias {
  final AuthRepositorio auth;
  final CentrosRepositorio centros;
  final FavoritosRepositorio favoritos;
  final RecordatoriosRepositorio recordatorios;
  final PerfilRepositorio perfil;
  final FarmaciasRepositorio farmacias;
  final AjustesController ajustes;

  // Sprint 3: APIs externas y GPS.
  final ClimaServicio clima;
  final GeocodificacionServicio geocodificacion;
  final UbicacionServicio ubicacion;

  // Sprint 4: calidad del aire (HU-15) y dictado por voz (HU-10).
  final CalidadAireServicio calidadAire;
  final VozServicio voz;

  // Consulta de medicamentos a la farmacia por WhatsApp.
  final WhatsAppServicio whatsapp;

  const Dependencias({
    required this.auth,
    required this.centros,
    required this.favoritos,
    required this.recordatorios,
    required this.perfil,
    required this.farmacias,
    required this.ajustes,
    required this.clima,
    required this.geocodificacion,
    required this.ubicacion,
    required this.calidadAire,
    required this.voz,
    required this.whatsapp,
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
