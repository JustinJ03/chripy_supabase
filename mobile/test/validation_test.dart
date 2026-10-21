// Import Flutter test runners, simulated gestures, finders, and assertions.
import 'package:flutter_test/flutter_test.dart';
// Import the pure validation functions; these tests need no backend.
import 'package:chripy/validation.dart';

// Register this file's tests with the Flutter test runner.
void main() {
  // Register a validation unit test with no SDK initialization or network dependency.
  test('Reject empty posts and enforce Unicode character limit', () {
    // Check that this boundary/input is accepted (null) or rejected (a validation message).
    expect(validatePost('   '), isNotNull);
    // Check that this boundary/input is accepted (null) or rejected (a validation message).
    expect(validatePost('Hello'), isNull);
    // Check that this boundary/input is accepted (null) or rejected (a validation message).
    expect(validatePost(List.filled(280, '😀').join()), isNull);
    // Check that this boundary/input is accepted (null) or rejected (a validation message).
    expect(validatePost(List.filled(281, 'a').join()), isNotNull);
  });
  // Register a validation unit test with no SDK initialization or network dependency.
  test('Username matches database rules', () {
    // Check that this boundary/input is accepted (null) or rejected (a validation message).
    expect(validateUsername('justin_joel'), isNull);
    // Check that this boundary/input is accepted (null) or rejected (a validation message).
    expect(validateUsername('ab'), isNotNull);
    // Check that this boundary/input is accepted (null) or rejected (a validation message).
    expect(validateUsername('Justin'), isNotNull);
    // Check that this boundary/input is accepted (null) or rejected (a validation message).
    expect(validateUsername('two words'), isNotNull);
  });
  // Register a validation unit test with no SDK initialization or network dependency.
  test('Display name validates trimmed Unicode database length', () {
    // Check that this boundary/input is accepted (null) or rejected (a validation message).
    expect(validateDisplayName('   '), isNotNull);
    // Check that this boundary/input is accepted (null) or rejected (a validation message).
    expect(validateDisplayName(' Alice '), isNull);
    // Check that this boundary/input is accepted (null) or rejected (a validation message).
    expect(validateDisplayName(List.filled(50, '😀').join()), isNull);
    // Check that this boundary/input is accepted (null) or rejected (a validation message).
    expect(validateDisplayName(List.filled(51, 'a').join()), isNotNull);
    // Check that this boundary/input is accepted (null) or rejected (a validation message).
    expect(validateDisplayName(List.filled(25, 'e\u0301').join()), isNull);
    // Check that this boundary/input is accepted (null) or rejected (a validation message).
    expect(validateDisplayName(List.filled(26, 'e\u0301').join()), isNotNull);
  });
  // Register a validation unit test with no SDK initialization or network dependency.
  test(
    // Name the regression covering optional bios and Unicode length boundaries.
    'Bio allows empty text and validates trimmed Unicode database length',
    () {
      // Check that this boundary/input is accepted (null) or rejected (a validation message).
      expect(validateBio('   '), isNull);
      // Check that this boundary/input is accepted (null) or rejected (a validation message).
      expect(validateBio(' ${List.filled(160, '😀').join()} '), isNull);
      // Check that this boundary/input is accepted (null) or rejected (a validation message).
      expect(validateBio(List.filled(161, 'a').join()), isNotNull);
      // Check that this boundary/input is accepted (null) or rejected (a validation message).
      expect(validateBio(List.filled(80, 'e\u0301').join()), isNull);
      // Check that this boundary/input is accepted (null) or rejected (a validation message).
      expect(validateBio(List.filled(81, 'e\u0301').join()), isNotNull);
    },
  );
}
