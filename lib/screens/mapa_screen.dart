import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../models/bus_ubicacion.dart';
import '../models/ruta.dart';
import '../services/api.dart';
import '../services/navegacion.dart';
import '../services/notificaciones.dart';
import '../services/server_config.dart';
import '../services/sesion.dart';
import '../services/ubicacion.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/lb.dart';

/// Mapa en vivo con la lista de rutas: la página de inicio de la web en celular (home.html + home.js).
/// El mapa empieza vacío; al tocar una ruta se dibuja solo esa y se ven solo sus buses.
class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

const _radioCercanas = 1000.0; // "Cercanas a mí": rutas que pasan a 1 km o menos
const _medellin = LatLng(6.2442, -75.5812);

class _BusAnimado {
  _BusAnimado(this.desde, this.hasta, this.inicio);
  LatLng desde;
  LatLng hasta;
  Duration inicio;
}

class _MapaScreenState extends State<MapaScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final MapController _mapa = MapController();
  final TextEditingController _buscar = TextEditingController();
  late final Ticker _ticker = createTicker(_alAvanzar);
  Duration _ahora = Duration.zero;

  // Datos
  List<Ruta> _rutas = [];
  List<AvisoMapa> _avisos = [];
  int _totalActivas = 0;
  bool _cargando = true;
  String? _errorCarga;
  bool _mapaListo = false;

  // Lista y filtros
  int? _seleccionada;
  String _busqueda = '';
  String _filtro = 'all';
  Map<int, double>? _distancias;
  String _filtroMensaje = '';
  bool _buscandoUbicacion = false;
  bool _plegado = false;
  bool _ubicando = false;

  // Buses en vivo
  Timer? _timerBuses;
  List<BusUbicacion> _ultimosBuses = [];
  final Map<int, _BusAnimado> _posiciones = {};
  bool _buscandoBuses = false;
  bool _sinConexion = false;
  int? _msPuntos;

  // Tu ubicación y ventanas sobre el mapa
  LatLng? _yo;
  bool _circulo = false;
  ({LatLng punto, String tipo, int? busId})? _globo;
  Map<String, dynamic>? _llegada;
  bool _llegadaReintentando = false;
  Timer? _timerLlegada;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargar();
    _timerBuses = Timer.periodic(const Duration(seconds: 5), (_) => _consultarBuses());
    ServerConfig.cambios.addListener(_alCambiarServidor);
    Sesion.i.addListener(_alCambiarSesion);
    Ubicacion.silenciosa().then((p) => _yo ??= p);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ServerConfig.cambios.removeListener(_alCambiarServidor);
    Sesion.i.removeListener(_alCambiarSesion);
    _timerBuses?.cancel();
    _timerLlegada?.cancel();
    _ticker.dispose();
    _buscar.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _cargar(silencioso: true);
  }

  void _alCambiarSesion() => setState(() {});

  void _alCambiarServidor() {
    setState(() {
      _cargando = true;
      _seleccionada = null;
      _ultimosBuses = [];
      _posiciones.clear();
      _globo = null;
    });
    _cargar();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _errorCarga = null);
    try {
      final d = await Api.get('mapa/');
      if (!mounted) return;
      setState(() {
        _rutas = (d['rutas'] as List? ?? []).map((r) => Ruta.fromJson(r as Map<String, dynamic>)).toList();
        _avisos = (d['avisos'] as List? ?? []).map((a) => AvisoMapa.fromJson(a as Map<String, dynamic>)).toList();
        _totalActivas = (d['total_activas'] as num?)?.toInt() ?? 0;
        _cargando = false;
        _errorCarga = null;
        if (_seleccionada != null && !_rutas.any((r) => r.id == _seleccionada)) _seleccionada = null;
      });
    } on ApiError catch (e) {
      if (!mounted || silencioso) return;
      setState(() {
        _cargando = false;
        _errorCarga = e.mensaje;
      });
    }
  }

  Ruta? get _ruta => _seleccionada == null ? null : _rutas.where((r) => r.id == _seleccionada).firstOrNull;

  // ================= RUTA ELEGIDA =================

  void _seleccionar(int id) {
    setState(() {
      _seleccionada = _seleccionada == id ? null : id;
      _buscandoBuses = _seleccionada != null;
      _globo = null;
      _posiciones.removeWhere((_, _) => true);
    });
    _cerrarLlegada();
    final ruta = _ruta;
    if (ruta != null && ruta.coordenadas.isNotEmpty) {
      final puntos = ruta.coordenadas.map((c) => LatLng(c[1], c[0])).toList();
      if (puntos.length == 1) {
        _mapa.move(puntos.first, 15);
      } else {
        _mapa.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(puntos), padding: const EdgeInsets.all(40)));
      }
    }
    _actualizarBuses(_ultimosBuses);
    if (_seleccionada != null) _consultarBuses();
  }

  String get _avisoMapa {
    final ruta = _ruta;
    if (_rutas.isEmpty) return _cargando ? 'Cargando las rutas…' : 'No hay rutas registradas.';
    if (ruta == null) return 'Elige una ruta para ver su recorrido y sus buses.';
    final nombre = ruta.codigo.isNotEmpty ? ruta.codigo : ruta.nombre;
    if (_sinConexion) return '$nombre: sin conexión, reintentando…';
    if (_buscandoBuses) return '$nombre: buscando buses…';
    final n = _posiciones.length;
    final sinTrazado = ruta.coordenadas.isEmpty ? 'sin recorrido trazado. ' : '';
    return '$nombre: $sinTrazado${n == 0 ? 'sin buses en vivo' : n == 1 ? '1 bus en vivo' : '$n buses en vivo'}';
  }

  // ================= BUSES EN VIVO =================

  Future<void> _consultarBuses() async {
    if (_seleccionada == null) return; // sin ruta elegida no se muestra ningún bus
    final reloj = Stopwatch()..start();
    try {
      final d = await Api.get('/api/ubicaciones/');
      if (!mounted) return;
      final buses = (d['buses'] as List? ?? []).map((b) => BusUbicacion.fromJson(b as Map<String, dynamic>)).toList();
      setState(() {
        _msPuntos = reloj.elapsedMilliseconds;
        _buscandoBuses = false;
        _sinConexion = false;
      });
      _actualizarBuses(buses);
    } on ApiError {
      if (mounted) setState(() => _sinConexion = true);
    }
  }

  void _actualizarBuses(List<BusUbicacion> todos) {
    _ultimosBuses = todos;
    final visibles = todos.where((b) => _seleccionada != null && b.rutaId == _seleccionada).toList();
    final reducido = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    setState(() {
      for (final bus in visibles) {
        final destino = LatLng(bus.latitud, bus.longitud);
        final previo = _posiciones[bus.busId];
        if (previo == null || reducido) {
          _posiciones[bus.busId] = _BusAnimado(destino, destino, _ahora);
        } else {
          // Se desliza hasta su nuevo punto en vez de saltar
          _posiciones[bus.busId] = _BusAnimado(_posicionDe(bus.busId), destino, _ahora);
        }
      }
      _posiciones.removeWhere((id, _) => !visibles.any((b) => b.busId == id));
      if (_globo?.tipo == 'bus' && !_posiciones.containsKey(_globo!.busId)) {
        _globo = null;
        _cerrarLlegada();
      }
    });
    if (!_ticker.isActive && _posiciones.isNotEmpty) _ticker.start();
  }

  void _alAvanzar(Duration t) {
    _ahora = t;
    final moviendo = _posiciones.values.any((p) => t - p.inicio < const Duration(milliseconds: 4500));
    if (moviendo) {
      setState(() {});
    } else if (_posiciones.isEmpty) {
      _ticker.stop();
      _ahora = Duration.zero;
    }
  }

  LatLng _posicionDe(int busId) {
    final p = _posiciones[busId];
    if (p == null) return _medellin;
    final f = ((_ahora - p.inicio).inMilliseconds / 4500).clamp(0.0, 1.0);
    return LatLng(p.desde.latitude + (p.hasta.latitude - p.desde.latitude) * f,
        p.desde.longitude + (p.hasta.longitude - p.desde.longitude) * f);
  }

  void _abrirBus(int busId) {
    setState(() {
      _globo = (punto: _posicionDe(busId), tipo: 'bus', busId: busId);
      _llegada = null;
      _llegadaReintentando = false;
    });
    _timerLlegada?.cancel();
    _consultarLlegada(busId);
    _timerLlegada = Timer.periodic(const Duration(seconds: 5), (_) => _consultarLlegada(busId));
  }

  void _cerrarLlegada() {
    _timerLlegada?.cancel();
    _timerLlegada = null;
  }

  Future<void> _consultarLlegada(int busId) async {
    final yo = _yo ?? Ubicacion.ultima;
    try {
      final d = await Api.get('/api/tiempo-llegada-usuario/$busId/',
          q: yo == null ? null : {'lat': '${yo.latitude}', 'lng': '${yo.longitude}'});
      if (!mounted || _globo?.busId != busId) return;
      setState(() {
        _llegada = d;
        _llegadaReintentando = false;
      });
    } on ApiError catch (e) {
      if (!mounted || _globo?.busId != busId) return;
      setState(() {
        _llegada = e.sinConexion ? null : e.datos;
        _llegadaReintentando = e.sinConexion;
      });
    }
  }

  // ================= TU UBICACIÓN Y CERCANAS =================

  Future<void> _miUbicacion() async {
    setState(() => _ubicando = true);
    try {
      final yo = await Ubicacion.obtener();
      if (!mounted) return;
      setState(() {
        _yo = yo;
        _globo = (punto: yo, tipo: 'yo', busId: null);
      });
      _mapa.move(yo, 15);
    } on UbicacionError catch (e) {
      if (mounted) _avisar(e.mensaje);
    } finally {
      if (mounted) setState(() => _ubicando = false);
    }
  }

  void _avisar(String texto) {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(texto, style: const TextStyle(fontSize: 15.5, height: 1.4)),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Aceptar'))],
      ),
    );
  }

  Future<void> _activarCercanas() async {
    setState(() {
      _buscandoUbicacion = true;
      _filtroMensaje = 'Obteniendo tu ubicación…';
    });
    try {
      final yo = await Ubicacion.obtener();
      final distancias = <int, double>{
        for (final r in _rutas)
          if (r.coordenadas.isNotEmpty) r.id: Ubicacion.distanciaARuta(yo, r.coordenadas),
      };
      final cuantas = distancias.values.where((d) => d <= _radioCercanas).length;
      if (!mounted) return;
      setState(() {
        _yo = yo;
        _distancias = distancias;
        _filtro = 'cercanas';
        _circulo = true;
        _filtroMensaje = cuantas > 0
            ? '${cuantas == 1 ? '1 ruta pasa' : '$cuantas rutas pasan'} a 1 km o menos de ti.'
            : 'Ninguna ruta pasa a 1 km o menos de tu ubicación.';
      });
      if (_seleccionada == null) {
        final d = const Distance();
        _mapa.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds(d.offset(yo, _radioCercanas * 1.42, 315), d.offset(yo, _radioCercanas * 1.42, 135)),
          padding: const EdgeInsets.all(10),
        ));
      }
    } on UbicacionError catch (e) {
      if (!mounted) return;
      setState(() {
        _quitarCercanas();
        _filtroMensaje = e.mensaje;
      });
    } finally {
      if (mounted) setState(() => _buscandoUbicacion = false);
    }
  }

  void _quitarCercanas() {
    _filtro = 'all';
    _distancias = null;
    _circulo = false;
    _filtroMensaje = '';
  }

  List<Ruta> get _visibles {
    final t = _busqueda.toLowerCase();
    final lista = _rutas.where((r) {
      final coincide = t.isEmpty ||
          r.nombre.toLowerCase().contains(t) ||
          r.codigo.toLowerCase().contains(t) ||
          r.origen.toLowerCase().contains(t) ||
          r.destino.toLowerCase().contains(t);
      final d = _distancias?[r.id];
      final filtro = _filtro == 'all' || (d != null && d <= _radioCercanas);
      return coincide && filtro;
    }).toList();
    if (_filtro == 'cercanas' && _distancias != null) {
      lista.sort((a, b) => (_distancias![a.id] ?? double.infinity).compareTo(_distancias![b.id] ?? double.infinity));
    }
    return lista;
  }

  // ================= PANTALLA =================

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    final alto = MediaQuery.of(context).size.height;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(child: _zonaMapa(context)),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: alto * (alto < 700 ? 0.6 : 0.5)),
              child: Container(
                decoration: BoxDecoration(
                  color: lb.blanco,
                  border: Border(top: BorderSide(color: lb.tinta, width: 2)),
                ),
                child: _panel(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _zonaMapa(BuildContext context) {
    final lb = context.lb;
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final ruta = _ruta;

    Widget mosaicos = TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.example.monitor_app',
      maxZoom: 19,
    );
    // El mapa base se atenúa para que solo la ruta elegida tenga color (como la web)
    mosaicos = ColorFiltered(colorFilter: oscuro ? _filtroOscuro : _filtroGris, child: mosaicos);

    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: lb.mapaFondo,
            child: FlutterMap(
              mapController: _mapa,
              options: MapOptions(
                initialCenter: _medellin,
                initialZoom: 13,
                minZoom: 10,
                maxZoom: 19,
                backgroundColor: lb.mapaFondo,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                onMapReady: () => Future.delayed(const Duration(milliseconds: 900), () {
                  if (mounted) setState(() => _mapaListo = true);
                }),
                onTap: (_, _) {
                  if (_globo != null) {
                    setState(() => _globo = null);
                    _cerrarLlegada();
                  }
                },
              ),
              children: [
                mosaicos,
                if (_circulo && _yo != null)
                  CircleLayer(circles: [
                    CircleMarker(
                      point: _yo!,
                      radius: _radioCercanas,
                      useRadiusInMeter: true,
                      color: const Color(0xFF014CAB).withValues(alpha: 0.08),
                      borderColor: const Color(0xFF014CAB),
                      borderStrokeWidth: 1,
                    ),
                  ]),
                if (ruta != null && ruta.coordenadas.length > 1)
                  PolylineLayer(polylines: [
                    // Borde blanco bajo la línea de color, como en un plano de transporte
                    Polyline(
                      points: ruta.coordenadas.map((c) => LatLng(c[1], c[0])).toList(),
                      color: Colors.white,
                      strokeWidth: 10,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                    Polyline(
                      points: ruta.coordenadas.map((c) => LatLng(c[1], c[0])).toList(),
                      color: ruta.color,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ]),
                if (ruta != null) MarkerLayer(markers: _marcadoresRuta(ruta)),
                if (_yo != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: _yo!,
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => setState(() => _globo = (punto: _yo!, tipo: 'yo', busId: null)),
                        child: const _PuntoUbicacion(),
                      ),
                    ),
                  ]),
                MarkerLayer(markers: [
                  for (final id in _posiciones.keys)
                    Marker(
                      point: _posicionDe(id),
                      width: 52,
                      height: 36,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () => _abrirBus(id),
                        child: _ChapaBus(codigo: ruta?.codigo ?? '', color: ruta?.color ?? lb.placaNeutra),
                      ),
                    ),
                ]),
                if (_globo != null) MarkerLayer(markers: [_marcadorGlobo(context)]),
              ],
            ),
          ),
        ),

        // Mientras llegan los mosaicos del mapa
        Positioned.fill(
          child: IgnorePointer(
            ignoring: _mapaListo,
            child: AnimatedOpacity(
              opacity: _mapaListo ? 0 : 1,
              duration: const Duration(milliseconds: 500),
              child: ColoredBox(
                color: lb.mapaFondo,
                child: const Center(child: CargandoTexto('Cargando el mapa…')),
              ),
            ),
          ),
        ),

        // Tablero de avisos: en el celular va arriba
        Positioned(top: 0, left: 0, right: 0, child: _TableroAvisos(avisos: _avisos)),

        // Aparece si falla la consulta de los buses
        if (_sinConexion)
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(child: _PildoraConexion()),
          ),
      ],
    );
  }

  List<Marker> _marcadoresRuta(Ruta ruta) {
    if (ruta.coordenadas.isEmpty) return [];
    final origen = LatLng(ruta.coordenadas.first[1], ruta.coordenadas.first[0]);
    final destino = LatLng(ruta.coordenadas.last[1], ruta.coordenadas.last[0]);
    return [
      for (final p in ruta.paradas)
        Marker(
          point: LatLng(p.lat, p.lng),
          width: 22,
          height: 22,
          child: GestureDetector(
            onTap: () => setState(() => _globo = (punto: LatLng(p.lat, p.lng), tipo: 'parada', busId: null)),
            child: Center(
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: ruta.color, width: 3),
                ),
              ),
            ),
          ),
        ),
      for (final (punto, tipo) in [(origen, 'origen'), (destino, 'destino')])
        Marker(
          point: punto,
          width: 26,
          height: 26,
          child: GestureDetector(
            onTap: () => setState(() => _globo = (punto: punto, tipo: tipo, busId: null)),
            child: Center(child: _PuntoRuta(color: ruta.color, destino: tipo == 'destino')),
          ),
        ),
    ];
  }

  Marker _marcadorGlobo(BuildContext context) {
    final g = _globo!;
    final ruta = _ruta;
    final esBus = g.tipo == 'bus';
    final punto = esBus ? _posicionDe(g.busId!) : g.punto;
    Widget contenido;
    double alto;
    switch (g.tipo) {
      case 'bus':
        final bus = _ultimosBuses.where((b) => b.busId == g.busId).firstOrNull;
        contenido = _FichaBus(
          placa: bus?.placa ?? '',
          codigo: ruta?.codigo ?? '',
          color: ruta?.color ?? context.lb.placaNeutra,
          ruta: bus?.ruta ?? 'Sin ruta',
          velocidad: bus?.velocidad ?? 0,
          llegada: _llegada,
          reintentando: _llegadaReintentando,
          onCerrar: () {
            setState(() => _globo = null);
            _cerrarLlegada();
          },
        );
        alto = 250;
      case 'origen':
        contenido = _GloboTexto(titulo: 'Origen', texto: ruta?.origen ?? '');
        alto = 140;
      case 'destino':
        contenido = _GloboTexto(titulo: 'Destino', texto: ruta?.destino ?? '');
        alto = 140;
      case 'parada':
        contenido = const _GloboTexto(titulo: '', texto: 'Parada', pequeno: true);
        alto = 90;
      default:
        contenido = const _GloboTexto(titulo: 'Tu ubicación', texto: '');
        alto = 90;
    }
    return Marker(
      point: punto,
      width: 252,
      height: alto,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: esBus ? 38 : 14),
        child: Align(alignment: Alignment.bottomCenter, child: contenido),
      ),
    );
  }

  // ================= HOJA DE RUTAS =================

  Widget _panel(BuildContext context) {
    final lb = context.lb;
    final total = _rutas.length;
    final visibles = _visibles;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cabecera
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Rutas', style: AppTheme.titulo(size: 27, color: lb.tinta, height: 1)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _cargando ? '' : '$_totalActivas activa${_totalActivas == 1 ? '' : 's'} de $total',
                  style: TextStyle(fontSize: 14.4, color: lb.grisTexto),
                ),
              ),
              SizedBox(
                width: 36,
                height: 36,
                child: OutlinedButton(
                  onPressed: () => setState(() => _plegado = !_plegado),
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(36, 36)),
                  child: Text(_plegado ? '+' : '−',
                      semanticsLabel: 'Mostrar u ocultar la lista de rutas',
                      style: TextStyle(fontSize: 19, height: 1, color: lb.tinta)),
                ),
              ),
            ],
          ),
        ),

        // Acciones
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              Expanded(child: LbAccion(_ubicando ? 'Buscando…' : 'Mi ubicación', esperando: _ubicando, onPressed: _miUbicacion)),
              const SizedBox(width: 8),
              Expanded(
                child: Sesion.i.activa
                    ? LbAccion('Reportar', onPressed: () => Navegacion.reportar(_seleccionada))
                    : LbAccion('Inicia sesión para reportar', onPressed: () => Navegacion.ir(Navegacion.cuenta)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: Notificaciones.i.permiso,
                  builder: (context, permiso, _) => LbAccion(
                    switch (permiso) {
                      'granted' => 'Notificaciones activadas',
                      'denied' => 'Notificaciones bloqueadas',
                      _ => 'Activar notificaciones',
                    },
                    estado: switch (permiso) {
                      'granted' => EstadoAccion.activado,
                      'denied' => EstadoAccion.bloqueado,
                      _ => EstadoAccion.normal,
                    },
                    onPressed: permiso == 'granted'
                        ? null
                        : permiso == 'denied'
                            ? () => _avisar('Permite las notificaciones de LocalBus en los ajustes de tu celular.')
                            : Notificaciones.i.activar,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Búsqueda, filtros y lista (se pliegan)
        Flexible(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: curvaSuave,
            alignment: Alignment.topCenter,
            child: _plegado ? const SizedBox(width: double.infinity) : _cuerpoPanel(context, visibles),
          ),
        ),
      ],
    );
  }

  Widget _cuerpoPanel(BuildContext context, List<Ruta> visibles) {
    final lb = context.lb;
    final ruta = _ruta;
    final enVivo = ruta != null && !_buscandoBuses && !_sinConexion && _posiciones.isNotEmpty;
    final buscando = ruta != null && (_buscandoBuses || _sinConexion);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _buscar,
            onChanged: (v) => setState(() => _busqueda = v),
            textInputAction: TextInputAction.search,
            style: TextStyle(fontSize: 16, color: lb.tinta),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, origen o destino',
              hintStyle: TextStyle(color: lb.grisTexto),
              suffixIcon: _busqueda.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Borrar búsqueda',
                      onPressed: () => setState(() {
                        _buscar.clear();
                        _busqueda = '';
                      }),
                      icon: Text('✕', style: TextStyle(color: lb.grisTexto, fontSize: 15)),
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: LbPestanas<String>(
            separacion: 20,
            elegida: _filtro,
            pestanas: [
              const PestanaLb('all', 'Todas'),
              PestanaLb('cercanas', 'Cercanas a mí', esperando: _buscandoUbicacion),
            ],
            onElegir: (v) {
              if (v == 'cercanas') {
                _activarCercanas();
              } else {
                setState(_quitarCercanas);
              }
            },
          ),
        ),
        if (_filtroMensaje.isNotEmpty)
          _Franja(
            texto: _filtroMensaje,
            fondo: lb.blanco,
            color: lb.grisTexto,
            prefijo: _buscandoUbicacion ? Aro(size: 12, color: lb.grisTexto) : null,
          ),
        _Franja(
          texto: _avisoMapa,
          fondo: lb.concreto,
          color: lb.tinta,
          borde: true,
          prefijo: buscando ? Aro(size: 12, color: lb.tinta) : enVivo ? const EnVivoDot(size: 9) : null,
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: lb.linea))),
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Puntos de la ruta: '),
              TextSpan(text: _msPuntos == null ? '—' : '$_msPuntos', style: const TextStyle(fontWeight: FontWeight.w700)),
              const TextSpan(text: ' ms'),
            ]),
            style: TextStyle(fontSize: 13.6, color: lb.tinta, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
        Flexible(child: _lista(context, visibles)),
      ],
    );
  }

  Widget _lista(BuildContext context, List<Ruta> visibles) {
    final lb = context.lb;
    if (_cargando) {
      return const Padding(padding: EdgeInsets.all(24), child: CargandoTexto('Cargando las rutas…'));
    }
    if (_errorCarga != null) {
      return SingleChildScrollView(
        child: StateMessage(
          icon: Icons.wifi_off_rounded,
          title: 'No pudimos cargar las rutas',
          message: '$_errorCarga\n\nServidor: ${ServerConfig.url}. Mantén presionado el título de cualquier otra '
              'pantalla para cambiarlo.',
          actionLabel: 'Reintentar',
          onAction: _cargar,
        ),
      );
    }
    if (_rutas.isEmpty) {
      return _SinResultados('No hay rutas disponibles', 'Por ahora ninguna empresa tiene rutas habilitadas.');
    }
    if (visibles.isEmpty) {
      if (_filtro == 'cercanas' && _busqueda.isEmpty) return const SizedBox(height: 8);
      return _SinResultados('No encontramos rutas', 'Prueba con otro nombre, código, origen o destino.');
    }
    return ListView.builder(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 8),
      shrinkWrap: true,
      itemCount: visibles.length,
      itemBuilder: (context, i) {
        final r = visibles[i];
        return _TarjetaRuta(
          ruta: r,
          elegida: r.id == _seleccionada,
          distancia: _filtro == 'cercanas' ? (_distancias?[r.id]) : null,
          onTap: () => _seleccionar(r.id),
          linea: lb.linea,
        );
      },
    );
  }
}

