import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/alerta.dart';
import '../models/ruta.dart';
import '../services/api.dart';
import '../services/mensajes.dart';
import '../services/navegacion.dart';
import '../services/server_config.dart';
import '../services/sesion.dart';
import '../services/ubicacion.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/lb.dart';

/// Centro de alertas (alertas.html) para invitados y pasajeros: las alertas que las empresas ya revisaron y,
/// con sesión, «Mis reportes», crear o editar una alerta y «Rutas que sigo».
class AlertasScreen extends StatefulWidget {
  const AlertasScreen({super.key});

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> {
  List<Alerta> _alertas = [];
  List<Alerta> _misReportes = [];
  List<RutaOpcion> _rutas = [];
  Set<int> _seguidas = {};
  List<int> _diasOpciones = const [7, 30, 90];
  int _dias = 7;
  bool _recortada = false;
  int _max = 300;
  bool _cargando = true;
  String? _error;

  String _vista = 'publicas';
  String _tipo = 'all';
  int? _rutaFiltro;

  @override
  void initState() {
    super.initState();
    _cargar();
    Sesion.i.addListener(_alCambiarSesion);
    ServerConfig.cambios.addListener(_cargar);
    Navegacion.pedidoReportar.addListener(_alPedirReporte);
    Navegacion.pestana.addListener(_alCambiarPestana);
    // Se pidió «Reportar» desde el mapa antes de abrir esta pestaña por primera vez
    if (Navegacion.pedidoReportar.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _alPedirReporte());
    }
  }

  @override
  void dispose() {
    Sesion.i.removeListener(_alCambiarSesion);
    ServerConfig.cambios.removeListener(_cargar);
    Navegacion.pedidoReportar.removeListener(_alPedirReporte);
    Navegacion.pestana.removeListener(_alCambiarPestana);
    super.dispose();
  }

  void _alCambiarSesion() {
    if (!Sesion.i.activa) _vista = 'publicas';
    _cargar();
  }

  void _alCambiarPestana() {
    if (Navegacion.pestana.value == Navegacion.alertas && !_cargando) _cargar(silencioso: true);
  }

