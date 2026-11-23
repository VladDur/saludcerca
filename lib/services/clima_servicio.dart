import '../models/centro_salud.dart';
import '../models/clima.dart';
import 'api_cliente.dart';

/// Contrato del servicio de clima (las pruebas usan uno falso).
abstract class ClimaServicio {
  Future<Clima> actual(Ubicacion ubicacion);
}

/// Clima con la API pública de Open-Meteo (HTTPS, sin clave).
/// Documentación: https://open-meteo.com/en/docs
class OpenMeteoClimaServicio implements ClimaServicio {
  static const urlBase = 'https://api.open-meteo.com/v1/forecast';

  final ApiCliente _api;
  final String _urlBase;
  final Duration vigencia;

  // Caché simple: el clima cambia poco y así ahorramos datos móviles.
  Clima? _ultimo;
  Ubicacion? _ultimaUbicacion;
  DateTime? _cuando;

  OpenMeteoClimaServicio(this._api,
      {String urlBase = urlBase, this.vigencia = const Duration(minutes: 15)})
      : _urlBase = urlBase;

  static Uri construirUri(Ubicacion u, {String base = urlBase}) =>
      Uri.parse(base).replace(queryParameters: {
        'latitude': u.lat.toStringAsFixed(4),
        'longitude': u.lng.toStringAsFixed(4),
        'current': 'temperature_2m,apparent_temperature,relative_humidity_2m,'
            'precipitation,weather_code,wind_speed_10m,is_day',
        'daily': 'uv_index_max,temperature_2m_min,temperature_2m_max,'
            'precipitation_probability_max',
        'timezone': 'America/La_Paz',
        'forecast_days': '1',
      });

  @override
  Future<Clima> actual(Ubicacion ubicacion) async {
    final c = _ultimo;
    if (c != null &&
        _ultimaUbicacion != null &&
        _ultimaUbicacion!.distanciaKm(ubicacion) < 2 &&
        DateTime.now().difference(_cuando!) < vigencia) {
      return c;
    }
    final json = await _api.getJson(construirUri(ubicacion, base: _urlBase),
        servicio: 'el clima');
    final Clima clima;
    try {
      clima = Clima.desdeOpenMeteo(json);
    } on FormatException catch (e) {
      throw ApiException(TipoErrorApi.formatoInvalido, 'el clima',
          detalle: e.message);
    }
    _ultimo = clima;
    _ultimaUbicacion = ubicacion;
    _cuando = DateTime.now();
    return clima;
  }
}
