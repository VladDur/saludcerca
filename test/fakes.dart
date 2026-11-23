import 'dart:async';

import 'package:saludcerca/core/app_scope.dart';
import 'package:saludcerca/data/repositorios.dart';
import 'package:saludcerca/models/centro_salud.dart';
import 'package:saludcerca/models/clima.dart';
import 'package:saludcerca/models/farmacia.dart';
import 'package:saludcerca/models/favorito.dart';
import 'package:saludcerca/models/perfil.dart';
import 'package:saludcerca/models/recordatorio.dart';
import 'package:saludcerca/services/api_cliente.dart';
import 'package:saludcerca/services/clima_servicio.dart';
import 'package:saludcerca/services/geocodificacion_servicio.dart';
import 'package:saludcerca/services/ubicacion_servicio.dart';
import 'package:saludcerca/settings/ajustes_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

/// Repositorios en memoria para probar la app sin conexión a Supabase.

const correoPrueba = 'prueba@saludcerca.app';
const clavePrueba = 'Prueba123';

CentroSalud centroPrueba(String id, String nombre,
        {String ciudad = 'La Paz',
        bool emergencias = false,
        bool veinticuatro = true,
        double lat = -16.50}) =>
    CentroSalud(
      id: id,
      nombre: nombre,
      tipo: emergencias ? TipoCentro.hospital : TipoCentro.centroSalud,
      ciudad: ciudad,
      zona: 'Zona $id',
      direccion: 'Calle $id',
      telefono: '2-000-000$id',
      ubicacion: Ubicacion(lat, -68.13),
      abierto24h: veinticuatro,
      horaApertura: veinticuatro ? null : '08:00',
      horaCierre: veinticuatro ? null : '16:00',
      diasAtencion: const [1, 2, 3, 4, 5],
      atiendeEmergencias: emergencias,
      servicios: const ['Medicina general', 'Vacunas'],
      descripcion: 'Descripción $nombre',
    );

class FakeAuth implements AuthRepositorio {
  final _ctrl = StreamController<UsuarioActual?>.broadcast();
  UsuarioActual? _usuario;

  FakeAuth({bool conSesion = false}) {
    if (conSesion) {
      _usuario = const UsuarioActual(id: 'u1', correo: correoPrueba);
    }
  }

  @override
  UsuarioActual? get usuarioActual => _usuario;

  @override
  Stream<UsuarioActual?> get cambios => _ctrl.stream;

  @override
  Future<void> iniciarSesion(String correo, String clave) async {
    if (correo.trim() != correoPrueba || clave != clavePrueba) {
      throw const AuthException('Invalid login credentials');
    }
    _usuario = const UsuarioActual(id: 'u1', correo: correoPrueba);
    _ctrl.add(_usuario);
  }

  @override
  Future<ResultadoRegistro> registrar(
      {required String nombre,
      required String correo,
      required String clave}) async {
    if (correo.trim() == correoPrueba) {
      throw const AuthException('User already registered');
    }
    _usuario = UsuarioActual(id: 'u2', correo: correo.trim());
    _ctrl.add(_usuario);
    return ResultadoRegistro.sesionIniciada;
  }

  @override
  Future<void> cerrarSesion() async {
    _usuario = null;
    _ctrl.add(null);
  }
}

class FakeCentros implements CentrosRepositorio {
  final centros = [
    centroPrueba('1', 'Centro Uno', lat: -16.49),
    centroPrueba('2', 'Hospital Dos', emergencias: true, lat: -16.52),
    centroPrueba('3', 'Posta Tres', ciudad: 'El Alto', lat: -16.55),
  ];

  @override
  Future<List<CentroSalud>> buscar(FiltroCentros f) async {
    final t = f.texto.toLowerCase();
    return centros
        .where((c) =>
            (t.isEmpty ||
                c.nombre.toLowerCase().contains(t) ||
                c.zona.toLowerCase().contains(t)) &&
            (f.ciudad == null || c.ciudad == f.ciudad) &&
            (f.tipo == null || c.tipo == f.tipo) &&
            (!f.soloEmergencias || c.atiendeEmergencias))
        .toList();
  }