  /// «Reportar» del mapa: abre el formulario con la ruta fijada preseleccionada.
  Future<void> _alPedirReporte() async {
    final pedido = Navegacion.pedidoReportar.value;
    if (pedido == null || !Sesion.i.activa) return;
    Navegacion.pedidoReportar.value = null;
    if (_rutas.isEmpty) await _cargar();
    if (!mounted) return;
    _abrirFormulario(rutaFijada: pedido.rutaId);
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final d = await Api.get('alertas/', q: {'dias': '$_dias'});
      if (!mounted) return;
      setState(() {
        _alertas = (d['alertas'] as List? ?? []).map((a) => Alerta.fromJson(a as Map<String, dynamic>)).toList();
        _misReportes =
            (d['mis_reportes'] as List? ?? []).map((a) => Alerta.fromJson(a as Map<String, dynamic>)).toList();
        _rutas = (d['rutas'] as List? ?? []).map((r) => RutaOpcion.fromJson(r as Map<String, dynamic>)).toList();
        _seguidas = (d['rutas_seguidas'] as List? ?? []).whereType<int>().toSet();
        _diasOpciones = (d['dias_opciones'] as List? ?? const [7, 30, 90]).whereType<int>().toList();
        _dias = (d['dias'] as num?)?.toInt() ?? _dias;
        _recortada = d['recortada'] == true;
        _max = (d['max_alertas'] as num?)?.toInt() ?? 300;
        _cargando = false;
        _error = null;
        if (_rutaFiltro != null && !_rutasFiltro.any((r) => r.$1 == _rutaFiltro)) _rutaFiltro = null;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        if (!silencioso) _error = e.mensaje;
      });
    }
  }

  List<Alerta> get _fuente => _vista == 'mios' ? _misReportes : _alertas;

  List<Alerta> get _filtradas => _fuente
      .where((a) => (_tipo == 'all' || a.tipo == _tipo) && (_rutaFiltro == null || a.rutaId == _rutaFiltro))
      .toList();

  /// Solo las rutas que tienen alertas en la lista (filtro «Ruta»).
  List<(int, String)> get _rutasFiltro {
    final vistas = <int, Alerta>{for (final a in _alertas) a.rutaId: a};
    final lista = vistas.values.toList()
      ..sort((a, b) {
        final n = a.rutaNombre.toLowerCase().compareTo(b.rutaNombre.toLowerCase());
        return n != 0 ? n : a.rutaCodigo.compareTo(b.rutaCodigo);
      });
    return [for (final a in lista) (a.rutaId, '${a.rutaCodigo} · ${a.rutaNombre}')];
  }

  int _contar(String tipo) => _alertas.where((a) => a.tipo == tipo).length;

  @override
  Widget build(BuildContext context) {
    final con = Sesion.i.activa;
    final filtradas = _filtradas;
    final pendientes = _misReportes.where((r) => r.estado == 'Pendiente').length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _cargar(silencioso: true),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                sliver: SliverList.list(children: [
                  CabeceraPagina(
                    etiqueta: 'Centro de alertas',
                    titulo: 'Alertas',
                    subtitulo: 'Novedades de las rutas que las empresas ya revisaron.'
                        '${con ? ' En «Mis reportes» ves en qué va cada alerta que enviaste.' : ''}',
                  ),
                  if (con)
                    LbPestanas<String>(
                      elegida: _vista,
                      onElegir: (v) => setState(() => _vista = v),
                      pestanas: [
                        const PestanaLb('publicas', 'Publicadas'),
                        PestanaLb('mios', 'Mis reportes', cuenta: _misReportes.length, pendiente: pendientes > 0),
                      ],
                    ),
                  const SizedBox(height: 4),
                  LbPestanas<String>(
                    elegida: _tipo,
                    onElegir: (v) => setState(() => _tipo = v),
                    pestanas: [
                      PestanaLb('all', 'Todas', cuenta: _alertas.length),
                      PestanaLb('delay', 'Demoras', cuenta: _contar('delay')),
                      PestanaLb('warning', 'Advertencias', cuenta: _contar('warning')),
                      PestanaLb('info', 'Información', cuenta: _contar('info')),
                    ],
                  ),
                  LbSelect<int>(
                    etiqueta: 'Ruta',
                    enLinea: true,
                    valor: _rutaFiltro,
                    opciones: [(null, 'Todas las rutas'), for (final r in _rutasFiltro) (r.$1, r.$2)],
                    onChanged: (v) => setState(() => _rutaFiltro = v),
                  ),
                  LbSelect<int>(
                    etiqueta: 'Resueltas de',
                    enLinea: true,
                    valor: _dias,
                    opciones: [for (final d in _diasOpciones) (d, 'los últimos $d días')],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _dias = v);
                      _cargar();
                    },
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: con
                        ? [
                            _BotonSeguir(cuenta: _seguidas.length, onPressed: _rutas.isEmpty ? null : _abrirSeguir),
                            LbBoton('Crear alerta', onPressed: _rutas.isEmpty ? null : () => _abrirFormulario()),
                          ]
                        : [
                            LbBoton('Inicia sesión para crear alertas',
                                estilo: EstiloBoton.secundario, onPressed: () => Navegacion.ir(Navegacion.cuenta)),
                          ],
                  ),
                  if (!_cargando && _error == null && filtradas.isEmpty && _fuente.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LbNota('No hay alertas con estos filtros por ahora. Prueba con otros.', margen: EdgeInsets.zero),
                    ),
                  if (_recortada && _vista == 'publicas')
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: LbNota(
                          'Mostramos las $_max alertas más importantes. Usa los filtros o un periodo más corto para ver el resto.',
                          margen: EdgeInsets.zero),
                    ),
                  const SizedBox(height: 18),
                ]),
              ),
              if (_cargando)
                const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.all(28), child: CargandoTexto('Cargando las alertas…')),
                )
              else if (_error != null)
                SliverToBoxAdapter(
                  child: StateMessage(
                    icon: Icons.wifi_off_rounded,
                    title: 'No pudimos cargar las alertas',
                    message: _error,
                    actionLabel: 'Reintentar',
                    onAction: _cargar,
                  ),
                )
              else if (_fuente.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  sliver: SliverToBoxAdapter(child: _vacio(con)),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                  sliver: SliverList.separated(
                    itemCount: filtradas.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, i) => _TarjetaAlerta(
                      alerta: filtradas[i],
                      mio: _vista == 'mios',
                      onTap: () => _verDetalle(filtradas[i], _vista == 'mios'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vacio(bool con) {
    final lb = context.lb;
    final (titulo, texto) = _vista == 'mios'
        ? (
            'Aún no has enviado reportes',
            'Si ves un problema en una ruta, avísalo con «Crear alerta». Aquí verás si la empresa lo publicó, lo resolvió o lo descartó.'
          )
        : (
            'Todavía no hay alertas publicadas',
            'Cuando una empresa revise una novedad, aparecerá aquí.'
                '${con ? ' Si ves un problema en una ruta, avísalo con «Crear alerta».' : ''}'
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      color: lb.concreto,
      child: Column(children: [
        Text(titulo, textAlign: TextAlign.center, style: AppTheme.titulo(size: 22.4, color: lb.tinta, height: 1.2)),
        const SizedBox(height: 6),
        Text(texto, textAlign: TextAlign.center, style: TextStyle(fontSize: 15.2, color: lb.grisTexto, height: 1.4)),
      ]),
    );
  }

  // ================= DETALLE =================

  Future<void> _verDetalle(Alerta a, bool mio) async {
    final resultado = await mostrarModal<String>(
      context,
      titulo: 'Detalle de la alerta',
      contenido: (c) => _Detalle(alerta: a, mio: mio),
    );
    if (!mounted) return;
    if (resultado == 'editar') {
      _abrirFormulario(editar: a);
    } else if (resultado == 'inhabilitada') {
      _cargar(silencioso: true);
    }
  }

  // ================= CREAR O EDITAR =================

  Future<void> _abrirFormulario({Alerta? editar, int? rutaFijada}) async {
    final resultado = await mostrarModal<Map<String, dynamic>>(
      context,
      titulo: editar == null ? 'Crear alerta' : 'Editar alerta',
      contenido: (c) => _FormularioAlerta(rutas: _rutas, editar: editar, rutaFijada: rutaFijada),
    );
    if (!mounted || resultado == null) return;
    Mensajes.mostrar('${resultado['mensaje']}', nivel: nivelDesdeTexto(resultado['nivel'] as String?));
    // Después de enviar un reporte se vuelve a «Mis reportes»
    if (editar == null) setState(() => _vista = 'mios');
    _cargar(silencioso: true);
  }

  // ================= RUTAS QUE SIGO =================

  Future<void> _abrirSeguir() async {
    final resultado = await mostrarModal<Map<String, dynamic>>(
      context,
      titulo: 'Rutas que sigo',
      contenido: (c) => _SeguirRutas(rutas: _rutas, seguidas: _seguidas),
    );
    if (!mounted || resultado == null) return;
    setState(() => _seguidas = (resultado['rutas_seguidas'] as List? ?? []).whereType<int>().toSet());
    Mensajes.mostrar('${resultado['mensaje']}');
  }
}

class _BotonSeguir extends StatelessWidget {
  const _BotonSeguir({required this.cuenta, required this.onPressed});
  final int cuenta;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        LbBoton('Rutas que sigo', estilo: EstiloBoton.secundario, onPressed: onPressed),
        if (cuenta > 0) Positioned(right: -6, top: -8, child: LbCuenta(cuenta)),
      ],
    );
  }
}

