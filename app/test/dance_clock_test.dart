import 'package:flutter_test/flutter_test.dart';
import 'package:v2rvpn/ui/dance.dart';

/// The dance's clock: the beat the settings choose (Settings > Light
/// dance > Beat speed), and the beats the clock keeps it between.
void main() {
  testWidgets('the beat runs at the speed the settings chose', (tester) async {
    final clock = DanceClock(speed: 4)..start();
    expect(clock.tick, 0);
    // Four beats a second: a quarter second each.
    await tester.pump(const Duration(milliseconds: 250));
    expect(clock.tick, 1);
    await tester.pump(const Duration(milliseconds: 250));
    expect(clock.tick, 2);
    // Slower: one beat a second, and the beat does not fire early on the
    // timer the new tempo started.
    clock.setSpeed(1);
    await tester.pump(const Duration(milliseconds: 900));
    expect(clock.tick, 2);
    await tester.pump(const Duration(milliseconds: 100));
    expect(clock.tick, 3);
    clock.dispose();
  });

  test('the speed stays within the beats the clock allows', () {
    final clock = DanceClock();
    expect(clock.speed, 1);
    clock.setSpeed(0);
    expect(clock.speed, 1);
    clock.setSpeed(9);
    expect(clock.speed, 4);
    clock.dispose();
  });

  test('the clock runs only while the dance is on', () {
    final clock = DanceClock(enabled: false, speed: 2)..start();
    expect(clock.running, isFalse);
    clock.setEnabled(true);
    expect(clock.running, isTrue);
    clock.setEnabled(false);
    expect(clock.running, isFalse);
    clock.dispose();
  });
}