// ================= FILTROS DE COLOR DEL MAPA =================

/// grayscale(0.9) brightness(1.06): el mapa base casi gris, como en la web.
const ColorFilter _filtroGris = ColorFilter.matrix(<double>[
  0.309, 0.682, 0.069, 0, 6, //
  0.203, 0.788, 0.069, 0, 6, //
  0.203, 0.682, 0.175, 0, 6, //
  0, 0, 0, 1, 0,
]);

/// Tema oscuro: los mosaicos se invierten y se apagan.
const ColorFilter _filtroOscuro = ColorFilter.matrix(<double>[
  -0.28, -0.6, -0.06, 0, 205, //
  -0.24, -0.64, -0.06, 0, 205, //
  -0.24, -0.6, -0.1, 0, 210, //
  0, 0, 0, 1, 0,
]);

// ================= PIEZAS DEL MAPA =================

class _Franja extends StatelessWidget {
  const _Franja({required this.texto, required this.fondo, required this.color, this.prefijo, this.borde = false});

  final String texto;
  final Color fondo;
  final Color color;
  final Widget? prefijo;
  final bool borde;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Container(
          key: ValueKey(texto),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: fondo,
            border: borde ? Border(bottom: BorderSide(color: context.lb.linea)) : null,
          ),
          child: Row(
            children: [
              if (prefijo != null) ...[prefijo!, const SizedBox(width: 9)],
              Expanded(child: Text(texto, style: TextStyle(fontSize: 13.6, height: 1.35, color: color))),
            ],
          ),
        ),
      ),
    );
  }
}

