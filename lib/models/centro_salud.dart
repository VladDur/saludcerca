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
}

/// Centro de salud que ve el USUARIO en la app.
class CentroSalud {
  final String id;
  final String nombre;
  final TipoCentro tipo;
  final String ciudad; // La Paz o El Alto
  final String zona;
  final String direccion;
  final String telefono;
  final String horario;
  final bool abiertoAhora;
  final bool atiendeEmergencias;
  final double distanciaKm;
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
    required this.horario,
    required this.abiertoAhora,
    required this.atiendeEmergencias,
    required this.distanciaKm,
    required this.servicios,
    required this.descripcion,
  });

  /// Distancia en texto legible: "650 m" o "2,4 km".
  String get distanciaTexto {
    if (distanciaKm < 1) return '${(distanciaKm * 1000).round()} m';
    return '${distanciaKm.toStringAsFixed(1).replaceAll('.', ',')} km';
  }
}
