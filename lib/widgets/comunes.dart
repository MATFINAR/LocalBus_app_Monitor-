import 'package:flutter/material.dart';
import '../tema.dart';
import '../utils/estados.dart';

/// Barra superior: fondo blanco (o el del tema oscuro), título en Barlow Condensed y línea inferior de 1 px.
AppBar barraSuperior(BuildContext context, String titulo, {List<Widget>? acciones}) {
  final c = context.colores;
  return AppBar(
    backgroundColor: c.fondo,
    foregroundColor: c.tinta,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    title: Text(titulo, style: estiloTitulo(size: 28, color: c.tinta)),
    shape: Border(bottom: BorderSide(color: c.linea)),
    actions: acciones,
  );
}

/// Campo de texto con solo una línea inferior de 2 px (azul con el foco).
InputDecoration decoracionCampo(
  BuildContext context, {
  required String etiqueta,
  String? ayuda,
  Widget? prefijo,
  Widget? sufijo,
}) {
  final c = context.colores;
  final linea = UnderlineInputBorder(borderSide: BorderSide(color: c.tinta, width: 2));
  return InputDecoration(
    labelText: etiqueta,
    hintText: ayuda,
    prefixIcon: prefijo,
    suffixIcon: sufijo,
    labelStyle: TextStyle(color: c.grisTexto),
    floatingLabelStyle: TextStyle(color: c.azul),
    hintStyle: TextStyle(color: c.grisTexto),
    border: linea,
    enabledBorder: linea,
    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.azul, width: 2)),
    contentPadding: const EdgeInsets.symmetric(vertical: 10),
  );
}

/// Desplegable con la misma línea inferior que los campos de texto.
class Desplegable<T> extends StatelessWidget {
  final String etiqueta;
  final T valor;
  final Map<T, String> opciones;
  final ValueChanged<T?> alCambiar;

  const Desplegable({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.opciones,
    required this.alCambiar,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: decoracionCampo(context, etiqueta: etiqueta),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: valor,
          isExpanded: true,
          isDense: true,
          items: opciones.entries
              .map((o) => DropdownMenuItem<T>(
                    value: o.key,
                    child: Text(o.value, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: alCambiar,
        ),
      ),
    );
  }
}

/// Placa de ruta: el código en Barlow Condensed sobre el color de la ruta, como en el parabrisas.
class PlacaRuta extends StatelessWidget {
  final String codigo;
  final int? rutaId;
  final double tamano;

  const PlacaRuta({super.key, required this.codigo, required this.rutaId, this.tamano = 15});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ruta $codigo',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: tamano * 0.5, vertical: tamano * 0.12),
        decoration: BoxDecoration(color: colorDeRuta(rutaId), borderRadius: esquinaPequena),
        child: Text(
          codigo,
          style: estiloTitulo(size: tamano, color: ColoresLocalBus.sobreColor),
        ),
      ),
    );
  }
}

/// Insignia de estado: borde de 1 px y texto del color del tono. La de advertencia va rellena de
/// amarillo con texto negro (el amarillo sobre blanco no se lee). Con [relleno], fondo del tono.
class Insignia extends StatelessWidget {
  final Etiqueta etiqueta;
  final bool relleno;

  const Insignia(this.etiqueta, {super.key, this.relleno = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final color = c.de(etiqueta.tono);
    final lleno = relleno || etiqueta.tono == Tono.advertencia;
    final texto = lleno ? c.sobre(etiqueta.tono) : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: lleno ? color : null,
        border: Border.all(color: color),
        borderRadius: esquinaPequena,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(etiqueta.icono, size: 13, color: texto),
          const SizedBox(width: 4),
          Text(
            etiqueta.texto,
            style: TextStyle(color: texto, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Ficha con borde de 1 px, sin sombra. Puede llevar una franja de color arriba o a la izquierda
/// (el color de la ruta o del tipo de alerta).
class Ficha extends StatelessWidget {
  final Widget child;
  final Color? franjaSuperior;
  final Color? franjaIzquierda;
  final EdgeInsetsGeometry padding;

  const Ficha({
    super.key,
    required this.child,
    this.franjaSuperior,
    this.franjaIzquierda,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    Widget contenido = Padding(padding: padding, child: child);

    if (franjaIzquierda != null) {
      contenido = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: franjaIzquierda),
            Expanded(child: contenido),
          ],
        ),
      );
    }
    if (franjaSuperior != null) {
      contenido = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: franjaSuperior),
          contenido,
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.fondo,
        border: Border.all(color: c.linea),
        borderRadius: esquinaFicha,
      ),
      child: ClipRRect(borderRadius: esquinaFicha, child: contenido),
    );
  }
}

