import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monitor_app/models/ruta.dart';
import 'package:monitor_app/screens/mapa_screen.dart';
import 'package:monitor_app/services/ventana_flotante.dart';
import 'package:monitor_app/theme/app_theme.dart';

/// Imagen de 1x1 para los mosaicos del mapa.
final _mosaico = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

void main() {
  test('Lee una demora y a qué rutas afecta', () {
    final d = DemoraMapa.fromJson({
      'alerta': 7, 'lat': 6.245, 'lng': -75.575, 'descripcion': 'Trancón', 'ruta': 'Centro',
      'ruta_codigo': 'R1', 'hace': '5 minutos', 'rutas': [1, 2], 'directas': [1],
    });
    expect(d.afecta(2), isTrue);
    expect(d.afecta(3), isFalse);
    expect(d.enRuta(1), isTrue);
    expect(d.enRuta(2), isFalse);
  });

  testWidgets('Al elegir una ruta se ven las demoras que pueden afectarla, y solo esas', (tester) async {
    final semantica = tester.ensureSemantics();
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(VentanaFlotante.canal, (MethodCall _) async => null);
    final servidor = MockClient((p) async {
      if (p.url.host == 'tile.openstreetmap.org') return http.Response.bytes(_mosaico, 200);
      return http.Response(
          jsonEncode({
            'rutas': [
              {'id': 1, 'codigo': 'R1', 'nombre': 'Centro', 'coordenadas': [[-75.58, 6.24], [-75.57, 6.25]]},
              {'id': 2, 'codigo': 'R2', 'nombre': 'Norte', 'coordenadas': [[-75.58, 6.24], [-75.56, 6.26]]},
              {'id': 3, 'codigo': 'R3', 'nombre': 'Sur', 'coordenadas': [[-75.60, 6.20], [-75.61, 6.19]]},
            ],
            'demoras': [
              {'alerta': 7, 'lat': 6.245, 'lng': -75.575, 'descripcion': 'Trancón por un choque', 'ruta': 'Centro',
               'ruta_codigo': 'R1', 'hace': '5 minutos', 'rutas': [1, 2], 'directas': [1]},
            ],
            'buses': [],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: const MapaScreen()));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      final marcador = find.bySemanticsLabel('Demora: Trancón por un choque');
      expect(marcador, findsNothing); // sin ruta elegida no se pinta

      // R2 no es la ruta de la alerta, pero pasa a 500 m: también se le muestra
      await tester.ensureVisible(find.text('R2').last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('R2').last);
      await tester.pump(const Duration(milliseconds: 500));
      expect(marcador, findsOneWidget);
      expect(find.textContaining('1 demora reportada'), findsWidgets);

      await tester.tap(marcador);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Demora · hace 5 minutos'), findsOneWidget);
      expect(find.text('Reportada en R1 · Centro, a 500 m o menos de esta ruta'), findsOneWidget);

      // R3 queda lejos: no se le muestra
      await tester.ensureVisible(find.text('R3').last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('R3').last);
      await tester.pump(const Duration(milliseconds: 500));
      expect(marcador, findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    }, () => servidor);

    expect(tester.takeException(), isNull);
    semantica.dispose();
  });
}
