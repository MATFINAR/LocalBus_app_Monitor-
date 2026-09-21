import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ruta.dart';
import '../models/alerta.dart';
import '../models/bus_ubicacion.dart';

class ApiService {
  // ===== CAMBIA ESTA IP =====
  static const String baseUrl = 'http://192.168.20.59:8000';
  // ==========================

  // Obtener todas las rutas
  Future<List<Ruta>> obtenerRutas() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/rutas/'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List rutas = data['rutas'] ?? [];
        return rutas.map((r) => Ruta.fromJson(r)).toList();
      } else {
        throw Exception('Error al obtener rutas');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener todas las alertas
  Future<List<Alerta>> obtenerAlertas() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/alertas/'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List alertas = data['alertas'] ?? [];
        return alertas.map((a) => Alerta.fromJson(a)).toList();
      } else {
        throw Exception('Error al obtener alertas');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener ubicaciones de buses activos
  Future<List<BusUbicacion>> obtenerUbicaciones() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/ubicaciones/'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List buses = data['buses'] ?? [];
        return buses.map((b) => BusUbicacion.fromJson(b)).toList();
      } else {
        throw Exception('Error al obtener ubicaciones');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}