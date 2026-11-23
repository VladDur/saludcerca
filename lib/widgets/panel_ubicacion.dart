import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../services/ubicacion_servicio.dart';
import '../theme/app_theme.dart';

/// HU-13: muestra desde dónde se calculan las distancias.
/// Con GPS pide a Nominatim la dirección aproximada ("Sopocachi, La Paz").
class PanelUbicacion extends StatefulWidget {
  final ResultadoUbicacion? resultado; // null = buscando
  final VoidCallback onActualizar;

  const PanelUbicacion(
      {super.key, required this.resultado, required this.onActualizar});

  @override
  State<PanelUbicacion> createState() => _PanelUbicacionState();
}

class _PanelUbicacionState extends State<PanelUbicacion> {
  String? _direccion;
  bool _buscandoDireccion = false;

  @override
  void didUpdateWidget(PanelUbicacion old) {
    super.didUpdateWidget(old);
    if (old.resultado?.ubicacion != widget.resultado?.ubicacion) {
      _direccion = null;
      _buscarDireccion();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buscarDireccion());
  }

  Future<void> _buscarDireccion() async {
    final r = widget.resultado;
    if (r == null || !r.esGps || !mounted) return;
    setState(() => _buscandoDireccion = true);
    try {
      final d =
          await AppScope.de(context).geocodificacion.direccionDe(r.ubicacion);
      if (mounted) setState(() => _direccion = d);
    } catch (_) {
      // Sin dirección se muestran las coordenadas: no es un error grave.
    } finally {
      if (mounted) setState(() => _buscandoDireccion = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final acento = ColoresSalud.de(context).acento;
    final r = widget.resultado;

    final String titulo;
    final String detalle;
    final IconData icono;
    if (r == null) {
      titulo = 'Buscando tu ubicación…';
      detalle = 'Mientras tanto usamos Plaza Murillo, La Paz';
      icono = Icons.location_searching;
    } else if (r.esGps) {
      titulo = 'Cerca de ti';
      detalle = _direccion ??
          (_buscandoDireccion
              ? 'Buscando la dirección…'
              : '${r.ubicacion.lat.toStringAsFixed(4)}, '
                  '${r.ubicacion.lng.toStringAsFixed(4)}');
      icono = Icons.my_location;
    } else {
      titulo = 'Distancias desde Plaza Murillo, La Paz';
      detalle = '${r.motivo}.';
      icono = Icons.location_disabled;
    }

    return Semantics(
      container: true,
      label: 'Ubicación: $titulo. $detalle',
      child: Row(
        children: [
          Icon(icono, size: 24, color: acento),
          const SizedBox(width: 8),
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      key: const Key('ubicacion_titulo'),
                      style: textos.titleSmall),
                  Text(detalle,
                      key: const Key('ubicacion_detalle'),
                      style: textos.bodyMedium),
                ],
              ),
            ),
          ),
          IconButton(
            key: const Key('actualizar_ubicacion'),
            tooltip: 'Actualizar mi ubicación',
            onPressed: r == null ? null : widget.onActualizar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