// ================= TARJETA =================

Color colorTipo(BuildContext context, String tipo) => switch (tipo) {
      'delay' => context.lb.rojoInterfaz,
      'warning' => context.lb.amarillo,
      _ => context.lb.azul,
    };

class EtiquetaTipo extends StatelessWidget {
  const EtiquetaTipo(this.tipo, {super.key});
  final String tipo;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 4, 9, 3),
      decoration: BoxDecoration(color: colorTipo(context, tipo), borderRadius: BorderRadius.circular(AppTheme.radio)),
      child: Text(
        nombreTipoAlerta(tipo).toUpperCase(),
        style: AppTheme.titulo(size: 13.6, color: tipo == 'warning' ? const Color(0xFF080707) : lb.blanco, height: 1)
            .copyWith(letterSpacing: 1.1),
      ),
    );
  }
}

class EstadoAlerta extends StatelessWidget {
  const EstadoAlerta({super.key, required this.estado, required this.texto});
  final String estado;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    final (borde, fondo, letra) = switch (estado) {
      'Resuelta' => (lb.verde, Colors.transparent, lb.verde),
      'Pendiente' => (lb.amarillo, lb.amarillo, lb.sobreAmarillo),
      'En_proceso' => (lb.azul, Colors.transparent, lb.azul),
      _ => (lb.tinta, Colors.transparent, lb.tinta),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: fondo, border: Border.all(color: borde), borderRadius: BorderRadius.circular(3)),
      child: Text(texto, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: letra)),
    );
  }
}

