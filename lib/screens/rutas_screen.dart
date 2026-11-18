import 'package:flutter/material.dart';
import '../models/ruta.dart';
import '../services/api_service.dart';
import '../utils/estados.dart';
import '../utils/texto.dart';

class RutasScreen extends StatefulWidget {
  /// Abre el mapa con esta ruta elegida.
  final ValueChanged<int> onVerEnMapa;

  const RutasScreen({super.key, required this.onVerEnMapa});

  @override
  State<RutasScreen> createState() => _RutasScreenState();
}

class _RutasScreenState extends State<RutasScreen> {
  /// Orden de las pestañas de estado (null = todas).
  static const List<String?> _estados = [
    null,
    Ruta.activa,
    Ruta.sinBuses,
    Ruta.fueraHorario,
    Ruta.fueraServicio,
  ];

  final ApiService _apiService = ApiService();
  final TextEditingController _buscador = TextEditingController();
  List<Ruta> _rutas = [];
  bool _cargando = true;
  String? _error;

  String _busqueda = '';
  String? _empresa;
  String? _estado;

  @override
  void initState() {
    super.initState();
    _cargarRutas();
  }

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  Future<void> _cargarRutas() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final rutas = await _apiService.obtenerRutas();
      if (mounted) {
        setState(() {
          _rutas = rutas;
          _cargando = false;
          // Si la empresa elegida ya no tiene rutas, se quita el filtro
          if (_empresa != null && !rutas.any((r) => r.empresa == _empresa)) _empresa = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _cargando = false;
        });
      }
    }
  }

  void _quitarFiltros() {
    _buscador.clear();
    setState(() {
      _busqueda = '';
      _empresa = null;
      _estado = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛣️ Rutas'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargarRutas,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error al cargar rutas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _cargarRutas,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_rutas.isEmpty) {
      return const Center(
        child: Text('No hay rutas registradas'),
      );
    }

    // Búsqueda y empresa primero; los conteos de estado salen de ese resultado
    final candidatas = _rutas
        .where((r) => _empresa == null || r.empresa == _empresa)
        .where((r) => coincide(_busqueda, [r.codigo, r.nombre, r.origen, r.destino, r.empresa]))
        .toList();
    final visibles = candidatas.where((r) => _estado == null || r.estado == _estado).toList();

    return RefreshIndicator(
      onRefresh: _cargarRutas,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: visibles.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _filtros(candidatas, visibles.isEmpty);
          return _buildRutaCard(visibles[index - 1]);
        },
      ),
    );
  }

  Widget _filtros(List<Ruta> candidatas, bool sinResultados) {
    final empresas = _rutas.map((r) => r.empresa).where((e) => e.isNotEmpty).toSet().toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _buscador,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            labelText: 'Buscar ruta',
            hintText: 'Código, nombre, origen o destino',
            border: const OutlineInputBorder(),
            suffixIcon: _busqueda.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Borrar búsqueda',
                    onPressed: () {
                      _buscador.clear();
                      setState(() => _busqueda = '');
                    },
                  ),
          ),
          onChanged: (texto) => setState(() => _busqueda = texto),
        ),
        if (empresas.length > 1) ...[
          const SizedBox(height: 8),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Empresa',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _empresa,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Todas las empresas')),
                  ...empresas.map((e) => DropdownMenuItem<String?>(
                        value: e,
                        child: Text(e, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (valor) => setState(() => _empresa = valor),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _estados.map((estado) {
            final cantidad = estado == null
                ? candidatas.length
                : candidatas.where((r) => r.estado == estado).length;
            return ChoiceChip(
              label: Text('${_nombreEstado(estado)} ($cantidad)'),
              selected: _estado == estado,
              onSelected: (_) => setState(() => _estado = estado),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        if (sinResultados)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  const Text('Ninguna ruta coincide con estos filtros.'),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _quitarFiltros, child: const Text('Quitar filtros')),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _nombreEstado(String? estado) {
    if (estado == null) return 'Todas';
    switch (estado) {
      case Ruta.activa:
        return 'Activas';
      case Ruta.sinBuses:
        return 'Sin buses';
      case Ruta.fueraHorario:
        return 'Fuera de horario';
      case Ruta.fueraServicio:
        return 'Fuera de servicio';
      default:
        return estado;
    }
  }

  Widget _buildRutaCard(Ruta ruta) {
    final estado = etiquetaRuta(ruta);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade800,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ruta.codigo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ruta.nombre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _insigniaEstado(estado),
              ],
            ),
            if (ruta.empresa.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(ruta.empresa, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ],
            if (ruta.motivo.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: estado.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ruta.motivo,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _infoRow(Icons.trip_origin, 'Origen', ruta.origen),
            const SizedBox(height: 6),
            _infoRow(Icons.place, 'Destino', ruta.destino),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem(Icons.route, '${ruta.distanciaKm.toStringAsFixed(1)} km'),
                _statItem(Icons.access_time, '${ruta.duracionEstimadaMinutos} min'),
                _statItem(Icons.location_on, '${ruta.numParadas} paradas'),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ruta.tieneRecorrido
                  ? TextButton.icon(
                      onPressed: () => widget.onVerEnMapa(ruta.id),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Ver en el mapa'),
                    )
                  : Text(
                      'Sin recorrido trazado',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _insigniaEstado(Etiqueta estado) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: estado.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estado.icono, size: 13, color: estado.color),
          const SizedBox(width: 4),
          Text(
            estado.texto,
            style: TextStyle(
              color: estado.color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blue),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _statItem(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 22),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
