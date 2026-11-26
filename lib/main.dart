import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/env.dart';
import 'core/app_scope.dart';
import 'data/supabase/supabase_repositorios.dart';
import 'services/api_cliente.dart';
import 'services/calidad_aire_servicio.dart';
import 'services/clima_servicio.dart';
import 'services/geocodificacion_servicio.dart';
import 'services/ubicacion_servicio.dart';
import 'services/voz_servicio.dart';
import 'services/whatsapp_servicio.dart';
import 'settings/ajustes_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ajustes = await AjustesController.cargar();

  if (!Env.configurado) {
    runApp(ConfiguracionFaltanteApp(ajustes: ajustes));
    return;
  }

  // La sesión se guarda en el teléfono: al reabrir la app sigue iniciada.
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey, // anon key o publishable key
  );

  runApp(SaludCercaApp(dependencias: dependenciasReales(ajustes)));
}

/// Implementaciones reales: Supabase, Open-Meteo (clima y calidad del aire),
/// Nominatim, GPS, reconocimiento de voz del sistema y WhatsApp.
Dependencias dependenciasReales(AjustesController ajustes,
    {ClimaServicio? clima,
    GeocodificacionServicio? geocodificacion,
    CalidadAireServicio? calidadAire,
    VozServicio? voz,
    WhatsAppServicio? whatsapp}) {
  final api = ApiCliente();
  return Dependencias(
    auth: SupabaseAuthRepositorio(),
    centros: SupabaseCentrosRepositorio(),
    favoritos: SupabaseFavoritosRepositorio(),
    recordatorios: SupabaseRecordatoriosRepositorio(),
    perfil: SupabasePerfilRepositorio(),
    farmacias: SupabaseFarmaciasRepositorio(),
    ajustes: ajustes,
    clima: clima ?? OpenMeteoClimaServicio(api),
    geocodificacion: geocodificacion ?? NominatimServicio(api),
    ubicacion: GpsUbicacionServicio(),
    calidadAire: calidadAire ?? OpenMeteoCalidadAireServicio(api),
    voz: voz ?? SttVozServicio(),
    whatsapp: whatsapp ?? UrlWhatsAppServicio(),
  );
}
