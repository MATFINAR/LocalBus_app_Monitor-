import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Piezas de interfaz de LocalBus con el mismo aspecto que la página web (alertas.css, home.css, registro.css,
/// rutas.css). Los nombres de las clases de la web van en cada comentario.

const Curve curvaSuave = Cubic(0.22, 0.61, 0.36, 1);

/// Aro que gira (.spinner). Hereda el color que se le pase.
class Aro extends StatelessWidget {
  const Aro({super.key, this.size = 14, this.color, this.grosor = 2});

  final double size;
  final Color? color;
  final double grosor;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: grosor,
          color: color ?? context.lb.grisTexto,
          backgroundColor: Colors.transparent,
        ),
      );
}

/// Cabecera de página (.alertas-cabecera, .ru-cabecera): etiqueta roja, título y subtítulo, con una raya de 2 px.
class CabeceraPagina extends StatelessWidget {
  const CabeceraPagina({super.key, required this.etiqueta, required this.titulo, this.subtitulo});

  final String etiqueta;
  final String titulo;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 17),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: lb.tinta, width: 2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta.toUpperCase(),
            style: AppTheme.titulo(size: 13.6, color: lb.rojoInterfaz, height: 1).copyWith(letterSpacing: 1.6),
          ),
          const SizedBox(height: 4),
          Semantics(
            header: true,
            child: Text(titulo, style: AppTheme.titulo(size: 30, color: lb.tinta)),
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 6),
            Text(subtitulo!, style: TextStyle(fontSize: 15.2, height: 1.45, color: lb.grisTexto)),
          ],
        ],
      ),
    );
  }
}

enum EstiloBoton { principal, secundario, peligro, exito, texto }

/// Botón de las páginas (.al-boton, .ru-boton): Barlow en mayúsculas; tinta y azul al tocarlo.
class LbBoton extends StatelessWidget {
  const LbBoton(
    this.texto, {
    super.key,
    required this.onPressed,
    this.estilo = EstiloBoton.principal,
    this.cargando = false,
    this.ancho = false,
  });

  final String texto;
  final VoidCallback? onPressed;
  final EstiloBoton estilo;
  final bool cargando;

  /// Ocupa todo el ancho disponible.
  final bool ancho;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    final inactivo = onPressed == null || cargando;

    Color fondo(Set<WidgetState> s) {
      final tocado = s.contains(WidgetState.pressed) || s.contains(WidgetState.focused);
      if (inactivo) return estilo == EstiloBoton.texto ? Colors.transparent : lb.grisTexto;
      return switch (estilo) {
        EstiloBoton.principal => tocado ? lb.azul : lb.tinta,
        EstiloBoton.secundario => tocado ? lb.tinta : lb.blanco,
        EstiloBoton.peligro => tocado ? lb.rojoInterfaz : lb.blanco,
        EstiloBoton.exito => tocado ? lb.tinta : lb.verde,
        EstiloBoton.texto => tocado ? lb.concreto : Colors.transparent,
      };
    }

    Color frente(Set<WidgetState> s) {
      final tocado = s.contains(WidgetState.pressed) || s.contains(WidgetState.focused);
      if (inactivo) return estilo == EstiloBoton.texto ? lb.grisTexto : lb.blanco;
      return switch (estilo) {
        EstiloBoton.principal || EstiloBoton.exito => lb.blanco,
        EstiloBoton.secundario => tocado ? lb.blanco : lb.tinta,
        EstiloBoton.peligro => tocado ? lb.blanco : lb.rojoInterfaz,
        EstiloBoton.texto => lb.tinta,
      };
    }

    Color borde(Set<WidgetState> s) {
      final tocado = s.contains(WidgetState.pressed) || s.contains(WidgetState.focused);
      if (inactivo) return estilo == EstiloBoton.texto ? Colors.transparent : lb.grisTexto;
      return switch (estilo) {
        EstiloBoton.principal => tocado ? lb.azul : lb.tinta,
        EstiloBoton.secundario => lb.tinta,
        EstiloBoton.peligro => lb.rojoInterfaz,
        EstiloBoton.exito => tocado ? lb.tinta : lb.verde,
        EstiloBoton.texto => Colors.transparent,
      };
    }

