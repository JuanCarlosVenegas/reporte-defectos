import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../catalogos.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets.dart';
import 'detalle.dart';

class DashboardView extends StatefulWidget {
  final User user;
  final Map<String, dynamic> perfil;
  final List<Reporte> reportes;
  final bool cargado;
  final String? error;
  final bool mostrarResumen;
  final VoidCallback onNuevo;
  final VoidCallback onPerfil;

  const DashboardView({
    super.key,
    required this.user,
    required this.perfil,
    required this.reportes,
    required this.cargado,
    required this.error,
    required this.mostrarResumen,
    required this.onNuevo,
    required this.onPerfil,
  });

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  String _q = '';
  String? _linea;
  String _estado = 'todos';

  List<Reporte> get _filtrados {
    final String q = normalizar(_q.trim());
    return widget.reportes.where((Reporte r) {
      if (_linea != null && r.linea != _linea) return false;
      if (_estado == 'activo' && r.resuelto) return false;
      if (_estado == 'resuelto' && !r.resuelto) return false;
      if (_estado == 'hoy' && !esHoy(r.creado)) return false;
      if (q.isNotEmpty) {
        final List<String> campos = <String>[
          r.lote, r.s('codigoMaterial'), r.s('nombreMaterial'), r.folio, r.s('pedidoSAP'), r.linea
        ];
        final String lq = q.replaceFirst(RegExp(r'^linea\s*'), '');
        final bool porLinea = normalizar(r.linea) == 'linea $lq';
        if (!porLinea && !campos.any((String c) => normalizar(c).contains(q))) return false;
      }
      return true;
    }).toList();
  }

