import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api.dart';
import '../services/navegacion.dart';
import '../services/server_config.dart';
import '../theme/app_theme.dart';
import '../widgets/lb.dart';
import '../widgets/servidor_dialog.dart';

/// Acerca de (acerca_de.html): presentación animada por escenas, cifras reales de la red y quiénes somos.
class AcercaScreen extends StatefulWidget {
  const AcercaScreen({super.key});

  @override
  State<AcercaScreen> createState() => _AcercaScreenState();
}

class _AcercaScreenState extends State<AcercaScreen> {
  Map<String, dynamic>? _cifras;
  String _contacto = '';

  @override
  void initState() {
    super.initState();
    _cargar();
    ServerConfig.cambios.addListener(_cargar);
    Navegacion.pestana.addListener(_alVolver);
  }

  @override
  void dispose() {
    ServerConfig.cambios.removeListener(_cargar);
    Navegacion.pestana.removeListener(_alVolver);
    super.dispose();
  }

  void _alVolver() {
    if (Navegacion.pestana.value == Navegacion.acerca) _cargar();
  }

  Future<void> _cargar() async {
    try {
      final d = await Api.get('acerca/');
      if (!mounted) return;
      setState(() {
        _cifras = d['cifras'] as Map<String, dynamic>?;
        _contacto = '${d['contacto_email'] ?? ''}';
      });
    } on ApiError {
      // Sin conexión: las cifras quedan en «—»
    }
  }

