import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saludcerca/core/errores.dart';
import 'package:saludcerca/models/centro_salud.dart';
import 'package:saludcerca/models/clima.dart';
import 'package:saludcerca/models/farmacia.dart';
import 'package:saludcerca/services/api_cliente.dart';
import 'package:saludcerca/services/clima_servicio.dart';
import 'package:saludcerca/services/geocodificacion_servicio.dart';
import 'package:saludcerca/services/ubicacion_servicio.dart';

import 'fakes.dart';

/// Pruebas unitarias del Sprint 3: consumo de APIs (Open-Meteo, Nominatim),
/// manejo de errores HTTP y modelos de farmacias de turno y ubicación.

// Respuesta real de Open-Meteo (23/11/2026, Plaza Murillo), recortada.
const _jsonOpenMeteo = '''
{"latitude":-16.55536,"longitude":-68.12201,"timezone":"America/La_Paz",
 "current":{"time":"2026-11-23T10:45","interval":900,"temperature_2m":20.2,
  "apparent_temperature":18.8,"relative_humidity_2m":12,"precipitation":0.00,
  "weather_code":3,"wind_speed_10m":9.7,"is_day":1},
 "daily":{"time":["2026-11-23"],"uv_index_max":[11.10],"temperature_2m_min":[7.7],
  "temperature_2m_max":[22.3],"precipitation_probability_max":[18]}}
''';

// Respuesta real de Nominatim /search para "Plaza Avaroa", recortada.
const _jsonBusqueda = '''
[{"place_id":4148332,"lat":"-16.5103129","lon":"-68.1267271","name":"Plaza Abaroa",
  "display_name":"Plaza Abaroa, Kantutani, Sopocachi, Cotahuma, Municipio Nuestra Señora de La Paz, La Paz, Bolivia"}]
''';

// Respuesta real de Nominatim /reverse, recortada.
const _jsonInversa = '''
{"display_name":"Calle Belisario Salinas, Kantutani, Sopocachi, La Paz, Bolivia",
 "address":{"road":"Calle Belisario Salinas","neighbourhood":"Kantutani","quarter":"Sopocachi",
  "suburb":"Cotahuma","city":"Municipio Nuestra Señora de La Paz","country":"Bolivia"}}
''';

ApiCliente clienteCon(MockClientHandler h,
        {Duration tiempo = const Duration(seconds: 5)}) =>
    ApiCliente(cliente: MockClient(h), tiempoMaximo: tiempo);

http.Response json(String cuerpo, [int codigo = 200]) =>
    http.Response.bytes(utf8.encode(cuerpo), codigo,
        headers: {'content-type': 'application/json; charset=utf-8'});

Future<ApiException> errorDe(Future<Object?> f) async {
  try {
    await f;
  } on ApiException catch (e) {
    return e;
  }
  fail('Se esperaba ApiException');
}

