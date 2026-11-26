import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/errores.dart';
import '../models/calidad_aire.dart';
import '../models/centro_salud.dart';
import '../theme/app_theme.dart';

/// HU-15 · Tarjeta de calidad del aire (Open-Meteo Air Quality) con consejos
/// de salud preventiva para adultos mayores.
/// Estados: cargando, error con "Reintentar" y datos.
///
/// El color viene del tema ([ColoresSalud]): verde = aire limpio,
/// naranja = atención, rojo = alerta. El nivel también se escribe con
/// palabras para no depender solo del color.
class TarjetaCalidadAire extends StatefulWidget {
  final Ubicacion ubicacion;

  const TarjetaCalidadAire({super.key, required this.ubicacion});

  @override
  State<TarjetaCalidadAire> createState() => _TarjetaCalidadAireState();
}

class _TarjetaCalidadAireState extends State<TarjetaCalidadAire> {
  Future<CalidadAire>? _futuro;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _futuro ??= _consultar();
  }

  @override
  void didUpdateWidget(TarjetaCalidadAire old) {
    super.didUpdateWidget(old);
    if (old.ubicacion != widget.ubicacion) _futuro = _consultar();
  }

  Future<CalidadAire> _consultar() =>
      AppScope.de(context).calidadAire.actual(widget.ubicacion)..ignore();

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    return Card(
      key: const Key('tarjeta_aire'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<CalidadAire>(
          future: _futuro,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return Semantics(
                label: 'Cargando la calidad del aire',
                child: const Row(children: [
                  SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3)),
                  SizedBox(width: 14),
                  Expanded(child: Text('Cargando la calidad del aire…')),
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
                          key: const Key('aire_error'),
                          style: textos.bodyLarge),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      key: const Key('aire_reintentar'),
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
            final a = snap.data!;
            final color = colorDe(context, a.gravedad);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Calidad del aire', style: textos.titleMedium),
                const SizedBox(height: 8),
                Semantics(
                  label: 'Calidad del aire ${a.nivel.nombre}, '
                      'índice ${a.indice}. Partículas finas '
                      '${a.pm25.toStringAsFixed(1)} microgramos por metro cúbico.',
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        Container(
                          key: const Key('aire_indice'),
                          constraints:
                              const BoxConstraints(minWidth: 64, minHeight: 64),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: fondoDe(context, a.gravedad),
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 3),
                          ),
                          child: Text('${a.indice}',
                              style: textos.headlineSmall?.copyWith(
                                  color: color, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.nivel.nombre,
                                  key: const Key('aire_nivel'),
                                  style: textos.titleLarge?.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                  'PM2,5: ${CalidadAire.microgramos(a.pm25)}'
                                  '${a.pm10 == null ? '' : ' · PM10: ${CalidadAire.microgramos(a.pm10!)}'}',
                                  style: textos.bodyMedium),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                for (final c in a.consejos) _FilaConsejo(consejo: c),
                const SizedBox(height: 6),
                Text('Datos: Open-Meteo Air Quality (índice US AQI)',
                    style: textos.bodySmall
                        ?.copyWith(color: esquema.onSurfaceVariant)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Color del tema según la gravedad (funciona en claro, oscuro y alto
/// contraste porque viene de [ColoresSalud]).
Color colorDe(BuildContext context, Gravedad g) {
  final c = ColoresSalud.de(context);
  return switch (g) {
    Gravedad.buena => c.abierto,
    Gravedad.atencion => c.emergencia,
    Gravedad.alerta => c.cerrado,
  };
}

Color fondoDe(BuildContext context, Gravedad g) {
  final c = ColoresSalud.de(context);
  return switch (g) {
    Gravedad.buena => c.abiertoFondo,
    Gravedad.atencion => c.emergenciaFondo,
    Gravedad.alerta => c.cerradoFondo,
  };
}

class _FilaConsejo extends StatelessWidget {
  final ConsejoSalud consejo;
  const _FilaConsejo({required this.consejo});

  @override
  Widget build(BuildContext context) {
    final c = ColoresSalud.de(context);
    final color = colorDe(context, consejo.gravedad);
    final icono = switch (consejo.tipo) {
      TipoConsejo.aire => consejo.gravedad == Gravedad.buena
          ? Icons.directions_walk
          : Icons.masks,
      TipoConsejo.uv => Icons.wb_sunny,
    };
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fondoDe(context, consejo.gravedad),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: c.grosorBorde > 1 ? 2 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(consejo.titulo,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: color)),
                const SizedBox(height: 2),
                Text(consejo.texto,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
