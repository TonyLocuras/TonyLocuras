# TODO OK — Guía de montaje (de cero)

Esta guía deja listo todo lo que necesito para empezar a construir la app. Cópiala a `docs/SETUP.md` del repo privado cuando lo tengas. Ningún paso necesita pagar nada ni dar una tarjeta (la fase 1 usa el plan gratuito de Firebase, "Spark").

**Qué te voy a pedir al final:** solo el nombre del repo privado y el resultado de `flutter doctor`. No me pegues claves, contraseñas ni archivos de configuración de Firebase.

---

## 1. Crear el repo privado

1. En GitHub: **New repository** → nombre `todo-ok` → **Private** → sin README → Create.
2. Si usas Claude Code en la nube, añade ese repo a la sesión (Settings → Connectors → GitHub, y comprueba que Claude tiene acceso a ese repo).
3. Pásame el nombre exacto (`tu-usuario/todo-ok`).

## 2. Instalar Flutter y Android Studio (en tu ordenador)

1. Descarga **Android Studio** (developer.android.com/studio) e instálalo con las opciones por defecto. Ábrelo una vez y deja que descargue el SDK de Android.
2. Descarga **Flutter** (docs.flutter.dev/get-started/install), descomprímelo (por ejemplo en `C:\src\flutter` o `~/development/flutter`) y añade `flutter/bin` al PATH.
3. En una terminal:
   ```
   flutter doctor --android-licenses
   flutter doctor
   ```
   Debe salir el apartado de Android con ✓. Lo de Xcode/iOS lo puedes ignorar.
4. Instala **Node.js 20 o superior** (nodejs.org) y las herramientas de Firebase:
   ```
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   ```

## 3. Crear el proyecto Firebase (plan Spark)

1. console.firebase.google.com → **Add project** → nombre `todo-ok` → desactiva Google Analytics (no hace falta).
2. **Deja el plan Spark.** Si en algún paso te pide pasar a Blaze o dar una tarjeta, **para y avísame**.
3. **Build → Authentication → Get started → Sign-in method → Google → Enable**, con tu email como correo de asistencia.
4. **Build → Firestore Database → Create database** → modo **producción** → región `eur3` (Europa).
5. **Project settings → Your apps → Add app → Android** con el nombre de paquete `com.tonylocuras.todook`. No hace falta descargar nada aún.

## 4. Crear el proyecto Flutter y conectarlo

En la carpeta donde clonaste el repo privado:

```
flutter create --org com.tonylocuras --project-name todo_ok --platforms=android,ios .
flutterfire configure --project=<ID-de-tu-proyecto-firebase> --platforms=android,ios
```

Esto genera `lib/firebase_options.dart` y `android/app/google-services.json`. **No los subas a git** (el `.gitignore` que añadiré los excluye; no me los pegues).

## 5. Clave de firma de release (importante)

El login con Google solo funciona si el APK está firmado con una clave registrada en Firebase. Usaremos **una sola clave** para todos los APK que instales en móviles reales.

1. Crea el keystore (la contraseña la eliges tú y la guardas tú):
   ```
   keytool -genkey -v -keystore ~/todook-release.jks -alias todook -keyalg RSA -keysize 2048 -validity 10000
   ```
   (En Windows `keytool` está en la carpeta `jbr/bin` de Android Studio.)
2. **Haz copia de seguridad de ese archivo fuera del repo** (por ejemplo en tu gestor de contraseñas o un disco). Si lo pierdes, tu contacto tendrá que desinstalar la app para actualizarla.
3. Saca las huellas:
   ```
   keytool -list -v -keystore ~/todook-release.jks -alias todook
   ```
4. En Firebase: **Project settings → Your apps → Android → Add fingerprint** y pega **SHA-1** y **SHA-256**.
5. En Google Cloud Console → **APIs y servicios → Credenciales** → la clave de API de Android: **Restricciones de aplicación → Aplicaciones Android** → paquete `com.tonylocuras.todook` + la SHA-1 del paso 3.

## 6. Retención de datos (TTL)

Las coordenadas se borran solas con políticas TTL. Desde la terminal con `gcloud` (o en la consola: Firestore → Time-to-live):

```
gcloud firestore fields ttls update expireAt --collection-group=expeditions --enable-ttl
gcloud firestore fields ttls update expireAt --collection-group=checkins --enable-ttl
gcloud firestore fields ttls update expireAt --collection-group=contacts --enable-ttl
gcloud firestore fields ttls update expiresAt --collection-group=pairingCodes --enable-ttl
```

El borrado puede tardar entre 24 y 72 horas después de la fecha. Si la consola te pide pasar a Blaze para esto, **avísame** y lo replanteamos.

## 7. Distribuir la app a tu contacto

1. Firebase → **Release & Monitor → App Distribution** → Get started (gratis).
2. Crea un grupo "contactos" y añade el email de tu contacto.
3. Cuando haya un APK firmado con la clave de release, lo subo o lo subes tú y tu contacto lo instala desde el correo (tiene que permitir "instalar apps desconocidas").

## 8. Qué necesitas para probar

- Un **móvil Android de pruebas** (el tuyo vale) con depuración USB activada.
- **Un segundo móvil Android** para hacer de contacto. Sin él no se puede comprobar la alarma de verdad.
- Antes de la primera expedición real: pasar el checklist en el móvil real del contacto.

## 9. iPhone (aviso)

Instalar la app en un iPhone requiere una cuenta Apple Developer (99 $/año) y un Mac. Sin eso no hay forma gratuita. Aunque se instale, la alarma puede quedar silenciada. La alarma fiable es en Android.

---

**Cuando termines 1 a 5:** dime el nombre del repo y pega la salida de `flutter doctor`. Con eso empiezo por la Task 1b, el spike que comprueba que el servicio de vigilancia funciona en un Android real. Todo lo demás depende de ese resultado.