  @override
  Future<CentroSalud?> porId(String id) async =>
      centros.where((c) => c.id == id).firstOrNull;
}

class _FilaFavorito {
  final String id, centroId;
  String nota;
  bool activo = true;
  _FilaFavorito(this.id, this.centroId, this.nota);
}

class FakeFavoritos implements FavoritosRepositorio {
  final FakeCentros centros;
  final filas = <_FilaFavorito>[];
  FakeFavoritos(this.centros);

  @override
  Future<List<Favorito>> listar() async => [
        for (final f in filas.where((f) => f.activo))
          Favorito(
              id: f.id,
              centroId: f.centroId,
              nota: f.nota,
              centro: await centros.porId(f.centroId)),
      ];

  @override
  Future<Favorito?> buscarPorCentro(String centroId) async {
    final f =
        filas.where((f) => f.activo && f.centroId == centroId).firstOrNull;
    return f == null
        ? null
        : Favorito(id: f.id, centroId: f.centroId, nota: f.nota);
  }

  @override
  Future<void> agregar(String centroId, {String nota = ''}) async {
    final existente = filas.where((f) => f.centroId == centroId).firstOrNull;
    if (existente != null) {
      existente
        ..activo = true
        ..nota = nota;
    } else {
      filas.add(_FilaFavorito('f${filas.length + 1}', centroId, nota));
    }
  }

  @override
  Future<void> actualizarNota(String favoritoId, String nota) async =>
      filas.firstWhere((f) => f.id == favoritoId).nota = nota;

  @override
  Future<void> quitar(String favoritoId) async =>
      filas.firstWhere((f) => f.id == favoritoId).activo = false;
}

class FakeRecordatorios implements RecordatoriosRepositorio {
  final filas = <String, (Recordatorio, bool)>{}; // id -> (dato, activo)
  int _n = 0;

  @override
  Future<List<Recordatorio>> listar({bool incluirPasados = false}) async =>
      filas.values
          .where((e) => e.$2 && (incluirPasados || !e.$1.vencido))
          .map((e) => e.$1)
          .toList()
        ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));

  @override
  Future<void> crear(Recordatorio r) async {
    final id = 'r${++_n}';
    filas[id] = (_conId(r, id), true);
  }

  @override
  Future<void> actualizar(Recordatorio r) async => filas[r.id!] = (r, true);

  @override
  Future<void> eliminar(String id) async => filas[id] = (filas[id]!.$1, false);

  Recordatorio _conId(Recordatorio r, String id) => Recordatorio(
        id: id,
        titulo: r.titulo.trim(),
        descripcion: r.descripcion,
        tipo: r.tipo,
        fechaHora: r.fechaHora,
        centroId: r.centroId,
      );
}

class FakePerfil implements PerfilRepositorio {
  Perfil perfil = const Perfil(id: 'u1', nombreCompleto: 'Ana Pérez');

  @override
  Future<Perfil> obtener() async => perfil;

  @override
  Future<void> actualizar(Perfil p) async => perfil = p;
}

