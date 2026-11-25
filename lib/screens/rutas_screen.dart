import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ruta.dart';
import '../services/api.dart';
import '../services/server_config.dart';
import '../services/ubicacion.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/lb.dart';

/// Rutas (rutas.html) como las ve un pasajero: filtros por estado, búsqueda y tres formas de verlas.
class RutasScreen extends StatefulWidget {
  const RutasScreen({super.key});

  @override
  State<RutasScreen> createState() => _RutasScreenState();
}

const _estados = [
  ('Activa', 'Activas'),
  ('Sin_buses', 'Sin buses activos'),
  ('Fuera_horario', 'Fuera de horario'),
  ('Fuera_servicio', 'Fuera de servicio'),
];

class _RutasScreenState extends State<RutasScreen> {
  final TextEditingController _buscar = TextEditingController();
  final MapController _mapa = MapController();
  List<Ruta> _rutas = [];
  bool _cargando = true;
  String? _error;
  String _filtro = 'todas';
  String _texto = '';
  String _vista = 'tabla';
  Ruta? _globo;

  @override
  void initState() {
    super.initState();
    _cargar();
    ServerConfig.cambios.addListener(_cargar);
    SharedPreferences.getInstance().then((p) {
      final guardada = p.getString('rutas_vista');
      if (mounted && (guardada == 'fichas' || guardada == 'mapa')) setState(() => _vista = guardada!);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    ServerConfig.cambios.removeListener(_cargar);
    _buscar.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final d = await Api.get('mapa/');
      if (!mounted) return;
      setState(() {
        _rutas = (d['rutas'] as List? ?? []).map((r) => Ruta.fromJson(r as Map<String, dynamic>)).toList();
        _cargando = false;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.mensaje;
      });
    }
  }

  List<Ruta> get _visibles {
    final t = _texto.toLowerCase().trim();
    return _rutas.where((r) {
      final estado = _filtro == 'todas' || r.estado == _filtro;
      final texto = t.isEmpty || '${r.codigo} ${r.nombre} ${r.origen} ${r.destino}'.toLowerCase().contains(t);
      return estado && texto;
    }).toList();
  }

  void _cambiarVista(String v) {
    setState(() {
      _vista = v;
      _globo = null;
    });
    SharedPreferences.getInstance().then((p) => p.setString('rutas_vista', v)).catchError((_) => false);
    if (v == 'mapa') WidgetsBinding.instance.addPostFrameCallback((_) => _encuadrar());
  }

  void _encuadrar() {
    final puntos = [
      for (final r in _visibles)
        if (r.coordenadas.length > 1) ...r.coordenadas.map((c) => LatLng(c[1], c[0])),
    ];
    if (puntos.length < 2) return;
    try {
      _mapa.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(puntos), padding: const EdgeInsets.all(30), maxZoom: 15));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _visibles;
    final mapa = _vista == 'mapa';

    final cabecera = <Widget>[
      const CabeceraPagina(
        etiqueta: 'Red de transporte',
        titulo: 'Rutas',
        subtitulo: 'Recorridos de las empresas de transporte de Medellín. Elige una en el mapa para ver sus buses en vivo.',
      ),
      if (_rutas.isNotEmpty) ...[
        const SizedBox(height: 10),
        TextField(
          controller: _buscar,
          onChanged: (v) {
            setState(() {
              _texto = v;
              _globo = null;
            });
            if (mapa) _encuadrar();
          },
          textInputAction: TextInputAction.search,
          style: TextStyle(fontSize: 16, color: context.lb.tinta),
          decoration: InputDecoration(
            hintText: 'Buscar ruta, origen o destino',
            suffixIcon: _texto.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Borrar búsqueda',
                    onPressed: () => setState(() {
                      _buscar.clear();
                      _texto = '';
                    }),
                    icon: const Icon(Icons.close, size: 18),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        LbPestanas<String>(
          elegida: _filtro,
          onElegir: (v) {
            setState(() {
              _filtro = v;
              _globo = null;
            });
            if (mapa) _encuadrar();
          },
          pestanas: [
            PestanaLb('todas', 'Todas', cuenta: _rutas.length),
            for (final (estado, nombre) in _estados)
              PestanaLb(estado, nombre, cuenta: _rutas.where((r) => r.estado == estado).length),
          ],
        ),
        _VerComo(vista: _vista, onElegir: _cambiarVista),
        if (visibles.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: LbNota('No hay rutas con estos filtros. Prueba con otro estado u otra búsqueda.', margen: EdgeInsets.zero),
          ),
      ],
      const SizedBox(height: 14),
    ];

    Widget cuerpo;
    if (_cargando) {
      cuerpo = const SliverToBoxAdapter(
          child: Padding(padding: EdgeInsets.all(28), child: CargandoTexto('Cargando las rutas…')));
    } else if (_error != null) {
      cuerpo = SliverToBoxAdapter(
        child: StateMessage(
          icon: Icons.wifi_off_rounded,
          title: 'No pudimos cargar las rutas',
          message: _error,
          actionLabel: 'Reintentar',
          onAction: _cargar,
        ),
      );
    } else if (_rutas.isEmpty) {
      cuerpo = SliverToBoxAdapter(child: _vacio(context));
    } else if (mapa) {
      cuerpo = SliverToBoxAdapter(child: _vistaMapa(context, visibles));
    } else {
      cuerpo = SliverList.builder(
        itemCount: visibles.length,
        itemBuilder: (context, i) => Padding(
          padding: EdgeInsets.only(bottom: _vista == 'fichas' ? 14 : 0),
          child: FichaRuta(ruta: visibles[i], tarjeta: _vista == 'fichas'),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _cargar,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverList.list(children: cabecera),
              ),
              SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), sliver: cuerpo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vacio(BuildContext context) {
    final lb = context.lb;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      color: lb.concreto,
      child: Column(children: [
        Text('No hay rutas disponibles por ahora',
            textAlign: TextAlign.center, style: AppTheme.titulo(size: 22.4, color: lb.tinta, height: 1.2)),
        const SizedBox(height: 6),
        Text('Cuando una empresa publique sus recorridos, aparecerán aquí y en el mapa.',
            textAlign: TextAlign.center, style: TextStyle(color: lb.grisTexto, height: 1.4)),
      ]),
    );
  }

  Widget _vistaMapa(BuildContext context, List<Ruta> visibles) {
    final lb = context.lb;
    final conTrazado = visibles.where((r) => r.coordenadas.length > 1).toList();
    final sinTrazado = visibles.length - conTrazado.length;
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final alto = MediaQuery.of(context).size.height * 0.62;

    final nota = conTrazado.isEmpty
        ? 'No hay rutas para mostrar con estos filtros.'
        : '${conTrazado.length == 1 ? '1 ruta en el mapa.' : '${conTrazado.length} rutas en el mapa.'}'
            ' Toca una línea para ver sus datos.'
            '${sinTrazado > 0 ? ' $sinTrazado ${sinTrazado == 1 ? 'ruta no tiene' : 'rutas no tienen'} recorrido trazado.' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: alto,
          decoration: BoxDecoration(border: Border.all(color: lb.linea)),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapa,
                options: MapOptions(
                  initialCenter: const LatLng(6.2442, -75.5812),
                  initialZoom: 12,
                  minZoom: 10,
                  maxZoom: 19,
                  backgroundColor: lb.mapaFondo,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  onMapReady: _encuadrar,
                  onTap: (_, punto) => _tocar(punto, conTrazado),
                ),
                children: [
                  oscuro
                      ? ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            -0.28, -0.6, -0.06, 0, 205, //
                            -0.24, -0.64, -0.06, 0, 205, //
                            -0.24, -0.6, -0.1, 0, 210, //
                            0, 0, 0, 1, 0,
                          ]),
                          child: TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.monitor_app'),
                        )
                      : TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.monitor_app'),
                  PolylineLayer(polylines: [
                    for (final r in conTrazado)
                      Polyline(
                        points: r.coordenadas.map((c) => LatLng(c[1], c[0])).toList(),
                        color: r.color.withValues(alpha: 0.85),
                        strokeWidth: _globo?.id == r.id ? 8 : 5,
                      ),
                  ]),
                ],
              ),
              if (_globo != null)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Material(
                    color: lb.blanco,
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radioVentana)),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 36, 10),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: alto * 0.7),
                            child: SingleChildScrollView(child: FichaRuta(ruta: _globo!, globo: true)),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            tooltip: 'Cerrar',
                            onPressed: () => setState(() => _globo = null),
                            icon: Text('×', style: TextStyle(fontSize: 22, color: lb.grisTexto)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(nota, style: TextStyle(fontSize: 13.6, color: lb.grisTexto, height: 1.4)),
        ),
      ],
    );
  }

  /// Toca cerca de una línea (a 22 px o menos en pantalla) para ver sus datos.
  void _tocar(LatLng punto, List<Ruta> rutas) {
    final zoom = _mapa.camera.zoom;
    final metrosPorPixel = 156543.03392 * math.cos(punto.latitude * math.pi / 180) / math.pow(2, zoom);
    Ruta? cercana;
    var minima = 22 * metrosPorPixel;
    for (final r in rutas) {
      final d = Ubicacion.distanciaARuta(punto, r.coordenadas);
      if (d < minima) {
        minima = d;
        cercana = r;
      }
    }
    setState(() => _globo = cercana);
  }
}