void main() {
  final uri = Uri.parse('https://api.ejemplo.com/datos');

  group('ApiCliente: HTTPS, timeout y códigos HTTP', () {
    test('200 con JSON válido devuelve los datos y envía User-Agent', () async {
      late http.Request enviada;
      final api = clienteCon((r) async {
        enviada = r;
        return json('{"ok": true}');
      });
      expect(await api.getJson(uri, servicio: 'prueba'), {'ok': true});
      expect(enviada.headers['User-Agent'], contains('SaludCerca'));
      expect(enviada.headers['Accept'], 'application/json');
    });

    test('rechaza URLs que no son HTTPS', () {
      final api = clienteCon((_) async => json('{}'));
      expect(() => api.getJson(Uri.parse('http://inseguro.com'), servicio: 'x'),
          throwsArgumentError);
    });

    final casos = {
      404: TipoErrorApi.noEncontrado,
      429: TipoErrorApi.limiteSolicitudes,
      500: TipoErrorApi.servidor,
      503: TipoErrorApi.servidor,
      400: TipoErrorApi.respuestaHttp,
      403: TipoErrorApi.respuestaHttp,
    };
    casos.forEach((codigo, tipo) {
      test('HTTP $codigo -> $tipo', () async {
        final api = clienteCon((_) async => json('{"error":true}', codigo));
        final e = await errorDe(api.getJson(uri, servicio: 'el clima'));
        expect(e.tipo, tipo);
        expect(e.codigoHttp, codigo);
        expect(e.mensaje, isNotEmpty);
      });
    });

    test('JSON mal formado -> formatoInvalido', () async {
      final api = clienteCon((_) async => json('<html>no es json</html>'));
      final e = await errorDe(api.getJson(uri, servicio: 'el clima'));
      expect(e.tipo, TipoErrorApi.formatoInvalido);
    });

    test('sin conexión -> sinConexion', () async {
      final api = clienteCon(
          (_) async => throw http.ClientException('Failed host lookup'));
      final e = await errorDe(api.getJson(uri, servicio: 'el clima'));
      expect(e.tipo, TipoErrorApi.sinConexion);
      expect(mensajeError(e), startsWith('Sin conexión a internet'));
    });

    test('respuesta lenta -> tiempoAgotado', () async {
      final api = clienteCon((_) async {
        await Future.delayed(const Duration(milliseconds: 300));
        return json('{}');
      }, tiempo: const Duration(milliseconds: 50));
      final e = await errorDe(api.getJson(uri, servicio: 'el clima'));
      expect(e.tipo, TipoErrorApi.tiempoAgotado);
    });
  });

  group('Open-Meteo (clima)', () {
    test('construye la URL con HTTPS, coordenadas y zona horaria', () {
      final u = OpenMeteoClimaServicio.construirUri(Ubicacion.referencia);
      expect(u.scheme, 'https');
      expect(u.host, 'api.open-meteo.com');
      expect(u.queryParameters['latitude'], '-16.4958');
      expect(u.queryParameters['timezone'], 'America/La_Paz');
      expect(u.queryParameters['current'], contains('weather_code'));
    });

    test('convierte la respuesta real y genera avisos de salud', () async {
      final s =
          OpenMeteoClimaServicio(clienteCon((_) async => json(_jsonOpenMeteo)));
      final c = await s.actual(Ubicacion.referencia);
      expect(c.temperatura, 20.2);
      expect(c.humedad, 12);
      expect(c.descripcion, 'Nublado');
      expect(c.uvMaximo, 11.1);
      expect(c.avisos.map((a) => a.tipo), [TipoAviso.uv]);
      expect(c.avisos.first.titulo, contains('muy alta'));
    });

    test('usa caché: no repite la consulta en 15 minutos', () async {
      var llamadas = 0;
      final s = OpenMeteoClimaServicio(clienteCon((_) async {
        llamadas++;
        return json(_jsonOpenMeteo);
      }));
      await s.actual(Ubicacion.referencia);
      await s.actual(const Ubicacion(-16.4960, -68.1340)); // a ~50 m
      expect(llamadas, 1);
    });

    test('JSON con campos faltantes -> formatoInvalido', () async {
      final s = OpenMeteoClimaServicio(
          clienteCon((_) async => json('{"current":{"time":"x"}}')));
      final e = await errorDe(s.actual(Ubicacion.referencia));
      expect(e.tipo, TipoErrorApi.formatoInvalido);
    });

    test('avisos de frío y lluvia', () {
      final c = climaPrueba(uv: 2, minima: -1, lluvia: 80);
      expect(c.avisos.map((a) => a.tipo), [TipoAviso.frio, TipoAviso.lluvia]);
      expect(climaPrueba(uv: 3, minima: 8, lluvia: 10).avisos, isEmpty);
    });
  });

  group('Nominatim (geocodificación)', () {
    test('búsqueda limitada a La Paz y El Alto', () {
      final u = NominatimServicio.uriBusqueda('Plaza Avaroa');
      expect(u.scheme, 'https');
      expect(u.queryParameters['countrycodes'], 'bo');
      expect(u.queryParameters['bounded'], '1');
      expect(u.queryParameters['format'], 'jsonv2');
    });

    test('convierte resultados de búsqueda (lat/lon llegan como texto)',
        () async {
      final s = NominatimServicio(clienteCon((_) async => json(_jsonBusqueda)),
          limitador: LimitadorSolicitudes(Duration.zero));
      final r = await s.buscar('Plaza Avaroa');
      expect(r, hasLength(1));
      expect(r.first.nombre, 'Plaza Abaroa');
      expect(r.first.ubicacion.lat, closeTo(-16.5103, 0.0001));
    });

    test('dirección inversa legible', () async {
      final s = NominatimServicio(clienteCon((_) async => json(_jsonInversa)),
          limitador: LimitadorSolicitudes(Duration.zero));
      expect(await s.direccionDe(ubicacionGpsPrueba),
          'Calle Belisario Salinas, Sopocachi, La Paz');
    });

    test('"Unable to geocode" devuelve null sin error', () async {
      final s = NominatimServicio(
          clienteCon((_) async => json('{"error":"Unable to geocode"}')),
          limitador: LimitadorSolicitudes(Duration.zero));
      expect(await s.direccionDe(const Ubicacion(0, 0)), isNull);
    });

    test('resultado con lat no numérica -> formatoInvalido', () async {
      final s = NominatimServicio(
          clienteCon((_) async =>
              json('[{"lat":"abc","lon":"1","display_name":"x"}]')),
          limitador: LimitadorSolicitudes(Duration.zero));
      final e = await errorDe(s.buscar('algo'));
      expect(e.tipo, TipoErrorApi.formatoInvalido);
    });

    test('textos de menos de 3 letras no consultan la API', () async {
      var llamadas = 0;
      final s = NominatimServicio(clienteCon((_) async {
        llamadas++;
        return json('[]');
      }));
      expect(await s.buscar('ab'), isEmpty);
      expect(llamadas, 0);
    });

    test('respeta 1 solicitud por intervalo (política de uso)', () async {
      final limitador = LimitadorSolicitudes(const Duration(milliseconds: 200));
      final horas = <DateTime>[];
      await Future.wait([
        for (var i = 0; i < 3; i++)
          limitador.ejecutar(() async => horas.add(DateTime.now())),
      ]);
      expect(horas[1].difference(horas[0]).inMilliseconds,
          greaterThanOrEqualTo(190));
      expect(horas[2].difference(horas[1]).inMilliseconds,
          greaterThanOrEqualTo(190));
    });
  });

  group('HU-13 ubicación', () {
    test('GPS dentro de La Paz / El Alto se usa', () {
      final r = evaluarPosicion(ubicacionGpsPrueba);
      expect(r.esGps, isTrue);
      expect(r.ubicacion, ubicacionGpsPrueba);
    });

    test('GPS fuera de cobertura usa Plaza Murillo y explica el motivo', () {
      final r = evaluarPosicion(const Ubicacion(37.42, -122.08)); // California
      expect(r.esGps, isFalse);
      expect(r.ubicacion, Ubicacion.referencia);
      expect(r.motivo, contains('fuera'));
    });

    test('ordena por cercanía al usuario', () {
      final lista = [
        farmaciaPrueba('a', 'Lejana', lat: -16.60),
        farmaciaPrueba('b', 'Cercana', lat: -16.51, lng: -68.127),
      ];
      final r = ordenarPorCercania(
          lista, ubicacionGpsPrueba, (Farmacia f) => f.ubicacion);
      expect(r.first.nombre, 'Cercana');
      expect(formatearDistancia(0.65), '650 m');
      expect(formatearDistancia(2.43), '2,4 km');
    });
  });

  group('HU-03 farmacias de turno', () {
    final fila = {
      'id': 't1',
      'fecha': '2026-11-23',
      'hora_inicio': '08:00:00',
      'hora_fin': '08:00:00',
      'farmacias': {
        'id': 'f1',
        'nombre': 'Farmacia San Pedro',
        'ciudad': 'La Paz',
        'zona': 'San Pedro',
        'direccion': 'Calle Colombia',
        'telefono': '2-100-0001',
        'latitud': -16.5005,
        'longitud': -68.136,
      },
    };

    test('se convierte desde la respuesta de PostgREST', () {
      final t = TurnoFarmacia.desdeMapa(fila);
      expect(t.farmacia.nombre, 'Farmacia San Pedro');
      expect(t.horaInicio, '08:00');
      expect(t.inicio, DateTime(2026, 11, 23, 8));
      expect(t.fin, DateTime(2026, 11, 24, 8));
    });

    test('vigencia del turno de 24 horas', () {
      final t = TurnoFarmacia.desdeMapa(fila);
      expect(t.vigenteEn(DateTime(2026, 11, 23, 7, 59)), isFalse);
      expect(t.vigenteEn(DateTime(2026, 11, 23, 8)), isTrue);
      expect(t.vigenteEn(DateTime(2026, 11, 24, 3)), isTrue); // madrugada
      expect(t.vigenteEn(DateTime(2026, 11, 24, 8)), isFalse);
      expect(t.horarioTexto(DateTime(2026, 11, 23, 12)),
          'De hoy 08:00 a mañana 08:00');
    });

    test('antes de las 08:00 sigue el turno del día anterior', () {
      expect(
          fechaTurnoVigente(DateTime(2026, 11, 23, 3)), DateTime(2026, 11, 22));
      expect(
          fechaTurnoVigente(DateTime(2026, 11, 23, 9)), DateTime(2026, 11, 23));
      expect(fechaTurnoVigente(DateTime(2026, 12, 1, 2)),
          DateTime(2026, 11, 30)); // cambio de mes
    });

    test('turno sin farmacia embebida es un formato inválido', () {
      expect(() => TurnoFarmacia.desdeMapa({...fila, 'farmacias': null}),
          throwsFormatException);
    });
  });
}
