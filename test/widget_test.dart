import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saludcerca/app.dart';
import 'package:saludcerca/core/app_scope.dart';
import 'package:saludcerca/models/recordatorio.dart';
import 'package:saludcerca/screens/shell_screen.dart';

import 'fakes.dart';

Future<Dependencias> abrirApp(WidgetTester tester,
    {bool conSesion = false, Map<String, Object> prefs = const {}}) async {
  tester.view.physicalSize = const Size(1080, 2400); // teléfono 360 x 800 dp
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final deps = await crearDependencias(conSesion: conSesion, prefs: prefs);
  await tester.pumpWidget(SaludCercaApp(dependencias: deps));
  await tester.pumpAndSettle();
  return deps;
}

/// Desplaza hasta el elemento, espera a que se oculten los avisos y lo toca.
Future<void> tocar(WidgetTester tester, Finder f) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
  if (f.evaluate().isEmpty) await alInicio(tester);
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(f, 200,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .first);
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Vuelve al inicio de la lista vertical de la pantalla.
Future<void> alInicio(WidgetTester tester) async {
  final listas = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down);
  for (final e in listas.evaluate()) {
    final state = (e as StatefulElement).state as ScrollableState;
    state.position.jumpTo(0);
  }
  await tester.pumpAndSettle();
}

/// Desplaza la lista vertical hasta que [f] se construya (ListView es perezosa).
Future<Finder> visible(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    await alInicio(tester);
  }
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(f, 200,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .first);
    await tester.pumpAndSettle();
  }
  return f;
}

Future<void> irAPestana(WidgetTester tester, String nombre) async {
  await tester.tap(find.descendant(
      of: find.byType(NavigationBar), matching: find.text(nombre)));
  await tester.pumpAndSettle();
}