    final boton = TextButton(
      onPressed: inactivo ? null : onPressed,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(fondo),
        foregroundColor: WidgetStateProperty.resolveWith(frente),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        side: WidgetStateProperty.resolveWith((s) => BorderSide(color: borde(s))),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radio))),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
        minimumSize: const WidgetStatePropertyAll(Size(64, 46)),
        textStyle: WidgetStatePropertyAll(
          AppTheme.titulo(size: 16.8, height: 1).copyWith(letterSpacing: 0.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(texto.toUpperCase(), textAlign: TextAlign.center)),
          if (cargando) ...[const SizedBox(width: 10), Aro(size: 13, color: lb.blanco)],
        ],
      ),
    );
    return ancho ? SizedBox(width: double.infinity, child: boton) : boton;
  }
}

enum EstadoAccion { normal, activado, bloqueado }

/// Botón de acción del panel del mapa (.accion): borde de tinta; al tocarlo se invierte.
class LbAccion extends StatelessWidget {
  const LbAccion(
    this.texto, {
    super.key,
    required this.onPressed,
    this.esperando = false,
    this.estado = EstadoAccion.normal,
  });

  final String texto;
  final VoidCallback? onPressed;
  final bool esperando;
  final EstadoAccion estado;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    final (bordeBase, fondoBase, textoBase) = switch (estado) {
      EstadoAccion.activado => (lb.verde, lb.blanco, lb.verde),
      EstadoAccion.bloqueado => (lb.linea, lb.concreto, lb.grisTexto),
      EstadoAccion.normal => (lb.tinta, lb.blanco, lb.tinta),
    };
    final invierte = estado == EstadoAccion.normal;
    return Opacity(
      opacity: esperando ? 0.6 : 1,
      child: TextButton(
        onPressed: esperando ? null : onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
              (s) => invierte && s.contains(WidgetState.pressed) ? lb.tinta : fondoBase),
          foregroundColor: WidgetStateProperty.resolveWith(
              (s) => invierte && s.contains(WidgetState.pressed) ? lb.blanco : textoBase),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStatePropertyAll(BorderSide(color: bordeBase)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radio))),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontFamily: AppTheme.fuenteTexto, fontWeight: FontWeight.w700, fontSize: 13.6, height: 1.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (esperando) ...[Aro(size: 12, color: lb.tinta), const SizedBox(width: 7)],
            Flexible(child: Text(texto, textAlign: TextAlign.center, style: TextStyle(color: esperando ? lb.tinta : null))),
          ],
        ),
      ),
    );
  }
}

/// Número dentro de una pestaña (.al-cuenta). Amarillo si hay pendientes.
class LbCuenta extends StatelessWidget {
  const LbCuenta(this.numero, {super.key, this.pendiente = false});

  final int numero;
  final bool pendiente;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: pendiente ? lb.amarillo : lb.concreto,
        borderRadius: BorderRadius.circular(AppTheme.radio),
      ),
      child: Text(
        '$numero',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12.5,
          color: pendiente ? lb.sobreAmarillo : lb.tinta,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class PestanaLb<T> {
  const PestanaLb(this.valor, this.etiqueta, {this.cuenta, this.pendiente = false, this.esperando = false});

  final T valor;
  final String etiqueta;
  final int? cuenta;
  final bool pendiente;
  final bool esperando;
}

/// Pestañas con raya azul debajo de la elegida (.al-pestana, .filter-chip, .ru-pestana). Van en una sola fila que
/// se desplaza de lado si no caben.
class LbPestanas<T> extends StatelessWidget {
  const LbPestanas({
    super.key,
    required this.pestanas,
    required this.elegida,
    required this.onElegir,
    this.separacion = 24,
    this.tamano = 15.2,
  });

  final List<PestanaLb<T>> pestanas;
  final T elegida;
  final ValueChanged<T> onElegir;
  final double separacion;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: lb.linea))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
        children: [
          for (final (i, p) in pestanas.indexed)
            Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : separacion),
            child: Semantics(
              button: true,
              selected: p.valor == elegida,
              child: InkWell(
                onTap: p.esperando ? null : () => onElegir(p.valor),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: curvaSuave,
                  // Unos 48 px de alto: el mínimo cómodo para tocar
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: p.valor == elegida ? lb.azul : Colors.transparent, width: 3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.etiqueta,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: tamano,
                          height: 1.2,
                          color: p.valor == elegida ? lb.tinta : lb.grisTexto,
                        ),
                      ),
                      if (p.cuenta != null) LbCuenta(p.cuenta!, pendiente: p.pendiente),
                      if (p.esperando) ...[const SizedBox(width: 8), Aro(size: 12, color: lb.grisTexto)],
                    ],
                  ),
                ),
              ),
            ),
            ),
        ],
        ),
      ),
    );
  }
}

