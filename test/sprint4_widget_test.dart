import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saludcerca/app.dart';
import 'package:saludcerca/core/app_scope.dart';
import 'package:saludcerca/services/api_cliente.dart';
import 'package:saludcerca/services/voz_servicio.dart';
import 'package:saludcerca/theme/app_theme.dart';

import 'fakes.dart';

/// HU-17 · Pruebas de widgets del Sprint 4 (sin internet ni micrófono):
/// tarjeta de calidad del aire (HU-15) con errores simulados y dictado del
/// título de un recordatorio por voz.

Future<Dependencias> abrir(WidgetTester tester,
    {FakeCalidadAire? aire,
    FakeVoz? voz,
    Map<String, Object> prefs = const {}}) async {
  tester.view.physicalSize = const Size(1080, 2400); // 360 x 800 dp
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final deps = await crearDependencias(
      conSesion: true, prefs: prefs, calidadAire: aire, voz: voz);
  await tester.pumpWidget(SaludCercaApp(dependencias: deps));
  await tester.pumpAndSettle();
  return deps;
}

Future<void> verTarjetaAire(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.byKey(const Key('tarjeta_aire')), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

Future<void> abrirFormulario(WidgetTester tester) async {
  await tester.tap(find.descendant(
      of: find.byType(NavigationBar), matching: find.text('Recordar')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('nuevo_recordatorio')));
  await tester.pumpAndSettle();
}

String tituloActual(WidgetTester tester) => tester
    .widget<TextFormField>(find.byKey(const Key('recordatorio_titulo')))
    .controller!
    .text;

void main() {
  group('HU-15 calidad del aire y consejos', () {
    testWidgets('aire limpio: índice, nivel en palabras y consejo',
        (tester) async {
      final aire = FakeCalidadAire()..aire = airePrueba(indice: 18, uv: 3.7);
      await abrir(tester, aire: aire);
      await verTarjetaAire(tester);
      expect(
          find.descendant(
              of: find.byKey(const Key('aire_indice')),
              matching: find.text('18')),
          findsOneWidget);
      expect(find.byKey(const Key('aire_nivel')), findsOneWidget);
      expect(find.text('Buena'), findsOneWidget);
      expect(find.text('Aire limpio'), findsOneWidget);
      expect(find.text('Sol moderado (UV 4)'), findsOneWidget);
      expect(find.textContaining('PM2,5: 1.6 µg/m³'), findsOneWidget);
    });

    testWidgets('aire dañino: consejo de quedarse en casa en color de alerta',
        (tester) async {
      final aire = FakeCalidadAire()..aire = airePrueba(indice: 160, pm25: 70);
      await abrir(tester, aire: aire);
      await verTarjetaAire(tester);
      expect(find.text('Dañina'), findsOneWidget);
      expect(find.text('Mejor quédate en casa'), findsOneWidget);
      // El color sale del tema (ColoresSalud.cerrado), no está fijo.
      final ctx = tester.element(find.byKey(const Key('aire_nivel')));
      final texto = tester.widget<Text>(find.byKey(const Key('aire_nivel')));
      expect(texto.style?.color, ColoresSalud.de(ctx).cerrado);
    });

    testWidgets('HTTP 503 simulado: mensaje y Reintentar funciona',
        (tester) async {
      final aire = FakeCalidadAire()
        ..error = const ApiException(
            TipoErrorApi.servidor, 'la calidad del aire',
            codigoHttp: 503);
      await abrir(tester, aire: aire);
      await verTarjetaAire(tester);
      expect(find.byKey(const Key('aire_error')), findsOneWidget);
      expect(find.textContaining('(error 503)'), findsOneWidget);
      // El resto de la pantalla sigue funcionando.
      expect(find.byKey(const Key('tarjeta_clima')), findsOneWidget);

      aire.error = null;
      await tester.ensureVisible(find.byKey(const Key('aire_reintentar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('aire_reintentar')));
      await tester.pumpAndSettle();
      expect(find.text('Aire limpio'), findsOneWidget);
      expect(aire.llamadas, 2);
    });

    for (final (error, texto) in [
      (
        const ApiException(TipoErrorApi.sinConexion, 'la calidad del aire'),
        'Sin conexión a internet'
      ),
      (
        const ApiException(TipoErrorApi.tiempoAgotado, 'la calidad del aire'),
        'tardó demasiado'
      ),
      (
        const ApiException(
            TipoErrorApi.limiteSolicitudes, 'la calidad del aire',
            codigoHttp: 429),
        'muchas consultas'
      ),
      (
        const ApiException(TipoErrorApi.servidor, 'la calidad del aire',
            codigoHttp: 500),
        '(error 500)'
      ),
    ]) {
      testWidgets('error simulado ${error.tipo.name}: "$texto"',
          (tester) async {
        await abrir(tester, aire: FakeCalidadAire()..error = error);
        await verTarjetaAire(tester);
        expect(find.textContaining(texto), findsOneWidget);
        expect(find.byKey(const Key('aire_reintentar')), findsOneWidget);
      });
    }

    testWidgets('texto grande y modo oscuro de alto contraste sin desbordes',
        (tester) async {
      await abrir(tester,
          aire: FakeCalidadAire()..aire = airePrueba(indice: 120, uv: 11),
          prefs: {
            'ajustes.texto_grande': true,
            'ajustes.alto_contraste': true,
            'ajustes.modo_tema': 'dark'
          });
      await verTarjetaAire(tester);
      expect(find.text('Cuidado si eres adulto mayor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Recordatorio por voz', () {
    testWidgets('el dictado llena el título y el usuario puede corregirlo',
        (tester) async {
      final voz = FakeVoz();
      await abrir(tester, voz: voz);
      await abrirFormulario(tester);
      expect(find.text('Dictar el título con la voz'), findsOneWidget);
      // El botón mide al menos 48 dp.
      expect(
          tester.getSize(find.byKey(const Key('recordatorio_dictar'))).height,
          greaterThanOrEqualTo(48));

      await tester.tap(find.byKey(const Key('recordatorio_dictar')));
      await tester.pumpAndSettle();
      expect(voz.llamadas, 1);
      expect(tituloActual(tester), 'Sacar ficha en hospital Miraflores');
      expect(find.text('Revisa el título y corrígelo si hace falta.'),
          findsOneWidget);

      // El usuario corrige con el teclado antes de guardar.
      await tester.enterText(find.byKey(const Key('recordatorio_titulo')),
          'Sacar ficha en el Hospital de Miraflores');
      expect(tituloActual(tester), 'Sacar ficha en el Hospital de Miraflores');
    });

    testWidgets('mientras escucha muestra lo reconocido y se puede detener',
        (tester) async {
      final voz = FakeVoz()
        ..manual = true
        ..parciales = const ['sacar ficha'];
      await abrir(tester, voz: voz);
      await abrirFormulario(tester);
      await tester.tap(find.byKey(const Key('recordatorio_dictar')));
      await tester.pump();
      expect(find.text('Escuchando… toca para terminar'), findsOneWidget);
      expect(find.text('«sacar ficha»'), findsOneWidget);
      expect(tituloActual(tester), isEmpty); // aún no se toca el título

      await tester.tap(find.byKey(const Key('recordatorio_dictar')));
      await tester.pumpAndSettle();
      expect(voz.detenido, isTrue);
      expect(find.text('Dictar el título con la voz'), findsOneWidget);
      expect(tituloActual(tester), 'Sacar ficha en hospital Miraflores');
    });

    testWidgets('permiso de micrófono negado: avisa y no cambia el título',
        (tester) async {
      final voz = FakeVoz()
        ..error = const VozException(TipoErrorVoz.permisoDenegado);
      await abrir(tester, voz: voz);
      await abrirFormulario(tester);
      await tester.enterText(
          find.byKey(const Key('recordatorio_titulo')), 'Control de presión');
      await tester.tap(find.byKey(const Key('recordatorio_dictar')));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('permite el uso del micrófono'), findsOneWidget);
      expect(tituloActual(tester), 'Control de presión');
      expect(find.text('Dictar el título con la voz'), findsOneWidget);
    });

    testWidgets('si no entendió, pide hablar otra vez', (tester) async {
      final voz = FakeVoz()
        ..error = const VozException(TipoErrorVoz.noEntendio);
      await abrir(tester, voz: voz);
      await abrirFormulario(tester);
      await tester.tap(find.byKey(const Key('recordatorio_dictar')));
      await tester.pumpAndSettle();
      expect(find.textContaining('No te escuchamos bien'), findsOneWidget);
      expect(tituloActual(tester), isEmpty);
    });

    testWidgets('un error inesperado del reconocedor no rompe el formulario',
        (tester) async {
      final voz = FakeVoz()..error = StateError('falla nativa');
      await abrir(tester, voz: voz);
      await abrirFormulario(tester);
      await tester.tap(find.byKey(const Key('recordatorio_dictar')));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudo usar el dictado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
