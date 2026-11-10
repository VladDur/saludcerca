import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Etiqueta de color: "Abierto", "Cerrado", "Emergencias 24h", etc.
class EtiquetaEstado extends StatelessWidget {
  final String texto;
  final Color color;
  final Color fondo;
  final IconData icono;

  const EtiquetaEstado({
    super.key,
    required this.texto,
    required this.color,
    required this.fondo,
    required this.icono,
  });

  factory EtiquetaEstado.abierto(bool abierto) => abierto
      ? const EtiquetaEstado(
          texto: 'Abierto ahora',
          color: AppColors.abierto,
          fondo: AppColors.abiertoFondo,
          icono: Icons.check_circle)
      : const EtiquetaEstado(
          texto: 'Cerrado',
          color: AppColors.cerrado,
          fondo: AppColors.cerradoFondo,
          icono: Icons.cancel);

  factory EtiquetaEstado.emergencias() => const EtiquetaEstado(
      texto: 'Emergencias',
      color: AppColors.emergencia,
      fondo: AppColors.emergenciaFondo,
      icono: Icons.local_hospital);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 6),
          Text(texto,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
