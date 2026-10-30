import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../catalogos.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets.dart';
import 'detalle.dart';

const List<String> _pasos = <String>[
  'Información básica',
  'Lote y trazabilidad',
  'Cantidades y tiempos',
  'Descripción y evidencia',
];

class WizardScreen extends StatefulWidget {
  final User user;
  final Map<String, dynamic> perfil;
  final Reporte? existente;
  final List<String>? fotosExistentes;

  const WizardScreen({
    super.key,
    required this.user,
    required this.perfil,
    this.existente,
    this.fotosExistentes,
  });

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  int _paso = 0;
  bool _guardando = false;
  String _progreso = '';
  final Map<String, String> _err = <String, String>{};
  final ScrollController _scroll = ScrollController();

  // Fase 1
  String _tipo = '';
  String _planta = plantaEmisora;
  final TextEditingController _tipoMaterial = TextEditingController();
  final TextEditingController _materialAfect = TextEditingController();
  final FocusNode _fnMaterialAfect = FocusNode();
  String? _proveedor;
  final TextEditingController _plantaProv = TextEditingController();
  final FocusNode _fnPlantaProv = FocusNode();
  final TextEditingController _nombreMaterial = TextEditingController();
  final TextEditingController _defecto = TextEditingController();
  final FocusNode _fnDefecto = FocusNode();
  // Fase 2
  final TextEditingController _codigo = TextEditingController();
  final TextEditingController _sap = TextEditingController();
  final TextEditingController _lote = TextEditingController();
  String _fechaProd = '';
  String? _linea;
  String _fechaRep = '';
  String? _turno;
  // Fase 3
  final Map<String, TextEditingController> _cant = <String, TextEditingController>{};
  final Map<String, String> _unid = <String, String>{};
  // Fase 4
  final TextEditingController _desc = TextEditingController();
  final List<String> _fotos = <String>[];

  bool get _editando => widget.existente != null;

  @override
  void initState() {
    super.initState();
    for (final List<String> c in cantidades) {
      _cant[c[0]] = TextEditingController();
      _unid[c[0]] = c[0] == 'tiempoPerdido' ? 'MIN' : 'PZA';
    }
    final Reporte? r = widget.existente;
    if (r != null) {
      _tipo = r.tipo;
      if (r.s('planta').isNotEmpty) _planta = r.s('planta');
      _tipoMaterial.text = r.s('tipoMaterial');
      _materialAfect.text = r.s('materialAfectacion');
      _proveedor = proveedores.contains(r.proveedor) ? r.proveedor : null;
      _plantaProv.text = r.s('plantaProveedor');
      _nombreMaterial.text = r.s('nombreMaterial');
      _defecto.text = r.defecto;
      _codigo.text = r.s('codigoMaterial');
      _sap.text = r.s('pedidoSAP');
      _lote.text = r.lote;
      _fechaProd = r.s('fechaProduccion');
      _linea = lineas.contains(r.linea) ? r.linea : null;
      _fechaRep = r.s('fechaReporte');
      _turno = turnos.contains(r.s('turno')) ? r.s('turno') : null;
      final Map<String, dynamic> c = r.cantidades;
      for (final String k in _cant.keys) {
        final Object? v = c[k];
        if (v is Map) {
          _cant[k]!.text = (v['v'] ?? '').toString();
          final String u = (v['u'] ?? '').toString();
          if (u.isNotEmpty) _unid[k] = u;
        }
      }
      _desc.text = r.s('descripcion');
      _fotos.addAll(widget.fotosExistentes ?? <String>[]);
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _tipoMaterial, _materialAfect, _plantaProv, _nombreMaterial, _defecto, _codigo, _sap, _lote, _desc
    ]) {
      c.dispose();
    }
    for (final TextEditingController c in _cant.values) {
      c.dispose();
    }
    _fnMaterialAfect.dispose();
    _fnPlantaProv.dispose();
    _fnDefecto.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---------- Validación ----------
  bool _validar() {
    _err.clear();
    void req(String k, String v) {
      if (v.trim().isEmpty) _err[k] = 'Este campo es obligatorio.';
    }

    if (_paso == 0) {
      if (_tipo.isEmpty) _err['tipo'] = 'Elige AVISO o DMR.';
      req('tipoMaterial', _tipoMaterial.text);
      req('materialAfect', _materialAfect.text);
      req('proveedor', _proveedor ?? '');
      req('plantaProv', _plantaProv.text);
      req('nombreMaterial', _nombreMaterial.text);
      req('defecto', _defecto.text);
    } else if (_paso == 1) {
      req('codigo', _codigo.text);
      req('lote', _lote.text);
      req('fechaProd', _fechaProd);
      req('linea', _linea ?? '');
      req('fechaRep', _fechaRep);
      req('turno', _turno ?? '');
    } else if (_paso == 2) {
      for (final List<String> c in cantidades) {
        final String k = c[0];
        final String v = _cant[k]!.text.trim().replaceAll(',', '.');
        final bool obligatorio = k == 'totalLote' || k == 'defectos';
        if (v.isEmpty) {
          if (obligatorio) _err['c_$k'] = 'Captura la cantidad.';
        } else {
          final double? n = double.tryParse(v);
          if (n == null || n < 0) _err['c_$k'] = 'Escribe un número válido.';
        }
      }
    } else {
      req('desc', _desc.text);
    }
    setState(() {});
    if (_err.isNotEmpty) aviso(context, 'Revisa los campos marcados.');
    return _err.isEmpty;
  }

