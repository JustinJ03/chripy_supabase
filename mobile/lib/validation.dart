// Accept 1–280 trimmed Unicode code points, matching the post/reply database rule.
String? validatePost(String value) {
  // Count trimmed Unicode code points, matching PostgreSQL char_length rather than visible graphemes.
  final count = value.trim().runes.length;
  // Return an error for empty/oversized posts, or null when the text is valid.
  return count < 1 || count > 280 ? 'Use 1–280 characters.' : null;
}

// Require 3–24 lowercase ASCII letters, digits, or underscores after trimming.
String? validateUsername(String value) =>
    // Apply the same anchored username pattern used by the profile CHECK constraint.
    RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(value.trim())
    // Use no widget/value or no error for this branch of the conditional expression.
    ? null
    // Choose this value for the corresponding true/false branch of the condition above.
    : 'Use 3–24 lowercase letters, numbers or underscores.';

// Require 1–50 trimmed Unicode code points for the display name.
String? validateDisplayName(String value) {
  // Count trimmed Unicode code points, matching PostgreSQL char_length rather than visible graphemes.
  final count = value.trim().runes.length;
  // Reject a display name outside the inclusive one-to-fifty code-point range.
  return count < 1 || count > 50
      // Choose this value for the corresponding true/false branch of the condition above.
      ? 'Use 1–50 characters for your display name.'
      // Use no widget/value or no error for this branch of the conditional expression.
      : null;
}

// Allow an empty bio but reject more than 160 trimmed Unicode code points.
String? validateBio(String value) => value.trim().runes.length > 160
    // Choose this value for the corresponding true/false branch of the condition above.
    ? 'Use at most 160 characters for your bio.'
    // Use no widget/value or no error for this branch of the conditional expression.
    : null;
