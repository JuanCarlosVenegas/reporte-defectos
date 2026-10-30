import 'package:firebase_core/firebase_core.dart';

/// Datos del proyecto de Firebase (Configuración del proyecto > Tus apps > Android).
/// Estas claves identifican el proyecto; la seguridad la dan las reglas de Firestore.
class FbConfig {
  static const String apiKey = '';
  static const String appId = '';
  static const String messagingSenderId = '';
  static const String projectId = '';
  static const String storageBucket = '';

  static bool get listo =>
      apiKey.isNotEmpty && appId.isNotEmpty && projectId.isNotEmpty;

  static FirebaseOptions get options => const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        storageBucket: storageBucket,
      );
}
