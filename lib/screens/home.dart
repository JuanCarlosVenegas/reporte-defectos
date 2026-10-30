import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../theme.dart';
import 'dashboard.dart';
import 'perfil.dart';
import 'wizard.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({super.key, required this.user});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  List<Reporte> _reportes = <Reporte>[];
  bool _cargado = false;
  String? _error;
  Map<String, dynamic> _perfil = <String, dynamic>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subR;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subP;
  final int _inicio = DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> get ajustes {
    final Object? a = _perfil['ajustes'];
    final Map<String, dynamic> base = <String, dynamic>{'alertas': true, 'resumen': true, 'oscuro': false};
    if (a is Map) base.addAll(Map<String, dynamic>.from(a));
    return base;
  }

  @override
  void initState() {
    super.initState();
    final String uid = widget.user.uid;
    _subP = Db.usuario(uid).snapshots().listen((DocumentSnapshot<Map<String, dynamic>> s) {
      if (!mounted) return;
      setState(() => _perfil = s.data() ?? <String, dynamic>{});
      themeMode.value = ajustes['oscuro'] == true ? ThemeMode.dark : ThemeMode.light;
    }, onError: (Object e) {});
    _subR = Db.reportes
        .orderBy('creado', descending: true)
        .limit(500)
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snap) {
      final List<Reporte> nuevos = <Reporte>[];
      if (_cargado) {
        for (final DocumentChange<Map<String, dynamic>> ch in snap.docChanges) {
          if (ch.type != DocumentChangeType.added) continue;
          final Reporte r = Reporte(ch.doc.id, ch.doc.data() ?? <String, dynamic>{});
          if (r.autor != uid && r.creado > _inicio) nuevos.add(r);
        }
      }
      if (!mounted) return;
      setState(() {
        _reportes = snap.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> d) => Reporte(d.id, d.data()))
            .toList();
        _cargado = true;
        _error = null;
      });
      if (ajustes['alertas'] == true) {
        for (final Reporte r in nuevos) {
          final Pal p = Pal.of(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: p.crit,
            duration: const Duration(seconds: 6),
            content: Text('Alerta: nuevo ${r.tipo} en ${r.linea}\n${r.defecto}'),
          ));
        }
      }
    }, onError: (Object e) {
      if (mounted) setState(() => _error = 'Sin acceso a los reportes: $e');
    });
  }

  @override
  void dispose() {
    _subR?.cancel();
    _subP?.cancel();
    super.dispose();
  }

  void _nuevo() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (BuildContext _) => WizardScreen(user: widget.user, perfil: _perfil),
    ));
  }

  Widget _navItem(int i, IconData icono, String texto) {
    final Pal p = Pal.of(context);
    final bool on = _tab == i;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = i),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Icon(icono, color: on ? p.accent : p.muted),
          const SizedBox(height: 2),
          Text(texto,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: on ? p.accent : p.muted)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Pal p = Pal.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: <Widget>[
          DashboardView(
            user: widget.user,
            perfil: _perfil,
            reportes: _reportes,
            cargado: _cargado,
            error: _error,
            mostrarResumen: ajustes['resumen'] == true,
            onNuevo: _nuevo,
            onPerfil: () => setState(() => _tab = 1),
          ),
          PerfilView(user: widget.user, perfil: _perfil, ajustes: ajustes),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _nuevo,
        tooltip: 'Nuevo reporte',
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: p.surface,
        height: 64,
        padding: EdgeInsets.zero,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(children: <Widget>[
          _navItem(0, Icons.home_outlined, 'Inicio'),
          const SizedBox(width: 72),
          _navItem(1, Icons.person_outline, 'Perfil'),
        ]),
      ),
    );
  }
}