class _TarjetaAlerta extends StatelessWidget {
  const _TarjetaAlerta({required this.alerta, required this.mio, required this.onTap});

  final Alerta alerta;
  final bool mio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    final a = alerta;
    final pequeno = TextStyle(fontSize: 12.8, fontWeight: FontWeight.w600, color: lb.grisTexto, height: 1.35);
    return Semantics(
      button: true,
      label: mio ? 'Ver tu reporte de ${a.rutaNombre}' : 'Ver la alerta de ${a.rutaNombre}',
      child: Material(
        color: lb.blanco,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radio)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radio),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radio),
              border: Border(
                left: BorderSide(color: colorTipo(context, a.tipo), width: 5),
                top: BorderSide(color: lb.linea),
                right: BorderSide(color: lb.linea),
                bottom: BorderSide(color: lb.linea),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  EtiquetaTipo(a.tipo),
                  const Spacer(),
                  Text(a.fecha, style: TextStyle(fontSize: 12.8, color: lb.grisTexto)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  PlacaRuta(codigo: a.rutaCodigo, color: a.color, size: 16),
                  const SizedBox(width: 10),
                  Expanded(child: Text(a.rutaNombre, style: AppTheme.titulo(size: 19.2, color: lb.tinta, height: 1.15))),
                ]),
                const SizedBox(height: 10),
                Text(
                  mio && a.confirmacion ? 'Confirmaste esta alerta: «${a.sumada}»' : a.descripcion,
                  style: TextStyle(fontSize: 15.2, height: 1.5, color: lb.tinta),
                ),
                if (mio && a.sumada.isNotEmpty && !a.confirmacion) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Se sumó a una alerta igual que ya existía'
                    '${a.sumadaEmpresa.isNotEmpty ? ', publicada por ${a.sumadaEmpresa}' : ''}.',
                    style: pequeno,
                  ),
                ],
                if (mio && a.descartada) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(border: Border(left: BorderSide(color: lb.rojoInterfaz, width: 2))),
                    child: Text('La empresa la descartó: ${a.motivo}.',
                        style: TextStyle(fontSize: 13.6, color: lb.tinta, height: 1.35)),
                  ),
                ],
                if (!mio && a.empresa.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Publicada por ${a.empresa}', style: pequeno),
                ],
                if (a.estado == 'En_proceso' && a.vence.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Vigente hasta las ${a.vence}', style: pequeno),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: lb.linea))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(mio ? a.pieReporte : '${a.rutaOrigen} → ${a.rutaDestino}',
                            style: TextStyle(fontSize: 12.8, color: lb.grisTexto)),
                      ),
                      const SizedBox(width: 10),
                      EstadoAlerta(estado: a.estado, texto: mio ? a.estadoReporte : a.estadoTexto),
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
}

