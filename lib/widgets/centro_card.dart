import 'package:flutter/material.dart';

import '../models/centro_salud.dart';
import '../theme/app_theme.dart';
import 'etiqueta_estado.dart';

/// Tarjeta de un centro de salud en la lista de Inicio.
class CentroCard extends StatelessWidget {
  final CentroSalud centro;
  final VoidCallback onTap;

  const CentroCard({super.key, required this.centro, required this.onTap});

  IconData get _icono {
    switch (centro.tipo) {
      case TipoCentro.hospital:
        return Icons.local_hospital;
      case TipoCentro.centroSalud:
        return Icons.medical_services;
      case TipoCentro.posta:
        return Icons.healing;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primarioClaro,
                child: Icon(_icono, color: AppColors.primario, size: 30),
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
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        EtiquetaEstado.abierto(centro.abiertoAhora),
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
                  const Icon(Icons.place, color: AppColors.secundario),
                  Text(centro.distanciaTexto,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secundario)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
