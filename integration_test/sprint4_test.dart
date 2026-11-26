import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saludcerca/app.dart';
import 'package:saludcerca/main.dart' as app;
import 'package:saludcerca/screens/shell_screen.dart';
import 'package:saludcerca/services/api_cliente.dart';
import 'package:saludcerca/services/calidad_aire_servicio.dart';
import 'package:saludcerca/services/voz_servicio.dart';
import 'package:saludcerca/settings/ajustes_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Prueba end-to-end del Sprint 4 contra los servicios REALES (Supabase y
/// Open-Meteo Air Quality) y capturas de evidencia:
///   flutter drive --driver=test_driver/sprint4_driver.dart \
///     --target=integration_test/sprint4_test.dart --dart-define-from-file=env.json -d <id>
///
/// El emulador y el simulador no tienen una persona que hable, así que el
/// dictado usa [_VozGuionada], que entrega la frase como lo haría el
/// reconocedor (primero parciales, luego el texto final). El resto de la
/// pantalla y el guardado en Supabase son los reales.

const _correo = String.fromEnvironment('TEST_EMAIL');
const _clave = String.fromEnvironment('TEST_PASSWORD');
const _frase = 'sacar ficha en hospital Miraflores';

class _VozGuionada implements VozServicio {
  Completer<String>? _pendiente;

  @override
  Future<String> dictar({void Function(String parcial)? alParcial}) {
    final c = _pendiente = Completer<String>();
    () async {
      final palabras = _frase.split(' ');
      for (var i = 1; i <= palabras.length; i++) {
        await Future.delayed(const Duration(milliseconds: 450));
        if (c.isCompleted) return;
        alParcial?.call(palabras.take(i).join(' '));
      }
    }();
    return c.future;
  }

