import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/errores.dart';
import '../models/centro_salud.dart';
import '../models/farmacia.dart';
import '../services/ubicacion_servicio.dart';
import '../theme/app_theme.dart';
import '../widgets/etiqueta_estado.dart';
import '../widgets/fila_info.dart';
import '../widgets/mensajes.dart';
import '../widgets/panel_ubicacion.dart';
import 'mapa_screen.dart';

/// HU-03: farmacias de turno de hoy o mañana, ordenadas por cercanía (HU-13).
class FarmaciasScreen extends StatefulWidget {
  /// Momento "actual"; las pruebas lo fijan para no depender del reloj.
  final DateTime Function() ahora;

  const FarmaciasScreen({super.key, this.ahora = DateTime.now});

  @override
  State<FarmaciasScreen> createState() => _FarmaciasScreenState();
}

class _FarmaciasScreenState extends State<FarmaciasScreen> {
  String? _ciudad;
  bool _manana = false;
  ResultadoUbicacion? _ubicacion;
  late Future<List<TurnoFarmacia>> _futuro = _consultar();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarUbicacion());
  }

  Future<void> _cargarUbicacion({bool forzar = false}) async {
    if (forzar) setState(() => _ubicacion = null);
    final r = await AppScope.de(context).ubicacion.obtener(forzar: forzar);
    if (mounted) setState(() => _ubicacion = r);
  }

  DateTime get _fecha {
    final vigente = fechaTurnoVigente(widget.ahora());
    return _manana
        ? DateTime(vigente.year, vigente.month, vigente.day + 1)
        : vigente;
  }

  Future<List<TurnoFarmacia>> _consultar() =>
      AppScope.de(context).farmacias.deTurno(_fecha, ciudad: _ciudad)
        ..ignore(); // el error lo muestra el FutureBuilder

  void _recargar() => setState(() {
        _futuro = _consultar();
      });

  Future<void> _refrescar() async {
    _recargar();
    await _futuro.catchError((_) => <TurnoFarmacia>[]);
  }

  Ubicacion get _origen => _ubicacion?.ubicacion ?? Ubicacion.referencia;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmacias de turno'),
        actions: [
          IconButton(
            key: const Key('farmacias_mapa'),
            tooltip: 'Ver en el mapa',
            icon: const Icon(Icons.map),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MapaScreen(soloFarmacias: true))),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refrescar,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PanelUbicacion(
                resultado: _ubicacion,
                onActualizar: () => _cargarUbicacion(forzar: true),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    key: const Key('turno_hoy'),
                    label: const Text('De turno hoy'),
                    selected: !_manana,
                    onSelected: (_) {
                      _manana = false;
                      _recargar();
                    },
                  ),
                  ChoiceChip(
                    key: const Key('turno_manana'),
                    label: const Text('Mañana'),
                    selected: _manana,
                    onSelected: (_) {
                      _manana = true;
                      _recargar();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final c in const [null, 'La Paz', 'El Alto'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c ?? 'Todas las ciudades'),
                        selected: _ciudad == c,
                        onSelected: (_) {
                          _ciudad = c;
                          _recargar();
                        },
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<TurnoFarmacia>>(
                future: _futuro,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return EstadoVacio(
                      icono: Icons.cloud_off,
                      mensaje: mensajeError(snap.error!),
                      textoBoton: 'Reintentar',
                      alPulsar: _recargar,
                    );
                  }
                  final turnos = ordenarPorCercania(snap.data!, _origen,
                      (TurnoFarmacia t) => t.farmacia.ubicacion);
                  if (turnos.isEmpty) {
                    return const EstadoVacio(
                      icono: Icons.local_pharmacy_outlined,
                      mensaje: 'No hay farmacias de turno registradas para '
                          'ese día y ciudad.',
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          '${turnos.length} '
                          '${turnos.length == 1 ? 'farmacia' : 'farmacias'} '
                          'de turno ${_manana ? 'mañana' : 'hoy'}',
                          key: const Key('farmacias_total'),
                          style: textos.titleLarge),
                      const SizedBox(height: 12),
                      for (final t in turnos)
                        TarjetaFarmacia(
                          turno: t,
                          origen: _origen,
                          ahora: widget.ahora(),
                          onTap: () => mostrarDetalleFarmacia(context, t,
                              origen: _origen, ahora: widget.ahora()),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TarjetaFarmacia extends StatelessWidget {
  final TurnoFarmacia turno;
  final Ubicacion origen;
  final DateTime ahora;
  final VoidCallback onTap;

  const TarjetaFarmacia({
    super.key,
    required this.turno,
    required this.origen,
    required this.ahora,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final acento = ColoresSalud.de(context).acento;
    final f = turno.farmacia;
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
                backgroundColor: esquema.secondaryContainer,
                child: Icon(Icons.local_pharmacy,
                    color: esquema.onSecondaryContainer, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.nombre, style: textos.titleMedium),
                    const SizedBox(height: 4),
                    Text('${f.zona} · ${f.ciudad}', style: textos.bodyMedium),
                    const SizedBox(height: 4),
                    Text(turno.horarioTexto(ahora), style: textos.bodyMedium),
                    const SizedBox(height: 10),
                    turno.vigenteEn(ahora)
                        ? EtiquetaEstado.abierto(true)
                        : EtiquetaEstado.info('Próximo turno', Icons.schedule),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(children: [
                Icon(Icons.place, color: acento),
                Text(formatearDistancia(origen.distanciaKm(f.ubicacion)),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: acento)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hoja inferior con el detalle de una farmacia de turno.
Future<void> mostrarDetalleFarmacia(BuildContext context, TurnoFarmacia t,
    {required Ubicacion origen, required DateTime ahora, bool conMapa = true}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final f = t.farmacia;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(f.nombre, style: Theme.of(ctx).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                t.vigenteEn(ahora)
                    ? EtiquetaEstado.abierto(true)
                    : EtiquetaEstado.info('Próximo turno', Icons.schedule),
                EtiquetaEstado.info(
                    'A ${formatearDistancia(origen.distanciaKm(f.ubicacion))}',
                    Icons.place),
              ]),
              const SizedBox(height: 8),
              FilaInfo(
                  icono: Icons.location_on,
                  titulo: 'Dirección',
                  valor: '${f.direccion}, ${f.ciudad}'),
              FilaInfo(
                  icono: Icons.schedule,
                  titulo: 'Turno',
                  valor: t.horarioTexto(ahora)),
              FilaInfo(
                  icono: Icons.phone, titulo: 'Teléfono', valor: f.telefono),
              if (conMapa) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('farmacia_ver_mapa'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => MapaScreen(
                              enfocar: f.ubicacion,
                              seleccionId: f.id,
                              soloFarmacias: true)),
                    );
                  },
                  icon: const Icon(Icons.map),
                  label: const Text('Ver en el mapa'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