/// Nota con franja izquierda (.al-nota azul, .al-error roja, .al-filtro-mensaje).
class LbNota extends StatelessWidget {
  const LbNota(this.texto, {super.key, this.color, this.hijo, this.margen = const EdgeInsets.only(bottom: 16)});

  final String texto;
  final Color? color;
  final Widget? hijo;
  final EdgeInsets margen;

  factory LbNota.error(BuildContext context, String texto, {EdgeInsets margen = const EdgeInsets.only(bottom: 16)}) =>
      LbNota(texto, color: context.lb.rojoInterfaz, margen: margen);

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: margen,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: lb.concreto,
          border: Border(left: BorderSide(color: color ?? lb.azul, width: 4)),
        ),
        child: hijo ?? Text(texto, style: TextStyle(fontSize: 14, height: 1.45, color: lb.tinta)),
      ),
    );
  }
}

/// Etiqueta de un campo (.form-label, .al-campo label).
class LbEtiqueta extends StatelessWidget {
  const LbEtiqueta(this.texto, {super.key, this.opcional = false});

  final String texto;
  final bool opcional;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: texto),
          if (opcional)
            TextSpan(text: ' (opcional)', style: TextStyle(fontWeight: FontWeight.w400, color: lb.grisTexto)),
        ]),
        style: TextStyle(fontSize: 13.6, fontWeight: FontWeight.w700, color: lb.tinta),
      ),
    );
  }
}

enum EstadoCampo { ninguno, cargando, bien, mal }

/// Campo de texto con su etiqueta, ayuda y mensaje de validación (.form-group de registro.css).
class LbCampo extends StatefulWidget {
  const LbCampo({
    super.key,
    required this.etiqueta,
    required this.controller,
    this.opcional = false,
    this.hint,
    this.ayuda,
    this.mensaje,
    this.estado = EstadoCampo.ninguno,
    this.contrasena = false,
    this.teclado,
    this.accion,
    this.autofill,
    this.maxLength,
    this.formateadores,
    this.onChanged,
    this.onSubmitted,
    this.lineas = 1,
    this.mayusculas = TextCapitalization.none,
    this.extra,
    this.focusNode,
    this.autofocus = false,
  });

  final String etiqueta;
  final TextEditingController controller;
  final bool opcional;
  final String? hint;
  final String? ayuda;
  final String? mensaje;
  final EstadoCampo estado;
  final bool contrasena;
  final TextInputType? teclado;
  final TextInputAction? accion;
  final Iterable<String>? autofill;
  final int? maxLength;
  final List<TextInputFormatter>? formateadores;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int lineas;
  final TextCapitalization mayusculas;

  /// Algo debajo del campo (barra de fuerza, sugerencias).
  final Widget? extra;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<LbCampo> createState() => _LbCampoState();
}

