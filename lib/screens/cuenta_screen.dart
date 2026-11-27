import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/alerta.dart';
import '../services/api.dart';
import '../services/mensajes.dart';
import '../services/navegacion.dart';
import '../services/sesion.dart';
import '../theme/app_theme.dart';
import '../widgets/caja_con_franja.dart';
import '../widgets/guia.dart';
import '../widgets/lb.dart';
import 'acerca_screen.dart';
import 'perfil_screen.dart';

/// Pestaña de la cuenta: sin sesión, iniciar sesión (y desde ahí registrarse o recuperar la contraseña); con
/// sesión, «Mi perfil». Tiene su propio navegador para que la barra inferior siga a la vista.
class CuentaTab extends StatefulWidget {
  const CuentaTab({super.key});

  @override
  State<CuentaTab> createState() => _CuentaTabState();
}

class _CuentaTabState extends State<CuentaTab> {
  final GlobalKey<NavigatorState> _nav = GlobalKey();
  bool _activa = Sesion.i.activa;

  @override
  void initState() {
    super.initState();
    Sesion.i.addListener(_alCambiarSesion);
    Navegacion.pedidoRegistro.addListener(_alPedirRegistro);
  }

  @override
  void dispose() {
    Sesion.i.removeListener(_alCambiarSesion);
    Navegacion.pedidoRegistro.removeListener(_alPedirRegistro);
    super.dispose();
  }

  void _alCambiarSesion() {
    if (_activa == Sesion.i.activa) return;
    setState(() => _activa = Sesion.i.activa);
    _nav.currentState?.popUntil((r) => r.isFirst);
  }

  void _alPedirRegistro() {
    if (Sesion.i.activa) return;
    _nav.currentState?.popUntil((r) => r.isFirst);
    _nav.currentState?.push(MaterialPageRoute(builder: (_) => const RegistroScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return NavigatorPopHandler(
      onPopWithResult: (_) => _nav.currentState?.maybePop(),
      child: Navigator(
        key: _nav,
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => ListenableBuilder(
            listenable: Sesion.i,
            builder: (context, _) => Sesion.i.activa ? const PerfilScreen() : const LoginScreen(),
          ),
        ),
      ),
    );
  }
}

// ================= TARJETA DE ACCESO =================

/// Tarjeta de las páginas de acceso (.registro-card): logo sobre negro, título, subtítulo y el formulario.
class TarjetaAcceso extends StatelessWidget {
  const TarjetaAcceso(
      {super.key, required this.titulo, required this.subtitulo, required this.hijos, this.atras = false, this.accion});

  /// Botón arriba a la derecha (la «Guía»).
  final Widget? accion;

  final String titulo;
  final String subtitulo;
  final List<Widget> hijos;
  final bool atras;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (atras)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: TextButton.styleFrom(foregroundColor: lb.tinta),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Volver'),
                ),
              ),
            CajaConFranja(
              color: lb.blanco,
              radio: AppTheme.radioVentana,
              borde: Border(
                  top: BorderSide(color: lb.tinta, width: 4),
                  left: BorderSide(color: lb.linea),
                  right: BorderSide(color: lb.linea),
                  bottom: BorderSide(color: lb.linea),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: lb.linea))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (accion != null) Align(alignment: Alignment.centerRight, child: accion),
                        Center(
                          child: Container(
                            height: 110,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF080707), // el logo tiene partes blancas: siempre sobre negro
                              borderRadius: BorderRadius.circular(AppTheme.radio),
                            ),
                            child: Image.asset('assets/img/LocalBus-Logo.png', semanticLabel: 'LocalBus'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Semantics(header: true, child: Text(titulo, style: AppTheme.titulo(size: 27, color: lb.tinta))),
                        const SizedBox(height: 4),
                        Text(subtitulo, style: TextStyle(fontSize: 15.2, height: 1.4, color: lb.grisTexto)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
                    child: AutofillGroup(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error del formulario (.registro-error).
class ErrorAcceso extends StatelessWidget {
  const ErrorAcceso(this.texto, {super.key});
  final String? texto;

  @override
  Widget build(BuildContext context) {
    if (texto == null || texto!.isEmpty) return const SizedBox.shrink();
    return LbNota.error(context, texto!, margen: const EdgeInsets.only(bottom: 18));
  }
}

/// Texto con un enlace al final («¿No tienes una cuenta? Crea una cuenta»).
class EnlaceAcceso extends StatelessWidget {
  const EnlaceAcceso({super.key, required this.texto, required this.enlace, required this.alTocar});
  final String texto;
  final String enlace;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: texto.isEmpty ? '' : '$texto '),
          TextSpan(
            text: enlace,
            style: TextStyle(color: lb.azul, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
            recognizer: TapGestureRecognizer()..onTap = alTocar,
          ),
        ]),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15, color: lb.grisTexto),
      ),
    );
  }
}

