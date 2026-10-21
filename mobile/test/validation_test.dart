import 'package:flutter_test/flutter_test.dart';
import 'package:chripy/validation.dart';

void main() {
  test('Reject empty posts and enforce Unicode character limit', () {
    expect(validatePost('   '), isNotNull);
    expect(validatePost('Hello'), isNull);
    expect(validatePost(List.filled(280, '😀').join()), isNull);
    expect(validatePost(List.filled(281, 'a').join()), isNotNull);
  });
  test('Username matches database rules', () {
    expect(validateUsername('justin_joel'), isNull);
    expect(validateUsername('ab'), isNotNull);
    expect(validateUsername('Justin'), isNotNull);
    expect(validateUsername('two words'), isNotNull);
  });
  test('Display name validates trimmed Unicode database length', () {
    expect(validateDisplayName('   '), isNotNull);
    expect(validateDisplayName(' Alice '), isNull);
    expect(validateDisplayName(List.filled(50, '😀').join()), isNull);
    expect(validateDisplayName(List.filled(51, 'a').join()), isNotNull);
    expect(validateDisplayName(List.filled(25, 'e\u0301').join()), isNull);
    expect(validateDisplayName(List.filled(26, 'e\u0301').join()), isNotNull);
  });
  test(
    'Bio allows empty text and validates trimmed Unicode database length',
    () {
      expect(validateBio('   '), isNull);
      expect(validateBio(' ${List.filled(160, '😀').join()} '), isNull);
      expect(validateBio(List.filled(161, 'a').join()), isNotNull);
      expect(validateBio(List.filled(80, 'e\u0301').join()), isNull);
      expect(validateBio(List.filled(81, 'e\u0301').join()), isNotNull);
    },
  );
}
