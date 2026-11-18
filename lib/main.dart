import 'package:flutter/material.dart';
import 'screens/mapa_screen.dart';
import 'screens/rutas_screen.dart';
import 'screens/alertas_screen.dart';
import 'tema.dart';
import 'utils/seleccion.dart';

void main() {
  runApp(const MonitorApp());
}

class MonitorApp extends StatelessWidget {
  const MonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LocalBus Monitor',
      debugShowCheckedModeBanner: false,
      // Igual que la web: sigue el tema claro u oscuro del dispositivo
      theme: temaLocalBus(Brightness.light),
      darkTheme: temaLocalBus(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final SeleccionRuta _seleccion = SeleccionRuta();

  // Se crean una sola vez: IndexedStack las mantiene vivas al cambiar de pestaña, así el mapa
  // conserva su zoom y posición y no se vuelve a descargar todo cada vez.
  late final List<Widget> _screens = [
    MapaScreen(seleccion: _seleccion),
    RutasScreen(onVerEnMapa: _verEnMapa),
    AlertasScreen(onVerEnMapa: _verEnMapa),
  ];

  void _verEnMapa(int rutaId) {
    _seleccion.elegir(rutaId);
    setState(() => _currentIndex = 0);
  }

  @override
  void dispose() {
    _seleccion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _BarraPestanas(
        actual: _currentIndex,
        alElegir: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

/// Pestañas inferiores: la activa lleva una línea azul de 3 px arriba y el texto en azul.
class _BarraPestanas extends StatelessWidget {
  final int actual;
  final ValueChanged<int> alElegir;

  const _BarraPestanas({required this.actual, required this.alElegir});

  static const _pestanas = [
    (Icons.map_outlined, Icons.map, 'Mapa'),
    (Icons.alt_route, Icons.alt_route, 'Rutas'),
    (Icons.notifications_none, Icons.notifications, 'Alertas'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      decoration: BoxDecoration(
        color: c.fondo,
        border: Border(top: BorderSide(color: c.linea)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < _pestanas.length; i++)
              Expanded(child: _pestana(context, i)),
          ],
        ),
      ),
    );
  }

  Widget _pestana(BuildContext context, int i) {
    final c = context.colores;
    final (icono, iconoActivo, texto) = _pestanas[i];
    final activa = i == actual;
    final color = activa ? c.azul : c.grisTexto;

    return Semantics(
      selected: activa,
      button: true,
      label: texto,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => alElegir(i),
        child: AnimatedContainer(
          duration: duracionCorta,
          curve: curvaSuave,
          height: 60,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: activa ? c.azul : Colors.transparent, width: 3),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(activa ? iconoActivo : icono, color: color),
              const SizedBox(height: 2),
              Text(
                texto,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: activa ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
