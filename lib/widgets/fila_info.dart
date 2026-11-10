import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fila con ícono, título y valor (dirección, horario, teléfono...).
class FilaInfo extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;

  const FilaInfo({
    super.key,
    required this.icono,
    required this.titulo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: AppColors.primario, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(valor, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
