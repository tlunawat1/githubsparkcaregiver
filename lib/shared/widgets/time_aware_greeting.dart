import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A widget that displays a time-aware greeting with the user's name.
class TimeAwareGreeting extends StatelessWidget {
  const TimeAwareGreeting({
    super.key,
    required this.userName,
    this.subtitle,
  });

  final String userName;
  final String? subtitle;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  String _getTimeEmoji() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return '\u2600\uFE0F'; // sun
    } else if (hour >= 12 && hour < 17) {
      return '\u2600\uFE0F'; // sun
    } else if (hour >= 17 && hour < 21) {
      return '\uD83C\uDF05'; // sunset
    } else {
      return '\uD83C\uDF19'; // moon
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final dateFormat = DateFormat.yMMMMEEEEd();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${_getGreeting()}, $userName',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _getTimeEmoji(),
              style: const TextStyle(fontSize: 24),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle ?? dateFormat.format(now),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