// ================= INICIAR SESIÓN =================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.identificador});
  final String? identificador;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _guia = ClavesGuia();
  late final TextEditingController _usuario = TextEditingController(text: widget.identificador);
  final TextEditingController _clave = TextEditingController();
  // Como casi todas las apps: la sesión se recuerda salvo que se desmarque
  bool _recordar = true;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final usuario = _usuario.text.trim();
    if (usuario.isEmpty || _clave.text.isEmpty) {
      setState(() => _error = usuario.isEmpty ? 'Escribe tu usuario o tu correo.' : 'Escribe tu contraseña.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final d = await Api.post('login/', {'identificador': usuario, 'contrasena': _clave.text});
      TextInput.finishAutofillContext();
      await Sesion.i.iniciar('${d['token']}', Usuario.fromJson(d['usuario'] as Map<String, dynamic>),
          recordar: _recordar);
      Mensajes.mostrar('${d['mensaje']}');
      // Como en la web: después de entrar se va al mapa (y la primera vez, la bienvenida)
      if (d['mostrar_bienvenida'] == true) Navegacion.bienvenida.value = true;
      Navegacion.ir(Navegacion.mapa);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _error = e.mensaje;
        });
      }
    }
  }

  List<PasoGuia> _pasosGuia() => [
        const PasoGuia('Tu cuenta',
            'Con una cuenta de pasajero puedes reportar novedades, seguir rutas y recibir solo sus alertas. Sin cuenta puedes ver el mapa, las rutas y las alertas.'),
        PasoGuia('Usuario o correo', 'Escribe tu nombre de usuario o el correo con el que te registraste.',
            _guia['usuario']),
        PasoGuia('Contraseña', 'Con Mostrar puedes revisar lo que escribiste.', _guia['clave']),
        PasoGuia(
            'Recordarme y recuperar',
            'Con Recordarme la sesión sigue abierta al cerrar la app; desmárcalo en un celular prestado. Si olvidaste la contraseña, te enviamos un código al correo.',
            _guia['recordar']),
        PasoGuia('Iniciar sesión', 'Al entrar vas al mapa.', _guia['entrar']),
        PasoGuia('Crear una cuenta', 'Si aún no tienes cuenta, créala aquí. Te pedimos confirmar el correo con un código.',
            _guia['crear']),
        const PasoGuia('Listo', 'Esta guía sigue en el botón Guía.'),
      ];

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return TarjetaAcceso(
      accion: BotonGuia(id: 'ingresar', titulo: 'Guía de Ingresar', pestana: Navegacion.cuenta, pasos: _pasosGuia),
      titulo: 'Inicia sesión',
      subtitulo: 'Entra a tu cuenta de LocalBus.',
      hijos: [
        ErrorAcceso(_error),
        _guia.marcar('usuario', LbCampo(
          etiqueta: 'Usuario o correo',
          controller: _usuario,
          hint: 'usuario123 o tu@correo.com',
          teclado: TextInputType.emailAddress,
          accion: TextInputAction.next,
          autofill: const [AutofillHints.username, AutofillHints.email],
        )),
        _guia.marcar('clave', LbCampo(
          etiqueta: 'Contraseña',
          controller: _clave,
          contrasena: true,
          accion: TextInputAction.done,
          autofill: const [AutofillHints.password],
          onSubmitted: (_) => _entrar(),
        )),
        Wrap(
          key: _guia['recordar'],
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 4,
          children: [
            InkWell(
              onTap: () => setState(() => _recordar = !_recordar),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Checkbox(value: _recordar, onChanged: (v) => setState(() => _recordar = v ?? false)),
                Text('Recordarme', style: TextStyle(color: lb.tinta, fontSize: 15)),
              ]),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecuperarScreen())),
              style: TextButton.styleFrom(foregroundColor: lb.azul),
              child: const Text('¿Olvidaste tu contraseña?',
                  style: TextStyle(fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _guia.marcar('entrar', LbBoton('Iniciar sesión', ancho: true, cargando: _enviando, onPressed: _entrar)),
        EnlaceAcceso(
          key: _guia['crear'],
          texto: '¿No tienes una cuenta?',
          enlace: 'Crea una cuenta',
          alTocar: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegistroScreen())),
        ),
      ],
    );
  }
}

