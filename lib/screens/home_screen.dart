import 'package:flutter/material.dart';

import '../data/centros_ejemplo.dart';
import '../main.dart';
import '../models/centro_salud.dart';
import '../theme/app_theme.dart';
import '../widgets/centro_card.dart';

enum _Filtro { todos, abiertos, emergencias }

/// Pantalla 2: Inicio con los centros de salud cercanos.
class HomeScreen extends StatefulWidget {
  final String nombreUsuario;

  const HomeScreen({super.key, required this.nombreUsuario});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _busqueda = '';
  _Filtro _filtro = _Filtro.todos;

  List<CentroSalud> get _centrosFiltrados {
    final texto = _busqueda.toLowerCase();
    final lista = centrosEjemplo.where((c) {
      final coincide = texto.isEmpty ||
          c.nombre.toLowerCase().contains(texto) ||
          c.zona.toLowerCase().contains(texto) ||
          c.ciudad.toLowerCase().contains(texto);
      switch (_filtro) {
        case _Filtro.todos:
          return coincide;
        case _Filtro.abiertos:
          return coincide && c.abiertoAhora;
        case _Filtro.emergencias:
          return coincide && c.atiendeEmergencias;
      }
    }).toList();
    lista.sort((a, b) => a.distanciaKm.compareTo(b.distanciaKm));
    return lista;
  }

  void _cerrarSesion() {
    Navigator.pushReplacementNamed(context, Rutas.login);
  }

  Widget _chip(String texto, _Filtro valor) {
    return ChoiceChip(
      label: Text(texto, style: const TextStyle(fontSize: 16)),
      selected: _filtro == valor,
      onSelected: (_) => setState(() => _filtro = valor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final centros = _centrosFiltrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SaludCerca'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Hola, ${widget.nombreUsuario}', style: textos.headlineMedium),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.my_location,
                    size: 20, color: AppColors.secundario),
                const SizedBox(width: 6),
                Text('Tu ubicación: La Paz (ejemplo)', style: textos.bodyMedium),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre o zona',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _busqueda = v),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Todos', _Filtro.todos),
                _chip('Abiertos ahora', _Filtro.abiertos),
                _chip('Emergencias', _Filtro.emergencias),
              ],
            ),
            const SizedBox(height: 20),
            Text('Centros de salud cercanos (${centros.length})',
                style: textos.titleLarge),
            const SizedBox(height: 12),
            if (centros.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text('No encontramos centros con esa búsqueda.',
                    textAlign: TextAlign.center, style: textos.bodyLarge),
              )
            else
              ...centros.map(
                (c) => CentroCard(
                  centro: c,
                  onTap: () =>
                      Navigator.pushNamed(context, Rutas.detalle, arguments: c),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
