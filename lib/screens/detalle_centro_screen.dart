import 'package:flutter/material.dart';

import '../models/centro_salud.dart';
import '../theme/app_theme.dart';
import '../widgets/etiqueta_estado.dart';
import '../widgets/fila_info.dart';

/// Pantalla 3: Detalle de un centro de salud.
class DetalleCentroScreen extends StatelessWidget {
  final CentroSalud centro;

  const DetalleCentroScreen({super.key, required this.centro});

  void _avisoProximamente(BuildContext context, String accion) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$accion estará disponible en una próxima versión.',
            style: const TextStyle(fontSize: 17)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del centro')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Encabezado
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primarioClaro,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(centro.tipo.nombre.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 14,
                          letterSpacing: 1,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primario)),
                  const SizedBox(height: 6),
                  Text(centro.nombre, style: textos.headlineMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      EtiquetaEstado.abierto(centro.abiertoAhora),
                      if (centro.atiendeEmergencias)
                        EtiquetaEstado.emergencias(),
                      EtiquetaEstado(
                        texto: 'A ${centro.distanciaTexto}',
                        color: AppColors.secundario,
                        fondo: Colors.white,
                        icono: Icons.place,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(centro.descripcion, style: textos.bodyLarge),
            const SizedBox(height: 8),
            const Divider(),
            FilaInfo(
                icono: Icons.location_on,
                titulo: 'Dirección',
                valor: '${centro.direccion}, ${centro.ciudad}'),
            FilaInfo(
                icono: Icons.schedule, titulo: 'Horario', valor: centro.horario),
            FilaInfo(
                icono: Icons.phone, titulo: 'Teléfono', valor: centro.telefono),
            const Divider(),
            const SizedBox(height: 8),
            Text('Servicios', style: textos.titleLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: centro.servicios
                  .map((s) => Chip(
                        label: Text(s, style: const TextStyle(fontSize: 16)),
                        backgroundColor: Colors.white,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => _avisoProximamente(context, 'Llamar'),
              icon: const Icon(Icons.call),
              label: const Text('Llamar'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _avisoProximamente(context, 'Ver en el mapa'),
              icon: const Icon(Icons.map),
              label: const Text('Cómo llegar'),
            ),
          ],
        ),
      ),
    );
  }
}