  String _cifra(String clave) => _cifras == null ? '—' : '${_cifras![clave] ?? 0}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Semantics(header: true, child: const SizedBox.shrink(), label: 'Acerca de LocalBus'),
            _Presentacion(cifras: _cifras),
            _Seccion(
              titulo: 'LocalBus hoy',
              subtitulo: 'Cifras reales, en este momento.',
              hijo: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.7,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  _Cifra('Empresas de transporte', _cifra('empresas')),
                  _Cifra('Rutas', _cifra('rutas')),
                  _Cifra('Buses', _cifra('buses')),
                  _Cifra('Buses en el mapa ahora', _cifra('en_vivo'), viva: true),
                ],
              ),
            ),
            _Seccion(
              titulo: 'Por qué existe',
              hijo: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _Parrafo('Todos hemos esperado un bus sin saber si ya pasó, si viene retrasado o si ese día no está '
                      'circulando. Ese tiempo perdido se repite todos los días para miles de personas.'),
                  _Parrafo('Las empresas de transporte saben dónde están sus buses, pero esa información casi nunca le '
                      'llega a quien los espera. LocalBus la pone a la vista de todos, en un mapa sencillo y gratuito.'),
                  _Parrafo('Y el beneficio va más allá de cada viaje: un transporte público en el que se puede confiar es '
                      'una mejor opción para moverse por la ciudad, y eso ayuda a que todos nos movamos mejor.'),
                ],
              ),
            ),
            _Seccion(
              titulo: 'Para quién es',
              hijo: Column(children: const [
                _Tarjeta('Para quienes viajan en bus',
                    'Ves tu ruta y sus buses en el mapa, y te enteras de demoras o cambios antes de salir de casa. No necesitas registrarte para usarlo.'),
                _Tarjeta('Para las empresas de transporte',
                    'Muestran sus rutas y sus buses en un solo lugar, y avisan a sus pasajeros cuando hay una novedad.'),
                _Tarjeta('Para la movilidad de la ciudad',
                    'Cuando saber cuándo llega el bus es fácil, más personas eligen el transporte público. Eso significa menos esperas, menos carros en la calle y una ciudad que se mueve mejor para todos.',
                    destacada: true),
              ]),
            ),
            _Seccion(
              titulo: 'Lo que nos importa',
              hijo: Column(children: [
                const _Principio('Que lo que ves sea cierto',
                    'Solo mostramos los buses que están recorriendo su ruta en este momento. Si un bus deja de reportar dónde está, lo quitamos del mapa para no confundirte.'),
                const _Principio('Que sea fácil',
                    'Funciona desde el navegador de tu celular o tu computador, sin instalar nada y sin pasos complicados.'),
                const _Principio('Que estés al tanto',
                    'Cuando una ruta tiene un problema, como obras, un cierre o una demora, te avisamos para que puedas organizarte.'),
                _Principio('Que tus datos estén cuidados', 'Usamos tu información solo para que el servicio funcione. Lo explicamos en la ',
                    enlace: 'política de privacidad', alEnlace: () => abrirWeb('/privacidad/')),
              ]),
            ),
            _Seccion(
              titulo: 'Equipo',
              subtitulo: 'Las personas detrás de LocalBus.',
              hijo: Column(children: const [
                _Persona('JH', 'Juan José Higuita', 'Analista', 'Le da forma a la idea y a lo que el servicio debe resolver.'),
                _Persona('MT', 'Miguel Ángel Taborda', 'Desarrollador principal', 'Construye LocalBus y lo mantiene funcionando.'),
                _Persona('AV', 'Alejandro Vasco', 'Diseñador', 'Se asegura de que sea claro y fácil de usar.'),
              ]),
            ),
            // Contacto (.ac-contacto, siempre oscuro)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              color: const Color(0xFF080707),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('¿Tienes una empresa de transporte o una sugerencia?',
                      style: AppTheme.titulo(size: 25, color: Colors.white, height: 1.15)),
                  const SizedBox(height: 10),
                  if (_contacto.isNotEmpty)
                    Wrap(children: [
                      const Text('Escríbenos a ', style: TextStyle(color: Color(0xFFD5DADD), height: 1.5)),
                      GestureDetector(
                        onTap: () => launchUrl(Uri(scheme: 'mailto', path: _contacto)),
                        child: Text(_contacto,
                            style: const TextStyle(
                                color: Colors.white, decoration: TextDecoration.underline, height: 1.5)),
                      ),
                      const Text('. Nos encantará saber de ti.', style: TextStyle(color: Color(0xFFD5DADD), height: 1.5)),
                    ])
                  else
                    const Text('Usa los datos de contacto del pie de página. Nos encantará saber de ti.',
                        style: TextStyle(color: Color(0xFFD5DADD), height: 1.5)),
                  const SizedBox(height: 12),
                  const Text('LocalBus · Medellín y su área metropolitana',
                      style: TextStyle(color: Color(0xFF9AA3AA), fontSize: 13)),
                ],
              ),
            ),
            const _Pie(),
            const _Servidor(),
          ],
        ),
      ),
    );
  }
}

/// Dirección del servidor, al final de la pantalla. Mantenerla presionada 15 segundos permite cambiarla.
class _Servidor extends StatelessWidget {
  const _Servidor();

  static const _espera = Duration(seconds: 15);

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(duration: _espera),
          (r) => r.onLongPress = () {
            HapticFeedback.mediumImpact();
            mostrarDialogoServidor(context);
          },
        ),
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: ValueListenableBuilder<int>(
          valueListenable: ServerConfig.cambios,
          builder: (context, _, _) => Text('Servidor: ${ServerConfig.url}',
              style: TextStyle(fontSize: 11.5, color: context.lb.grisTexto)),
        ),
      ),
    );
  }
}

/// Abre una página de la web de LocalBus (términos, privacidad) en el navegador.
Future<void> abrirWeb(String ruta) async {
  await launchUrl(Api.web(ruta), mode: LaunchMode.externalApplication);
}

