import '../models/centro_salud.dart';
import '../models/favorito.dart';
import '../models/perfil.dart';
import '../models/recordatorio.dart';

/// Contratos de acceso a datos. La app solo conoce estas interfaces;
/// la implementación real usa Supabase (`data/supabase/`) y las pruebas
/// usan implementaciones en memoria.

/// Usuario autenticado.
class UsuarioActual {
  final String id;
  final String correo;
  const UsuarioActual({required this.id, required this.correo});
}

/// Resultado de registrar una cuenta.
enum ResultadoRegistro { sesionIniciada, confirmarCorreo }

abstract class AuthRepositorio {
  UsuarioActual? get usuarioActual;

  /// Emite cada vez que se inicia o se cierra sesión.
  Stream<UsuarioActual?> get cambios;

  Future<void> iniciarSesion(String correo, String clave);
  Future<ResultadoRegistro> registrar(
      {required String nombre, required String correo, required String clave});
  Future<void> cerrarSesion();
}

/// Filtros dinámicos para la consulta de centros.
class FiltroCentros {
  final String texto;
  final String? ciudad; // null = todas
  final TipoCentro? tipo; // null = todos
  final bool soloEmergencias;

  const FiltroCentros({
    this.texto = '',
    this.ciudad,
    this.tipo,
    this.soloEmergencias = false,
  });

  FiltroCentros copiar({
    String? texto,
    String? Function()? ciudad,
    TipoCentro? Function()? tipo,
    bool? soloEmergencias,
  }) =>
      FiltroCentros(
        texto: texto ?? this.texto,
        ciudad: ciudad != null ? ciudad() : this.ciudad,
        tipo: tipo != null ? tipo() : this.tipo,
        soloEmergencias: soloEmergencias ?? this.soloEmergencias,
      );
}

abstract class CentrosRepositorio {
  Future<List<CentroSalud>> buscar(FiltroCentros filtro);
  Future<CentroSalud?> porId(String id);
}

abstract class FavoritosRepositorio {
  Future<List<Favorito>> listar();
  Future<Favorito?> buscarPorCentro(String centroId);
  Future<void> agregar(String centroId, {String nota = ''});
  Future<void> actualizarNota(String favoritoId, String nota);

  /// Baja lógica: `activo = false`.
  Future<void> quitar(String favoritoId);
}

abstract class RecordatoriosRepositorio {
  Future<List<Recordatorio>> listar({bool incluirPasados = false});
  Future<void> crear(Recordatorio r);
  Future<void> actualizar(Recordatorio r);

  /// Baja lógica: `activo = false`.
  Future<void> eliminar(String id);
}

abstract class PerfilRepositorio {
  Future<Perfil> obtener();
  Future<void> actualizar(Perfil perfil);
}
