import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config.dart';
import '../models/alerta.dart';
import '../models/bus_ubicacion.dart';
import '../models/ruta.dart';
import '../services/api_service.dart';
import '../utils/estados.dart';
import '../utils/formato.dart';
import '../utils/seleccion.dart';
import '../utils/texto.dart';

class MapaScreen extends StatefulWidget {
  final SeleccionRuta seleccion;

  const MapaScreen({super.key, required this.seleccion});

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
  List<Alerta> _alertas = [];
  Timer? _timerBuses;
  Timer? _timerRutas;
  bool _cargando = true;
  bool _mostrarAlertas = true;

  /// Hay una consulta de buses en curso: si el servidor tarda más que el intervalo, no se apilan.
  bool _consultandoBuses = false;

  /// Se eligió una ruta pero aún no se ha podido encuadrar (sus datos no habían llegado).
  bool _encuadrePendiente = false;

  /// Último error de conexión; null cuando la última consulta salió bien.
  String? _errorConexion;
  DateTime? _ultimaActualizacion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.seleccion.addListener(_alCambiarSeleccion);
    _cargarDatos();
    _iniciarConsultas();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.seleccion.removeListener(_alCambiarSeleccion);
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
    _timerRutas = Timer.periodic(Config.intervaloRutas, (_) => _cargarRutasYAlertas());
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
      _cargarRutasYAlertas(),
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

  Future<void> _cargarRutasYAlertas() async {
    // El aviso de conexión lo da la consulta de buses, que corre cada pocos segundos
    try {
      final rutas = await _apiService.obtenerRutas();
      if (mounted) setState(() => _rutas = rutas);
      if (_encuadrePendiente) _programarEncuadre();
    } catch (e) {
      debugPrint('Error al cargar rutas: $e');
    }
    try {
      final alertas = await _apiService.obtenerAlertas();
      if (mounted) setState(() => _alertas = alertas);
    } catch (e) {
      debugPrint('Error al cargar alertas: $e');
    }
  }

  // ===== Ruta elegida =====

  Ruta? get _rutaElegida {
    final id = widget.seleccion.rutaId;
    if (id == null) return null;
    for (final ruta in _rutas) {
      if (ruta.id == id) return ruta;
    }
    return null;
  }

  void _alCambiarSeleccion() {
    if (!mounted) return;
    setState(() {});
    _encuadrePendiente = widget.seleccion.rutaId != null;
    _programarEncuadre();
  }

