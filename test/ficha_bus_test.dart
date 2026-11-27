import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monitor_app/screens/mapa_screen.dart';
import 'package:monitor_app/theme/app_theme.dart';

final _mosaico = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

void main() {
  // Las tipografías reales: la de relleno de las pruebas es mucho más ancha y daría medidas falsas
  setUpAll(() async {
    for (final (familia, archivos) in [
      ('Barlow Condensed', ['BarlowCondensed-Medium', 'BarlowCondensed-SemiBold', 'BarlowCondensed-Bold']),
      ('Atkinson Hyperlegible', ['AtkinsonHyperlegible-Regular', 'AtkinsonHyperlegible-Bold']),
    ]) {
      final cargador = FontLoader(familia);
      for (final a in archivos) {
        cargador.addFont(Future.value(ByteData.view(File('assets/fonts/$a.ttf').readAsBytesSync().buffer)));
      }
      await cargador.load();
    }
  });

  for (final escala in [1.0, 1.3]) {
    testWidgets('La tarjeta del bus cabe completa (letra x$escala)', (tester) async {
      final servidor = MockClient((p) async {
        if (p.url.host == 'tile.openstreetmap.org') return http.Response.bytes(_mosaico, 200);
        final d = p.url.path.contains('tiempo-llegada')
            ? {'status': 'ok', 'tiempo_texto': '12 min', 'tiempo_minutos': 12, 'distancia_km': 3.4}
            : {
                'rutas': [
                  {'id': 1, 'codigo': 'R1', 'nombre': 'Centro', 'coordenadas': [[-75.58, 6.24], [-75.57, 6.25]]},
                ],
                'buses': [
                  {'bus_id': 9, 'ruta_id': 1, 'placa': 'ABC123', 'ruta': 'San Antonio de Prado - Itagüí',
                   'latitud': 6.245, 'longitud': -75.575, 'velocidad': 32.5},
                ],
              };
        return http.Response.bytes(utf8.encode(jsonEncode(d)), 200);
      });

      // Tamaño de un celular
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(escala)), child: child!),
          home: const MapaScreen(),
        ));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        // Se elige la ruta (con letra grande su tarjeta puede quedar recortada, así que sin simular el dedo)
        // y luego el bus del mapa
        tester.widget<InkWell>(find.ancestor(of: find.text('R1'), matching: find.byType(InkWell)).first).onTap!();
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        final chapa = find.ancestor(of: find.text('R1'), matching: find.byType(GestureDetector)).first;
        tester.widget<GestureDetector>(chapa).onTap!();
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(find.textContaining('km/h'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
      }, () => servidor);
    });
  }
}
