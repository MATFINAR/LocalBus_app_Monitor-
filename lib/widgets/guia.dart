import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/navegacion.dart';
import '../theme/app_theme.dart';
import 'lb.dart';

/// Un paso del tour (como cada <section> de la guía de la web). Sin [clave] sale centrado, sin resaltar nada.
class PasoGuia {
  const PasoGuia(this.titulo, this.texto, [this.clave]);

  final String titulo;
  final String texto;

  /// Lo que se resalta. Si ahora no está en pantalla (vacío, otra vista, otro rol), el paso se salta.
  final GlobalKey? clave;
}

/// Claves de los elementos que señala el tour de una pantalla, por nombre.
class ClavesGuia {
  final Map<String, GlobalKey> _claves = {};

  GlobalKey operator [](String nombre) => _claves.putIfAbsent(nombre, () => GlobalKey(debugLabel: nombre));

  /// Marca [hijo] como el elemento [nombre].
  Widget marcar(String nombre, Widget hijo) => KeyedSubtree(key: this[nombre], child: hijo);
}

/// Botón «Guía» de cada vista (guia.js). La primera vez que se visita la vista, el tour empieza solo.
class BotonGuia extends StatefulWidget {
  const BotonGuia({
    super.key,
    required this.id,
    required this.titulo,
    required this.pestana,
    required this.pasos,
    this.lista = true,
    this.alEmpezar,
  });

  /// Nombre con el que se recuerda que el tour ya se mostró.
  final String id;
  final String titulo;

  /// Pestaña de la barra inferior donde vive la vista.
  final int pestana;
  final List<PasoGuia> Function() pasos;

  /// Los datos de la vista ya cargaron: antes no se empieza solo, para no saltarse pasos.
  final bool lista;

  /// Antes de empezar (por ejemplo, volver al principio de la lista).
  final VoidCallback? alEmpezar;

  /// El tour automático de la primera visita. Las pruebas de otras cosas lo apagan.
  @visibleForTesting
  static bool automatico = true;

  @override
  State<BotonGuia> createState() => _BotonGuiaState();
}

class _BotonGuiaState extends State<BotonGuia> {
  static bool _abierta = false;
  Timer? _espera;
  bool _vista = false;

  @override
  void initState() {
    super.initState();
    Navegacion.pestana.addListener(_programar);
    _programar();
  }

