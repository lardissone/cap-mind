# CapMind — PRD

> Working title. Probable rebranding antes del primer release público (idea en exploración: algo en la línea de "drop and forget"). Toda referencia al nombre en el doc debe poder cambiarse con un find-and-replace global.

**Versión del doc:** v0.1
**Autor:** Leandro Ardissone
**Fecha:** 2026-05-27
**Audiencia:** developer/contractor que va a implementar el proyecto.
**Estado:** draft para handoff.

---

## 1. Resumen

CapMind es una app de macOS que vive en la menu bar y mandar contenido a [MyMind](https://mymind.com) sin abrir la web. Solo escritura: nunca se buscan ni se navegan objetos existentes. Dos formas rápidas de entrada (nota de texto, captura de pantalla parcial) y una pasiva (drag-and-drop al icono de la menu bar). Todo lo que entra se sube vía la [API pública de MyMind](https://access.mymind.com/api) y se confirma en un toast/estado breve.

El proyecto es el sibling de [CapNote](https://github.com/lardissone/cap-note), que hace lo mismo contra Capacities. Se debe reutilizar arquitectura, patrones de UI, build pipeline y dependencias de CapNote salvo donde se indique lo contrario.

## 2. Problema

Hoy, para mandar algo a MyMind desde la Mac, hay que: abrir la web de MyMind, esperar carga, arrastrar/pegar, esperar el procesado y volver al contexto anterior. La extensión de Chrome de MyMind ayuda con URLs e imágenes en el browser, pero deja afuera todo lo que vive en el sistema operativo (archivos en el Finder, fragmentos de pantalla, notas rápidas mientras estás en otra app).

La fricción mata el hábito de capture. CapMind elimina esa fricción para los tres formatos más comunes que el usuario quiere mandar desde fuera del browser.

## 3. Objetivos

- Capturar y enviar a MyMind en <2 segundos desde el shortcut hasta que el dato sale del cliente.
- Cero pasos de organización en el momento del capture (sin pickers de space, sin tags, sin título). El usuario ya organiza en MyMind cuando recuerda.
- Cero cliente del lado read: nunca listamos, buscamos ni mostramos objetos existentes en MyMind.
- Funcionar sin abrir ninguna ventana principal: la app vive en la menu bar.

## 4. No objetivos (fase 1)

Lo siguiente está deliberadamente fuera de scope:

- Browse, search o navegación de objetos existentes en MyMind.
- Edición de objetos ya subidos.
- Asignar spaces o tags en el momento del capture (puede entrar en fase 2; ver §15).
- Historial visible de uploads recientes con deep-link a MyMind (entra en fase 2).
- Sincronización offline o queue persistente entre reinicios.
- App de iOS / iPadOS / web companion.
- Soporte de video (requiere plan Mastermind en MyMind y agrega complejidad innecesaria).

## 5. Usuarios

Un usuario primario: el dueño de la cuenta de MyMind que ya paga el servicio y quiere capturar más rápido. Se asume conocimiento básico de macOS (instalar una app firmada y notarizada vía DMG/zip de GitHub Releases), y disposición a generar un access key en el panel de MyMind y pegarlo en Settings una sola vez.

No es una app para usuarios sin cuenta paga, y no hay onboarding pensado para descubrimiento orgánico.

## 6. Glosario MyMind

Conceptos que usa el doc; vienen tal cual de la [API de MyMind](https://access.mymind.com/api).

- **Mind:** todo el contenido del usuario (equivalente a "inbox" / "library").
- **Object:** un item guardado. Tipos: URL, note (texto), image, document, video.
- **Space:** colección con nombre, tipo carpeta. Un object puede pertenecer a 0–100 spaces.
- **Tag:** etiqueta. Puede aplicarse a la creación o después.
- **Access key:** par `kid` + `secret` (HS256) que se genera desde [access.mymind.com/extensions](https://access.mymind.com/extensions). El secret se muestra una sola vez. Se firma un JWT por request, ligado a `path` + `method`, con `exp` recomendado de 5 minutos.

## 7. Decisiones técnicas fijas

| Item | Decisión |
| --- | --- |
| Lenguaje / framework | Swift + SwiftUI (con interop AppKit donde haga falta), mismo stack que CapNote. |
| Min macOS | 15.0 Sequoia. |
| Distribución | GitHub Releases (zip), hardened-runtime signed + notarized vía GitHub Actions, auto-update con Sparkle 2 y appcast en `gh-pages` (mismo workflow que CapNote). |
| Sandbox | No sandbox. Razón: drag-and-drop de archivos arbitrarios al icono y captura de pantalla son hostiles a sandbox sin entitlements caros. App Store queda fuera. |
| Build system | Swift Package Manager (sin `.xcodeproj` committed). Se abre con `xed .` desde la raíz. |
| Dependencias SPM | `sindresorhus/KeyboardShortcuts` (atajos globales) y `sparkle-project/Sparkle` (updates). Sin más libs externas: el JWT (HS256) se hace con `CryptoKit`. |
| Bundle id | `io.lardissone.capmind` (placeholder; rebrand mode). |
| Default space en uploads | Ninguno. Todo entra a la mind principal. |
| Idioma de la app | Inglés (UI, copy, README). |

## 8. Arquitectura general

Tres componentes que comparten estado:

```
┌──────────────────┐        ┌────────────────────────┐
│ Menu bar icon    │──────▶ │  Capture coordinators   │
│ (MenuBarExtra)   │        │   - NoteController      │
│   • drop target  │        │   - ScreenCaptureCtrl   │
│   • menu items   │        │   - DropController      │
└──────────────────┘        └──────────┬─────────────┘
                                       │
                                       ▼
                              ┌────────────────────┐
                              │  MyMindClient      │
                              │  (URLSession,      │
                              │   JWT signer,      │
                              │   multipart, retry)│
                              └─────────┬──────────┘
                                        ▼
                                https://api.mymind.com
```

`MyMindClient` es stateless salvo por el access key (kid + secret, en Keychain). Los tres controllers se construyen al startup y viven en memoria. No hay base de datos local en fase 1. Settings se guardan en `UserDefaults`; el secret va a Keychain.

## 9. Flujos de usuario

### 9.1 Primera vez: setup

1. El usuario abre la app desde el `.app` recién descargado. No aparece ventana, solo el icono en la menu bar (estado: rojo/atención).
2. Click en el icono → menú con "Open Settings…" como primera opción habilitada (el resto, gris).
3. Settings es un panel flotante (no es una ventana de doc; usar el mismo patrón `NSPanel` + `MenuBarExtra` que CapNote, ver §11.4). Tres secciones: Account, Shortcuts, Updates.
4. En Account: link a `https://access.mymind.com/extensions` ("Generate access key"), campo `Key ID` (texto plano) y `Secret` (textfield seguro). Botón "Test connection" → llama `GET /objects?limit=1` y muestra status (verde / mensaje del error code).
5. Al guardar con test verde, el icono de la menu bar cambia a estado normal y los items quedan habilitados.

### 9.2 Nota de texto

1. Usuario presiona el shortcut global de nota (default: `⌘⇧⌥M`; configurable).
2. Aparece un panel flotante centrado (o en la posición elegida en Settings; ver §11.4), sobre cualquier app activa, sin robar focus de la app de fondo más allá del propio editor. Tamaño base 480×260.
3. Editor de texto plano vacío con placeholder "Drop a thought into your mind…". El cursor arranca con focus.
4. Atajos dentro del panel:
   - `⌘↩` → enviar.
   - `Esc` → cerrar sin enviar (el contenido se descarta).
   - `⌘,` → flip a Settings (mismo panel, misma animación que CapNote).
   - `⌘⌥t` → toggle "Always on top" del panel (default: on para este flujo; ver §11.5).
5. Al enviar: panel muestra estado "Sending…" 200 ms, "Sent" 600 ms, después se cierra y limpia el buffer. Si falla, se mantiene abierto con error inline y el texto intacto (ver §12).
6. El body se manda como `text/markdown`. No se agrega título, tags ni space.

### 9.3 Captura de pantalla parcial

1. Usuario presiona el shortcut global de captura (default: `⌘⇧⌥S`; configurable).
2. La app entra en modo selección de región: overlay full-screen semitransparente, cursor crosshair, las dimensiones del rectángulo actual se muestran en píxeles al lado del cursor.
3. El usuario hace click-and-drag para definir el área.
4. Mientras drag-ea: si presiona `Esc`, se cancela la operación sin más diálogos. Si suelta el mouse, la región queda fija.
5. Al soltar: la app captura el rectángulo seleccionado a PNG (no JPEG; preservamos calidad), cierra el overlay y manda el upload de inmediato vía `POST /objects` multipart. No hay preview, no hay confirm modal.
6. Feedback: un toast minimal en la menu bar (un mini popover anclado al icono) con "Uploading…" → "Uploaded ✓" / mensaje de error. Duración 1.5 s en éxito, persistente con dismiss manual si falla.

#### 9.3.1 Implementación de la captura

Usar `ScreenCaptureKit` (`SCStream` + `SCContentFilter`) para el snapshot. Para la UI de selección, crear una `NSWindow` borderless por display (multi-monitor), `level = .screenSaver`, ignora eventos del mouse fuera del rectángulo activo. El overlay dibuja el rectángulo con `CAShapeLayer` para evitar repaints lentos.

Multi-display: el shortcut activa overlays en todos los displays simultáneamente. La región se confina al display donde empezó el drag.

Permisos macOS: la primera vez que se invoca, macOS pide permiso de Screen Recording. La app debe detectar la negativa (`CGPreflightScreenCaptureAccess` antes de crear el stream) y mostrar un alert con un link directo a "System Settings > Privacy & Security > Screen Recording".

Retina: capturar a la resolución nativa del display (los `CGRect` que da `SCContentFilter` ya manejan el factor; PNG resultante debe verse 1:1 con lo seleccionado).

### 9.4 Drag-and-drop al icono de la menu bar

1. El usuario arrastra algo (un archivo desde Finder, una selección de texto desde cualquier app, una imagen desde el browser) sobre el icono de la menu bar.
2. El icono cambia de estado visual ("about to receive") mientras el cursor está sobre él con un drag activo.
3. Al soltar:
   - Si es un archivo soportado por MyMind (jpg, jpeg, png, gif, webp, avif, heif/heic, jxl, bmp, tiff, psd, svg, md, pdf — ver [Supported Formats](https://access.mymind.com/api/supported-formats)) → upload directo vía `POST /objects` multipart con el blob original. Cap 64 MB; rechazar antes de mandar.
   - Si es una URL (browser link) → `POST /objects` con `{ "url": "..." }`.
   - Si es texto plano → `POST /objects` con `{ "content": "..." }` (markdown body).
   - Si es una imagen sin archivo (drag desde un browser que arrastra el bitmap) → convertir a PNG, upload como blob.
   - Si es un archivo no soportado → toast de error "Format not supported by MyMind" con la extensión.
4. Feedback igual que §9.3.6: toast anclado al icono.

#### 9.4.1 Múltiples items

Si el usuario arrastra varios items en un solo drop (ej: 5 imágenes del Finder), se hace una request por item, en serie (no paralelo; más predecible para rate limits y para el orden de aparición en MyMind). El toast muestra progreso `2/5`. Si una falla, se sigue con las restantes y el toast final lista el conteo de éxitos/fallos.

### 9.5 Menu bar dropdown

Click en el icono (sin drag) abre un menú con:

- App status (gris, no clickable): `Ready` / `Sending…` / `Last error: <type>`.
- `New note` (`⌘N` dentro del menú; el shortcut global está en §9.2).
- `Capture region` (mismo principio).
- divider
- `Open Settings…`
- `Check for Updates…` (Sparkle).
- `About CapMind`.
- `Quit`.

## 10. Settings

### 10.1 Account

- Key ID (text field, plano).
- Secret (secure text field, no se muestra después de guardado; reemplaza con `••••••••` y un botón "Replace").
- Botón `Test connection` → ejecuta `GET /objects?limit=1` firmado. Mensaje claro: "Connected" en verde, o el `type` del error y el `detail` del problem-json.
- Link "Manage access keys in MyMind" → abre `https://access.mymind.com/extensions`.

El secret va a Keychain como `kSecClassGenericPassword`, service `io.lardissone.capmind.api-secret`, account `default`. El Key ID puede ir en `UserDefaults` (no es sensible por sí solo; necesita el secret para firmar).

### 10.2 Shortcuts

Dos rows, cada una con un `KeyboardShortcuts.Recorder`:

- New note (default: `⌘⇧⌥M`).
- Capture region (default: `⌘⇧⌥S`).

Botón "Reset to defaults".

### 10.3 General

- Panel position al abrir nota: `Last used` / `Centered on active screen` / `At cursor`. Default: `Centered on active screen`.
- Always on top en el editor de nota: switch, default ON.
- Launch at login: switch, default OFF. Implementación con `ServiceManagement.SMAppService` (macOS 13+).
- Status bar icon style: `Filled` / `Outline`. Default: `Outline`.

### 10.4 Updates

Tres switches Sparkle estándar: `Check automatically`, `Include beta releases`, `Download in background`. Botón `Check now`.

## 11. Componentes técnicos

### 11.1 App entry y menu bar

Patrón directo de CapNote:

- `@main App` con `MenuBarExtra(.systemImage: "tray.and.arrow.down")`. Si el menú estándar de `MenuBarExtra` no permite el drop-target (es probable; ver §11.6), reemplazar por `NSStatusItem` custom.
- `NSApplicationDelegateAdaptor(AppDelegate)` con `NSApp.setActivationPolicy(.accessory)` (no Dock icon, no command tab).
- Shortcuts globales con `KeyboardShortcuts.Name`. `KeyboardShortcuts.onKeyDown(for: .openNote)` y `.captureRegion`.

### 11.2 Panel de nota

- `NotePanel: NSPanel` con `styleMask = [.nonactivatingPanel, .titled, .fullSizeContentView]`, `level = .floating`, `hidesOnDeactivate = false`, `becomesKeyOnlyIfNeeded = true`.
- Contenido SwiftUI vía `NSHostingView`.
- `NotePanelController` (singleton, `@MainActor`) maneja show/hide, posicionamiento (centrado vs cursor vs last-used), flip a Settings, animación de resize.
- Editor: `PlainTextEditor` (NSViewRepresentable sobre `NSTextView`), patrón calcado de CapNote para poder interceptar `⌘Enter` y matar auto-substitutions. SwiftUI `TextEditor` no alcanza por las mismas razones que en CapNote (intercept de teclas, focus reliability).

### 11.3 Captura

- `RegionCaptureController` (clase, no struct; necesita `NSWindow` ownership) crea una `OverlayWindow` por `NSScreen.screens`.
- `OverlayWindow` dibuja crosshair + rectángulo dinámico con un `CAShapeLayer` sobre un `CALayer` translúcido. Capta `mouseDown`, `mouseDragged`, `mouseUp` y `keyDown` (para `Esc`).
- Cuando `mouseUp` llega: cierra todos los overlays, calcula el `CGRect` en coords del display objetivo, llama a `ScreenshotCaptureService.captureRect(display:, rect:)`.
- `ScreenshotCaptureService` usa `SCStream` con un `SCStreamConfiguration` para una sola frame (un `CMSampleBuffer`), convierte a PNG con `CIImage` → `CIContext.pngRepresentation`. Alternativa con menos código: `CGWindowListCreateImage` (legacy pero todavía funciona en macOS 15; menos performante pero más simple). Decisión del implementador, justificándolo en el PR.

### 11.4 Drop target en el icono

- `MenuBarExtra` no expone API de drop directo. Solución: usar `NSStatusItem` custom con un `NSView` que implemente `NSDraggingDestination`.
- El view registra los types: `.fileURL`, `.string`, `.URL`, `.tiff`, `.png`, `.pdf`.
- `draggingEntered(_:)` cambia el icono ("about to receive"); `draggingExited(_:)` lo revierte.
- `performDragOperation(_:)` parsea el pasteboard, decide el branch (file / URL / texto / image bitmap) y llama al `MyMindClient`.

### 11.5 MyMindClient

```swift
final class MyMindClient {
    init(credentialsProvider: CredentialsProviding, urlSession: URLSession = .shared)

    func createObjectFromContent(_ markdown: String) async throws -> ObjectRef
    func createObjectFromURL(_ url: URL) async throws -> ObjectRef
    func createObjectFromFile(_ data: Data, mimeType: String, filename: String) async throws -> ObjectRef
    func testConnection() async throws
}
```

- `URLSession` plana. No `URLSessionConfiguration.background` en fase 1 (la app vive en foreground 99% del tiempo y la persistencia entre quits no está en scope).
- JWT signer: clase aparte, `MyMindJWTSigner`. HS256 con `CryptoKit.HMAC<SHA256>`. Header `{ "alg": "HS256", "kid": "<kid>" }`. Payload `{ "path": "/objects", "method": "POST", "iat": <now>, "exp": <now+300> }`. Base64URL sin padding. ~40 líneas.
- Headers en cada request: `Authorization: Bearer <jwt>`, `User-Agent: CapMind/<version> (macOS)`, `Content-Type` según el body.
- Multipart: construir a mano (boundary fija por request, parts `metadata` JSON + `blob` binario). No agregar dependencia para esto.
- Error mapping: parsear `application/problem+json`, mapear `type` a un enum `MyMindError`:
  ```swift
  enum MyMindError: Error {
      case badRequest(String)
      case unauthorized
      case forbidden
      case notFound
      case payloadTooLarge
      case unprocessable(String)
      case rateLimited(retryAfterSeconds: Int)
      case server(String)
      case unavailable
      case network(URLError)
      case decoding(Error)
      case unsupportedMime(String)   // pre-flight, no del server
  }
  ```
- Backoff: en `rateLimited`, leer `RateLimit` header, encontrar policies con `r=0`, esperar `max(t)` segundos. Reintento único por request. Si vuelve a fallar, surface al usuario.

### 11.6 Almacenamiento

- `UserDefaults`: keyId, panel position, icon style, launch-at-login flag, shortcut bindings (manejados por `KeyboardShortcuts`), Sparkle flags.
- Keychain: secret. Wrapper igual al `Storage/Keychain.swift` de CapNote pero con service id propio.

## 12. Estados de error y feedback

Tabla de qué se muestra al usuario según el escenario:

| Escenario | UI | Acción del usuario |
| --- | --- | --- |
| Sin Key ID o secret configurados | Toast: "Set up your MyMind access key in Settings" + abre Settings. Icono de menu bar en estado rojo. | Configurar. |
| 401 Unauthorized | Toast: "Authentication failed. Check your access key." | Re-test en Settings. |
| 403 Forbidden | Toast: "Your key doesn't have permission for this action." | Regenerar key con más scope. |
| 413 PayloadTooLarge | Toast: "File too large (64 MB max)." | Subir manualmente. |
| 415 Unsupported (pre-flight nuestro) | Toast: "MyMind doesn't accept .xyz files." | Convertir o ignorar. |
| 422 Unprocessable | Toast con `detail` del problem-json. | Caso por caso. |
| 429 RateLimited | Toast: "Rate limit hit. Retrying in Ns…" + retry automático. Si falla otra vez: surface error. | Esperar. |
| 5xx | Toast: "MyMind is having issues. Try again in a minute." | Reintentar. |
| Sin red | Toast: "No connection." Sin retry automático. | Reintentar manual. |
| Drop con 5 items y 1 falla | Toast final: "4 uploaded, 1 failed." Click muestra cuál. | Reintentar manual. |

Nota de nota fallida: el panel del editor se queda abierto, el contenido del editor intacto, error inline arriba de los botones. `⌘Enter` reintenta.

## 13. Layout de archivos sugerido

Espejado de CapNote, con cambios donde aplica:

```
Sources/CapMind/
  CapMindApp.swift                 # @main, MenuBarExtra/NSStatusItem, AppDelegate
  AppSettings.swift                # @Observable, UserDefaults + Keychain bridge
  AppState.swift                   # @Observable runtime state
  HotkeyName.swift                 # KeyboardShortcuts.Name + defaults

  Note/
    NotePanel.swift                # NSPanel subclass
    NotePanelController.swift      # owns the panel, flip animation, submit pipeline
    NoteInputView.swift            # SwiftUI editor + footer
    PlainTextEditor.swift          # NSTextView wrapper (igual que CapNote)
    SendStatus.swift               # enum idle/sending/sent/error

  Capture/
    RegionCaptureController.swift  # coordinator
    OverlayWindow.swift            # NSWindow borderless per-screen
    OverlayView.swift              # crosshair, rect, dim layer
    ScreenshotCaptureService.swift # ScreenCaptureKit wrapper

  Drop/
    StatusItemDropView.swift       # NSView w/ NSDraggingDestination
    DropController.swift           # parses pasteboard, calls client

  API/
    MyMindClient.swift             # public surface
    MyMindJWTSigner.swift          # HS256 con CryptoKit
    MyMindRequests.swift           # builders (JSON / multipart)
    MyMindModels.swift             # ObjectRef, problem-json, RateLimit headers
    MyMindError.swift

  Storage/
    Keychain.swift                 # service id: io.lardissone.capmind.api-secret
    LaunchAtLogin.swift            # SMAppService wrapper

  Settings/
    SettingsView.swift             # root, sections como en CapNote
    AccountSection.swift
    ShortcutsSection.swift
    GeneralSection.swift
    UpdatesSection.swift

  Updates/
    Updater.swift                  # Sparkle wrapper

Tests/CapMindTests/
  MyMindJWTSignerTests.swift
  MyMindRequestsTests.swift        # via MockURLProtocol
  DropControllerTests.swift        # pasteboard parsing
```

## 14. Criterios de aceptación

Lista chequeable para el implementador antes de mergear.

1. La app arranca sin Dock icon, queda en menu bar.
2. Settings → Account: pegar Key ID y secret, click `Test connection`, ver verde. El secret quedó guardado en Keychain (verificable con `security find-generic-password -s io.lardissone.capmind.api-secret`).
3. `⌘⇧⌥M` (default) abre el panel de nota sobre la app activa, sin robar focus de la app de fondo más allá del propio panel.
4. Escribir "Hello from CapMind" y `⌘Enter` crea un object con content markdown en MyMind, verificable en la web.
5. `Esc` en el panel lo cierra y descarta el contenido.
6. `⌘⇧⌥S` muestra overlay full-screen en todos los displays. Click-and-drag dibuja rectángulo con dimensiones live al lado del cursor.
7. Soltar el mouse cierra el overlay, sube la región como PNG, muestra toast `Uploaded ✓`. El object aparece en MyMind con la imagen correcta a resolución nativa.
8. `Esc` durante drag cancela todo el overlay sin upload.
9. Arrastrar un `.png` del Finder al icono de la menu bar: el icono cambia visualmente durante hover, al soltar sube el archivo, toast de éxito.
10. Arrastrar un URL desde Safari (no el favicon, el address bar): se manda como URL, no como texto.
11. Arrastrar una selección de texto plano desde TextEdit: se manda como markdown content.
12. Arrastrar 3 archivos a la vez: 3 requests en serie, toast con progreso, toast final con conteo.
13. Arrastrar un `.xyz` (no soportado): toast de error, ningún upload.
14. Arrastrar un archivo de 70 MB: rechazado pre-flight con toast claro, sin tocar la red.
15. Borrar el secret de Keychain mientras la app corre y hacer una acción: se surface el error de auth, se sugiere ir a Settings.
16. Quit con `⌘Q` desde el menú deja la máquina sin proceso colgado (`ps aux | grep CapMind` vacío).
17. Build firmado y notarizado pasa Gatekeeper en una Mac limpia (test en VM o segunda Mac).
18. Sparkle: cambiar el appcast a una versión más alta, abrir la app, "Check for Updates" detecta y aplica el update.
19. Tests unitarios verdes: JWT signer (vectores conocidos), multipart builder (boundary correcto, parts correctas), pasteboard parser (cada branch).

## 15. Fases / roadmap

**Fase 1 (este PRD):** todo lo anterior. Estimación gruesa, 2–3 semanas dedicadas con un dev senior Swift que ya conoce SwiftUI + AppKit interop.

**Fase 2 (siguiente, no comprometida):**
- Historial visible de uploads recientes (últimos N) en el dropdown del menu bar, con deep-link a MyMind (`https://access.mymind.com/object/<id>`).
- Picker opcional de space y tags en el editor de nota (atajos rápidos, no obligatorio).
- Queue persistente: si un upload falla por red, lo intenta de nuevo cuando vuelve la conexión, sobreviviendo a un quit.
- Editor markdown con preview (eval de [SwiftDown](https://github.com/qeude/SwiftDown) o [swift-markdown-engine](https://github.com/nodes-app/swift-markdown-engine), o la TextEditor con AttributedString de macOS 26 si está estable).

**Fase 3 / wishlist:**
- Auto-tagging local con un modelo on-device (a evaluar).
- iOS companion con Share Extension.
- Soporte de video para usuarios Mastermind.

## 16. Open questions para el implementador

Cosas no resueltas en este doc; resolver en PR o devolverlas a Leandro.

- ¿`MenuBarExtra` puede aceptar drops sin recurrir a `NSStatusItem` custom en macOS 15? Si sí, ahorro de código. Verificar con un prototipo de 30 minutos antes de comprometerse a la ruta `NSStatusItem`.
- `SCStream` vs `CGWindowListCreateImage` para el snapshot: medir tiempo de captura y peso de código. `CGWindowListCreateImage` está deprecated en docs pero sigue funcionando; `SCStream` es el camino oficial pero más verbose. Decidir y dejarlo justificado en commit.
- Default shortcuts (`⌘⇧⌥M`, `⌘⇧⌥S`): verificar que no chocan con shortcuts comunes (Raycast, Alfred). Si hay choque conocido, proponer alternativa.
- Drag de selección de texto desde una app que solo pone HTML en el pasteboard (Google Docs, Notion web): ¿lo mandamos como HTML convertido a markdown, o como texto plano? Decisión sugerida: texto plano (rápido, predecible, y MyMind acepta markdown que termina siendo render-equivalente para la mayoría de los pegados). Pero abierto.

## 17. Referencias

- [CapNote repo](https://github.com/lardissone/cap-note): sibling app, fuente de patrones de UI, build pipeline y dependencias.
- [MyMind API reference](https://access.mymind.com/api)
- [Authentication](https://access.mymind.com/api/authentication) (JWT HS256, kid + secret).
- [Objects](https://access.mymind.com/api/objects) (`POST /objects` con content / url / blob multipart).
- [Spaces](https://access.mymind.com/api/spaces) (no usado en fase 1).
- [Supported Formats](https://access.mymind.com/api/supported-formats) (cap 64 MB, MIME types aceptados).
- [Markdown Support](https://access.mymind.com/api/markdown-support) (CommonMark + page links, pipe tables, task lists).
- [Error Handling](https://access.mymind.com/api/errors) (problem-json RFC 9457).
- [Rate Limits](https://access.mymind.com/api/rate-limits) (burst + sustained, headers `RateLimit-Policy`, `RateLimit`, `RateLimit-Cost`).
- [LLM Instructions](https://access.mymind.com/api/llm) (pegable a un modelo si el implementador quiere ayuda asistida).
- [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit/): captura nativa de macOS 12+.
- [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts): shortcuts globales + Recorder UI.
- [Sparkle 2](https://github.com/sparkle-project/Sparkle): auto-updates.
