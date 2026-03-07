import 'dart:ui';

import 'package:flame/components.dart';

class SmokeCloudComponent extends PositionComponent {
  SmokeCloudComponent({
    required Vector2 position,
    required double lifetimeSeconds,
  }) : _remainingSeconds = lifetimeSeconds,
       super(position: position, anchor: Anchor.center, size: Vector2.all(0.9));

  double _remainingSeconds;

  final Paint _paint = Paint()..color = const Color(0xAA9AA2AD);

  @override
  void update(double dt) {
    super.update(dt);

    _remainingSeconds -= dt;
    if (_remainingSeconds <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final opacity = (_remainingSeconds / 2.0).clamp(0.2, 1.0);
    _paint.color = Color.fromARGB(
      (255 * opacity).round().clamp(0, 255),
      0x9A,
      0xA2,
      0xAD,
    );

    final radius = (size.x / 2) * (1.2 - opacity * 0.2);
    canvas.drawCircle(Offset.zero, radius, _paint);
  }
}
