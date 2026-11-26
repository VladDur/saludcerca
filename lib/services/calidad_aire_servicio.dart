import '../models/calidad_aire.dart';
import '../models/centro_salud.dart';
import 'api_cliente.dart';

/// Contrato del servicio de calidad del aire (las pruebas usan uno falso).
abstract class CalidadAireServicio {
  Future<CalidadAire> actual(Ubicacion ubicacion);
}

/// Calidad del aire con la API pública Air Quality de Open-Meteo
/// (HTTPS, GET, sin clave). Documentación:
/// https://open-meteo.com/en/docs/air-quality-api
class OpenMeteoCalidadAireServicio implements CalidadAireServicio {
  static const urlBase =
      'https://air-quality-api.open-meteo.com/v1/air-quality';
  static const _servicio = 'la calidad del aire';

  final ApiCliente _api;
  final String _urlBase;
  final Duration vigencia;

  // Caché simple: el dato se actualiza cada hora en la API.
  CalidadAire? _ultima;
  Ubicacion? _ultimaUbicacion;
  DateTime? _cuando;

  OpenMeteoCalidadAireServicio(this._api,
      {String urlBase = urlBase, this.vigencia = const Duration(minutes: 30)})
      : _urlBase = urlBase;

  static Uri construirUri(Ubicacion u, {String base = urlBase}) =>
      Uri.parse(base).replace(queryParameters: {
        'latitude': u.lat.toStringAsFixed(4),
        'longitude': u.lng.toStringAsFixed(4),
        'current': 'pm2_5,pm10,us_aqi,uv_index',
        'timezone': 'America/La_Paz',
      });

  @override
  Future<CalidadAire> actual(Ubicacion ubicacion) async {
    final c = _ultima;
    if (c != null &&
        _ultimaUbicacion != null &&
        _ultimaUbicacion!.distanciaKm(ubicacion) < 2 &&
        DateTime.now().difference(_cuando!) < vigencia) {
      return c;
    }
    final json = await _api.getJson(construirUri(ubicacion, base: _urlBase),
        servicio: _servicio);
    final CalidadAire aire;
    try {
      aire = CalidadAire.desdeOpenMeteo(json);
    } on FormatException catch (e) {
      throw ApiException(TipoErrorApi.formatoInvalido, _servicio,
          detalle: e.message);
    }
    _ultima = aire;
    _ultimaUbicacion = ubicacion;
    _cuando = DateTime.now();
    return aire;
  }
}
