import '../services/api_cliente.dart';

/// Tipo de aviso de salud según el clima.
enum TipoAviso { uv, frio, lluvia, calor }

class AvisoSalud {
  final TipoAviso tipo;
  final String titulo;
  final String consejo;
  const AvisoSalud(this.tipo, this.titulo, this.consejo);
}

/// Clima actual y resumen del día, leído de Open-Meteo.
class Clima {
  final double temperatura; // °C
  final double sensacion; // °C
  final int humedad; // %
  final double precipitacion; // mm en la última hora
  final int codigoTiempo; // código WMO
  final double viento; // km/h
  final bool esDeDia;
  final double uvMaximo; // índice UV máximo del día
  final double minima; // °C mínima del día
  final double maxima; // °C máxima del día
  final int probabilidadLluvia; // % máxima del día
  final DateTime hora;

  const Clima({
    required this.temperatura,
    required this.sensacion,
    required this.humedad,
    required this.precipitacion,
    required this.codigoTiempo,
    required this.viento,
    required this.esDeDia,
    required this.uvMaximo,
    required this.minima,
    required this.maxima,
    required this.probabilidadLluvia,
    required this.hora,
  });

  /// Convierte la respuesta JSON de `/v1/forecast`. Lanza [FormatException]
  /// si falta un campo o tiene otro tipo.
  factory Clima.desdeOpenMeteo(Object? json) {
    final actual = campo<Map>(json, 'current');
    final diario = campo<Map>(json, 'daily');
    double primero(String clave) {
      final lista = campo<List>(diario, clave);
      if (lista.isEmpty || lista.first is! num) {
        throw FormatException('"daily.$clave" vacío o inválido');
      }
      return (lista.first as num).toDouble();
    }

    final hora = DateTime.tryParse(campo<String>(actual, 'time'));
    if (hora == null) throw const FormatException('"current.time" inválido');
    return Clima(
      temperatura: campo<double>(actual, 'temperature_2m'),
      sensacion: campo<double>(actual, 'apparent_temperature'),
      humedad: campo<double>(actual, 'relative_humidity_2m').round(),
      precipitacion: campo<double>(actual, 'precipitation'),
      codigoTiempo: campo<double>(actual, 'weather_code').round(),
      viento: campo<double>(actual, 'wind_speed_10m'),
      esDeDia: campo<double>(actual, 'is_day') == 1,
      uvMaximo: primero('uv_index_max'),
      minima: primero('temperature_2m_min'),
      maxima: primero('temperature_2m_max'),
      probabilidadLluvia: primero('precipitation_probability_max').round(),
      hora: hora,
    );
  }

  /// Descripción en español del código WMO.
  String get descripcion {
    final c = codigoTiempo;
    if (c == 0) return esDeDia ? 'Despejado' : 'Noche despejada';
    if (c <= 2) return 'Parcialmente nublado';
    if (c == 3) return 'Nublado';
    if (c == 45 || c == 48) return 'Niebla';
    if (c >= 51 && c <= 57) return 'Llovizna';
    if ((c >= 61 && c <= 67) || (c >= 80 && c <= 82)) return 'Lluvia';
    if ((c >= 71 && c <= 77) || c == 85 || c == 86) return 'Nieve';
    if (c >= 95) return 'Tormenta';
    return 'Variable';
  }

  bool get estaLloviendo =>
      precipitacion > 0 ||
      (codigoTiempo >= 51 && codigoTiempo <= 67) ||
      (codigoTiempo >= 80 && codigoTiempo <= 82) ||
      codigoTiempo >= 95;

  /// Avisos de salud preventiva para adultos mayores.
  List<AvisoSalud> get avisos {
    final r = <AvisoSalud>[];
    if (uvMaximo >= 8) {
      r.add(AvisoSalud(
          TipoAviso.uv,
          'Radiación UV muy alta (${uvMaximo.round()})',
          'Usa sombrero, lentes y bloqueador. Evita el sol de 10:00 a 15:00.'));
    } else if (uvMaximo >= 6) {
      r.add(AvisoSalud(TipoAviso.uv, 'Radiación UV alta (${uvMaximo.round()})',
          'Usa sombrero y bloqueador si sales a mediodía.'));
    }
    if (minima <= 3 || sensacion <= 5) {
      r.add(const AvisoSalud(TipoAviso.frio, 'Frío intenso',
          'Abrígate bien, sobre todo al salir temprano o de noche, y toma líquidos tibios.'));
    }
    if (estaLloviendo || probabilidadLluvia >= 60) {
      r.add(AvisoSalud(
          TipoAviso.lluvia,
          estaLloviendo
              ? 'Está lloviendo'
              : 'Probable lluvia ($probabilidadLluvia %)',
          'Lleva paraguas y camina con cuidado: el piso puede estar resbaloso.'));
    }
    if (maxima >= 25) {
      r.add(const AvisoSalud(TipoAviso.calor, 'Día caluroso',
          'Toma agua con frecuencia aunque no tengas sed.'));
    }
    return r;
  }

  static String grados(double v) => '${v.round()} °C';
}
