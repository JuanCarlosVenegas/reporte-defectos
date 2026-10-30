import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Acceso a Firestore.
/// - reportes/{id}: un reporte (AVISO o DMR)
/// - fotos/{id}: una fotografía de evidencia (jpeg en base64)
/// - usuarios/{uid}: perfil y ajustes de cada usuario
class Db {
  static FirebaseFirestore get fs => FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get reportes =>
      fs.collection('reportes');
  static CollectionReference<Map<String, dynamic>> get fotos =>
      fs.collection('fotos');
  static DocumentReference<Map<String, dynamic>> usuario(String uid) =>
      fs.collection('usuarios').doc(uid);

  static Future<List<String>> cargarFotos(String reporteId) async {
    final QuerySnapshot<Map<String, dynamic>> snap =
        await fotos.where('reporte', isEqualTo: reporteId).get();
    final List<Map<String, dynamic>> docs =
        snap.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> d) => d.data()).toList();
    docs.sort((Map<String, dynamic> a, Map<String, dynamic> b) =>
        ((a['i'] as num?) ?? 0).compareTo((b['i'] as num?) ?? 0));
    return docs.map((Map<String, dynamic> d) => (d['img'] ?? '').toString()).toList();
  }
}

class Reporte {
  final String id;
  final Map<String, dynamic> d;
  Reporte(this.id, this.d);

  String s(String k) => (d[k] ?? '').toString();
  String get tipo => s('tipo');
  String get folio => s('folio');
  String get estado => s('estado');
  bool get resuelto => estado == 'resuelto';
  String get linea => s('linea');
  String get lote => s('lote');
  String get defecto => s('defecto');
  String get proveedor => s('proveedor');
  String get autor => s('autor');
  int get creado => (d['creado'] as num?)?.toInt() ?? 0;
  int get actualizado => (d['actualizado'] as num?)?.toInt() ?? 0;
  int get cerrado => (d['cerrado'] as num?)?.toInt() ?? 0;
  int get numFotos => (d['fotos'] as num?)?.toInt() ?? 0;

  Map<String, dynamic> get cantidades {
    final Object? c = d['cantidades'];
    if (c is Map) return Map<String, dynamic>.from(c);
    return <String, dynamic>{};
  }

  /// Texto "valor unidad" de una cantidad, o '' si está vacía.
  String cantidad(String k) {
    final Object? c = cantidades[k];
    if (c is Map) {
      final String v = (c['v'] ?? '').toString();
      final String u = (c['u'] ?? '').toString();
      if (v.isEmpty) return '';
      return '$v $u'.trim();
    }
    return '';
  }
}

String normalizar(String s) {
  const String con = 'áéíóúüñàèìòùÁÉÍÓÚÜÑÀÈÌÒÙ';
  const String sin = 'aeiouunaeiouAEIOUUNAEIOU';
  final StringBuffer b = StringBuffer();
  for (final int r in s.runes) {
    final String ch = String.fromCharCode(r);
    final int i = con.indexOf(ch);
    b.write(i >= 0 ? sin[i] : ch);
  }
  return b.toString().toLowerCase();
}

String dos(int n) => n.toString().padLeft(2, '0');

String fechaISO(DateTime d) => '${d.year}-${dos(d.month)}-${dos(d.day)}';

String fechaCorta(String iso) {
  if (iso.isEmpty) return '';
  final List<String> p = iso.split('-');
  if (p.length != 3) return iso;
  return '${p[2]}/${p[1]}/${p[0]}';
}

const List<String> _meses = <String>[
  'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
];

String fechaHora(int ms) {
  if (ms <= 0) return '';
  final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${dos(d.day)} ${_meses[d.month - 1]} ${d.year}, ${dos(d.hour)}:${dos(d.minute)}';
}

bool esHoy(int ms) {
  if (ms <= 0) return false;
  final DateTime a = DateTime.fromMillisecondsSinceEpoch(ms);
  final DateTime b = DateTime.now();
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String hace(int ms) {
  final int s = (DateTime.now().millisecondsSinceEpoch - ms) ~/ 1000;
  if (s < 60) return 'Ahora';
  if (s < 3600) return 'Hace ${s ~/ 60} min';
  if (s < 86400) return 'Hace ${s ~/ 3600} h';
  final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${dos(d.day)} ${_meses[d.month - 1]}';
}

String generarFolio(String tipo) {
  final DateTime d = DateTime.now();
  const String abc = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final Random r = Random();
  final String suf = List<String>.generate(3, (_) => abc[r.nextInt(abc.length)]).join();
  final String yy = (d.year % 100).toString().padLeft(2, '0');
  return '$tipo-$yy${dos(d.month)}${dos(d.day)}-${dos(d.hour)}${dos(d.minute)}-$suf';
}
