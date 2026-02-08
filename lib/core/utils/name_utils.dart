String formatFullName({
  required String firstName,
  String? lastName,
}) {
  final trimmedLast = lastName?.trim();
  if (trimmedLast == null || trimmedLast.isEmpty) {
    return firstName.trim();
  }
  return '${firstName.trim()} $trimmedLast';
}

String nameInitials({
  required String firstName,
  String? lastName,
}) {
  final first = firstName.trim();
  final last = lastName?.trim();
  if (first.isEmpty && (last == null || last.isEmpty)) {
    return '?';
  }
  if (last == null || last.isEmpty) {
    return first.isNotEmpty ? first[0].toUpperCase() : '?';
  }
  return '${first.isNotEmpty ? first[0].toUpperCase() : ''}${last.isNotEmpty ? last[0].toUpperCase() : ''}';
}