// ================= SECCIONES =================

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, this.subtitulo, required this.hijo});
  final String titulo;
  final String? subtitulo;
  final Widget hijo;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 10),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: lb.tinta, width: 2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(header: true, child: Text(titulo, style: AppTheme.titulo(size: 28, color: lb.tinta))),
              if (subtitulo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(subtitulo!, style: TextStyle(color: lb.grisTexto, fontSize: 15)),
                ),
            ]),
          ),
          hijo,
        ],
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra(this.etiqueta, this.valor, {this.viva = false});
  final String etiqueta;
  final String valor;
  final bool viva;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: lb.concreto,
        border: Border(left: BorderSide(color: viva ? lb.verde : lb.tinta, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(etiqueta, maxLines: 2, style: TextStyle(fontSize: 12.8, color: lb.grisTexto, height: 1.2)),
          const SizedBox(height: 2),
          Text(valor, style: AppTheme.titulo(size: 34, color: viva ? lb.verde : lb.tinta, height: 1)),
        ],
      ),
    );
  }
}

class _Parrafo extends StatelessWidget {
  const _Parrafo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(texto, style: TextStyle(fontSize: 16, height: 1.6, color: context.lb.tinta)),
      );
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta(this.titulo, this.texto, {this.destacada = false});
  final String titulo;
  final String texto;
  final bool destacada;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: destacada ? lb.azulClaro : lb.blanco,
        border: Border.all(color: destacada ? lb.azul : lb.linea),
        borderRadius: BorderRadius.circular(AppTheme.radio),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: AppTheme.titulo(size: 20, color: lb.tinta)),
        const SizedBox(height: 6),
        Text(texto, style: TextStyle(fontSize: 15, height: 1.5, color: lb.tinta)),
      ]),
    );
  }
}

class _Principio extends StatelessWidget {
  const _Principio(this.titulo, this.texto, {this.enlace, this.alEnlace});
  final String titulo;
  final String texto;
  final String? enlace;
  final VoidCallback? alEnlace;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: lb.linea))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 4, height: 22, margin: const EdgeInsets.only(right: 12, top: 1), color: lb.rojo),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: AppTheme.titulo(size: 19, color: lb.tinta)),
            const SizedBox(height: 4),
            Wrap(children: [
              Text(texto, style: TextStyle(fontSize: 15, height: 1.5, color: lb.tinta)),
              if (enlace != null)
                GestureDetector(
                  onTap: alEnlace,
                  child: Text('$enlace.',
                      style: TextStyle(fontSize: 15, height: 1.5, color: lb.azul, decoration: TextDecoration.underline)),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Persona extends StatelessWidget {
  const _Persona(this.iniciales, this.nombre, this.rol, this.texto);
  final String iniciales;
  final String nombre;
  final String rol;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: lb.tinta, borderRadius: BorderRadius.circular(AppTheme.radio)),
          child: Text(iniciales, style: AppTheme.titulo(size: 22, color: lb.blanco, height: 1)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre, style: AppTheme.titulo(size: 19, color: lb.tinta)),
            Text(rol.toUpperCase(),
                style: AppTheme.titulo(size: 13, color: lb.rojoInterfaz).copyWith(letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Text(texto, style: TextStyle(fontSize: 15, height: 1.45, color: lb.tinta)),
          ]),
        ),
      ]),
    );
  }
}

/// Pie de la web (footer de base.html): enlaces rápidos, legales y contacto.
class _Pie extends StatelessWidget {
  const _Pie();

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    Widget enlace(String texto, VoidCallback alTocar) => InkWell(
          onTap: alTocar,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(texto, style: TextStyle(color: lb.tinta, decoration: TextDecoration.underline, fontSize: 15)),
          ),
        );
    Widget titulo(String t) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Text(t, style: AppTheme.titulo(size: 19, color: lb.tinta)),
        );

    return Container(
      margin: const EdgeInsets.only(top: 28),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: lb.linea))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titulo('LocalBus'),
          Text('Transformando la movilidad urbana con tecnología de última generación.',
              style: TextStyle(color: lb.grisTexto, height: 1.5)),
          titulo('Enlaces rápidos'),
          enlace('Ver el mapa en vivo', () => Navegacion.ir(Navegacion.mapa)),
          enlace('Buscar una ruta', () => Navegacion.ir(Navegacion.rutas)),
          enlace('Centro de alertas', () => Navegacion.ir(Navegacion.alertas)),
          enlace('Términos y condiciones', () => abrirWeb('/terminos/')),
          enlace('Política de privacidad', () => abrirWeb('/privacidad/')),
          titulo('Contacto'),
          Row(children: [
            Text('Teléfono  ', style: TextStyle(color: lb.grisTexto, fontSize: 13)),
            enlace('+57 (1) 234 5678', () => launchUrl(Uri(scheme: 'tel', path: '+571234567890'))),
          ]),
          Row(children: [
            Text('Correo  ', style: TextStyle(color: lb.grisTexto, fontSize: 13)),
            Flexible(
                child: enlace('correoLocalbus@gmail.com',
                    () => launchUrl(Uri(scheme: 'mailto', path: 'correoLocalbus@gmail.com')))),
          ]),
          const SizedBox(height: 16),
          Text('© ${DateTime.now().year} LocalBus - Sistema de Localización en Tiempo Real',
              style: TextStyle(color: lb.grisTexto, fontSize: 12.5)),
        ],
      ),
    );
  }
}

