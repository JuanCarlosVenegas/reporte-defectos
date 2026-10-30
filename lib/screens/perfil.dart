import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data.dart';
import '../theme.dart';
import '../widgets.dart';

class PerfilView extends StatefulWidget {
  final User user;
  final Map<String, dynamic> perfil;
  final Map<String, dynamic> ajustes;
  const PerfilView({super.key, required this.user, required this.perfil, required this.ajustes});

  @override
  State<PerfilView> createState() => _PerfilViewState();
}

class _PerfilViewState extends State<PerfilView> {
  final TextEditingController _depto = TextEditingController();
  final TextEditingController _nombre = TextEditingController();
  bool _editandoDatos = false;

  @override
  void dispose() {
    _depto.dispose();
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar(Map<String, dynamic> cambios) async {
    try {
      await Db.usuario(widget.user.uid).set(cambios, SetOptions(merge: true));
    } catch (e) {
      if (mounted) aviso(context, 'No se pudo guardar: $e');
    }
  }

  Future<void> _ajuste(String k, bool v) async {
    if (k == 'oscuro') themeMode.value = v ? ThemeMode.dark : ThemeMode.light;
    await _guardar(<String, dynamic>{
      'ajustes': <String, dynamic>{k: v}
    });
  }

  Future<void> _cambiarFoto() async {
    final ImageSource? fuente = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de la galería'),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (fuente == null) return;
    try {
      final XFile? x = await ImagePicker().pickImage(
          source: fuente, maxWidth: 360, maxHeight: 360, imageQuality: 75,
          preferredCameraDevice: CameraDevice.front);
      if (x == null) return;
      final Uint8List bytes = await x.readAsBytes();
      await _guardar(<String, dynamic>{'foto': base64Encode(bytes)});
      if (mounted) aviso(context, 'Foto de perfil actualizada');
    } catch (e) {
      if (mounted) aviso(context, 'No se pudo usar esa imagen: $e');
    }
  }

  Future<void> _salir() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (ok == true) {
      themeMode.value = ThemeMode.light;
      await FirebaseAuth.instance.signOut();
    }
  }

  Widget _switch(String k, String titulo, String sub) {
    final Pal p = Pal.of(context);
    return SwitchListTile(
      value: widget.ajustes[k] == true,
      onChanged: (bool v) => _ajuste(k, v),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: TextStyle(color: p.muted, fontSize: 13)),
      activeColor: p.onAccent,
      activeTrackColor: p.accent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Pal p = Pal.of(context);
    final String nombre = (widget.perfil['nombre'] ?? widget.user.displayName ?? '').toString();
    final String correo = (widget.perfil['correo'] ?? widget.user.email ?? '').toString();
    final String depto = (widget.perfil['departamento'] ?? '').toString();
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: <Widget>[
        Container(
          color: p.steel,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 22),
              child: Column(children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.accent, width: 3)),
                  child: Avatar(fotoB64: widget.perfil['foto']?.toString(), nombre: nombre, radio: 46),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _cambiarFoto,
                  icon: Icon(Icons.photo_camera_outlined, size: 18, color: p.steelFg),
                  label: Text('Cambiar foto de perfil', style: TextStyle(color: p.steelFg, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(10, 36),
                    side: const BorderSide(color: Color(0x40FFFFFF)),
                    shape: const StadiumBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Text(nombre.isEmpty ? 'Usuario' : nombre,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.steelFg, fontSize: 24, fontWeight: FontWeight.w800)),
                Text([correo, depto].where((String s) => s.isNotEmpty).join(' · '),
                    textAlign: TextAlign.center, style: TextStyle(color: p.steelMuted, fontSize: 14)),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            Row(children: <Widget>[
              const Expanded(child: Text('Perfil', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
              TextButton(
                onPressed: () async {
                  if (_editandoDatos) {
                    final String n = _nombre.text.trim();
                    final String d = _depto.text.trim();
                    if (n.isEmpty || d.isEmpty) {
                      aviso(context, 'Nombre y departamento no pueden quedar vacíos.');
                      return;
                    }
                    await _guardar(<String, dynamic>{'nombre': n, 'departamento': d, 'correo': correo});
                    try {
                      await widget.user.updateDisplayName(n);
                    } catch (_) {}
                    if (mounted) aviso(context, 'Perfil actualizado');
                  } else {
                    _nombre.text = nombre;
                    _depto.text = depto;
                  }
                  if (mounted) setState(() => _editandoDatos = !_editandoDatos);
                },
                child: Text(_editandoDatos ? 'Guardar' : 'Editar'),
              ),
            ]),
            const SizedBox(height: 6),
            if (_editandoDatos)
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                TextField(
                    controller: _nombre,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nombre completo')),
                const SizedBox(height: 12),
                TextField(
                    controller: _depto,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Departamento')),
              ])
            else
              Caja(children: <Widget>[
                FilaDato('Nombre', nombre),
                FilaDato('Correo', correo),
                FilaDato('Departamento', depto, ultima: true),
              ]),
            const SizedBox(height: 20),
            const Text('Ajustes', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Caja(children: <Widget>[
              _switch('alertas', 'Alertas de paro de línea',
                  'Aviso al instante cuando alguien registra un reporte nuevo.'),
              Divider(height: 1, color: p.line),
              _switch('resumen', 'Resumen diario de defectos',
                  'Muestra en Inicio los defectos más frecuentes del día.'),
              Divider(height: 1, color: p.line),
              _switch('oscuro', 'Modo oscuro', 'Pantalla oscura para turnos nocturnos.'),
            ]),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: _salir,
              icon: Icon(Icons.logout, color: p.crit),
              label: Text('Cerrar sesión', style: TextStyle(color: p.crit)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: p.crit)),
            ),
          ]),
        ),
      ],
    );
  }
}