// ================= REGISTRO =================

/// Comprueba en el servidor, medio segundo después de escribir, si un dato ya está en uso.
class VerificadorDisponible {
  VerificadorDisponible(this.campo, this.alCambiar);

  final String campo;
  final VoidCallback alCambiar;
  Timer? _timer;
  int _pedido = 0;
  EstadoCampo estado = EstadoCampo.ninguno;
  String? mensaje;
  List<String> sugerencias = [];

  void revisar(String valor, {String? formatoMalo}) {
    _timer?.cancel();
    sugerencias = [];
    if (valor.isEmpty) {
      estado = EstadoCampo.ninguno;
      mensaje = null;
    } else if (formatoMalo != null) {
      estado = EstadoCampo.mal;
      mensaje = formatoMalo;
    } else {
      estado = EstadoCampo.cargando;
      mensaje = null;
      _timer = Timer(const Duration(milliseconds: 500), () => _consultar(valor));
    }
    alCambiar();
  }

  Future<void> _consultar(String valor) async {
    final pedido = ++_pedido;
    try {
      final d = await Api.post('disponible/', {'campo': campo, 'valor': valor});
      if (pedido != _pedido) return;
      final existe = d['existe'] == true;
      estado = existe ? EstadoCampo.mal : EstadoCampo.bien;
      _marcar(existe, (d['sugerencias'] as List? ?? []).map((s) => '$s').toList());
    } on ApiError catch (e) {
      if (pedido != _pedido) return;
      estado = EstadoCampo.ninguno;
      mensaje = e.status == 429 ? e.mensaje : null;
    }
    alCambiar();
  }

  /// Los mismos textos que registro.js en la web.
  void _marcar(bool existe, List<String> nuevas) {
    estado = existe ? EstadoCampo.mal : EstadoCampo.bien;
    mensaje = switch ((campo, existe)) {
      ('email', true) => 'Este correo ya tiene una cuenta. Inicia sesión o usa otro.',
      ('email', false) => 'Correo disponible',
      ('nickname', true) => 'Este nombre de usuario ya está en uso. Prueba con otro.',
      ('nickname', false) => 'Nombre de usuario disponible',
      (_, true) => 'Este teléfono ya tiene una cuenta. Usa otro.',
      _ => 'Teléfono disponible',
    };
    sugerencias = nuevas;
  }

  /// Comprobación al enviar (como la web antes de mandar el formulario): devuelve si el dato ya está en uso y
  /// actualiza el aviso del campo. Sin conexión devuelve false: el servidor lo vuelve a revisar al registrar.
  Future<bool> comprobarAhora(String valor) async {
    _timer?.cancel();
    final pedido = ++_pedido;
    try {
      final d = await Api.post('disponible/', {'campo': campo, 'valor': valor});
      final existe = d['existe'] == true;
      if (pedido == _pedido) {
        _marcar(existe, (d['sugerencias'] as List? ?? []).map((s) => '$s').toList());
        alCambiar();
      }
      return existe;
    } on ApiError {
      return false;
    }
  }

  void cancelar() => _timer?.cancel();
}

/// Correo con forma válida (la misma expresión que registro.js).
final RegExp formatoCorreo = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

const String textoCorreoInvalido = 'Escribe un correo válido, por ejemplo tu@correo.com';

/// Nombre de usuario con forma válida y su aviso (registro y perfil).
final RegExp formatoUsuario = RegExp(r'^[a-zA-Z0-9._]{3,30}$');
const String textoUsuarioInvalido = 'Usa entre 3 y 30 caracteres: letras, números, puntos o guiones bajos.';

/// Teléfono con forma válida y su aviso (registro y perfil).
final RegExp formatoTelefono = RegExp(r'^\d{7,15}$');
const String textoTelefonoInvalido = 'Escribe al menos 7 dígitos.';