/// «Ver como»: Tabla, Fichas o Mapa (.ru-vista).
class _VerComo extends StatelessWidget {
  const _VerComo({required this.vista, required this.onElegir});
  final String vista;
  final ValueChanged<String> onElegir;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    Widget boton(String valor, String texto) {
      final activa = vista == valor;
      return Semantics(
        button: true,
        selected: activa,
        child: InkWell(
          onTap: () => onElegir(valor),
          borderRadius: BorderRadius.circular(AppTheme.radio),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: activa ? lb.tinta : lb.blanco,
              border: Border.all(color: activa ? lb.tinta : lb.linea),
              borderRadius: BorderRadius.circular(AppTheme.radio),
            ),
            child: Text(texto,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.4, color: activa ? lb.blanco : lb.tinta)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ExcludeSemantics(
              child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text('Ver como', style: TextStyle(fontSize: 13.6, color: lb.grisTexto)),
          )),
          boton('tabla', 'Tabla'),
          boton('fichas', 'Fichas'),
          boton('mapa', 'Mapa'),
        ],
      ),
    );
  }
}

/// Una ruta como fila de la tabla en el celular, como ficha o dentro del globo del mapa (.ru-fila).
class FichaRuta extends StatelessWidget {
  const FichaRuta({super.key, required this.ruta, this.tarjeta = false, this.globo = false});

