import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monitor_app/models/alerta.dart';
import 'package:monitor_app/screens/alertas_screen.dart';
import 'package:monitor_app/theme/app_theme.dart';

/// Una alerta de la empresa que afecta a tres rutas: en una ya está resuelta.
const _alerta = {
  'id': 7,
  'tipo': 'delay',
  'estado': 'En_proceso',
  'descripcion': 'Manifestación en la Oriental',
  'ruta_id': 1,
  'ruta_codigo': 'TN-01',
  'ruta_nombre': 'Bello - Centro',
  'rutas': [
    {'id': 1, 'codigo': 'TN-01', 'nombre': 'Bello - Centro', 'color': '#014CAB', 'estado': 'En_proceso'},
    {'id': 2, 'codigo': 'TN-02', 'nombre': 'Castilla - El Poblado', 'color': '#E63946', 'estado': 'Resuelta'},
    {'id': 3, 'codigo': 'TN-03', 'nombre': 'Manrique - Laureles', 'color': '#2E7D32', 'estado': 'En_proceso'},
  ],
};

void main() {
  test('Lee las rutas afectadas con su estado', () {
    final a = Alerta.fromJson(_alerta);
    expect(a.rutas.map((r) => r.codigo), ['TN-01', 'TN-02', 'TN-03']);
    expect(a.otrasRutas.map((r) => r.codigo), ['TN-02', 'TN-03']);
    expect(a.rutasResueltas, 1);
    expect(a.afectaRuta(3), isTrue);
    expect(a.afectaRuta(9), isFalse);
  });

  test('Sin la lista de rutas (servidor anterior) solo cuenta la principal', () {
    final a = Alerta.fromJson({..._alerta}..remove('rutas'));
    expect(a.rutas, isEmpty);
    expect(a.otrasRutas, isEmpty);
    expect(a.afectaRuta(1), isTrue);
    expect(a.afectaRuta(3), isFalse);
  });

  testWidgets('La tarjeta muestra las otras rutas y cuántas están resueltas', (tester) async {
    final servidor = MockClient((_) async => http.Response(
          jsonEncode({
            'alertas': [_alerta],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: const AlertasScreen()));
      await tester.pumpAndSettle();
    }, () => servidor);

    expect(tester.takeException(), isNull);
    expect(find.text('También en', skipOffstage: false), findsOneWidget);
    expect(find.text('TN-02', skipOffstage: false), findsOneWidget);
    expect(find.text('TN-03', skipOffstage: false), findsOneWidget);
    expect(find.text('· 1 de 3 resuelta', skipOffstage: false), findsOneWidget);
  });
}