/// Barra de fuerza de la contraseña (registro.js): 4 niveles.
class FuerzaContrasena extends StatelessWidget {
  const FuerzaContrasena(this.contrasena, {super.key});
  final String contrasena;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    if (contrasena.isEmpty) return const SizedBox.shrink();
    var f = 0;
    if (contrasena.length >= 8) f++;
    if (RegExp('[a-z]').hasMatch(contrasena) && RegExp('[A-Z]').hasMatch(contrasena)) f++;
    if (RegExp(r'\d').hasMatch(contrasena)) f++;
    if (RegExp(r'[^a-zA-Z\d]').hasMatch(contrasena)) f++;
    if (f == 0) return const SizedBox.shrink();
    final (color, texto) = switch (f) {
      1 => (lb.rojoInterfaz, 'Contraseña débil'),
      2 => (lb.amarillo, 'Contraseña media'),
      3 => (lb.azul, 'Contraseña fuerte'),
      _ => (lb.verde, 'Contraseña muy fuerte'),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(
          builder: (context, c) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            width: c.maxWidth * f / 4,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(texto, style: TextStyle(fontSize: 12.8, fontWeight: FontWeight.w700, color: lb.grisTexto)),
      ]),
    );
  }
}

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _email = TextEditingController();
  final _usuario = TextEditingController();
  final _clave = TextEditingController();
  final _clave2 = TextEditingController();
  final _telefono = TextEditingController();
  late final _vEmail = VerificadorDisponible('email', _refrescar);
  late final _vUsuario = VerificadorDisponible('nickname', _refrescar);
  late final _vTelefono = VerificadorDisponible('telefono', _refrescar);
  bool _terminos = false;
  bool _enviando = false;
  String? _error;
  String? _errorClave;
  Timer? _timerClave;

  void _refrescar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_nombre, _apellido, _email, _usuario, _clave, _clave2, _telefono]) {
      c.dispose();
    }
    _vEmail.cancelar();
    _vUsuario.cancelar();
    _vTelefono.cancelar();
    _timerClave?.cancel();
    super.dispose();
  }

  /// Reglas del servidor (largo, común, solo números, parecida a tus datos). Devuelve el error o null; sin
  /// conexión devuelve null y el servidor lo vuelve a revisar al registrar.
  Future<String?> _reglasClave() async {
    try {
      final d = await Api.post('contrasena/', {
        'password': _clave.text,
        'nombre': _nombre.text.trim(),
        'apellido': _apellido.text.trim(),
        'email': _email.text.trim().toLowerCase(),
        'username': _usuario.text.trim(),
      });
      return d['error'] as String?;
    } on ApiError {
      return null;
    }
  }

  void _revisarClave() {
    _timerClave?.cancel();
    // Mientras se escribe se quita el aviso anterior; el nuevo llega tras una pausa (como en la web)
    setState(() => _errorClave = null);
    if (_clave.text.isEmpty) return;
    _timerClave = Timer(const Duration(milliseconds: 500), () async {
      final error = await _reglasClave();
      if (mounted) setState(() => _errorClave = error);
    });
  }

  /// Si cambian el nombre, el correo o el usuario, «parecida a tus datos» puede cambiar (como en la web).
  void _alCambiarDato() {
    if (_clave.text.isNotEmpty) _revisarClave();
  }

  void _mostrarError(String texto) => setState(() {
        _enviando = false;
        _error = texto;
      });

  /// Las mismas validaciones y en el mismo orden que registro.js antes de enviar el formulario.
  String? _errorLocal() {
    final email = _email.text.trim();
    final usuario = _usuario.text.trim();
    final telefono = _telefono.text.trim();
    if ([_nombre, _apellido, _email, _usuario, _clave].any((c) => c.text.trim().isEmpty)) {
      return 'Completa todos los campos obligatorios.';
    }
    if (!formatoCorreo.hasMatch(email)) return '$textoCorreoInvalido.';
    if (_vEmail.estado == EstadoCampo.mal) return 'Ese correo ya tiene una cuenta. Inicia sesión o usa otro.';
    if (!RegExp(r'^[a-zA-Z0-9._]{3,30}$').hasMatch(usuario) || _vUsuario.estado == EstadoCampo.mal) {
      return 'Corrige el nombre de usuario: está en uso o tiene caracteres no permitidos.';
    }
    if ((telefono.isNotEmpty && !RegExp(r'^\d{7,15}$').hasMatch(telefono)) || _vTelefono.estado == EstadoCampo.mal) {
      return 'Corrige el teléfono: ya tiene una cuenta o tiene menos de 7 dígitos.';
    }
    if (_clave.text != _clave2.text) return 'Las contraseñas no coinciden. Escríbelas de nuevo.';
    if (_clave.text.length < 8) return 'La contraseña debe tener al menos 8 caracteres.';
    if (_errorClave != null) return 'Cambia la contraseña: $_errorClave';
    if (!_terminos) return 'Para crear tu cuenta, acepta los términos y condiciones.';
    return null;
  }

  /// Antes de enviar se comprueba todo contra el servidor (correo, usuario, teléfono y contraseña), como la web:
  /// así no se manda nada con errores aunque las comprobaciones en vivo no hubieran terminado.
  Future<String?> _errorEnServidor() async {
    final telefono = _telefono.text.trim();
    final r = await Future.wait<Object?>([
      _vEmail.comprobarAhora(_email.text.trim().toLowerCase()),
      _vUsuario.comprobarAhora(_usuario.text.trim()),
      telefono.length >= 7 ? _vTelefono.comprobarAhora(telefono) : Future.value(false),
      _reglasClave(),
    ]);
    if (r[0] == true) return 'Ese correo ya tiene una cuenta. Inicia sesión o usa otro.';
    if (r[1] == true) return 'Ese nombre de usuario ya está en uso. Elige otro.';
    if (r[2] == true) return 'Ese teléfono ya tiene una cuenta. Usa otro.';
    if (r[3] is String) {
      if (mounted) setState(() => _errorClave = r[3] as String);
      return 'Cambia la contraseña: ${r[3]}';
    }
    return null;
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    final local = _errorLocal();
    if (local != null) {
      _mostrarError(local);
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    final enServidor = await _errorEnServidor();
    if (!mounted) return;
    if (enServidor != null) {
      _mostrarError(enServidor);
      return;
    }
    try {
      final d = await Api.post(
          'registro/',
          {
            'nombre': _nombre.text.trim(),
            'apellido': _apellido.text.trim(),
            'email': _email.text.trim().toLowerCase(),
            'username': _usuario.text.trim(),
            'password': _clave.text,
            'password2': _clave2.text,
            'telefono': _telefono.text.trim(),
            'terminos': _terminos,
          },
          Api.esperaCorreo);
      if (!mounted) return;
      setState(() => _enviando = false);
      final pendiente = '${d['pendiente']}';
      final email = '${d['email']}';
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VerificarCodigoScreen(
          titulo: 'Verifica tu correo',
          texto: 'Enviamos un código de 6 dígitos a $email. Escríbelo para terminar de crear tu cuenta. '
              'Vence en 15 minutos.',
          boton: 'Verificar y crear cuenta',
          verificar: (codigo) async {
            final r = await Api.post('registro/verificar/', {'pendiente': pendiente, 'codigo': codigo});
            Mensajes.mostrar('${r['mensaje']}');
            return () => Navigator.of(context).popUntil((ruta) => ruta.isFirst);
          },
          alReiniciar: () => Navigator.of(context).pop(),
        ),
      ));
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
    final enlace = TextStyle(color: lb.azul, fontWeight: FontWeight.w700, decoration: TextDecoration.underline);
    return TarjetaAcceso(
      titulo: 'Crear cuenta',
      subtitulo: 'Con tu cuenta recibes alertas de las rutas que te importan.',
      atras: true,
      hijos: [
        ErrorAcceso(_error),
        LbCampo(
            etiqueta: 'Nombre',
            controller: _nombre,
            hint: 'Tu nombre',
            maxLength: 49,
            mayusculas: TextCapitalization.words,
            autofill: const [AutofillHints.givenName],
            onChanged: (_) => _alCambiarDato(),
            accion: TextInputAction.next),
        LbCampo(
            etiqueta: 'Apellido',
            controller: _apellido,
            hint: 'Tu apellido',
            maxLength: 49,
            mayusculas: TextCapitalization.words,
            autofill: const [AutofillHints.familyName],
            onChanged: (_) => _alCambiarDato(),
            accion: TextInputAction.next),
        LbCampo(
          etiqueta: 'Correo electrónico',
          controller: _email,
          hint: 'tu@correo.com',
          maxLength: 100,
          teclado: TextInputType.emailAddress,
          autofill: const [AutofillHints.email],
          accion: TextInputAction.next,
          estado: _vEmail.estado,
          mensaje: _vEmail.mensaje,
          ayuda: 'Usaremos este correo para enviarte alertas.',
          onChanged: (v) {
            final t = v.trim().toLowerCase();
            _vEmail.revisar(t, formatoMalo: formatoCorreo.hasMatch(t) ? null : textoCorreoInvalido);
            _alCambiarDato();
          },
        ),
        LbCampo(
          etiqueta: 'Nombre de usuario',
          controller: _usuario,
          hint: 'usuario123',
          maxLength: 100,
          autofill: const [AutofillHints.newUsername],
          accion: TextInputAction.next,
          estado: _vUsuario.estado,
          mensaje: _vUsuario.mensaje,
          onChanged: (v) {
            final t = v.trim();
            _vUsuario.revisar(t,
                formatoMalo: formatoUsuario.hasMatch(t) ? null : textoUsuarioInvalido);
            _alCambiarDato();
          },
          extra: _Sugerencias(
            sugerencias: _vUsuario.sugerencias,
            alElegir: (s) {
              _usuario.text = s;
              _vUsuario.revisar(s);
            },
          ),
        ),
        LbCampo(
          etiqueta: 'Contraseña',
          controller: _clave,
          contrasena: true,
          autofill: const [AutofillHints.newPassword],
          accion: TextInputAction.next,
          estado: _errorClave != null ? EstadoCampo.mal : EstadoCampo.ninguno,
          mensaje: _errorClave,
          ayuda: 'Mínimo 8 caracteres, que no sea solo números ni una contraseña común.',
          onChanged: (_) {
            setState(() {});
            _revisarClave();
          },
          extra: FuerzaContrasena(_clave.text),
        ),
        LbCampo(
          etiqueta: 'Confirmar contraseña',
          controller: _clave2,
          contrasena: true,
          autofill: const [AutofillHints.newPassword],
          accion: TextInputAction.next,
          onChanged: (_) => setState(() {}),
          estado: _clave2.text.isNotEmpty && _clave2.text != _clave.text ? EstadoCampo.mal : EstadoCampo.ninguno,
          mensaje: _clave2.text.isNotEmpty && _clave2.text != _clave.text ? 'Las contraseñas no coinciden.' : null,
        ),
        LbCampo(
          etiqueta: 'Teléfono',
          opcional: true,
          controller: _telefono,
          hint: '3001234567',
          maxLength: 15,
          teclado: TextInputType.number,
          autofill: const [AutofillHints.telephoneNumber],
          formateadores: [FilteringTextInputFormatter.digitsOnly],
          estado: _vTelefono.estado,
          mensaje: _vTelefono.mensaje,
          ayuda: 'Solo números, entre 7 y 15 dígitos.',
          onChanged: (v) => _vTelefono.revisar(v,
              formatoMalo: v.isEmpty || formatoTelefono.hasMatch(v) ? null : textoTelefonoInvalido),
        ),
        _Casilla(
          valor: _terminos,
          alCambiar: (v) => setState(() => _terminos = v),
          texto: Text.rich(TextSpan(children: [
            const TextSpan(text: 'Acepto los '),
            TextSpan(
                text: 'términos y condiciones',
                style: enlace,
                recognizer: TapGestureRecognizer()..onTap = () => abrirWeb('/terminos/')),
            const TextSpan(text: ' y la '),
            TextSpan(
                text: 'política de privacidad',
                style: enlace,
                recognizer: TapGestureRecognizer()..onTap = () => abrirWeb('/privacidad/')),
          ])),
        ),
        const SizedBox(height: 18),
        LbBoton('Crear cuenta', ancho: true, cargando: _enviando, onPressed: _enviar),
        EnlaceAcceso(texto: '¿Ya tienes una cuenta?', enlace: 'Inicia sesión', alTocar: () => Navigator.of(context).pop()),
      ],
    );
  }
}

