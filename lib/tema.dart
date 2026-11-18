// Identidad visual de LocalBus, la misma de la web (docs/GUIA_DE_DISENO.md y base.css):
// blanco predominante con negro, azul y rojo de la marca; verde y amarillo solo como estado;
// cada ruta con su color de placa; esquinas casi rectas y estructura con líneas de 1 px.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Papel de un color de estado. El color nunca va solo: siempre acompaña a un texto.
enum Tono {
  /// Correcto o en vivo (verde).
  exito,

  /// Advertencia (amarillo, con texto negro encima).
  advertencia,

  /// Neutro o sin actividad (gris).
  neutro,

  /// Error, demora, fuera de servicio (rojo de interfaz).
  peligro,

  /// Información, acción o selección (azul).
  accion,
}

/// Tokens de color. Los valores son los de base.css en tema claro y oscuro.
@immutable
class ColoresLocalBus extends ThemeExtension<ColoresLocalBus> {
  final Color fondo;
  final Color tinta;
  final Color concreto;
  final Color linea;
  final Color grisTexto;
  final Color azul;
  final Color rojo;
  final Color rojoInterfaz;
  final Color verde;
  final Color amarillo;

  const ColoresLocalBus({
    required this.fondo,
    required this.tinta,
    required this.concreto,
    required this.linea,
    required this.grisTexto,
    required this.azul,
    required this.rojo,
    required this.rojoInterfaz,
    required this.verde,
    required this.amarillo,
  });

  static const claro = ColoresLocalBus(
    fondo: Color(0xFFFFFFFF),
    tinta: Color(0xFF080707),
    concreto: Color(0xFFEEF0F1),
    linea: Color(0xFFD3D8DB),
    grisTexto: Color(0xFF5B646B),
    azul: Color(0xFF014CAB),
    rojo: Color(0xFFFE151E),
    rojoInterfaz: Color(0xFFD4121A),
    verde: Color(0xFF187A45),
    amarillo: Color(0xFFF7C600),
  );

  // Pares invertidos: fondo oscuro y tinta clara; azul, rojo y verde aclarados para mantener 4,5:1
  static const oscuro = ColoresLocalBus(
    fondo: Color(0xFF121517),
    tinta: Color(0xFFE9ECEE),
    concreto: Color(0xFF1F2529),
    linea: Color(0xFF353D43),
    grisTexto: Color(0xFFA1AAB1),
    azul: Color(0xFF78AEFF),
    rojo: Color(0xFFFF3B42),
    rojoInterfaz: Color(0xFFFF6B70),
    verde: Color(0xFF4CC38A),
    amarillo: Color(0xFFF7C600),
  );

  /// Texto sobre colores fijos (placas de ruta, marcadores): blanco en los dos temas.
  static const Color sobreColor = Color(0xFFFFFFFF);

  /// Texto sobre el amarillo de advertencia: negro en los dos temas.
  static const Color sobreAmarillo = Color(0xFF080707);

  Color de(Tono tono) {
    switch (tono) {
      case Tono.exito:
        return verde;
      case Tono.advertencia:
        return amarillo;
      case Tono.neutro:
        return grisTexto;
      case Tono.peligro:
        return rojoInterfaz;
      case Tono.accion:
        return azul;
    }
  }

  /// Color del texto sobre un relleno de ese tono. En tema oscuro los tonos son claros y llevan
  /// texto oscuro encima (el fondo); el amarillo lleva negro siempre.
  Color sobre(Tono tono) => tono == Tono.advertencia ? sobreAmarillo : fondo;

  @override
  ColoresLocalBus copyWith({
    Color? fondo,
    Color? tinta,
    Color? concreto,
    Color? linea,
    Color? grisTexto,
    Color? azul,
    Color? rojo,
    Color? rojoInterfaz,
    Color? verde,
    Color? amarillo,
  }) {
    return ColoresLocalBus(
      fondo: fondo ?? this.fondo,
      tinta: tinta ?? this.tinta,
      concreto: concreto ?? this.concreto,
      linea: linea ?? this.linea,
      grisTexto: grisTexto ?? this.grisTexto,
      azul: azul ?? this.azul,
      rojo: rojo ?? this.rojo,
      rojoInterfaz: rojoInterfaz ?? this.rojoInterfaz,
      verde: verde ?? this.verde,
      amarillo: amarillo ?? this.amarillo,
    );
  }

