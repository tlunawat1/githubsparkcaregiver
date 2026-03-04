/// Maps raw API / exception error messages to user-friendly text.
///
/// Call [friendlyError] anywhere an error is shown to the user in auth flows.
String friendlyError(Object error) {
  final raw = _extractRaw(error);
  if (raw.isEmpty) return _kGeneric;

  final lower = raw.toLowerCase();

  // --- Network & timeout ---
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return 'The server is taking a while. Please try again in a moment.';
  }
  if (lower.contains('network error') ||
      lower.contains('connection error') ||
      lower.contains('socketexception') ||
      lower.contains('no internet')) {
    return 'No internet connection. Please check your network and try again.';
  }

  // --- Rate limit (should normally be handled by cooldown, but just in case) ---
  if (lower.contains('429') || lower.contains('rate') || lower.contains('too many')) {
    return 'Too many attempts. Please wait a minute and try again.';
  }

  // --- Wrong credentials ---
  if (lower.contains('invalid email or password') ||
      lower.contains('invalid credentials') ||
      lower.contains('unauthorized') ||
      lower.contains('wrong password') ||
      lower.contains('incorrect password')) {
    return 'Incorrect email or password. Please try again.';
  }

  // --- Wrong verification / reset code ---
  if (lower.contains('invalid code') ||
      lower.contains('invalid verification') ||
      lower.contains('wrong code') ||
      lower.contains('incorrect code')) {
    return 'That code doesn\'t match. Please double-check and try again.';
  }

  // --- Expired code ---
  if (lower.contains('expired') || lower.contains('code has expired')) {
    return 'This code has expired. Please request a new one.';
  }

  // --- Account not found ---
  if (lower.contains('not found') || lower.contains('no account') || lower.contains('user not found')) {
    return 'We couldn\'t find an account with that email. Please check or register.';
  }

  // --- Email already taken ---
  if (lower.contains('already exists') ||
      lower.contains('already registered') ||
      lower.contains('email is taken') ||
      lower.contains('duplicate') ||
      lower.contains('conflict')) {
    return 'An account with this email already exists. Try logging in instead.';
  }

  // --- Email not verified ---
  if (lower.contains('verify your email') || lower.contains('not verified') || lower.contains('email verification')) {
    return 'Please verify your email first. Check your inbox for the verification code.';
  }

  // --- Session expired ---
  if (lower.contains('session expired') || lower.contains('token') && lower.contains('expired')) {
    return 'Your session has expired. Please log in again.';
  }

  // --- Server error ---
  if (lower.contains('500') || lower.contains('server error') || lower.contains('internal')) {
    return 'Something went wrong on our end. Please try again shortly.';
  }

  // --- Password too short ---
  if (lower.contains('password') && (lower.contains('short') || lower.contains('at least'))) {
    return 'Password must be at least 6 characters.';
  }

  // --- Generic API prefix cleanup ---
  // Remove common prefixes like "Api400 - ", "ApiException: 400 - ", etc.
  final cleaned = raw.replaceAll(RegExp(r'^Api\d+\s*[-–]\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'^ApiException:\s*\d+\s*[-–]\s*', caseSensitive: false), '')
      .replaceAll('Exception: ', '')
      .trim();

  if (cleaned.isNotEmpty) return cleaned;

  return _kGeneric;
}

const _kGeneric = 'Something went wrong. Please try again.';

String _extractRaw(Object error) {
  final str = error.toString();
  // ApiException.toString() → "ApiException: 400 - message"
  // Strip the prefix so we get just the message.
  return str.replaceAll(RegExp(r'^ApiException:\s*\d+\s*[-–]\s*'), '').trim();
}
