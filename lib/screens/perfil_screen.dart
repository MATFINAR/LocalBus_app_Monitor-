import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/alerta.dart';
import '../services/api.dart';
import '../services/mensajes.dart';
import '../services/navegacion.dart';
import '../services/sesion.dart';
import '../theme/app_theme.dart';
import '../widgets/lb.dart';
import 'cuenta_screen.dart';

/// «Mi perfil» del pasajero (el modal de perfil de base.html): datos, Ajustes, editar, cambiar contraseña,
/// eliminar la cuenta y cerrar sesión.
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

enum _Modo { ver, editar, contrasena, eliminar }

const _colores = [
  ('#E63946', 'Rojo'),
  ('#1D3557', 'Azul oscuro'),
  ('#457B9D', 'Azul claro'),
  ('#2E7D32', 'Verde'),
  ('#F39C12', 'Naranja'),
  ('#9B59B6', 'Morado'),
  ('#E91E63', 'Rosa'),
  ('#00BCD4', 'Cian'),
  ('#FF5722', 'Rojo naranja'),
  ('#607D8B', 'Gris azulado'),
  ('#795548', 'Marrón'),
  ('#1A1A1A', 'Negro'),
];

class _PerfilScreenState extends State<PerfilScreen> {
  _Modo _modo = _Modo.ver;
  String? _estadoTema;
  bool _guardandoTema = false;

  @override
  void initState() {
    super.initState();
    Sesion.i.refrescar();
  }

