import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'add_reminder_screen.dart';

/// Screen for editing an existing reminder
class EditReminderScreen extends StatefulWidget {
  final String reminderId;

  const EditReminderScreen({
    super.key,
    required this.reminderId,
  });

  @override
  State<EditReminderScreen> createState() => _EditReminderScreenState();
}

class _EditReminderScreenState extends State<EditReminderScreen> {
  @override
  Widget build(BuildContext context) {
    return AddReminderScreen(
      reminderId: widget.reminderId,
    );
  }
}
