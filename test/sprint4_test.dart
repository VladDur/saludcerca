import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saludcerca/core/errores.dart';
import 'package:saludcerca/models/calidad_aire.dart';
import 'package:saludcerca/models/centro_salud.dart';
import 'package:saludcerca/services/api_cliente.dart';
import 'package:saludcerca/services/calidad_aire_servicio.dart';
import 'package:saludcerca/services/voz_servicio.dart';

/// HU-17 · Pruebas unitarias del Sprint 4: API de calidad del aire
/// (Open-Meteo Air Quality) con errores simulados, consejos de salud (HU-15)
/// y utilidades del dictado por voz.

// Respuesta real de Open-Meteo Air Quality (26/11/2026, La Paz).
const _jsonAire = '''
{"latitude":-16.5,"longitude":-68.1,"generationtime_ms":0.19,"utc_offset_seconds":-14400,
 "timezone":"America/La_Paz","timezone_abbreviation":"GMT-4","elevation":3645.0,
 "current_units":{"time":"iso8601","interval":"seconds","pm2_5":"μg/m³","pm10":"μg/m³","us_aqi":"USAQI","uv_index":""},
 "current":{"time":"2026-11-26T11:00","interval":3600,"pm2_5":1.6,"pm10":1.7,"us_aqi":18,"uv_index":3.70}}
''';

const _plazaMurillo = Ubicacion(-16.4955, -68.1336);

http.Response _json(String cuerpo, [int codigo = 200]) =>
    http.Response.bytes(utf8.encode(cuerpo), codigo,
        headers: {'content-type': 'application/json; charset=utf-8'});

OpenMeteoCalidadAireServicio _servicio(MockClientHandler h,
        {Duration tiempo = const Duration(seconds: 5)}) =>
    OpenMeteoCalidadAireServicio(
        ApiCliente(cliente: MockClient(h), tiempoMaximo: tiempo));

Future<ApiException> _errorDe(Future<Object?> f) async {
  try {
    await f;
  } on ApiException catch (e) {
    return e;
  }
  fail('Se esperaba ApiException');
}

Map<String, Object?> _actual(Map<String, Object?> campos) => {
      'current': {
        'time': '2026-11-26T11:00',
        'pm2_5': 10.0,
        'pm10': 20.0,
        'us_aqi': 40,
        'uv_index': 1.0,
        ...campos,
      }
    };

