import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/errores.dart';
import '../data/repositorios.dart';
import '../models/centro_salud.dart';
import '../theme/app_theme.dart';
import '../widgets/centro_card.dart';
import '../widgets/mensajes.dart';
import 'detalle_centro_screen.dart';

/// Pestaña Centros: consulta dinámica a Supabase con búsqueda y filtros.
class CentrosScreen extends StatefulWidget {
  const CentrosScreen({super.key});

  @override
  State<CentrosScreen> createState() => _CentrosScreenState();
}

class _CentrosScreenState extends State<CentrosScreen> {
  FiltroCentros _filtro = const FiltroCentros();
  bool _soloAbiertos = false;
  late Future<List<CentroSalud>> _futuro = _consultar();
  Timer? _espera;

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }

  Future<List<CentroSalud>> _consultar() =>
      AppScope.de(context).centros.buscar(_filtro);

  void _aplicar(FiltroCentros nuevo) {
    setState(() {
      _filtro = nuevo;
      _futuro = _consultar();
    });
  }

  void _buscarTexto(String texto) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400),
        () => _aplicar(_filtro.copiar(texto: texto)));
  }

  Future<void> _refrescar() async {
    final f = _consultar();
    setState(() {
      _futuro = f;
    });
    await f.catchError((_) => <CentroSalud>[]);
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('SaludCerca')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refrescar,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Centros de salud', style: textos.headlineMedium),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.my_location,
                      size: 20, color: ColoresSalud.de(context).acento),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Distancias desde Plaza Murillo, La Paz',
                        style: textos.bodyMedium),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('buscar_centros'),
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'Buscar por nombre o zona',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _buscarTexto,
              ),
              const SizedBox(height: 12),
              _FilaFiltros(
                children: [
                  for (final c in const [null, 'La Paz', 'El Alto'])
                    ChoiceChip(
                      label: Text(c ?? 'Todas las ciudades'),
                      selected: _filtro.ciudad == c,
                      onSelected: (_) =>
                          _aplicar(_filtro.copiar(ciudad: () => c)),
                    ),
                  FilterChip(
                    label: const Text('Abiertos ahora'),
                    selected: _soloAbiertos,
                    onSelected: (v) => setState(() => _soloAbiertos = v),
                  ),
                  FilterChip(
                    label: const Text('Emergencias'),
                    selected: _filtro.soloEmergencias,
                    onSelected: (v) =>
                        _aplicar(_filtro.copiar(soloEmergencias: v)),
                  ),
                ],
              ),
              _FilaFiltros(
                children: [
                  for (final t in [null, ...TipoCentro.values])
                    ChoiceChip(
                      label: Text(t?.nombre ?? 'Todos los tipos'),
                      selected: _filtro.tipo == t,
                      onSelected: (_) =>
                          _aplicar(_filtro.copiar(tipo: () => t)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<CentroSalud>>(
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
                      alPulsar: _refrescar,
                    );
                  }
                  var centros = snap.data!;
                  if (_soloAbiertos) {
                    centros = centros.where((c) => c.estaAbierto()).toList();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          'Encontramos ${centros.length} '
                          '${centros.length == 1 ? 'centro' : 'centros'}',
                          style: textos.titleLarge),
                      const SizedBox(height: 12),
                      if (centros.isEmpty)
                        const EstadoVacio(
                          icono: Icons.search_off,
                          mensaje: 'No encontramos centros con esa búsqueda.',
                        )
                      else
                        ...centros.map(
                          (c) => CentroCard(
                            centro: c,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      DetalleCentroScreen(centro: c)),
                            ),
                          ),
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

/// Fila de filtros con desplazamiento horizontal: así la lista de centros
/// queda visible aun con texto grande.
class _FilaFiltros extends StatelessWidget {
  final List<Widget> children;

  const _FilaFiltros({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final c in children)
            Padding(padding: const EdgeInsets.only(right: 8), child: c),
        ],
      ),
    );
  }
}
