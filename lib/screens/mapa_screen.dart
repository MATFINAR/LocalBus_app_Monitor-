import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/bus_ubicacion.dart';
import '../models/ruta.dart';
import '../services/api_service.dart';
import '../utils/estados.dart';
import '../utils/formato.dart';

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();

  List<BusUbicacion> _buses = [];
  List<Ruta> _rutas = [];
  Timer? _timerBuses;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _timerBuses = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _cargarBuses(),
    );
  }

  @override
  void dispose() {
    _timerBuses?.cancel();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    await Future.wait([
      _cargarBuses(),
      _cargarRutas(),
    ]);
    if (mounted) {
      setState(() => _cargando = false);
    }
  }

  Future<void> _cargarBuses() async {
    try {
      final buses = await _apiService.obtenerUbicaciones();
      if (mounted) {
        setState(() => _buses = buses);
      }
    } catch (e) {
      debugPrint('Error al cargar buses: $e');
    }
  }

  Future<void> _cargarRutas() async {
    try {
      final rutas = await _apiService.obtenerRutas();
      if (mounted) {
        setState(() => _rutas = rutas);
      }
    } catch (e) {
      debugPrint('Error al cargar rutas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🗺️ Mapa de Buses'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(4.6097, -74.0817),
              initialZoom: 12,
              minZoom: 8,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.monitor_app',
              ),

              // Rutas (líneas)
              PolylineLayer(
                polylines: _rutas
                    .where((r) => r.recorrido.length >= 2)
                    .map((ruta) => Polyline(
                          points: ruta.recorrido,
                          color: etiquetaRuta(ruta).color,
                          strokeWidth: 4,
                          borderColor: Colors.white,
                          borderStrokeWidth: 1,
                        ))
                    .toList(),
              ),

              // Paradas
              MarkerLayer(
                markers: _rutas.expand((ruta) {
                  return ruta.paradas.map((parada) => Marker(
                        point: parada,
                        width: 20,
                        height: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ));
                }).toList(),
              ),

              // Buses
              MarkerLayer(
                markers: _buses.map((bus) {
                  return Marker(
                    point: LatLng(bus.latitud, bus.longitud),
                    width: 60,
                    height: 60,
                    child: GestureDetector(
                      onTap: () => _mostrarInfoBus(bus),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade800,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.greenAccent, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🚌', style: TextStyle(fontSize: 28)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Contador de buses
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade800,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🚌', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    '${_buses.length} activos',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading
          if (_cargando)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  void _mostrarInfoBus(BusUbicacion bus) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🚌', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bus ${bus.placa}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          bus.ruta ?? 'Sin ruta asignada',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 30),
              if (bus.conductor != null && bus.conductor!.isNotEmpty) ...[
                _infoItem(Icons.badge_outlined, 'Conductor', bus.conductor!),
                const SizedBox(height: 8),
              ],
              if (bus.empresa.isNotEmpty) ...[
                _infoItem(Icons.business, 'Empresa', bus.empresa),
                const SizedBox(height: 8),
              ],
              _infoItem(Icons.speed, 'Velocidad', '${bus.velocidad.toStringAsFixed(1)} km/h'),
              const SizedBox(height: 8),
              _infoItem(Icons.my_location, 'Coordenadas',
                  '${bus.latitud.toStringAsFixed(5)}, ${bus.longitud.toStringAsFixed(5)}'),
              const SizedBox(height: 8),
              _infoItem(Icons.access_time, 'Última actualización',
                  '${horaConSegundos(bus.timestamp)} (${haceCuanto(bus.timestamp)})'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _mapController.move(
                      LatLng(bus.latitud, bus.longitud),
                      16,
                    );
                  },
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('Centrar en el mapa'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(width: 12),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Expanded(child: Text(value)),
      ],
    );
  }
}