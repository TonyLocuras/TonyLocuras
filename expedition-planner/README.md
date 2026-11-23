# Expedition Planner (Fase 1)

Planificador de rutas de montaña, alpinismo y supervivencia. Asistente en 3 pasos
(Dónde → Ruta → Análisis) y modo experto con mapa y caché offline.

## Qué hace la Fase 1
- Importa GPX; calcula distancia, desnivel (+/−, con filtro de ruido de 3 m), altitud máxima, tiempo (Naismith + factores por actividad y peso de mochila) y perfil de altitud.
- Previsión Open-Meteo con temperatura por altitud (−6,5 °C/km), viento (sensación térmica), UV por altitud, minutos hasta quemarse, cota de 0 °C.
- Lista de mochila generada según ruta, clima y actividad (incluye espeleo y alpinismo).
- Mapa topográfico con descarga de zona offline (máx. 2000 teselas por descarga, según la política de uso de OpenTopoMap).

## Requisitos
- Flutter estable (Dart 3). Probado con Flutter 3.50.
- Windows: Visual Studio con la carga "Desarrollo para el escritorio con C++".
- Android: Android SDK + `flutter doctor --android-licenses`.

## Comandos
```bash
flutter pub get
flutter test
flutter run -d windows          # o -d <id de tu móvil>
./tools/build.sh apk            # build/app/outputs/flutter-apk/app-release.apk
./tools/build.sh windows        # build/windows/x64/runner/Release/
```
En Windows PowerShell: `.\tools\build.ps1 windows` o `.\tools\build.ps1 apk`.

## Estructura
`lib/domain` lógica pura y testeada · `lib/data` GPX, Open-Meteo, caché de teselas · `lib/ui` asistente y mapa.

## Fuera de la Fase 1 (siguientes planes)
Seguridad/emergencia, bitácora, cuenta y sincronización (Supabase), inventario de equipo,
riesgos específicos, planificador de grabación, asistente IA, ventana de luz solar.
