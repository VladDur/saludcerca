import 'package:flutter/material.dart';

import '../core/errores.dart';

/// Mensajes de confirmación y error uniformes en toda la app.
class Mensajes {
  static void exito(BuildContext context, String texto) =>
      _mostrar(context, texto, Icons.check_circle, error: false);

  static void error(BuildContext context, Object errorOTexto) => _mostrar(
        context,
        errorOTexto is String ? errorOTexto : mensajeError(errorOTexto),
        Icons.error,
        error: true,
      );

  static void _mostrar(BuildContext context, String texto, IconData icono,
      {required bool error}) {
    final esquema = Theme.of(context).colorScheme;
    final fondo = error ? esquema.error : esquema.inverseSurface;
    final frente = error ? esquema.onError : esquema.onInverseSurface;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: fondo,
        duration: Duration(seconds: error ? 5 : 3),
        content: Semantics(
          liveRegion: true,
          child: Row(children: [
            Icon(icono, color: frente),
            const SizedBox(width: 12),
            Expanded(
                child:
                    Text(texto, style: TextStyle(fontSize: 17, color: frente))),
          ]),
        ),
      ));
  }

  /// Diálogo de confirmación (Sí / No). Devuelve true si confirma.
  static Future<bool> confirmar(
    BuildContext context, {
    required String titulo,
    required String mensaje,
    String textoAceptar = 'Sí, continuar',
  }) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje, style: Theme.of(ctx).textTheme.bodyLarge),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(textoAceptar)),
        ],
      ),
    );
    return r ?? false;
  }
}

/// Estado vacío o de error con botón de reintento.
class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String mensaje;
  final String? textoBoton;
  final VoidCallback? alPulsar;

  const EstadoVacio({
    super.key,
    required this.icono,
    required this.mensaje,
    this.textoBoton,
    this.alPulsar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(mensaje,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge),
          if (textoBoton != null) ...[
            const SizedBox(height: 20),
            OutlinedButton(onPressed: alPulsar, child: Text(textoBoton!)),
          ],
        ],
      ),
    );
  }
}
