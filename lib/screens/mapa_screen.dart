import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config.dart';
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

class _MapaScreenState extends State<MapaScreen> with WidgetsBindingObserver {
  /// Centro de Medellín, donde opera LocalBus.
  static const LatLng _centroInicial = LatLng(6.2442, -75.5812);

  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();

  List<BusUbicacion> _buses = [];
  List<Ruta> _rutas = [];
  Timer? _timerBuses;
  Timer? _timerRutas;
  bool _cargando = true;

  /// Hay una consulta de buses en curso: si el servidor tarda más que el intervalo, no se apilan.
  bool _consultandoBuses = false;

  /// Último error de conexión; null cuando la última consulta salió bien.
  String? _errorConexion;
  DateTime? _ultimaActualizacion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarDatos();
    _iniciarConsultas();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detenerConsultas();
    super.dispose();
  }

  /// Con la app en segundo plano no se consulta: ahorra batería y datos.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cargarDatos();
      _iniciarConsultas();
    } else if (state == AppLifecycleState.paused) {
      _detenerConsultas();
    }
  }

  void _iniciarConsultas() {
    _detenerConsultas();
    _timerBuses = Timer.periodic(Config.intervaloBuses, (_) => _cargarBuses());
    _timerRutas = Timer.periodic(Config.intervaloRutas, (_) => _cargarRutas());
  }

  void _detenerConsultas() {
    _timerBuses?.cancel();
    _timerRutas?.cancel();
    _timerBuses = null;
    _timerRutas = null;
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
    if (_consultandoBuses) return;
    _consultandoBuses = true;
    try {
      final buses = await _apiService.obtenerUbicaciones();
      if (mounted) {
        setState(() {
          _buses = buses;
          _errorConexion = null;
          _ultimaActualizacion = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorConexion = e.toString());
    } finally {
      _consultandoBuses = false;
    }
  }

  Future<void> _cargarRutas() async {
    try {
      final rutas = await _apiService.obtenerRutas();
      if (mounted) {
        setState(() => _rutas = rutas);
      }
    } catch (e) {
      // El aviso de conexión lo da la consulta de buses, que corre cada pocos segundos
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
              initialCenter: _centroInicial,
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
                              color: Colors.black.withValues(alpha: 0.3),
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
                    color: Colors.black.withValues(alpha: 0.2),
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

          // Sin conexión: se ve mientras dure y se va solo al recuperarse
          if (_errorConexion != null && !_cargando)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _avisoSinConexion(),
            ),

          // Carga inicial
          if (_cargando)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avisoSinConexion() {
    final ultima = _ultimaActualizacion;
    return Material(
      color: Colors.red.shade700,
      borderRadius: BorderRadius.circular(8),
      elevation: 4,
      child: Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.cloud_off, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _errorConexion!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ultima == null
                          ? 'Reintentando…'
                          : 'Reintentando… Posiciones de las ${horaConSegundos(ultima)}.',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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