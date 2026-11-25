import 'package:flutter/material.dart';

/// Tokens de diseño de LocalBus, tomados de docs/GUIA_DE_DISENO.md del sitio web.
///
/// Reglas de la marca: el blanco predomina, con negro (tinta), azul y rojo.
/// El azul es lo que se toca o está seleccionado; el rojo es marca y alertas;
/// verde y amarillo solo indican estado. Cada ruta tiene su propio color.
@immutable
class LbColors extends ThemeExtension<LbColors> {
  const LbColors({
    required this.blanco,
    required this.tinta,
    required this.azul,
    required this.rojo,
    required this.rojoInterfaz,
    required this.verde,
    required this.amarillo,
    required this.concreto,
    required this.linea,
    required this.grisTexto,
    required this.sobreColor,
    required this.sobreAmarillo,
    required this.azulClaro,
    required this.placaNeutra,
    required this.mapaFondo,
  });

  /// Fondo suave azul (--azul-claro).
  final Color azulClaro;

  /// Placa de una ruta sin color asignado.
  final Color placaNeutra;

  /// Fondo del mapa mientras cargan los mosaicos.
  final Color mapaFondo;

  /// Fondo de páginas, paneles y menú.
  final Color blanco;

  /// Texto y estructura: bordes, botones principales.
  final Color tinta;

  /// Acciones, selección, foco.
  final Color azul;

  /// Rojo de marca (logo y cosas grandes).
  final Color rojo;

  /// Rojo para texto pequeño, botones y errores (contraste 4,5:1).
  final Color rojoInterfaz;

  /// Correcto o en vivo.
  final Color verde;

  /// Advertencia.
  final Color amarillo;

  /// Fondo de hover y de elemento elegido.
  final Color concreto;

  /// Divisores de 1 px.
  final Color linea;

  /// Texto secundario.
  final Color grisTexto;

  /// Texto sobre un color fijo (placas de ruta): siempre blanco.
  final Color sobreColor;

  /// Texto sobre el amarillo: siempre negro.
  final Color sobreAmarillo;

  static const light = LbColors(
    blanco: Color(0xFFFEFEFE),
    tinta: Color(0xFF080707),
    azul: Color(0xFF014CAB),
    rojo: Color(0xFFFE151E),
    rojoInterfaz: Color(0xFFD4121A),
    verde: Color(0xFF187A45),
    amarillo: Color(0xFFF7C600),
    concreto: Color(0xFFEEF0F1),
    linea: Color(0xFFD3D8DB),
    grisTexto: Color(0xFF5B646B),
    sobreColor: Color(0xFFFFFFFF),
    sobreAmarillo: Color(0xFF080707),
    azulClaro: Color(0xFFE8F0FE),
    placaNeutra: Color(0xFF080707),
    mapaFondo: Color(0xFFE6E9EA),
  );

  static const dark = LbColors(
    blanco: Color(0xFF121517),
    tinta: Color(0xFFE9ECEE),
    azul: Color(0xFF78AEFF),
    rojo: Color(0xFFFF3B42),
    rojoInterfaz: Color(0xFFFF6B70),
    verde: Color(0xFF4CC38A),
    amarillo: Color(0xFFF7C600),
    concreto: Color(0xFF1F2529),
    linea: Color(0xFF353D43),
    grisTexto: Color(0xFFA1AAB1),
    sobreColor: Color(0xFFFFFFFF),
    sobreAmarillo: Color(0xFF080707),
    azulClaro: Color(0xFF13284A),
    placaNeutra: Color(0xFF4A535A),
    mapaFondo: Color(0xFF1B2024),
  );

  @override
  LbColors copyWith() => this;

  @override
  LbColors lerp(ThemeExtension<LbColors>? other, double t) {
    if (other is! LbColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return LbColors(
      blanco: mix(blanco, other.blanco),
      tinta: mix(tinta, other.tinta),
      azul: mix(azul, other.azul),
      rojo: mix(rojo, other.rojo),
      rojoInterfaz: mix(rojoInterfaz, other.rojoInterfaz),
      verde: mix(verde, other.verde),
      amarillo: mix(amarillo, other.amarillo),
      concreto: mix(concreto, other.concreto),
      linea: mix(linea, other.linea),
      grisTexto: mix(grisTexto, other.grisTexto),
      sobreColor: mix(sobreColor, other.sobreColor),
      sobreAmarillo: mix(sobreAmarillo, other.sobreAmarillo),
      azulClaro: mix(azulClaro, other.azulClaro),
      placaNeutra: mix(placaNeutra, other.placaNeutra),
      mapaFondo: mix(mapaFondo, other.mapaFondo),
    );
  }
}

extension LbContext on BuildContext {
  /// Tokens de marca del tema actual.
  LbColors get lb => Theme.of(this).extension<LbColors>()!;
}

class AppTheme {
  AppTheme._();

  /// Modo de tema actual. Por defecto sigue el ajuste del dispositivo.
  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static const String fuenteTitulo = 'Barlow Condensed';
  static const String fuenteTexto = 'Atkinson Hyperlegible';

  /// Esquinas casi rectas: 3 px en botones, placas y marcadores.
  static const double radio = 3;