class _Sugerencias extends StatelessWidget {
  const _Sugerencias({required this.sugerencias, required this.alElegir});
  final List<String> sugerencias;
  final ValueChanged<String> alElegir;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    if (sugerencias.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Estos nombres están disponibles:', style: TextStyle(fontSize: 12.8, color: lb.grisTexto)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in sugerencias)
            ActionChip(
              label: Text(s),
              onPressed: () => alElegir(s),
              backgroundColor: lb.concreto,
              side: BorderSide(color: lb.linea),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radio)),
            ),
        ]),
      ]),
    );
  }
}

class _Casilla extends StatelessWidget {
  const _Casilla({required this.valor, required this.alCambiar, required this.texto});
  final bool valor;
  final ValueChanged<bool> alCambiar;
  final Widget texto;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => alCambiar(!valor),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(value: valor, onChanged: (v) => alCambiar(v ?? false)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: DefaultTextStyle.merge(style: TextStyle(fontSize: 14.5, height: 1.4, color: context.lb.tinta), child: texto),
            ),
          ),
        ]),
      ),
    );
  }
}

// ================= CÓDIGO DE 6 DÍGITOS =================

/// Pide el código de 6 dígitos que llegó al correo. `verificar` devuelve qué hacer al terminar bien.
class VerificarCodigoScreen extends StatefulWidget {
  const VerificarCodigoScreen({
    super.key,
    required this.titulo,
    required this.texto,
    required this.boton,
    required this.verificar,
    required this.alReiniciar,
  });