// ================= PRESENTACIÓN (VIDEO POR ESCENAS) =================

const _negro = Color(0xFF080707);
const _rojo = Color(0xFFFE151E);
const _amarillo = Color(0xFFF7C600);
const _gris = Color(0xFFB5BCC1);

class _Presentacion extends StatefulWidget {
  const _Presentacion({required this.cifras});
  final Map<String, dynamic>? cifras;

  @override
  State<_Presentacion> createState() => _PresentacionState();
}

class _PresentacionState extends State<_Presentacion> with TickerProviderStateMixin {
  static const _escenas = 8;
  static const _nombres = [
    'la espera', 'el problema', 'LocalBus', 'elige tu ruta', 'míralo llegar', 'novedades', 'la ciudad', 'cierre'
  ];
  late final AnimationController _avance = AnimationController(vsync: this, duration: const Duration(milliseconds: 4800))
    ..addStatusListener(_alTerminar);
  int _escena = 0;
  bool _pausado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _pausado = true;
      _avance.value = 1;
    } else if (!_avance.isAnimating && !_pausado) {
      _avance.forward();
    }
  }

  void _alTerminar(AnimationStatus s) {
    if (s != AnimationStatus.completed || _pausado) return;
    if (_escena < _escenas - 1) {
      _ir(_escena + 1);
    } else {
      setState(() => _pausado = true);
    }
  }

  void _ir(int escena) {
    setState(() => _escena = escena);
    _avance.forward(from: 0);
    if (_pausado) _avance.stop();
  }

  void _alternar() {
    setState(() => _pausado = !_pausado);
    if (_pausado) {
      _avance.stop();
    } else if (_escena == _escenas - 1 && _avance.isCompleted) {
      _ir(0);
    } else {
      _avance.forward();
    }
  }

  @override
  void dispose() {
    _avance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Presentación de LocalBus',
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 0.86,
            child: Container(
              color: _negro,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: curvaSuave,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(a), child: child),
                ),
                child: KeyedSubtree(key: ValueKey(_escena), child: _escenaActual()),
              ),
            ),
          ),
          Container(
            color: _negro,
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: _pausado ? 'Reproducir la presentación' : 'Pausar la presentación',
                  onPressed: _alternar,
                  icon: Icon(_pausado ? Icons.play_arrow_rounded : Icons.pause_rounded, color: Colors.white),
                ),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _avance,
                    builder: (context, _) => Row(
                      children: [
                        for (var i = 0; i < _escenas; i++)
                          Expanded(
                            child: Semantics(
                              button: true,
                              label: 'Escena ${i + 1}: ${_nombres[i]}',
                              child: InkWell(
                                onTap: () => _ir(i),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 14),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      minHeight: 4,
                                      value: i < _escena ? 1 : i == _escena ? _avance.value : 0,
                                      color: Colors.white,
                                      backgroundColor: const Color(0x4DFFFFFF),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Ver otra vez desde el inicio',
                  onPressed: () {
                    setState(() => _pausado = false);
                    _ir(0);
                  },
                  icon: const Icon(Icons.replay_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _escenaActual() {
    final c = widget.cifras;
    String n(String k) => c == null ? '—' : '${c[k] ?? 0}';
    return switch (_escena) {
      0 => _EscenaEspera(avance: _avance),
      1 => _EscenaProblema(avance: _avance),
      2 => const _EscenaMarca(),
      3 => _EscenaPaso(
          paso: '1',
          titulo: 'Elige tu ruta',
          detalle: 'Búscala por su nombre, o mira las que pasan cerca de ti.',
          visual: _ListaRutas(avance: _avance)),
      4 => _EscenaPaso(
          paso: '2',
          titulo: 'Míralo llegar, en vivo',
          detalle: 'El bus se mueve en el mapa mientras recorre su ruta.',
          visual: _MapaVivo(avance: _avance)),
      5 => _EscenaPaso(
          paso: '3',
          titulo: 'Entérate de cualquier novedad',
          detalle: 'Si hay obras, un desvío o una demora, te avisamos.',
          visual: _Avisos(avance: _avance)),
      6 => _Centro(children: [
          Text('Menos espera.\nMás ciudad.',
              textAlign: TextAlign.center, style: AppTheme.titulo(size: 46, color: Colors.white, height: 1.05)),
          const SizedBox(height: 24),
          Wrap(spacing: 18, runSpacing: 10, alignment: WrapAlignment.center, children: [
            _CifraVideo(n('rutas'), 'rutas'),
            _CifraVideo(n('empresas'), 'empresas de transporte'),
            _CifraVideo(n('buses'), 'buses'),
          ]),
        ]),
      _ => _Centro(children: [
          const _Marca(size: 44),
          const SizedBox(height: 10),
          const Text('Sabe dónde viene tu bus antes de salir.',
              textAlign: TextAlign.center, style: TextStyle(color: _gris, fontSize: 17, height: 1.4)),
          const SizedBox(height: 22),
          Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
            FilledButton(
              onPressed: () => Navegacion.ir(Navegacion.mapa),
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _negro),
              child: const Text('Ver el mapa'),
            ),
            OutlinedButton(
              onPressed: () => Navegacion.ir(Navegacion.rutas),
              style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white)),
              child: const Text('Ver las rutas'),
            ),
          ]),
        ]),
    };
  }
}

