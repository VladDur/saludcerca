import 'package:flutter/material.dart';

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
    final textos = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: Theme.of(context).colorScheme.primary, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: textos.bodyMedium),
                  const SizedBox(height: 2),
                  Text(valor, style: textos.bodyLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