  final Ruta ruta;
  final bool tarjeta;
  final bool globo;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    final r = ruta;
    Widget dato(String etiqueta, String? valor) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etiqueta, style: TextStyle(fontSize: 12, color: lb.grisTexto)),
            Text(valor ?? 'Sin dato',
                style: TextStyle(
                  fontSize: 15,
                  color: valor == null ? lb.grisTexto : lb.tinta,
                  fontStyle: valor == null ? FontStyle.italic : null,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ],
        );

    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PlacaRuta(codigo: r.codigo, color: r.color, size: 17),
            Text(r.nombre, style: AppTheme.titulo(size: 19, color: lb.tinta, height: 1.15)),
            if (!r.activa) InsigniaRuta(estado: r.estado, texto: r.estadoNombre),
          ],
        ),
        if (r.motivo.isNotEmpty) MotivoRuta(estado: r.estado, texto: r.motivo),
        const SizedBox(height: 10),
        TrayectoRuta(origen: r.origen, destino: r.destino, color: r.color, lineas: 2),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: dato('Distancia', r.distanciaTexto)),
          Expanded(child: dato('Duración', r.duracionMinutos > 0 ? '${r.duracionMinutos} min' : null)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: dato('Frecuencia', r.frecuenciaMinutos > 0 ? 'Cada ${r.frecuenciaMinutos} min' : null)),
          Expanded(child: dato('Paradas', '${r.numParadas}')),
        ]),
        const SizedBox(height: 8),
        dato('Empresa', r.empresa),
      ],
    );

    if (globo) return contenido;
    if (tarjeta) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: lb.blanco,
          borderRadius: BorderRadius.circular(AppTheme.radio),
          border: Border(
            left: BorderSide(color: r.color, width: 5),
            top: BorderSide(color: lb.linea),
            right: BorderSide(color: lb.linea),
            bottom: BorderSide(color: lb.linea),
          ),
        ),
        child: contenido,
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 15, 0, 16),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: r.color, width: 4), bottom: BorderSide(color: lb.linea)),
      ),
      child: contenido,
    );
  }
}
