import 'dart:async';

import '../models/centro_salud.dart';
import 'api_cliente.dart';

/// Lugar encontrado al buscar una dirección.
class LugarEncontrado {
  final String nombre; // texto corto para la lista
  final String direccionCompleta;
  final Ubicacion ubicacion;

  const LugarEncontrado(
      {required this.nombre,
      required this.direccionCompleta,
      required this.ubicacion});

  /// Elemento de la respuesta `jsonv2` de Nominatim (lat y lon llegan como texto).
  factory LugarEncontrado.desdeNominatim(Object? m) {
    final lat = double.tryParse(campo<String>(m, 'lat'));
    final lon = double.tryParse(campo<String>(m, 'lon'));
    if (lat == null || lon == null) {
      throw const FormatException('lat/lon no numéricos');
    }
    final completa = campo<String>(m, 'display_name');
    final nombre = (m as Map)['name'];
    return LugarEncontrado(
      nombre: nombre is String && nombre.isNotEmpty
          ? nombre
          : completa.split(',').first,
      direccionCompleta: completa,
      ubicacion: Ubicacion(lat, lon),
    );
  }
}

abstract class GeocodificacionServicio {
  /// Busca direcciones o lugares en La Paz y El Alto.
  Future<List<LugarEncontrado>> buscar(String texto);

  /// Dirección legible de un punto ("Sopocachi, La Paz"), o null.
  Future<String?> direccionDe(Ubicacion ubicacion);
}

/// Espera lo necesario para no pasar de una solicitud por intervalo.
/// La política de Nominatim permite como máximo 1 solicitud por segundo.
class LimitadorSolicitudes {
  final Duration intervalo;
  DateTime? _ultima;
  Future<void> _cola = Future.value();

  LimitadorSolicitudes([this.intervalo = const Duration(seconds: 1)]);

  Future<T> ejecutar<T>(Future<T> Function() tarea) {
    final resultado = _cola.then((_) async {
      final ultima = _ultima;
      if (ultima != null) {
        final falta = intervalo - DateTime.now().difference(ultima);
        if (falta > Duration.zero) await Future.delayed(falta);
      }
      _ultima = DateTime.now();
      return tarea();
    });
    _cola = resultado.then((_) {}, onError: (_) {});
    return resultado;
  }
}

/// Geocodificación con Nominatim (OpenStreetMap).
/// Política de uso: https://operations.osmfoundation.org/policies/nominatim/
/// - Máximo 1 solicitud por segundo ([LimitadorSolicitudes]).
/// - User-Agent que identifica la app ([ApiCliente.userAgent]).
/// - Resultados en caché para no repetir consultas.
class NominatimServicio implements GeocodificacionServicio {
  static const urlBase = 'https://nominatim.openstreetmap.org';

  /// Rectángulo que cubre La Paz y El Alto (oeste, norte, este, sur).
  static const cajaLaPazElAlto = '-68.30,-16.38,-68.00,-16.62';

  final ApiCliente _api;
  final LimitadorSolicitudes _limitador;
  final _cacheBusqueda = <String, List<LugarEncontrado>>{};
  final _cacheDireccion = <String, String?>{};

  NominatimServicio(this._api, {LimitadorSolicitudes? limitador})
      : _limitador = limitador ?? LimitadorSolicitudes();

  static Uri uriBusqueda(String texto) =>
      Uri.parse('$urlBase/search').replace(queryParameters: {
        'q': texto,
        'format': 'jsonv2',
        'limit': '5',
        'countrycodes': 'bo',
        'viewbox': cajaLaPazElAlto,
        'bounded': '1',
        'accept-language': 'es',
      });

  static Uri uriInversa(Ubicacion u) =>
      Uri.parse('$urlBase/reverse').replace(queryParameters: {
        'lat': u.lat.toStringAsFixed(5),
        'lon': u.lng.toStringAsFixed(5),
        'format': 'jsonv2',
        'zoom': '16',
        'accept-language': 'es',
      });

  @override
  Future<List<LugarEncontrado>> buscar(String texto) async {
    final t = texto.trim();
    if (t.length < 3) return const [];
    final clave = t.toLowerCase();
    final guardado = _cacheBusqueda[clave];
    if (guardado != null) return guardado;

    final json = await _limitador
        .ejecutar(() => _api.getJson(uriBusqueda(t), servicio: 'el mapa'));
    try {
      if (json is! List) throw const FormatException('Se esperaba una lista');
      final lugares = json.map(LugarEncontrado.desdeNominatim).toList();
      return _cacheBusqueda[clave] = lugares;
    } on FormatException catch (e) {
      throw ApiException(TipoErrorApi.formatoInvalido, 'el mapa',
          detalle: e.message);
    }
  }

  @override
  Future<String?> direccionDe(Ubicacion u) async {
    // Se redondea a ~100 m para aprovechar la caché.
    final clave = '${u.lat.toStringAsFixed(3)},${u.lng.toStringAsFixed(3)}';
    if (_cacheDireccion.containsKey(clave)) return _cacheDireccion[clave];
    final json = await _limitador
        .ejecutar(() => _api.getJson(uriInversa(u), servicio: 'el mapa'));
    if (json is! Map) {
      throw const ApiException(TipoErrorApi.formatoInvalido, 'el mapa');
    }
    // Nominatim responde 200 con {"error": "Unable to geocode"} si no hay nada.
    if (json.containsKey('error')) return _cacheDireccion[clave] = null;
    return _cacheDireccion[clave] = resumirDireccion(json);
  }

  /// "Sopocachi, La Paz" a partir del objeto `address` de Nominatim.
  static String? resumirDireccion(Map json) {
    final a = json['address'];
    if (a is! Map) {
      final d = json['display_name'];
      return d is String ? d.split(',').take(2).join(',').trim() : null;
    }
    String? primero(List<String> claves) {
      for (final k in claves) {
        final v = a[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return null;
    }

    final calle = primero(['road', 'pedestrian', 'square']);
    final zona =
        primero(['quarter', 'neighbourhood', 'suburb', 'city_district']);
    var ciudad = primero(['city', 'town', 'village', 'municipality']);
    // "Municipio Nuestra Señora de La Paz" -> "La Paz"
    ciudad = ciudad
        ?.replaceFirst(RegExp(r'^Municipio (de )?'), '')
        .replaceFirst('Nuestra Señora de ', '');
    final partes = [calle, zona, ciudad].whereType<String>().toSet().toList();
    return partes.isEmpty ? null : partes.join(', ');
  }
}
