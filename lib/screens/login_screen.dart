import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_theme.dart';

/// Pantalla 1: Inicio de sesión (sin backend; valida el formulario y entra).
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

  @override
  void dispose() {
    _correoCtrl.dispose();
    _claveCtrl.dispose();
    super.dispose();
  }

  void _ingresar() {
    if (!_formKey.currentState!.validate()) return;
    // Prototipo: no hay base de datos. Usamos la parte antes de la @ como nombre.
    final nombre = _correoCtrl.text.trim().split('@').first;
    Navigator.pushReplacementNamed(context, Rutas.inicio, arguments: nombre);
  }

  void _entrarComoInvitado() {
    Navigator.pushReplacementNamed(context, Rutas.inicio, arguments: 'Invitado');
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.primario,
                      child: Icon(Icons.health_and_safety,
                          size: 56, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text('SaludCerca',
                        textAlign: TextAlign.center,
                        style: textos.headlineMedium
                            ?.copyWith(color: AppColors.primario)),
                    const SizedBox(height: 6),
                    Text('Centros de salud y farmacias cerca de ti',
                        textAlign: TextAlign.center, style: textos.bodyLarge),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _correoCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        final valor = v?.trim() ?? '';
                        if (valor.isEmpty) return 'Escribe tu correo';
                        if (!valor.contains('@') || !valor.contains('.')) {
                          return 'El correo no es válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _claveCtrl,
                      obscureText: _ocultarClave,
                      textInputAction: TextInputAction.done,
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
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Mínimo 6 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: _ingresar,
                      icon: const Icon(Icons.login),
                      label: const Text('Ingresar'),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: _entrarComoInvitado,
                      child: const Text('Entrar como invitado'),
                    ),
                    const SizedBox(height: 24),
                    Text('Prototipo de demostración · datos de ejemplo',
                        textAlign: TextAlign.center, style: textos.bodyMedium),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
