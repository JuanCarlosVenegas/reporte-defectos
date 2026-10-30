import 'package:firebase_core/firebase_core.dart';

/// Datos del proyecto de Firebase (Configuración del proyecto > Tus apps > Android).
/// Estas claves identifican el proyecto; la seguridad la dan las reglas de Firestore.
class FbConfig {
  static const String apiKey = 'AIzaSyAHYRDD0bu8BAGflsM4epNV0Fx_3BoOP4U';
  static const String appId = '1:414481098655:android:715a27345feac88096bfaa';
  static const String messagingSenderId = '414481098655';
  static const String projectId = 'reporte-defectos';
  static const String storageBucket = 'reporte-defectos.firebasestorage.app';

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