// ================= DETALLE =================

class _Detalle extends StatefulWidget {
  const _Detalle({required this.alerta, required this.mio});
  final Alerta alerta;
  final bool mio;

  @override
  State<_Detalle> createState() => _DetalleState();
}

class _DetalleState extends State<_Detalle> {
  bool _confirmando = false;
  bool _enviando = false;
  String? _error;

  Future<void> _inhabilitar() async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final d = await Api.post('alertas/${widget.alerta.id}/inhabilitar/');
      if (!mounted) return;
      Mensajes.mostrar('${d['mensaje']}');
      Navigator.of(context).pop('inhabilitada');
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _error = e.mensaje;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    final a = widget.alerta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) LbNota.error(context, _error!),
        LbDato(etiqueta: 'Ruta', valor: '${a.rutaCodigo} · ${a.rutaNombre}'),
        LbDato(etiqueta: 'Tipo', hijo: Align(alignment: Alignment.centerLeft, child: EtiquetaTipo(a.tipo))),
        LbDato(etiqueta: 'Descripción', valor: a.descripcion),
        LbDato(etiqueta: 'Estado', valor: widget.mio ? a.estadoReporte : a.estadoTexto),
        LbDato(etiqueta: 'Creada', valor: a.fecha),
        const SizedBox(height: 16),
        if (widget.mio && a.editable)
          const LbNota('Puedes editarla o inhabilitarla mientras esté pendiente. Si la editas, la empresa la revisará con el texto nuevo.'),
        if (widget.mio && !a.editable && (a.estado == 'En_proceso' || a.estado == 'Resuelta'))
          const LbNota('La empresa ya la revisó: desde ahora la gestiona ella.'),
        if (widget.mio && a.descartada)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: lb.rojoInterfaz, width: 2))),
            child: Text('La empresa la descartó: ${a.motivo}.', style: TextStyle(color: lb.tinta, height: 1.4)),
          ),
        if (a.editable && !_confirmando)
          LbAcciones(botones: [
            LbBoton('Editar', estilo: EstiloBoton.secundario, onPressed: () => Navigator.of(context).pop('editar')),
            LbBoton('Inhabilitar', estilo: EstiloBoton.peligro, onPressed: () => setState(() => _confirmando = true)),
          ]),
        if (_confirmando) ...[
          LbNota('¿Inhabilitar esta alerta? Dejará de mostrarse, pero queda guardada en el sistema.',
              color: lb.rojoInterfaz),
          LbAcciones(botones: [
            LbBoton('Cancelar', estilo: EstiloBoton.secundario, onPressed: () => setState(() => _confirmando = false)),
            LbBoton('Sí, inhabilitar', estilo: EstiloBoton.peligro, cargando: _enviando, onPressed: _inhabilitar),
          ]),
        ],
      ],
    );
  }
}

// ================= FORMULARIO =================

class _FormularioAlerta extends StatefulWidget {
  const _FormularioAlerta({required this.rutas, this.editar, this.rutaFijada});

  final List<RutaOpcion> rutas;
  final Alerta? editar;
  final int? rutaFijada;

  @override
  State<_FormularioAlerta> createState() => _FormularioAlertaState();
}

class _FormularioAlertaState extends State<_FormularioAlerta> {
  final TextEditingController _descripcion = TextEditingController();
  int? _ruta;
  String? _tipo;
  String? _error;
  bool _enviando = false;
  int _pedido = 0;

  // Ubicación (solo al crear): las rutas son las que pasan a 500 m de quien reporta
  LatLng? _yo;
  String _textoUbicacion = 'Buscando tu ubicación…';
  List<RutaOpcion>? _cercanas;
  bool _buscandoRutas = false;
  String _ayudaRuta = '';

