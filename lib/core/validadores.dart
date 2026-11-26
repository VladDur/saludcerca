/// Validaciones de formularios reutilizables (devuelven el mensaje de error
/// o `null` si el valor es correcto).
class Validadores {
  static final _correo = RegExp(r'^[\w.+\-]+@[\w\-]+(\.[\w\-]+)+$');
  static final _telefono = RegExp(r'^[0-9+\- ]{7,15}$');

  static String? correo(String? v) {
    final valor = v?.trim() ?? '';
    if (valor.isEmpty) return 'Escribe tu correo';
    if (!_correo.hasMatch(valor)) return 'El correo no es válido';
    return null;
  }

  static String? clave(String? v) {
    final valor = v ?? '';
    if (valor.isEmpty) return 'Escribe tu contraseña';
    if (valor.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  static String? claveNueva(String? v) {
    final base = clave(v);
    if (base != null) return base;
    if (!RegExp(r'[0-9]').hasMatch(v!) || !RegExp(r'[A-Za-z]').hasMatch(v)) {
      return 'Usa letras y números';
    }
    return null;
  }

  static String? Function(String?) confirmarClave(String Function() original) =>
      (v) => v != original() ? 'Las contraseñas no coinciden' : null;

  static String? nombre(String? v) {
    final valor = v?.trim() ?? '';
    if (valor.isEmpty) return 'Escribe tu nombre';
    if (valor.length < 3) return 'Mínimo 3 letras';
    if (valor.length > 80) return 'Máximo 80 caracteres';
    return null;
  }

  /// Teléfono opcional: vacío es válido.
  static String? telefonoOpcional(String? v) {
    final valor = v?.trim() ?? '';
    if (valor.isEmpty) return null;
    if (!_telefono.hasMatch(valor)) {
      return 'Teléfono no válido (7 a 15 dígitos)';
    }
    return null;
  }

  static String? titulo(String? v) {
    final valor = v?.trim() ?? '';
    if (valor.isEmpty) return 'Escribe un título';
    if (valor.length < 3) return 'Mínimo 3 caracteres';
    if (valor.length > 60) return 'Máximo 60 caracteres';
    return null;
  }

  static String? medicamento(String? v) {
    final valor = v?.trim() ?? '';
    if (valor.isEmpty) return 'Escribe el medicamento';
    if (valor.length < 3) return 'Mínimo 3 caracteres';
    if (valor.length > 100) return 'Máximo 100 caracteres';
    return null;
  }

  static String? Function(String?) maximo(int max) =>
      (v) => (v?.trim().length ?? 0) > max ? 'Máximo $max caracteres' : null;
}
