import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config.dart';
import '../models/alerta.dart';
import '../models/bus_ubicacion.dart';
import '../models/ruta.dart';
import '../services/api_service.dart';
import '../servidor.dart';
import '../tema.dart';
import '../utils/estados.dart';
import '../utils/formato.dart';
import '../utils/seleccion.dart';
import '../utils/texto.dart';
import '../widgets/comunes.dart';

class MapaScreen extends StatefulWidget {
  final SeleccionRuta seleccion;

  /// Lleva a Ajustes para corregir la dirección del servidor.
  final VoidCallback onAbrirAjustes;

  const MapaScreen({super.key, required this.seleccion, required this.onAbrirAjustes});

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
    Servidor.instancia.addListener(_alCambiarServidor);
    _cargarDatos();
    _iniciarConsultas();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.seleccion.removeListener(_alCambiarSeleccion);
    Servidor.instancia.removeListener(_alCambiarServidor);
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

  /// Otro servidor: lo de antes no vale (otras rutas, otros ids). Se empieza de cero.
  void _alCambiarServidor() {
    if (!mounted) return;
    setState(() {
      _buses = [];
      _rutas = [];
      _alertas = [];
      _errorConexion = null;
      _ultimaActualizacion = null;
      _cargando = true;
    });
    if (widget.seleccion.rutaId != null) widget.seleccion.elegir(null);
    _cargarDatos();
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
    final c = context.colores;
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final ruta = _rutaElegida;
    final rutasVisibles = ruta != null ? [ruta] : _rutas;
    final busesVisibles = ruta != null ? _buses.where((b) => b.rutaId == ruta.id).toList() : _buses;
    final alertasVisibles = _mostrarAlertas
        ? _alertas
            .where((a) => a.estaVigente && a.tieneUbicacion && (ruta == null || a.rutaId == ruta.id))
            .toList()
        : <Alerta>[];

    return Scaffold(
      appBar: barraSuperior(context, 'Mapa', acciones: [
        IconButton(
          icon: Icon(_mostrarAlertas ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
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
      ]),
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
                // En tema oscuro las teselas se invierten, como en la web
                tileBuilder: oscuro ? darkModeTileBuilder : null,
              ),

              // Rutas con el color de su placa; fuera de servicio, gris y punteada
              PolylineLayer(
                polylines: rutasVisibles.where((r) => r.tieneRecorrido).map((r) {
                  final pausada = r.estaFueraDeServicio;
                  return Polyline(
                    points: r.recorrido,
                    color: pausada ? c.grisTexto : colorDeRuta(r.id),
                    strokeWidth: ruta != null ? 6 : 3,
                    isDotted: pausada,
                    borderColor: c.fondo,
                    borderStrokeWidth: ruta != null ? 1.5 : 0,
                  );
                }).toList(),
              ),

              // Paradas: solo de la ruta elegida (todas juntas tapan el mapa)
              if (ruta != null)
                MarkerLayer(
                  markers: ruta.paradas
                      .map((parada) => Marker(
                            point: parada,
                            width: 16,
                            height: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: c.fondo,
                                shape: BoxShape.circle,
                                border: Border.all(color: colorDeRuta(ruta.id), width: 3),
                              ),
                            ),
                          ))
                      .toList(),
                ),

              // Alertas en proceso con ubicación (círculos: no se confunden con los buses, que son cuadrados)
              MarkerLayer(
                markers: alertasVisibles.map((alerta) {
                  final tipo = etiquetaTipoAlerta(alerta.tipo);
                  return Marker(
                    point: LatLng(alerta.latitud!, alerta.longitud!),
                    width: 44,
                    height: 44,
                    child: Semantics(
                      button: true,
                      label: 'Alerta: ${tipo.texto}. ${alerta.descripcion}',
                      child: GestureDetector(
                        onTap: () => _mostrarInfoAlerta(alerta),
                        child: Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c.de(tipo.tono),
                              shape: BoxShape.circle,
                              border: Border.all(color: c.fondo, width: 2),
                              boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6)],
                            ),
                            child: Icon(tipo.icono, color: c.sobre(tipo.tono), size: 18),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Buses: cuadro del color de su ruta
              MarkerLayer(
                markers: busesVisibles.map((bus) {
                  return Marker(
                    point: LatLng(bus.latitud, bus.longitud),
                    width: 48,
                    height: 48,
                    child: Semantics(
                      button: true,
                      label: 'Bus ${bus.placa}${bus.ruta != null ? ', ruta ${bus.ruta}' : ''}',
                      child: GestureDetector(
                        onTap: () => _mostrarInfoBus(bus),
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: colorDeRuta(bus.rutaId),
                              borderRadius: esquinaFicha,
                              border: Border.all(color: ColoresLocalBus.sobreColor, width: 2),
                              boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 8)],
                            ),
                            child: const Icon(Icons.directions_bus, color: ColoresLocalBus.sobreColor, size: 22),
                          ),
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
            child: AnimatedSwitcher(
              duration: duracionCorta,
              switchInCurve: curvaSuave,
              child: ruta != null
                  ? _fichaRutaElegida(ruta, busesVisibles.length)
                  : Align(
                      key: const ValueKey('contador'),
                      alignment: Alignment.topRight,
                      child: _contadorBuses(busesVisibles.length),
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

          // Carga inicial: se retira al llegar los primeros datos
          if (_cargando)
            Container(
              color: c.fondo.withValues(alpha: 0.75),
              child: const EstadoCargando('Cargando buses y rutas…'),
            ),
        ],
      ),
    );
  }

  /// Sombra solo en lo que flota sobre el mapa.
  BoxDecoration _flotante() {
    final c = context.colores;
    return BoxDecoration(
      color: c.fondo,
      border: Border.all(color: c.linea),
      borderRadius: esquinaFicha,
      boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 12, offset: Offset(0, 2))],
    );
  }

  Widget _contadorBuses(int cantidad) {
    final c = context.colores;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
        decoration: _flotante(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cantidad > 0)
              const PuntoEnVivo()
            else
              Padding(
                padding: const EdgeInsets.all(5),
                child: Icon(Icons.circle, size: 10, color: c.grisTexto),
              ),
            const SizedBox(width: 6),
            Text(
              cantidad == 0
                  ? 'Ningún bus en vivo'
                  : (cantidad == 1 ? '1 bus en vivo' : '$cantidad buses en vivo'),
              style: estiloTitulo(size: 18, weight: FontWeight.w600, color: c.tinta),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fichaRutaElegida(Ruta ruta, int buses) {
    final c = context.colores;
    final estado = etiquetaRuta(ruta);
    return Container(
      key: ValueKey('ruta-${ruta.id}'),
      decoration: _flotante(),
      child: ClipRRect(
        borderRadius: esquinaFicha,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: colorDeRuta(ruta.id)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                  child: Row(
                    children: [
                      PlacaRuta(codigo: ruta.codigo, rutaId: ruta.id, tamano: 16),
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
                              style: estiloTitulo(size: 18, color: c.tinta),
                            ),
                            Text(
                              ruta.tieneRecorrido
                                  ? '${estado.texto}. ${buses == 1 ? '1 bus en vivo' : '$buses buses en vivo'}'
                                  : 'Esta ruta no tiene recorrido trazado.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                // El amarillo no se lee como texto: la advertencia va en tinta
                                color: estado.tono == Tono.advertencia ? c.tinta : c.de(estado.tono),
                              ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avisoSinConexion() {
    final c = context.colores;
    final ultima = _ultimaActualizacion;
    final texto = c.sobre(Tono.peligro);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.rojoInterfaz, borderRadius: esquinaFicha),
        child: Row(
          children: [
            Icon(Icons.cloud_off, color: texto),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_errorConexion!, style: TextStyle(color: texto, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    ultima == null
                        ? 'Reintentando…'
                        : 'Reintentando… Las posiciones son de las ${horaConSegundos(ultima)}.',
                    style: TextStyle(color: texto, fontSize: 12),
                  ),
                  TextButton(
                    onPressed: widget.onAbrirAjustes,
                    style: TextButton.styleFrom(
                      foregroundColor: texto,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text('Cambiar servidor', style: TextStyle(decoration: TextDecoration.underline)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarInfoAlerta(Alerta alerta) {
    final tipo = etiquetaTipoAlerta(alerta.tipo);
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final c = context.colores;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Insignia(tipo, relleno: true),
                    const Spacer(),
                    Text(haceCuanto(alerta.fechaVisible), style: TextStyle(color: c.grisTexto)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(alerta.descripcion, style: TextStyle(fontSize: 17, color: c.tinta)),
                const SizedBox(height: 16),
                Divider(color: c.linea),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (alerta.rutaCodigo.isNotEmpty) ...[
                      PlacaRuta(codigo: alerta.rutaCodigo, rutaId: alerta.rutaId),
                      const SizedBox(width: 8),
                    ],
                    Expanded(child: Text(alerta.ruta, style: TextStyle(color: c.tinta))),
                  ],
                ),
                const SizedBox(height: 12),
                _dato('Empresa', alerta.empresa),
                _dato('Reportó', alerta.usuario),
                if (alerta.vence != null) _dato('Vigencia', hastaCuando(alerta.vence!)),
                const SizedBox(height: 4),
                Text(
                  'La ubicación es aproximada (unos 100 m).',
                  style: TextStyle(fontSize: 12, color: c.grisTexto),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarInfoBus(BusUbicacion bus) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final c = context.colores;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // La placa del bus, como la de un carro
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.amarillo,
                    border: Border.all(color: ColoresLocalBus.sobreAmarillo, width: 2),
                    borderRadius: esquinaPequena,
                  ),
                  child: Text(
                    bus.placa,
                    style: estiloTitulo(size: 26, color: ColoresLocalBus.sobreAmarillo),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (bus.rutaCodigo != null && bus.rutaCodigo!.isNotEmpty) ...[
                      PlacaRuta(codigo: bus.rutaCodigo!, rutaId: bus.rutaId),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(bus.ruta ?? 'Sin ruta asignada', style: TextStyle(color: c.tinta)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: c.linea),
                const SizedBox(height: 12),
                if (bus.conductor != null && bus.conductor!.isNotEmpty) _dato('Conductor', bus.conductor!),
                if (bus.empresa.isNotEmpty) _dato('Empresa', bus.empresa),
                _dato('Velocidad', '${bus.velocidad.toStringAsFixed(0)} km/h'),
                _dato('Última posición', '${horaConSegundos(bus.timestamp)} (${haceCuanto(bus.timestamp).toLowerCase()})'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (bus.rutaId != null && widget.seleccion.rutaId != bus.rutaId) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.seleccion.elegir(bus.rutaId);
                          },
                          icon: const Icon(Icons.alt_route, size: 18),
                          label: const Text('Ver su ruta'),
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
                        icon: const Icon(Icons.center_focus_strong, size: 18),
                        label: const Text('Centrar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Fila "Etiqueta   valor" de las fichas del mapa.
  Widget _dato(String etiqueta, String valor) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(etiqueta, style: TextStyle(color: c.grisTexto, fontSize: 14)),
          ),
          Expanded(child: Text(valor, style: TextStyle(color: c.tinta, fontSize: 14))),
        ],
      ),
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
    final c = context.colores;
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Elegir ruta', style: estiloTitulo(size: 24, color: c.tinta)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: TextField(
                  textInputAction: TextInputAction.search,
                  decoration: decoracionCampo(
                    context,
                    etiqueta: 'Buscar ruta',
                    ayuda: 'Código, nombre, empresa o barrio',
                    prefijo: const Icon(Icons.search),
                  ),
                  onChanged: (texto) => setState(() => _busqueda = texto),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: rutas.length + 1,
                  separatorBuilder: (context, i) => Divider(color: c.linea, indent: 20, endIndent: 20),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return _fila(
                        elegida: widget.elegida == null,
                        inicio: Icon(Icons.layers_outlined, color: c.tinta),
                        titulo: 'Todas las rutas',
                        detalle: '${widget.rutas.length} rutas',
                        alTocar: () => widget.onElegir(null),
                      );
                    }
                    final ruta = rutas[i - 1];
                    return _fila(
                      elegida: ruta.id == widget.elegida,
                      color: colorDeRuta(ruta.id),
                      inicio: PlacaRuta(codigo: ruta.codigo, rutaId: ruta.id),
                      titulo: ruta.nombre,
                      detalle: ruta.tieneRecorrido
                          ? '${ruta.empresa}\n${etiquetaRuta(ruta).texto}'
                          : '${ruta.empresa}\nSin recorrido trazado',
                      alTocar: () => widget.onElegir(ruta.id),
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

  /// Fila de la lista; la elegida lleva fondo concreto y borde izquierdo de color.
  Widget _fila({
    required bool elegida,
    required Widget inicio,
    required String titulo,
    required String detalle,
    required VoidCallback alTocar,
    Color? color,
  }) {
    final c = context.colores;
    return Semantics(
      selected: elegida,
      button: true,
      child: InkWell(
        onTap: alTocar,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: elegida ? c.concreto : null,
            border: Border(
              left: BorderSide(color: elegida ? (color ?? c.azul) : Colors.transparent, width: 4),
            ),
          ),
          child: Row(
            children: [
              SizedBox(width: 72, child: Align(alignment: Alignment.centerLeft, child: inicio)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: TextStyle(color: c.tinta, fontWeight: FontWeight.w700)),
                    Text(detalle, style: TextStyle(color: c.grisTexto, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
