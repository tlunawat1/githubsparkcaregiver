# Change Log

## 2026-02-06: Edit Profile & Email Verification Improvements

### Summary
Added Edit Profile screen accessible from Settings, improved unique code display, and replaced email verification modal with a simple toast message.

### Changes Made

#### New Files
- `lib/features/settings/presentation/screens/edit_profile_screen.dart` - Edit Profile screen with:
  - Editable name field with validation (required, min 2 characters)
  - Read-only email and phone fields with visible borders and lock icons
  - Avatar display with user's initial
  - Cancel and Update buttons
  - API integration via `UserApi.updateCurrentUser()`

#### Modified Files

**`lib/core/routing/app_router.dart`**
- Added `editProfile` route constant (`/settings/edit-profile`)
- Added import for `EditProfileScreen`
- Added nested route under `/settings` for edit profile screen

**`lib/features/settings/presentation/screens/settings_screen.dart`**
- Added edit icon button next to user name in profile card
- Edit icon navigates to Edit Profile screen
- Reloads settings on return if profile was updated
- Fixed unique code display being cropped by icons:
  - Reduced font from `titleLarge` to `titleMedium`
  - Reduced letter spacing from `2` to `1`

**`lib/features/auth/presentation/screens/email_verification_screen.dart`**
- Removed `_showSuccessDialog` modal popup
- Replaced with simple SnackBar toast: "Email verified! Copy and share your code to connect."
- Now navigates directly to home screen after verification

### User Flow Changes

#### Edit Profile
1. User taps edit icon on Settings page profile section
2. Edit Profile screen opens with current user data
3. User can modify name (email/phone are read-only)
4. Cancel returns without saving, Update saves and returns

#### Email Verification (Before)
1. User enters verification code
2. Modal dialog shows with unique code
3. User taps Continue to proceed

#### Email Verification (After)
1. User enters verification code
2. Toast message appears: "Email verified! Copy and share your code to connect."
3. Automatically navigates to home screen

### Testing Checklist
- [ ] Tap edit icon on Settings → opens Edit Profile screen
- [ ] Edit Profile shows name (editable), email (read-only), phone (read-only)
- [ ] Name validation: empty or < 2 chars shows error
- [ ] Cancel button returns to Settings without saving
- [ ] Update button saves name and returns to Settings
- [ ] Settings page shows updated name after edit
- [ ] Unique code fully visible (not cropped by icons)
- [ ] Email verification shows toast instead of modal
- [ ] After verification, navigates directly to home screen

---

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
