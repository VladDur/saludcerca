import '../services/api_cliente.dart';

/// Niveles del índice de calidad del aire de EE. UU. (US AQI), que es el que
/// devuelve Open-Meteo en `us_aqi`.
enum NivelAire {
  bueno('Buena', 0),
  moderado('Moderada', 51),
  sensibles('Dañina para personas sensibles', 101),
  danino('Dañina', 151),
  muyDanino('Muy dañina', 201),
  peligroso('Peligrosa', 301);

  final String nombre;
  final int desde; // valor mínimo del índice para este nivel
  const NivelAire(this.nombre, this.desde);

  static NivelAire deIndice(int aqi) {
    var r = NivelAire.bueno;
    for (final n in NivelAire.values) {
      if (aqi >= n.desde) r = n;
    }
    return r;
  }
}

/// Gravedad de un consejo: sirve para elegir el color de la tarjeta.
enum Gravedad { buena, atencion, alerta }

/// Tipo de consejo, para elegir el ícono.
enum TipoConsejo { aire, uv }

class ConsejoSalud {
  final TipoConsejo tipo;
  final Gravedad gravedad;
  final String titulo;
  final String texto;
  const ConsejoSalud(this.tipo, this.gravedad, this.titulo, this.texto);
}

/// Calidad del aire actual, leída de la API Air Quality de Open-Meteo.
class CalidadAire {
  final double pm25; // µg/m³, partículas finas
  final double? pm10; // µg/m³, partículas gruesas
  final int indice; // US AQI
  final double? uv; // índice UV de la hora actual
  final DateTime hora;

  const CalidadAire({
    required this.pm25,
    required this.pm10,
    required this.indice,
    required this.uv,
    required this.hora,
  });

  /// Convierte la respuesta de `/v1/air-quality`. `us_aqi`, `pm2_5` y `time`
  /// son obligatorios; `pm10` y `uv_index` pueden venir en `null`.
  /// Lanza [FormatException] si falta un campo obligatorio.
  factory CalidadAire.desdeOpenMeteo(Object? json) {
    final actual = campo<Map>(json, 'current');
    final hora = DateTime.tryParse(campo<String>(actual, 'time'));
    if (hora == null) throw const FormatException('"current.time" inválido');
    final indice = campo<double>(actual, 'us_aqi');
    if (indice < 0) throw const FormatException('"us_aqi" negativo');
    double? opcional(String clave) {
      final v = actual[clave];
      if (v == null) return null;
      if (v is num) return v.toDouble();
      throw FormatException('Campo "$clave" inválido: ${v.runtimeType}');
    }

    return CalidadAire(
      pm25: campo<double>(actual, 'pm2_5'),
      pm10: opcional('pm10'),
      indice: indice.round(),
      uv: opcional('uv_index'),
      hora: hora,
    );
  }

  NivelAire get nivel => NivelAire.deIndice(indice);

  Gravedad get gravedad => switch (nivel) {
        NivelAire.bueno => Gravedad.buena,
        NivelAire.moderado || NivelAire.sensibles => Gravedad.atencion,
        _ => Gravedad.alerta,
      };

  /// Consejos de salud preventiva pensados para adultos mayores, que son
  /// un grupo sensible a la contaminación y a la radiación UV de la altura.
  List<ConsejoSalud> get consejos {
    final r = <ConsejoSalud>[_consejoAire()];
    final u = uv;
    if (u != null && u >= 8) {
      r.add(ConsejoSalud(
          TipoConsejo.uv,
          Gravedad.alerta,
          'Sol muy fuerte ahora (UV ${u.round()})',
          'Usa sombrero de ala ancha, lentes oscuros y bloqueador. '
              'Busca la sombra y bebe agua.'));
    } else if (u != null && u >= 6) {
      r.add(ConsejoSalud(
          TipoConsejo.uv,
          Gravedad.atencion,
          'Sol fuerte ahora (UV ${u.round()})',
          'Si sales, usa sombrero y bloqueador, y no te quedes mucho al sol.'));
    } else if (u != null && u >= 3) {
      r.add(ConsejoSalud(
          TipoConsejo.uv,
          Gravedad.atencion,
          'Sol moderado (UV ${u.round()})',
          'En la altura el sol quema rápido: lleva sombrero si vas a caminar.'));
    }
    return r;
  }

  ConsejoSalud _consejoAire() {
    switch (nivel) {
      case NivelAire.bueno:
        return const ConsejoSalud(
            TipoConsejo.aire,
            Gravedad.buena,
            'Aire limpio',
            'Buen momento para caminar o hacer ejercicio suave al aire libre.');
      case NivelAire.moderado:
        return const ConsejoSalud(
            TipoConsejo.aire,
            Gravedad.atencion,
            'Aire aceptable',
            'Puedes salir. Si tienes asma o problemas del corazón, '
                'evita esfuerzos largos y lleva tu medicamento.');
      case NivelAire.sensibles:
        return const ConsejoSalud(
            TipoConsejo.aire,
            Gravedad.atencion,
            'Cuidado si eres adulto mayor',
            'Acorta las caminatas, evita avenidas con mucho tráfico '
                'y descansa si sientes tos o falta de aire.');
      case NivelAire.danino:
        return const ConsejoSalud(
            TipoConsejo.aire,
            Gravedad.alerta,
            'Mejor quédate en casa',
            'Evita el ejercicio afuera. Si sales, usa barbijo y vuelve pronto. '
                'Mantén las ventanas cerradas.');
      case NivelAire.muyDanino:
      case NivelAire.peligroso:
        return const ConsejoSalud(
            TipoConsejo.aire,
            Gravedad.alerta,
            'Aire muy contaminado',
            'No salgas si no es necesario. Si te falta el aire o tienes dolor '
                'en el pecho, busca un centro de salud de inmediato.');
    }
  }

  static String microgramos(double v) => '${v.toStringAsFixed(1)} µg/m³';
}
