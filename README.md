# rallyx_modern

`rallyx_modern` is a Flutter game library for a Rally-X inspired top-down
driving game built with Flame + Forge2D.

## Library API

Import the package entrypoint:

```dart
import 'package:rallyx_modern/rallyx_modern.dart';
```

The library exports the minimum public classes needed to run and embed the
game:

- `RallyXGame`
- `InputSource` / `KeyboardInputSource` / `VehicleCommand`
- `HudOverlay`, `DebugOverlay`, `GameOverOverlay`

## Example App

A runnable app using this package lives in [`example/`](example).

Run from `example/`:

```bash
flutter run -d macos
flutter run -d windows
```
