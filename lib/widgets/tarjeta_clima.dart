import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/errores.dart';
import '../models/centro_salud.dart';
import '../models/clima.dart';
import '../theme/app_theme.dart';

/// Tarjeta de clima (Open-Meteo) con avisos de salud preventiva.
/// Estados: cargando, error con "Reintentar" y datos.
class TarjetaClima extends StatefulWidget {
  final Ubicacion ubicacion;

  const TarjetaClima({super.key, required this.ubicacion});

  @override
  State<TarjetaClima> createState() => _TarjetaClimaState();
}

class _TarjetaClimaState extends State<TarjetaClima> {
  Future<Clima>? _futuro;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _futuro ??= _consultar();
  }

  @override
  void didUpdateWidget(TarjetaClima old) {
    super.didUpdateWidget(old);
    if (old.ubicacion != widget.ubicacion) _futuro = _consultar();
  }

  // El error lo muestra el FutureBuilder; `ignore` evita que se reporte
  // como "no manejado" si la falla llega antes de que se suscriba.
  Future<Clima> _consultar() =>
      AppScope.de(context).clima.actual(widget.ubicacion)..ignore();

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    return Card(
      key: const Key('tarjeta_clima'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<Clima>(
          future: _futuro,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return Semantics(
                label: 'Cargando el clima',
                child: const Row(children: [
                  SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3)),
                  SizedBox(width: 14),
                  Expanded(child: Text('Cargando el clima…')),
                ]),
              );
            }
            if (snap.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.cloud_off, color: esquema.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(mensajeError(snap.error!),
                          key: const Key('clima_error'),
                          style: textos.bodyLarge),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      key: const Key('clima_reintentar'),
                      onPressed: () => setState(() {
                        _futuro = _consultar();
                      }),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ),
                ],
              );
            }
            final c = snap.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: 'Clima ahora: ${Clima.grados(c.temperatura)}, '
                      '${c.descripcion}. Mínima ${Clima.grados(c.minima)}, '
                      'máxima ${Clima.grados(c.maxima)}.',
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        Icon(_icono(c), size: 44, color: esquema.primary),
                        const SizedBox(width: 12),
                        Text(Clima.grados(c.temperatura),
                            key: const Key('clima_temperatura'),
                            style: textos.headlineMedium),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.descripcion, style: textos.titleMedium),
                              Text(
                                  'Mín. ${Clima.grados(c.minima)} · '
                                  'Máx. ${Clima.grados(c.maxima)}',
                                  style: textos.bodyMedium),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                for (final a in c.avisos) _FilaAviso(aviso: a),
                if (c.avisos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Buen clima para salir. ¡Cuídate!',
                        style: textos.bodyMedium),
                  ),
                const SizedBox(height: 6),
                Text('Datos: Open-Meteo',
                    style: textos.bodySmall
                        ?.copyWith(color: esquema.onSurfaceVariant)),
              ],
            );
          },
        ),
      ),
    );
  }

  IconData _icono(Clima c) {
    if (c.codigoTiempo >= 95) return Icons.thunderstorm;
    if (c.estaLloviendo) return Icons.umbrella;
    if (c.codigoTiempo >= 71 && c.codigoTiempo <= 86) return Icons.ac_unit;
    if (c.codigoTiempo >= 3) return Icons.cloud;
    if (c.codigoTiempo >= 1) return Icons.wb_cloudy;
    return c.esDeDia ? Icons.wb_sunny : Icons.nightlight;
  }
}

class _FilaAviso extends StatelessWidget {
  final AvisoSalud aviso;
  const _FilaAviso({required this.aviso});

  @override
  Widget build(BuildContext context) {
    final c = ColoresSalud.de(context);
    final icono = switch (aviso.tipo) {
      TipoAviso.uv => Icons.wb_sunny,
      TipoAviso.frio => Icons.ac_unit,
      TipoAviso.lluvia => Icons.umbrella,
      TipoAviso.calor => Icons.local_drink,
    };
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.emergenciaFondo,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: c.emergencia, width: c.grosorBorde > 1 ? 2 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: c.emergencia),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(aviso.titulo,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: c.emergencia)),
                const SizedBox(height: 2),
                Text(aviso.consejo,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