  Future<void> _elegirTema(String tema) async {
    setState(() {
      _guardandoTema = true;
      _estadoTema = 'Guardando…';
    });
    try {
      await Api.post('perfil/tema/', {'tema': tema});
      final u = Sesion.i.usuario!;
      await Sesion.i.actualizarUsuario(Usuario.fromJson({...u.toJson(), 'tema': tema}));
      if (mounted) setState(() => _estadoTema = 'Guardado.');
    } on ApiError catch (e) {
      if (mounted) setState(() => _estadoTema = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardandoTema = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    final u = Sesion.i.usuario;
    if (u == null) return const SizedBox.shrink();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const CabeceraPagina(etiqueta: 'Tu cuenta', titulo: 'Mi perfil'),
            // Avatar grande
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Column(children: [
                AvatarIniciales(iniciales: u.iniciales, color: u.color, size: 92),
                const SizedBox(height: 12),
                Text(u.nombre, textAlign: TextAlign.center, style: AppTheme.titulo(size: 26, color: lb.tinta)),
                const SizedBox(height: 2),
                Text(u.email, textAlign: TextAlign.center, style: TextStyle(color: lb.grisTexto)),
              ]),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey(_modo),
                child: switch (_modo) {
                  _Modo.ver => _vista(context, u),
                  _Modo.editar => _EditarPerfil(usuario: u, alTerminar: () => setState(() => _modo = _Modo.ver)),
                  _Modo.contrasena => _CambiarContrasena(alTerminar: () => setState(() => _modo = _Modo.ver)),
                  _Modo.eliminar => _EliminarCuenta(alCancelar: () => setState(() => _modo = _Modo.ver)),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vista(BuildContext context, Usuario u) {
    final lb = context.lb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LbDato(etiqueta: 'Nombre completo', valor: u.nombre.isEmpty ? 'No especificado' : u.nombre),
        LbDato(etiqueta: 'Correo electrónico', valor: u.email),
        LbDato(etiqueta: 'Nombre de usuario', valor: u.nickName),
        LbDato(etiqueta: 'Teléfono', valor: u.telefono.isEmpty ? 'No especificado' : u.telefono),

        // Ajustes: se guardan al elegir, sin botón de guardar
        Container(
          margin: const EdgeInsets.only(top: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: lb.concreto, borderRadius: BorderRadius.circular(AppTheme.radio)),
          // Sin este Material, el color de la caja tapa el efecto al tocar las opciones
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ajustes', style: AppTheme.titulo(size: 22, color: lb.tinta)),
                const SizedBox(height: 10),
                Text('Tema de la app', style: TextStyle(fontWeight: FontWeight.w700, color: lb.tinta)),
                for (final (valor, titulo, texto) in [
                  ('sistema', 'Igual que el dispositivo', 'Claro u oscuro, según cómo tengas tu celular.'),
                  ('claro', 'Claro', 'Fondo blanco siempre.'),
                  ('oscuro', 'Oscuro', 'Fondo oscuro siempre. Cansa menos la vista de noche.'),
                ])
                  RadioListTile<String>(
                    value: valor,
                    groupValue: u.tema == 'claro' || u.tema == 'oscuro' ? u.tema : 'sistema',
                    onChanged: _guardandoTema ? null : (v) => _elegirTema(v!),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(titulo, style: TextStyle(fontWeight: FontWeight.w700, color: lb.tinta, fontSize: 15)),
                    subtitle: Text(texto, style: TextStyle(color: lb.grisTexto, fontSize: 13)),
                  ),
                if (_estadoTema != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(_estadoTema!, style: TextStyle(fontSize: 13, color: lb.grisTexto)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        LbAcciones(botones: [
          LbBoton('Editar perfil', onPressed: () => setState(() => _modo = _Modo.editar)),
          LbBoton('Cambiar contraseña',
              estilo: EstiloBoton.secundario, onPressed: () => setState(() => _modo = _Modo.contrasena)),
        ]),
        const SizedBox(height: 10),
        LbBoton('Cerrar sesión',
            estilo: EstiloBoton.secundario,
            ancho: true,
            onPressed: () async {
              await Sesion.i.cerrar();
              Mensajes.mostrar('Sesión cerrada correctamente. ¡Hasta pronto!');
              Navegacion.ir(Navegacion.mapa);
            }),
        Container(
          margin: const EdgeInsets.only(top: 26),
          padding: const EdgeInsets.only(top: 16),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: lb.linea))),
          child: Align(
            alignment: Alignment.centerLeft,
            child: LbBoton('Eliminar cuenta',
                estilo: EstiloBoton.peligro, onPressed: () => setState(() => _modo = _Modo.eliminar)),
          ),
        ),
      ],
    );
  }
}

// ================= EDITAR PERFIL =================

class _EditarPerfil extends StatefulWidget {
  const _EditarPerfil({required this.usuario, required this.alTerminar});
  final Usuario usuario;
  final VoidCallback alTerminar;

  @override
  State<_EditarPerfil> createState() => _EditarPerfilState();
}

class _EditarPerfilState extends State<_EditarPerfil> {
  late final _nombre = TextEditingController(text: widget.usuario.nombre);
  late final _email = TextEditingController(text: widget.usuario.email);
  late final _nick = TextEditingController(text: widget.usuario.nickName);
  late final _telefono = TextEditingController(text: widget.usuario.telefono);
  late String _color = widget.usuario.colorPerfil.toUpperCase();
  late final _vEmail = VerificadorDisponible('email', _refrescar);
  late final _vNick = VerificadorDisponible('nickname', _refrescar);
  late final _vTelefono = VerificadorDisponible('telefono', _refrescar);
  bool _enviando = false;
  String? _error;

  void _refrescar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_nombre, _email, _nick, _telefono]) {
      c.dispose();
    }
    _vEmail.cancelar();
    _vNick.cancelar();
    _vTelefono.cancelar();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_vEmail.estado == EstadoCampo.mal) {
      setState(() => _error = 'Corrige el correo electrónico antes de guardar.');
      return;
    }
    if (_vNick.estado == EstadoCampo.mal) {
      setState(() => _error = 'Corrige el nombre de usuario antes de guardar.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final d = await Api.post('perfil/', {
        'nombre': _nombre.text.trim(),
        'email': _email.text.trim(),
        'nickName': _nick.text.trim(),
        'telefono': _telefono.text.trim(),
        'color_perfil': _color,
      }, Api.esperaCorreo); // si cambia el correo, el servidor envía un código
      await Sesion.i.actualizarUsuario(Usuario.fromJson(d['usuario'] as Map<String, dynamic>));
      if (!mounted) return;
      Mensajes.mostrar('${d['mensaje']}', nivel: nivelDesdeTexto(d['nivel'] as String?));
      widget.alTerminar();
      final cambio = d['cambio'] as String?;
      if (cambio != null) {
        final nav = Navigator.of(context);
        nav.push(MaterialPageRoute(
          builder: (_) => VerificarCodigoScreen(
            titulo: 'Confirma tu nuevo correo',
            texto: 'Enviamos un código de 6 dígitos a ${d['email_nuevo']}. Escríbelo para cambiar el correo de tu cuenta.',
            boton: 'Confirmar correo',
            verificar: (codigo) async {
              final r = await Api.post('perfil/correo/', {'cambio': cambio, 'codigo': codigo});
              await Sesion.i.actualizarUsuario(Usuario.fromJson(r['usuario'] as Map<String, dynamic>));
              Mensajes.mostrar('${r['mensaje']}');
              return () => nav.pop();
            },
            alReiniciar: () => nav.pop(),
          ),
        ));
      }
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
        const LbEtiqueta('Color del avatar'),
        Text('Elige un color para tu perfil', style: TextStyle(fontSize: 12.8, color: lb.grisTexto)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (hex, nombre) in _colores)
              Semantics(
                button: true,
                selected: _color == hex,
                label: nombre,
                child: GestureDetector(
                  onTap: () => setState(() => _color = hex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Color(int.parse('FF${hex.substring(1)}', radix: 16)),
                      shape: BoxShape.circle,
                      border: Border.all(color: _color == hex ? lb.tinta : Colors.transparent, width: 3),
                      boxShadow: _color == hex ? [BoxShadow(color: lb.blanco, spreadRadius: -5)] : null,
                    ),
                    child: _color == hex ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        LbCampo(etiqueta: 'Nombre completo', controller: _nombre, maxLength: 100, mayusculas: TextCapitalization.words),
        LbCampo(
          etiqueta: 'Correo electrónico',
          controller: _email,
          maxLength: 100,
          teclado: TextInputType.emailAddress,
          estado: _vEmail.estado,
          mensaje: _vEmail.mensaje,
          onChanged: (v) {
            final t = v.trim().toLowerCase();
            if (t == widget.usuario.email) return _vEmail.revisar('');
            _vEmail.revisar(t,
                formatoMalo: RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t) ? null : '⚠️ Ingresa un correo válido');
          },
        ),
        LbCampo(
          etiqueta: 'Nombre de usuario',
          controller: _nick,
          maxLength: 100,
          estado: _vNick.estado,
          mensaje: _vNick.mensaje,
          onChanged: (v) {
            final t = v.trim();
            _vNick.revisar(t,
                formatoMalo: RegExp(r'^[a-zA-Z0-9._]{3,30}$').hasMatch(t)
                    ? null
                    : '⚠️ Solo letras, números, puntos y guiones (3-30 caracteres)');
          },
        ),
        LbCampo(
          etiqueta: 'Teléfono',
          controller: _telefono,
          hint: '3001234567',
          maxLength: 15,
          teclado: TextInputType.number,
          formateadores: [FilteringTextInputFormatter.digitsOnly],
          estado: _vTelefono.estado,
          mensaje: _vTelefono.mensaje,
          onChanged: (v) => _vTelefono.revisar(v == widget.usuario.telefono ? '' : v,
              formatoMalo: v.isEmpty || RegExp(r'^\d{7,15}$').hasMatch(v) ? null : '⚠️ Debe tener entre 7 y 15 dígitos'),
        ),
        LbAcciones(botones: [
          LbBoton('Cancelar', estilo: EstiloBoton.secundario, onPressed: widget.alTerminar),
          LbBoton('Guardar cambios', cargando: _enviando, onPressed: _guardar),
        ]),
      ],
    );
  }
}

