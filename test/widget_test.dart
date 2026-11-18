// Pruebas de lectura de las respuestas de la API de LocalBus (Django).
// Los JSON imitan lo que devuelven /api/rutas/, /api/alertas/ y /api/ubicaciones/.

import 'package:flutter_test/flutter_test.dart';
import 'package:monitor_app/models/alerta.dart';
import 'package:monitor_app/models/bus_ubicacion.dart';
import 'package:monitor_app/models/ruta.dart';
import 'package:monitor_app/utils/formato.dart';

void main() {
  group('Ruta.fromJson', () {
    test('lee el estado calculado, su nombre y el motivo', () {
      final ruta = Ruta.fromJson({
        'id': 3,
        'codigo': 'R3',
        'nombre': 'Centro - Robledo',
        'estado': 'Sin_buses',
        'estado_nombre': 'Sin buses activos',
        'motivo': 'Hay buses programados, pero ninguno está enviando su ubicación en este momento.',
        'coordenadas': [
          [-75.57, 6.25],
          [-75.58, 6.26],
        ],
        'paradas': [
          {'lat': 6.25, 'lng': -75.57},
        ],
      });

      expect(ruta.estado, Ruta.sinBuses);
      expect(ruta.estadoNombre, 'Sin buses activos');
      expect(ruta.motivo, startsWith('Hay buses programados'));
      expect(ruta.estaActiva, isFalse);
      // El backend envía [longitud, latitud]
      expect(ruta.recorrido.first.latitude, 6.25);
      expect(ruta.recorrido.first.longitude, -75.57);
      expect(ruta.paradas.single.latitude, 6.25);
    });

    test('sin estado_nombre usa el estado sin guiones bajos', () {
      final ruta = Ruta.fromJson({'estado': 'Fuera_horario'});
      expect(ruta.estadoNombre, 'Fuera horario');
    });

    test('ignora coordenadas mal formadas', () {
      final ruta = Ruta.fromJson({
        'coordenadas': [
          [-75.57],
          null,
          [-75.58, 6.26],
        ],
        'paradas': [
          {'lat': null, 'lng': -75.57},
        ],
      });
      expect(ruta.recorrido, hasLength(1));
      expect(ruta.paradas, isEmpty);
    });
  });

  group('Alerta.fromJson', () {
    test('lee estado, publicación y vencimiento', () {
      final alerta = Alerta.fromJson({
        'id': 10,
        'tipo': 'delay',
        'descripcion': 'Trancón en la 80',
        'estado': 'En_proceso',
        'ruta': 'Centro - Robledo',
        'ruta_id': 3,
        'usuario': 'Transportes ABC',
        'fecha': '2026-11-17T10:00:00-05:00',
        'publicada': '2026-11-17T10:05:00-05:00',
        'vence': '2026-11-17T12:05:00-05:00',
      });

      expect(alerta.estaVigente, isTrue);
      expect(alerta.fechaVisible, alerta.publicada);
      expect(alerta.vence, isNotNull);
    });

    test('sin fecha de publicación usa la de creación', () {
      final alerta = Alerta.fromJson({
        'estado': 'Resuelta',
        'fecha': '2026-11-17T10:00:00-05:00',
        'publicada': null,
        'vence': null,
      });
      expect(alerta.estaResuelta, isTrue);
      expect(alerta.fechaVisible, alerta.fecha);
    });
  });

  test('BusUbicacion.fromJson lee conductor, empresa y ruta', () {
    final bus = BusUbicacion.fromJson({
      'bus_id': 7,
      'placa': 'ABC123',
      'empresa': 'Transportes ABC',
      'ruta': 'Centro - Robledo',
      'ruta_id': 3,
      'conductor': 'Ana Pérez',
      'latitud': 6.25,
      'longitud': -75.57,
      'velocidad': 28,
      'timestamp': '2026-11-17T10:00:00-05:00',
    });

    expect(bus.conductor, 'Ana Pérez');
    expect(bus.empresa, 'Transportes ABC');
    expect(bus.rutaId, 3);
    expect(bus.velocidad, 28.0);
  });

  group('formato', () {
    final ahora = DateTime(2026, 11, 17, 15, 0);

    test('haceCuanto', () {
      expect(haceCuanto(ahora, ahora: ahora), 'Ahora');
      expect(haceCuanto(ahora.subtract(const Duration(minutes: 5)), ahora: ahora), 'Hace 5 min');
      expect(haceCuanto(ahora.subtract(const Duration(hours: 3)), ahora: ahora), 'Hace 3 h');
      expect(haceCuanto(ahora.subtract(const Duration(days: 1)), ahora: ahora), 'Hace 1 día');
    });

    test('hastaCuando', () {
      expect(hastaCuando(DateTime(2026, 11, 17, 16, 30), ahora: ahora), 'Hasta las 16:30');
      expect(hastaCuando(DateTime(2026, 11, 18, 8, 0), ahora: ahora), 'Hasta el 18/11 a las 08:00');
    });
  });
}
