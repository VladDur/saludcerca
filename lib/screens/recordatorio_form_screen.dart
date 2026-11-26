import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/validadores.dart';
import '../data/repositorios.dart';
import '../models/centro_salud.dart';
import '../models/recordatorio.dart';
import '../services/voz_servicio.dart';
import '../widgets/mensajes.dart';
import 'recordatorios_screen.dart';

/// Formulario para crear (CREATE) o editar (UPDATE) un recordatorio.
/// Devuelve `true` al cerrar si se guardó.
class RecordatorioFormScreen extends StatefulWidget {
  final Recordatorio? existente;
  final CentroSalud? centro; // centro sugerido desde el detalle

  const RecordatorioFormScreen({super.key, this.existente, this.centro});

  @override
  State<RecordatorioFormScreen> createState() => _RecordatorioFormScreenState();
}

class _RecordatorioFormScreenState extends State<RecordatorioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _tituloCtrl =
      TextEditingController(text: widget.existente?.titulo ?? '');
  late final _descripcionCtrl =
      TextEditingController(text: widget.existente?.descripcion ?? '');
  late TipoRecordatorio _tipo = widget.existente?.tipo ?? TipoRecordatorio.cita;
  late DateTime? _fechaHora = widget.existente?.fechaHora;
  late String? _centroId = widget.existente?.centroId ?? widget.centro?.id;
  List<CentroSalud> _centros = [];
  bool _guardando = false;
  bool _intentoGuardar = false;
  final _tituloFoco = FocusNode();

  // Dictado por voz del título.
  bool _escuchando = false;
  String _parcial = '';
  VozServicio? _voz;

  bool get _esEdicion => widget.existente != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarCentros());
  }

  @override
  void dispose() {
    if (_escuchando) _voz?.detener();
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _tituloFoco.dispose();
    super.dispose();
  }

  Future<void> _cargarCentros() async {
    try {
      final lista =
          await AppScope.de(context).centros.buscar(const FiltroCentros());
      if (mounted) setState(() => _centros = lista);
    } catch (_) {
      // El centro es opcional: si falla la carga, el formulario sigue útil.
    }
  }

  /// Escucha al usuario y pone lo que dijo en el título. El usuario revisa
  /// el texto y lo corrige con el teclado antes de guardar.
  Future<void> _dictar() async {
    final voz = _voz = AppScope.de(context).voz;
    if (_escuchando) {
      await voz.detener();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _escuchando = true;
      _parcial = '';
    });
    try {
      final texto = await voz.dictar(
          alParcial: (p) => mounted ? setState(() => _parcial = p) : null);
      if (!mounted) return;
      final titulo = textoDictadoComoTitulo(texto);
      _tituloCtrl.value = TextEditingValue(
          text: titulo,
          selection: TextSelection.collapsed(offset: titulo.length));
      setState(() => _escuchando = false);
      _tituloFoco.requestFocus();
      Mensajes.exito(context, 'Revisa el título y corrígelo si hace falta.');
    } on VozException catch (e) {
      if (!mounted) return;
      setState(() => _escuchando = false);
      Mensajes.error(context, e.mensaje);
    } catch (e) {
      if (!mounted) return;
      setState(() => _escuchando = false);
      Mensajes.error(context, const VozException(TipoErrorVoz.otro).mensaje);
    }
  }

  Future<void> _elegirFechaHora() async {
    final ahora = DateTime.now();
    final base = _fechaHora ?? ahora.add(const Duration(hours: 1));
    final fecha = await showDatePicker(
      context: context,
      initialDate: base.isBefore(ahora) ? ahora : base,
      firstDate: DateTime(ahora.year, ahora.month, ahora.day),
      lastDate: ahora.add(const Duration(days: 730)),
      helpText: 'Elige el día',
    );
    if (fecha == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      helpText: 'Elige la hora',
    );
    if (hora == null) return;
    setState(() => _fechaHora =
        DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute));
  }

  String? get _errorFecha {
    if (_fechaHora == null) return 'Elige la fecha y la hora';
    if (!_esEdicion && _fechaHora!.isBefore(DateTime.now())) {
      return 'La fecha debe ser futura';
    }
    return null;
  }

  Future<void> _guardar() async {
    setState(() => _intentoGuardar = true);
    final formularioOk = _formKey.currentState!.validate();
    if (!formularioOk || _errorFecha != null || _guardando) {
      Mensajes.error(context, 'Revisa los campos marcados en rojo.');
      return;
    }
    setState(() => _guardando = true);
    final r = Recordatorio(
      id: widget.existente?.id,
      titulo: _tituloCtrl.text,
      descripcion: _descripcionCtrl.text,
      tipo: _tipo,
      fechaHora: _fechaHora!,
      centroId: _centroId,
    );
    try {
      final repo = AppScope.de(context).recordatorios;
      _esEdicion ? await repo.actualizar(r) : await repo.crear(r);
      if (!mounted) return;
      Mensajes.exito(context,
          _esEdicion ? 'Recordatorio actualizado.' : 'Recordatorio guardado.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) Mensajes.error(context, e);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final errorFecha = _intentoGuardar ? _errorFecha : null;
    final idsCentros = _centros.map((c) => c.id).toSet();

    return Scaffold(
      appBar: AppBar(
          title:
              Text(_esEdicion ? 'Editar recordatorio' : 'Nuevo recordatorio')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: _intentoGuardar
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Tipo', style: textos.titleMedium),
              const SizedBox(height: 8),
              // Wrap en vez de SegmentedButton: con texto grande baja de línea.
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final t in TipoRecordatorio.values)
                    ChoiceChip(
                      avatar: Icon(t.icono),
                      showCheckmark: false,
                      label: Text(t.nombre),
                      selected: _tipo == t,
                      onSelected: (_) => setState(() => _tipo = t),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('recordatorio_titulo'),
                controller: _tituloCtrl,
                focusNode: _tituloFoco,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Ej.: Control de presión',
                ),
                validator: Validadores.titulo,
              ),
              _BotonDictar(
                escuchando: _escuchando,
                parcial: _parcial,
                onPressed: _guardando ? null : _dictar,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionCtrl,
                maxLength: 250,
                maxLines: 3,
                minLines: 1,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                    labelText: 'Detalle (opcional)',
                    hintText: 'Ej.: llevar carnet y análisis'),
                validator: Validadores.maximo(250),
              ),
              const SizedBox(height: 8),
              Semantics(
                button: true,
                label: 'Fecha y hora',
                child: InkWell(
                  key: const Key('recordatorio_fecha'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: _elegirFechaHora,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Fecha y hora',
                      prefixIcon: const Icon(Icons.calendar_month),
                      errorText: errorFecha,
                    ),
                    child: Text(
                      _fechaHora == null
                          ? 'Toca para elegir'
                          : formatoFechaHora(_fechaHora!),
                      style: TextStyle(
                          fontSize: 18,
                          color: _fechaHora == null
                              ? textos.bodyMedium?.color
                              : esquema.onSurface),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: idsCentros.contains(_centroId) ? _centroId : null,
                style: TextStyle(fontSize: 18, color: esquema.onSurface),
                decoration: const InputDecoration(
                  labelText: 'Centro de salud (opcional)',
                  prefixIcon: Icon(Icons.local_hospital_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Ninguno')),
                  for (final c in _centros)
                    DropdownMenuItem(
                        value: c.id,
                        child: Text(c.nombre, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _centroId = v),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                key: const Key('guardar_recordatorio'),
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 3))
                    : const Icon(Icons.save),
                label: Text(_esEdicion ? 'Guardar cambios' : 'Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón grande para dictar el título con la voz (mínimo 48 dp / 44 pt).
/// Mientras escucha muestra "Escuchando…" y lo que va reconociendo.
class _BotonDictar extends StatelessWidget {
  final bool escuchando;
  final String parcial;
  final VoidCallback? onPressed;

  const _BotonDictar(
      {required this.escuchando, required this.parcial, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: escuchando,
          child: OutlinedButton.icon(
            key: const Key('recordatorio_dictar'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: escuchando ? esquema.error : null,
              side: BorderSide(
                  color: escuchando ? esquema.error : esquema.outline,
                  width: escuchando ? 2 : 1),
            ),
            onPressed: onPressed,
            icon: Icon(escuchando ? Icons.stop_circle : Icons.mic, size: 28),
            label: Text(escuchando
                ? 'Escuchando… toca para terminar'
                : 'Dictar el título con la voz'),
          ),
        ),
        if (escuchando)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              parcial.isEmpty
                  ? 'Habla ahora. Ej.: «sacar ficha en el hospital Miraflores»'
                  : '«$parcial»',
              key: const Key('recordatorio_dictado_parcial'),
              style: textos.bodyLarge?.copyWith(
                  fontStyle: parcial.isEmpty ? FontStyle.italic : null),
            ),
          ),
      ],
    );
  }
}
