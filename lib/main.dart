import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_config.dart';
import 'screens/home.dart';
import 'screens/login.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? error;
  if (!FbConfig.listo) {
    error = 'Falta la configuración de Firebase en lib/firebase_config.dart.';
  } else {
    try {
      await Firebase.initializeApp(options: FbConfig.options);
    } catch (e) {
      error = 'No se pudo conectar con Firebase: $e';
    }
  }
  runApp(MyApp(configError: error));
}

class MyApp extends StatelessWidget {
  final String? configError;
  const MyApp({super.key, this.configError});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (BuildContext context, ThemeMode mode, Widget? _) {
        return MaterialApp(
          title: 'Reporte de Defectos CCZ',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: mode,
          locale: const Locale('es', 'MX'),
          supportedLocales: const <Locale>[Locale('es', 'MX'), Locale('es'), Locale('en')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: configError != null
              ? PantallaError(mensaje: configError!)
              : const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final User? u = snap.data;
        if (u == null) return const LoginScreen();
        return HomeScreen(key: ValueKey<String>(u.uid), user: u);
      },
    );
  }
}

class PantallaError extends StatelessWidget {
  final String mensaje;
  const PantallaError({super.key, required this.mensaje});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Marca(size: 56),
                const SizedBox(height: 16),
                const Text('Configuración pendiente',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(mensaje, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
