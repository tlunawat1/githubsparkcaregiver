# Change Log

## 2026-02-06: Settings Page Redesign

### Summary
Updated the settings experience by removing the bottom sheet modal from home screens, navigating directly to the settings page, enhancing user profile details, removing switch role and reset app options, and adding a swipe-to-logout button.

### Changes Made

#### New Files
- `lib/shared/widgets/swipe_to_logout_button.dart` - A horizontal swipe-to-confirm widget for logout action with:
  - Drag gesture from left to right
  - 80% threshold to trigger action
  - Visual feedback (progress fill, fading label, icon change)
  - Haptic feedback on drag start and completion

#### Modified Files

**`lib/shared/widgets/widgets.dart`**
- Added export for `swipe_to_logout_button.dart`

**`lib/features/settings/presentation/screens/settings_screen.dart`**
- Enhanced profile section to display:
  - User avatar with initials
  - Name and role badge
  - Email address
  - Phone number (if available)
  - Unique code with copy/share functionality
- Removed "Switch Role" option and associated dialog
- Removed "Reset App" option and associated dialog
- Removed the entire "Account" danger zone section
- Added `SwipeToLogoutButton` in new "Account" section for logout
- Logout flow:
  1. User swipes button past 80% threshold
  2. Confirmation dialog appears
  3. On confirm: calls `AuthApi.logout()`, clears local settings, navigates to welcome screen

**`lib/features/dependent/presentation/screens/dependent_home_screen.dart`**
- Changed settings icon to navigate directly to settings page (`context.go(AppRoutes.settings)`)
- Removed `_showSettingsBottomSheet` method and all related helper methods
- Removed unused `_themeMode` variable
- Removed unused `_settingsRepository` dependency

**`lib/features/caregiver/presentation/screens/caregiver_home_screen.dart`**
- Changed settings icon to navigate directly to settings page (`context.go(AppRoutes.settings)`)
- Removed `_showSettingsBottomSheet` method and all related helper methods
- Removed unused `_themeMode` variable
- Removed unused `_settingsRepository` dependency
- Removed unused `repositories.dart` import

### User Flow Changes

#### Before
1. User taps settings icon on home screen
2. Bottom sheet modal appears with quick settings options
3. User selects "All Settings" to access full settings page

#### After
1. User taps settings icon on home screen
2. Navigates directly to full settings page
3. All settings are accessible in one place
4. Logout via swipe-to-confirm button at bottom of settings

### Removed Features
- Quick settings bottom sheet modal
- "Switch Role" functionality (switch between Caregiver/Dependent mode)
- "Reset App" functionality (clear all data)

### Bug Fixes
- Fixed unique code wrapping to two lines by adding `maxLines: 1` to SelectableText widget

### Testing Checklist
- [ ] Tap settings icon from Dependent home screen → navigates to Settings page
- [ ] Tap settings icon from Caregiver home screen → navigates to Settings page
- [ ] Settings page displays user name, email, phone (if available)
- [ ] Unique code displays with copy and share buttons
- [ ] Theme selection works correctly
- [ ] Swipe-to-logout button requires full swipe to trigger
- [ ] Logout confirmation dialog appears after swipe
- [ ] Cancel on logout dialog returns to settings
- [ ] Confirm logout clears session and navigates to welcome screen
