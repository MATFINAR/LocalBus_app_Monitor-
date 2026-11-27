import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monitor_app/screens/rutas_screen.dart';
import 'package:monitor_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fuentes.dart';

final _mosaico = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

void main() {
  setUpAll(cargarFuentes);

  testWidgets('Rutas > Mapa: arrastrar hacia arriba mueve el mapa, no la página', (tester) async {
    SharedPreferences.setMockInitialValues({'rutas_vista': 'mapa'});
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final servidor = MockClient((p) async {
      if (p.url.host == 'tile.openstreetmap.org') return http.Response.bytes(_mosaico, 200);
      return http.Response.bytes(
          utf8.encode(jsonEncode({
            'rutas': [
              {'id': 1, 'codigo': 'R1', 'nombre': 'Centro', 'coordenadas': [[-75.58, 6.24], [-75.57, 6.25]]},
            ],
          })),
          200);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: const RutasScreen()));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      final mapa = find.byType(FlutterMap);
      await tester.ensureVisible(mapa);
      await tester.pumpAndSettle();
      final pagina = tester.state<ScrollableState>(
          find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
      final antes = pagina.position.pixels;
      final camara = MapCamera.of(tester.element(find.byType(TileLayer).first)).center;

      await tester.drag(mapa, const Offset(0, -150));
      await tester.pumpAndSettle();

      expect(pagina.position.pixels, antes); // la página no se movió
      expect(MapCamera.of(tester.element(find.byType(TileLayer).first)).center, isNot(camara)); // el mapa sí
    }, () => servidor);
  });
}