class _SinResultados extends StatelessWidget {
  const _SinResultados(this.titulo, this.texto);
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(titulo, style: TextStyle(fontWeight: FontWeight.w700, color: lb.tinta)),
          const SizedBox(height: 4),
          Text(texto, style: TextStyle(fontSize: 13.6, color: lb.grisTexto)),
        ],
      ),
    );
  }
}

/// Tarjeta de una ruta en la lista (.route-card).
class _TarjetaRuta extends StatelessWidget {
  const _TarjetaRuta({required this.ruta, required this.elegida, required this.onTap, required this.linea, this.distancia});

  final Ruta ruta;
  final bool elegida;
  final VoidCallback onTap;
  final Color linea;
  final double? distancia;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    final datos = TextStyle(fontSize: 13.6, color: lb.grisTexto, fontFeatures: const [FontFeature.tabularFigures()]);
    return Semantics(
      button: true,
      selected: elegida,
      child: Material(
        color: elegida ? lb.concreto : lb.blanco,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: curvaSuave,
            padding: const EdgeInsets.fromLTRB(16, 14, 20, 14),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: elegida ? ruta.color : Colors.transparent, width: 5),
                bottom: BorderSide(color: linea),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: const BoxConstraints(minWidth: 51),
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 5),
                  decoration: BoxDecoration(color: ruta.color, borderRadius: BorderRadius.circular(AppTheme.radio)),
                  child: Text(ruta.codigo,
                      textAlign: TextAlign.center,
                      style: AppTheme.titulo(size: 20.8, color: lb.sobreColor, height: 1).copyWith(letterSpacing: 0.4)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (ruta.empresa.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(ruta.empresa,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: lb.grisTexto)),
                        ),
                      TrayectoRuta(origen: ruta.origen, destino: ruta.destino, color: ruta.color),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 16,
                        runSpacing: 3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('${_numero(ruta.distanciaKm)} km', style: datos),
                          Text('${ruta.duracionMinutos} min', style: datos),
                          Text('cada ${ruta.frecuenciaMinutos} min', style: datos),
                          if (!ruta.activa) InsigniaRuta(estado: ruta.estado, texto: ruta.estadoNombre),
                        ],
                      ),
                      if (ruta.motivo.isNotEmpty) MotivoRuta(estado: ruta.estado, texto: ruta.motivo),
                      if (distancia != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('Pasa ${_textoDistancia(distancia!)}',
                              style: TextStyle(fontSize: 13.6, fontWeight: FontWeight.w700, color: lb.tinta)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _numero(double v) => v == v.roundToDouble() ? v.toStringAsFixed(1) : '$v';
  static String _textoDistancia(double m) => m < 100 ? 'a menos de 100 m' : 'a ${(m / 10).round() * 10} m';
}

/// Chapa del bus (.bus-chapa): código de la ruta sobre su color, con un pico abajo.
class _ChapaBus extends StatelessWidget {
  const _ChapaBus({required this.codigo, required this.color});

  final String codigo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final blanco = context.lb.blanco;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: blanco, width: 2),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 4, offset: Offset(0, 1))],
          ),
          child: Text(codigo, style: AppTheme.titulo(size: 15, color: Colors.white, height: 1)),
        ),
        CustomPaint(size: const Size(12, 6), painter: _Pico(blanco)),
      ],
    );
  }
}

