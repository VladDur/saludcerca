/// Configuración de Supabase.
///
/// Los valores NO se guardan en el código: se pasan al compilar con
/// `--dart-define-from-file=env.json` (ver `env.example.json` y el README).
/// La anon key es pública por diseño; la seguridad la dan las políticas RLS.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get configurado =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