  final String titulo;
  final String texto;
  final String boton;
  final Future<VoidCallback> Function(String codigo) verificar;

  /// El código ya no sirve (venció o demasiados intentos).
  final VoidCallback alReiniciar;

  @override
  State<VerificarCodigoScreen> createState() => _VerificarCodigoScreenState();
}

class _VerificarCodigoScreenState extends State<VerificarCodigoScreen> {
  final _codigo = TextEditingController();
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_codigo.text.trim())) {
      setState(() => _error = 'Escribe los 6 dígitos del código.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final despues = await widget.verificar(_codigo.text.trim());
      if (mounted) despues();
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.reiniciar) {
        Mensajes.mostrar(e.mensaje, nivel: Nivel.error);
        widget.alReiniciar();
        return;
      }
      setState(() {
        _enviando = false;
        _error = e.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TarjetaAcceso(
      titulo: widget.titulo,
      subtitulo: widget.texto,
      atras: true,
      hijos: [
        ErrorAcceso(_error),
        LbCampo(
          etiqueta: 'Código de verificación',
          controller: _codigo,
          hint: '000000',
          maxLength: 6,
          autofocus: true,
          teclado: TextInputType.number,
          autofill: const [AutofillHints.oneTimeCode],
          formateadores: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _enviar(),
          ayuda: 'Si no lo ves, revisa la carpeta de correo no deseado.',
        ),
        LbBoton(widget.boton, ancho: true, cargando: _enviando, onPressed: _enviar),
      ],
    );
  }
}

// ================= RECUPERAR LA CONTRASEÑA =================

class RecuperarScreen extends StatefulWidget {
  const RecuperarScreen({super.key});

  @override
  State<RecuperarScreen> createState() => _RecuperarScreenState();
}

class _RecuperarScreenState extends State<RecuperarScreen> {
  final _email = TextEditingController();
  bool _enviando = false;
  String? _error;
  String? _errorEmail;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    final email = _email.text.trim().toLowerCase();
    // Como la web: el correo es obligatorio y debe tener forma de correo (campo type="email")
    if (email.isEmpty) {
      setState(() => _error = 'Escribe tu correo.');
      return;
    }
    if (!formatoCorreo.hasMatch(email)) {
      setState(() {
        _errorEmail = textoCorreoInvalido;
        _error = '$textoCorreoInvalido.';
      });
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final d = await Api.post('recuperar/', {'email': email}, Api.esperaCorreo);
      if (!mounted) return;
      setState(() => _enviando = false);
      Mensajes.mostrar('${d['mensaje']}');
      final nav = Navigator.of(context);
      nav.push(MaterialPageRoute(
        builder: (_) => VerificarCodigoScreen(
          titulo: 'Revisa tu correo',
          texto: 'Escribe el código de 6 dígitos que enviamos a $email. Vence en 15 minutos.',
          boton: 'Verificar código',
          verificar: (codigo) async {
            final r = await Api.post('recuperar/verificar/', {'email': email, 'codigo': codigo});
            final permiso = '${r['permiso']}';
            return () => nav.pushReplacement(MaterialPageRoute(builder: (_) => _NuevaContrasena(permiso: permiso)));
          },
          alReiniciar: () => nav.pop(),
        ),
      ));
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
    return TarjetaAcceso(
      titulo: 'Recuperar contraseña',
      subtitulo: 'Escribe el correo de tu cuenta y te enviaremos un código para crear una contraseña nueva.',
      atras: true,
      hijos: [
        ErrorAcceso(_error),
        LbCampo(
          etiqueta: 'Correo electrónico',
          controller: _email,
          hint: 'tu@correo.com',
          maxLength: 100,
          teclado: TextInputType.emailAddress,
          autofill: const [AutofillHints.email],
          estado: _errorEmail != null ? EstadoCampo.mal : EstadoCampo.ninguno,
          mensaje: _errorEmail,
          ayuda: 'Te enviaremos un código de 6 dígitos a este correo.',
          onChanged: (v) {
            final t = v.trim();
            final nuevo = t.isEmpty || formatoCorreo.hasMatch(t) ? null : textoCorreoInvalido;
            if (nuevo != _errorEmail || _error != null) {
              setState(() {
                _errorEmail = nuevo;
                _error = null;
              });
            }
          },
          onSubmitted: (_) => _enviar(),
        ),
        LbBoton('Enviar código', ancho: true, cargando: _enviando, onPressed: _enviar),
        EnlaceAcceso(texto: '¿Ya la recordaste?', enlace: 'Inicia sesión', alTocar: () => Navigator.of(context).pop()),
      ],
    );
  }
}

class _NuevaContrasena extends StatefulWidget {
  const _NuevaContrasena({required this.permiso});
  final String permiso;

  @override
  State<_NuevaContrasena> createState() => _NuevaContrasenaState();
}

class _NuevaContrasenaState extends State<_NuevaContrasena> {
  final _clave = TextEditingController();
  final _clave2 = TextEditingController();
  bool _enviando = false;
  String? _error;
  String? _errorClave;
  Timer? _timerClave;

  @override
  void dispose() {
    _clave.dispose();
    _clave2.dispose();
    _timerClave?.cancel();
    super.dispose();
  }

  /// Las reglas del servidor con los datos de la cuenta que se recupera (el permiso la identifica).
  Future<String?> _reglasClave() async {
    try {
      final d = await Api.post('contrasena/', {'password': _clave.text, 'permiso': widget.permiso});
      return d['error'] as String?;
    } on ApiError {
      return null; // sin conexión: el servidor lo vuelve a revisar al guardar
    }
  }

  void _revisarClave() {
    _timerClave?.cancel();
    setState(() {
      _errorClave = null;
      _error = null;
    });
    if (_clave.text.isEmpty) return;
    _timerClave = Timer(const Duration(milliseconds: 500), () async {
      final error = await _reglasClave();
      if (mounted) setState(() => _errorClave = error);
    });
  }

  /// Las mismas reglas que la página «Nueva contraseña» de la web antes de enviar.
  String? _errorLocal() {
    if (_clave.text.isEmpty) return 'Escribe la nueva contraseña.';
    if (_clave.text.length < 8) return 'La contraseña debe tener al menos 8 caracteres.';
    if (_clave.text != _clave2.text) return 'Las contraseñas no coinciden.';
    if (_errorClave != null) return 'Cambia la contraseña: $_errorClave';
    return null;
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    final local = _errorLocal();
    if (local != null) {
      setState(() => _error = local);
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final d = await Api.post('recuperar/nueva/', {
        'permiso': widget.permiso,
        'password1': _clave.text,
        'password2': _clave2.text,
      });
      if (!mounted) return;
      Mensajes.mostrar('${d['mensaje']}');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen(identificador: '${d['email']}')),
        (r) => r.isFirst,
      );
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.reiniciar) {
        Mensajes.mostrar(e.mensaje, nivel: Nivel.error);
        Navigator.of(context).popUntil((r) => r.isFirst);
        return;
      }
      setState(() {
        _enviando = false;
        _error = e.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TarjetaAcceso(
      titulo: 'Nueva contraseña',
      subtitulo: 'Elige la contraseña nueva de tu cuenta.',
      hijos: [
        ErrorAcceso(_error),
        LbCampo(
          etiqueta: 'Nueva contraseña',
          controller: _clave,
          contrasena: true,
          autofill: const [AutofillHints.newPassword],
          accion: TextInputAction.next,
          estado: _errorClave != null ? EstadoCampo.mal : EstadoCampo.ninguno,
          mensaje: _errorClave,
          ayuda: 'Mínimo 8 caracteres, que no sea solo números ni una contraseña común.',
          onChanged: (_) => _revisarClave(),
          extra: FuerzaContrasena(_clave.text),
        ),
        LbCampo(
          etiqueta: 'Confirmar la nueva contraseña',
          controller: _clave2,
          contrasena: true,
          autofill: const [AutofillHints.newPassword],
          onChanged: (_) => setState(() => _error = null),
          estado: _clave2.text.isEmpty
              ? EstadoCampo.ninguno
              : (_clave2.text == _clave.text ? EstadoCampo.bien : EstadoCampo.mal),
          mensaje: _clave2.text.isEmpty
              ? null
              : (_clave2.text == _clave.text ? '✓ Las contraseñas coinciden' : '❌ Las contraseñas no coinciden'),
          onSubmitted: (_) => _enviar(),
        ),
        LbBoton('Guardar contraseña', ancho: true, cargando: _enviando, onPressed: _enviar),
      ],
    );
  }
}
