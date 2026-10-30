# Reporte de Defectos CCZ

App Flutter para el Reporte de Defectos e Incidencias en Línea de Producción (Compañía Cervecera de Zacatecas). Usa Firebase para usuarios, datos en tiempo real y fotos de evidencia.

## Descargar el APK

En el repositorio, entra a **Releases** y descarga `ReporteCCZ.apk` desde el teléfono Android. Al abrirlo, Android pedirá permitir "instalar apps de origen desconocido"; acéptalo una vez.

Cada vez que se sube un cambio a `main`, GitHub compila un APK nuevo solo (pestaña **Actions**).

## Configurar Firebase (una sola vez)

1. Entra a https://console.firebase.google.com y crea un proyecto (plan gratuito Spark).
2. **Authentication** > Comenzar > método **Correo electrónico/contraseña** > Habilitar.
3. **Firestore Database** > Crear base de datos > modo producción > ubicación `nam5` o la más cercana.
4. En Firestore > **Reglas**, pega el contenido de `firestore.rules` y publica.
5. Configuración del proyecto (engrane) > **Agregar app** > Android, nombre del paquete `com.ccz.reporte_defectos`.
6. Descarga `google-services.json` y copia estos valores a `lib/firebase_config.dart`:
   - `apiKey` = `client[0].api_key[0].current_key`
   - `appId` = `client[0].client_info.mobilesdk_app_id`
   - `messagingSenderId` = `project_info.project_number`
   - `projectId` = `project_info.project_id`
   - `storageBucket` = `project_info.storage_bucket`

## Datos

- `usuarios/{uid}`: nombre, correo, departamento, foto y ajustes.
- `reportes/{id}`: un AVISO o DMR con sus 4 fases.
- `fotos/{id}`: evidencia comprimida (hasta 8 por reporte).

La app arranca vacía; todo se captura desde cero.

## iPhone

iOS no instala archivos APK. Para iPhone se necesita una cuenta Apple Developer (99 USD al año) y distribuir por TestFlight; el mismo código Flutter sirve.