  void _abrir(Reporte r) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (BuildContext _) => DetalleScreen(reporteId: r.id, user: widget.user, perfil: widget.perfil),
    ));
  }

  Widget _kpi(String id, int n, String label, Color col) {
    final Pal p = Pal.of(context);
    final bool on = _estado == id;
    return Expanded(
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: on ? col : p.line, width: on ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _estado = on ? 'todos' : id),
          child: Container(
            decoration: BoxDecoration(border: Border(left: BorderSide(color: col, width: 4))),
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text('$n',
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w800, height: 1,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()])),
              const SizedBox(height: 4),
              Etiqueta(label),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _resumen() {
    final Pal p = Pal.of(context);
    final List<Reporte> hoy = widget.reportes.where((Reporte r) => esHoy(r.creado)).toList();
    final Map<String, int> cnt = <String, int>{};
    final Map<String, int> lin = <String, int>{};
    for (final Reporte r in hoy) {
      cnt[r.defecto] = (cnt[r.defecto] ?? 0) + 1;
      lin[r.linea] = (lin[r.linea] ?? 0) + 1;
    }
    final List<MapEntry<String, int>> top = cnt.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
    final List<MapEntry<String, int>> topL = lin.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          const Expanded(child: Etiqueta('Resumen diario de defectos')),
          Text(fechaCorta(fechaISO(DateTime.now())), style: TextStyle(color: p.muted, fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        if (hoy.isEmpty)
          Text('Sin defectos registrados hoy.', style: TextStyle(color: p.muted))
        else ...<Widget>[
          Text(
              '${hoy.length} reporte${hoy.length == 1 ? '' : 's'} hoy'
              '${topL.isNotEmpty ? ' · más afectada: ${topL.first.key} (${topL.first.value})' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (int i = 0; i < top.length && i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('${i + 1}. ${top[i].key}  × ${top[i].value}', style: const TextStyle(fontSize: 14)),
            ),
        ],
      ]),
    );
  }

  Widget _tarjeta(Reporte r) {
    final Pal p = Pal.of(context);
    final Color col = r.resuelto ? p.ok : p.warn;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), side: BorderSide(color: p.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _abrir(r),
          child: Container(
            decoration: BoxDecoration(border: Border(left: BorderSide(color: col, width: 4))),
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Row(children: <Widget>[
                TipoBadge(r.tipo),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(r.folio,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.muted, fontSize: 12, fontFamily: 'monospace'))),
                EstadoPill(r.resuelto),
              ]),
              const SizedBox(height: 6),
              Text(r.defecto, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
                Expanded(
                    child: Text('${r.linea} · Lote ${r.lote} · ${r.proveedor}',
                        style: TextStyle(color: p.muted, fontSize: 13))),
                Text(hace(r.creado), style: TextStyle(color: p.muted, fontSize: 12)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Pal p = Pal.of(context);
    final List<Reporte> R = widget.reportes;
    final List<Reporte> L = _filtrados;
    final int act = R.where((Reporte r) => !r.resuelto).length;
    final int hoy = R.where((Reporte r) => esHoy(r.creado)).length;
    final int res = R.where((Reporte r) => r.resuelto).length;
    final String nombre = (widget.perfil['nombre'] ?? widget.user.displayName ?? '').toString();
    final String depto = (widget.perfil['departamento'] ?? '').toString();
    const Map<String, String> titulos = <String, String>{
      'todos': 'Reportes recientes',
      'activo': 'Reportes activos',
      'hoy': 'Reportes de hoy',
      'resuelto': 'Reportes resueltos',
    };

    final List<Widget> lista = <Widget>[];
    if (widget.error != null) {
      lista.add(_vacio('Sin conexión', widget.error!));
    } else if (!widget.cargado) {
      lista.add(const Padding(
          padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())));
    } else if (R.isEmpty) {
      lista.add(_vacio('Aún no hay reportes',
          'Registra el primer aviso o DMR. Aparecerá aquí al instante para todo el equipo.',
          boton: true));
    } else if (L.isEmpty) {
      lista.add(_vacio('Sin resultados', 'Ningún reporte coincide con la búsqueda o el filtro.'));
    } else {
      lista.addAll(L.map(_tarjeta));
    }

    return Column(children: <Widget>[
      Container(
        color: p.steel,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(children: <Widget>[
              Row(children: <Widget>[
                const Marca(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text('Hola, ${nombre.isEmpty ? 'Usuario' : nombre.split(' ').first}',
                        style: TextStyle(color: p.steelFg, fontSize: 20, fontWeight: FontWeight.w800)),
                    Text('${depto.isEmpty ? '' : '$depto · '}Compañía Cervecera de Zacatecas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.steelMuted, fontSize: 13)),
                  ]),
                ),
                GestureDetector(
                  onTap: widget.onPerfil,
                  child: Avatar(fotoB64: widget.perfil['foto']?.toString(), nombre: nombre),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                onChanged: (String v) => setState(() => _q = v),
                style: TextStyle(color: p.steelFg),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Buscar por lote, no. de material o línea',
                  hintStyle: TextStyle(color: p.steelMuted),
                  prefixIcon: Icon(Icons.search, color: p.steelMuted),
                  fillColor: const Color(0x1FFFFFFF),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0x33FFFFFF))),
                ),
              ),
            ]),
          ),
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
          children: <Widget>[
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: <Widget>[
                  _chip(null, 'TODAS'),
                  for (final String l in lineas) _chip(l, l),
                ],
              ),
            ),
            Row(children: <Widget>[
              _kpi('activo', act, 'Activos', p.warn),
              const SizedBox(width: 10),
              _kpi('hoy', hoy, 'Hoy', p.accent),
              const SizedBox(width: 10),
              _kpi('resuelto', res, 'Resueltos', p.ok),
            ]),
            if (widget.mostrarResumen && widget.cargado) _resumen(),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
              child: Row(children: <Widget>[
                Expanded(
                    child: Text('${titulos[_estado]}${_linea != null ? ' · $_linea' : ''}',
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
                if (widget.cargado)
                  Text('${L.length} de ${R.length}', style: TextStyle(color: p.muted, fontSize: 12)),
              ]),
            ),
            ...lista,
          ],
        ),
      ),
    ]);
  }

  Widget _chip(String? valor, String texto) {
    final Pal p = Pal.of(context);
    final bool on = _linea == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texto,
            style: TextStyle(
                fontWeight: FontWeight.w700, letterSpacing: 0.5, color: on ? p.onAccent : p.fg)),
        selected: on,
        showCheckmark: false,
        selectedColor: p.accent,
        backgroundColor: p.surface,
        side: BorderSide(color: on ? p.accent : p.line),
        shape: const StadiumBorder(),
        onSelected: (bool _) => setState(() => _linea = valor),
      ),
    );
  }

  Widget _vacio(String titulo, String texto, {bool boton = false}) {
    final Pal p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      decoration: BoxDecoration(
        border: Border.all(color: p.line, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: <Widget>[
        Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(texto, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
        if (boton) ...<Widget>[
          const SizedBox(height: 12),
          FilledButton.icon(
              onPressed: widget.onNuevo, icon: const Icon(Icons.add), label: const Text('Nuevo reporte')),
        ],
      ]),
    );
  }
}
