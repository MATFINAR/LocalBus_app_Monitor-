import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class UbicacionError implements Exception {
  UbicacionError(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Ubicación del celular. La última conocida sirve para la llegada de los buses, como en la web.
class Ubicacion {
  Ubicacion._();

  static LatLng? ultima;

  /// Pide permiso si hace falta. Lanza [UbicacionError] con un mensaje para la persona.
  static Future<LatLng> obtener() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw UbicacionError('Activa la ubicación (GPS) de tu celular para usar esta opción.');
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.deniedForever) {
      throw UbicacionError('No pudimos obtener tu ubicación. Permítela a LocalBus en los ajustes del celular.');
    }
    if (permiso == LocationPermission.denied) {
      throw UbicacionError('No pudimos obtener tu ubicación. Revisa que la app tenga permiso.');
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return ultima = LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      final conocida = await Geolocator.getLastKnownPosition();
      if (conocida != null) return ultima = LatLng(conocida.latitude, conocida.longitude);
      throw UbicacionError('No pudimos obtener tu ubicación. Inténtalo de nuevo en un lugar abierto.');
    }
  }

  /// Sin preguntar nada: solo si ya hay permiso (al abrir el mapa, para la llegada de los buses).
  static Future<LatLng?> silenciosa() async {
    try {
      final permiso = await Geolocator.checkPermission();
      if (permiso != LocationPermission.always && permiso != LocationPermission.whileInUse) return null;
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
      return ultima = LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Distancia en metros del punto `p` al recorrido (tramo más cercano, no solo los vértices),
  /// igual que distanciaARuta() de la web. `coordenadas` en [lng, lat].
  static double distanciaARuta(LatLng p, List<List<double>> coordenadas) {
    const r = 6371000.0;
    const rad = 3.141592653589793 / 180;
    final cosLat = _cos(p.latitude * rad);
    List<double> xy(List<double> c) => [(c[0] - p.longitude) * rad * r * cosLat, (c[1] - p.latitude) * rad * r];

    var minima = double.infinity;
    for (var i = 0; i < coordenadas.length; i++) {
      final a = xy(coordenadas[i]);
      if (i == coordenadas.length - 1) {
        if (coordenadas.length == 1) minima = _min(minima, _hypot(a[0], a[1]));
        break;
      }
      final b = xy(coordenadas[i + 1]);
      final dx = b[0] - a[0], dy = b[1] - a[1];
      final largo2 = dx * dx + dy * dy;
      final t = largo2 == 0 ? 0.0 : (-(a[0] * dx + a[1] * dy) / largo2).clamp(0.0, 1.0);
      minima = _min(minima, _hypot(a[0] + t * dx, a[1] + t * dy));
    }
    return minima;
  }

  static double _cos(double x) => math.cos(x);
  static double _hypot(double a, double b) => math.sqrt(a * a + b * b);
  static double _min(double a, double b) => a < b ? a : b;
}