class _Pico extends CustomPainter {
  _Pico(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Pico old) => old.color != color;
}

/// Origen (hueco) y destino (lleno) de la ruta (.punto-ruta).
class _PuntoRuta extends StatelessWidget {
  const _PuntoRuta({required this.color, required this.destino});
  final Color color;
  final bool destino;

  @override
  Widget build(BuildContext context) {
    final blanco = context.lb.blanco;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: destino ? color : blanco,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 4),
        boxShadow: [
          BoxShadow(color: blanco, spreadRadius: 2),
          const BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
    );
  }
}

/// Tu ubicación: punto azul con una onda lenta y tenue (.punto-ubicacion).
class _PuntoUbicacion extends StatefulWidget {
  const _PuntoUbicacion();

  @override
  State<_PuntoUbicacion> createState() => _PuntoUbicacionState();
}

class _PuntoUbicacionState extends State<_PuntoUbicacion> with SingleTickerProviderStateMixin {
  late final AnimationController _onda =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _onda.stop();
    } else if (!_onda.isAnimating) {
      _onda.repeat();
    }
  }

  @override
  void dispose() {
    _onda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return AnimatedBuilder(
      animation: _onda,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_onda.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 22 * (0.8 + 1.8 * t),
              height: 22 * (0.8 + 1.8 * t),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: lb.azul.withValues(alpha: 0.45 * (1 - t)), width: 2),
              ),
            ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: lb.azul,
                shape: BoxShape.circle,
                border: Border.all(color: lb.blanco, width: 3),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF014CAB).withValues(alpha: 0.2), spreadRadius: 6),
                  const BoxShadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Ventanita sobre el mapa (popup de Leaflet) para el origen, el destino, una parada o tu ubicación.
