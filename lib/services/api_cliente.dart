import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Tipos de falla al consumir una API externa.
enum TipoErrorApi {
  sinConexion,
  tiempoAgotado,
  limiteSolicitudes, // HTTP 429
  noEncontrado, // HTTP 404
  servidor, // HTTP 5xx
  respuestaHttp, // otro código fuera de 2xx
  formatoInvalido, // JSON mal formado o con campos inesperados
}

/// Error de una API externa con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  final TipoErrorApi tipo;
  final String servicio; // "clima", "mapa", ...
  final int? codigoHttp;
  final String? detalle; // para registros, no se muestra al usuario

  const ApiException(this.tipo, this.servicio, {this.codigoHttp, this.detalle});

  /// Mensaje en español para la interfaz.
  String get mensaje {
    switch (tipo) {
      case TipoErrorApi.sinConexion:
        return 'Sin conexión a internet. No pudimos cargar $servicio.';
      case TipoErrorApi.tiempoAgotado:
        return 'El servicio de $servicio tardó demasiado en responder. '
            'Intenta otra vez.';
      case TipoErrorApi.limiteSolicitudes:
        return 'Hiciste muchas consultas seguidas. Espera unos segundos.';
      case TipoErrorApi.noEncontrado:
        return 'No encontramos información de $servicio (error 404).';
      case TipoErrorApi.servidor:
        return 'El servicio de $servicio no está disponible ahora '
            '(error $codigoHttp). Intenta más tarde.';
      case TipoErrorApi.respuestaHttp:
        return 'El servicio de $servicio respondió con un error '
            '($codigoHttp).';
      case TipoErrorApi.formatoInvalido:
        return 'Recibimos datos de $servicio que no entendemos. '
            'Intenta más tarde.';
    }
  }

  @override
  String toString() =>
      'ApiException($servicio, $tipo, http=$codigoHttp, $detalle)';
}

/// Cliente HTTP común para las APIs externas (Open-Meteo y Nominatim).
///
/// - Solo acepta HTTPS.
/// - Aplica un tiempo máximo de espera.
/// - Envía un User-Agent que identifica la app (lo exige Nominatim).
/// - Convierte cualquier falla en [ApiException].
/// - Deja un registro de cada solicitud en la consola (método, URL, código
///   HTTP y milisegundos), útil como evidencia.
class ApiCliente {
  static const userAgent =
      'SaludCerca/0.3 (app academica UPDS; https://github.com/VladDur/saludcerca)';

  final http.Client _http;
  final Duration tiempoMaximo;

  ApiCliente(
      {http.Client? cliente, this.tiempoMaximo = const Duration(seconds: 10)})
      : _http = cliente ?? http.Client();

  Future<Object?> getJson(Uri uri, {required String servicio}) async {
    if (uri.scheme != 'https') {
      throw ArgumentError('Solo se permiten URLs HTTPS: $uri');
    }
    final reloj = Stopwatch()..start();
    http.Response r;
    try {
      r = await _http.get(uri, headers: const {
        'User-Agent': userAgent,
        'Accept': 'application/json',
        'Accept-Language': 'es',
      }).timeout(tiempoMaximo);
    } on TimeoutException {
      _registrar(uri, 'TIMEOUT', reloj);
      throw ApiException(TipoErrorApi.tiempoAgotado, servicio,
          detalle: 'más de ${tiempoMaximo.inSeconds} s');
    } on SocketException catch (e) {
      _registrar(uri, 'SIN RED', reloj);
      throw ApiException(TipoErrorApi.sinConexion, servicio,
          detalle: e.message);
    } on http.ClientException catch (e) {
      _registrar(uri, 'SIN RED', reloj);
      throw ApiException(TipoErrorApi.sinConexion, servicio,
          detalle: e.message);
    }
    _registrar(uri, '${r.statusCode}', reloj);

    final c = r.statusCode;
    if (c == 429) {
      throw ApiException(TipoErrorApi.limiteSolicitudes, servicio,
          codigoHttp: c);
    }
    if (c == 404) {
      throw ApiException(TipoErrorApi.noEncontrado, servicio, codigoHttp: c);
    }
    if (c >= 500) {
      throw ApiException(TipoErrorApi.servidor, servicio, codigoHttp: c);
    }
    if (c < 200 || c >= 300) {
      throw ApiException(TipoErrorApi.respuestaHttp, servicio,
          codigoHttp: c, detalle: _recortar(r.body));
    }
    try {
      return jsonDecode(utf8.decode(r.bodyBytes));
    } on FormatException catch (e) {
      throw ApiException(TipoErrorApi.formatoInvalido, servicio,
          codigoHttp: c, detalle: e.message);
    }
  }

  void _registrar(Uri uri, String resultado, Stopwatch reloj) {
    debugPrint('[API] GET ${uri.host}${uri.path} -> $resultado '
        '(${reloj.elapsedMilliseconds} ms)');
  }

  static String _recortar(String s) =>
      s.length > 200 ? '${s.substring(0, 200)}…' : s;
}

/// Lee un campo obligatorio de un JSON; si falta o tiene otro tipo lanza
/// [FormatException] (el servicio la convierte en `formatoInvalido`).
T campo<T>(Object? mapa, String clave) {
  if (mapa is! Map) throw FormatException('Se esperaba un objeto en "$clave"');
  final v = mapa[clave];
  if (T == double && v is num) return v.toDouble() as T;
  if (v is! T) {
    throw FormatException('Campo "$clave" inválido: ${v.runtimeType}');
  }
  return v;
}
