import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:monitor_app/models/alerta.dart';
import 'package:monitor_app/models/ruta.dart';
import 'package:monitor_app/services/server_config.dart';
import 'package:monitor_app/services/ubicacion.dart';

void main() {
  test('Ruta se lee igual que la entrega /api/movil/mapa/', () {
    final r = Ruta.fromJson({
      'id': 286,
      'codigo': 'C01',
      'nombre': 'Centro',
      'empresa': 'Coopetransa',
      'origen': 'A',
      'destino': 'B',
      'distancia_km': 3,
      'duracion_estimada_minutos': 20,
      'frecuencia_minutos': 10,
      'num_paradas': 4,
      'estado': 'Fuera_horario',
      'estado_nombre': 'Fuera de horario',
      'motivo': 'No hay buses programados en este momento.',
      'color': '#3F5B7A',
      'coordenadas': [
        [-75.58, 6.24],
        [-75.57, 6.25],
      ],
      'paradas': [
        {'lat': 6.245, 'lng': -75.575},
      ],
    });
    expect(r.activa, isFalse);
    expect(r.color.toARGB32(), 0xFF3F5B7A);
    expect(r.distanciaTexto, '3.0 km');
    expect(r.coordenadas, hasLength(2));
    expect(r.paradas.single.lat, 6.245);
  });

  test('Textos del estado de una alerta en «Mis reportes»', () {
    Alerta a(Map<String, dynamic> extra) => Alerta.fromJson({'id': 1, 'tipo': 'delay', 'estado': 'Pendiente', ...extra});
    expect(a({}).tipoNombre, 'Demora');
    expect(a({}).pieReporte, 'Esperando la revisión de la empresa');
    expect(a({'estado': 'En_proceso'}).estadoReporte, 'En proceso');
    expect(a({'estado': 'Cancelada', 'descartada': true}).estadoReporte, 'Descartada');
    expect(a({'estado': 'Cancelada'}).pieReporte, 'La inhabilitaste');
  });

  test('Distancia de un punto al recorrido (como distanciaARuta de la web)', () {
    // Tramo horizontal de ~1,1 km sobre el ecuador; el punto está ~111 m al norte de su mitad
    final d = Ubicacion.distanciaARuta(const LatLng(0.001, 0.005), [
      [0.0, 0.0],
      [0.01, 0.0],
    ]);
    expect(d, closeTo(111, 2));
  });

  test('La dirección del servidor se completa', () {
    expect(ServerConfig.normalizar('192.168.1.13'), 'http://192.168.1.13:8000');
    expect(ServerConfig.normalizar('http://192.168.1.13:8000/'), 'http://192.168.1.13:8000');
    expect(ServerConfig.normalizar('no es una ip'), isNull);
    expect(ServerConfig.normalizar('localbus.up.railway.app/'), 'https://localbus.up.railway.app');
    expect(ServerConfig.normalizar('http://localbus.up.railway.app'), 'https://localbus.up.railway.app');
    expect(ServerConfig.normalizar(ServerConfig.porDefecto), ServerConfig.porDefecto);
  });
}