class _LbCampoState extends State<LbCampo> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    final colorEstado = switch (widget.estado) {
      EstadoCampo.bien => lb.verde,
      EstadoCampo.mal => lb.rojoInterfaz,
      _ => null,
    };
    final raya = colorEstado == null
        ? null
        : UnderlineInputBorder(borderSide: BorderSide(color: colorEstado, width: 2));

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LbEtiqueta(widget.etiqueta, opcional: widget.opcional),
          TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            obscureText: widget.contrasena && !_visible,
            enableSuggestions: !widget.contrasena,
            autocorrect: false,
            keyboardType: widget.teclado,
            textInputAction: widget.accion,
            autofillHints: widget.autofill,
            maxLength: widget.maxLength,
            maxLines: widget.contrasena ? 1 : widget.lineas,
            minLines: widget.lineas > 1 ? widget.lineas : null,
            inputFormatters: widget.formateadores,
            textCapitalization: widget.mayusculas,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            style: TextStyle(fontSize: 16.5, height: 1.3, color: lb.tinta),
            decoration: InputDecoration(
              hintText: widget.hint,
              counterText: '',
              enabledBorder: raya,
              focusedBorder: raya != null && widget.estado == EstadoCampo.mal ? raya : null,
              suffixIconConstraints: const BoxConstraints(minHeight: 36),
              suffixIcon: widget.contrasena
                  ? TextButton(
                      onPressed: () => setState(() => _visible = !_visible),
                      style: TextButton.styleFrom(
                        foregroundColor: lb.azul,
                        minimumSize: const Size(60, 36),
                        textStyle: const TextStyle(
                            fontFamily: AppTheme.fuenteTexto, fontWeight: FontWeight.w700, fontSize: 12.8),
                      ),
                      child: Text(_visible ? 'Ocultar' : 'Mostrar'),
                    )
                  : widget.estado == EstadoCampo.cargando
                      ? Padding(padding: const EdgeInsets.all(9), child: Aro(size: 16, color: lb.grisTexto))
                      : null,
            ),
          ),
          if (widget.extra != null) widget.extra!,
          if (widget.mensaje != null && widget.mensaje!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                widget.mensaje!,
                style: TextStyle(fontSize: 12.8, fontWeight: FontWeight.w700, height: 1.35, color: colorEstado ?? lb.grisTexto),
              ),
            ),
          if (widget.ayuda != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(widget.ayuda!, style: TextStyle(fontSize: 12.8, height: 1.35, color: lb.grisTexto)),
            ),
        ],
      ),
    );
  }
}

/// Lista desplegable con etiqueta y raya inferior (.al-campo select, .al-filtro-ruta).
class LbSelect<T> extends StatelessWidget {
  const LbSelect({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.opciones,
    required this.onChanged,
    this.ayuda,
    this.enLinea = false,
    this.habilitado = true,
    this.error = false,
  });

  final String etiqueta;
  final T? valor;
  final List<(T?, String)> opciones;
  final ValueChanged<T?> onChanged;
  final String? ayuda;

  /// Etiqueta a la izquierda y raya de 1 px (filtros de la lista).
  final bool enLinea;
  final bool habilitado;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    final raya = UnderlineInputBorder(
      borderSide: BorderSide(color: error ? lb.rojoInterfaz : lb.tinta, width: enLinea ? 1 : 2),
    );
    final lista = DropdownButtonFormField<T?>(
      initialValue: opciones.any((o) => o.$1 == valor) ? valor : null,
      key: ValueKey('$etiqueta-$valor-${opciones.length}-$habilitado'),
      isExpanded: true,
      onChanged: habilitado ? onChanged : null,
      dropdownColor: lb.blanco,
      iconEnabledColor: lb.tinta,
      style: TextStyle(fontFamily: AppTheme.fuenteTexto, fontSize: 15.5, color: lb.tinta),
      decoration: InputDecoration(
        border: raya,
        enabledBorder: raya,
        disabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: lb.linea, width: enLinea ? 1 : 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      ),
      items: [
        for (final o in opciones)
          DropdownMenuItem<T?>(value: o.$1, child: Text(o.$2, overflow: TextOverflow.ellipsis)),
      ],
    );

    if (enLinea) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            Text(etiqueta, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.2, color: lb.tinta)),
            const SizedBox(width: 12),
            Expanded(child: lista),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LbEtiqueta(etiqueta),
          lista,
          if (ayuda != null && ayuda!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(ayuda!, style: TextStyle(fontSize: 12.8, height: 1.35, color: lb.grisTexto)),
            ),
        ],
      ),
    );
  }
}

/// Ventana modal (.al-modal-caja): borde superior de tinta, título y botón ×.
Future<T?> mostrarModal<T>(BuildContext context, {required String titulo, required WidgetBuilder contenido}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: const Color(0x8C080707),
    transitionDuration: const Duration(milliseconds: 250),
    transitionBuilder: (context, anim, _, child) {
      final c = CurvedAnimation(parent: anim, curve: curvaSuave);
      return FadeTransition(
        opacity: c,
        child: SlideTransition(position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(c), child: child),
      );
    },
    pageBuilder: (context, _, _) => _Modal(titulo: titulo, contenido: contenido),
  );
}

class _Modal extends StatelessWidget {
  const _Modal({required this.titulo, required this.contenido});

