import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../theme.dart';
import '../widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _registro = false;
  bool _cargando = false;
  bool _verPass = false;
  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _depto = TextEditingController();
  final TextEditingController _correo = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  final Map<String, String> _err = <String, String>{};

  @override
  void dispose() {
    _nombre.dispose();
    _depto.dispose();
    _correo.dispose();
    _pass.dispose();
    super.dispose();
  }

  String _mensajeAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'user-disabled':
        return 'Este usuario está deshabilitado.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo. Inicia sesión.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'network-request-failed':
        return 'Sin conexión a internet.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos.';
      case 'operation-not-allowed':
        return 'Activa "Correo/contraseña" en Firebase Authentication.';
      default:
        return e.message ?? e.code;
    }
  }

  bool _validar() {
    _err.clear();
    final String c = _correo.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(c)) _err['correo'] = 'Escribe un correo válido.';
    if (_pass.text.length < 6) _err['pass'] = 'Mínimo 6 caracteres.';
    if (_registro) {
      if (_nombre.text.trim().isEmpty) _err['nombre'] = 'Escribe tu nombre.';
      if (_depto.text.trim().isEmpty) _err['depto'] = 'Escribe tu departamento.';
    }
    setState(() {});
    return _err.isEmpty;
  }

  Future<void> _enviar() async {
    if (!_validar()) return;
    setState(() => _cargando = true);
    try {
      final FirebaseAuth auth = FirebaseAuth.instance;
      if (_registro) {
        final UserCredential cred = await auth.createUserWithEmailAndPassword(
            email: _correo.text.trim(), password: _pass.text);
        final User u = cred.user!;
        await u.updateDisplayName(_nombre.text.trim());
        await Db.usuario(u.uid).set(<String, dynamic>{
          'nombre': _nombre.text.trim(),
          'correo': _correo.text.trim(),
          'departamento': _depto.text.trim(),
          'foto': '',
          'ajustes': <String, dynamic>{'alertas': true, 'resumen': true, 'oscuro': false},
          'creado': DateTime.now().millisecondsSinceEpoch,
        }, SetOptions(merge: true));
      } else {
        await auth.signInWithEmailAndPassword(email: _correo.text.trim(), password: _pass.text);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) aviso(context, _mensajeAuth(e));
    } catch (e) {
      if (mounted) aviso(context, 'No se pudo completar: $e');
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _recuperar() async {
    final String c = _correo.text.trim();
    if (c.isEmpty) {
      aviso(context, 'Escribe tu correo arriba y vuelve a tocar "Olvidé mi contraseña".');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: c);
      if (mounted) aviso(context, 'Te enviamos un correo para restablecer tu contraseña.');
    } on FirebaseAuthException catch (e) {
      if (mounted) aviso(context, _mensajeAuth(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Pal p = Pal.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        children: <Widget>[
          Container(height: 240, color: p.steel),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(children: <Widget>[
                        const Marca(size: 52),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                            Text('REPORTE DE DEFECTOS',
                                style: TextStyle(
                                    color: p.steelFg,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5)),
                            Text('Incidencias en línea de producción',
                                style: TextStyle(color: p.steelMuted, fontSize: 13)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const Etiqueta('Control de gestión'),
                            const SizedBox(height: 2),
                            Text(_registro ? 'Crear cuenta' : 'Iniciar sesión',
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 18),
                            if (_registro) ...<Widget>[
                              TextField(
                                controller: _nombre,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                    labelText: 'Nombre completo', errorText: _err['nombre']),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _depto,
                                textCapitalization: TextCapitalization.sentences,
                                decoration: InputDecoration(
                                    labelText: 'Departamento',
                                    hintText: 'Ej. Calidad, Envasado, Almacén',
                                    errorText: _err['depto']),
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextField(
                              controller: _correo,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              decoration: InputDecoration(
                                  labelText: 'Correo (usuario)', errorText: _err['correo']),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _pass,
                              obscureText: !_verPass,
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                errorText: _err['pass'],
                                suffixIcon: IconButton(
                                  icon: Icon(_verPass ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _verPass = !_verPass),
                                ),
                              ),
                              onSubmitted: (String _) => _enviar(),
                            ),
                            const SizedBox(height: 18),
                            FilledButton(
                              onPressed: _cargando ? null : _enviar,
                              child: _cargando
                                  ? const SizedBox(
                                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                                  : Text(_registro ? 'Crear cuenta' : 'Iniciar sesión'),
                            ),
                            if (!_registro)
                              TextButton(
                                  onPressed: _cargando ? null : _recuperar,
                                  child: const Text('Olvidé mi contraseña')),
                            const Divider(height: 24),
                            TextButton(
                              onPressed: _cargando
                                  ? null
                                  : () => setState(() {
                                        _registro = !_registro;
                                        _err.clear();
                                      }),
                              child: Text(_registro
                                  ? '¿Ya tienes cuenta? Inicia sesión'
                                  : '¿Primera vez? Crea tu cuenta'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