  bool get _crear => widget.editar == null;

  @override
  void initState() {
    super.initState();
    final e = widget.editar;
    if (e != null) {
      _ruta = e.rutaId;
      _tipo = e.tipo;
      _descripcion.text = e.descripcion;
    } else {
      if (widget.rutaFijada != null && widget.rutas.any((r) => r.id == widget.rutaFijada)) _ruta = widget.rutaFijada;
      _pedirUbicacion();
    }
    _descripcion.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _descripcion.dispose();
    super.dispose();
  }

  String _nombreRuta(int? id) => widget.rutas.where((r) => r.id == id).firstOrNull?.etiqueta ?? 'en el mapa';

  Future<void> _pedirUbicacion() async {
    setState(() {
      _buscandoRutas = true;
      _ayudaRuta = 'Estamos buscando las rutas que pasan cerca de ti.';
      _textoUbicacion = 'Buscando tu ubicación…';
    });
    try {
      final yo = await Ubicacion.obtener();
      if (!mounted) return;
      _yo = yo;
      setState(() => _textoUbicacion =
          'Ubicación lista: se enviará con tu alerta y sirve para detectar si ya la reportaron cerca.');
      final d = await Api.get('alertas/rutas-cercanas/',
          q: {'latitud': yo.latitude.toStringAsFixed(6), 'longitud': yo.longitude.toStringAsFixed(6)});
      if (!mounted) return;
      final lista = (d['rutas'] as List? ?? []).map((r) => RutaOpcion.fromJson(r as Map<String, dynamic>)).toList();
      final fijada = widget.rutaFijada;
      final enRango = fijada != null && lista.any((r) => r.id == fijada);
      setState(() {
        _cercanas = lista;
        _buscandoRutas = false;
        _ruta = enRango ? fijada : (lista.any((r) => r.id == _ruta) ? _ruta : null);
        _ayudaRuta = lista.isEmpty
            ? 'Ninguna ruta pasa a 500 m o menos de ti. Acércate al trazado de una ruta para reportarla.'
            : fijada != null && !enRango
                ? 'La ruta que fijaste (${_nombreRuta(fijada)}) no pasa a 500 m de ti. Elige una de las que sí.'
                : 'Estas son las rutas que pasan a 500 metros o menos de tu ubicación.';
      });
      _buscarRepetida();
    } on UbicacionError {
      if (!mounted) return;
      setState(() {
        _textoUbicacion =
            'No pudimos ver tu ubicación. Puedes enviar la alerta igual, pero sin ella no sabremos si ya la reportaron cerca.';
        _cercanas = null;
        _buscandoRutas = false;
        _ayudaRuta = '';
      });
    } on ApiError {
      if (!mounted) return;
      setState(() {
        _cercanas = null;
        _buscandoRutas = false;
        _ayudaRuta = '';
      });
    }
  }

  /// ¿Ya hay una alerta igual cerca? Sin ubicación también se pregunta: las de la empresa valen para toda la ruta.
  Future<void> _buscarRepetida() async {
    if (!_crear || _ruta == null || _tipo == null || _buscandoRutas) return;
    final pedido = ++_pedido;
    try {
      final d = await Api.get('alertas/cercana/', q: {
        'ruta': '$_ruta',
        'tipo': _tipo!,
        if (_yo != null) 'latitud': _yo!.latitude.toStringAsFixed(6),
        if (_yo != null) 'longitud': _yo!.longitude.toStringAsFixed(6),
      });
      if (!mounted || pedido != _pedido || d['existe'] != true) return;
      final respuesta = await mostrarModal<Object>(
        context,
        titulo: 'Ya existe una alerta igual',
        contenido: (c) => _AvisoRepetida(datos: d, ruta: _ruta!, tipo: _tipo!, yo: _yo),
      );
      if (!mounted) return;
      if (respuesta == 'descartar') {
        Navigator.of(context).pop();
      } else if (respuesta is Map<String, dynamic>) {
        Navigator.of(context).pop(respuesta);
      }
    } on ApiError {
      // Sin aviso: el reporte se puede enviar igual
    }
  }