  /// 4 px en ventanas flotantes.
  static const double radioVentana = 4;

  /// Los siete colores de ruta (asignados con id % 7). No incluyen rojo, azul,
  /// amarillo ni verde para que una ruta no se confunda con una alerta, una
  /// acción, una advertencia o un "en vivo". Todos pasan 4,5:1 con texto blanco.
  static const List<Color> coloresRuta = [
    Color(0xFF087F8C), // turquesa
    Color(0xFF6B3FA0), // violeta
    Color(0xFFB85C00), // ámbar
    Color(0xFFA82A7B), // magenta
    Color(0xFF5C6B1E), // oliva
    Color(0xFF7A4A2B), // café
    Color(0xFF3F5B7A), // pizarra
  ];

  static Color colorDeRuta(int idRuta) =>
      coloresRuta[idRuta.abs() % coloresRuta.length];

  /// Estilo de títulos, códigos de ruta, placas y cifras (Barlow Condensed).
  static TextStyle titulo({
    double size = 20,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: fuenteTitulo,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height ?? 1.1,
      letterSpacing: 0.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static ThemeData light() => _build(Brightness.light, LbColors.light);
  static ThemeData dark() => _build(Brightness.dark, LbColors.dark);

  static ThemeData _build(Brightness brightness, LbColors c) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.azul,
      onPrimary: isDark ? const Color(0xFF08162B) : Colors.white,
      primaryContainer:
          isDark ? const Color(0xFF13284A) : const Color(0xFFE3EDFA),
      onPrimaryContainer: c.azul,
      secondary: c.tinta,
      onSecondary: c.blanco,
      tertiary: c.verde,
      onTertiary: c.blanco,
      error: c.rojoInterfaz,
      onError: isDark ? const Color(0xFF2B0507) : Colors.white,
      surface: c.blanco,
      onSurface: c.tinta,
      onSurfaceVariant: c.grisTexto,
      outline: c.grisTexto,
      outlineVariant: c.linea,
      surfaceContainerLowest: c.blanco,
      surfaceContainerLow: c.blanco,
      surfaceContainer: c.blanco,
      surfaceContainerHigh: c.concreto,
      surfaceContainerHighest: c.concreto,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radio),
    );

    Color pressedBlue(Set<WidgetState> s, Color normal) =>
        s.contains(WidgetState.pressed) ||
                s.contains(WidgetState.hovered) ||
                s.contains(WidgetState.focused)
            ? c.azul
            : normal;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fuenteTexto,
    );

    final textTheme = base.textTheme
        .apply(bodyColor: c.tinta, displayColor: c.tinta)
        .copyWith(
          titleLarge: titulo(size: 26, color: c.tinta),
          titleMedium: titulo(size: 20, color: c.tinta),
          titleSmall: titulo(size: 17, weight: FontWeight.w600, color: c.tinta),
          labelLarge: const TextStyle(
            fontFamily: fuenteTexto,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        );

    return base.copyWith(
      extensions: [c],
      scaffoldBackgroundColor: c.blanco,
      textTheme: textTheme,
      dividerColor: c.linea,
      dividerTheme: DividerThemeData(color: c.linea, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.blanco,
        foregroundColor: c.tinta,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: titulo(size: 26, color: c.tinta),
        shape: Border(bottom: BorderSide(color: c.tinta, width: 2)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.tinta,
          shape: shape,
        ),
      ),
      // Botón principal: tinta; al tocarlo, azul.
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor:
              WidgetStateProperty.resolveWith((s) => pressedBlue(s, c.tinta)),
          foregroundColor: WidgetStatePropertyAll(c.blanco),
          shape: WidgetStatePropertyAll(shape),
          elevation: const WidgetStatePropertyAll(0),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: fuenteTexto,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
      // Botón secundario: borde de 1 px de tinta y fondo blanco; al tocarlo se invierte.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.pressed) ? c.tinta : c.blanco),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.pressed) ? c.blanco : c.tinta),
          side: WidgetStatePropertyAll(BorderSide(color: c.tinta)),
          shape: WidgetStatePropertyAll(shape),
          elevation: const WidgetStatePropertyAll(0),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: fuenteTexto,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
      // La barra inferior conserva su forma; solo toma los colores de la marca.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.blanco,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: fuenteTexto,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? c.azul : c.grisTexto,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? c.azul : c.grisTexto);
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.blanco,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.linea,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radioVentana),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.azul,
        circularTrackColor: c.linea,
      ),
      // Campos como en la web: solo una línea inferior de 2 px de tinta; azul al escribir
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
        hintStyle: const TextStyle(color: Color(0xFF7A838A)),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: c.tinta, width: 2),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: c.tinta, width: 2),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: c.azul, width: 2),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: c.rojoInterfaz, width: 2),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: c.rojoInterfaz, width: 2),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.azul,
        selectionColor: c.azul.withValues(alpha: 0.25),
        selectionHandleColor: c.azul,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.tinta : c.blanco),
        checkColor: WidgetStatePropertyAll(c.blanco),
        side: BorderSide(color: c.tinta, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.azul : c.tinta),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.blanco,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radioVentana),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.blanco,
        surfaceTintColor: Colors.transparent,
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
