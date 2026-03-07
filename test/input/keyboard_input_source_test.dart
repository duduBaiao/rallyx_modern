import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyx_modern/game/input/keyboard_input_source.dart';

void main() {
  group('KeyboardInputSource', () {
    test('maps arrow keys and smoke to vehicle command values', () {
      final source = KeyboardInputSource();

      source.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowUp,
          logicalKey: LogicalKeyboardKey.arrowUp,
          timeStamp: Duration.zero,
        ),
      );
      source.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowRight,
          logicalKey: LogicalKeyboardKey.arrowRight,
          timeStamp: Duration.zero,
        ),
      );
      source.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.space,
          logicalKey: LogicalKeyboardKey.space,
          timeStamp: Duration.zero,
        ),
      );

      final command = source.poll(1 / 60);
      expect(command.throttle, 1.0);
      expect(command.brake, 0.0);
      expect(command.steering, 1.0);
      expect(command.smoke, isTrue);
    });

    test('releasing keys resets command values', () {
      final source = KeyboardInputSource();

      source.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowLeft,
          logicalKey: LogicalKeyboardKey.arrowLeft,
          timeStamp: Duration.zero,
        ),
      );
      source.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowDown,
          logicalKey: LogicalKeyboardKey.arrowDown,
          timeStamp: Duration.zero,
        ),
      );
      source.handleKeyEvent(
        const KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.arrowLeft,
          logicalKey: LogicalKeyboardKey.arrowLeft,
          timeStamp: Duration.zero,
        ),
      );
      source.handleKeyEvent(
        const KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.arrowDown,
          logicalKey: LogicalKeyboardKey.arrowDown,
          timeStamp: Duration.zero,
        ),
      );

      final command = source.poll(1 / 60);
      expect(command.throttle, 0.0);
      expect(command.brake, 0.0);
      expect(command.steering, 0.0);
      expect(command.smoke, isFalse);
    });
  });
}
