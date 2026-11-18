String _dos(int n) => n.toString().padLeft(2, '0');

/// "Ahora", "Hace 5 min", "Hace 3 h", "Hace 2 días".
String haceCuanto(DateTime fecha, {DateTime? ahora}) {
  final diff = (ahora ?? DateTime.now()).difference(fecha);
  if (diff.isNegative || diff.inMinutes < 1) return 'Ahora';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
  return diff.inDays == 1 ? 'Hace 1 día' : 'Hace ${diff.inDays} días';
}

/// "14:05" en hora local.
String horaCorta(DateTime fecha) {
  final l = fecha.toLocal();
  return '${_dos(l.hour)}:${_dos(l.minute)}';
}

/// "14:05:09" en hora local.
String horaConSegundos(DateTime fecha) {
  final l = fecha.toLocal();
  return '${_dos(l.hour)}:${_dos(l.minute)}:${_dos(l.second)}';
}

/// "Hasta las 15:30" (hoy) o "Hasta el 18/11 a las 15:30".
String hastaCuando(DateTime vence, {DateTime? ahora}) {
  final l = vence.toLocal();
  final a = (ahora ?? DateTime.now()).toLocal();
  final mismoDia = l.year == a.year && l.month == a.month && l.day == a.day;
  if (mismoDia) return 'Hasta las ${horaCorta(vence)}';
  return 'Hasta el ${l.day}/${l.month} a las ${horaCorta(vence)}';
}
