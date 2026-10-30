import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'catalogos.dart';
import 'data.dart';

/// Genera el PDF del reporte (tamaño carta) con sus 4 fases y la evidencia.
Future<Uint8List> construirPdf(Reporte r, List<String> fotos, String autor) async {
  final pw.Document doc = pw.Document(title: r.folio, author: autor);
  final PdfColor acero = PdfColor.fromInt(0xFF22324A);
  final PdfColor azul = PdfColor.fromInt(0xFF1F4E9A);
  final PdfColor gris = PdfColor.fromInt(0xFFE2E7EE);
  final PdfColor tinta = PdfColor.fromInt(0xFF142033);
  final PdfColor apagado = PdfColor.fromInt(0xFF5A6678);

  String v(String s) => s.trim().isEmpty ? '-' : s;

  pw.Widget seccion(String t) => pw.Container(
        width: double.infinity,
        color: gris,
        margin: const pw.EdgeInsets.only(top: 12, bottom: 4),
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(t.toUpperCase(),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: tinta)),
      );

  pw.Widget fila(String k, String valor) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: <pw.Widget>[
          pw.SizedBox(
            width: 175,
            child: pw.Text(k,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: apagado)),
          ),
          pw.Expanded(child: pw.Text(v(valor), style: pw.TextStyle(fontSize: 9.5, color: tinta))),
        ]),
      );

  final List<pw.Widget> cuerpo = <pw.Widget>[
    pw.Container(
      color: acero,
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: <pw.Widget>[
        pw.Text('REPORTE DE DEFECTOS E INCIDENCIAS',
            style: pw.TextStyle(color: PdfColors.white, fontSize: 15, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 3),
        pw.Text('$plantaEmisora - Línea de Producción',
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 9.5)),
        pw.SizedBox(height: 3),
        pw.Text(
            '${r.tipo}    Folio: ${r.folio}    Estado: ${r.resuelto ? 'RESUELTO' : 'ACTIVO'}',
            style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ]),
    ),
    pw.Container(height: 2, color: azul),
    seccion('Fase 1 - Información básica del defecto'),
    fila('Planta emisora', r.s('planta')),
    fila('Tipo de material', r.s('tipoMaterial')),
    fila('Material que genera la afectación', r.s('materialAfectacion')),
    fila('Proveedor', r.proveedor),
    fila('Planta', r.s('plantaProveedor')),
    fila('Nombre del material', r.s('nombreMaterial')),
    fila('Defecto encontrado', r.defecto),
    seccion('Fase 2 - Detalles del lote y trazabilidad'),
    fila('Código de material', r.s('codigoMaterial')),
    fila('No. pedido SAP', r.s('pedidoSAP')),
    fila('Número de lote', r.lote),
    fila('Fecha de producción del lote', fechaCorta(r.s('fechaProduccion'))),
    fila('Línea impactada', r.linea),
    fila('Fecha de reporte', fechaCorta(r.s('fechaReporte'))),
    fila('Turno', r.s('turno')),
    seccion('Fase 3 - Cantidades y tiempos perdidos'),
    for (final List<String> c in cantidades) fila(c[1], r.cantidad(c[0])),
    seccion('Fase 4 - Descripción detallada'),
    for (final String linea in v(r.s('descripcion')).split('\n'))
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        child: pw.Text(linea, style: pw.TextStyle(fontSize: 9.5, color: tinta)),
      ),
    seccion('Registro'),
    fila('Reportó', autor),
    fila('Departamento', r.s('autorDepto')),
    fila('Creado', fechaHora(r.creado)),
    fila('Validado y cerrado',
        r.cerrado > 0 ? '${fechaHora(r.cerrado)} ${r.s('cerradoPorNombre')}' : 'Pendiente'),
  ];

  if (fotos.isNotEmpty) {
    cuerpo.add(seccion('Evidencia fotográfica (${fotos.length})'));
    for (int i = 0; i < fotos.length; i += 2) {
      final List<pw.Widget> par = <pw.Widget>[];
      for (int j = i; j < i + 2; j++) {
        if (j < fotos.length) {
          pw.Widget img;
          try {
            img = pw.Image(pw.MemoryImage(base64Decode(fotos[j])), fit: pw.BoxFit.contain);
          } catch (_) {
            img = pw.Center(child: pw.Text('Foto ${j + 1} no disponible'));
          }
          par.add(pw.Expanded(child: pw.Container(height: 200, child: img)));
        } else {
          par.add(pw.Expanded(child: pw.SizedBox()));
        }
        if (j == i) par.add(pw.SizedBox(width: 10));
      }
      cuerpo.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: par),
      ));
    }
  }

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.letter,
    margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 36),
    footer: (pw.Context ctx) => pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text('${r.folio}   -   Página ${ctx.pageNumber} de ${ctx.pagesCount}',
          style: pw.TextStyle(fontSize: 8, color: apagado)),
    ),
    build: (pw.Context ctx) => cuerpo,
  ));
  return doc.save();
}
