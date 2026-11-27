import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monitor_app/models/alerta.dart';
import 'package:monitor_app/screens/mapa_screen.dart';
import 'package:monitor_app/screens/perfil_screen.dart';
import 'package:monitor_app/services/navegacion.dart';
import 'package:monitor_app/services/notificaciones.dart';
import 'package:monitor_app/services/sesion.dart';
import 'package:monitor_app/services/texto.dart';
import 'package:monitor_app/theme/app_theme.dart';

final _mosaico = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

http.Response _json(Object d) => http.Response.bytes(utf8.encode(jsonEncode(d)), 200);

const _mapa = {
  'rutas': [
    {'id': 1, 'codigo': 'R1', 'nombre': 'Centro', 'coordenadas': [[-75.58, 6.24], [-75.57, 6.25]]},
  ],
};

Future<void> _esperar(WidgetTester tester, Duration total) async {
  for (var t = Duration.zero; t < total; t += const Duration(milliseconds: 500)) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  test('La búsqueda no distingue tildes ni mayúsculas', () {
    expect(coincideBusqueda('itagui', ['ES-06', 'San Antonio de Prado - Itagüí']), isTrue);
    expect(coincideBusqueda('NIQUIA centro', ['TN-01', 'Niquía - Centro']), isTrue);
    expect(coincideBusqueda('bello', ['TN-01', 'Niquía - Centro']), isFalse);
    expect(coincideBusqueda('  ', ['x']), isTrue);
  });

  testWidgets('Mapa: una consulta de buses a la vez, ninguna fuera de la pestaña, y el tablero se pone al día',
      (tester) async {
    Navegacion.pestana.value = Navegacion.mapa;
    var buses = 0, enCurso = 0, maximo = 0, mapas = 0;
    final servidor = MockClient((p) async {
      if (p.url.host == 'tile.openstreetmap.org') return http.Response.bytes(_mosaico, 200);
      if (p.url.path == '/api/ubicaciones/') {
        buses++;
        enCurso++;
        if (enCurso > maximo) maximo = enCurso;
        await Future<void>.delayed(const Duration(seconds: 8)); // servidor lento: más que los 5 s entre consultas
        enCurso--;
        return _json({'buses': []});
      }
      mapas++;
      return _json(_mapa);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: const MapaScreen()));
      await _esperar(tester, const Duration(seconds: 2));
      tester.widget<InkWell>(find.ancestor(of: find.text('R1'), matching: find.byType(InkWell)).first).onTap!();
      await _esperar(tester, const Duration(seconds: 20));
      expect(maximo, 1); // nunca dos a la vez

      await _esperar(tester, const Duration(seconds: 9)); // termina la que estaba en curso
      Navegacion.pestana.value = Navegacion.alertas;
      final antes = buses;
      await _esperar(tester, const Duration(seconds: 20));
      expect(buses, antes); // en otra pestaña no se pide nada

      final mapasAntes = mapas;
      Notificaciones.i.llegaron.value++;
      await _esperar(tester, const Duration(seconds: 1));
      expect(mapas, mapasAntes + 1); // llegó una alerta: el tablero se actualiza

      Navegacion.pestana.value = Navegacion.mapa;
      await tester.pumpWidget(const SizedBox.shrink());
      await _esperar(tester, const Duration(seconds: 10));
    }, () => servidor);
  });

  testWidgets('Editar perfil: tu propio nombre de usuario no se marca como «en uso»', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await Sesion.i.iniciar('t', Usuario.fromJson({'nombre': 'Ana', 'nickName': 'ana.perez', 'email': 'a@b.co'}),
        recordar: false);
    final consultados = <String>[];
    final servidor = MockClient((p) async {
      if (p.url.path.endsWith('/disponible/')) {
        consultados.add('${(jsonDecode(p.body) as Map)['valor']}');
        return _json({'existe': true});
      }
      return _json({'usuario': {'nombre': 'Ana', 'nickName': 'ana.perez', 'email': 'a@b.co'}});
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: const PerfilScreen()));
      await tester.pumpAndSettle();
      expect(find.text('EDITAR PERFIL'), findsOneWidget);
      tester.widget<TextButton>(find.ancestor(of: find.text('EDITAR PERFIL'), matching: find.byType(TextButton))).onPressed!();
      await tester.pumpAndSettle();

      // Campos: nombre, correo, nombre de usuario, teléfono
      final campo = find.byType(TextField).at(2);
      expect(tester.widget<TextField>(campo).controller!.text, 'ana.perez');
      await tester.enterText(campo, 'ana.pere');
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(campo, 'ana.perez');
      await tester.pump(const Duration(seconds: 1));
    }, () => servidor);

    expect(consultados, ['ana.pere']); // el propio no se consulta
    expect(find.textContaining('ya está en uso'), findsNothing);
    await Sesion.i.cerrar();
  });
}
