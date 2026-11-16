import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/validadores.dart';
import '../../widgets/mensajes.dart';
import 'registro_screen.dart';

/// Inicio de sesión con correo y contraseña (Supabase Auth).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correoCtrl = TextEditingController();
  final _claveCtrl = TextEditingController();
  bool _ocultarClave = true;
  bool _cargando = false;

  @override
  void dispose() {
    _correoCtrl.dispose();
    _claveCtrl.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (_cargando || !_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await AppScope.de(context)
          .auth
          .iniciarSesion(_correoCtrl.text, _claveCtrl.text);
      // AuthGate cambia a la pantalla principal al detectar la sesión.
    } catch (e) {
      if (mounted) Mensajes.error(context, e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _irARegistro() async {
    final correo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const RegistroScreen()),
    );
    if (correo != null) _correoCtrl.text = correo;
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: esquema.primary,
                        child: Icon(Icons.health_and_safety,
                            size: 56, color: esquema.onPrimary),
                      ),
                      const SizedBox(height: 16),
                      Text('SaludCerca',
                          textAlign: TextAlign.center,
                          style: textos.headlineMedium
                              ?.copyWith(color: esquema.primary)),
                      const SizedBox(height: 6),
                      Text('Centros de salud cerca de ti',
                          textAlign: TextAlign.center, style: textos.bodyLarge),
                      const SizedBox(height: 32),
                      TextFormField(
                        key: const Key('login_correo'),
                        controller: _correoCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        style: const TextStyle(fontSize: 18),
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: Validadores.correo,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('login_clave'),
                        controller: _claveCtrl,
                        obscureText: _ocultarClave,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _ingresar(),
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
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
                        validator: Validadores.clave,
                      ),
                      const SizedBox(height: 28),
                      FilledButton.icon(
                        onPressed: _cargando ? null : _ingresar,
                        icon: _cargando
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 3))
                            : const Icon(Icons.login),
                        label: Text(_cargando ? 'Ingresando...' : 'Ingresar'),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _cargando ? null : _irARegistro,
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Crear una cuenta'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