  @override
  Future<void> detener() async {
    final c = _pendiente;
    if (c != null && !c.isCompleted) c.complete(_frase);
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final so = Platform.isIOS ? 'ios' : 'android';
  var n = 0;

  Future<void> quieto(WidgetTester t, [int ms = 900]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> esperar(WidgetTester t, Finder f,
      {Duration max = const Duration(seconds: 25)}) async {
    final fin = DateTime.now().add(max);
    while (DateTime.now().isBefore(fin)) {
      await t.pump(const Duration(milliseconds: 200));
      if (f.evaluate().isNotEmpty) {
        await t.pump(const Duration(milliseconds: 400));
        return;
      }
    }
    final visibles = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .whereType<String>()
        .join(' | ');
    throw TestFailure('No apareció: $f\nEn pantalla: $visibles');
  }

  Future<void> captura(WidgetTester t, String nombre,
      [int espera = 600]) async {
    await quieto(t, espera);
    n++;
    final archivo = '${n.toString().padLeft(2, '0')}_${nombre}_$so';
    debugPrint('[CAPTURA] $archivo');
    await quieto(t, 1500);
    if (Platform.isAndroid && n == 1) {
      await binding.convertFlutterSurfaceToImage();
      await t.pump();
    }
    await binding.takeScreenshot(archivo);
    debugPrint('[EVIDENCIA] $archivo');
  }

  Future<void> tocar(WidgetTester t, Finder f) async {
    await esperar(t, f);
    await t.ensureVisible(f.first);
    await quieto(t, 300);
    await t.tap(f.first, warnIfMissed: false);
    await quieto(t);
  }

  Future<void> verAire(WidgetTester t) async {
    await esperar(t, find.byKey(const Key('tarjeta_aire')),
        max: const Duration(seconds: 45));
    await t.ensureVisible(find.byKey(const Key('tarjeta_aire')));
    await quieto(t);
  }

  testWidgets('Sprint 4 end-to-end: calidad del aire y dictado', (t) async {
    expect(_correo, isNotEmpty, reason: 'Falta TEST_EMAIL en env.json');
    (await SharedPreferences.getInstance()).clear();
    final ajustes = await AjustesController.cargar();
    // Igual que main(), pero con el dictado guionado.
    await app.main();
    await quieto(t, 1500);
    if (find.byType(ShellScreen).evaluate().isNotEmpty) {
      await Supabase.instance.client.auth.signOut();
      await quieto(t, 1500);
    }
    await t.pumpWidget(KeyedSubtree(
        key: UniqueKey(),
        child: SaludCercaApp(
            dependencias:
                app.dependenciasReales(ajustes, voz: _VozGuionada()))));
    await esperar(t, find.text('Ingresar'));
    await t.enterText(find.byKey(const Key('login_correo')), _correo);
    await t.enterText(find.byKey(const Key('login_clave')), _clave);
    await tocar(t, find.text('Ingresar'));
    await esperar(t, find.byType(ShellScreen));

    // ---------- HU-15 calidad del aire (API real) ----------
    await verAire(t);
    await esperar(t, find.byKey(const Key('aire_nivel')));
    await captura(t, 'calidad_aire_consejos', 1200);

    // ---------- Recordatorio por voz ----------
    await tocar(
        t,
        find.descendant(
            of: find.byType(NavigationBar), matching: find.text('Recordar')));
    await tocar(t, find.byKey(const Key('nuevo_recordatorio')));
    await captura(t, 'recordatorio_boton_dictar');
    await t.tap(find.byKey(const Key('recordatorio_dictar')));
    await quieto(t, 1500);
    await esperar(t, find.text('Escuchando… toca para terminar'));
    await captura(t, 'recordatorio_escuchando', 900);
    await quieto(t, 1500);
    await t.tap(find.byKey(const Key('recordatorio_dictar'))); // terminar
    await esperar(t, find.text('Revisa el título y corrígelo si hace falta.'));
    final titulo = t
        .widget<TextFormField>(find.byKey(const Key('recordatorio_titulo')))
        .controller!
        .text;
    expect(titulo, 'Sacar ficha en hospital Miraflores');
    await captura(t, 'recordatorio_titulo_dictado', 300);

    // El usuario confirma: elige fecha y hora y guarda en Supabase.
    FocusManager.instance.primaryFocus?.unfocus();
    await quieto(t, 600);
    await tocar(t, find.byKey(const Key('recordatorio_fecha')));
    await tocar(t, find.byType(TextButton).last); // Aceptar fecha
    await tocar(t, find.byType(TextButton).last); // Aceptar hora
    await tocar(t, find.byKey(const Key('guardar_recordatorio')));
    await esperar(t, find.text('Sacar ficha en hospital Miraflores'));
    await captura(t, 'recordatorio_guardado');

    // Limpieza: baja lógica del recordatorio de prueba.
    await tocar(t, find.byTooltip('Eliminar'));
    await tocar(t, find.text('Sí, eliminar'));
    await quieto(t, 1500);

    // ---------- Errores con el servicio real ----------
    // Ruta inexistente -> HTTP 404; tiempo máximo de 1 ms -> tiempo agotado.
    for (final (servicio, clave, nombre) in [
      (
        OpenMeteoCalidadAireServicio(ApiCliente(),
            urlBase: 'https://air-quality-api.open-meteo.com/v1/no-existe'),
        '404',
        'error_aire_404'
      ),
      (
        OpenMeteoCalidadAireServicio(
            ApiCliente(tiempoMaximo: const Duration(milliseconds: 1))),
        'tardó demasiado',
        'error_aire_timeout'
      ),
    ]) {
      await t.pumpWidget(KeyedSubtree(
          key: UniqueKey(),
          child: SaludCercaApp(
              dependencias:
                  app.dependenciasReales(ajustes, calidadAire: servicio))));
      await verAire(t);
      await esperar(t, find.byKey(const Key('aire_error')));
      expect(find.textContaining(clave), findsOneWidget);
      await captura(t, nombre);
    }

    await Supabase.instance.client.auth.signOut();
    await esperar(t, find.text('Ingresar'));
  });
}
