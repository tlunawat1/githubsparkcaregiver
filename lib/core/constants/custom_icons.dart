import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Reminder category enumeration
enum ReminderCategory {
  medicine,
  meal,
  exercise,
  call,
  general,
}

/// Semantic icon mappings for the app.
/// Uses rounded Material icons for a friendlier feel.
class AppIcons {
  AppIcons._();

  // ============================================
  // Category Icons
  // ============================================

  /// Get icon for a reminder category
  static IconData getCategoryIcon(ReminderCategory category) {
    return switch (category) {
      ReminderCategory.medicine => Icons.medication_rounded,
      ReminderCategory.meal => Icons.restaurant_rounded,
      ReminderCategory.exercise => Icons.directions_walk_rounded,
      ReminderCategory.call => Icons.phone_rounded,
      ReminderCategory.general => Icons.notifications_rounded,
    };
  }

  /// Get color for a reminder category
  static Color getCategoryColor(ReminderCategory category) {
    return switch (category) {
      ReminderCategory.medicine => AppColors.categoryMedicine,
      ReminderCategory.meal => AppColors.categoryMeal,
      ReminderCategory.exercise => AppColors.categoryExercise,
      ReminderCategory.call => AppColors.categoryCall,
      ReminderCategory.general => AppColors.categoryGeneral,
    };
  }

  /// Get light background color for a reminder category
  static Color getCategoryLightColor(ReminderCategory category) {
    return switch (category) {
      ReminderCategory.medicine => AppColors.categoryMedicineLight,
      ReminderCategory.meal => AppColors.categoryMealLight,
      ReminderCategory.exercise => AppColors.categoryExerciseLight,
      ReminderCategory.call => AppColors.categoryCallLight,
      ReminderCategory.general => AppColors.categoryGeneralLight,
    };
  }

  /// Get gradient for a reminder category
  static LinearGradient getCategoryGradient(ReminderCategory category) {
    return switch (category) {
      ReminderCategory.medicine => AppColors.medicineGradient,
      ReminderCategory.meal => AppColors.mealGradient,
      ReminderCategory.exercise => AppColors.exerciseGradient,
      ReminderCategory.call => AppColors.callGradient,
      ReminderCategory.general => AppColors.generalGradient,
    };
  }

  // ============================================
  // Status Icons
  // ============================================

  static const IconData pending = Icons.schedule_rounded;
  static const IconData completed = Icons.check_circle_rounded;
  static const IconData missed = Icons.error_rounded;
  static const IconData snoozed = Icons.snooze_rounded;

  /// Get icon for a reminder status
  static IconData getStatusIcon(String status) {
    return switch (status) {
      'pending' => pending,
      'completed' => completed,
      'missed' => missed,
      'snoozed' => snoozed,
      _ => pending,
    };
  }

  // ============================================
  // Navigation Icons
  // ============================================

  static const IconData home = Icons.home_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData forward = Icons.arrow_forward_ios_rounded;
  static const IconData menu = Icons.menu_rounded;
  static const IconData close = Icons.close_rounded;

  // ============================================
  // Action Icons
  // ============================================

  static const IconData add = Icons.add_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData delete = Icons.delete_rounded;
  static const IconData save = Icons.save_rounded;
  static const IconData refresh = Icons.refresh_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData filter = Icons.filter_list_rounded;

  // ============================================
  // Reminder Action Icons
  // ============================================

  static const IconData done = Icons.check_rounded;
  static const IconData snooze = Icons.snooze_rounded;
  static const IconData voiceNote = Icons.mic_rounded;
  static const IconData playVoice = Icons.play_circle_rounded;
  static const IconData stopVoice = Icons.stop_circle_rounded;

  // ============================================
  // User & Relationship Icons
  // ============================================

  static const IconData person = Icons.person_rounded;
  static const IconData people = Icons.people_rounded;
  static const IconData addPerson = Icons.person_add_rounded;
  static const IconData caregiver = Icons.health_and_safety_rounded;
  static const IconData dependent = Icons.elderly_rounded;
  static const IconData link = Icons.link_rounded;
  static const IconData unlink = Icons.link_off_rounded;

  // ============================================
  // Emergency Icons
  // ============================================

  static const IconData sos = Icons.warning_rounded;
  static const IconData emergency = Icons.emergency_rounded;
  static const IconData emergencyContact = Icons.contact_emergency_rounded;
  static const IconData phone = Icons.phone_rounded;

  // ============================================
  // Time & Schedule Icons
  // ============================================

  static const IconData time = Icons.access_time_rounded;
  static const IconData calendar = Icons.calendar_today_rounded;
  static const IconData repeat = Icons.repeat_rounded;
  static const IconData today = Icons.today_rounded;

  // ============================================
  // Priority Icons
  // ============================================

  static const IconData priorityHigh = Icons.priority_high_rounded;
  static const IconData priorityNormal = Icons.remove_rounded;

  // ============================================
  // Notification Icons
  // ============================================

  static const IconData notification = Icons.notifications_rounded;
  static const IconData notificationActive = Icons.notifications_active_rounded;
  static const IconData notificationOff = Icons.notifications_off_rounded;

  // ============================================
  // Misc Icons
  // ============================================

  static const IconData info = Icons.info_rounded;
  static const IconData help = Icons.help_rounded;
  static const IconData logout = Icons.logout_rounded;
  static const IconData language = Icons.language_rounded;
  static const IconData timezone = Icons.public_rounded;
  static const IconData darkMode = Icons.dark_mode_rounded;
  static const IconData lightMode = Icons.light_mode_rounded;
  static const IconData accessibility = Icons.accessibility_new_rounded;
  static const IconData animation = Icons.animation_rounded;
}

/// Category icon widget with circular background
class CategoryIconWidget extends StatelessWidget {
  const CategoryIconWidget({
    super.key,
    required this.category,
    this.size = 48,
    this.iconSize = 24,
  });

  final ReminderCategory category;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppIcons.getCategoryLightColor(category),
        shape: BoxShape.circle,
      ),
      child: Icon(
        AppIcons.getCategoryIcon(category),
        color: AppIcons.getCategoryColor(category),
        size: iconSize,
      ),
    );
  }
}

/// Status icon widget with circular background
class StatusIconWidget extends StatelessWidget {
  const StatusIconWidget({
    super.key,
    required this.status,
    this.size = 40,
    this.iconSize = 24,
  });

  final String status;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.getStatusColor(status);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        AppIcons.getStatusIcon(status),
        color: color,
        size: iconSize,
      ),
    );
  }
}
