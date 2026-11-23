import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saludcerca/app.dart';
import 'package:saludcerca/main.dart' as app;
import 'package:saludcerca/screens/shell_screen.dart';
import 'package:saludcerca/services/api_cliente.dart';
import 'package:saludcerca/services/clima_servicio.dart';
import 'package:saludcerca/services/geocodificacion_servicio.dart';
import 'package:saludcerca/settings/ajustes_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Prueba end-to-end del Sprint 3 contra los servicios REALES:
/// Supabase (Auth + API REST), Open-Meteo, Nominatim y teselas de OSM.
///
/// Antes de correrla, el dispositivo debe tener permiso de ubicación y una
/// posición en La Paz (ver README, sección "Pruebas del Sprint 3"):
///   flutter drive --driver=test_driver/sprint3_driver.dart \
///     --target=integration_test/sprint3_test.dart --dart-define-from-file=env.json -d <id>
/// Las capturas quedan en sprint3-evidencias/.

const _correo = String.fromEnvironment('TEST_EMAIL');
const _clave = String.fromEnvironment('TEST_PASSWORD');

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
    // Aviso para capturar también desde el equipo (xcrun simctl / adb).
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

  Future<void> pestana(WidgetTester t, String nombre) => tocar(
      t,
      find.descendant(
          of: find.byType(NavigationBar), matching: find.text(nombre)));

  Future<void> atras(WidgetTester t) async {
    await t.pageBack();
    await quieto(t, 1200);
  }

  testWidgets('Sprint 3 end-to-end: APIs reales', (t) async {
    expect(_correo, isNotEmpty, reason: 'Falta TEST_EMAIL en env.json');
    (await SharedPreferences.getInstance()).clear();
    await app.main();
    await quieto(t, 1500);
    if (find.byType(ShellScreen).evaluate().isNotEmpty) {
      await Supabase.instance.client.auth.signOut();
      await quieto(t, 1500);
    }

    // ---------- Supabase Auth (JWT) ----------
    await esperar(t, find.text('Ingresar'));
    await t.enterText(find.byKey(const Key('login_correo')), _correo);
    await t.enterText(find.byKey(const Key('login_clave')), _clave);
    await tocar(t, find.text('Ingresar'));
    await esperar(t, find.byType(ShellScreen));
    final sesion = Supabase.instance.client.auth.currentSession!;
    expect(sesion.accessToken.split('.'), hasLength(3)); // JWT
    debugPrint(
        '[AUTH] sesión iniciada, JWT con expiración ${sesion.expiresAt}');

    // ---------- HU-13 ubicación + Open-Meteo + Nominatim inversa ----------
    await esperar(t, find.text('Cerca de ti'),
        max: const Duration(seconds: 45));
    await esperar(t, find.byKey(const Key('clima_temperatura')));
    await esperar(t, find.textContaining('La Paz'));
    await captura(t, 'centros_ubicacion_clima', 1500);
    await t.scrollUntilVisible(find.textContaining('Encontramos'), 300,
        scrollable: find.byType(Scrollable).first);
    await t.drag(find.byType(Scrollable).first, const Offset(0, -250));
    await captura(t, 'centros_por_cercania');

    // ---------- HU-03 farmacias de turno (API REST de Supabase) ----------
    await pestana(t, 'Farmacias');
    await esperar(t, find.byKey(const Key('farmacias_total')));
    expect(find.text('4 farmacias de turno hoy'), findsOneWidget);
    await captura(t, 'farmacias_turno_hoy');
    await tocar(t, find.text('El Alto'));
    await esperar(t, find.text('2 farmacias de turno hoy'));
    await captura(t, 'farmacias_el_alto');
    await tocar(t, find.byKey(const Key('turno_manana')));
    await esperar(t, find.text('2 farmacias de turno mañana'));
    await captura(t, 'farmacias_manana');
    await tocar(t, find.byKey(const Key('turno_hoy')));
    await tocar(t, find.text('Todas las ciudades'));
    await esperar(t, find.text('4 farmacias de turno hoy'));
    await tocar(t, find.textContaining('Farmacia ').first);
    await esperar(t, find.byKey(const Key('farmacia_ver_mapa')));
    await captura(t, 'farmacia_detalle');
    await tocar(t, find.byKey(const Key('farmacia_ver_mapa')));
    await esperar(t, find.byKey(const Key('mapa_osm')));
    await captura(t, 'mapa_farmacia_enfocada', 4000);
    await atras(t);

    // RLS: el catálogo es de solo lectura para el usuario.
    final db = Supabase.instance.client;
    final turnos = await db
        .from('turnos_farmacia')
        .select('id, farmacias!inner(nombre)')
        .limit(1);
    expect(turnos, isNotEmpty);
    Object? errorEscritura;
    try {
      await db.from('farmacias').insert({
        'nombre': 'Intento',
        'ciudad': 'La Paz',
        'zona': 'x',
        'direccion': 'x',
        'telefono': '1',
        'latitud': 0,
        'longitud': 0,
      });
    } catch (e) {
      errorEscritura = e;
    }
    expect(errorEscritura, isA<PostgrestException>(),
        reason: 'El usuario no puede escribir en farmacias');
    debugPrint('[RLS] insert en farmacias rechazado: '
        '${(errorEscritura as PostgrestException).code} ${errorEscritura.message}');

    // ---------- HU-12 mapa + búsqueda con Nominatim ----------
    await pestana(t, 'Centros');
    await tocar(t, find.byKey(const Key('abrir_mapa')));
    await esperar(t, find.textContaining('Centros (10)'));
    await captura(t, 'mapa_centros_farmacias', 4000);
    await t.enterText(find.byKey(const Key('mapa_buscar')), 'Plaza Avaroa');
    await tocar(t, find.byKey(const Key('mapa_buscar_boton')));
    await esperar(t, find.byKey(const Key('mapa_resultados')));
    await captura(t, 'mapa_busqueda_resultados');
    await tocar(
        t,
        find.descendant(
            of: find.byKey(const Key('mapa_resultados')),
            matching: find.byType(ListTile)));
    await esperar(t, find.byKey(const Key('marcador_busqueda')));
    await captura(t, 'mapa_lugar_encontrado', 4000);
    await tocar(t, find.byKey(const Key('mapa_filtro_farmacias')));
    await captura(t, 'mapa_solo_centros', 2500);
    await tocar(t, find.byKey(const Key('mapa_filtro_farmacias')));
    await atras(t);

    // Detalle de un centro -> "Ver en el mapa" -> tocar el marcador.
    await t.enterText(find.byKey(const Key('buscar_centros')), 'sopocachi');
    await esperar(t, find.text('Encontramos 1 centro'));
    await tocar(t, find.text('Centro de Salud Sopocachi'));
    await esperar(t, find.text('Servicios'));
    await t.scrollUntilVisible(find.byKey(const Key('detalle_ver_mapa')), 300,
        scrollable: find.byType(Scrollable).first);
    await tocar(t, find.byKey(const Key('detalle_ver_mapa')));
    await esperar(t, find.byKey(const Key('mapa_osm')));
    await quieto(t, 3000);
    await tocar(t, find.bySemanticsLabel('Centro: Centro de Salud Sopocachi'));
    await esperar(t, find.byKey(const Key('mapa_ver_detalle')));
    await captura(t, 'mapa_marcador_centro');
    await t.tapAt(const Offset(20, 120)); // cierra la hoja
    await quieto(t);
    await atras(t);
    await atras(t);

    // ---------- Manejo de errores con servicios reales ----------
    // Open-Meteo con una ruta inexistente responde HTTP 404 y Nominatim con
    // un tiempo máximo de 1 ms produce "tiempo agotado".
    final ajustes = await AjustesController.cargar();
    // UniqueKey: se crea un árbol nuevo para que ninguna pantalla reutilice
    // datos de las dependencias anteriores.
    await t.pumpWidget(KeyedSubtree(
        key: UniqueKey(),
        child: SaludCercaApp(
          dependencias: app.dependenciasReales(
            ajustes,
            clima: OpenMeteoClimaServicio(ApiCliente(),
                urlBase: 'https://api.open-meteo.com/v1/no-existe'),
            geocodificacion: NominatimServicio(
                ApiCliente(tiempoMaximo: const Duration(milliseconds: 1))),
          ),
        )));
    await esperar(t, find.byKey(const Key('clima_error')));
    expect(find.textContaining('404'), findsOneWidget);
    await captura(t, 'error_clima_404');
    await tocar(t, find.byKey(const Key('abrir_mapa')));
    await t.enterText(find.byKey(const Key('mapa_buscar')), 'El Prado');
    await tocar(t, find.byKey(const Key('mapa_buscar_boton')));
    await esperar(t, find.byKey(const Key('mapa_busqueda_error')));
    expect(find.textContaining('tardó demasiado'), findsOneWidget);
    await captura(t, 'error_nominatim_timeout');
    await atras(t);

    await Supabase.instance.client.auth.signOut();
    await esperar(t, find.text('Ingresar'));
  });
}