class _GloboTexto extends StatelessWidget {
  const _GloboTexto({required this.titulo, required this.texto, this.pequeno = false});
  final String titulo;
  final String texto;
  final bool pequeno;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return _Globo(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (titulo.isNotEmpty) Text(titulo, style: TextStyle(fontWeight: FontWeight.w700, color: lb.tinta)),
            if (texto.isNotEmpty)
              Text(texto,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: pequeno ? 12.5 : 14, color: lb.tinta, height: 1.35)),
          ],
        ),
      ),
    );
  }
}

class _Globo extends StatelessWidget {
  const _Globo({required this.child, this.ancho});
  final Widget child;
  final double? ancho;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: ancho,
          constraints: const BoxConstraints(maxWidth: 252),
          decoration: BoxDecoration(
            color: lb.blanco,
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 10, offset: Offset(0, 2))],
          ),
          child: child,
        ),
        CustomPaint(size: const Size(18, 9), painter: _Pico(lb.blanco)),
      ],
    );
  }
}

/// Ventana de un bus (.bus-ficha): placa, ruta, llegada estimada y velocidad.
class _FichaBus extends StatelessWidget {
  const _FichaBus({
    required this.placa,
    required this.codigo,
    required this.color,
    required this.ruta,
    required this.velocidad,
    required this.llegada,
    required this.reintentando,
    required this.onCerrar,
  });

