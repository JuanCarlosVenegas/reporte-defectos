import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../catalogos.dart';
import '../data.dart';
import '../pdf_report.dart';
import '../theme.dart';
import '../widgets.dart';
import 'wizard.dart';

class DetalleScreen extends StatefulWidget {
  final String reporteId;
  final User user;
  final Map<String, dynamic> perfil;
  const DetalleScreen({super.key, required this.reporteId, required this.user, required this.perfil});

  @override
  State<DetalleScreen> createState() => _DetalleScreenState();
}

class _DetalleScreenState extends State<DetalleScreen> {
  List<String>? _fotos;
  int _fotosCargadas = -1;
  bool _ocupado = false;

  Future<void> _cargarFotos(Reporte r) async {
    _fotosCargadas = r.numFotos;
    try {
      final List<String> f = await Db.cargarFotos(r.id);
      if (mounted) setState(() => _fotos = f);
    } catch (e) {
      if (mounted) setState(() => _fotos = <String>[]);
    }
  }

  Future<String> _nombreAutor(Reporte r) async {
    if (r.s('autorNombre').isNotEmpty) return r.s('autorNombre');
    if (r.autor.isEmpty) return '';
    try {
      final DocumentSnapshot<Map<String, dynamic>> d = await Db.usuario(r.autor).get();
      return (d.data()?['nombre'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  Future<void> _editar(Reporte r) async {
    setState(() => _ocupado = true);
    List<String> f = _fotos ?? <String>[];
    if (_fotos == null) {
      try {
        f = await Db.cargarFotos(r.id);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _ocupado = false);
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (BuildContext _) => WizardScreen(
          user: widget.user, perfil: widget.perfil, existente: r, fotosExistentes: f),
    ));
    if (mounted) _cargarFotos(r);
  }

  Future<void> _cerrar(Reporte r) async {
    final bool reabrir = r.resuelto;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: Text(reabrir ? '¿Reabrir este reporte?' : '¿Validar y cerrar este reporte?'),
        content: Text(reabrir
            ? 'Volverá a contarse como activo.'
            : 'Se marcará como resuelto con tu usuario y la hora actual.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(reabrir ? 'Reabrir' : 'Validar y cerrar')),
        ],
      ),
    );
    if (ok != true) return;
    final int ahora = DateTime.now().millisecondsSinceEpoch;
    try {
      await Db.reportes.doc(r.id).update(reabrir
          ? <String, dynamic>{'estado': 'activo', 'cerrado': null, 'cerradoPor': null, 'actualizado': ahora}
          : <String, dynamic>{
              'estado': 'resuelto',
              'cerrado': ahora,
              'cerradoPor': widget.user.uid,
              'cerradoPorNombre': (widget.perfil['nombre'] ?? widget.user.displayName ?? '').toString(),
              'actualizado': ahora,
            });
      if (mounted) aviso(context, reabrir ? 'Reporte reabierto' : 'Reporte validado y cerrado');
    } catch (e) {
      if (mounted) aviso(context, 'No se pudo actualizar: $e');
    }
  }

  Future<void> _pdf(Reporte r) async {
    setState(() => _ocupado = true);
    try {
      final List<String> f = _fotos ?? await Db.cargarFotos(r.id);
      final String autor = await _nombreAutor(r);
      final Uint8List bytes = await construirPdf(r, f, autor);
      if (!mounted) return;
      setState(() => _ocupado = false);
      await Printing.sharePdf(bytes: bytes, filename: '${r.folio}.pdf');
    } catch (e) {
      if (mounted) {
        setState(() => _ocupado = false);
        aviso(context, 'No se pudo generar el PDF: $e');
      }
    }
  }

  Widget _seccion(String titulo, List<List<String>> filas) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Etiqueta(titulo),
        const SizedBox(height: 8),
        Caja(children: <Widget>[
          for (int i = 0; i < filas.length; i++)
            FilaDato(filas[i][0], filas[i][1], ultima: i == filas.length - 1),
        ]),
      ]),
    );
  }

  void _verFoto(String b64) {
    showDialog<void>(
      context: context,
      builder: (BuildContext c) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(children: <Widget>[
          Positioned.fill(
            child: InteractiveViewer(child: Center(child: Image.memory(base64Decode(b64)))),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(c),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Pal p = Pal.of(context);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: Db.reportes.doc(widget.reporteId).snapshots(),
      builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snap) {
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle del reporte')),
            body: Center(
                child: snap.hasError
                    ? Text('No se pudo cargar: ${snap.error}')
                    : const CircularProgressIndicator()),
          );
        }
        final Map<String, dynamic>? data = snap.data!.data();
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle del reporte')),
            body: const Center(child: Text('Este reporte ya no existe.')),
          );
        }
        final Reporte r = Reporte(snap.data!.id, data);
        if (_fotosCargadas != r.numFotos) {
          _fotosCargadas = r.numFotos;
          Future<void>.microtask(() => _cargarFotos(r));
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Detalle del reporte', style: TextStyle(fontWeight: FontWeight.w800))),
          body: Stack(children: <Widget>[
            ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                Container(
                  color: p.steel,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Row(children: <Widget>[
                      TipoBadge(r.tipo, sobreOscuro: true),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(r.folio,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: p.steelFg, fontFamily: 'monospace', fontSize: 13))),
                      EstadoPill(r.resuelto),
                    ]),
                    const SizedBox(height: 10),
                    Text(r.defecto,
                        style: TextStyle(
                            color: p.steelFg, fontSize: 22, fontWeight: FontWeight.w800, height: 1.15)),
                    const SizedBox(height: 6),
                    Text('${r.linea} · Turno ${r.s('turno')} · ${fechaCorta(r.s('fechaReporte'))}',
                        style: TextStyle(color: p.steelMuted, fontSize: 14)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                    _seccion('Información básica del defecto', <List<String>>[
                      <String>['Planta emisora', r.s('planta')],
                      <String>['Tipo de material', r.s('tipoMaterial')],
                      <String>['Material que genera la afectación', r.s('materialAfectacion')],
                      <String>['Proveedor', r.proveedor],
                      <String>['Planta', r.s('plantaProveedor')],
                      <String>['Nombre del material', r.s('nombreMaterial')],
                      <String>['Defecto encontrado', r.defecto],
                    ]),
                    _seccion('Lote y trazabilidad', <List<String>>[
                      <String>['Código de material', r.s('codigoMaterial')],
                      <String>['No. pedido SAP', r.s('pedidoSAP')],
                      <String>['Número de lote', r.lote],
                      <String>['Fecha de producción', fechaCorta(r.s('fechaProduccion'))],
                      <String>['Línea impactada', r.linea],
                      <String>['Fecha de reporte', fechaCorta(r.s('fechaReporte'))],
                      <String>['Turno', r.s('turno')],
                    ]),
                    _seccion('Cantidades y tiempos perdidos', <List<String>>[
                      for (final List<String> c in cantidades) <String>[c[1], r.cantidad(c[0])],
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                        const Etiqueta('Descripción detallada'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: p.surface,
                            border: Border.all(color: p.line),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(r.s('descripcion').isEmpty ? '—' : r.s('descripcion')),
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                        Etiqueta('Evidencia (${r.numFotos})'),
                        const SizedBox(height: 8),
                        if (_fotos == null)
                          Text('Cargando fotografías…', style: TextStyle(color: p.muted))
                        else if (_fotos!.isEmpty)
                          Text('Sin evidencia fotográfica.', style: TextStyle(color: p.muted))
                        else
                          GridView.count(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: <Widget>[
                              for (final String f in _fotos!)
                                GestureDetector(
                                  onTap: () => _verFoto(f),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(base64Decode(f), fit: BoxFit.cover, gaplessPlayback: true),
                                  ),
                                ),
                            ],
                          ),
                      ]),
                    ),
                    FutureBuilder<String>(
                      future: _nombreAutor(r),
                      builder: (BuildContext context, AsyncSnapshot<String> a) => _seccion('Registro', <List<String>>[
                        <String>['Reportó', a.data ?? ''],
                        <String>['Departamento', r.s('autorDepto')],
                        <String>['Creado', fechaHora(r.creado)],
                        <String>['Última edición', fechaHora(r.actualizado)],
                        <String>[
                          'Validado y cerrado',
                          r.cerrado > 0
                              ? '${fechaHora(r.cerrado)}${r.s('cerradoPorNombre').isNotEmpty ? ' · ${r.s('cerradoPorNombre')}' : ''}'
                              : ''
                        ],
                      ]),
                    ),
                  ]),
                ),
              ],
            ),
            if (_ocupado)
              Container(
                color: const Color(0x5905090F),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              ),
          ]),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(color: p.surface, border: Border(top: BorderSide(color: p.line))),
              child: Row(children: <Widget>[
                Expanded(
                    child: _accion(Icons.edit_outlined, 'Editar reporte', () => _editar(r), p.fg, p.surface, p.line)),
                const SizedBox(width: 8),
                Expanded(
                    child: _accion(
                        r.resuelto ? Icons.replay : Icons.check_circle_outline,
                        r.resuelto ? 'Reabrir' : 'Validar y cerrar',
                        () => _cerrar(r),
                        r.resuelto ? p.fg : Colors.white,
                        r.resuelto ? p.surface : p.ok,
                        r.resuelto ? p.line : p.ok)),
                const SizedBox(width: 8),
                Expanded(
                    child: _accion(Icons.picture_as_pdf_outlined, 'Generar PDF', () => _pdf(r), p.onAccent,
                        p.accent, p.accent)),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _accion(IconData icono, String texto, VoidCallback onTap, Color fg, Color bg, Color borde) {
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9), side: BorderSide(color: borde)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _ocupado ? null : onTap,
        child: SizedBox(
          height: 60,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
            Icon(icono, color: fg, size: 22),
            const SizedBox(height: 3),
            Text(texto,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}
