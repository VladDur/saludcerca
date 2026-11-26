import 'centro_salud.dart';

/// Farmacia de La Paz o El Alto (tabla `farmacias`).
class Farmacia {
  final String id;
  final String nombre;
  final String ciudad;
  final String zona;
  final String direccion;
  final String telefono;
  final Ubicacion ubicacion;

  /// Celular con código de país (59170000000); null si no atiende por chat.
  final String? whatsapp;

  const Farmacia({
    required this.id,
    required this.nombre,
    required this.ciudad,
    required this.zona,
    required this.direccion,
    required this.telefono,
    required this.ubicacion,
    this.whatsapp,
  });

  factory Farmacia.desdeMapa(Map<String, dynamic> m) => Farmacia(
        id: m['id'] as String,
        nombre: m['nombre'] as String,
        ciudad: m['ciudad'] as String,
        zona: m['zona'] as String,
        direccion: m['direccion'] as String,
        telefono: m['telefono'] as String,
        ubicacion: Ubicacion((m['latitud'] as num).toDouble(),
            (m['longitud'] as num).toDouble()),
        whatsapp: m['whatsapp'] as String?,
      );
}

/// Una farmacia en un turno (tabla `turnos_farmacia` con la farmacia
/// embebida). El turno empieza el día [fecha] a [horaInicio] y termina al
/// día siguiente a [horaFin].
class TurnoFarmacia {
  final String id;
  final DateTime fecha; // solo la fecha (00:00 local)
  final String horaInicio; // "08:00"
  final String horaFin; // "08:00"
  final Farmacia farmacia;

  const TurnoFarmacia({
    required this.id,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.farmacia,
  });

  factory TurnoFarmacia.desdeMapa(Map<String, dynamic> m) {
    final f = m['farmacias'];
    if (f is! Map<String, dynamic>) {
      throw const FormatException('Turno sin farmacia');
    }
    final fecha = DateTime.parse(m['fecha'] as String);
    return TurnoFarmacia(
      id: m['id'] as String,
      fecha: DateTime(fecha.year, fecha.month, fecha.day),
      horaInicio: (m['hora_inicio'] as String).substring(0, 5),
      horaFin: (m['hora_fin'] as String).substring(0, 5),
      farmacia: Farmacia.desdeMapa(f),
    );
  }

  static int _minutos(String h) =>
      int.parse(h.substring(0, 2)) * 60 + int.parse(h.substring(3, 5));

  DateTime get inicio => fecha.add(Duration(minutes: _minutos(horaInicio)));

  DateTime get fin => fecha
      .add(const Duration(days: 1))
      .add(Duration(minutes: _minutos(horaFin)));

  bool vigenteEn(DateTime momento) =>
      !momento.isBefore(inicio) && momento.isBefore(fin);

  /// "Hoy 08:00 a mañana 08:00" respecto de [hoy].
  String horarioTexto(DateTime hoy) {
    final base = DateTime(hoy.year, hoy.month, hoy.day);
    String dia(DateTime d) {
      final dd = DateTime(d.year, d.month, d.day).difference(base).inDays;
      if (dd == 0) return 'hoy';
      if (dd == 1) return 'mañana';
      if (dd == -1) return 'ayer';
      if (dd == 2) return 'pasado mañana';
      return '${d.day}/${d.month}';
    }

    return 'De ${dia(inicio)} $horaInicio a ${dia(fin)} $horaFin';
  }
}

/// Fecha del turno vigente: antes de la hora de cambio (08:00) sigue
/// de turno la farmacia del día anterior.
DateTime fechaTurnoVigente(DateTime ahora, {int horaCambio = 8}) {
  return DateTime(ahora.year, ahora.month,
      ahora.hour < horaCambio ? ahora.day - 1 : ahora.day);
}