  final String placa;
  final String codigo;
  final Color color;
  final String ruta;
  final double velocidad;
  final Map<String, dynamic>? llegada;
  final bool reintentando;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return _Globo(
      ancho: 240,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: lb.linea))),
            child: Row(
              children: [
                Text(placa, style: AppTheme.titulo(size: 24, color: lb.tinta, height: 1).copyWith(letterSpacing: 0.7)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(6, 5, 6, 4),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppTheme.radio)),
                  child: Text(codigo.isEmpty ? 'Ruta' : codigo,
                      style: AppTheme.titulo(size: 17, color: lb.sobreColor, height: 1)),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onCerrar,
                  tooltip: 'Cerrar',
                  visualDensity: VisualDensity.compact,
                  icon: Text('×', style: TextStyle(fontSize: 20, color: lb.grisTexto, height: 1)),
                ),
              ],
            ),
          ),
          _Llegada(datos: llegada, reintentando: reintentando),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: lb.linea))),
            child: Row(
              children: [
                Expanded(
                  child: Text(ruta,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.6, color: lb.grisTexto)),
                ),
                const SizedBox(width: 12),
                Text('${velocidad.toStringAsFixed(1)} km/h',
                    style: TextStyle(
                        fontSize: 13.6,
                        fontWeight: FontWeight.w700,
                        color: lb.tinta,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Llegada estimada (.llegada): el nivel solo cambia el color de la franja lateral.
class _Llegada extends StatelessWidget {
  const _Llegada({required this.datos, required this.reintentando});
  final Map<String, dynamic>? datos;
  final bool reintentando;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    String etiqueta;
    String? valor;
    String? nota;
    var pequeno = false;
    var nivel = lb.grisTexto;
    var esqueleto = false;

    final d = datos;
    if (reintentando) {
      etiqueta = 'Sin conexión';
      nota = 'No pudimos calcular la llegada. Se intenta de nuevo solo.';
    } else if (d == null) {
      etiqueta = 'Calculando la llegada…';
      esqueleto = true;
    } else if (d['status'] == 'stopped') {
      etiqueta = 'Estado';
      valor = 'Detenido';
      nota = 'El bus no está en movimiento.';
      pequeno = true;
    } else if (d['status'] == 'passed') {
      etiqueta = 'Estado';
      valor = 'Ya pasó';
      nota = 'Pasó por tu punto hace ${d['distancia_km']} km.';
      pequeno = true;
    } else if (d['status'] == 'ok' && d['tiempo_texto'] != null) {
      final minutos = (d['tiempo_minutos'] as num?)?.toDouble() ?? 99;
      nivel = minutos < 5 ? lb.verde : minutos < 15 ? lb.amarillo : lb.azul;
      etiqueta = d['destino_origen'] == 'usuario' ? 'Llega a tu ubicación en' : 'Llega al punto más cercano de la ruta en';
      valor = '${d['tiempo_texto']}';
      nota = 'Distancia: ${d['distancia_km']} km';
    } else if (d['status'] == 'ok') {
      nivel = lb.amarillo;
      etiqueta = 'Falta tu ubicación';
      nota = 'Pulsa "Mi ubicación" para ver cuándo llega.';
    } else {
      etiqueta = 'Sin datos';
      nota = '${d['error'] ?? 'No pudimos calcular la llegada.'}';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: nivel, width: 6))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            if (reintentando) ...[Aro(size: 11, color: lb.grisTexto), const SizedBox(width: 7)],
            Flexible(child: Text(etiqueta, style: TextStyle(fontSize: 12.8, color: lb.grisTexto))),
          ]),
          if (esqueleto) ...[
            const SizedBox(height: 8),
            _Esqueleto(ancho: 130, alto: 27),
            const SizedBox(height: 7),
            _Esqueleto(ancho: 90, alto: 13),
          ],
          if (valor != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(valor,
                  key: ValueKey(valor), style: AppTheme.titulo(size: pequeno ? 22.4 : 33.6, color: lb.tinta)),
            ),
          if (nota != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(nota, style: TextStyle(fontSize: 13.6, color: lb.grisTexto, height: 1.3)),
            ),
        ],
      ),
    );
  }
}

