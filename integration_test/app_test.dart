import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saludcerca/main.dart' as app;
import 'package:saludcerca/screens/shell_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Prueba end-to-end contra el proyecto REAL de Supabase.
/// Ejecutar (ver README):
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/app_test.dart --dart-define-from-file=env.json -d <dispositivo>
/// Recorre login, consultas, CRUD, RLS, HU-06 y modo oscuro, y guarda
/// capturas en sprint2-evidencias/.

const _correo = String.fromEnvironment('TEST_EMAIL');
const _clave = String.fromEnvironment('TEST_PASSWORD');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final so = Platform.isIOS ? 'ios' : 'android';
  var n = 0;

  Future<void> esperar(WidgetTester t, Finder f,
      {Duration max = const Duration(seconds: 20)}) async {
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

  Future<void> quieto(WidgetTester t, [int ms = 900]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> captura(WidgetTester t, String nombre) async {
    await quieto(t, 600);
    n++;
    final archivo = '${n.toString().padLeft(2, '0')}_${nombre}_$so';
    if (Platform.isAndroid && n == 1) {
      await binding.convertFlutterSurfaceToImage();
      await t.pump();
    }
    await binding.takeScreenshot(archivo);
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

  Future<void> ocultarAvisos(WidgetTester t) async {
    final ctx = t.element(find.byType(Scaffold).first);
    ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
    await quieto(t, 500);
  }

  testWidgets('Sprint 2 end-to-end con Supabase', (t) async {
    expect(_correo, isNotEmpty, reason: 'Falta TEST_EMAIL en env.json');
    (await SharedPreferences.getInstance()).clear(); // ajustes por defecto
    await app.main();
    await quieto(t, 1500);

    // Si quedó una sesión de una corrida anterior, se cierra.
    if (find.byType(ShellScreen).evaluate().isNotEmpty) {
      await Supabase.instance.client.auth.signOut();
      await quieto(t, 1500);
    }

    // ---------- Autenticación ----------
    await esperar(t, find.text('Ingresar'));
    await captura(t, 'login');
    await tocar(t, find.text('Ingresar'));
    await captura(t, 'login_validacion');

    await t.enterText(find.byKey(const Key('login_correo')), _correo);
    await t.enterText(find.byKey(const Key('login_clave')), 'Incorrecta1');
    await tocar(t, find.text('Ingresar'));
    await esperar(t, find.text('Correo o contraseña incorrectos.'));
    await captura(t, 'login_error');
    await ocultarAvisos(t);

    await t.enterText(find.byKey(const Key('login_clave')), _clave);
    await tocar(t, find.text('Ingresar'));
    await esperar(t, find.byType(ShellScreen));
    final uid = Supabase.instance.client.auth.currentUser!.id;

    // ---------- Consultas dinámicas ----------
    await esperar(t, find.textContaining('Encontramos'));
    expect(find.text('Encontramos 10 centros'), findsOneWidget);
    await captura(t, 'centros_lista');
    await tocar(t, find.text('El Alto'));
    await esperar(t, find.text('Encontramos 4 centros'));
    await tocar(t, find.text('Emergencias'));
    await esperar(t, find.text('Encontramos 2 centros'));
    await captura(t, 'centros_filtro_el_alto_emergencias');
    await tocar(t, find.text('Emergencias'));
    await tocar(t, find.text('Todas las ciudades'));
    await t.enterText(find.byKey(const Key('buscar_centros')), 'sopocachi');
    await esperar(t, find.text('Encontramos 1 centro'));
    await captura(t, 'centros_busqueda');

    // ---------- Detalle + Favoritos (CREATE / baja lógica) ----------
    await tocar(t, find.text('Centro de Salud Sopocachi'));
    await esperar(t, find.text('Servicios'));
    await quieto(t, 1500);
    if (find.byTooltip('Quitar de favoritos').evaluate().isNotEmpty) {
      await tocar(t, find.byTooltip('Quitar de favoritos'));
      await tocar(t, find.text('Sí, quitar'));
      await esperar(t, find.byTooltip('Agregar a favoritos'));
      await ocultarAvisos(t);
    }
    await captura(t, 'detalle_centro');
    await tocar(t, find.byTooltip('Agregar a favoritos'));
    await t.enterText(
        find.byKey(const Key('nota_favorito')), 'Aquí atiende mi doctora');
    await captura(t, 'favorito_nota_formulario');
    await tocar(t, find.text('Guardar'));
    await esperar(t, find.text('Agregado a tus favoritos.'));
    await captura(t, 'favorito_agregado');
    await t.pageBack();
    await quieto(t);

    await pestana(t, 'Favoritos');
    await esperar(t, find.text('Nota: Aquí atiende mi doctora'));
    await captura(t, 'favoritos_lista');

    // ---------- Recordatorios: CREATE ----------
    await pestana(t, 'Recordar');
    await esperar(t, find.byKey(const Key('nuevo_recordatorio')));
    await quieto(t, 1500);
    await tocar(t, find.byKey(const Key('nuevo_recordatorio')));
    await tocar(t, find.byKey(const Key('guardar_recordatorio')));
    await esperar(t, find.text('Escribe un título'));
    await captura(t, 'recordatorio_validacion');
    await ocultarAvisos(t);
    await tocar(t, find.text('Medicamento'));
    await t.enterText(
        find.byKey(const Key('recordatorio_titulo')), 'Tomar losartán');
    await tocar(t, find.byKey(const Key('recordatorio_fecha')));
    await tocar(t, find.text('OK')); // fecha
    await tocar(t, find.text('OK')); // hora
    await captura(t, 'recordatorio_formulario');
    await tocar(t, find.byKey(const Key('guardar_recordatorio')));
    await esperar(t, find.text('Tomar losartán'));
    await captura(t, 'recordatorio_creado');
    await ocultarAvisos(t);

    // ---------- Recordatorios: UPDATE ----------
    final tarjeta = find.ancestor(
        of: find.text('Tomar losartán'), matching: find.byType(Card));
    await tocar(
        t, find.descendant(of: tarjeta, matching: find.byTooltip('Editar')));
    await t.enterText(
        find.byKey(const Key('recordatorio_titulo')), 'Tomar losartán 50 mg');
    await tocar(t, find.byKey(const Key('guardar_recordatorio')));
    await esperar(t, find.text('Tomar losartán 50 mg'));
    await captura(t, 'recordatorio_editado');
    await ocultarAvisos(t);

    // ---------- Recordatorios: baja lógica ----------
    final tarjeta2 = find.ancestor(
        of: find.text('Tomar losartán 50 mg'), matching: find.byType(Card));
    await tocar(
        t, find.descendant(of: tarjeta2, matching: find.byTooltip('Eliminar')));
    await captura(t, 'recordatorio_confirmar_eliminar');
    await tocar(t, find.text('Sí, eliminar'));
    await esperar(t, find.text('Recordatorio eliminado.'));
    await captura(t, 'recordatorio_eliminado');
    // La fila sigue en la base de datos con activo = false.
    final db = Supabase.instance.client;
    final filas = await db
        .from('recordatorios')
        .select('titulo, activo')
        .eq('titulo', 'Tomar losartán 50 mg');
    expect(filas, isNotEmpty);
    expect(filas.every((f) => f['activo'] == false), isTrue);

    // ---------- Seguridad RLS con sesión ----------
    final todos = await db.from('favoritos').select('usuario_id');
    expect(todos.every((f) => f['usuario_id'] == uid), isTrue,
        reason: 'Solo debe ver sus propios favoritos');
    Object? errorAjeno;
    try {
      await db.from('recordatorios').insert({
        'usuario_id': '00000000-0000-0000-0000-000000000000',
        'titulo': 'Intento ajeno',
        'fecha_hora': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      errorAjeno = e;
    }
    expect(errorAjeno, isA<PostgrestException>(),
        reason: 'RLS debe impedir crear datos de otro usuario');
    Object? errorBorrar;
    try {
      await db.from('favoritos').delete().eq('usuario_id', uid).select();
    } catch (e) {
      errorBorrar = e;
    }
    expect(errorBorrar, isA<PostgrestException>(),
        reason: 'No existe DELETE físico: solo baja lógica');

    // ---------- Perfil: READ / UPDATE ----------
    await ocultarAvisos(t);
    await pestana(t, 'Perfil');
    await esperar(t, find.byKey(const Key('perfil_nombre')));
    await captura(t, 'perfil');
    await t.enterText(find.byKey(const Key('perfil_telefono')), '12');
    await tocar(t, find.byKey(const Key('guardar_perfil')));
    await esperar(t, find.textContaining('Teléfono no válido'));
    await captura(t, 'perfil_validacion');
    await ocultarAvisos(t);
    await t.enterText(find.byKey(const Key('perfil_telefono')), '71234567');
    await tocar(t, find.byKey(const Key('guardar_perfil')));
    await esperar(t, find.text('Tus datos se guardaron correctamente.'));
    await captura(t, 'perfil_guardado');
    await ocultarAvisos(t);

    // ---------- HU-06 y modo oscuro ----------
    await t.scrollUntilVisible(
        find.byKey(const Key('switch_texto_grande')), -300,
        scrollable: find.byType(Scrollable).first);
    await tocar(t, find.byKey(const Key('switch_texto_grande')));
    await captura(t, 'hu06_texto_grande_perfil');
    await pestana(t, 'Centros');
    await esperar(t, find.textContaining('Encontramos'));
    await captura(t, 'hu06_texto_grande_centros');

    await pestana(t, 'Perfil');
    await tocar(t, find.byKey(const Key('switch_alto_contraste')));
    await captura(t, 'hu06_alto_contraste_perfil');
    await pestana(t, 'Centros');
    await esperar(t, find.textContaining('Encontramos'));
    await captura(t, 'hu06_alto_contraste_centros');

    await pestana(t, 'Perfil');
    await tocar(t, find.text('Oscuro'));
    await captura(t, 'oscuro_alto_contraste_perfil');
    await tocar(t, find.byKey(const Key('switch_alto_contraste')));
    await tocar(t, find.byKey(const Key('switch_texto_grande')));
    await captura(t, 'oscuro_perfil');
    await pestana(t, 'Centros');
    await esperar(t, find.textContaining('Encontramos'));
    await captura(t, 'oscuro_centros');
    await pestana(t, 'Favoritos');
    await esperar(t, find.text('Nota: Aquí atiende mi doctora'));
    await captura(t, 'oscuro_favoritos');

    // Las preferencias quedaron guardadas en el teléfono.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ajustes.modo_tema'), 'dark');

    // Se deja el tema como "Sistema" para no afectar el uso normal.
    await pestana(t, 'Perfil');
    await tocar(t, find.text('Sistema'));

    // ---------- Cierre de sesión ----------
    await t.scrollUntilVisible(find.byKey(const Key('cerrar_sesion')), 300,
        scrollable: find.byType(Scrollable).first);
    await tocar(t, find.byKey(const Key('cerrar_sesion')));
    await captura(t, 'cerrar_sesion_confirmar');
    await tocar(t, find.text('Sí, salir'));
    await esperar(t, find.text('Ingresar'));
    expect(Supabase.instance.client.auth.currentUser, isNull);
  });
}
