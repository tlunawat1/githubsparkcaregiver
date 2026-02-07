import '../constants/custom_icons.dart';

/// Infers the reminder category from the title text.
/// This allows automatic categorization without requiring backend changes.
class CategoryInference {
  CategoryInference._();

  /// Medicine-related keywords
  static final _medicinePattern = RegExp(
    r'\b(medicine|pill|medication|dose|vitamin|tablet|capsule|prescription|aspirin|inhaler|insulin|blood\s*pressure|cholesterol)\b',
    caseSensitive: false,
  );

  /// Meal-related keywords
  static final _mealPattern = RegExp(
    r'\b(breakfast|lunch|dinner|meal|eat|food|snack|brunch|supper|drink\s*water|hydrate|tea|coffee)\b',
    caseSensitive: false,
  );

  /// Exercise-related keywords
  static final _exercisePattern = RegExp(
    r'\b(walk|exercise|stretch|yoga|workout|physio|therapy|gym|swimming|bike|cycling|jog|run|morning\s*walk|evening\s*walk)\b',
    caseSensitive: false,
  );

  /// Call-related keywords
  static final _callPattern = RegExp(
    r'\b(call|phone|video|facetime|zoom|skype|check\s*in|talk\s*to|speak\s*with|ring)\b',
    caseSensitive: false,
  );

  /// Infer category from reminder title
  static ReminderCategory inferCategory(String title) {
    if (_medicinePattern.hasMatch(title)) {
      return ReminderCategory.medicine;
    }
    if (_mealPattern.hasMatch(title)) {
      return ReminderCategory.meal;
    }
    if (_exercisePattern.hasMatch(title)) {
      return ReminderCategory.exercise;
    }
    if (_callPattern.hasMatch(title)) {
      return ReminderCategory.call;
    }
    return ReminderCategory.general;
  }

  /// Get a friendly label for the category
  static String getCategoryLabel(ReminderCategory category) {
    return switch (category) {
      ReminderCategory.medicine => 'Medicine',
      ReminderCategory.meal => 'Meal',
      ReminderCategory.exercise => 'Exercise',
      ReminderCategory.call => 'Call',
      ReminderCategory.general => 'Reminder',
    };
  }
}
