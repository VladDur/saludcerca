import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/errores.dart';
import '../models/recordatorio.dart';
import '../theme/app_theme.dart';
import '../widgets/mensajes.dart';
import 'recordatorio_form_screen.dart';

String formatoFechaHora(DateTime f) {
  const dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  const meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic'
  ];
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dias[f.weekday - 1]} ${f.day} ${meses[f.month - 1]} ${f.year}, '
      '${dos(f.hour)}:${dos(f.minute)}';
}

/// Pestaña Recordatorios: CRUD completo con baja lógica.
class RecordatoriosScreen extends StatefulWidget {
  const RecordatoriosScreen({super.key});

  @override
  State<RecordatoriosScreen> createState() => _RecordatoriosScreenState();
}

class _RecordatoriosScreenState extends State<RecordatoriosScreen> {
  bool _incluirPasados = false;
  late Future<List<Recordatorio>> _futuro = _cargar();

  Future<List<Recordatorio>> _cargar() => AppScope.de(context)
      .recordatorios
      .listar(incluirPasados: _incluirPasados);

  Future<void> _refrescar() async {
    final f = _cargar();
    setState(() {
      _futuro = f;
    });
    await f.catchError((_) => <Recordatorio>[]);
  }

  Future<void> _abrirFormulario([Recordatorio? r]) async {
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RecordatorioFormScreen(existente: r)),
    );
    if (guardado == true) _refrescar();
  }

  Future<void> _eliminar(Recordatorio r) async {
    final ok = await Mensajes.confirmar(context,
        titulo: 'Eliminar recordatorio',
        mensaje: '¿Eliminar "${r.titulo}"? Ya no aparecerá en tu lista.',
        textoAceptar: 'Sí, eliminar');
    if (!ok || !mounted) return;
    try {
      await AppScope.de(context).recordatorios.eliminar(r.id!);
      if (mounted) Mensajes.exito(context, 'Recordatorio eliminado.');
      _refrescar();
    } catch (e) {
      if (mounted) Mensajes.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis recordatorios')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('nuevo_recordatorio'),
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refrescar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Mostrar también los pasados',
                    style: textos.bodyLarge),
                value: _incluirPasados,
                onChanged: (v) {
                  _incluirPasados = v;
                  _refrescar();
                },
              ),
              FutureBuilder<List<Recordatorio>>(
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
                  final lista = snap.data!;
                  if (lista.isEmpty) {
                    return const EstadoVacio(
                      icono: Icons.alarm_off,
                      mensaje:
                          'No tienes recordatorios.\nPulsa "Nuevo" para crear uno.',
                    );
                  }
                  return Column(
                    children: [
                      for (final r in lista)
                        _TarjetaRecordatorio(
                          recordatorio: r,
                          alEditar: () => _abrirFormulario(r),
                          alEliminar: () => _eliminar(r),
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

class _TarjetaRecordatorio extends StatelessWidget {
  final Recordatorio recordatorio;
  final VoidCallback alEditar;
  final VoidCallback alEliminar;

  const _TarjetaRecordatorio({
    required this.recordatorio,
    required this.alEditar,
    required this.alEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final r = recordatorio;
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alEditar,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: esquema.primaryContainer,
                child: Icon(r.tipo.icono, color: esquema.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.titulo, style: textos.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${r.tipo.nombre} · ${formatoFechaHora(r.fechaHora)}',
                      style: textos.bodyMedium?.copyWith(
                          color: r.vencido
                              ? ColoresSalud.de(context).cerrado
                              : null),
                    ),
                    if (r.centroNombre != null) ...[
                      const SizedBox(height: 4),
                      Text(r.centroNombre!, style: textos.bodyMedium),
                    ],
                    if (r.descripcion.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(r.descripcion, style: textos.bodyLarge),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                      tooltip: 'Editar',
                      onPressed: alEditar,
                      icon: const Icon(Icons.edit)),
                  IconButton(
                      tooltip: 'Eliminar',
                      onPressed: alEliminar,
                      icon: const Icon(Icons.delete_outline)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