// ================= CAMBIAR CONTRASEÑA =================

class _CambiarContrasena extends StatefulWidget {
  const _CambiarContrasena({required this.alTerminar});
  final VoidCallback alTerminar;

  @override
  State<_CambiarContrasena> createState() => _CambiarContrasenaState();
}

class _CambiarContrasenaState extends State<_CambiarContrasena> {
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmar = TextEditingController();
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_actual.text.isEmpty || _nueva.text.length < 8) {
      setState(() => _error = _actual.text.isEmpty
          ? 'Escribe tu contraseña actual.'
          : 'La nueva contraseña debe tener mínimo 8 caracteres.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final d = await Api.post('perfil/contrasena/', {
        'actual': _actual.text,
        'nueva': _nueva.text,
        'confirmar': _confirmar.text,
      });
      await Sesion.i.actualizarToken('${d['token']}');
      Mensajes.mostrar('${d['mensaje']}');
      widget.alTerminar();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) LbNota.error(context, _error!),
        LbCampo(etiqueta: 'Contraseña actual', controller: _actual, contrasena: true, autofill: const [AutofillHints.password]),
        LbCampo(
          etiqueta: 'Nueva contraseña',
          controller: _nueva,
          contrasena: true,
          autofill: const [AutofillHints.newPassword],
          ayuda: 'Mínimo 8 caracteres',
          onChanged: (_) => setState(() {}),
          extra: FuerzaContrasena(_nueva.text),
        ),
        LbCampo(
            etiqueta: 'Confirmar la nueva contraseña',
            controller: _confirmar,
            contrasena: true,
            autofill: const [AutofillHints.newPassword]),
        LbAcciones(botones: [
          LbBoton('Cancelar', estilo: EstiloBoton.secundario, onPressed: widget.alTerminar),
          LbBoton('Cambiar contraseña', cargando: _enviando, onPressed: _guardar),
        ]),
      ],
    );
  }
}