class _Centro extends StatelessWidget {
  const _Centro({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: children)),
      );
}

class _Marca extends StatelessWidget {
  const _Marca({this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: const [
          TextSpan(text: 'Local', style: TextStyle(color: Colors.white)),
          TextSpan(text: 'Bus', style: TextStyle(color: _rojo)),
        ]),
        style: AppTheme.titulo(size: size, height: 1),
      );
}

class _CifraVideo extends StatelessWidget {
  const _CifraVideo(this.numero, this.texto);
  final String numero;
  final String texto;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(text: numero, style: AppTheme.titulo(size: 26, color: _amarillo)),
          TextSpan(text: ' $texto', style: const TextStyle(color: _gris, fontSize: 14)),
        ]),
      );
}

class _EscenaEspera extends StatelessWidget {
  const _EscenaEspera({required this.avance});
  final Animation<double> avance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: avance,
      builder: (context, _) {
        final t = avance.value;
        return _Centro(children: [
          const Text('7:12 a. m.', style: TextStyle(color: _gris, fontSize: 16, letterSpacing: 1)),
          const SizedBox(height: 20),
          SizedBox(
            height: 130,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              // Poste del paradero
              Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: _amarillo,
                  child: Text('BUS', style: AppTheme.titulo(size: 16, color: _negro, height: 1)),
                ),
                Container(width: 4, height: 96, color: _gris),
              ]),
              const SizedBox(width: 26),
              // Persona esperando y el reloj que gira
              Column(mainAxisSize: MainAxisSize.min, children: [
                Opacity(
                  opacity: (t * 3).clamp(0.0, 1.0),
                  child: Text('?  ?  ?', style: AppTheme.titulo(size: 22, color: _amarillo)),
                ),
                const SizedBox(height: 6),
                Container(width: 22, height: 22, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                const SizedBox(height: 4),
                Container(
                  width: 34,
                  height: 58,
                  decoration: const BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
                ),
              ]),
              const SizedBox(width: 22),
              Transform.rotate(
                angle: t * math.pi * 4,
                child: const Icon(Icons.schedule_rounded, color: Colors.white, size: 40),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          Text('¿Ya pasó mi bus?', textAlign: TextAlign.center, style: AppTheme.titulo(size: 40, color: Colors.white)),
        ]);
      },
    );
  }
}

