import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monitor_app/services/notificaciones.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Toda alerta nueva llega a la barra una sola vez, aunque el permiso se dé después', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({'alertas_cursor': '2026-01-01T00:00:00+00:00'});
    final barra = <int>[];
    Notificaciones.i.enBarra = (id, titulo, texto) async => barra.add(id);

    // El servidor entrega primero las más nuevas
    final servidor = MockClient((_) async => http.Response(
        jsonEncode({
          'alertas': [
            for (var id = 5; id >= 1; id--) {'id': id, 'tipo': 'info', 'ruta': 'R$id', 'descripcion': 'd'},
          ],
          'cursor': '2026-02-01T00:00:00+00:00',
        }),
        200));

    await http.runWithClient(() async {
      Notificaciones.i.permiso.value = 'default';
      await Notificaciones.i.revisar(enPantalla: false);
      expect(barra, isEmpty); // sin permiso quedan pendientes

      Notificaciones.i.permiso.value = 'granted';
      await Notificaciones.i.revisar(enPantalla: false);
      expect(barra, [1, 2, 3, 4, 5]); // todas, no solo tres

      await Notificaciones.i.revisar(enPantalla: false);
      expect(barra, hasLength(5)); // sin repetir
    }, () => servidor);
  });
}