Future<Dependencias> crearDependencias({
  bool conSesion = false,
  Map<String, Object> prefs = const {},
  FakeFarmacias? farmacias,
  FakeClima? clima,
  FakeGeocodificacion? geocodificacion,
  FakeUbicacion? ubicacion,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final centros = FakeCentros();
  return Dependencias(
    auth: FakeAuth(conSesion: conSesion),
    centros: centros,
    favoritos: FakeFavoritos(centros),
    recordatorios: FakeRecordatorios(),
    perfil: FakePerfil(),
    farmacias: farmacias ?? FakeFarmacias(),
    ajustes: await AjustesController.cargar(),
    clima: clima ?? FakeClima(),
    geocodificacion: geocodificacion ?? FakeGeocodificacion(),
    ubicacion: ubicacion ?? FakeUbicacion(),
  );
}

// ---------------- Sprint 3 ----------------

/// Sopocachi, a ~1,7 km de Plaza Murillo.
const ubicacionGpsPrueba = Ubicacion(-16.5100, -68.1270);

Farmacia farmaciaPrueba(String id, String nombre,
        {String ciudad = 'La Paz', double lat = -16.50, double lng = -68.13}) =>
    Farmacia(
      id: id,
      nombre: nombre,
      ciudad: ciudad,
      zona: 'Zona $id',
      direccion: 'Calle $id',
      telefono: '2-100-000$id',
      ubicacion: Ubicacion(lat, lng),
    );

class FakeFarmacias implements FarmaciasRepositorio {
  Object? error;
  DateTime? ultimaFecha;
  final farmacias = [
    farmaciaPrueba('f1', 'Farmacia Lejana', lat: -16.53),
    farmaciaPrueba('f2', 'Farmacia Cercana', lat: -16.5105, lng: -68.1268),
    farmaciaPrueba('f3', 'Farmacia Alteña',
        ciudad: 'El Alto', lat: -16.50, lng: -68.17),
  ];

  @override
  Future<List<TurnoFarmacia>> deTurno(DateTime fecha, {String? ciudad}) async {
    ultimaFecha = fecha;
    if (error != null) throw error!;
    return [
      for (final f in farmacias)
        if (ciudad == null || f.ciudad == ciudad)
          TurnoFarmacia(
              id: 't${f.id}',
              fecha: DateTime(fecha.year, fecha.month, fecha.day),
              horaInicio: '08:00',
              horaFin: '08:00',
              farmacia: f),
    ];
  }
}

Clima climaPrueba({double uv = 11, double minima = 1, int lluvia = 70}) =>
    Clima(
      temperatura: 14,
      sensacion: 12,
      humedad: 50,
      precipitacion: 0,
      codigoTiempo: 2,
      viento: 10,
      esDeDia: true,
      uvMaximo: uv,
      minima: minima,
      maxima: 17,
      probabilidadLluvia: lluvia,
      hora: DateTime(2026, 11, 23, 10),
    );

class FakeClima implements ClimaServicio {
  Clima clima = climaPrueba(uv: 3, minima: 8, lluvia: 10); // sin avisos
  Object? error;
  int llamadas = 0;

  @override
  Future<Clima> actual(Ubicacion ubicacion) async {
    llamadas++;
    if (error != null) throw error!;
    return clima;
  }
}

class FakeGeocodificacion implements GeocodificacionServicio {
  Object? error;
  final lugares = const [
    LugarEncontrado(
        nombre: 'Plaza Avaroa',
        direccionCompleta: 'Plaza Avaroa, Sopocachi, La Paz, Bolivia',
        ubicacion: Ubicacion(-16.5098, -68.1262)),
  ];

  @override
  Future<List<LugarEncontrado>> buscar(String texto) async {
    if (error != null) throw error!;
    return lugares
        .where((l) =>
            l.direccionCompleta.toLowerCase().contains(texto.toLowerCase()))
        .toList();
  }

  @override
  Future<String?> direccionDe(Ubicacion u) async =>
      error != null ? throw error! : 'Sopocachi, La Paz';
}

class FakeUbicacion implements UbicacionServicio {
  ResultadoUbicacion resultado =
      const ResultadoUbicacion.gps(ubicacionGpsPrueba);
  ResultadoUbicacion? _ultimo;

  @override
  ResultadoUbicacion get ultimaConocida => _ultimo ?? sinConsultar;

  @override
  Future<ResultadoUbicacion> obtener({bool forzar = false}) async =>
      _ultimo = resultado;
}

const errorSinRed = ApiException(TipoErrorApi.sinConexion, 'el clima');