class _EscenaProblema extends StatelessWidget {
  const _EscenaProblema({required this.avance});
  final Animation<double> avance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: avance,
      builder: (context, _) {
        final minutos = (Curves.easeOut.transform((avance.value * 1.4).clamp(0, 1)) * 40).round();
        return _Centro(children: [
          Text.rich(
            TextSpan(children: const [
              TextSpan(text: 'Todos los días,\nmiles de personas\n'),
              TextSpan(text: 'esperan sin saber.', style: TextStyle(color: _amarillo)),
            ]),
            textAlign: TextAlign.center,
            style: AppTheme.titulo(size: 34, color: Colors.white, height: 1.15),
          ),
          const SizedBox(height: 26),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text('$minutos', style: AppTheme.titulo(size: 64, color: _rojo, height: 1)),
            const SizedBox(width: 12),
            const Text('minutos perdidos\nen un solo paradero', style: TextStyle(color: _gris, fontSize: 15, height: 1.3)),
          ]),
        ]);
      },
    );
  }
}

class _EscenaMarca extends StatelessWidget {
  const _EscenaMarca();

  @override
  Widget build(BuildContext context) => const _Centro(children: [
        _Marca(size: 72),
        SizedBox(height: 12),
        Text('Sabe dónde viene tu bus.', style: TextStyle(color: _gris, fontSize: 19)),
      ]);
}

class _EscenaPaso extends StatelessWidget {
  const _EscenaPaso({required this.paso, required this.titulo, required this.detalle, required this.visual});
  final String paso;
  final String titulo;
  final String detalle;
  final Widget visual;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(paso, style: AppTheme.titulo(size: 44, color: _rojo, height: 1)),
          Text(titulo, style: AppTheme.titulo(size: 32, color: Colors.white)),
          const SizedBox(height: 6),
          Text(detalle, style: const TextStyle(color: _gris, fontSize: 15.5, height: 1.4)),
          const SizedBox(height: 18),
          Expanded(child: visual),
        ],
      ),
    );
  }
}

class _ListaRutas extends StatelessWidget {
  const _ListaRutas({required this.avance});
  final Animation<double> avance;

  @override
  Widget build(BuildContext context) {
    const items = [
      ('R07', Color(0xFF087F8C), 'Belén - Parque Berrío'),
      ('R01', Color(0xFF6B3FA0), 'Parque Berrío - El Poblado'),
      ('R02', Color(0xFFB85C00), 'Parque Berrío - Aranjuez'),
    ];
    return AnimatedBuilder(
      animation: avance,
      builder: (context, _) {
        final elegida = avance.value > 0.45;
        return Column(
          children: [
            for (final (i, it) in items.indexed)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: elegida && i == 1 ? const Color(0xFF262D32) : const Color(0xFF141414),
                  border: Border(left: BorderSide(color: elegida && i == 1 ? it.$2 : Colors.transparent, width: 5)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 3),
                    decoration: BoxDecoration(color: it.$2, borderRadius: BorderRadius.circular(3)),
                    child: Text(it.$1, style: AppTheme.titulo(size: 17, color: Colors.white, height: 1)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(it.$3, style: const TextStyle(color: Colors.white, fontSize: 15))),
                  if (elegida && i == 1) const Icon(Icons.touch_app_rounded, color: Colors.white, size: 22),
                ]),
              ),
          ],
        );
      },
    );
  }
}