void main() {
  group('Servicio de calidad del aire (Open-Meteo Air Quality)', () {
    test('construye la URL HTTPS con coordenadas, variables y zona horaria',
        () {
      final u = OpenMeteoCalidadAireServicio.construirUri(_plazaMurillo);
      expect(u.scheme, 'https');
      expect(u.host, 'air-quality-api.open-meteo.com');
      expect(u.path, '/v1/air-quality');
      expect(u.queryParameters['latitude'], '-16.4955');
      expect(u.queryParameters['longitude'], '-68.1336');
      expect(u.queryParameters['current'], 'pm2_5,pm10,us_aqi,uv_index');
      expect(u.queryParameters['timezone'], 'America/La_Paz');
    });

    test('200: convierte la respuesta real y envía GET con User-Agent',
        () async {
      late http.Request enviada;
      final s = _servicio((r) async {
        enviada = r;
        return _json(_jsonAire);
      });
      final a = await s.actual(_plazaMurillo);
      expect(enviada.method, 'GET');
      expect(enviada.headers['User-Agent'], contains('SaludCerca'));
      expect(a.pm25, 1.6);
      expect(a.pm10, 1.7);
      expect(a.indice, 18);
      expect(a.uv, closeTo(3.7, 0.001));
      expect(a.hora, DateTime(2026, 11, 26, 11));
      expect(a.nivel, NivelAire.bueno);
    });

    test('usa caché: no repite la consulta para el mismo lugar', () async {
      var llamadas = 0;
      final s = _servicio((_) async {
        llamadas++;
        return _json(_jsonAire);
      });
      await s.actual(_plazaMurillo);
      await s.actual(const Ubicacion(-16.4960, -68.1340)); // a pocos metros
      expect(llamadas, 1);
      await s.actual(const Ubicacion(-16.5200, -68.1800)); // El Alto
      expect(llamadas, 2);
    });

    for (final (codigo, tipo, texto) in [
      (429, TipoErrorApi.limiteSolicitudes, 'muchas consultas'),
      (500, TipoErrorApi.servidor, '(error 500)'),
      (503, TipoErrorApi.servidor, '(error 503)'),
      (400, TipoErrorApi.respuestaHttp, '(400)'),
    ]) {
      test('HTTP $codigo simulado -> $tipo con mensaje claro', () async {
        final s = _servicio(
            (_) async => _json('{"error":true,"reason":"simulado"}', codigo));
        final e = await _errorDe(s.actual(_plazaMurillo));
        expect(e.tipo, tipo);
        expect(e.codigoHttp, codigo);
        expect(mensajeError(e), contains(texto));
      });
    }

    test('sin internet (SocketException) -> sinConexion', () async {
      final s = _servicio(
          (_) async => throw const SocketException('Network is unreachable'));
      final e = await _errorDe(s.actual(_plazaMurillo));
      expect(e.tipo, TipoErrorApi.sinConexion);
      expect(e.mensaje,
          'Sin conexión a internet. No pudimos cargar la calidad del aire.');
    });

    test('respuesta lenta -> tiempoAgotado', () async {
      final s = _servicio((_) async {
        await Future.delayed(const Duration(milliseconds: 300));
        return _json(_jsonAire);
      }, tiempo: const Duration(milliseconds: 50));
      final e = await _errorDe(s.actual(_plazaMurillo));
      expect(e.tipo, TipoErrorApi.tiempoAgotado);
      expect(e.mensaje, contains('de la calidad del aire tardó demasiado'));
    });

    test('JSON mal formado -> formatoInvalido', () async {
      final s = _servicio((_) async => _json('<html>error</html>'));
      final e = await _errorDe(s.actual(_plazaMurillo));
      expect(e.tipo, TipoErrorApi.formatoInvalido);
    });

    test('JSON sin us_aqi -> formatoInvalido (no se guarda en caché)',
        () async {
      var llamadas = 0;
      final s = _servicio((_) async {
        llamadas++;
        return _json('{"current":{"time":"2026-11-26T11:00","pm2_5":3}}');
      });
      final e = await _errorDe(s.actual(_plazaMurillo));
      expect(e.tipo, TipoErrorApi.formatoInvalido);
      await _errorDe(s.actual(_plazaMurillo));
      expect(llamadas, 2);
    });

    test('después de un error, un nuevo intento puede funcionar', () async {
      var primera = true;
      final s = _servicio((_) async {
        if (primera) {
          primera = false;
          return _json('{}', 503);
        }
        return _json(_jsonAire);
      });
      await _errorDe(s.actual(_plazaMurillo));
      expect((await s.actual(_plazaMurillo)).indice, 18);
    });
  });

  group('Modelo CalidadAire y consejos (HU-15)', () {
    test('pm10 y uv_index pueden venir en null', () {
      final a =
          CalidadAire.desdeOpenMeteo(_actual({'pm10': null, 'uv_index': null}));
      expect(a.pm10, isNull);
      expect(a.uv, isNull);
      expect(a.consejos, hasLength(1)); // solo el del aire
    });

    test('campos con tipo incorrecto lanzan FormatException', () {
      expect(() => CalidadAire.desdeOpenMeteo(_actual({'pm2_5': 'alto'})),
          throwsFormatException);
      expect(() => CalidadAire.desdeOpenMeteo(_actual({'uv_index': 'x'})),
          throwsFormatException);
      expect(() => CalidadAire.desdeOpenMeteo(_actual({'time': 'ayer'})),
          throwsFormatException);
      expect(() => CalidadAire.desdeOpenMeteo(_actual({'us_aqi': -1})),
          throwsFormatException);
      expect(() => CalidadAire.desdeOpenMeteo([]), throwsFormatException);
    });

    test('niveles del índice US AQI en sus límites', () {
      expect(NivelAire.deIndice(0), NivelAire.bueno);
      expect(NivelAire.deIndice(50), NivelAire.bueno);
      expect(NivelAire.deIndice(51), NivelAire.moderado);
      expect(NivelAire.deIndice(100), NivelAire.moderado);
      expect(NivelAire.deIndice(101), NivelAire.sensibles);
      expect(NivelAire.deIndice(151), NivelAire.danino);
      expect(NivelAire.deIndice(201), NivelAire.muyDanino);
      expect(NivelAire.deIndice(301), NivelAire.peligroso);
      expect(NivelAire.deIndice(500), NivelAire.peligroso);
    });

    CalidadAire aire(int indice, {double? uv}) => CalidadAire(
        pm25: 5, pm10: 8, indice: indice, uv: uv, hora: DateTime(2026));

    test('color (gravedad) según el nivel', () {
      expect(aire(30).gravedad, Gravedad.buena);
      expect(aire(80).gravedad, Gravedad.atencion);
      expect(aire(120).gravedad, Gravedad.atencion);
      expect(aire(160).gravedad, Gravedad.alerta);
      expect(aire(350).gravedad, Gravedad.alerta);
    });

    test('consejo del aire pensado para adultos mayores', () {
      expect(aire(20).consejos.first.titulo, 'Aire limpio');
      expect(aire(120).consejos.first.titulo, 'Cuidado si eres adulto mayor');
      expect(aire(160).consejos.first.texto, contains('barbijo'));
      expect(aire(250).consejos.first.texto, contains('centro de salud'));
    });

    test('consejos por radiación UV de la altura', () {
      expect(aire(20, uv: 1).consejos, hasLength(1));
      final moderado = aire(20, uv: 3.7).consejos.last;
      expect(moderado.tipo, TipoConsejo.uv);
      expect(moderado.titulo, 'Sol moderado (UV 4)');
      expect(aire(20, uv: 6).consejos.last.gravedad, Gravedad.atencion);
      final extremo = aire(20, uv: 11.2).consejos.last;
      expect(extremo.gravedad, Gravedad.alerta);
      expect(extremo.titulo, 'Sol muy fuerte ahora (UV 11)');
    });

    test('formato de microgramos', () {
      expect(CalidadAire.microgramos(1.6), '1.6 µg/m³');
    });
  });

  group('Dictado por voz', () {
    test('el texto dictado se convierte en un título válido', () {
      expect(textoDictadoComoTitulo('sacar ficha en hospital Miraflores'),
          'Sacar ficha en hospital Miraflores');
      expect(textoDictadoComoTitulo('  tomar   la pastilla. '),
          'Tomar la pastilla');
      expect(textoDictadoComoTitulo(''), '');
      final largo = textoDictadoComoTitulo('a' * 100);
      expect(largo.length, 60);
    });

    test('códigos de error de Android e iOS se traducen', () {
      expect(VozException.desdeCodigo('error_permission').tipo,
          TipoErrorVoz.permisoDenegado);
      expect(VozException.desdeCodigo('error_insufficient_permissions').tipo,
          TipoErrorVoz.permisoDenegado);
      expect(VozException.desdeCodigo('error_network').tipo,
          TipoErrorVoz.sinConexion);
      expect(VozException.desdeCodigo('error_server_disconnected').tipo,
          TipoErrorVoz.sinConexion);
      expect(VozException.desdeCodigo('error_no_match').tipo,
          TipoErrorVoz.noEntendio);
      expect(VozException.desdeCodigo('error_speech_timeout').tipo,
          TipoErrorVoz.noEntendio);
      expect(VozException.desdeCodigo('error_audio_error').tipo,
          TipoErrorVoz.otro);
    });

    test('cada falla tiene un mensaje en español', () {
      for (final t in TipoErrorVoz.values) {
        expect(VozException(t).mensaje, isNotEmpty);
      }
      expect(const VozException(TipoErrorVoz.permisoDenegado).mensaje,
          contains('micrófono'));
    });
  });
}
