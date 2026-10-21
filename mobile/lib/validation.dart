String? validatePost(String value) {
  final count = value.trim().runes.length;
  return count < 1 || count > 280 ? 'Use 1–280 characters.' : null;
}

String? validateUsername(String value) =>
    RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(value.trim())
    ? null
    : 'Use 3–24 lowercase letters, numbers or underscores.';

String? validateDisplayName(String value) {
  final count = value.trim().runes.length;
  return count < 1 || count > 50
      ? 'Use 1–50 characters for your display name.'
      : null;
}

String? validateBio(String value) => value.trim().runes.length > 160
    ? 'Use at most 160 characters for your bio.'
    : null;