class _MapaVivo extends StatelessWidget {
  const _MapaVivo({required this.avance});
  final Animation<double> avance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: avance,
      builder: (context, _) {
        final t = Curves.easeInOut.transform((avance.value * 1.15).clamp(0, 1));
        final minutos = math.max(1, 4 - (t * 3).floor());
        return Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _PlanoVivo(t))),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.white,
              child: Text.rich(TextSpan(children: [
                const TextSpan(text: 'Llega en ', style: TextStyle(color: _negro)),
                TextSpan(
                    text: t >= 1 ? 'ya llegó' : '$minutos min',
                    style: AppTheme.titulo(size: 22, color: const Color(0xFF187A45))),
              ])),
            ),
          ),
        ]);
      },
    );
  }
}

class _PlanoVivo extends CustomPainter {
  _PlanoVivo(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size s) {
    final calles = Paint()
      ..color = const Color(0xFF262D32)
      ..strokeWidth = 6;
    for (final f in [0.23, 0.54, 0.85]) {
      canvas.drawLine(Offset(0, s.height * f), Offset(s.width, s.height * f), calles);
    }
    for (final f in [0.17, 0.44, 0.72]) {
      canvas.drawLine(Offset(s.width * f, 0), Offset(s.width * f, s.height), calles);
    }
    final puntos = [
      Offset(s.width * 0.05, s.height * 0.85),
      Offset(s.width * 0.44, s.height * 0.85),
      Offset(s.width * 0.44, s.height * 0.54),
      Offset(s.width * 0.72, s.height * 0.54),
      Offset(s.width * 0.72, s.height * 0.23),
      Offset(s.width * 0.95, s.height * 0.23),
    ];
    final ruta = Path()..moveTo(puntos.first.dx, puntos.first.dy);
    for (final p in puntos.skip(1)) {
      ruta.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        ruta,
        Paint()
          ..color = const Color(0xFF6B3FA0)
          ..strokeWidth = 7
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round);
    // Tú
    final tu = Offset(s.width * 0.72, s.height * 0.38);
    canvas.drawCircle(tu, 14, Paint()..color = const Color(0x55014CAB));
    canvas.drawCircle(tu, 8, Paint()..color = const Color(0xFF78AEFF));
    // El bus avanza por la ruta
    final metrica = ruta.computeMetrics().first;
    final pos = metrica.getTangentForOffset(metrica.length * t * 0.72)?.position ?? puntos.first;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: pos, width: 30, height: 20), const Radius.circular(4)),
        Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(pos.dx - 10, pos.dy - 6, 8, 6), Paint()..color = const Color(0xFF6B3FA0));
    canvas.drawRect(Rect.fromLTWH(pos.dx + 2, pos.dy - 6, 8, 6), Paint()..color = const Color(0xFF6B3FA0));
  }

  @override
  bool shouldRepaint(_PlanoVivo old) => old.t != t;
}

class _Avisos extends StatelessWidget {
  const _Avisos({required this.avance});
  final Animation<double> avance;

  @override
  Widget build(BuildContext context) {
    Widget aviso(String titulo, String texto, Color color, double desde) {
      final v = ((avance.value - desde) * 4).clamp(0.0, 1.0);
      return Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - v)),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: color, width: 5))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: AppTheme.titulo(size: 18, color: _negro)),
              const SizedBox(height: 2),
              Text(texto, style: const TextStyle(color: Color(0xFF5B646B), fontSize: 14)),
            ]),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: avance,
      builder: (context, _) => Column(children: [
        aviso('Desvío por obras', 'La ruta R01 toma la carrera 43A hasta el viernes.', _amarillo, 0.05),
        aviso('Demora', 'Los buses de la R07 van 10 minutos tarde.', const Color(0xFFD4121A), 0.3),
      ]),
    );
  }
}
