import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../models/centro_salud.dart';
import '../theme/app_theme.dart';
import 'etiqueta_estado.dart';

IconData iconoTipoCentro(TipoCentro tipo) {
  switch (tipo) {
    case TipoCentro.hospital:
      return Icons.local_hospital;
    case TipoCentro.centroSalud:
      return Icons.medical_services;
    case TipoCentro.posta:
      return Icons.healing;
  }
}

/// Tarjeta de un centro de salud en las listas.
class CentroCard extends StatelessWidget {
  final CentroSalud centro;
  final VoidCallback onTap;
  final String? nota;
  final Widget? accion;

  const CentroCard({
    super.key,
    required this.centro,
    required this.onTap,
    this.nota,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final colores = ColoresSalud.de(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: esquema.primaryContainer,
                child: Icon(iconoTipoCentro(centro.tipo),
                    color: esquema.onPrimaryContainer, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(centro.nombre, style: textos.titleMedium),
                    const SizedBox(height: 4),
                    Text('${centro.tipo.nombre} · ${centro.zona}',
                        style: textos.bodyMedium),
                    if (nota != null && nota!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Nota: $nota',
                          style: textos.bodyMedium
                              ?.copyWith(fontStyle: FontStyle.italic)),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        EtiquetaEstado.abierto(centro.estaAbierto()),
                        if (centro.atiendeEmergencias)
                          EtiquetaEstado.emergencias(),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Icon(Icons.place, color: colores.acento),
                  Text(
                      centro.distanciaTexto(AppScope.de(context)
                          .ubicacion
                          .ultimaConocida
                          .ubicacion),
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colores.acento)),
                  if (accion != null) accion!,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
