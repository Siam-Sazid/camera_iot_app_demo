# camera_iot_demo_app

A Flutter demo app that combines **4K camera capture** with **MQTT-based IoT smart lighting control**.

---

## How This Project Works

### 1. The Big Picture

This app does two independent things at the same time:

```
┌─────────────────────────────────────────┐
│           CameraControlScreen           │
│                                         │
│  ┌─────────────────┐  ┌──────────────┐  │
│  │  CameraService  │  │LightIotService│  │
│  │  (hardware)     │  │  (network)   │  │
│  └─────────────────┘  └──────────────┘  │
└─────────────────────────────────────────┘
```

- **CameraService** talks to the phone's camera hardware
- **LightIotService** talks to a smart bulb over the network via MQTT
- **CameraControlScreen** is the UI that uses both

They are deliberately kept separate. The camera doesn't know about MQTT, and MQTT doesn't know about the camera. The screen is the only place they meet.

---

### 2. The Entry Point — `main.dart`

```dart
void main() {
  runApp(const MyApp());
}
```

Every Flutter app starts here. `runApp` takes a widget and makes it the root of the UI tree.

```dart
return ChangeNotifierProvider(
  create: (_) => LightIotService(),
  child: MaterialApp(
    home: CameraControlScreen(),
  ),
);
```

Two things happening here:

**`MaterialApp`** sets up the whole app — theme, navigation, title. Think of it as the app's shell.

**`ChangeNotifierProvider`** is more interesting. Ask yourself: *the camera screen needs to know the current brightness level — but how does it get it?* You could pass it as a constructor argument, but that gets messy as the app grows. Instead, `Provider` puts `LightIotService` into a "slot" that any widget below it in the tree can reach by asking for it. This is called **dependency injection**.

---

### 3. The Service Layer — Why Two Separate Classes?

#### `CameraService` — Managing Hardware

```dart
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
```

The underscore prefix (`_`) means these fields are **private** — nothing outside the class can touch them directly. This is intentional. The screen never manipulates the controller directly; it always goes through the service's public methods. This is **encapsulation** — hide the complexity, expose only what callers need.

The camera lifecycle has three phases:

```
initialize() → [use: takePicture / startVideoRecording] → dispose()
```

Notice `initialize()` is `async`:

```dart
Future<void> initialize() async {
  final status = await Permission.camera.request();  // ask user
  _cameras = await availableCameras();               // list cameras
  await _reinitController(ResolutionPreset.high);    // start preview
}
```

`await` means *"pause here until this finishes, then continue"*. The camera isn't ready instantly — it needs OS permission and hardware warmup. `Future<void>` is Dart's way of saying *"this will complete later, and returns nothing when it does"*.

**Why cache `_cameras`?** We call `availableCameras()` once and store the result. Resolution switches (`_reinitController`) need to know which camera to use, but re-querying the OS every time is wasteful.

#### `LightIotService` — Managing Network State

```dart
class LightIotService extends ChangeNotifier {
  int _brightness = 50;
  bool _isConnected = false;
```

This class **extends ChangeNotifier**. That single decision is what makes the brightness slider update automatically when the IoT state changes. Here's how it works:

```dart
Future<void> setBrightness(int value) async {
  // 1. publish over MQTT
  _client!.publishMessage(...);
  // 2. update local state
  _brightness = value;
  // 3. tell everyone who's watching
  notifyListeners();
}
```

`notifyListeners()` is the key call. It signals Provider, which tells Flutter to rebuild any widget that called `context.watch<LightIotService>()`. The screen doesn't poll for updates — it's **pushed** changes reactively.

**What is MQTT?** It's a lightweight publish/subscribe protocol designed for IoT devices. Think of it like a group chat:
- You **subscribe** to a topic to receive messages: `home/light/brightness/state`
- You **publish** to a topic to send commands: `home/light/brightness/set`
- A **broker** (server) sits in the middle and routes messages

```
App ──publish──▶ Broker ──▶ Smart Bulb (subscribed to /set)
App ◀──message── Broker ◀── Smart Bulb (publishes to /state)
```

---

### 4. The Screen — Where Everything Connects

#### State the screen owns

```dart
class _CameraControlScreenState extends State<CameraControlScreen>
    with WidgetsBindingObserver {
  final _cameraService = CameraService();
  bool _isRecording = false;
  bool _isSwitching = false;
```

