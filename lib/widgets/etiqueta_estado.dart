import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum _Clase { abierto, cerrado, emergencias, info }

/// Etiqueta de color: "Abierto ahora", "Cerrado", "Emergencias", etc.
/// Los colores salen del tema (claro, oscuro o alto contraste).
class EtiquetaEstado extends StatelessWidget {
  final String texto;
  final IconData icono;
  final _Clase _clase;

  const EtiquetaEstado._(this.texto, this.icono, this._clase);

  factory EtiquetaEstado.abierto(bool abierto) => abierto
      ? const EtiquetaEstado._(
          'Abierto ahora', Icons.check_circle, _Clase.abierto)
      : const EtiquetaEstado._('Cerrado', Icons.cancel, _Clase.cerrado);

  factory EtiquetaEstado.emergencias() => const EtiquetaEstado._(
      'Emergencias', Icons.local_hospital, _Clase.emergencias);

  factory EtiquetaEstado.info(String texto, IconData icono) =>
      EtiquetaEstado._(texto, icono, _Clase.info);

  @override
  Widget build(BuildContext context) {
    final c = ColoresSalud.de(context);
    final (color, fondo) = switch (_clase) {
      _Clase.abierto => (c.abierto, c.abiertoFondo),
      _Clase.cerrado => (c.cerrado, c.cerradoFondo),
      _Clase.emergencias => (c.emergencia, c.emergenciaFondo),
      _Clase.info => (c.acento, Theme.of(context).cardTheme.color!),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
        border: c.grosorBorde > 1 ? Border.all(color: color, width: 2) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(texto,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
  }
}