  @override
  ColoresLocalBus lerp(ThemeExtension<ColoresLocalBus>? other, double t) {
    if (other is! ColoresLocalBus) return this;
    return ColoresLocalBus(
      fondo: Color.lerp(fondo, other.fondo, t)!,
      tinta: Color.lerp(tinta, other.tinta, t)!,
      concreto: Color.lerp(concreto, other.concreto, t)!,
      linea: Color.lerp(linea, other.linea, t)!,
      grisTexto: Color.lerp(grisTexto, other.grisTexto, t)!,
      azul: Color.lerp(azul, other.azul, t)!,
      rojo: Color.lerp(rojo, other.rojo, t)!,
      rojoInterfaz: Color.lerp(rojoInterfaz, other.rojoInterfaz, t)!,
      verde: Color.lerp(verde, other.verde, t)!,
      amarillo: Color.lerp(amarillo, other.amarillo, t)!,
    );
  }
}

extension ColoresDelContexto on BuildContext {
  ColoresLocalBus get colores => Theme.of(this).extension<ColoresLocalBus>() ?? ColoresLocalBus.claro;
}

/// Colores de placa de ruta, asignados con `id % 7` igual que la web (PALETA_RUTAS en home.js).
/// Sin rojo, azul, amarillo ni verde, para no confundirse con alertas, acciones o estados.
/// Todos tienen contraste de 4,5:1 o más con texto blanco.
const List<Color> paletaRutas = [
  Color(0xFF087F8C), // turquesa
  Color(0xFF6B3FA0), // violeta
  Color(0xFFB85C00), // ámbar
  Color(0xFFA82A7B), // magenta
  Color(0xFF5C6B1E), // oliva
  Color(0xFF7A4A2B), // café
  Color(0xFF3F5B7A), // pizarra
];

/// Placa de una ruta sin id conocido.
const Color placaNeutra = Color(0xFF080707);

Color colorDeRuta(int? id) => id == null ? placaNeutra : paletaRutas[id.abs() % paletaRutas.length];

/// Barlow Condensed: títulos, códigos de ruta, placas y cifras.
TextStyle estiloTitulo({double size = 22, FontWeight weight = FontWeight.w700, Color? color}) {
  return GoogleFonts.barlowCondensed(
    fontSize: size,
    fontWeight: weight,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// Esquinas casi rectas: 3 px en botones y placas, 4 px en ventanas y fichas.
const BorderRadius esquinaPequena = BorderRadius.all(Radius.circular(3));
const BorderRadius esquinaFicha = BorderRadius.all(Radius.circular(4));

/// Curva y duración de los movimientos (cortos y sin rebote).
const Curve curvaSuave = Cubic(0.22, 0.61, 0.36, 1);
const Duration duracionCorta = Duration(milliseconds: 250);

ThemeData temaLocalBus(Brightness brillo) {
  final c = brillo == Brightness.dark ? ColoresLocalBus.oscuro : ColoresLocalBus.claro;

  final esquema = ColorScheme(
    brightness: brillo,
    primary: c.azul,
    onPrimary: c.fondo,
    secondary: c.tinta,
    onSecondary: c.fondo,
    error: c.rojoInterfaz,
    onError: c.fondo,
    surface: c.fondo,
    onSurface: c.tinta,
    onSurfaceVariant: c.grisTexto,
    surfaceContainerHighest: c.concreto,
    outline: c.linea,
    outlineVariant: c.linea,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: esquema);
  final texto = GoogleFonts.atkinsonHyperlegibleTextTheme(base.textTheme)
      .apply(bodyColor: c.tinta, displayColor: c.tinta);

  const relleno = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  const forma = RoundedRectangleBorder(borderRadius: esquinaPequena);

  return base.copyWith(
    scaffoldBackgroundColor: c.fondo,
    canvasColor: c.fondo,
    textTheme: texto,
    extensions: [c],
    dividerTheme: DividerThemeData(color: c.linea, thickness: 1, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.azul),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.fondo,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      showDragHandle: true,
      dragHandleColor: c.linea,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.fondo,
      selectedColor: c.tinta,
      checkmarkColor: c.fondo,
      side: BorderSide(color: c.linea),
      shape: forma,
      showCheckmark: false,
    ),
    // Botón principal: tinta; secundario: borde de 1 px de tinta; texto: azul (es lo que se toca)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.tinta,
        foregroundColor: c.fondo,
        elevation: 0,
        shape: forma,
        padding: relleno,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.tinta,
        side: BorderSide(color: c.tinta),
        shape: forma,
        padding: relleno,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.azul,
        shape: forma,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
}