class _Esqueleto extends StatefulWidget {
  const _Esqueleto({required this.ancho, required this.alto});
  final double ancho;
  final double alto;

  @override
  State<_Esqueleto> createState() => _EsqueletoState();
}

class _EsqueletoState extends State<_Esqueleto> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final a = oscuro ? const Color(0xFF1F2529) : const Color(0xFFE6E9EA);
    final b = oscuro ? const Color(0xFF2A3136) : const Color(0xFFF4F5F7);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.ancho,
        height: widget.alto,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: LinearGradient(
            begin: Alignment(-1 + 4 * _c.value - 2, 0),
            end: Alignment(1 + 4 * _c.value - 2, 0),
            colors: [a, b, a],
          ),
        ),
      ),
    );
  }
}

/// Aviso de conexión (.estado-conexion).
class _PildoraConexion extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final texto = oscuro ? const Color(0xFFF2D27A) : const Color(0xFF7A5500);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: oscuro ? const Color(0xFF2B2410) : const Color(0xFFFFF8E1),
          border: Border.all(color: oscuro ? const Color(0xFF6B5410) : const Color(0xFFE8C97A)),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Aro(size: 13, color: texto),
          const SizedBox(width: 8),
          Text('Sin conexión. Reintentando…', style: TextStyle(fontSize: 13.6, fontWeight: FontWeight.w700, color: texto)),
        ]),
      ),
    );
  }
}

