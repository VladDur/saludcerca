import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/errores.dart';
import '../core/validadores.dart';
import '../models/favorito.dart';
import '../widgets/centro_card.dart';
import '../widgets/mensajes.dart';
import 'detalle_centro_screen.dart';

/// Pide (o edita) la nota personal de un favorito. Devuelve null si cancela.
Future<String?> pedirNotaFavorito(BuildContext context, String nombreCentro,
    {String inicial = ''}) {
  final ctrl = TextEditingController(text: inicial);
  final formKey = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(inicial.isEmpty ? 'Guardar en favoritos' : 'Editar nota'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nombreCentro, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('nota_favorito'),
              controller: ctrl,
              autofocus: true,
              maxLength: 200,
              maxLines: 3,
              minLines: 1,
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                hintText: 'Ej.: aquí atiende mi doctora',
              ),
              validator: Validadores.maximo(200),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(ctx, ctrl.text.trim());
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

/// Pestaña Favoritos: READ, UPDATE (nota) y baja lógica.
class FavoritosScreen extends StatefulWidget {
  const FavoritosScreen({super.key});

  @override
  State<FavoritosScreen> createState() => _FavoritosScreenState();
}

class _FavoritosScreenState extends State<FavoritosScreen> {
  late Future<List<Favorito>> _futuro = _cargar();

  Future<List<Favorito>> _cargar() => AppScope.de(context).favoritos.listar();

  Future<void> _refrescar() async {
    final f = _cargar();
    setState(() {
      _futuro = f;
    });
    await f.catchError((_) => <Favorito>[]);
  }

  Future<void> _editarNota(Favorito f) async {
    final nota =
        await pedirNotaFavorito(context, f.centro!.nombre, inicial: f.nota);
    if (nota == null || !mounted) return;
    try {
      await AppScope.de(context).favoritos.actualizarNota(f.id, nota);
      if (mounted) Mensajes.exito(context, 'Nota actualizada.');
      _refrescar();
    } catch (e) {
      if (mounted) Mensajes.error(context, e);
    }
  }

  Future<void> _quitar(Favorito f) async {
    final ok = await Mensajes.confirmar(context,
        titulo: 'Quitar de favoritos',
        mensaje: '¿Quitar "${f.centro!.nombre}" de tus favoritos?',
        textoAceptar: 'Sí, quitar');
    if (!ok || !mounted) return;
    try {
      await AppScope.de(context).favoritos.quitar(f.id);
      if (mounted) Mensajes.exito(context, 'Quitado de tus favoritos.');
      _refrescar();
    } catch (e) {
      if (mounted) Mensajes.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis favoritos')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refrescar,
          child: FutureBuilder<List<Favorito>>(
            future: _futuro,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return ListView(children: [
                  EstadoVacio(
                    icono: Icons.cloud_off,
                    mensaje: mensajeError(snap.error!),
                    textoBoton: 'Reintentar',
                    alPulsar: _refrescar,
                  ),
                ]);
              }
              final lista = snap.data!;
              if (lista.isEmpty) {
                return ListView(children: const [
                  EstadoVacio(
                    icono: Icons.favorite_border,
                    mensaje:
                        'Aún no tienes favoritos.\nAbre un centro y pulsa "Guardar en favoritos".',
                  ),
                ]);
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final f in lista)
                    CentroCard(
                      centro: f.centro!,
                      nota: f.nota,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                DetalleCentroScreen(centro: f.centro!)),
                      ).then((_) => _refrescar()),
                      accion: PopupMenuButton<String>(
                        tooltip: 'Opciones',
                        iconSize: 28,
                        onSelected: (v) =>
                            v == 'nota' ? _editarNota(f) : _quitar(f),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'nota',
                              child: ListTile(
                                  leading: Icon(Icons.edit_note),
                                  title: Text('Editar nota'))),
                          PopupMenuItem(
                              value: 'quitar',
                              child: ListTile(
                                  leading: Icon(Icons.heart_broken),
                                  title: Text('Quitar'))),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
