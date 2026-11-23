import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_scope.dart';
import '../core/errores.dart';
import '../data/repositorios.dart';
import '../models/centro_salud.dart';
import '../models/farmacia.dart';
import '../services/api_cliente.dart';
import '../services/geocodificacion_servicio.dart';
import '../services/ubicacion_servicio.dart';
import '../theme/app_theme.dart';
import '../widgets/centro_card.dart';
import '../widgets/mensajes.dart';
import 'detalle_centro_screen.dart';
import 'farmacias_screen.dart';

LatLng aLatLng(Ubicacion u) => LatLng(u.lat, u.lng);

/// HU-12: mapa interactivo de OpenStreetMap con centros de salud, farmacias
/// de turno y la ubicación del usuario. Incluye búsqueda de direcciones con
/// Nominatim.
class MapaScreen extends StatefulWidget {
  /// Punto donde centrar el mapa al abrirlo (por ejemplo, un centro).
  final Ubicacion? enfocar;

  /// Marcador que se muestra resaltado.
  final String? seleccionId;

  /// Abre el mapa mostrando solo las farmacias de turno.
  final bool soloFarmacias;

  /// Las pruebas de widgets no descargan teselas de internet.
  @visibleForTesting
  static bool cargarTeselas = true;

  const MapaScreen(
      {super.key, this.enfocar, this.seleccionId, this.soloFarmacias = false});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  final _mapa = MapController();
  final _busqueda = TextEditingController();

  late bool _verCentros = !widget.soloFarmacias;
  bool _verFarmacias = true;

  ResultadoUbicacion? _ubicacion;
  List<CentroSalud> _centros = const [];
  List<TurnoFarmacia> _turnos = const [];
  bool _cargando = true;
  Object? _errorDatos;