/// Tablero de avisos (.map-marquee-container): etiqueta roja y los avisos que pasan solos.
class _TableroAvisos extends StatefulWidget {
  const _TableroAvisos({required this.avisos});
  final List<AvisoMapa> avisos;

  @override
  State<_TableroAvisos> createState() => _TableroAvisosState();
}

class _TableroAvisosState extends State<_TableroAvisos> with TickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  late final Ticker _ticker = createTicker(_avanzar);
  late final AnimationController _parpadeo =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  Duration _anterior = Duration.zero;
  bool _quieto = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _quieto = MediaQuery.of(context).disableAnimations;
    if (_quieto) {
      _ticker.stop();
      _parpadeo.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _avanzar(Duration t) {
    final paso = (t - _anterior).inMicroseconds / 1e6;
    _anterior = t;
    if (!_scroll.hasClients || paso <= 0 || paso > 0.5) return;
    final pos = _scroll.position;
    final grupo = (pos.maxScrollExtent + pos.viewportDimension) / 2;
    if (grupo <= 0 || pos.maxScrollExtent <= 0) return;
    var nuevo = _scroll.offset + math.max(30.0, grupo / 80) * paso;
    if (nuevo >= grupo) nuevo -= grupo;
    _scroll.jumpTo(nuevo.clamp(0, pos.maxScrollExtent));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _parpadeo.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    final hay = widget.avisos.isNotEmpty;
    final ancho = MediaQuery.of(context).size.width;

    Widget grupo() => ConstrainedBox(
          constraints: BoxConstraints(minWidth: ancho),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 48, 0),
            child: Row(
              children: [
                if (!hay)
                  Text('Las rutas operan sin novedades.', style: TextStyle(fontSize: 14.4, color: lb.tinta))
                else
                  for (final a in widget.avisos) ...[_aviso(context, a), const SizedBox(width: 48)],
              ],
            ),
          ),
        );

    return Container(
      height: 48,
      decoration: BoxDecoration(color: lb.blanco, border: Border(bottom: BorderSide(color: lb.linea))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: lb.rojoInterfaz,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Row(children: [
              if (hay)
                AnimatedBuilder(
                  animation: _parpadeo,
                  builder: (context, _) {
                    final t = math.sin(_parpadeo.value * math.pi);
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: lb.blanco,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.7 * (1 - t)), spreadRadius: 5 * t)],
                      ),
                    );
                  },
                ),
              Text(hay ? 'Avisos' : 'Sin avisos', style: AppTheme.titulo(size: 17.6, color: lb.blanco, height: 1)),
            ]),
          ),
          Expanded(
            child: ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
                stops: [0, 0.04, 0.96, 1],
              ).createShader(r),
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                physics: _quieto ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
                child: Row(children: [grupo(), if (!_quieto) ExcludeSemantics(child: grupo())]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aviso(BuildContext context, AvisoMapa a) {
    final lb = context.lb;
    final (fondo, letra, nombre) = switch (a.tipo.toLowerCase()) {
      'delay' => (lb.rojoInterfaz, lb.blanco, 'Demora'),
      'warning' => (lb.amarillo, lb.sobreAmarillo, 'Advertencia'),
      _ => (lb.azul, lb.blanco, 'Información'),
    };
    return Row(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(AppTheme.radio)),
          child: Text(nombre, style: TextStyle(fontSize: 12.8, fontWeight: FontWeight.w700, color: letra)),
        ),
        Text(a.ruta, style: TextStyle(fontSize: 14.4, fontWeight: FontWeight.w700, color: lb.tinta)),
        const SizedBox(width: 5),
        Text(a.descripcion, style: TextStyle(fontSize: 14.4, color: lb.tinta)),
        const SizedBox(width: 8),
        Text('hace ${a.hace}', style: TextStyle(fontSize: 12.8, color: lb.grisTexto)),
      ],
    );
  }
}
