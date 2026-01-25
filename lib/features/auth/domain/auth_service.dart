import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Authentication service for password hashing and code generation
class AuthService {
  static const _saltLength = 16;
  static const _uniqueCodeLength = 9;
  static const _verificationCodeLength = 6;
  static const _linkingCodeLength = 5;

  // Characters for unique code generation (excludes confusing chars like 0, O, 1, I, L)
  static const _uniqueCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _numericChars = '0123456789';

  final Random _random = Random.secure();

  /// Generate a random salt for password hashing
  String _generateSalt() {
    final values = List<int>.generate(_saltLength, (_) => _random.nextInt(256));
    return base64Encode(values);
  }

  /// Hash a password with SHA-256 and a salt
  /// Returns a string in format: salt:hash
  String hashPassword(String password) {
    final salt = _generateSalt();
    final bytes = utf8.encode(password + salt);
    final hash = sha256.convert(bytes).toString();
    return '$salt:$hash';
  }

  /// Verify a password against a stored hash
  /// The storedHash should be in format: salt:hash
  bool verifyPassword(String password, String storedHash) {
    final parts = storedHash.split(':');
    if (parts.length != 2) return false;

    final salt = parts[0];
    final expectedHash = parts[1];

    final bytes = utf8.encode(password + salt);
    final actualHash = sha256.convert(bytes).toString();

    return actualHash == expectedHash;
  }

  /// Generate a unique 9-character alphanumeric code for user identification
  /// Example: "A1B2C3D4E"
  String generateUniqueCode() {
    return List.generate(
      _uniqueCodeLength,
      (_) => _uniqueCodeChars[_random.nextInt(_uniqueCodeChars.length)],
    ).join();
  }

  /// Generate a 6-digit verification code for email verification
  /// Example: "123456"
  String generateVerificationCode() {
    return List.generate(
      _verificationCodeLength,
      (_) => _numericChars[_random.nextInt(_numericChars.length)],
    ).join();
  }

  /// Generate a 5-digit linking code for dependent verification
  /// Example: "12345"
  String generateLinkingCode() {
    return List.generate(
      _linkingCodeLength,
      (_) => _numericChars[_random.nextInt(_numericChars.length)],
    ).join();
  }

  /// Hardcoded verification code for MVP (email verification)
  static const String mvpEmailVerificationCode = '123456';

  /// Hardcoded verification code for MVP (login via code)
  static const String mvpLoginCode = '123456';

  /// Hardcoded linking code for MVP (dependent linking)
  static const String mvpLinkingCode = '12345';

  /// Validate email format
  bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Validate password strength (minimum 6 characters)
  bool isValidPassword(String password) {
    return password.length >= 6;
  }

  /// Validate unique code format (9 alphanumeric characters)
  bool isValidUniqueCode(String code) {
    if (code.length != _uniqueCodeLength) return false;
    return code.split('').every((c) => _uniqueCodeChars.contains(c.toUpperCase()));
  }

  /// Validate linking code format (5 digits)
  bool isValidLinkingCode(String code) {
    if (code.length != _linkingCodeLength) return false;
    return code.split('').every((c) => _numericChars.contains(c));
  }

  /// Calculate verification code expiry (24 hours from now)
  DateTime getVerificationCodeExpiry() {
    return DateTime.now().add(const Duration(hours: 24));
  }

  /// Calculate linking code expiry (1 hour from now)
  DateTime getLinkingCodeExpiry() {
    return DateTime.now().add(const Duration(hours: 1));
  }

  /// Check if a code has expired
  bool isCodeExpired(DateTime? expiryTime) {
    if (expiryTime == null) return true;
    return DateTime.now().isAfter(expiryTime);
  }
}
