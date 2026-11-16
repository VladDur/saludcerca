/// Perfil del usuario autenticado (tabla `perfiles`).
class Perfil {
  final String id;
  final String nombreCompleto;
  final String? telefono;
  final String ciudad;
  final String? contactoEmergenciaNombre;
  final String? contactoEmergenciaTelefono;

  const Perfil({
    required this.id,
    required this.nombreCompleto,
    this.telefono,
    this.ciudad = 'La Paz',
    this.contactoEmergenciaNombre,
    this.contactoEmergenciaTelefono,
  });

  factory Perfil.desdeMapa(Map<String, dynamic> m) => Perfil(
        id: m['id'] as String,
        nombreCompleto: m['nombre_completo'] as String,
        telefono: m['telefono'] as String?,
        ciudad: m['ciudad'] as String? ?? 'La Paz',
        contactoEmergenciaNombre: m['contacto_emergencia_nombre'] as String?,
        contactoEmergenciaTelefono:
            m['contacto_emergencia_telefono'] as String?,
      );

  /// Campos editables por el usuario (UPDATE).
  Map<String, dynamic> aMapaEdicion() => {
        'nombre_completo': nombreCompleto.trim(),
        'telefono': _vacioANull(telefono),
        'ciudad': ciudad,
        'contacto_emergencia_nombre': _vacioANull(contactoEmergenciaNombre),
        'contacto_emergencia_telefono': _vacioANull(contactoEmergenciaTelefono),
      };

  static String? _vacioANull(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();

  String get primerNombre => nombreCompleto.trim().split(' ').first;
}