  final String titulo;
  final WidgetBuilder contenido;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    final teclado = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + teclado),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Material(
              color: lb.blanco,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radioVentana)),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: lb.tinta, width: 4))),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: lb.linea))),
                        child: Row(
                          children: [
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(titulo, style: AppTheme.titulo(size: 24, color: lb.tinta)),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Cerrar',
                              onPressed: () => Navigator.of(context).pop(),
                              style: IconButton.styleFrom(foregroundColor: lb.tinta, minimumSize: const Size(40, 40)),
                              icon: const Text('×', style: TextStyle(fontSize: 26, height: 1)),
                            ),
                          ],
                        ),
                      ),
                      contenido(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de botones al pie de un formulario (.al-acciones): a la derecha, y apilados si no caben.
class LbAcciones extends StatelessWidget {
  const LbAcciones({super.key, required this.botones, this.apiladas = false});

  final List<Widget> botones;
  final bool apiladas;

  @override
  Widget build(BuildContext context) {
    if (apiladas) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final b in botones) Padding(padding: const EdgeInsets.only(top: 8), child: b),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: botones),
    );
  }
}

/// Insignia del estado de una ruta (.route-badge, .ru-insignia).
class InsigniaRuta extends StatelessWidget {
  const InsigniaRuta({super.key, required this.estado, required this.texto});

  final String estado;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    final (borde, fondo, letra) = switch (estado) {
      'Fuera_servicio' => (lb.rojoInterfaz, Colors.transparent, lb.rojoInterfaz),
      'Sin_buses' => (lb.amarillo, lb.amarillo, lb.sobreAmarillo),
      'Fuera_horario' => (lb.linea, lb.concreto, lb.grisTexto),
      _ => (lb.grisTexto, Colors.transparent, lb.tinta),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: fondo,
        border: Border.all(color: borde),
        borderRadius: BorderRadius.circular(AppTheme.radio),
      ),
      child: Text(texto, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: letra)),
    );
  }
}

/// Por qué la ruta no está activa (.route-motivo): texto con raya izquierda del color del estado.
class MotivoRuta extends StatelessWidget {
  const MotivoRuta({super.key, required this.estado, required this.texto});

  final String estado;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    final raya = switch (estado) {
      'Sin_buses' => lb.amarillo,
      'Fuera_horario' => lb.linea,
      _ => lb.rojoInterfaz,
    };
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: raya, width: 2))),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 13.1,
          height: 1.35,
          color: estado == 'Fuera_horario' ? lb.grisTexto : lb.tinta,
        ),
      ),
    );
  }
}

/// Origen y destino como un tramo de línea de metro (.route-trayecto).
class TrayectoRuta extends StatelessWidget {
  const TrayectoRuta({super.key, required this.origen, required this.destino, required this.color, this.lineas});

  final String origen;
  final String destino;
  final Color color;

  /// Máximo de líneas de cada parada (null = todas).
  final int? lineas;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    Widget punto(bool lleno) => Container(
          width: 10.4,
          height: 10.4,
          decoration: BoxDecoration(
            color: lleno ? color : lb.blanco,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        );
    Widget parada(String texto, bool destino) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 4.5), child: punto(destino)),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                texto,
                maxLines: lineas,
                overflow: lineas == null ? null : TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15.2, height: 1.3, color: lb.tinta),
              ),
            ),
          ],
        );
    return Stack(
      children: [
        Positioned(left: 4.2, top: 10, bottom: 10, child: Container(width: 2, color: color)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [parada(origen, false), const SizedBox(height: 6), parada(destino, true)],
        ),
      ],
    );
  }
}

/// Avatar con las iniciales sobre el color elegido en el perfil.
class AvatarIniciales extends StatelessWidget {
  const AvatarIniciales({super.key, required this.iniciales, required this.color, this.size = 36});

  final String iniciales;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          iniciales,
          style: AppTheme.titulo(size: size * 0.42, color: Colors.white, height: 1),
        ),
      );
}

/// Un dato con su etiqueta (.detail-field, .al-detalle).
class LbDato extends StatelessWidget {
  const LbDato({super.key, required this.etiqueta, this.valor, this.hijo});

  final String etiqueta;
  final String? valor;
  final Widget? hijo;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: lb.linea))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: TextStyle(fontSize: 12.8, color: lb.grisTexto)),
          const SizedBox(height: 2),
          hijo ?? Text(valor ?? '-', style: TextStyle(fontSize: 15.5, height: 1.4, color: lb.tinta)),
        ],
      ),
    );
  }
}