  void _siguiente() {
    FocusScope.of(context).unfocus();
    if (!_validar()) return;
    if (_paso < 3) {
      setState(() => _paso++);
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } else {
      _guardar();
    }
  }

  void _anterior() {
    FocusScope.of(context).unfocus();
    if (_paso > 0) {
      setState(() {
        _paso--;
        _err.clear();
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  // ---------- Fotos ----------
  Future<void> _agregarFoto(ImageSource fuente) async {
    if (_fotos.length >= 8) {
      aviso(context, 'Máximo 8 fotografías por reporte.');
      return;
    }
    final ImagePicker picker = ImagePicker();
    try {
      List<XFile> archivos = <XFile>[];
      if (fuente == ImageSource.camera) {
        final XFile? x = await picker.pickImage(
            source: ImageSource.camera, maxWidth: 1280, maxHeight: 1280, imageQuality: 60);
        if (x != null) archivos = <XFile>[x];
      } else {
        archivos = await picker.pickMultiImage(maxWidth: 1280, maxHeight: 1280, imageQuality: 60);
      }
      final int libres = 8 - _fotos.length;
      if (archivos.length > libres) {
        archivos = archivos.sublist(0, libres);
        if (mounted) aviso(context, 'Solo se agregaron $libres; el máximo es 8.');
      }
      for (final XFile x in archivos) {
        final Uint8List bytes = await x.readAsBytes();
        _fotos.add(base64Encode(bytes));
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) aviso(context, 'No se pudo abrir la cámara o la galería: $e');
    }
  }

  // ---------- Guardar ----------
  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _progreso = 'Guardando reporte…';
    });
    final Reporte? orig = widget.existente;
    final DocumentReference<Map<String, dynamic>> ref =
        orig != null ? Db.reportes.doc(orig.id) : Db.reportes.doc();
    final int ahora = DateTime.now().millisecondsSinceEpoch;
    final Map<String, dynamic> cant = <String, dynamic>{};
    for (final String k in _cant.keys) {
      cant[k] = <String, dynamic>{'v': _cant[k]!.text.trim().replaceAll(',', '.'), 'u': _unid[k]};
    }
    final Map<String, dynamic> data = <String, dynamic>{
      'tipo': _tipo,
      'planta': _planta,
      'tipoMaterial': _tipoMaterial.text.trim(),
      'materialAfectacion': _materialAfect.text.trim(),
      'proveedor': _proveedor ?? '',
      'plantaProveedor': _plantaProv.text.trim(),
      'nombreMaterial': _nombreMaterial.text.trim(),
      'defecto': _defecto.text.trim(),
      'codigoMaterial': _codigo.text.trim(),
      'pedidoSAP': _sap.text.trim(),
      'lote': _lote.text.trim(),
      'fechaProduccion': _fechaProd,
      'linea': _linea ?? '',
      'fechaReporte': _fechaRep,
      'turno': _turno ?? '',
      'cantidades': cant,
      'descripcion': _desc.text.trim(),
      'fotos': _fotos.length,
      'estado': orig?.estado.isNotEmpty == true ? orig!.estado : 'activo',
      'folio': orig?.folio.isNotEmpty == true ? orig!.folio : generarFolio(_tipo),
      'autor': orig?.autor.isNotEmpty == true ? orig!.autor : widget.user.uid,
      'autorNombre': orig?.s('autorNombre').isNotEmpty == true
          ? orig!.s('autorNombre')
          : (widget.perfil['nombre'] ?? widget.user.displayName ?? '').toString(),
      'autorDepto': orig?.s('autorDepto').isNotEmpty == true
          ? orig!.s('autorDepto')
          : (widget.perfil['departamento'] ?? '').toString(),
      'creado': (orig?.creado ?? 0) > 0 ? orig!.creado : ahora,
      'actualizado': ahora,
      'cerrado': orig?.d['cerrado'],
      'cerradoPor': orig?.d['cerradoPor'],
    };

    final WriteBatch batch = Db.fs.batch();
    batch.set(ref, data);
    for (int i = 0; i < _fotos.length; i++) {
      batch.set(Db.fotos.doc('${ref.id}_$i'),
          <String, dynamic>{'reporte': ref.id, 'i': i, 'img': _fotos[i]});
    }
    final int antes = orig?.numFotos ?? 0;
    for (int i = _fotos.length; i < antes; i++) {
      batch.delete(Db.fotos.doc('${ref.id}_$i'));
    }
    bool pendiente = false;
    try {
      if (_fotos.isNotEmpty) setState(() => _progreso = 'Subiendo ${_fotos.length} foto(s)…');
      await batch.commit().timeout(const Duration(seconds: 25));
    } on TimeoutException {
      pendiente = true;
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        aviso(context, 'No se pudo guardar: $e');
      }
      return;
    }
    if (!mounted) return;
    aviso(
        context,
        pendiente
            ? 'Sin conexión: el reporte se enviará en cuanto haya señal.'
            : (_editando ? 'Cambios guardados' : 'Reporte registrado: ${data['folio']}'));
    final NavigatorState nav = Navigator.of(context);
    if (_editando) {
      nav.pop();
    } else {
      nav.pushReplacement(MaterialPageRoute<void>(
        builder: (BuildContext _) =>
            DetalleScreen(reporteId: ref.id, user: widget.user, perfil: widget.perfil),
      ));
    }
  }

