import 'package:flutter/material.dart';
import 'screens/mapa_screen.dart';
import 'screens/rutas_screen.dart';
import 'screens/alertas_screen.dart';
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Segoe UI',
      ),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Mapa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.route),
            label: 'Rutas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning),
            label: 'Alertas',
          ),
        ],
      ),
    );
  }
}