// ================= ELIMINAR LA CUENTA =================

class _EliminarCuenta extends StatefulWidget {
  const _EliminarCuenta({required this.alCancelar});
  final VoidCallback alCancelar;

  @override
  State<_EliminarCuenta> createState() => _EliminarCuentaState();
}

class _EliminarCuentaState extends State<_EliminarCuenta> {
  final _identificador = TextEditingController();
  final _clave = TextEditingController();
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _identificador.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _eliminar() async {
    if (_identificador.text.trim().isEmpty || _clave.text.isEmpty) {
      setState(() => _error = 'Escribe tu correo o nombre de usuario y tu contraseña.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final d = await Api.post('perfil/eliminar/', {
        'identificador': _identificador.text.trim(),
        'contrasena': _clave.text,
      });
      await Sesion.i.cerrar();
      Mensajes.mostrar('${d['mensaje']}');
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

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Eliminar tu cuenta', style: AppTheme.titulo(size: 22, color: lb.rojoInterfaz)),
        const SizedBox(height: 8),
        Text(
          'Se borrarán para siempre tu perfil, tus ajustes y las alertas que hayas reportado. Esto no se puede deshacer.',
          style: TextStyle(height: 1.45, color: lb.tinta),
        ),
        const SizedBox(height: 6),
        Text('Para confirmar que eres tú, escribe los datos de esta cuenta.', style: TextStyle(height: 1.45, color: lb.tinta)),
        const SizedBox(height: 18),
        if (_error != null) LbNota.error(context, _error!),
        LbCampo(
            etiqueta: 'Correo o nombre de usuario',
            controller: _identificador,
            autofill: const [AutofillHints.username]),
        LbCampo(etiqueta: 'Contraseña', controller: _clave, contrasena: true, autofill: const [AutofillHints.password]),
        LbAcciones(botones: [
          LbBoton('Cancelar', estilo: EstiloBoton.secundario, onPressed: widget.alCancelar),
          LbBoton('Eliminar mi cuenta', estilo: EstiloBoton.peligro, cargando: _enviando, onPressed: _eliminar),
        ]),
      ],
    );
  }
}