  void _programarEncuadre() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _encuadrar());
  }

  void _encuadrar() {
    final ruta = _rutaElegida;
    if (!mounted || ruta == null || !ruta.tieneRecorrido) return;
    _encuadrePendiente = false;
    _mapController.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(ruta.recorrido),
      // Arriba deja sitio a la ficha de la ruta elegida
      padding: const EdgeInsets.fromLTRB(40, 130, 40, 60),
    ));
  }

  void _abrirSelectorRuta() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SelectorRuta(
        rutas: _rutas,
        elegida: widget.seleccion.rutaId,
        onElegir: (rutaId) {
          Navigator.pop(context);
          widget.seleccion.elegir(rutaId);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ruta = _rutaElegida;
    final rutasVisibles = ruta != null ? [ruta] : _rutas;
    final busesVisibles = ruta != null ? _buses.where((b) => b.rutaId == ruta.id).toList() : _buses;
    final alertasVisibles = _mostrarAlertas
        ? _alertas
            .where((a) => a.estaVigente && a.tieneUbicacion && (ruta == null || a.rutaId == ruta.id))
            .toList()
        : <Alerta>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('🗺️ Mapa de Buses'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_mostrarAlertas ? Icons.notification_important : Icons.notifications_off_outlined),
            onPressed: () => setState(() => _mostrarAlertas = !_mostrarAlertas),
            tooltip: _mostrarAlertas ? 'Ocultar alertas del mapa' : 'Mostrar alertas en el mapa',
          ),
          IconButton(
            icon: const Icon(Icons.alt_route),
            onPressed: _rutas.isEmpty ? null : _abrirSelectorRuta,
            tooltip: 'Elegir ruta',
          ),
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

              // Rutas: todas finas, o la elegida más gruesa
              PolylineLayer(
                polylines: rutasVisibles
                    .where((r) => r.tieneRecorrido)
                    .map((r) => Polyline(
                          points: r.recorrido,
                          color: etiquetaRuta(r).color,
                          strokeWidth: ruta != null ? 6 : 3,
                          borderColor: Colors.white,
                          borderStrokeWidth: 1,
                        ))
                    .toList(),
              ),

              // Paradas: solo de la ruta elegida (todas juntas tapan el mapa)
              if (ruta != null)
                MarkerLayer(
                  markers: ruta.paradas
                      .map((parada) => Marker(
                            point: parada,
                            width: 18,
                            height: 18,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: etiquetaRuta(ruta).color, width: 3),
                              ),
                            ),
                          ))
                      .toList(),
                ),

              // Alertas en proceso con ubicación
              MarkerLayer(
                markers: alertasVisibles.map((alerta) {
                  final tipo = etiquetaTipoAlerta(alerta.tipo);
                  return Marker(
                    point: LatLng(alerta.latitud!, alerta.longitud!),
                    width: 36,
                    height: 36,
                    child: Semantics(
                      button: true,
                      label: 'Alerta: ${tipo.texto}. ${alerta.descripcion}',
                      child: GestureDetector(
                        onTap: () => _mostrarInfoAlerta(alerta),
                        child: Container(
                          decoration: BoxDecoration(
                            color: tipo.color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(tipo.icono, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Buses
              MarkerLayer(
                markers: busesVisibles.map((bus) {
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

          // Ruta elegida, o el contador de buses si se ven todas
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: ruta != null
                ? _fichaRutaElegida(ruta, busesVisibles.length)
                : Align(alignment: Alignment.topRight, child: _contadorBuses(busesVisibles.length)),
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

  Widget _contadorBuses(int cantidad) {
    return Container(
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
            cantidad == 1 ? '1 bus en vivo' : '$cantidad buses en vivo',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fichaRutaElegida(Ruta ruta, int buses) {
    final estado = etiquetaRuta(ruta);
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade800,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                ruta.codigo,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ruta.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${estado.texto}. ${buses == 1 ? '1 bus en vivo' : '$buses buses en vivo'}',
                    style: TextStyle(fontSize: 12, color: estado.color),
                  ),
                  if (!ruta.tieneRecorrido)
                    Text(
                      'Esta ruta no tiene recorrido trazado.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Ver todas las rutas',
              onPressed: () => widget.seleccion.elegir(null),
            ),
          ],
        ),
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

  void _mostrarInfoAlerta(Alerta alerta) {
    final tipo = etiquetaTipoAlerta(alerta.tipo);
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
                  Icon(tipo.icono, color: tipo.color, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    tipo.texto,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tipo.color),
                  ),
                  const Spacer(),
                  Text(haceCuanto(alerta.fechaVisible), style: TextStyle(color: Colors.grey.shade700)),
                ],
              ),
              const SizedBox(height: 12),
              Text(alerta.descripcion, style: const TextStyle(fontSize: 16)),
              const Divider(height: 30),
              _infoItem(Icons.route, 'Ruta', alerta.ruta),
              const SizedBox(height: 8),
              if (alerta.empresa.isNotEmpty) ...[
                _infoItem(Icons.business, 'Empresa', alerta.empresa),
                const SizedBox(height: 8),
              ],
              _infoItem(Icons.person, 'Reportó', alerta.usuario),
              if (alerta.vence != null) ...[
                const SizedBox(height: 8),
                _infoItem(Icons.timer_outlined, 'Vigencia', hastaCuando(alerta.vence!)),
              ],
              const SizedBox(height: 12),
              Text(
                'La ubicación es aproximada (unos 100 m).',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
        );
      },
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
              Row(
                children: [
                  if (bus.rutaId != null && widget.seleccion.rutaId != bus.rutaId) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.seleccion.elegir(bus.rutaId);
                        },
                        icon: const Icon(Icons.alt_route),
                        label: const Text('Ver su ruta'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _mapController.move(LatLng(bus.latitud, bus.longitud), 16);
                      },
                      icon: const Icon(Icons.center_focus_strong),
                      label: const Text('Centrar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(width: 12),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Expanded(child: Text(value)),
      ],
    );
  }
}

/// Hoja para elegir qué ruta ver en el mapa, con búsqueda.
class _SelectorRuta extends StatefulWidget {
  final List<Ruta> rutas;
  final int? elegida;
  final ValueChanged<int?> onElegir;

  const _SelectorRuta({required this.rutas, required this.elegida, required this.onElegir});

  @override
  State<_SelectorRuta> createState() => _SelectorRutaState();
}

class _SelectorRutaState extends State<_SelectorRuta> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final rutas = widget.rutas
        .where((r) => coincide(_busqueda, [r.codigo, r.nombre, r.empresa, r.origen, r.destino]))
        .toList();

    return Padding(
      // Sube con el teclado para que la búsqueda no quede tapada
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Buscar ruta',
                    hintText: 'Código, nombre, empresa o barrio',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (texto) => setState(() => _busqueda = texto),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: rutas.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return ListTile(
                        leading: const Icon(Icons.layers_outlined),
                        title: const Text('Todas las rutas'),
                        selected: widget.elegida == null,
                        onTap: () => widget.onElegir(null),
                      );
                    }
                    final ruta = rutas[i - 1];
                    final estado = etiquetaRuta(ruta);
                    return ListTile(
                      leading: SizedBox(
                        width: 64,
                        child: Text(
                          ruta.codigo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(ruta.nombre),
                      subtitle: Text(
                        ruta.tieneRecorrido ? '${ruta.empresa}\n${estado.texto}' : '${ruta.empresa}\nSin recorrido trazado',
                      ),
                      isThreeLine: true,
                      selected: ruta.id == widget.elegida,
                      onTap: () => widget.onElegir(ruta.id),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
