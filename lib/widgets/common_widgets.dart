import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Botón de la barra superior para alternar entre tema claro y oscuro.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? 'Usar tema claro' : 'Usar tema oscuro',
      icon: Icon(
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      ),
      onPressed: () {
        AppTheme.mode.value = isDark ? ThemeMode.light : ThemeMode.dark;
      },
    );
  }
}

/// Placa de ruta: el código en Barlow Condensed sobre el color de la ruta.
class PlacaRuta extends StatelessWidget {
  const PlacaRuta({
    super.key,
    required this.codigo,
    required this.color,
    this.size = 17,
  });

  final String codigo;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radio),
      ),
      child: Text(
        codigo,
        style: AppTheme.titulo(size: size, color: context.lb.sobreColor),
      ),
    );
  }
}

/// Insignia con borde de 1 px. Solo para estados que no son lo normal.
class LbBadge extends StatelessWidget {
  const LbBadge({
    super.key,
    required this.label,
    required this.color,
    this.textColor,
    this.fill,
    this.icon,
  });

  final String label;

  /// Color del borde (y del texto si no se indica otro).
  final Color color;
  final Color? textColor;

  /// Relleno opcional (por ejemplo, el amarillo de advertencia).
  final Color? fill;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(AppTheme.radio),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Punto que late para indicar información en vivo. Con movimiento reducido
/// queda fijo (el texto que lo acompaña sigue diciendo el estado).
class EnVivoDot extends StatefulWidget {
  const EnVivoDot({super.key, this.size = 9});

  final double size;

  @override
  State<EnVivoDot> createState() => _EnVivoDotState();
}

class _EnVivoDotState extends State<EnVivoDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  bool _animar = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducido = MediaQuery.of(context).disableAnimations;
    if (!reducido && !_animar) {
      _animar = true;
      _controller.repeat(reverse: true);
    } else if (reducido && _animar) {
      _animar = false;
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.lb.verde;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return SizedBox(
          width: widget.size + 8,
          height: widget.size + 8,
          child: Center(
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45 * (1 - t)),
                    blurRadius: 0,
                    spreadRadius: 1 + 3 * t,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Espera corta: aro que gira junto a un verbo en gerundio.
class CargandoTexto extends StatelessWidget {
  const CargandoTexto(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        const SizedBox(width: 12),
        Text(
          texto,
          style: TextStyle(
            color: context.lb.grisTexto,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Estados vacíos o de error: dicen qué pasó y qué hacer.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.color,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Color del ícono. Por defecto, gris de apoyo.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 36, color: color ?? lb.grisTexto),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(
                  message!,
                  style: TextStyle(color: lb.grisTexto, height: 1.4),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
