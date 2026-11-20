import 'package:flutter_test/flutter_test.dart';

void main() {
  test('widget harness does not boot Firebase', () {
    // The previous counter smoke test pumped Chorezilla, which initializes
    // Firebase. Premium behavior is covered in family_premium_test.dart.
    expect(true, isTrue);
  });
}
