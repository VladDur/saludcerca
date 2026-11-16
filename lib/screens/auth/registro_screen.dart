import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/validadores.dart';
import '../../data/repositorios.dart';
import '../../widgets/mensajes.dart';

/// Registro de un nuevo USUARIO (Supabase Auth + perfil automático).
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _claveCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();
  bool _ocultarClave = true;
  bool _cargando = false;

  @override
  void dispose() {
    for (final c in [_nombreCtrl, _correoCtrl, _claveCtrl, _confirmarCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _registrar() async {
    if (_cargando || !_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      final resultado = await AppScope.de(context).auth.registrar(
            nombre: _nombreCtrl.text,
            correo: _correoCtrl.text,
            clave: _claveCtrl.text,
          );
      if (!mounted) return;
      if (resultado == ResultadoRegistro.sesionIniciada) {
        Mensajes.exito(context, '¡Cuenta creada! Bienvenido a SaludCerca.');
        Navigator.pop(context); // AuthGate ya muestra la pantalla principal
      } else {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Revisa tu correo'),
            content: Text(
                'Te enviamos un enlace a ${_correoCtrl.text.trim()} para confirmar '
                'tu cuenta. Después vuelve e inicia sesión.',
                style: Theme.of(ctx).textTheme.bodyLarge),
            actions: [
              FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Entendido')),
            ],
          ),
        );
        if (mounted) Navigator.pop(context, _correoCtrl.text.trim());
      }
    } catch (e) {
      if (mounted) Mensajes.error(context, e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Completa tus datos para usar SaludCerca.',
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('registro_nombre'),
                  controller: _nombreCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: Validadores.nombre,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('registro_correo'),
                  controller: _correoCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: Validadores.correo,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('registro_clave'),
                  controller: _claveCtrl,
                  obscureText: _ocultarClave,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    helperText: 'Mínimo 6 caracteres, con letras y números',
                    helperStyle: const TextStyle(fontSize: 15),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _ocultarClave
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      icon: Icon(_ocultarClave
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setState(() => _ocultarClave = !_ocultarClave),
                    ),
                  ),
                  validator: Validadores.claveNueva,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('registro_confirmar'),
                  controller: _confirmarCtrl,
                  obscureText: _ocultarClave,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _registrar(),
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: 'Repite la contraseña',
                    prefixIcon: Icon(Icons.lock_reset),
                  ),
                  validator: Validadores.confirmarClave(() => _claveCtrl.text),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _cargando ? null : _registrar,
                  icon: _cargando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 3))
                      : const Icon(Icons.check),
                  label: Text(_cargando ? 'Creando...' : 'Crear cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
