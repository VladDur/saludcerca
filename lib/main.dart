import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/env.dart';
import 'core/app_scope.dart';
import 'data/supabase/supabase_repositorios.dart';
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

  runApp(SaludCercaApp(
    dependencias: Dependencias(
      auth: SupabaseAuthRepositorio(),
      centros: SupabaseCentrosRepositorio(),
      favoritos: SupabaseFavoritosRepositorio(),
      recordatorios: SupabaseRecordatoriosRepositorio(),
      perfil: SupabasePerfilRepositorio(),
      ajustes: ajustes,
    ),
  ));
}
