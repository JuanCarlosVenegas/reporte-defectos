import 'dart:convert';

import 'package:flutter/material.dart';

import 'data.dart';
import 'theme.dart';

void aviso(BuildContext context, String msg, {bool alerta = false}) {
  final Pal p = Pal.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: alerta ? p.crit : null,
      duration: Duration(seconds: alerta ? 6 : 3),
    ));
}

class Marca extends StatelessWidget {
  final double size;
  const Marca({super.key, this.size = 38});
  @override
  Widget build(BuildContext context) {
    final Pal p = Pal.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(size * 0.22)),
      child: Text('CCZ',
          style: TextStyle(
              color: p.onAccent,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.36,
              letterSpacing: 0.5)),
    );
  }
}

class TipoBadge extends StatelessWidget {
  final String tipo;
  final bool sobreOscuro;
  const TipoBadge(this.tipo, {super.key, this.sobreOscuro = false});
  @override
  Widget build(BuildContext context) {
    final Pal p = Pal.of(context);
    final bool dmr = tipo == 'DMR';
    final Color fondo = sobreOscuro ? const Color(0x2EFFFFFF) : (dmr ? p.accentSoft : p.surface2);
    final Color texto = sobreOscuro ? p.steelFg : (dmr ? p.accent : p.fg);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(4)),
      child: Text(tipo,
          style: TextStyle(color: texto, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
    );
  }
}

class EstadoPill extends StatelessWidget {
  final bool resuelto;
  const EstadoPill(this.resuelto, {super.key});
  @override
  Widget build(BuildContext context) {
    final Pal p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: resuelto ? p.okSoft : p.warnSoft, borderRadius: BorderRadius.circular(99)),
      child: Text(resuelto ? 'RESUELTO' : 'ACTIVO',
          style: TextStyle(
              color: resuelto ? p.ok : p.warn,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.8)),
    );
  }
}

class Avatar extends StatelessWidget {
  final String? fotoB64;
  final String nombre;
  final double radio;
  const Avatar({super.key, this.fotoB64, required this.nombre, this.radio = 20});
  @override
  Widget build(BuildContext context) {
    final Pal p = Pal.of(context);
    final String f = fotoB64 ?? '';
    if (f.isNotEmpty) {
      return CircleAvatar(radius: radio, backgroundImage: MemoryImage(base64Decode(f)));
    }
    final String ini = nombre.trim().isEmpty
        ? '?'
        : nombre.trim().split(RegExp(r'\s+')).take(2).map((String w) => w[0]).join().toUpperCase();
    return CircleAvatar(
      radius: radio,
      backgroundColor: p.accentSoft,
      child: Text(ini,
          style: TextStyle(color: p.accent, fontWeight: FontWeight.w700, fontSize: radio * 0.7)),
    );
  }
}

/// Campo de texto con sugerencias que se filtran mientras se escribe.
class CampoSugerencias extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final List<String> Function() opciones;
  final String? error;
  final VoidCallback? onChanged;

  const CampoSugerencias({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.opciones,
    this.error,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints cons) {
      return RawAutocomplete<String>(
        textEditingController: controller,
        focusNode: focusNode,
        optionsBuilder: (TextEditingValue v) {
          final String q = normalizar(v.text.trim());
          final List<String> o = opciones();
          if (q.isEmpty) return o;
          return o.where((String x) => normalizar(x).contains(q));
        },
        onSelected: (String s) {
          if (onChanged != null) onChanged!();
        },
        fieldViewBuilder: (BuildContext context, TextEditingController c, FocusNode f,
            VoidCallback onSubmit) {
          return TextField(
            controller: c,
            focusNode: f,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              errorText: error,
              suffixIcon: const Icon(Icons.search),
            ),
            onChanged: (String _) {
              if (onChanged != null) onChanged!();
            },
          );
        },
        optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected,
            Iterable<String> options) {
          final List<String> lista = options.toList();
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 280, maxWidth: cons.maxWidth),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: lista.length,
                  separatorBuilder: (BuildContext context, int i) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int i) {
                    return InkWell(
                      onTap: () => onSelected(lista[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Text(lista[i], style: const TextStyle(fontSize: 14)),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

/// Fila etiqueta / valor para la vista de detalle.
class FilaDato extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final bool ultima;
  const FilaDato(this.etiqueta, this.valor, {super.key, this.ultima = false});
  @override
  Widget build(BuildContext context) {
    final Pal p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          border: ultima ? null : Border(bottom: BorderSide(color: p.line))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
              flex: 42,
              child: Text(etiqueta, style: TextStyle(color: p.muted, fontSize: 14))),
          const SizedBox(width: 10),
          Expanded(
              flex: 58,
              child: Text(valor.isEmpty ? '—' : valor,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        ],
      ),
    );
  }
}

class Caja extends StatelessWidget {
  final List<Widget> children;
  const Caja({super.key, required this.children});
  @override
  Widget build(BuildContext context) {
    final Pal p = Pal.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class Etiqueta extends StatelessWidget {
  final String texto;
  final Color? color;
  const Etiqueta(this.texto, {super.key, this.color});
  @override
  Widget build(BuildContext context) {
    return Text(texto.toUpperCase(),
        style: TextStyle(
            color: color ?? Pal.of(context).muted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 1));
  }
}