void main() {
  group('Autenticación y pantallas protegidas', () {
    testWidgets('sin sesión solo se ve el inicio de sesión', (tester) async {
      await abrirApp(tester);
      expect(find.text('Ingresar'), findsOneWidget);
      expect(find.byType(ShellScreen), findsNothing);
    });

    testWidgets('valida el formulario de login', (tester) async {
      await abrirApp(tester);
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe tu correo'), findsOneWidget);
      expect(find.text('Escribe tu contraseña'), findsOneWidget);
    });

    testWidgets('credenciales incorrectas muestran un mensaje de error',
        (tester) async {
      await abrirApp(tester);
      await tester.enterText(
          find.byKey(const Key('login_correo')), correoPrueba);
      await tester.enterText(find.byKey(const Key('login_clave')), 'Otra1234');
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();
      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
      expect(find.byType(ShellScreen), findsNothing);
    });

    testWidgets('login correcto entra y cerrar sesión vuelve al login',
        (tester) async {
      await abrirApp(tester);
      await tester.enterText(
          find.byKey(const Key('login_correo')), correoPrueba);
      await tester.enterText(find.byKey(const Key('login_clave')), clavePrueba);
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();
      expect(find.byType(ShellScreen), findsOneWidget);
      expect(await visible(tester, find.text('Centro Uno')), findsOneWidget);

      await irAPestana(tester, 'Perfil');
      expect(find.text(correoPrueba), findsOneWidget); // usuario identificado
      await tocar(tester, find.byKey(const Key('cerrar_sesion')));
      await tester.tap(find.text('Sí, salir'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresar'), findsOneWidget);
    });

    testWidgets('registro valida y crea la cuenta', (tester) async {
      await abrirApp(tester);
      await tester.tap(find.text('Crear una cuenta'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('registro_nombre')), 'Luis Mamani');
      await tester.enterText(
          find.byKey(const Key('registro_correo')), 'luis@correo.com');
      await tester.enterText(
          find.byKey(const Key('registro_clave')), 'Clave123');
      await tester.enterText(
          find.byKey(const Key('registro_confirmar')), 'Clave124');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('registro_confirmar')), 'Clave123');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();
      expect(find.byType(ShellScreen), findsOneWidget);
    });
  });

  testWidgets('registro con un correo ya registrado muestra el aviso',
      (tester) async {
    await abrirApp(tester);
    await tester.tap(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('registro_nombre')), 'Ana Pérez');
    await tester.enterText(
        find.byKey(const Key('registro_correo')), correoPrueba);
    await tester.enterText(find.byKey(const Key('registro_clave')), 'Clave123');
    await tester.enterText(
        find.byKey(const Key('registro_confirmar')), 'Clave123');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Este correo ya está registrado'), findsOneWidget);
    expect(find.byType(ShellScreen), findsNothing);
  });

  group('Consultas dinámicas de centros', () {
    testWidgets('filtra por ciudad y por emergencias', (tester) async {
      await abrirApp(tester, conSesion: true);
      expect(await visible(tester, find.text('Encontramos 3 centros')),
          findsOneWidget);
      await tocar(tester, find.text('El Alto'));
      expect(await visible(tester, find.text('Encontramos 1 centro')),
          findsOneWidget);
      expect(await visible(tester, find.text('Posta Tres')), findsOneWidget);
      await tocar(tester, find.text('Todas las ciudades'));
      await tocar(tester, find.text('Emergencias').first);
      expect(await visible(tester, find.text('Hospital Dos')), findsOneWidget);
      expect(find.text('Centro Uno'), findsNothing);
    });
  });

  group('CRUD', () {
    testWidgets('favoritos: crear, editar nota y baja lógica', (tester) async {
      final deps = await abrirApp(tester, conSesion: true);
      final favoritos = deps.favoritos as FakeFavoritos;

      await tocar(tester, find.text('Centro Uno'));
      await tocar(tester, find.byKey(const Key('btn_favorito')));
      await tester.enterText(
          find.byKey(const Key('nota_favorito')), 'Mi doctora');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Agregado a tus favoritos.'), findsOneWidget);
      expect(favoritos.filas.single.nota, 'Mi doctora');

      await tester.pageBack();
      await tester.pumpAndSettle();
      await irAPestana(tester, 'Favoritos');
      expect(find.text('Nota: Mi doctora'), findsOneWidget);

      await tester.tap(find.byTooltip('Opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, quitar'));
      await tester.pumpAndSettle();
      expect(find.text('Quitado de tus favoritos.'), findsOneWidget);
      // Baja lógica: la fila sigue en la "tabla", pero inactiva.
      expect(favoritos.filas.single.activo, isFalse);
      expect(find.textContaining('Aún no tienes favoritos'), findsOneWidget);
    });

    testWidgets('recordatorios: validación, crear, editar y baja lógica',
        (tester) async {
      final deps = await abrirApp(tester, conSesion: true);
      final repo = deps.recordatorios as FakeRecordatorios;
      await irAPestana(tester, 'Recordar');

      // CREATE con validación
      await tester.tap(find.byKey(const Key('nuevo_recordatorio')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('guardar_recordatorio')));
      await tester.pumpAndSettle();
      expect(find.text('Escribe un título'), findsOneWidget);
      expect(find.text('Elige la fecha y la hora'), findsOneWidget);

      // Se guarda directamente en el repositorio para no depender del
      // selector de fecha nativo; luego se prueban READ/UPDATE/DELETE en UI.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await repo.crear(Recordatorio(
          titulo: 'Control de presión',
          fechaHora: DateTime.now().add(const Duration(days: 2))));
      await irAPestana(tester, 'Centros');
      await irAPestana(tester, 'Recordar');
      expect(find.text('Control de presión'), findsOneWidget); // READ

      // UPDATE
      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('recordatorio_titulo')), 'Control mensual');
      await tocar(tester, find.byKey(const Key('guardar_recordatorio')));
      expect(find.text('Control mensual'), findsOneWidget);

      // Baja lógica
      await tester.tap(find.byTooltip('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('Control mensual'), findsNothing);
      expect(repo.filas.values.single.$2, isFalse); // activo = false
    });

    testWidgets('perfil: valida y actualiza datos', (tester) async {
      final deps = await abrirApp(tester, conSesion: true);
      await irAPestana(tester, 'Perfil');
      final nombre = find.byKey(const Key('perfil_nombre'));
      await tester.ensureVisible(nombre);
      await tester.enterText(nombre, 'An');
      await tester.enterText(find.byKey(const Key('perfil_telefono')), '12');
      await tester.ensureVisible(find.byKey(const Key('guardar_perfil')));
      await tester.tap(find.byKey(const Key('guardar_perfil')));
      await tester.pumpAndSettle();
      expect(find.text('Mínimo 3 letras'), findsOneWidget);
      expect(find.textContaining('Teléfono no válido'), findsOneWidget);

      await tester.enterText(nombre, 'Ana María Pérez');
      await tester.enterText(
          find.byKey(const Key('perfil_telefono')), '71234567');
      await tocar(tester, find.byKey(const Key('guardar_perfil')));
      expect(
          find.text('Tus datos se guardaron correctamente.'), findsOneWidget);
      final perfil = (deps.perfil as FakePerfil).perfil;
      expect(perfil.nombreCompleto, 'Ana María Pérez');
      expect(perfil.telefono, '71234567');
    });
  });

  group('HU-05 accesibilidad y HU-06 modo oscuro', () {
    testWidgets('texto grande se aplica en toda la app', (tester) async {
      await abrirApp(tester, conSesion: true);
      double escala() =>
          MediaQuery.of(tester.element(find.text('Centros de salud')))
              .textScaler
              .scale(10) /
          10;
      expect(escala(), 1.0);

      await irAPestana(tester, 'Perfil');
      await tester.tap(find.byKey(const Key('switch_texto_grande')));
      await tester.pumpAndSettle();
      await irAPestana(tester, 'Centros');
      expect(escala(), closeTo(1.3, 0.001));
    });

    testWidgets('alto contraste y modo oscuro cambian el tema', (tester) async {
      final deps = await abrirApp(tester, conSesion: true);
      await irAPestana(tester, 'Perfil');

      ThemeData tema() => Theme.of(tester.element(find.text('Mi perfil')));
      expect(tema().brightness, Brightness.light);

      await tester.tap(find.text('Oscuro'));
      await tester.pumpAndSettle();
      expect(tema().brightness, Brightness.dark);
      expect(deps.ajustes.modoTema, ThemeMode.dark);

      await tester.tap(find.byKey(const Key('switch_alto_contraste')));
      await tester.pumpAndSettle();
      expect(tema().scaffoldBackgroundColor, Colors.black);
      expect(tema().colorScheme.onSurface, Colors.white);
    });

    testWidgets('las preferencias guardadas se aplican al reabrir',
        (tester) async {
      await abrirApp(tester, conSesion: true, prefs: {
        'ajustes.texto_grande': true,
        'ajustes.alto_contraste': true,
        'ajustes.modo_tema': 'dark',
      });
      final ctx =
          tester.element(await visible(tester, find.text('Centro Uno')));
      expect(Theme.of(ctx).brightness, Brightness.dark);
      expect(Theme.of(ctx).scaffoldBackgroundColor, Colors.black);
      expect(MediaQuery.of(ctx).textScaler.scale(10), closeTo(13, 0.01));
    });

    for (final variante in [
      ('normal', <String, Object>{}),
      (
        'texto grande + alto contraste + oscuro',
        <String, Object>{
          'ajustes.texto_grande': true,
          'ajustes.alto_contraste': true,
          'ajustes.modo_tema': 'dark',
        }
      ),
    ]) {
      testWidgets('botones ≥ 48 dp (Android) y ≥ 44 pt (iOS) · ${variante.$1}',
          (tester) async {
        final handle = tester.ensureSemantics();
        await abrirApp(tester, conSesion: true, prefs: variante.$2);
        for (final pestana in ['Centros', 'Favoritos', 'Recordar', 'Perfil']) {
          await irAPestana(tester, pestana);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline),
              reason: 'Android en $pestana');
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline),
              reason: 'iOS en $pestana');
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline),
              reason: 'Etiquetas en $pestana');
        }
        handle.dispose();
      });
    }

    testWidgets('contraste de texto suficiente en alto contraste',
        (tester) async {
      final handle = tester.ensureSemantics();
      await abrirApp(tester,
          conSesion: true, prefs: {'ajustes.alto_contraste': true});
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await irAPestana(tester, 'Perfil');
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });
}