- `_cameraService` — the screen *owns* this; it creates it and disposes it
- `_isRecording` — local UI state: is the video button currently red?
- `_isSwitching` — guards against rendering a disposed camera controller

The screen does **not** own `LightIotService` — that lives in the Provider above it and is shared.

#### How `context.watch` works

```dart
final lightService = context.watch<LightIotService>();
```

This line does two things: it **fetches** the `LightIotService` from the Provider above, and it **subscribes** — whenever `notifyListeners()` is called on it, this widget's `build` method runs again. Move the slider → `setBrightness` → `notifyListeners` → `build` runs → slider redraws at new position.

#### The `build` method and the `_isSwitching` guard

```dart
if (!_cameraService.isInitialized || _isSwitching) {
  return const Center(child: CircularProgressIndicator());
}
```

This is a **guard clause**. The `CameraPreview` widget holds a direct reference to the camera controller. If the controller has been disposed (during a resolution switch or background pause), rendering against it crashes. The guard ensures the preview is only shown when a valid controller is ready.

#### Resolution switching flow

When you tap **Photo**, this sequence runs:

```
tap Photo
    │
    ▼
_switchResolution(ultraHigh)   ← setState(_isSwitching=true) → spinner shown
    │                             dispose old controller
    │                             create new ultraHigh controller
    │                             setState(_isSwitching=false) → preview resumes
    ▼
takePicture()                  ← hardware captures at 4K
    │
    ▼
_switchResolution(high)        ← same dance, back to 1080p preview
    │
    ▼
_saveToDocuments()             ← copy temp file → app documents folder
    │
    ▼
Gal.putImage()                 ← add to device gallery
    │
    ▼
SnackBar("Photo saved")
```

The key insight: **the user pays the 4K hardware cost only during the moment of capture**, not during the entire preview session.

#### App lifecycle — the background pause

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused) {
    _cameraService.pause();   // dispose camera controller
  } else if (state == AppLifecycleState.resumed) {
    _cameraService.resume();  // reinitialize at high
  }
}
```

`WidgetsBindingObserver` is a mixin that lets the screen "listen" to the OS. When the user switches to another app, Android/iOS calls `paused`. Without this, the camera sensor would keep running in the background — burning battery, blocking other apps from using the camera. You register and unregister in `initState`/`dispose`:

```dart
WidgetsBinding.instance.addObserver(this);   // in initState
WidgetsBinding.instance.removeObserver(this); // in dispose
```

Forgetting `removeObserver` is a classic memory leak — the OS would keep calling your callback even after the widget is gone.

---

### 5. How Data Flows End-to-End

**Photo capture:**
```
User tap → _takePhoto() → CameraService (ultraHigh) → XFile (cache)
→ _saveToDocuments() (app docs) → Gal.putImage() (gallery) → SnackBar
```

**Brightness change:**
```
User drags slider → onChanged → lightService.setBrightness(v)
→ MQTT publish → broker → smart bulb
→ notifyListeners() → build() → slider redraws
```

**App backgrounded:**
```
OS signals paused → didChangeAppLifecycleState → cameraService.pause()
→ controller disposed → sensor off → battery saved
```

---

### 6. The Pattern You Should Remember

The architecture follows a clean rule: **services know nothing about UI, UI knows nothing about hardware/network internals**.

```
UI (screen)        → calls methods on services
Services           → do the work, return results / notify listeners
Provider           → bridges ChangeNotifier services to the widget tree
```

When you add a new feature, ask: *is this logic or is this UI?* If it's logic (talking to hardware, network, files), it belongs in a service. If it's presentation (what to show, when to show a spinner), it belongs in the screen.

---

## Project Structure

```
lib/
├── main.dart                        # App entry point, Provider setup
├── screens/
│   └── camera_control_screen.dart   # Main UI screen
└── services/
    ├── camera_services.dart         # Camera hardware management
    └── iot_service.dart             # MQTT / smart light control
```

## Dependencies

| Package | Purpose |
|---|---|
| `camera` | Camera preview and capture |
| `permission_handler` | Request camera permission at runtime |
| `mqtt_client` | MQTT broker communication |
| `provider` | Dependency injection / reactive state |
| `path_provider` | App documents directory path |
| `gal` | Save photos/videos to device gallery |

## Getting Started

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Flutter online documentation](https://docs.flutter.dev/)
