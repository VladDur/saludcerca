import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/errores.dart';
import '../core/validadores.dart';
import '../data/repositorios.dart';
import '../models/perfil.dart';
import '../widgets/mensajes.dart';

/// Pestaña Perfil: datos del usuario (READ/UPDATE), accesibilidad (HU-06),
/// modo oscuro y cierre de sesión.
class PerfilScreen extends StatefulWidget {
  final UsuarioActual usuario;

  const PerfilScreen({super.key, required this.usuario});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _contactoNombreCtrl = TextEditingController();
  final _contactoTelefonoCtrl = TextEditingController();
  String _ciudad = 'La Paz';
  Perfil? _perfil;
  Object? _error;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    for (final c in [
      _nombreCtrl,
      _telefonoCtrl,
      _contactoNombreCtrl,
      _contactoTelefonoCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final p = await AppScope.de(context).perfil.obtener();
      if (!mounted) return;
      setState(() {
        _perfil = p;
        _nombreCtrl.text = p.nombreCompleto;
        _telefonoCtrl.text = p.telefono ?? '';
        _ciudad = p.ciudad;
        _contactoNombreCtrl.text = p.contactoEmergenciaNombre ?? '';
        _contactoTelefonoCtrl.text = p.contactoEmergenciaTelefono ?? '';
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!_formKey.currentState!.validate()) {
      Mensajes.error(context, 'Revisa los campos marcados en rojo.');
      return;
    }
    setState(() => _guardando = true);
    final nuevo = Perfil(
      id: _perfil!.id,
      nombreCompleto: _nombreCtrl.text,
      telefono: _telefonoCtrl.text,
      ciudad: _ciudad,
      contactoEmergenciaNombre: _contactoNombreCtrl.text,
      contactoEmergenciaTelefono: _contactoTelefonoCtrl.text,
    );
    try {
      await AppScope.de(context).perfil.actualizar(nuevo);
      if (!mounted) return;
      setState(() => _perfil = nuevo);
      Mensajes.exito(context, 'Tus datos se guardaron correctamente.');
    } catch (e) {
      if (mounted) Mensajes.error(context, e);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cerrarSesion() async {
    final ok = await Mensajes.confirmar(context,
        titulo: 'Cerrar sesión',
        mensaje: '¿Quieres salir de tu cuenta?',
        textoAceptar: 'Sí, salir');
    if (!ok || !mounted) return;
    try {
      await AppScope.de(context).auth.cerrarSesion();
    } catch (e) {
      if (mounted) Mensajes.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SeccionAccesibilidad(),
            const SizedBox(height: 16),
            if (_error != null)
              EstadoVacio(
                icono: Icons.cloud_off,
                mensaje: mensajeError(_error!),
                textoBoton: 'Reintentar',
                alPulsar: _cargar,
              )
            else if (_perfil == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              _formulario(context),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('cerrar_sesion'),
              onPressed: _cerrarSesion,
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _formulario(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Mis datos', style: textos.titleLarge),
              const SizedBox(height: 4),
              Text(widget.usuario.correo, style: textos.bodyMedium),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('perfil_nombre'),
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person_outline)),
                validator: Validadores.nombre,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('perfil_telefono'),
                controller: _telefonoCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                    labelText: 'Teléfono (opcional)',
                    prefixIcon: Icon(Icons.phone_outlined)),
                validator: Validadores.telefonoOpcional,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _ciudad,
                style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.onSurface),
                decoration: const InputDecoration(
                    labelText: 'Ciudad', prefixIcon: Icon(Icons.location_city)),
                items: const [
                  DropdownMenuItem(value: 'La Paz', child: Text('La Paz')),
                  DropdownMenuItem(value: 'El Alto', child: Text('El Alto')),
                ],
                onChanged: (v) => setState(() => _ciudad = v ?? 'La Paz'),
              ),
              const SizedBox(height: 20),
              Text('Contacto de emergencia', style: textos.titleMedium),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contactoNombreCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                    labelText: 'Nombre (opcional)',
                    prefixIcon: Icon(Icons.contact_emergency_outlined)),
                validator: Validadores.maximo(80),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _contactoTelefonoCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                    labelText: 'Teléfono (opcional)',
                    prefixIcon: Icon(Icons.phone_in_talk_outlined)),
                validator: Validadores.telefonoOpcional,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('guardar_perfil'),
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 3))
                    : const Icon(Icons.save),
                label: const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// HU-06 (texto grande, alto contraste) y modo oscuro. Los cambios se
/// aplican al instante en todas las pantallas y se guardan en el teléfono.
class _SeccionAccesibilidad extends StatelessWidget {
  const _SeccionAccesibilidad();

  @override
  Widget build(BuildContext context) {
    final ajustes = AppScope.de(context).ajustes;
    final textos = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: ajustes,
      builder: (context, _) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text('Accesibilidad y apariencia',
                    style: textos.titleLarge),
              ),
              SwitchListTile(
                key: const Key('switch_texto_grande'),
                secondary: const Icon(Icons.format_size, size: 30),
                title: Text('Texto grande', style: textos.titleMedium),
                subtitle: Text('Aumenta el tamaño de las letras',
                    style: textos.bodyMedium),
                value: ajustes.textoGrande,
                onChanged: ajustes.cambiarTextoGrande,
              ),
              SwitchListTile(
                key: const Key('switch_alto_contraste'),
                secondary: const Icon(Icons.contrast, size: 30),
                title: Text('Alto contraste', style: textos.titleMedium),
                subtitle: Text('Colores más fuertes y bordes marcados',
                    style: textos.bodyMedium),
                value: ajustes.altoContraste,
                onChanged: ajustes.cambiarAltoContraste,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(children: [
                  const Icon(Icons.dark_mode_outlined, size: 30),
                  const SizedBox(width: 16),
                  Text('Tema', style: textos.titleMedium),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SegmentedButton<ThemeMode>(
                  key: const Key('selector_tema'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro')),
                    ButtonSegment(
                        value: ThemeMode.system, label: Text('Sistema')),
                  ],
                  selected: {ajustes.modoTema},
                  onSelectionChanged: (s) => ajustes.cambiarModoTema(s.first),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
