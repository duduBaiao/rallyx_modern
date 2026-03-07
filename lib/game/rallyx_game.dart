import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:rallyx_modern/game/config/game_config.dart';
import 'package:rallyx_modern/game/ui/debug_overlay.dart';
import 'package:rallyx_modern/game/world/fixed_step_forge2d_world.dart';

class RallyXGame extends Forge2DGame<FixedStepForge2DWorld>
    with KeyboardEvents, HasCollisionDetection {
  RallyXGame()
    : super(
        world: FixedStepForge2DWorld(gravity: Vector2.zero()),
        zoom: GameConfig.cameraZoom,
      );

  bool debugOverlayVisible = false;

  @override
  Color backgroundColor() => const Color(0xFF0E1116);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final center = Vector2(
      GameConfig.worldTilesWide / 2,
      GameConfig.worldTilesHigh / 2,
    );
    camera.moveTo(center);

    await world.add(
      _BackdropComponent(
        size: Vector2(
          GameConfig.worldTilesWide.toDouble(),
          GameConfig.worldTilesHigh.toDouble(),
        ),
      ),
    );
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f3) {
      toggleDebugOverlay();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void toggleDebugOverlay() {
    debugOverlayVisible = !debugOverlayVisible;
    if (debugOverlayVisible) {
      overlays.add(DebugOverlay.id);
    } else {
      overlays.remove(DebugOverlay.id);
    }
  }
}

class _BackdropComponent extends PositionComponent {
  _BackdropComponent({required Vector2 size}) : super(size: size);

  final Paint _floorPaint = Paint()..color = const Color(0xFF161B22);
  final Paint _linePaint = Paint()
    ..color = const Color(0xFF2A3240)
    ..strokeWidth = 0.03;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(rect, _floorPaint);

    for (var x = 0.0; x <= size.x; x += 1.0) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), _linePaint);
    }
    for (var y = 0.0; y <= size.y; y += 1.0) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), _linePaint);
    }
  }
}
