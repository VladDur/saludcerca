import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saludcerca/app.dart';
import 'package:saludcerca/core/validadores.dart';
import 'package:saludcerca/models/farmacia.dart';
import 'package:saludcerca/screens/farmacias_screen.dart';
import 'package:saludcerca/services/whatsapp_servicio.dart';
import 'package:saludcerca/settings/ajustes_controller.dart';

import 'fakes.dart';

/// Consulta de medicamentos a la farmacia por WhatsApp (sin internet).

const numeroPrueba = '59170000000';

Future<void> abrirDetalle(WidgetTester tester, FakeWhatsApp whatsapp,
    {String? numero = numeroPrueba,
    Map<String, Object> prefs = const {}}) async {
  tester.view.physicalSize = const Size(1080, 2400); // 360 x 800 dp
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final farmacias = FakeFarmacias();
  farmacias.farmacias
    ..clear()
    ..add(farmaciaPrueba('f1', 'Farmacia Central', whatsapp: numero));
  final deps = await crearDependencias(
      conSesion: true, prefs: prefs, farmacias: farmacias, whatsapp: whatsapp);
  await tester.pumpWidget(SaludCercaApp(dependencias: deps));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(
      of: find.byType(NavigationBar), matching: find.text('Farmacias')));
  await tester.pumpAndSettle();
  await tocar(tester, find.byType(TarjetaFarmacia));
}

Future<void> tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

final botonConsultar = find.byKey(const Key('farmacia_consultar'));
final campo = find.byKey(const Key('consulta_medicamento'));
final botonAbrir = find.byKey(const Key('consulta_abrir'));

void main() {
  group('enlace y mensaje', () {
    test('el enlace wa.me conserva espacios, tildes y signos', () {
      const texto = '¿Tienen ácido fólico + hierro & zinc?\nGracias';
      final enlace = enlaceWhatsApp(numeroPrueba, texto);
      expect(enlace.host, 'wa.me');
      expect(enlace.path, '/$numeroPrueba');
      expect(enlace.queryParameters['text'], texto);
      expect(enlace.toString(), isNot(contains('+')));
    });

    test('el mensaje nombra la farmacia y el medicamento', () {
      final m = mensajeCompra('Farmacia Central', '  Ibuprofeno 400 mg ');
      expect(m, contains('Farmacia Central'));
      expect(m, contains('medicamento: Ibuprofeno 400 mg.'));
    });

    test('valida el medicamento', () {
      expect(Validadores.medicamento('  '), 'Escribe el medicamento');
      expect(Validadores.medicamento('ab'), isNotNull);
      expect(Validadores.medicamento('a' * 101), isNotNull);
      expect(Validadores.medicamento('AAS'), isNull);
    });

    test('la farmacia lee su número de WhatsApp (opcional)', () {
      final mapa = <String, dynamic>{
        'id': 'f1',
        'nombre': 'Farmacia',
        'ciudad': 'La Paz',
        'zona': 'Centro',
        'direccion': 'Calle 1',
        'telefono': '2-100-0001',
        'latitud': -16.5,
        'longitud': -68.1,
        'whatsapp': null,
      };
      expect(Farmacia.desdeMapa(mapa).whatsapp, isNull);
      mapa['whatsapp'] = numeroPrueba;
      expect(Farmacia.desdeMapa(mapa).whatsapp, numeroPrueba);
    });
  });

  group('botón Consultar', () {
    testWidgets('no aparece si la farmacia no tiene WhatsApp', (tester) async {
      await abrirDetalle(tester, FakeWhatsApp(), numero: null);
      expect(find.text('Dirección'), findsOneWidget);
      expect(botonConsultar, findsNothing);
    });

    testWidgets('pide el medicamento y abre el chat con el mensaje',
        (tester) async {
      final w = FakeWhatsApp();
      await abrirDetalle(tester, w);
      await tocar(tester, botonConsultar);
      await tocar(tester, botonAbrir);
      expect(find.text('Escribe el medicamento'), findsOneWidget);
      expect(w.numero, isNull);
      await tester.enterText(campo, 'Paracetamol 500 mg');
      await tocar(tester, botonAbrir);
      expect(w.numero, numeroPrueba);
      expect(
          w.mensaje, mensajeCompra('Farmacia Central', 'Paracetamol 500 mg'));
      expect(campo, findsNothing);
    });

    testWidgets('Cancelar no abre WhatsApp', (tester) async {
      final w = FakeWhatsApp();
      await abrirDetalle(tester, w);
      await tocar(tester, botonConsultar);
      await tocar(tester, find.text('Cancelar'));
      expect(w.numero, isNull);
      expect(botonConsultar, findsOneWidget);
    });

    testWidgets('si no se puede abrir, avisa y ofrece el teléfono',
        (tester) async {
      final w = FakeWhatsApp()..disponible = false;
      await abrirDetalle(tester, w);
      await tocar(tester, botonConsultar);
      await tester.enterText(campo, 'Paracetamol');
      await tocar(tester, botonAbrir);
      expect(find.textContaining('No pudimos abrir WhatsApp'), findsOneWidget);
      expect(find.textContaining('2-100-000f1'), findsOneWidget);
    });

    testWidgets('accesible con texto grande, alto contraste y oscuro',
        (tester) async {
      await abrirDetalle(tester, FakeWhatsApp(), prefs: {
        AjustesController.kTextoGrande: true,
        AjustesController.kAltoContraste: true,
        AjustesController.kModoTema: 'oscuro',
      });
      await tester.ensureVisible(botonConsultar);
      await tester.pumpAndSettle();
      expect(tester.getSize(botonConsultar).height, greaterThanOrEqualTo(48));
      await tocar(tester, botonConsultar);
      expect(tester.getSize(botonAbrir).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });
  });
}
