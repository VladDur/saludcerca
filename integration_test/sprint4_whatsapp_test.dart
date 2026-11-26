import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saludcerca/app.dart';
import 'package:saludcerca/main.dart' as app;
import 'package:saludcerca/screens/shell_screen.dart';
import 'package:saludcerca/services/whatsapp_servicio.dart';
import 'package:saludcerca/settings/ajustes_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Evidencias de la consulta de medicamentos por WhatsApp (Sprint 4) contra
/// Supabase real:
///   flutter drive --driver=test_driver/sprint4_driver.dart \
///     --target=integration_test/sprint4_whatsapp_test.dart \
///     --dart-define-from-file=env.json -d <id>
///
/// El emulador no tiene WhatsApp, así que el enlace no se abre: un
/// [WhatsAppServicio] de registro guarda el número y el mensaje que la app
/// entregaría a WhatsApp, y la prueba comprueba el texto.

const _correo = String.fromEnvironment('TEST_EMAIL');
const _clave = String.fromEnvironment('TEST_PASSWORD');
const _farmacia = 'Farmacia Sopocachi Central';
const _medicamento = 'Paracetamol 500 mg';

class _WhatsAppRegistro implements WhatsAppServicio {
  String? numero;
  String? mensaje;

  @override
  Future<bool> abrirChat(String numero, String mensaje) async {
    this.numero = numero;
    this.mensaje = mensaje;
    debugPrint('[WHATSAPP] ${enlaceWhatsApp('591XXXXXXXX', mensaje)}');
    return true;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final so = Platform.isIOS ? 'ios' : 'android';
  var primera = true;

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

  Future<void> captura(WidgetTester t, String archivo) async {
    await quieto(t, 600);
    final nombre = '${archivo}_$so';
    debugPrint('[CAPTURA] $nombre');
    await quieto(t, 1500);
    if (Platform.isAndroid && primera) {
      primera = false;
      await binding.convertFlutterSurfaceToImage();
      await t.pump();
    }
    await binding.takeScreenshot(nombre);
    debugPrint('[EVIDENCIA] $nombre');
  }

  Future<void> tocar(WidgetTester t, Finder f) async {
    await esperar(t, f);
    await t.ensureVisible(f.first);
    await quieto(t, 300);
    await t.tap(f.first, warnIfMissed: false);
    await quieto(t);
  }

  testWidgets('Sprint 4: consultar un medicamento por WhatsApp', (t) async {
    expect(_correo, isNotEmpty, reason: 'Falta TEST_EMAIL en env.json');
    (await SharedPreferences.getInstance()).clear();
    final ajustes = await AjustesController.cargar();
    await app.main();
    await quieto(t, 1500);
    if (find.byType(ShellScreen).evaluate().isNotEmpty) {
      await Supabase.instance.client.auth.signOut();
      await quieto(t, 1500);
    }
    final whatsapp = _WhatsAppRegistro();
    await t.pumpWidget(KeyedSubtree(
        key: UniqueKey(),
        child: SaludCercaApp(
            dependencias:
                app.dependenciasReales(ajustes, whatsapp: whatsapp))));
    await esperar(t, find.text('Ingresar'));
    await t.enterText(find.byKey(const Key('login_correo')), _correo);
    await t.enterText(find.byKey(const Key('login_clave')), _clave);
    await tocar(t, find.text('Ingresar'));
    await esperar(t, find.byType(ShellScreen));

    await tocar(
        t,
        find.descendant(
            of: find.byType(NavigationBar), matching: find.text('Farmacias')));
    await esperar(t, find.byKey(const Key('farmacias_total')),
        max: const Duration(seconds: 40));
    await tocar(t, find.text(_farmacia));
    await esperar(t, find.byKey(const Key('farmacia_consultar')));
    await captura(t, '08_farmacia_boton_consultar');

    await tocar(t, find.byKey(const Key('farmacia_consultar')));
    await esperar(t, find.byKey(const Key('consulta_medicamento')));
    // Validación: vacío no se acepta.
    await tocar(t, find.byKey(const Key('consulta_abrir')));
    await esperar(t, find.text('Escribe el medicamento'));
    await captura(t, '09_consulta_validacion');
    // Cancelar no abre WhatsApp; se vuelve a abrir el diálogo limpio.
    await tocar(t, find.text('Cancelar'));
    expect(whatsapp.mensaje, isNull);
    await tocar(t, find.byKey(const Key('farmacia_consultar')));
    await esperar(t, find.byKey(const Key('consulta_medicamento')));
    await t.enterText(
        find.byKey(const Key('consulta_medicamento')), _medicamento);
    await quieto(t, 600);
    await captura(t, '10_consulta_medicamento');

    await tocar(t, find.byKey(const Key('consulta_abrir')));
    await quieto(t, 1200);
    expect(whatsapp.numero, matches(RegExp(r'^591[67][0-9]{7}$')));
    expect(whatsapp.mensaje, contains(_farmacia));
    expect(whatsapp.mensaje, contains(_medicamento));

    await Supabase.instance.client.auth.signOut();
    await esperar(t, find.text('Ingresar'));
  });
}
