<div align="center">

# 🏁 RS Digital Cockpit

### Android Car Launcher, Real-Time OBD-II KWP2000 Telemetry & Automotive Multimedia Hub  
**Diseñado a medida para Renault Clio II Sport 172 Fase 2 (2004 • Motor F4R 736 2.0L 16v • ECU Siemens Sirius 34)**

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Android](https://img.shields.io/badge/Android-Car_Launcher_%26_Tablets-3DDC84?style=for-the-badge&logo=android&logoColor=black)
![Riverpod](https://img.shields.io/badge/State-100%25_Riverpod-00B4AB?style=for-the-badge)
![Firebase](https://img.shields.io/badge/Firebase-Auth_%7C_Realtime_DB_%7C_Storage_%7C_FCM-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![OBD2](https://img.shields.io/badge/OBD--II-ISO_14230--4_KWP2000_(10.4_kbps)-FF6B00?style=for-the-badge)

</div>

---

## ✨ ¿Qué es RS Digital Cockpit?

**RS Digital Cockpit** (`com.rs.digital.cockpit`) transforma una tablet o smartphone Android en un **cuadro de instrumentos digital automotriz y centro multimedia** inspirado en la estética *Renault Sport 2004 Phase 2* (instrumentación Sagem, tipografía deportiva y modo nocturno/diurno).

Se conecta directamente por **Bluetooth Classic RFCOMM (SPP)** a un adaptador **OBD-II ELM327** sobre **Línea K (Pin 7 • ISO 14230-4 KWP2000 a 10.4 kbps)** con multiplexor de alta prioridad para RPM, e integra reproductor multimedia conectado a Android `MediaSessionManager`, mapa GPS en tiempo real con cronómetro de vueltas hacia Firebase y seguimiento automático de mantenimiento por kilometraje.

---

## 🚀 Funcionalidades Principales

### 1. 🏎️ `COCKPIT` — Tablero Digital y Telemetría en Tiempo Real
- **Tacómetro Sagem CustomPainter a 120 FPS:** Escala 0–8,000 RPM con interpolación suave, barra LED progresiva estilo F1 y fidelidad mecánica al motor F4R 736:
  - **Protección en frío (`< 75 °C`):** Zona de alerta dinámica a las **5,000 RPM**.
  - **Temperatura operativa (`≥ 75 °C`):** Testigo verde OEM de cambio a las **6,750 RPM** y parpadeo de corte de inyección a las **7,250 RPM**.
  - Indicador de marcha estimada para caja **JC5-129** y activación del **decalador VVT**.
- **Parámetros del Motor F4R en Vivo:** Temperatura de refrigerante (`0105`), acelerador TPS (`0111`), batería (`ATRV`), aire de admisión IAT (`010F`), y parámetros extendidos Sirius 34 (Presión MAP `010B`, Avance de encendido `010E`, Carga de motor `0104`).
- **Blackbox Cloud + Visor de Historial:** Guarda los picos de cada recorrido (Peak RPM, velocidad máxima, temperatura máxima, 0–100 km/h y DTCs) en **Firebase Realtime Database** y caché offline, con historial consultable desde el mismo tablero.
- **Monitor Vectorial de Fuerzas G (Plan 3):** Lectura real del acelerómetro y giroscopio de la tablet con estela vectorial, pico máximo y **botón `CALIBRAR`** para fijar el punto `0.00 G` en el ángulo exacto del soporte del auto.
- **Mini Google Maps en Vivo:** Muestra en tiempo real tu ubicación GPS y la calle actual directamente en el tablero.

### 2. 🎧 `MULTIMEDIA` — Centro de Audio Automotriz
- **Sincronización Nativa con el Sistema Android (`MediaSessionManager`):** Detecta automáticamente cualquier reproductor activo (Spotify, YouTube Music, Apple Music, etc.) y muestra el **arte de la canción a fondo completo** con filtro translúcido de alta legibilidad.
- **Controles Grandes Centrados para Conducción:** Botones ampliados para **Random (Shuffle)**, **Anterior**, **Play/Pausa**, **Siguiente** y **Repeat**, junto con **barra de progreso interactiva** (`seekTo`).
- **Control de Volumen Silencioso + Botón `ATT` (-75%):**
  - Slider conectado directamente a `AudioManager.STREAM_MUSIC` **sin activar el popup flotante del sistema Android**.
  - **Botón `ATT` (Atenuación rápida):** Un toque reduce el volumen un **75%** desde el nivel actual; otro toque lo restaura exactamente a donde estaba antes.

### 3. 🗺️ `TRACK` — Navegación, Lugares Cercanos y Cronómetro de Vueltas GPS
- **Mapa Interactivo (2/3 de pantalla) con Filtros Reales:** Búsqueda inmediata alrededor de tu ubicación GPS real para:
  - 🔧 **Talleres mecánicos**
  - ⛽ **Gasolineras**
  - 🅿️ **Estacionamientos**
- **Cronómetro de Laps GPS Automático (1/3 de pantalla • Plan 3):**
  - Fija el **Punto de Partida / Meta** en tu posición actual (dibuja bandera y perímetro de detección de 25 m).
  - Detecta automáticamente cada vez que completas una vuelta y vuelves a cruzar el punto, sumando la **Lap** y su tiempo exacto.
  - **Sincronización Automática a Firebase (`track_lap_sessions`):** Guarda cada sesión usando automáticamente la **calle real del punto de partida** (geocodificación inversa nativa) junto con el listado completo de vueltas y mejor tiempo.

### 4. 🛠️ `GARAGE` — Membresías Funcionales, Skins y Catálogo OEM
- **3 Planes Funcionales con Persistencia Local y Autorización Biométrica:**
  - **Plan 1 — RS Clubman (Gratis):** Telemetría básica K-Line, Shift-Light frío/caliente, Blackbox Cloud y Simulador F4R.
  - **Plan 2 — RS Cup Telemetry:** Desbloquea telemetría extendida Sirius 34 (`MAP`, `Avance`, `Carga`) y alertas automáticas de mantenimiento por kilometraje.
  - **Plan 3 — RS Trophy Pro:** Desbloquea **Skins exclusivos de tacómetro** (*Clio V6 Phase 2* y *Jean Ragnotti Edition*), **Cronómetro de Laps GPS**, **Monitor de Fuerzas G** y **Diagnóstico/Borrado de códigos DTC**.
- **Pasarela con Validación Luhn + Biometría:** Tarjeta interactiva animada (frente/CVV), validación **Algoritmo de Luhn (ISO/IEC 7812)**, confirmación biométrica nativa (`local_auth`) y tienda de refacciones OEM del Clio RS 172.

### 5. 👤 `ACCOUNT` — Perfil, Odómetro Automático y Alertas del Sistema
- **Autenticación Multi-Proveedor (Firebase Auth):** Correo y contraseña (con verificación de correo y subida de avatar a **Firebase Storage**), **Google Sign-In** y **GitHub OAuth**.
- **Odómetro Automático del Vehículo:** Acumula automáticamente el kilometraje real recorrido mediante **GPS + velocidad OBD-II (`010D`)**, permite sincronizar el kilometraje de tu tablero físico y dispara **notificaciones nativas del sistema Android** al acercarse o vencer los intervalos de servicio (**Aceite 5W40**, **Bujías NGK PFR6E-10** y **Kit de Distribución + VVT**).

### 6. 🔌 `ECU` — Conectividad OBD-II ELM327 y Diagnóstico Sirius 34
- **Switch Maestro `ECU ON / OFF`:** Apaga completamente el socket Bluetooth OBD-II con un toque cuando solo deseas escuchar música por Bluetooth sin interferencias.
- **Protocolo K-Line Optimizado para RPM:**
  - Negociación automática con la ECU (`ATSP5` Fast Init → `ATSP4` 5-Baud Init → `ATSP0` Auto).
  - Modo Turbo con respuestas de trama única (`010C1` + `ATST19` + `ATAT2`) y multiplexor que prioriza ~70% del ancho de banda a las **RPM**.
- **Escáner y Borrado Biométrico de DTCs (Plan 3):** Decodificación real de respuestas Modo `03` (`43 ...`) y borrado seguro Modo `04` protegido por huella digital, más **Monitor Serial KWP2000** en tiempo real y **Simulador F4R 736** integrado para pruebas fuera del vehículo.

---

## 🏗️ Arquitectura Técnica

| Capa | Tecnología / Detalle |
| :--- | :--- |
| **Framework & Lenguaje** | Flutter 3 / Dart 3 + Kotlin nativo (`MainActivity.kt`) |
| **Manejo de Estado** | **100% Flutter Riverpod** (`Notifier`, `AsyncNotifier`, `StreamProvider`) — `0% setState` |
| **Comunicación OBD-II** | Bluetooth Classic RFCOMM SPP (`00001101-0000-1000-8000-00805F9B34FB`) • KWP2000 10.4 kbps |
| **Audio & Multimedia** | Android `MediaSessionManager` + `NotificationListenerService` + `AudioManager` silencioso |
| **Mapas & Geolocalización** | `google_maps_flutter`, `geolocator`, Android `Geocoder`, OpenStreetMap Nominatim / Photon |
| **Nube (Firebase)** | Firebase Auth, Realtime Database, Cloud Storage, Cloud Messaging (FCM) |
| **Temas Dinámicos** | **Night Stage** (Sagem Amber `#FF6B00` & Anthracite) y **Daylight Cup** (Mondial Blue `#0038A8` & Iceberg Silver) |
| **ID de Paquete Android** | `com.rs.digital.cockpit` |

---

## ⚙️ Compilación Local

```bash
# 1. Instalar dependencias
flutter pub get

# 2. Verificación estática y pruebas unitarias (Parser KWP2000, Auth Rules, Luhn)
flutter analyze
flutter test

# 3. Compilar APK
flutter build apk --debug
```