  bool _buscando = false;
  List<LugarEncontrado>? _resultados;
  String? _errorBusqueda;
  LugarEncontrado? _lugarElegido;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _busqueda.dispose();
    _mapa.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final deps = AppScope.de(context);
    setState(() {
      _cargando = true;
      _errorDatos = null;
    });
    try {
      final resultados = await Future.wait([
        deps.ubicacion.obtener(),
        deps.centros.buscar(const FiltroCentros()),
        deps.farmacias.deTurno(fechaTurnoVigente(DateTime.now())),
      ]);
      if (!mounted) return;
      setState(() {
        _ubicacion = resultados[0] as ResultadoUbicacion;
        _centros = resultados[1] as List<CentroSalud>;
        _turnos = resultados[2] as List<TurnoFarmacia>;
      });
      if (widget.enfocar == null && _ubicacion!.esGps) {
        _mover(_ubicacion!.ubicacion, 15);
      }
    } catch (e) {
      if (mounted) setState(() => _errorDatos = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mover(Ubicacion u, double zoom) {
    try {
      _mapa.move(aLatLng(u), zoom);
    } catch (_) {
      // El mapa aún no está listo; se queda en la posición inicial.
    }
  }

  Future<void> _buscar() async {
    final texto = _busqueda.text.trim();
    FocusScope.of(context).unfocus();
    if (texto.length < 3) {
      setState(() => _errorBusqueda = 'Escribe al menos 3 letras.');
      return;
    }
    setState(() {
      _buscando = true;
      _errorBusqueda = null;
      _resultados = null;
    });
    try {
      final r = await AppScope.de(context).geocodificacion.buscar(texto);
      if (!mounted) return;
      setState(() {
        _resultados = r;
        if (r.isEmpty) {
          _errorBusqueda = 'No encontramos "$texto" en La Paz ni El Alto.';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _errorBusqueda = mensajeError(e));
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _elegirLugar(LugarEncontrado l) {
    setState(() {
      _lugarElegido = l;
      _resultados = null;
    });
    _mover(l.ubicacion, 16);
  }

  Ubicacion get _origen => _ubicacion?.ubicacion ?? Ubicacion.referencia;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final colores = ColoresSalud.de(context);
    final inicio = widget.enfocar ?? _origen;

    final marcadores = <Marker>[
      if (_verCentros)
        for (final c in _centros)
          _marcador(
            id: c.id,
            punto: c.ubicacion,
            icono: iconoTipoCentro(c.tipo),
            fondo: esquema.primary,
            frente: esquema.onPrimary,
            etiqueta: 'Centro: ${c.nombre}',
            alTocar: () => _mostrarCentro(c),
          ),
      if (_verFarmacias)
        for (final t in _turnos)
          _marcador(
            id: t.farmacia.id,
            punto: t.farmacia.ubicacion,
            icono: Icons.local_pharmacy,
            fondo: esquema.tertiary,
            frente: esquema.onTertiary,
            etiqueta: 'Farmacia de turno: ${t.farmacia.nombre}',
            alTocar: () => mostrarDetalleFarmacia(context, t,
                origen: _origen, ahora: DateTime.now(), conMapa: false),
          ),
      if (_lugarElegido != null)
        Marker(
          key: const Key('marcador_busqueda'),
          point: aLatLng(_lugarElegido!.ubicacion),
          width: 48,
          height: 48,
          alignment: Alignment.topCenter,
          child: Semantics(
            label: 'Lugar buscado: ${_lugarElegido!.nombre}',
            child: Icon(Icons.location_pin, size: 48, color: colores.cerrado),
          ),
        ),
      Marker(
        key: const Key('marcador_usuario'),
        point: aLatLng(_origen),
        width: 34,
        height: 34,
        // IgnorePointer: no bloquea los toques sobre marcadores cercanos.
        child: IgnorePointer(
            child: Semantics(
          label: _ubicacion?.esGps == true
              ? 'Tu ubicación'
              : 'Plaza Murillo (referencia)',
          child: Container(
            decoration: BoxDecoration(
              color: colores.acento,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: const [
                BoxShadow(blurRadius: 6, color: Colors.black38)
              ],
            ),
          ),
        )),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Mapa')),
      body: Column(
        children: [
          _barraBusqueda(context),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  key: const Key('mapa_osm'),
                  mapController: _mapa,
                  options: MapOptions(
                    initialCenter: aLatLng(inicio),
                    initialZoom: widget.enfocar != null ? 16 : 13,
                    minZoom: 10,
                    maxZoom: 18,
                    interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  ),
                  children: [
                    if (MapaScreen.cargarTeselas)
                      TileLayer(
                        // Teselas oficiales de OpenStreetMap (HTTPS).
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.saludcerca',
                        tileProvider: NetworkTileProvider(
                            headers: {'User-Agent': ApiCliente.userAgent}),
                        maxNativeZoom: 19,
                      ),
                    MarkerLayer(markers: marcadores),
                    const RichAttributionWidget(
                      alignment: AttributionAlignment.bottomLeft,
                      attributions: [
                        TextSourceAttribution(
                            '© colaboradores de OpenStreetMap'),
                      ],
                    ),
                  ],
                ),
                if (_cargando)
                  const Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: Center(child: CircularProgressIndicator())),
                if (_errorDatos != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Card(
                      child: EstadoVacio(
                        icono: Icons.cloud_off,
                        mensaje: mensajeError(_errorDatos!),
                        textoBoton: 'Reintentar',
                        alPulsar: _cargar,
                      ),
                    ),
                  ),
                if (_resultados != null || _errorBusqueda != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: _listaResultados(context),
                  ),
              ],
            ),
          ),
          _barraInferior(context),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton(
          key: const Key('mapa_mi_ubicacion'),
          tooltip: 'Ir a mi ubicación',
          onPressed: () async {
            final r =
                await AppScope.de(context).ubicacion.obtener(forzar: true);
            if (!mounted) return;
            setState(() => _ubicacion = r);
            _mover(r.ubicacion, 15);
            if (!r.esGps && context.mounted) {
              Mensajes.error(context,
                  '${r.motivo}. Mostramos Plaza Murillo como referencia.');
            }
          },
          child: const Icon(Icons.my_location),
        ),
      ),
    );
  }

  Marker _marcador({
    required String id,
    required Ubicacion punto,
    required IconData icono,
    required Color fondo,
    required Color frente,
    required String etiqueta,
    required VoidCallback alTocar,
  }) {
    final elegido = id == widget.seleccionId;
    final tam = elegido ? 56.0 : 48.0; // ≥ 48 dp / 44 pt
    return Marker(
      key: Key('marcador_$id'),
      point: aLatLng(punto),
      width: tam,
      height: tam,
      child: Semantics(
        button: true,
        label: etiqueta,
        child: GestureDetector(
          onTap: alTocar,
          child: Container(
            decoration: BoxDecoration(
              color: fondo,
              shape: BoxShape.circle,
              border: Border.all(
                  color: elegido ? frente : Colors.white,
                  width: elegido ? 4 : 2),
              boxShadow: const [
                BoxShadow(blurRadius: 4, color: Colors.black38)
              ],
            ),
            child: Icon(icono, color: frente, size: elegido ? 30 : 26),
          ),
        ),
      ),
    );
  }

  Widget _barraBusqueda(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('mapa_buscar'),
              controller: _busqueda,
              style: const TextStyle(fontSize: 18),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _buscar(),
              decoration: const InputDecoration(
                hintText: 'Buscar dirección o zona',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buscando
              ? const SizedBox(
                  width: 48,
                  height: 48,
                  child: Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator()))
              : IconButton.filled(
                  key: const Key('mapa_buscar_boton'),
                  tooltip: 'Buscar',
                  onPressed: _buscar,
                  icon: const Icon(Icons.travel_explore),
                ),
        ],
      ),
    );
  }

  Widget _listaResultados(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Card(
      key: const Key('mapa_resultados'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorBusqueda != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_errorBusqueda!,
                  key: const Key('mapa_busqueda_error'),
                  style: textos.bodyLarge),
            ),
          for (final l in _resultados ?? const <LugarEncontrado>[])
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.place),
              title: Text(l.nombre, style: textos.titleMedium),
              subtitle: Text(l.direccionCompleta,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => _elegirLugar(l),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() {
                _resultados = null;
                _errorBusqueda = null;
              }),
              child: const Text('Cerrar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barraInferior(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            FilterChip(
              key: const Key('mapa_filtro_centros'),
              avatar: const Icon(Icons.local_hospital),
              label: Text('Centros (${_centros.length})'),
              selected: _verCentros,
              onSelected: (v) => setState(() => _verCentros = v),
            ),
            const SizedBox(width: 8),
            FilterChip(
              key: const Key('mapa_filtro_farmacias'),
              avatar: const Icon(Icons.local_pharmacy),
              label: Text('Farmacias de turno (${_turnos.length})'),
              selected: _verFarmacias,
              onSelected: (v) => setState(() => _verFarmacias = v),
            ),
          ]),
        ),
      ),
    );
  }

  void _mostrarCentro(CentroSalud c) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(c.nombre, style: Theme.of(ctx).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                  '${c.tipo.nombre} · ${c.zona} · '
                  'a ${c.distanciaTexto(_origen)}',
                  style: Theme.of(ctx).textTheme.bodyLarge),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('mapa_ver_detalle'),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DetalleCentroScreen(centro: c)));
                },
                icon: const Icon(Icons.info_outline),
                label: const Text('Ver detalle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
