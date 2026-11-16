import 'dart:math' as math;

/// Tipo de establecimiento de salud.
enum TipoCentro { hospital, centroSalud, posta }

extension TipoCentroTexto on TipoCentro {
  String get nombre {
    switch (this) {
      case TipoCentro.hospital:
        return 'Hospital';
      case TipoCentro.centroSalud:
        return 'Centro de salud';
      case TipoCentro.posta:
        return 'Posta sanitaria';
    }
  }

  /// Valor guardado en la columna `tipo` de la base de datos.
  String get valorBd {
    switch (this) {
      case TipoCentro.hospital:
        return 'hospital';
      case TipoCentro.centroSalud:
        return 'centro_salud';
      case TipoCentro.posta:
        return 'posta';
    }
  }

  static TipoCentro desdeBd(String valor) =>
      TipoCentro.values.firstWhere((t) => t.valorBd == valor,
          orElse: () => TipoCentro.centroSalud);
}

/// Punto geográfico (latitud, longitud).
class Ubicacion {
  final double lat;
  final double lng;
  const Ubicacion(this.lat, this.lng);

  /// Ubicación de referencia del usuario (Plaza Murillo, La Paz).
  /// En un sprint posterior se reemplaza por el GPS del teléfono.
  static const referencia = Ubicacion(-16.4958, -68.1335);

  /// Distancia en km con la fórmula de Haversine.
  double distanciaKm(Ubicacion otra) {
    const radioTierra = 6371.0;
    double rad(double g) => g * math.pi / 180;
    final dLat = rad(otra.lat - lat);
    final dLng = rad(otra.lng - lng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat)) *
            math.cos(rad(otra.lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return radioTierra * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

/// Centro de salud leído desde la vista `v_centros` de Supabase.
class CentroSalud {
  final String id;
  final String nombre;
  final TipoCentro tipo;
  final String ciudad;
  final String zona;
  final String direccion;
  final String telefono;
  final Ubicacion ubicacion;
  final bool abierto24h;
  final String? horaApertura; // "07:00"
  final String? horaCierre; // "19:00"
  final List<int> diasAtencion; // 1 = lunes ... 7 = domingo
  final bool atiendeEmergencias;
  final List<String> servicios;
  final String descripcion;

  const CentroSalud({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.ciudad,
    required this.zona,
    required this.direccion,
    required this.telefono,
    required this.ubicacion,
    required this.abierto24h,
    required this.horaApertura,
    required this.horaCierre,
    required this.diasAtencion,
    required this.atiendeEmergencias,
    required this.servicios,
    required this.descripcion,
  });

  factory CentroSalud.desdeMapa(Map<String, dynamic> m) {
    String? hora(dynamic v) => v == null
        ? null
        : (v as String).substring(0, 5); // "07:00:00" -> "07:00"
    return CentroSalud(
      id: m['id'] as String,
      nombre: m['nombre'] as String,
      tipo: TipoCentroTexto.desdeBd(m['tipo'] as String),
      ciudad: m['ciudad'] as String,
      zona: m['zona'] as String,
      direccion: m['direccion'] as String,
      telefono: m['telefono'] as String,
      ubicacion: Ubicacion(
          (m['latitud'] as num).toDouble(), (m['longitud'] as num).toDouble()),
      abierto24h: m['abierto_24h'] as bool? ?? false,
      horaApertura: hora(m['hora_apertura']),
      horaCierre: hora(m['hora_cierre']),
      diasAtencion: ((m['dias_atencion'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      atiendeEmergencias: m['atiende_emergencias'] as bool? ?? false,
      servicios: ((m['servicios'] as List?) ?? const []).cast<String>(),
      descripcion: m['descripcion'] as String? ?? '',
    );
  }

  double get distanciaKm => Ubicacion.referencia.distanciaKm(ubicacion);

  /// Distancia en texto legible: "650 m" o "2,4 km".
  String get distanciaTexto {
    final km = distanciaKm;
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  /// ¿Está abierto en el momento indicado (hora local del teléfono)?
  bool estaAbierto([DateTime? momento]) {
    if (abierto24h) return true;
    final ahora = momento ?? DateTime.now();
    if (!diasAtencion.contains(ahora.weekday)) return false;
    if (horaApertura == null || horaCierre == null) return false;
    int minutos(String h) =>
        int.parse(h.substring(0, 2)) * 60 + int.parse(h.substring(3, 5));
    final actual = ahora.hour * 60 + ahora.minute;
    return actual >= minutos(horaApertura!) && actual < minutos(horaCierre!);
  }

  String get horarioTexto {
    if (abierto24h) return 'Atención las 24 horas';
    const nombres = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo'
    ];
    final dias = [...diasAtencion]..sort();
    String rango;
    final consecutivos = dias.isNotEmpty &&
        dias.last - dias.first == dias.length - 1 &&
        dias.length > 2;
    if (consecutivos) {
      rango = '${nombres[dias.first - 1]} a ${nombres[dias.last - 1]}';
    } else {
      rango = dias.map((d) => nombres[d - 1]).join(', ');
    }
    rango = rango.isEmpty ? rango : rango[0].toUpperCase() + rango.substring(1);
    return '$rango, ${horaApertura ?? '--'} a ${horaCierre ?? '--'}';
  }
}