  Future<void> _enviar() async {
    final descripcion = _descripcion.text.trim();
    if (_ruta == null || _tipo == null || descripcion.isEmpty) {
      setState(() => _error = _ruta == null
          ? 'Elige la ruta de la alerta.'
          : _tipo == null
              ? 'Elige el tipo de alerta.'
              : 'Escribe la descripción de la alerta.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final datos = <String, dynamic>{'ruta': _ruta, 'tipo': _tipo, 'descripcion': descripcion};
      if (_crear && _yo != null) {
        datos['latitud'] = _yo!.latitude.toStringAsFixed(6);
        datos['longitud'] = _yo!.longitude.toStringAsFixed(6);
      }
      final d = await Api.post(_crear ? 'alertas/crear/' : 'alertas/${widget.editar!.id}/editar/', datos);
      if (mounted) Navigator.of(context).pop(d);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _error = e.mensaje;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    final opciones = _crear && _cercanas != null ? _cercanas! : widget.rutas;
    final largo = _descripcion.text.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) LbNota.error(context, _error!),
        const LbNota('Tu alerta quedará pendiente hasta que la empresa de la ruta la revise. Después se publicará en el mapa.'),
        if (_crear) LbNota(_textoUbicacion),
        LbSelect<int>(
          etiqueta: 'Ruta',
          valor: _ruta,
          habilitado: !_buscandoRutas,
          error: _error != null && _ruta == null,
          opciones: [
            (
              null,
              _buscandoRutas
                  ? 'Buscando rutas cerca de ti…'
                  : opciones.isEmpty && _cercanas != null
                      ? 'No hay rutas a 500 m de ti'
                      : 'Elige una ruta'
            ),
            for (final r in opciones) (r.id, r.etiqueta),
          ],
          ayuda: _crear ? _ayudaRuta : null,
          onChanged: (v) {
            setState(() => _ruta = v);
            _buscarRepetida();
          },
        ),
        LbSelect<String>(
          etiqueta: 'Tipo de alerta',
          valor: _tipo,
          error: _error != null && _tipo == null,
          opciones: const [(null, 'Elige un tipo'), ('delay', 'Demora'), ('warning', 'Advertencia'), ('info', 'Información')],
          onChanged: (v) {
            setState(() => _tipo = v);
            _buscarRepetida();
          },
        ),
        const LbEtiqueta('Descripción'),
        TextField(
          controller: _descripcion,
          maxLength: 200,
          minLines: 4,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(fontSize: 16, height: 1.35, color: lb.tinta),
          decoration: const InputDecoration(
            hintText: 'Cuenta qué pasa y qué deben hacer los pasajeros',
            counterText: '',
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 16),
          child: Text(
            '$largo de 200 caracteres',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12.5,
              color: largo >= 180 ? lb.rojoInterfaz : lb.grisTexto,
              fontWeight: largo >= 180 ? FontWeight.w700 : FontWeight.w400,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        LbAcciones(botones: [
          LbBoton('Cancelar', estilo: EstiloBoton.secundario, onPressed: () => Navigator.of(context).pop()),
          LbBoton(_crear ? 'Crear alerta' : 'Guardar cambios', cargando: _enviando, onPressed: _enviar),
        ]),
      ],
    );
  }
}

/// Ya hay una alerta igual cerca: «Yo también lo veo», escribir otro reporte o descartar el propio.
class _AvisoRepetida extends StatefulWidget {
  const _AvisoRepetida({required this.datos, required this.ruta, required this.tipo, required this.yo});

  final Map<String, dynamic> datos;
  final int ruta;
  final String tipo;
  final LatLng? yo;

  @override
  State<_AvisoRepetida> createState() => _AvisoRepetidaState();
}

class _AvisoRepetidaState extends State<_AvisoRepetida> {
  bool _enviando = false;
  String? _error;

