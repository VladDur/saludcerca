import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../models/centro_salud.dart';
import '../models/favorito.dart';
import '../widgets/centro_card.dart';
import '../widgets/etiqueta_estado.dart';
import '../widgets/fila_info.dart';
import '../widgets/mensajes.dart';
import 'favoritos_screen.dart';
import 'mapa_screen.dart';
import 'recordatorio_form_screen.dart';

/// Detalle de un centro: datos, servicios, agregar/quitar de favoritos y
/// crear un recordatorio para ese centro.
class DetalleCentroScreen extends StatefulWidget {
  final CentroSalud centro;

  const DetalleCentroScreen({super.key, required this.centro});

  @override
  State<DetalleCentroScreen> createState() => _DetalleCentroScreenState();
}

class _DetalleCentroScreenState extends State<DetalleCentroScreen> {
  Favorito? _favorito;
  bool _cargandoFavorito = true;

  CentroSalud get centro => widget.centro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarFavorito());
  }

  Future<void> _cargarFavorito() async {
    try {
      final f = await AppScope.de(context).favoritos.buscarPorCentro(centro.id);
      if (mounted) setState(() => _favorito = f);
    } catch (e) {
      if (mounted) Mensajes.error(context, e);
    } finally {
      if (mounted) setState(() => _cargandoFavorito = false);
    }
  }

  Future<void> _alternarFavorito() async {
    final repo = AppScope.de(context).favoritos;
    if (_favorito == null) {
      final nota = await pedirNotaFavorito(context, centro.nombre);
      if (nota == null || !mounted) return;
      setState(() => _cargandoFavorito = true);
      try {
        await repo.agregar(centro.id, nota: nota);
        if (mounted) Mensajes.exito(context, 'Agregado a tus favoritos.');
      } catch (e) {
        if (mounted) Mensajes.error(context, e);
      }
    } else {
      final ok = await Mensajes.confirmar(context,
          titulo: 'Quitar de favoritos',
          mensaje: '¿Quitar "${centro.nombre}" de tus favoritos?',
          textoAceptar: 'Sí, quitar');
      if (!ok || !mounted) return;
      setState(() => _cargandoFavorito = true);
      try {
        await repo.quitar(_favorito!.id);
        if (mounted) Mensajes.exito(context, 'Quitado de tus favoritos.');
      } catch (e) {
        if (mounted) Mensajes.error(context, e);
      }
    }
    await _cargarFavorito();
  }

  void _avisoProximamente(String accion) {
    Mensajes.exito(
        context, '$accion estará disponible en una próxima versión.');
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final esFavorito = _favorito != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del centro'),
        actions: [
          IconButton(
            tooltip: esFavorito ? 'Quitar de favoritos' : 'Agregar a favoritos',
            onPressed: _cargandoFavorito ? null : _alternarFavorito,
            icon: Icon(esFavorito ? Icons.favorite : Icons.favorite_border),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              color: esquema.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(iconoTipoCentro(centro.tipo),
                          color: esquema.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Text(centro.tipo.nombre.toUpperCase(),
                          style: TextStyle(
                              fontSize: 14,
                              letterSpacing: 1,
                              fontWeight: FontWeight.bold,
                              color: esquema.onPrimaryContainer)),
                    ]),
                    const SizedBox(height: 6),
                    Text(centro.nombre, style: textos.headlineMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        EtiquetaEstado.abierto(centro.estaAbierto()),
                        if (centro.atiendeEmergencias)
                          EtiquetaEstado.emergencias(),
                        EtiquetaEstado.info(
                            'A ${centro.distanciaTexto(AppScope.de(context).ubicacion.ultimaConocida.ubicacion)}',
                            Icons.place),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_favorito != null && _favorito!.nota.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Tu nota: ${_favorito!.nota}',
                    style: textos.bodyLarge
                        ?.copyWith(fontStyle: FontStyle.italic)),
              ),
            Text(centro.descripcion, style: textos.bodyLarge),
            const SizedBox(height: 8),
            const Divider(),
            FilaInfo(
                icono: Icons.location_on,
                titulo: 'Dirección',
                valor: '${centro.direccion}, ${centro.ciudad}'),
            FilaInfo(
                icono: Icons.schedule,
                titulo: 'Horario',
                valor: centro.horarioTexto),
            FilaInfo(
                icono: Icons.phone, titulo: 'Teléfono', valor: centro.telefono),
            const Divider(),
            const SizedBox(height: 8),
            Text('Servicios', style: textos.titleLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  centro.servicios.map((s) => Chip(label: Text(s))).toList(),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              key: const Key('btn_favorito'),
              onPressed: _cargandoFavorito ? null : _alternarFavorito,
              icon: Icon(esFavorito ? Icons.heart_broken : Icons.favorite),
              label: Text(
                  esFavorito ? 'Quitar de favoritos' : 'Guardar en favoritos'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => RecordatorioFormScreen(centro: centro)),
              ),
              icon: const Icon(Icons.alarm_add),
              label: const Text('Crear recordatorio aquí'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('detalle_ver_mapa'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => MapaScreen(
                        enfocar: centro.ubicacion, seleccionId: centro.id)),
              ),
              icon: const Icon(Icons.map),
              label: const Text('Ver en el mapa'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _avisoProximamente('Llamar'),
              icon: const Icon(Icons.call),
              label: const Text('Llamar'),
            ),
          ],
        ),
      ),
    );
  }
}