/// Título de sección con su conteo.
class EncabezadoSeccion extends StatelessWidget {
  final String titulo;
  final int? cantidad;

  const EncabezadoSeccion(this.titulo, {super.key, this.cantidad});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Semantics(
        header: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(titulo, style: estiloTitulo(size: 22, color: c.tinta)),
            if (cantidad != null) ...[
              const SizedBox(width: 8),
              Text('$cantidad', style: estiloTitulo(size: 18, weight: FontWeight.w500, color: c.grisTexto)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dato con su etiqueta encima: "Distancia / 4,4 km".
class DatoEtiquetado extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const DatoEtiquetado(this.etiqueta, this.valor, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: TextStyle(fontSize: 12, color: c.grisTexto)),
        Text(valor, style: estiloTitulo(size: 20, weight: FontWeight.w600, color: c.tinta)),
      ],
    );
  }
}

/// Origen y destino unidos por una línea del color de la ruta (origen hueco, destino lleno).
class Recorrido extends StatelessWidget {
  final String origen;
  final String destino;
  final Color color;

  const Recorrido({super.key, required this.origen, required this.destino, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final estilo = TextStyle(fontSize: 14, color: c.tinta);

    Widget punto({required bool lleno}) => Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: lleno ? color : c.fondo,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
        );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              const SizedBox(height: 4),
              punto(lleno: false),
              Expanded(child: Container(width: 3, color: color)),
              punto(lleno: true),
              const SizedBox(height: 4),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Semantics(label: 'Origen', child: Text(origen, style: estilo)),
                const SizedBox(height: 14),
                Semantics(label: 'Destino', child: Text(destino, style: estilo)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Punto verde que late para la información en vivo. Quieto si el sistema pide menos movimiento.
class PuntoEnVivo extends StatefulWidget {
  final double tamano;
  const PuntoEnVivo({super.key, this.tamano = 10});

  @override
  State<PuntoEnVivo> createState() => _PuntoEnVivoState();
}

class _PuntoEnVivoState extends State<PuntoEnVivo> with SingleTickerProviderStateMixin {
  late final AnimationController _latido = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _latido.stop();
      _latido.value = 0;
    } else if (!_latido.isAnimating) {
      _latido.repeat();
    }
  }

  @override
  void dispose() {
    _latido.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final verde = context.colores.verde;
    final t = widget.tamano;
    return SizedBox(
      width: t * 2,
      height: t * 2,
      child: AnimatedBuilder(
        animation: _latido,
        builder: (context, _) {
          final v = Curves.easeOut.transform(_latido.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              // Onda que se abre y se desvanece
              Container(
                width: t * (1 + v),
                height: t * (1 + v),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: verde.withValues(alpha: 0.35 * (1 - v)),
                ),
              ),
              Container(
                width: t,
                height: t,
                decoration: BoxDecoration(shape: BoxShape.circle, color: verde),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Espera: aro que gira junto a un texto en gerundio.
class EstadoCargando extends StatelessWidget {
  final String texto;
  const EstadoCargando(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(width: 12),
            Text(texto, style: TextStyle(color: context.colores.grisTexto)),
          ],
        ),
      ),
    );
  }
}

/// Error: qué pasó y cómo seguir.
class EstadoError extends StatelessWidget {
  final String titulo;
  final String mensaje;
  final VoidCallback onReintentar;

  const EstadoError({super.key, required this.titulo, required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 40, color: c.rojoInterfaz),
            const SizedBox(height: 12),
            Text(titulo, textAlign: TextAlign.center, style: estiloTitulo(size: 24, color: c.tinta)),
            const SizedBox(height: 8),
            Text(mensaje, textAlign: TextAlign.center, style: TextStyle(color: c.grisTexto)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vacío: dice qué falta y, si se puede, qué hacer.
class EstadoVacio extends StatelessWidget {
  final String texto;
  final String? accion;
  final VoidCallback? onAccion;

  const EstadoVacio(this.texto, {super.key, this.accion, this.onAccion});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: context.colores.concreto, borderRadius: esquinaFicha),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(texto, style: const TextStyle(fontSize: 14)),
          if (accion != null && onAccion != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: onAccion,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(accion!),
            ),
          ],
        ],
      ),
    );
  }
}