  Future<void> _sumarse() async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final d = await Api.post('alertas/sumarse/', {
        'ruta': widget.ruta,
        'tipo': widget.tipo,
        if (widget.yo != null) 'latitud': widget.yo!.latitude.toStringAsFixed(6),
        if (widget.yo != null) 'longitud': widget.yo!.longitude.toStringAsFixed(6),
      });
      if (mounted) Navigator.of(context).pop(d);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _error = e.mensaje;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    final d = widget.datos;
    final donde = d['de_empresa'] == true
        ? 'La empresa ya publicó una alerta de este mismo tipo para esta ruta'
        : 'Ya hay una alerta de este mismo tipo para esta ruta a menos de 700 m de ti';
    final reportes = (d['reportes'] as num?)?.toInt() ?? 1;
    final texto = '$donde${d['publica'] == true ? '.' : ', y la empresa aún la está revisando.'}'
        '${reportes > 1 ? ' La reportaron $reportes personas.' : ''}';
    final descripcion = d['publica'] == true ? '${d['descripcion'] ?? ''}' : '';
    final yaReportaste = d['ya_reportaste'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) LbNota.error(context, _error!),
        Text(texto, style: TextStyle(fontSize: 15.5, height: 1.45, color: lb.tinta)),
        if (descripcion.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: lb.linea, width: 4))),
            child: Text('«$descripcion»', style: TextStyle(fontStyle: FontStyle.italic, color: lb.tinta, height: 1.4)),
          )
        else
          const SizedBox(height: 12),
        LbNota(yaReportaste
            ? 'Ya reportaste este problema: tu reporte sigue contando. No hace falta enviarlo otra vez.'
            : 'Si es el mismo problema, confírmalo con un clic: cuenta igual que un reporte y la empresa lo ve antes.'),
        LbAcciones(apiladas: true, botones: [
          if (!yaReportaste)
            LbBoton(_enviando ? 'Enviando…' : 'Yo también lo veo', cargando: _enviando, onPressed: _sumarse),
          LbBoton('Es otro problema: escribir mi reporte',
              estilo: EstiloBoton.secundario, onPressed: () => Navigator.of(context).pop()),
          LbBoton('Descartar mi reporte', estilo: EstiloBoton.texto, onPressed: () => Navigator.of(context).pop('descartar')),
        ]),
      ],
    );
  }
}

// ================= RUTAS QUE SIGO =================

class _SeguirRutas extends StatefulWidget {
  const _SeguirRutas({required this.rutas, required this.seguidas});
  final List<RutaOpcion> rutas;
  final Set<int> seguidas;

  @override
  State<_SeguirRutas> createState() => _SeguirRutasState();
}

class _SeguirRutasState extends State<_SeguirRutas> {
  late final Set<int> _elegidas = {...widget.seguidas};
  bool _enviando = false;
  String? _error;

  Future<void> _guardar() async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final d = await Api.post('alertas/seguir/', {'rutas': _elegidas.toList()});
      if (mounted) Navigator.of(context).pop(d);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _error = e.mensaje;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) LbNota.error(context, _error!),
        const LbNota('Te avisaremos solo de las alertas de estas rutas. Si no eliges ninguna, te avisamos de todas.'),
        Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
          decoration: BoxDecoration(border: Border.all(color: lb.linea)),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final r in widget.rutas)
                CheckboxListTile(
                  value: _elegidas.contains(r.id),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (v) => setState(() => v == true ? _elegidas.add(r.id) : _elegidas.remove(r.id)),
                  title: Row(children: [
                    PlacaRuta(codigo: r.codigo, color: r.color, size: 14),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r.nombre, style: TextStyle(fontSize: 14.5, color: lb.tinta))),
                  ]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LbAcciones(botones: [
          LbBoton('Cancelar', estilo: EstiloBoton.secundario, onPressed: () => Navigator.of(context).pop()),
          LbBoton('Guardar', cargando: _enviando, onPressed: _guardar),
        ]),
      ],
    );
  }
}