  @override
  void didUpdateWidget(BotonGuia anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.lista != widget.lista || anterior.id != widget.id) _programar();
  }

  @override
  void dispose() {
    _espera?.cancel();
    Navegacion.pestana.removeListener(_programar);
    super.dispose();
  }

  bool get _aLaVista =>
      mounted &&
      widget.lista &&
      Navegacion.pestana.value == widget.pestana &&
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      !Navigator.of(context, rootNavigator: true).canPop(); // sin ventanas encima

  /// Primera visita: se espera un momento a que la pantalla termine de dibujarse.
  void _programar() {
    _espera?.cancel();
    if (!BotonGuia.automatico || _vista || !widget.lista || Navegacion.pestana.value != widget.pestana) return;
    _espera = Timer(const Duration(milliseconds: 900), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('guia_${widget.id}') ?? false) {
          _vista = true;
          return;
        }
      } catch (_) {
        return; // sin almacenamiento no se sabe si ya se mostró: queda el botón
      }
      if (_aLaVista) _empezar();
    });
  }

  Future<void> _empezar() async {
    if (_abierta || !mounted) return;
    _abierta = true;
    _vista = true;
    try {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('guia_${widget.id}', true);
      } catch (_) {}
      if (!mounted) return;
      widget.alEmpezar?.call();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final pasos = [
        for (final p in widget.pasos())
          if (p.clave == null || _seVe(p.clave!)) p,
      ];
      if (pasos.isEmpty) return;
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 200),
        transitionBuilder: (context, animacion, _, hijo) => FadeTransition(opacity: animacion, child: hijo),
        pageBuilder: (context, _, _) => _Tour(titulo: widget.titulo, pasos: pasos),
      );
    } finally {
      _abierta = false;
    }
  }

  static bool _seVe(GlobalKey clave) {
    final caja = clave.currentContext?.findRenderObject();
    return caja is RenderBox && caja.attached && caja.hasSize && !caja.size.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return Semantics(
      button: true,
      label: '${widget.titulo}: recorrido por lo que hay en esta pantalla',
      excludeSemantics: true,
      onTap: _empezar,
      child: OutlinedButton.icon(
        onPressed: _empezar,
        style: OutlinedButton.styleFrom(
          backgroundColor: lb.blanco,
          foregroundColor: lb.tinta,
          side: BorderSide(color: lb.tinta),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radio)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(48, 40),
        ),
        icon: const Icon(Icons.help_outline, size: 18),
        label: const Text('Guía', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }
}

/// El recorrido: oscurece la pantalla, resalta el elemento del paso y muestra el globo con la explicación.
class _Tour extends StatefulWidget {
  const _Tour({required this.titulo, required this.pasos});

  final String titulo;
  final List<PasoGuia> pasos;

  @override
  State<_Tour> createState() => _TourState();
}

class _TourState extends State<_Tour> {
  int _actual = 0;
  Rect? _foco;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ir(0));
  }

  Future<void> _ir(int indice) async {
    if (!mounted) return;
    setState(() => _actual = indice);
    final contexto = widget.pasos[indice].clave?.currentContext;
    if (contexto != null) {
      // Se trae a la vista lo que se va a señalar
      await Scrollable.ensureVisible(contexto,
          alignment: 0.15,
          duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 300));
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted || _actual != indice) return;
    setState(() => _foco = _medir(widget.pasos[indice].clave));
  }

  Rect? _medir(GlobalKey? clave) {
    final caja = clave?.currentContext?.findRenderObject();
    if (caja is! RenderBox || !caja.attached) return null;
    final pantalla = Offset.zero & MediaQuery.of(context).size;
    final rect = (caja.localToGlobal(Offset.zero) & caja.size).inflate(6).intersect(pantalla.deflate(4));
    return rect.width <= 0 || rect.height <= 0 ? null : rect;
  }

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    final paso = widget.pasos[_actual];
    final total = widget.pasos.length;
    final ultimo = _actual == total - 1;
    final medidas = MediaQuery.of(context);
    final foco = _foco;

    // El globo va abajo, o arriba si lo señalado está en la mitad de abajo
    final Alignment lugar = foco == null
        ? Alignment.center
        : foco.center.dy > medidas.size.height / 2 && foco.top > medidas.size.height * 0.35
            ? Alignment.topCenter
            : Alignment.bottomCenter;

    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _Sombra(foco, lb.amarillo))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: lugar,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 480, maxHeight: math.max(220, medidas.size.height * 0.5)),
                child: Material(
                  color: lb.blanco,
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radioVentana)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Semantics(
                              liveRegion: true,
                              child: Text('${widget.titulo} · Paso ${_actual + 1} de $total',
                                  style: TextStyle(fontSize: 12.8, color: lb.grisTexto)),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Salir de la guía',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close, size: 20, color: lb.grisTexto),
                          ),
                        ]),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                    header: true,
                                    child: Text(paso.titulo, style: AppTheme.titulo(size: 22, color: lb.tinta))),
                                const SizedBox(height: 6),
                                Text(paso.texto, style: TextStyle(fontSize: 15, height: 1.45, color: lb.tinta)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                            value: (_actual + 1) / total, minHeight: 3, color: lb.azul, backgroundColor: lb.linea),
                        const SizedBox(height: 10),
                        LbAcciones(botones: [
                          LbBoton('Anterior',
                              estilo: EstiloBoton.secundario, onPressed: _actual == 0 ? null : () => _ir(_actual - 1)),
                          LbBoton(ultimo ? 'Terminar' : 'Siguiente',
                              onPressed: ultimo ? () => Navigator.of(context).pop() : () => _ir(_actual + 1)),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Fondo oscuro con un hueco sobre lo señalado.
class _Sombra extends CustomPainter {
  _Sombra(this.foco, this.borde);
  final Rect? foco;
  final Color borde;

  @override
  void paint(Canvas canvas, Size size) {
    final todo = Path()..addRect(Offset.zero & size);
    final hueco = foco == null ? null : RRect.fromRectAndRadius(foco!, const Radius.circular(6));
    canvas.drawPath(
      hueco == null ? todo : Path.combine(PathOperation.difference, todo, Path()..addRRect(hueco)),
      Paint()..color = const Color(0xB3080707),
    );
    if (hueco != null) {
      canvas.drawRRect(
          hueco,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = borde);
    }
  }

  @override
  bool shouldRepaint(_Sombra anterior) => anterior.foco != foco || anterior.borde != borde;
}