  // ---------- UI helpers ----------
  Widget _campo(String k, TextEditingController c, String label,
      {String hint = '', bool opcional = false, TextInputType? teclado}) {
    return TextField(
      controller: c,
      keyboardType: teclado,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        labelText: opcional ? '$label (opcional)' : label,
        hintText: hint,
        errorText: _err[k],
      ),
      onChanged: (String _) {
        if (_err.containsKey(k)) setState(() => _err.remove(k));
      },
    );
  }

  Widget _desplegable(String k, String label, String? valor, List<String> opciones,
      ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: valor,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, errorText: _err[k]),
      items: opciones
          .map((String o) => DropdownMenuItem<String>(
              value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (String? v) {
        _err.remove(k);
        onChanged(v);
      },
    );
  }

  Widget _fecha(String k, String label, String valor, ValueChanged<String> onChanged) {
    final Pal p = Pal.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        FocusScope.of(context).unfocus();
        final DateTime ini = DateTime.tryParse(valor) ?? DateTime.now();
        final DateTime? d = await showDatePicker(
          context: context,
          initialDate: ini,
          firstDate: DateTime(2015),
          lastDate: DateTime(2100),
          helpText: label,
        );
        if (d != null) {
          _err.remove(k);
          onChanged(fechaISO(d));
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: _err[k],
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(valor.isEmpty ? 'Seleccionar fecha' : fechaCorta(valor),
            style: TextStyle(color: valor.isEmpty ? p.muted : p.fg, fontSize: 16)),
      ),
    );
  }

  List<Widget> _fase1() {
    final Pal p = Pal.of(context);
    return <Widget>[
      const Etiqueta('Tipo de reporte'),
      const SizedBox(height: 6),
      Row(children: <Widget>[
        for (final String t in <String>['AVISO', 'DMR'])
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: t == 'AVISO' ? 8 : 0),
              child: _tipo == t
                  ? FilledButton(onPressed: () {}, child: Text(t))
                  : OutlinedButton(
                      onPressed: () => setState(() {
                            _tipo = t;
                            _err.remove('tipo');
                          }),
                      child: Text(t)),
            ),
          ),
      ]),
      if (_err['tipo'] != null)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(_err['tipo']!, style: TextStyle(color: p.crit, fontSize: 12)),
        ),
      const SizedBox(height: 16),
      _desplegable('planta', 'Planta emisora', _planta, const <String>[plantaEmisora],
          (String? v) => setState(() => _planta = v ?? plantaEmisora)),
      const SizedBox(height: 16),
      _campo('tipoMaterial', _tipoMaterial, 'Tipo de material', hint: 'Escribe el tipo de material'),
      const SizedBox(height: 16),
      CampoSugerencias(
        controller: _materialAfect,
        focusNode: _fnMaterialAfect,
        label: 'Material que está generando la afectación',
        hint: 'Escribe para buscar…',
        opciones: () => materialAfectacion,
        error: _err['materialAfect'],
        onChanged: () {
          if (_err.remove('materialAfect') != null) setState(() {});
        },
      ),
      const SizedBox(height: 16),
      _desplegable('proveedor', 'Proveedor', _proveedor, proveedores, (String? v) {
        setState(() {
          _proveedor = v;
          if (!(plantasProveedor[v] ?? <String>[]).contains(_plantaProv.text)) _plantaProv.clear();
          if (!(defectosPorProveedor[v] ?? <String>[]).contains(_defecto.text)) _defecto.clear();
        });
      }),
      const SizedBox(height: 16),
      CampoSugerencias(
        controller: _plantaProv,
        focusNode: _fnPlantaProv,
        label: 'Planta',
        hint: _proveedor == null ? 'Elige primero el proveedor' : 'Escribe la planta del proveedor',
        opciones: () => plantasProveedor[_proveedor] ?? <String>[],
        error: _err['plantaProv'],
        onChanged: () {
          if (_err.remove('plantaProv') != null) setState(() {});
        },
      ),
      const SizedBox(height: 16),
      _campo('nombreMaterial', _nombreMaterial, 'Nombre del material',
          hint: 'Escribe el nombre del material'),
      const SizedBox(height: 16),
      CampoSugerencias(
        controller: _defecto,
        focusNode: _fnDefecto,
        label: 'Nombre y descripción del defecto encontrado',
        hint: _proveedor == null ? 'Elige primero el proveedor' : 'Escribe para buscar el defecto',
        opciones: () => defectosPorProveedor[_proveedor] ?? <String>[],
        error: _err['defecto'],
        onChanged: () {
          if (_err.remove('defecto') != null) setState(() {});
        },
      ),
    ];
  }

  List<Widget> _fase2() {
    return <Widget>[
      _campo('codigo', _codigo, 'Código de material', hint: 'Ej. 3000123'),
      const SizedBox(height: 16),
      _campo('sap', _sap, 'No. pedido SAP', hint: 'Ej. 4500012345', opcional: true),
      const SizedBox(height: 16),
      _campo('lote', _lote, 'Número de lote', hint: 'Escribe el lote'),
      const SizedBox(height: 16),
      _fecha('fechaProd', 'Fecha de producción del lote', _fechaProd,
          (String v) => setState(() => _fechaProd = v)),
      const SizedBox(height: 16),
      _desplegable('linea', 'Línea impactada', _linea, lineas, (String? v) => setState(() => _linea = v)),
      const SizedBox(height: 16),
      _fecha('fechaRep', 'Fecha de reporte', _fechaRep, (String v) => setState(() => _fechaRep = v)),
      const SizedBox(height: 16),
      _desplegable('turno', 'Turno', _turno, turnos, (String? v) => setState(() => _turno = v)),
    ];
  }

  List<Widget> _fase3() {
    final List<Widget> w = <Widget>[];
    for (final List<String> c in cantidades) {
      final String k = c[0];
      final bool obligatorio = k == 'totalLote' || k == 'defectos';
      final List<String> us = k == 'tiempoPerdido' ? unidadesTiempo : unidades;
      w.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Expanded(
          child: TextField(
            controller: _cant[k],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: obligatorio ? c[1] : '${c[1]} (opcional)',
              hintText: '0',
              errorText: _err['c_$k'],
              errorMaxLines: 2,
            ),
            onChanged: (String _) {
              if (_err.remove('c_$k') != null) setState(() {});
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 104,
          child: DropdownButtonFormField<String>(
            value: us.contains(_unid[k]) ? _unid[k] : us.first,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Unidad'),
            items: us
                .map((String u) => DropdownMenuItem<String>(value: u, child: Text(u)))
                .toList(),
            onChanged: (String? v) => setState(() => _unid[k] = v ?? us.first),
          ),
        ),
      ]));
      w.add(const SizedBox(height: 16));
    }
    return w;
  }

  List<Widget> _fase4() {
    final Pal p = Pal.of(context);
    return <Widget>[
      TextField(
        controller: _desc,
        minLines: 6,
        maxLines: 14,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Descripción detallada del defecto que genera el reclamo',
          alignLabelWithHint: true,
          hintText: 'Qué se encontró, dónde, cómo se detectó y qué acciones se tomaron.',
          errorText: _err['desc'],
        ),
        onChanged: (String _) {
          if (_err.remove('desc') != null) setState(() {});
        },
      ),
      const SizedBox(height: 20),
      Row(children: <Widget>[
        const Expanded(child: Etiqueta('Fotografías y evidencia')),
        Text('${_fotos.length}/8', style: TextStyle(color: p.muted)),
      ]),
      const SizedBox(height: 10),
      GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: <Widget>[
          for (int i = 0; i < _fotos.length; i++)
            Stack(fit: StackFit.expand, children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(base64Decode(_fotos[i]), fit: BoxFit.cover, gaplessPlayback: true),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: const Color(0xB30A1019),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _fotos.removeAt(i)),
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ]),
          if (_fotos.length < 8) _botonFoto(Icons.photo_camera_outlined, 'Cámara', ImageSource.camera),
          if (_fotos.length < 8) _botonFoto(Icons.photo_library_outlined, 'Galería', ImageSource.gallery),
        ],
      ),
      const SizedBox(height: 8),
      Text('Toca la cámara para tomar la foto de evidencia. Hasta 8 fotos.',
          style: TextStyle(color: p.muted, fontSize: 13)),
    ];
  }

  Widget _botonFoto(IconData icono, String texto, ImageSource fuente) {
    final Pal p = Pal.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _agregarFoto(fuente),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: p.accent, width: 1.5),
          borderRadius: BorderRadius.circular(8),
          color: p.accentSoft,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          Icon(icono, color: p.accent, size: 28),
          const SizedBox(height: 4),
          Text(texto, style: TextStyle(color: p.accent, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      ),
    );
  }

  Future<bool> _confirmarSalida() async {
    final bool? r = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text('Se perderá lo que capturaste en este reporte.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Seguir editando')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salir')),
        ],
      ),
    );
    return r == true;
  }

  @override
  Widget build(BuildContext context) {
    final Pal p = Pal.of(context);
    final List<Widget> campos = _paso == 0
        ? _fase1()
        : _paso == 1
            ? _fase2()
            : _paso == 2
                ? _fase3()
                : _fase4();
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop || _guardando) return;
        final NavigatorState nav = Navigator.of(context);
        if (await _confirmarSalida()) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Salir sin guardar',
            onPressed: _guardando
                ? null
                : () async {
                    final NavigatorState nav = Navigator.of(context);
                    if (await _confirmarSalida()) nav.pop();
                  },
          ),
          title: Text(_editando ? 'Editar reporte' : 'Nuevo reporte',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          actions: <Widget>[
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('Fase ${_paso + 1}/4', style: TextStyle(color: p.steelMuted)),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(40),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(children: <Widget>[
                for (int i = 0; i < 4; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 3 ? 6 : 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= _paso ? p.accent : const Color(0x2EFFFFFF),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text('${i + 1}. ${_pasos[i]}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: i == _paso ? p.steelFg : p.steelMuted)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ),
        ),
        body: Stack(children: <Widget>[
          ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: <Widget>[
              Etiqueta('Fase ${_paso + 1}'),
              Text(_pasos[_paso], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.surface,
                  border: Border.all(color: p.line),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: campos),
              ),
            ],
          ),
          if (_guardando)
            Container(
              color: const Color(0x8C05090F),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3)),
                  const SizedBox(width: 12),
                  Text(_progreso, style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
        ]),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(color: p.surface, border: Border(top: BorderSide(color: p.line))),
            child: Row(children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _paso == 0 || _guardando ? null : _anterior,
                  child: const Text('Anterior'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _guardando ? null : _siguiente,
                  child: Text(_paso < 3
                      ? 'Siguiente'
                      : (_editando ? 'Guardar cambios' : 'Registrar reporte')),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
