import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/centro_salud.dart';
import '../../models/favorito.dart';
import '../../models/perfil.dart';
import '../../models/recordatorio.dart';
import '../repositorios.dart';

/// Implementaciones de los repositorios con Supabase.
/// Todas las consultas pasan por RLS: cada usuario solo ve sus filas.

SupabaseClient get _db => Supabase.instance.client;

String _uid() {
  final id = _db.auth.currentUser?.id;
  if (id == null) throw const AuthException('Sesión expirada');
  return id;
}

/// Supabase devuelve un usuario con la lista de identidades vacía cuando el
/// correo ya estaba registrado (protección contra enumeración de cuentas).
bool correoYaRegistrado(List<Object?>? identidades) =>
    identidades != null && identidades.isEmpty;

class SupabaseAuthRepositorio implements AuthRepositorio {
  UsuarioActual? _mapear(User? u) =>
      u == null ? null : UsuarioActual(id: u.id, correo: u.email ?? '');

  @override
  UsuarioActual? get usuarioActual => _mapear(_db.auth.currentUser);

  @override
  Stream<UsuarioActual?> get cambios =>
      _db.auth.onAuthStateChange.map((e) => _mapear(e.session?.user));

  @override
  Future<void> iniciarSesion(String correo, String clave) async {
    await _db.auth.signInWithPassword(email: correo.trim(), password: clave);
  }

  @override
  Future<ResultadoRegistro> registrar(
      {required String nombre,
      required String correo,
      required String clave}) async {
    final r = await _db.auth.signUp(
      email: correo.trim(),
      password: clave,
      data: {'nombre_completo': nombre.trim()},
    );
    // Con "Confirm email" activo, Supabase no revela si el correo ya existe:
    // responde como si el registro fuera exitoso, pero sin identidades.
    if (correoYaRegistrado(r.user?.identities)) {
      throw const AuthException('User already registered');
    }
    return r.session != null
        ? ResultadoRegistro.sesionIniciada
        : ResultadoRegistro.confirmarCorreo;
  }

  @override
  Future<void> cerrarSesion() => _db.auth.signOut();
}

class SupabaseCentrosRepositorio implements CentrosRepositorio {
  @override
  Future<List<CentroSalud>> buscar(FiltroCentros filtro) async {
    var consulta = _db.from('v_centros').select();
    final texto = filtro.texto.trim().replaceAll(RegExp(r'[,()%*]'), ' ');
    if (texto.isNotEmpty) {
      consulta = consulta.or('nombre.ilike.*$texto*,zona.ilike.*$texto*');
    }
    if (filtro.ciudad != null) consulta = consulta.eq('ciudad', filtro.ciudad!);
    if (filtro.tipo != null) {
      consulta = consulta.eq('tipo', filtro.tipo!.valorBd);
    }
    if (filtro.soloEmergencias) {
      consulta = consulta.eq('atiende_emergencias', true);
    }

    final filas = await consulta.order('nombre');
    final centros = filas.map(CentroSalud.desdeMapa).toList()
      ..sort((a, b) => a.distanciaKm.compareTo(b.distanciaKm));
    return centros;
  }

  @override
  Future<CentroSalud?> porId(String id) async {
    final fila =
        await _db.from('v_centros').select().eq('id', id).maybeSingle();
    return fila == null ? null : CentroSalud.desdeMapa(fila);
  }
}

class SupabaseFavoritosRepositorio implements FavoritosRepositorio {
  @override
  Future<List<Favorito>> listar() async {
    final filas = await _db
        .from('favoritos')
        .select('id, centro_id, nota')
        .eq('activo', true)
        .order('creado_en', ascending: false);
    if (filas.isEmpty) return [];
    final ids = filas.map((f) => f['centro_id'] as String).toList();
    final centros = await _db.from('v_centros').select().inFilter('id', ids);
    final porId = {
      for (final c in centros.map(CentroSalud.desdeMapa)) c.id: c,
    };
    return filas
        .map((f) => Favorito.desdeMapa(f, centro: porId[f['centro_id']]))
        .where((f) => f.centro != null)
        .toList();
  }

  @override
  Future<Favorito?> buscarPorCentro(String centroId) async {
    final fila = await _db
        .from('favoritos')
        .select('id, centro_id, nota')
        .eq('centro_id', centroId)
        .eq('activo', true)
        .maybeSingle();
    return fila == null ? null : Favorito.desdeMapa(fila);
  }

  @override
  Future<void> agregar(String centroId, {String nota = ''}) async {
    // Si existía dado de baja, se reactiva (upsert sobre usuario + centro).
    await _db.from('favoritos').upsert({
      'usuario_id': _uid(),
      'centro_id': centroId,
      'nota': nota.trim(),
      'activo': true,
    }, onConflict: 'usuario_id,centro_id');
  }

  @override
  Future<void> actualizarNota(String favoritoId, String nota) async {
    await _db
        .from('favoritos')
        .update({'nota': nota.trim()}).eq('id', favoritoId);
  }

  @override
  Future<void> quitar(String favoritoId) async {
    await _db.from('favoritos').update({'activo': false}).eq('id', favoritoId);
  }
}

class SupabaseRecordatoriosRepositorio implements RecordatoriosRepositorio {
  @override
  Future<List<Recordatorio>> listar({bool incluirPasados = false}) async {
    var consulta = _db
        .from('recordatorios')
        .select(
            'id, titulo, descripcion, tipo, fecha_hora, centro_id, centros_salud(nombre)')
        .eq('activo', true);
    if (!incluirPasados) {
      consulta = consulta.gte(
          'fecha_hora',
          DateTime.now()
              .subtract(const Duration(hours: 1))
              .toUtc()
              .toIso8601String());
    }
    final filas = await consulta.order('fecha_hora');
    return filas.map(Recordatorio.desdeMapa).toList();
  }

  @override
  Future<void> crear(Recordatorio r) async {
    await _db
        .from('recordatorios')
        .insert({...r.aMapa(), 'usuario_id': _uid()});
  }

  @override
  Future<void> actualizar(Recordatorio r) async {
    await _db.from('recordatorios').update(r.aMapa()).eq('id', r.id!);
  }

  @override
  Future<void> eliminar(String id) async {
    await _db.from('recordatorios').update({'activo': false}).eq('id', id);
  }
}

class SupabasePerfilRepositorio implements PerfilRepositorio {
  @override
  Future<Perfil> obtener() async {
    final fila =
        await _db.from('perfiles').select().eq('id', _uid()).maybeSingle();
    if (fila != null) return Perfil.desdeMapa(fila);
    // Respaldo: si el trigger no creó el perfil, lo creamos aquí.
    final user = _db.auth.currentUser!;
    final nuevo = await _db
        .from('perfiles')
        .insert({
          'id': user.id,
          'nombre_completo':
              (user.userMetadata?['nombre_completo'] as String?) ??
                  (user.email ?? 'Usuario').split('@').first,
        })
        .select()
        .single();
    return Perfil.desdeMapa(nuevo);
  }

  @override
  Future<void> actualizar(Perfil perfil) async {
    await _db.from('perfiles').update(perfil.aMapaEdicion()).eq('id', _uid());
  }
}
