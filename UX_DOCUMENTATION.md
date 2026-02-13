# ParentalCare Mobile App - Complete UX Documentation

**Version**: 1.0  
**Last Updated**: February 13, 2026  
**Document Purpose**: Comprehensive UX specification for redesign and enhancement

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Product Vision & Core Values](#product-vision--core-values)
3. [User Personas](#user-personas)
4. [Design System](#design-system)
5. [Complete Screen Inventory](#complete-screen-inventory)
6. [User Flows](#user-flows)
7. [Interaction Patterns](#interaction-patterns)
8. [Accessibility Features](#accessibility-features)
9. [Real-time Communication](#real-time-communication)
10. [Current Pain Points & Opportunities](#current-pain-points--opportunities)

---

## Executive Summary

ParentalCare is a cross-platform mobile application (iOS/Android) designed to help family caregivers remotely support their elderly dependents with medication reminders, daily tasks, and emergency assistance. The app focuses on **dignity, trust, and ease of use** rather than surveillance.

### Key Statistics
- **2 User Roles**: Caregiver and Dependent
- **19 Screens**: Complete app coverage
- **Platform**: Flutter (iOS & Android)
- **Target Users**: Adults caring for elderly parents (50-70 age group) and elderly dependents (65-85 age group)

### Core Value Propositions
1. **For Caregivers**: Peace of mind through gentle monitoring and reminder management
2. **For Dependents**: Maintain independence with dignified assistance
3. **For Both**: Simple, accessible interface with voice message support

---

## Product Vision & Core Values

### Mission Statement
*"Helping families stay connected and care for loved ones with dignity, not surveillance."*

### Design Principles

1. **Dignity First**
   - No language suggesting surveillance or control
   - Positive, supportive tone in all messaging
   - Empowering rather than patronizing

2. **Simplicity**
   - Large touch targets (64dp for primary actions)
   - Minimal cognitive load per screen
   - Clear visual hierarchy

3. **Accessibility**
   - Font sizes: 18-36px for primary content
   - High contrast mode support
   - Reduce animations option
   - Voice notes as alternative to text

4. **Trust & Warmth**
   - Warm color palette (Teal, Purple, Orange)
   - Rounded corners (12-20px radii)
   - Friendly, conversational copy

---

## User Personas

### Persona 1: Sarah (Caregiver)
- **Age**: 52
- **Occupation**: Marketing Manager
- **Tech Savvy**: Moderate
- **Pain Points**: 
  - Juggling work and caring for aging mother
  - Anxiety about medication compliance
  - Difficulty coordinating with siblings
- **Goals**:
  - Set up reliable medication reminders
  - Get notified if reminders are missed
  - Quick access to emergency contacts

### Persona 2: Margaret (Dependent)
- **Age**: 78
- **Tech Savvy**: Low
- **Pain Points**:
  - Forgets medication times
  - Feels patronized by "tracking" apps
  - Struggles with small text
- **Goals**:
  - Clear, timely reminders
  - Hear daughter's voice in reminders
  - Easy emergency button access
  - Maintain sense of independence

---

## Design System

### Color Palette

#### Primary Colors
```
Primary (Warm Teal): #00BCD4 - Trust, healing
  Light: #62EFFF
  Dark: #008BA3

Secondary (Purple): #9C27B0 - Wisdom, dignity
  Light: #D05CE3
  Dark: #6A0080

Accent (Warm Orange): #FF9800 - Energy, warmth
  Light: #FFC947
  Dark: #C66900
```

#### Status Colors
```
Success (Mint Green): #26A69A - Completed tasks
Warning (Amber): #FFB300 - Pending/upcoming
Error (Coral Red): #EF5350 - Missed/urgent
Info (Blue): #42A5F5 - Snoozed items
```

#### Category Colors (Reminder Types)
```
Medicine: #7E57C2 (Purple)
Meal: #FF7043 (Orange)
Exercise: #66BB6A (Green)
Call: #42A5F5 (Blue)
General: #26A69A (Teal)
```

#### SOS Colors
```
SOS Red: #D32F2F (High visibility)
SOS Red Dark: #B71C1C
SOS Red Light: #FFCDD2
```

### Typography

**Font Families**:
- **Headings**: Poppins (600-700 weight)
- **Body**: Inter (400-600 weight)

**Font Scale**:
```
Display Large: 57px (Bold) - Splash screens
Display Medium: 45px (Bold) - Hero sections
Display Small: 36px (Bold) - Main headings
Headline Large: 32px (Semi-bold)
Headline Medium: 28px (Semi-bold)
Headline Small: 24px (Semi-bold) - Section headers
Title Large: 22px (Medium) - Card titles
Title Medium: 16px (Medium) - Subtitles
Body Large: 18px (Normal/Semi-bold) - Primary text
Body Medium: 16px (Normal/Semi-bold) - Secondary text
Body Small: 14px (Normal) - Labels, captions
Label Large: 18px (Semi-bold) - Buttons
Label Medium: 14px (Medium) - Form labels
Label Small: 12px (Medium) - Badges, chips
```

### Spacing System

**Base Unit**: 4px

```
xs: 4px - Tight spacing, chips
sm: 8px - Form field gaps
md: 16px - Card padding
lg: 24px - Section spacing
xl: 32px - Screen margins
xxl: 48px - Major sections
```

### Border Radius

```
sm: 8px - Chips, small badges
md: 12px - Input fields, small cards
lg: 16px - Standard cards, buttons
xl: 20px - Large cards
xxl: 24px - Modals, dialogs
```

### Touch Targets

```
Minimum: 48dp - Small interactive elements
Standard: 56dp - Standard buttons
Elderly-optimized: 64dp - Primary actions
SOS Button: 56dp height, full-width
```

### Elevation & Shadows

```
Level 1 (Cards): 
  offset: (0, 2), blur: 4, alpha: 0.1

Level 2 (Raised buttons):
  offset: (0, 4), blur: 8, alpha: 0.15

Level 3 (FAB):
  offset: (0, 6), blur: 12, alpha: 0.2

Level 4 (Modals):
  offset: (0, 8), blur: 16, alpha: 0.25
```

---

## Complete Screen Inventory

### Authentication Flow (5 Screens)

#### 1. Welcome Screen (`/`)
**Purpose**: First impression, brand introduction

**Visual Layout**:
- **Header** (Top third):
  - Large circular icon (120x120dp) with heart symbol
  - App name: "Parental Care" (36px, Poppins Bold, Primary color)
  - Tagline: "Stay connected with your loved ones" (22px)

- **Feature List** (Middle):
  - 3 feature items with icons:
    1. 🔔 Gentle Reminders - "Set reminders for medications, appointments, and daily tasks"
    2. 🆘 Emergency SOS - "Quick access to help when it's needed most"
    3. 🎤 Voice Messages - "Add personal voice notes to reminders"

- **CTA** (Bottom):
  - "Get Started" button (full-width, 64dp height)

**Navigation**:
- Forward: Role Selection Screen

---

#### 2. Role Selection Screen (`/role-selection`)
**Purpose**: Choose between Caregiver or Dependent persona

**Visual Layout**:
- **Header**:
  - Back button (top-left)
  - Title: "Who are you?" (28px)
  - Subtitle: "Select your role" + explanation text

- **Role Cards** (2 large cards):

  **Caregiver Card**:
  - Background: Primary container color
  - Icon: Heart (56x56dp, primary color)
  - Title: "I'm a Caregiver"
  - Description: "Set reminders, manage contacts, and monitor your loved ones"
  - Feature badges (wrap layout):
    - ✓ Create and manage reminders
    - ✓ Add voice notes to reminders
    - ✓ Set up emergency contacts
    - ✓ View activity status
  - Arrow icon (right edge)

  **Dependent Card**:
  - Background: Secondary container color
  - Icon: Person (56x56dp, secondary color)
  - Title: "I'm a Dependent"
  - Description: "Receive reminders and get help when you need it"
  - Feature badges:
    - ✓ Receive gentle reminders
    - ✓ Listen to voice messages
    - ✓ One-tap SOS emergency button
    - ✓ Simple, easy-to-use interface
  - Arrow icon

**Interaction**:
- Tap card → Navigate to Login with role parameter
- Haptic feedback on tap

**Navigation**:
- Back: Welcome Screen
- Forward: Login Screen (with role)

---

#### 3. Login Screen (`/login?role={caregiver|dependent}`)
**Purpose**: Authenticate existing users

**Visual Layout**:
- **Header**:
  - Back button → Role Selection
  - Role icon (64x64dp) - Heart (caregiver) or Person (dependent)
  - "Welcome Back" (28px, bold)
  - "Sign in as [Caregiver/Dependent]" (18px, muted)

- **Form**:
  - Email field:
    - Label: "Email"
    - Placeholder: "Enter your email"
    - Icon: Email outline (left)
    - Validation: Email format
  
  - Password field:
    - Label: "Password"
    - Placeholder: "Enter your password"
    - Icon: Lock (left)
    - Toggle: Eye icon (right) - Show/hide password
    - Validation: Minimum length

- **Error Display**:
  - Red banner with error icon + message

- **Actions**:
  - "Login" button (full-width, 64dp, gradient)
  - Divider with "OR"
  - "Login with Verification Code" button (outlined)
  - "Don't have an account? Register" link

**States**:
- Loading: Spinner in button, disabled state
- Error: Red banner above form
- Success: Navigate to home screen

**Navigation**:
- Success → Caregiver Home or Dependent Home (based on role)
- "Register" → Registration Screen
- "Login with Code" → Code login flow

---

#### 4. Registration Screen (`/register?role={role}`)
**Purpose**: Create new account

**Visual Layout**:
- Similar header to Login
- **Form Fields**:
  1. Name (text, required)
  2. Email (email, required, validation)
  3. Password (password, required, min 8 chars)
  4. Confirm Password (password, required, must match)
  5. Phone Number (optional, tel format)
  6. Timezone (dropdown/picker, auto-detected)

- **Actions**:
  - "Create Account" button (64dp)
  - "Already have an account? Login" link

**Validation**:
- Real-time email format check
- Password strength indicator
- Match validation for confirm password

**Navigation**:
- Success → Email Verification Screen
- "Login" → Login Screen

---

#### 5. Email Verification Screen (`/email-verification`)
**Purpose**: Verify email with 6-digit code

**Visual Layout**:
- **Header**:
  - "Verify Your Email" (28px)
  - Explanation: "We've sent a code to [email]"

- **Code Input**:
  - 6-digit code entry (large boxes, auto-focus)
  - Keyboard: Numeric

- **Actions**:
  - Auto-verify on 6 digits entered
  - "Resend Code" button (text button, countdown timer)

- **States**:
  - Waiting: Empty boxes
  - Entering: Filled boxes
  - Verifying: Loading spinner
  - Error: Red shake animation + message
  - Success: Checkmark animation → Navigate

**Navigation**:
- Success → Profile Setup or Home (based on completion)

---

### Caregiver Flow (6 Screens)

#### 6. Caregiver Home Screen (`/caregiver`)
**Purpose**: Main hub for caregivers, entry point to dependent management

**Visual Layout**:
- **App Bar**:
  - Title: "Hello, [Caregiver Name]" (28px)
  - Settings icon (right, 28x28dp)

- **Unique Code Card** (Top section):
  - Background: Light primary container
  - Border: Primary color (1px)
  - Icon: QR code (32x32dp)
  - Label: "Your Code"
  - Code Display: Large, bold, monospace (24px, 2pt letter-spacing)
  - Copy button (icon only, ripple effect)
  - Purpose: For dependents to connect

- **Content States**:

  **Empty State** (No dependents):
  - Illustration/Icon: People outline (large)
  - Heading: "No Dependents Yet"
  - Message: "Add a dependent to start creating reminders and stay connected."
  - "Add Dependent" button

  **Dependents List**:
  - Section Header: "Your Dependents" (22px, bold)
  - Dependent Cards (vertical list):
    - Avatar: Circle with first initial (48dp)
    - Name: Dependent name (18px, bold)
    - Subtitle: "Tap to view reminders"
    - Status Indicator: Small dot (green = good, yellow = attention, red = urgent)
    - Arrow icon (right)
    - Card background: Surface color
    - Border radius: 16px
    - Tap area: Full card

- **FAB**:
  - Icon: Person Add (24px)
  - Label: "Add Dependent"
  - Position: Bottom-right
  - Extended FAB style

**Interaction**:
- Tap Dependent Card → Navigate to Dependent Dashboard
- Tap FAB → Open "Add Dependent" dialog
- Copy Code → Clipboard + snackbar confirmation
- Pull to refresh: Reload dependents list

**Add Dependent Dialog**:
- Title: "Add Dependent"
- Search field: "Enter unique code" (9 characters)
- Search button or auto-search on complete
- Results: Show found user with name + confirmation button
- Actions: "Cancel" / "Send Request"

**Real-time Updates**:
- SignalR events for new link requests
- Auto-refresh on connection restored

**Navigation**:
- Dependent Card → Dependent Dashboard Screen
- Settings icon → Settings Screen

---

#### 7. Dependent Dashboard Screen (`/caregiver/dependent/:dependentId`)
**Purpose**: Comprehensive view of a specific dependent's reminders and status

**Visual Layout**:
- **App Bar**:
  - Back button (left)
  - Title: "[Dependent Name]" (24px)
  - Emergency Contacts icon (right)

- **Progress Section** (Top):
  - Daily Progress Bar:
    - Greeting: "Good morning/afternoon/evening, [Name]"
    - Date: "Tuesday, February 13" (formatted)
    - Visual Progress:
      - Circular progress indicator or horizontal bar
      - "X of Y completed today"
      - Color: Green (success) gradient
      - Animation: Fills on load

- **Urgent Alert Banner** (Conditional):
  - Visible if missed/overdue reminders exist
  - Background: Red gradient
  - Border: Red (2px)
  - Icon: Priority high (20dp)
  - Text: "X Reminder(s) need attention!!"
  - Close button (dismissible)

- **Quick Stats** (3 chips, horizontal):
  - **Done Chip**:
    - Badge: Green circle with count
    - Label: "Done"
    - Tappable filter
    - Selected state: Thicker border, darker background
  
  - **Pending Chip**:
    - Badge: Amber circle with count
    - Label: "Pending"
    - Tappable filter
  
  - **Missed Chip**:
    - Badge: Red circle with count
    - Label: "Missed"
    - Tappable filter

- **Today's Schedule Section**:
  - Header: "Today's Schedule" (22px, bold)
  - Clear filter button (if filtered)
  
  **Timeline View**:
  - Vertical timeline with connectors
  - Each item:
    - Time badge (left): "8:00 AM"
    - Reminder card:
      - Category icon (48x48dp, colored background)
      - Title (18px, semi-bold)
      - Status icon (16dp, colored)
      - Status badge (chip)
      - Voice note indicator (if present)
      - Description (if present, 2 lines max)
    - Sorted: Pending first, then missed, then completed

- **All Reminders Section**:
  - Header: "All Reminders" (22px, bold) + "Add" button
  - Template Cards (vertical list):
    - Category icon (48dp)
    - Title (16px, semi-bold)
    - Schedule: "8:00 AM • Daily" (14px, muted)
    - Priority badge (if high): "HIGH" (red chip)
    - Arrow icon (right)
    - Tap → Edit Reminder Screen

- **FAB**:
  - Icon: Add
  - Label: "Add Reminder"
  - Action: Navigate to Add Reminder Screen

**Interaction**:
- Tap stat chip → Filter timeline view
- Tap timeline item → Edit reminder
- Tap template card → Edit reminder
- Swipe to refresh → Reload data

**Empty States**:
- No reminders today: 
  - Icon: Calendar check (large, success color)
  - "All caught up!"
  - "No reminders scheduled for today"
  
- No filter results:
  - Icon: Filter off
  - "No [Status] Reminders"
  - "There are no [status] reminders for today"

**Loading State**:
- Skeleton screens for progress bar, stats, timeline items

**Real-time Updates**:
- SignalR subscription to dependent ID
- Auto-update on instance status changes
- New reminders appear immediately

**Navigation**:
- Back → Caregiver Home
- Emergency Contacts → Emergency Contacts Screen
- Add Reminder FAB → Add Reminder Screen
- Edit Reminder → Edit Reminder Screen

---

#### 8. Add Reminder Screen (`/caregiver/dependent/:dependentId/add-reminder`)
**Purpose**: Create a new reminder for a dependent

**Visual Layout**:
- **App Bar**:
  - Back button → Dependent Dashboard
  - Title: "Add Reminder"

- **Form** (Scrollable):
  
  1. **Title Field**:
     - Label: "Title"
     - Placeholder: "e.g., Take medication"
     - Icon: Title icon (left)
     - Required, validation

  2. **Description Field** (Optional):
     - Label: "Description (optional)"
     - Placeholder: "Additional details..."
     - Icon: Notes icon
     - Multi-line (2 rows)

  3. **Time Section**:
     - Label: "Time" (bold)
     - Time Picker Button:
       - Display: "9:00 AM" (large, 28px)
       - Icon: Clock
       - Tap → Native time picker (12-hour format)

  4. **Repeat Pattern Section**:
     - Label: "Repeat" (bold)
     - Segmented Control / Radio Group:
       - Once
       - Daily
       - Weekly
       - Specific Days
     
     **If Specific Days selected**:
     - Day chips (Mon-Sun):
       - Unselected: Gray, outlined
       - Selected: Primary color, filled
       - Multi-select

  5. **Priority Toggle**:
     - Label: "Priority"
     - Toggle: Normal / High
     - High: Red badge indicator

  6. **Voice Note Section**:
     - Label: "Voice Note (optional)" (bold)
     - Voice Recorder Widget:
       - Record button (red circle, microphone icon)
       - States:
         - Ready: "Tap to record"
         - Recording: Waveform animation + timer + "Recording..."
         - Recorded: Playback controls (play, delete) + duration
       - Max duration indicator

- **Actions**:
  - "Save Reminder" button (full-width, 64dp, bottom or sticky)
  - Loading state on save

**Validation**:
- Title required
- Time required (defaults to current time)
- Specific days: At least one day selected
- Voice note: Optional, max 2 minutes

**Interaction**:
- Auto-save draft on back (optional)
- Confirm discard if unsaved changes

**Navigation**:
- Success → Back to Dependent Dashboard with success snackbar
- Cancel → Confirmation dialog if changes made

---

#### 9. Edit Reminder Screen (`/caregiver/reminder/:reminderId/edit`)
**Purpose**: Modify existing reminder

**Visual Layout**:
- Same as Add Reminder Screen
- **Additional Actions**:
  - "Delete Reminder" button (text button, red, bottom)
  - Delete confirmation dialog:
    - Title: "Delete Reminder?"
    - Message: "This will remove the reminder and all future instances."
    - Actions: "Cancel" / "Delete"

- Pre-filled with existing reminder data
- "Save Changes" button instead of "Save Reminder"

**Navigation**:
- Back → Dependent Dashboard
- Delete → Confirmation → Back with snackbar

---

#### 10. Dependent Selector Screen (`/caregiver/dependents`)
**Purpose**: Choose dependent when multiple exist (intermediate screen)

**Visual Layout**:
- **App Bar**:
  - Back button
  - Title: "Select Dependent"

- **Dependent Cards** (Grid or List):
  - Avatar + Name
  - Last activity timestamp
  - Quick stats (optional): "3 pending reminders"
  - Tap → Navigate to dashboard

**Navigation**:
- Tap card → Dependent Dashboard
- Back → Caregiver Home

---

#### 11. Emergency Contacts Screen (`/caregiver/dependent/:dependentId/emergency-contacts`)
**Purpose**: Manage emergency contacts for a dependent

**Visual Layout**:
- **App Bar**:
  - Back button
  - Title: "Emergency Contacts"
  - Info icon → Explanation dialog

- **Contact List**:
  - Contact Cards:
    - Avatar/Icon (32dp)
    - Name (18px, bold)
    - Relationship (14px, muted) - e.g., "Daughter"
    - Phone number (16px, primary color, tappable)
    - Email (if provided)
    - Edit button (icon)
    - Delete button (icon)

- **Empty State**:
  - Icon: Contact phone
  - "No Emergency Contacts"
  - "Add contacts who will be notified in case of emergency"

- **FAB**: "Add Contact"

**Add/Edit Contact Dialog**:
- Name field
- Phone field (required)
- Email field (optional)
- Relationship dropdown
- Actions: "Cancel" / "Save"

**Navigation**:
- Back → Dependent Dashboard

---

### Dependent Flow (4 Screens)

#### 12. Dependent Home Screen (`/dependent`)
**Purpose**: Main interface for dependents - today's reminders + SOS access

**Visual Layout**:
- **Header** (No app bar, custom):
  - Greeting: "Good morning/afternoon/evening," (22px)
  - Name: "[Dependent Name]" (36px, bold)
  - Date: "Tuesday, February 13" (18px, muted)
  - Settings icon (top-right, 28dp)

- **Unique Code Card** (Compact version):
  - Icon + "Your Code: XXXXX" + Copy button
  - Single line, small padding

- **Link Request Banner** (Conditional):
  - Visible if pending caregiver requests exist
  - Background: Info light gradient
  - Avatar + Name: "[Caregiver Name] wants to connect"
  - Button: "Review Request"
  - Tap → Link Request Dialog

- **Today's Progress** (If reminders exist):
  - Same as caregiver dashboard
  - Visual progress bar with completion stats

- **Today's Reminders Section**:
  - Header: "Today's Reminders" (28px, bold)

  **Empty State**:
  - Large icon: Check circle (80dp, success color)
  - "All done for now!" (28px, bold, success)
  - "No pending reminders. Enjoy your day!" (18px)
  - Background: Success gradient

  **"Up Next" Hero Card** (First pending reminder):
  - Background: Warning light gradient
  - Border: Warning color (2px)
  - Badge: "UP NEXT" (warning chip, top-left)
  - Info button (top-right) → Details modal
  - Content:
    - Category icon (52dp)
    - Title (18px, bold, warning dark)
    - Time (24px, bold, warning)
  - Action:
    - "Mark as Done" button (full-width, warning gradient)
  - Shadow: Elevated
  - Entry animation: Fade + scale

  **Reminder Grid** (2 columns):
  - Reminder Buttons (compact):
    - Category icon (24dp)
    - Title (16px, truncated)
    - Time (14px)
    - Status badge (small chip)
    - Voice note indicator (if present)
    - Loading indicator (if completing)
    - Aspect ratio: ~1.55:1
    - Status colors:
      - Pending: Warning gradient
      - Completed: Success gradient (strike-through, checkmark)
      - Missed: Error gradient
      - Snoozed: Info gradient
  - Staggered entrance animations (50ms delay between items)
  - Tap → Complete reminder (with confirmation)
  - Long-press or info icon → Details modal

- **SOS Button** (Fixed at bottom):
  - Position: Sticky footer, centered
  - Background: White surface with top shadow
  - Button:
    - Width: Full-width minus padding (280dp max)
    - Height: 56dp
    - Background: Red gradient (Crimson to Dark Red)
    - Icon: SOS icon (22dp)
    - Text: "SOS" (18px, bold, white)
    - Subtitle: "Hold 3s" (12px, white 85%)
    - Interaction: Long-press (3 seconds) with progress indicator
    - Pulse animation: Subtle breathing effect (scale 1.0-1.08, 2s loop)
    - Haptic: Heavy impact on long-press start, periodic clicks during hold
  - Shadow: Elevated

**Interaction**:
- Tap reminder button → Mark complete (optimistic UI + haptic)
- Tap info icon → Details modal
- Long-press SOS → Countdown + navigate to SOS Screen
- Pull to refresh → Reload data

**Loading State**:
- Skeleton: Greeting, name placeholder, reminder grid placeholders

**Real-time Updates**:
- SignalR connection for live reminder updates
- Auto-refresh on new instances
- Link requests appear immediately

**Navigation**:
- Settings icon → Settings Screen
- SOS button → SOS Screen
- Reminder tap → Complete action (in-place)

---

#### 13. Reminder Alert Screen (`/dependent/reminder/:instanceId`)
**Purpose**: Full-screen alert for a specific reminder (push notification target)

**Visual Layout**:
- **Background**: Gradient based on reminder category
- **Content** (Centered):
  - Category Icon (large, 96dp)
  - Title (36px, bold)
  - Time (28px)
  - Description (if present, 18px, 4 lines max)
  - Voice Note Player (if present):
    - Play/Pause button (large)
    - Waveform visualization
    - Duration/Progress
    - Auto-play on load (optional setting)

- **Actions** (Bottom):
  - "Mark as Done" button (full-width, 64dp, success gradient)
  - "Snooze 10 min" button (full-width, 64dp, info color)
  - "Back" link (text button)

**Interaction**:
- Auto-play voice note
- Haptic on button press
- Celebration animation on "Done"

**Navigation**:
- Done → Back to Dependent Home with snackbar
- Snooze → Back with snackbar
- Back → Dependent Home

---

#### 14. SOS Screen (`/dependent/sos`)
**Purpose**: Emergency activation screen with countdown

**Visual Layout**:
- **Background**: Red gradient (full screen)

- **Content** (Centered):
  
  **During Countdown**:
  - Large Timer Circle:
    - Red gradient fill
    - White countdown number (72px, bold)
    - Pulsing animation (scale 1.0-1.1)
    - Progress ring (optional)
  - Heading: "SOS Activated" (36px, white, bold)
  - Message: "Emergency contacts will be notified in X seconds" (18px, white)
  - Haptic: Heavy impact every second for last 3 seconds

  **Cancel Button** (Bottom):
  - Full-width, 72dp height
  - Success gradient
  - Text: "CANCEL - I'm Okay" (24px, bold, white)
  - Icon: Checkmark

  **After Countdown** (Completed state):
  - Icon: Checkmark in circle (120dp, success)
  - "Help is on the way" (36px, bold)
  - Message: "Your emergency contacts have been notified."
  - Emergency contacts list:
    - Name, relationship, phone (tappable)
  - "I'm Okay Now" button → Cancel alert + go home

**Interaction**:
- Auto-trigger after countdown (10 seconds default)
- Cancel button → Immediate cancel + snackbar + navigate home
- Notification sent to all emergency contacts (push + SMS if configured)

**Navigation**:
- Cancel → Dependent Home with success message
- Complete → Stay on screen with contacts

---

### Settings & Profile (4 Screens)

#### 15. Settings Screen (`/settings`)
**Purpose**: App configuration and account management

**Visual Layout**:
- **App Bar**:
  - Back button
  - Title: "Settings"

- **Profile Section**:
  - Avatar (circle, 64dp, with edit overlay)
  - Name (22px, bold)
  - Email (16px, muted)
  - Role badge: "Caregiver" or "Dependent" (chip)
  - "Edit Profile" button → Edit Profile Screen

- **Account Settings**:
  - **Timezone**:
    - Label: "Timezone"
    - Value: Current timezone (e.g., "America/New_York")
    - Arrow → Timezone Settings Screen
  
- **Linked Users**:
  - Label: "Connected Users" (section header)
  - User Cards:
    - Avatar + Name + Role
    - Relationship: "Your caregiver" / "Your dependent"
    - Arrow → Linked User Detail Screen
  - "Add Connection" button (if none)

- **Appearance**:
  - **Theme Mode**:
    - Radio group: System / Light / Dark
    - Current selection highlighted
  
  - **High Contrast**:
    - Toggle switch
    - Description: "Enhance text readability"
  
  - **Reduce Animations**:
    - Toggle switch
    - Description: "Minimize motion effects"

- **Notifications**:
  - **Notification Sound**:
    - Toggle switch
  
  - **Haptic Feedback**:
    - Toggle switch

- **About**:
  - App Version
  - Privacy Policy link
  - Terms of Service link
  - Support/Help link

- **Account Actions**:
  - **Logout Button**:
    - "Swipe to Logout" widget
    - Swipe gesture required for safety
    - Confirmation dialog

**Navigation**:
- Back → Previous screen (context-aware)
- Edit Profile → Edit Profile Screen
- Timezone → Timezone Settings Screen
- Linked User → Linked User Detail Screen
- Logout → Welcome Screen (clears auth)

---

#### 16. Edit Profile Screen (`/settings/edit-profile`)
**Purpose**: Update account information

**Visual Layout**:
- Form fields:
  - Name (required)
  - Email (disabled, not editable)
  - Phone Number (optional)
  - Avatar upload (optional)
- Save button

**Navigation**:
- Back → Settings
- Save → Settings with success snackbar

---

#### 17. Timezone Settings Screen (`/settings/timezone`)
**Purpose**: Select timezone for reminder scheduling

**Visual Layout**:
- Search field (filter timezones)
- Timezone list (grouped by region)
  - Americas, Europe, Asia, etc.
- Current selection highlighted
- Tap → Select + navigate back

**Navigation**:
- Back → Settings
- Select → Auto-save + navigate back

---

#### 18. Linked User Detail Screen (`/settings/linked-user`)
**Purpose**: View details and manage relationship with linked user

**Visual Layout**:
- User info:
  - Avatar (large, 96dp)
  - Name (28px)
  - Role (chip)
  - Email
  - Phone (if provided)
  - Unique code

- Relationship info:
  - Status: Active
  - Connected since: [Date]

- Actions:
  - "Remove Connection" button (destructive, red)
    - Confirmation dialog required

**Navigation**:
- Back → Settings
- Remove → Confirmation → Settings with snackbar

---

#### 19. Profile Setup Screen (`/profile-setup?role={role}`)
**Purpose**: Complete profile after registration (intermediate step)

**Visual Layout**:
- Similar to Edit Profile
- Additional fields:
  - Avatar selection/upload
  - Phone verification (optional)
- Skip button (optional)

**Navigation**:
- Complete → Home Screen
- Skip → Home Screen

---

## User Flows

### Flow 1: First-Time Caregiver Setup

```
1. Launch App
   ↓
2. Welcome Screen
   → Tap "Get Started"
   ↓
3. Role Selection Screen
   → Tap "I'm a Caregiver" card
   ↓
4. Login Screen (role=caregiver)
   → Tap "Don't have an account? Register"
   ↓
5. Registration Screen
   → Fill form (Name, Email, Password, Timezone)
   → Tap "Create Account"
   ↓
6. Email Verification Screen
   → Enter 6-digit code
   → Auto-verify
   ↓
7. Profile Setup Screen (Optional)
   → Upload avatar / Skip
   ↓
8. Caregiver Home Screen (Empty State)
   → View unique code
   → Tap "Add Dependent" FAB
   ↓
9. Add Dependent Dialog
   → Enter dependent's unique code
   → Tap "Send Request"
   ↓
10. (Dependent must accept request)
    ↓
11. Caregiver Home Screen (With Dependent)
    → Tap dependent card
    ↓
12. Dependent Dashboard Screen (Empty)
    → Tap "Add Reminder" FAB
    ↓
13. Add Reminder Screen
    → Fill form (Title, Time, Repeat, etc.)
    → Record voice note (optional)
    → Tap "Save Reminder"
    ↓
14. Dependent Dashboard Screen (With Reminder)
    → View in "All Reminders" section
    → Wait for scheduled time to see in timeline
```

**Total Steps**: 14  
**Estimated Time**: 8-12 minutes  
**Key Success Metrics**: 
- Registration completion rate
- First reminder creation rate
- Dependent linking rate

---

### Flow 2: First-Time Dependent Setup

```
1. Launch App
   ↓
2. Welcome Screen
   → Tap "Get Started"
   ↓
3. Role Selection Screen
   → Tap "I'm a Dependent" card
   ↓
4. Login Screen (role=dependent)
   → Tap "Register"
   ↓
5. Registration Screen
   → Fill form
   → Tap "Create Account"
   ↓
6. Email Verification Screen
   → Enter code
   ↓
7. Dependent Home Screen (Empty)
   → View unique code (share with caregiver)
   → Wait for link request
   ↓
8. (Caregiver sends request)
   ↓
9. Link Request Banner appears
   → Tap "Review Request"
   ↓
10. Link Request Dialog
    → View caregiver details
    → Enter 5-digit code
    → Tap "Accept"
    ↓
11. Dependent Home Screen (Linked)
    → Wait for caregiver to add reminders
    ↓
12. (Caregiver adds reminder)
    ↓
13. Reminder appears in grid
    → View today's reminders
```

**Total Steps**: 13  
**Estimated Time**: 6-10 minutes  
**Key Success Metrics**:
- Successful linking rate
- Code entry error rate
- Time to first reminder received

---

### Flow 3: Daily Caregiver Check-In

```
1. Launch App (already logged in)
   ↓
2. Caregiver Home Screen
   → View dependent cards
   → Check status indicators
   ↓
3. Tap dependent card
   ↓
4. Dependent Dashboard Screen
   → View progress bar (e.g., "3 of 5 completed")
   → Check urgent banner (if any missed)
   → Scan timeline for pending items
   ↓
5a. If all good:
    → Pull to refresh
    → Navigate back

5b. If issue found:
    → Tap missed reminder in timeline
    → Review details
    → Contact dependent (external action)
```

**Total Steps**: 5-6  
**Estimated Time**: 30-60 seconds  
**Frequency**: 2-5 times daily  
**Key Success Metrics**:
- Time to identify missed reminders
- Pull-to-refresh usage rate

---

### Flow 4: Dependent Completes Reminder

```
1. Dependent receives push notification
   → "Take medication - 9:00 AM"
   ↓
2. Tap notification
   ↓
3. Reminder Alert Screen opens
   → Auto-plays voice note (if present)
   → View reminder details
   ↓
4a. Mark as Done:
    → Tap "Mark as Done" button
    → Celebration animation
    → Success snackbar
    → Navigate back to home
    ↓
5a. Dependent Home Screen
    → Reminder card updates to "completed" (green, checkmark)
    → Progress bar updates

4b. Snooze:
    → Tap "Snooze 10 min"
    → Navigate back
    → Receive new notification after 10 min

4c. Miss:
    → Ignore notification
    → After 30 min (auto-miss):
      → Status changes to "missed" (red)
      → Caregiver sees urgent banner
```

**Total Steps**: 4-5  
**Estimated Time**: 10-30 seconds  
**Frequency**: 3-8 times daily  
**Key Success Metrics**:
- On-time completion rate
- Snooze rate
- Miss rate

---

### Flow 5: Emergency SOS Activation

```
1. Dependent feels unwell
   ↓
2. Open App (if not already open)
   → Dependent Home Screen visible
   ↓
3. Locate SOS Button (fixed at bottom)
   → Large, red, highly visible
   ↓
4. Long-press SOS button (3 seconds)
   → Visual progress indicator fills
   → Haptic feedback (pulse during press)
   ↓
5. SOS Screen opens automatically
   → Countdown begins (10 seconds)
   → Large timer display (pulsing)
   → "Emergency contacts will be notified in X seconds"
   ↓
6a. If genuine emergency:
    → Wait for countdown to complete
    → Periodic haptic feedback (last 3 seconds)
    ↓
7a. SOS Completed State
    → "Help is on the way"
    → Push notifications sent to all emergency contacts
    → List of notified contacts displayed
    → Phone numbers tappable (to call directly)

6b. If accidental press:
    → Tap "CANCEL - I'm Okay" button
    → Immediate cancellation
    → Success snackbar: "SOS cancelled - You're okay!"
    → Navigate back to Dependent Home

8. (Emergency contacts receive):
    → Push notification: "[Name] has triggered SOS"
    → (Future: SMS backup notification)
```

**Total Steps**: 7-8  
**Estimated Time**: 15-20 seconds (including countdown)  
**Key Success Metrics**:
- False positive rate (accidental activations)
- Cancellation window usage
- Time to notification delivery

---

### Flow 6: Creating a Recurring Reminder

```
1. Caregiver Home → Dependent Dashboard
   ↓
2. Tap "Add Reminder" FAB
   ↓
3. Add Reminder Screen
   ↓
4. Fill Title field
   → "Take blood pressure medication"
   ↓
5. Tap Time picker
   → Select "9:00 AM"
   ↓
6. Select Repeat pattern
   → "Specific Days"
   ↓
7. Select Days
   → Tap Mon, Wed, Fri chips
   → Chips turn primary color (selected state)
   ↓
8. Set Priority
   → Toggle "High" (optional)
   ↓
9. Add Description (optional)
   → "Take with food and water"
   ↓
10. Record Voice Note (optional)
    → Tap microphone button
    → Record: "Hi Mom, don't forget to take your blood pressure pill with breakfast!"
    → Waveform animates during recording
    → Tap stop
    → Preview playback
    ↓
11. Tap "Save Reminder" button
    → Loading state (spinner in button)
    → Success snackbar: "Reminder created"
    → Navigate back to Dependent Dashboard
    ↓
12. Dependent Dashboard Screen
    → New reminder appears in "All Reminders" section
    → (Future instances automatically created for Mon/Wed/Fri)
```

**Total Steps**: 12  
**Estimated Time**: 2-4 minutes  
**Key Success Metrics**:
- Voice note usage rate
- Recurring reminder setup rate
- Average reminder creation time

---

### Flow 7: Linking Dependent and Caregiver

**From Caregiver Side:**
```
1. Caregiver obtains dependent's unique code
   → Phone call, text message, or in-person
   ↓
2. Caregiver Home Screen
   → Tap "Add Dependent" FAB
   ↓
3. Add Dependent Dialog opens
   → Enter 9-character unique code
   → (Auto-search on complete, or tap search)
   ↓
4. Search result displays
   → Shows dependent's name + role
   → "Send Request" button
   ↓
5. Tap "Send Request"
   → Loading state
   → Success snackbar: "Request sent to [Name]"
   → Dialog closes
   ↓
6. Wait for dependent to accept
   → Real-time: SignalR event when accepted
   → Dependent card appears on home screen
```

**From Dependent Side:**
```
7. Dependent Home Screen
   → Link Request Banner appears (real-time)
   → Shows caregiver's name + avatar
   → "Review Request" button
   ↓
8. Tap "Review Request"
   → Link Request Dialog opens
   ↓
9. Link Request Dialog
   → Caregiver details displayed
   → Enter 5-digit verification code
     (Code was generated by system, caregiver must share it)
   ↓
10. Tap "Accept"
    → Verification + API call
    → Success snackbar: "Connected with [Caregiver Name]!"
    → Dialog closes
    → Banner dismisses
    ↓
11. (Both users immediately see connection)
    → Caregiver: Dependent card on home screen
    → Dependent: Caregiver in Settings > Linked Users
```

**Total Steps**: 11  
**Estimated Time**: 2-3 minutes  
**Error Cases**:
- Invalid code → Error message + retry
- Expired request → Regenerate code
- Network failure → Retry mechanism

---

### Flow 8: Editing Existing Reminder

```
1. Dependent Dashboard Screen
   ↓
2. Tap reminder card in "All Reminders" section
   ↓
3. Edit Reminder Screen opens
   → Pre-filled with existing data
   ↓
4. Modify any field (e.g., change time from 9am to 8am)
   ↓
5. Tap "Save Changes" button
   → Confirmation dialog (optional): "This will update all future instances"
   → Tap "Confirm"
   → Loading state
   → Success snackbar: "Reminder updated"
   ↓
6. Navigate back to Dependent Dashboard
   → Updated reminder reflected
   → (SignalR event sent to dependent)
   ↓
7. Dependent's app updates in real-time
   → Timeline refreshed with new time
```

**Alternative: Delete Reminder**
```
4. Scroll to bottom of Edit Reminder Screen
   ↓
5. Tap "Delete Reminder" (red text button)
   ↓
6. Confirmation Dialog
   → "Delete Reminder?"
   → "This will remove the reminder and all future instances."
   → Actions: "Cancel" / "Delete"
   ↓
7. Tap "Delete"
   → API call
   → Success snackbar: "Reminder deleted"
   ↓
8. Navigate back
   → Reminder removed from list
```

**Total Steps**: 7-8  
**Estimated Time**: 30-60 seconds  

---

## Interaction Patterns

### Touch Interactions

#### 1. Tap
- **Use Cases**: Primary actions, navigation, selections
- **Feedback**:
  - Haptic: Light impact (selection click)
  - Visual: Ripple effect (Material Design)
  - State: Pressed state (0.5-0.8 alpha overlay)

#### 2. Long Press
- **Use Cases**: SOS activation, alternative actions
- **Feedback**:
  - Haptic: Medium impact on start, periodic clicks during hold
  - Visual: Progress indicator fills
  - Duration: 3 seconds (SOS), 0.5 seconds (context menu)

#### 3. Swipe
- **Use Cases**: Dismiss cards, logout, refresh
- **Feedback**:
  - Haptic: Light impact on threshold
  - Visual: Card follows finger, background color change
  - Thresholds: 40% for dismiss, 120px for refresh

#### 4. Pull to Refresh
- **Use Cases**: Reload data on all list screens
- **Feedback**:
  - Visual: Circular progress indicator, arrow rotation
  - Haptic: Light impact at pull threshold
  - Loading state: Spinner + disabled scroll

### Gesture Patterns

#### Card Tap Animations
```
Sequence:
1. onTapDown: Scale 1.0 → 0.97 (100ms, easeInOut)
2. onTapUp: Scale 0.97 → 1.0 (100ms, easeInOut)
3. onTap: Navigate or trigger action

Disabled if: Reduce Animations setting enabled
```

#### Button Press
```
Sequence:
1. onPress: Shadow elevation 2dp → 0dp (50ms)
2. onRelease: Shadow 0dp → 2dp (50ms)
3. Background: Gradient brightens 10% during press
```

#### List Item Entrance
```
Staggered fade-in + slide animation:
- Duration: 200ms per item
- Delay: 50ms between items
- Slide: 5% X-axis (horizontal) or 10% Y-axis (vertical)
- Curve: easeOut
- Skip if: Reduce Animations enabled
```

### Loading States

#### 1. Button Loading
- Spinner replaces icon
- Text changes (e.g., "Saving..." instead of "Save")
- Disabled state (no interaction)
- Maintain size (no layout shift)

#### 2. Screen Loading (Skeleton)
- Shimmer animation on placeholders
- Gray boxes with rounded corners
- Preserve layout structure
- No content shift on load complete

#### 3. Inline Loading (Pull to Refresh)
- Circular progress indicator at top
- Content dimmed slightly
- Scroll disabled during load
- Smooth transition to loaded state

### Feedback Patterns

#### Haptic Feedback Hierarchy
```
Light Impact (SelectionClick):
  - Chip selection
  - Toggle switches
  - Radio buttons
  - Copy actions

Medium Impact:
  - Standard buttons
  - Card taps
  - Navigation actions
  - Form submissions

Heavy Impact:
  - Critical actions (SOS, Delete)
  - Countdown ticks (last 3 seconds)
  - Error states
  - Success confirmations
```

#### Visual Feedback
```
Success:
  - Green checkmark icon
  - Success color gradient background
  - Scale animation (0.5 → 1.2 → 1.0)
  - Duration: 800ms

Error:
  - Red error icon
  - Shake animation (X: -10 → +10 → 0, 3 cycles)
  - Error color border
  - Duration: 600ms

Warning:
  - Amber warning icon
  - Pulsing animation (alpha: 1.0 → 0.7, loop)

Info:
  - Blue info icon
  - Slide-in from top (Y: -50 → 0)
```

### Snackbar Pattern
```
Position: Bottom center (56dp from bottom on mobile)
Duration: 
  - Short: 2 seconds (success)
  - Long: 4 seconds (error, info)
  - Indefinite: Actions required

Layout:
  - Icon (24dp, left)
  - Message (16px, body text, 2 lines max)
  - Action button (optional, right)

Animations:
  - Enter: Slide up (200ms, easeOut)
  - Exit: Fade out (150ms, easeIn)

Dismissal:
  - Auto-dismiss after duration
  - Tap action button
  - Swipe down
```

### Modal Dialog Pattern
```
Background: Scrim (Black 40% alpha)
Enter Animation:
  - Scale: 0.8 → 1.0 (250ms, easeOut)
  - Fade: 0 → 1 (250ms)

Exit Animation:
  - Scale: 1.0 → 0.8 (200ms, easeIn)
  - Fade: 1 → 0 (200ms)

Layout:
  - Max width: 560dp (tablet)
  - Padding: 24dp
  - Border radius: 24dp
  - Elevation: 8dp

Actions:
  - Cancel/negative (left)
  - Confirm/positive (right, primary color)
  - Minimum 48dp height
```

### Voice Note Interaction
```
Record Flow:
1. Tap microphone button
   → Button animates (pulse)
   → Start recording
   
2. During recording:
   → Waveform animation (visual feedback)
   → Timer display (MM:SS)
   → Stop button appears (red)
   → Max duration indicator (progress bar)
   
3. Stop recording:
   → Tap stop button
   → Processing animation (brief)
   → Preview controls appear (play, delete)
   
4. Playback:
   → Tap play button
   → Play icon → Pause icon
   → Progress scrubber
   → Duration display (current / total)
   
5. Delete:
   → Tap delete button (X icon)
   → Confirmation: "Delete recording?"
   → Return to initial state
```

---

## Accessibility Features

### Visual Accessibility

#### Font Scaling
- **Support**: System font scaling up to 200%
- **Implementation**: Use relative units (sp, em) not fixed pixels
- **Testing**: Verify layout at 100%, 150%, 200% scaling

#### Color Contrast
- **Minimum Ratio**: 4.5:1 for normal text, 3:1 for large text (WCAG AA)
- **High Contrast Mode**: 7:1 ratio, bolder fonts, thicker borders
- **Testing**: All text-background combinations meet WCAG standards

#### Color Independence
- **No color-only indicators**: Status always shown with icon + text
- **Example**: Reminder status uses icon (✓, !, ⊗) + color + text label
- **Testing**: Grayscale mode verification

#### Focus Indicators
- **Keyboard navigation**: Visible focus ring (2px, primary color)
- **Size**: Focus area 2dp larger than target
- **Contrast**: Focus ring contrasts with both element and background

### Motor Accessibility

#### Touch Target Sizing
- **Minimum**: 48x48dp (WCAG guidelines)
- **Elderly-optimized**: 64x64dp for primary actions
- **SOS button**: 56dp height (emergency use case)
- **Spacing**: 8dp minimum between targets

#### Error Prevention
- **Confirmations**: Destructive actions require confirmation
- **Undo options**: Where possible (e.g., snackbar with undo)
- **Cancellation windows**: SOS has 10-second countdown

### Auditory Accessibility

#### Haptic Feedback
- **Always available**: Never rely on sound alone
- **Configurable**: Setting to enable/disable
- **Patterns**: Different intensities for different actions

#### Voice Notes
- **Visual transcript**: (Future feature)
- **Playback controls**: Play, pause, scrub, speed control
- **Visual indicators**: Waveform, progress bar, duration

### Cognitive Accessibility

#### Reduce Animations
- **Setting**: "Reduce Animations" toggle in Settings
- **Implementation**: 
  - Disable entrance animations
  - Disable decorative animations (pulse, breathing)
  - Maintain functional animations (loading, transitions)
  - Reduce animation duration by 50%

#### Clear Language
- **Tone**: Friendly, simple, direct
- **Sentence length**: Short (< 20 words)
- **Jargon**: Minimal technical terms
- **Icons**: Always paired with labels

#### Error Messages
- **Format**: "Problem: [Issue]. Solution: [Action]"
- **Example**: "Invalid code. Please check and try again."
- **Color**: Red background + icon + text (not color alone)

### Screen Reader Support

#### Semantic HTML/Widgets
- **All interactive elements**: Marked as buttons, links, etc.
- **Headings**: Proper hierarchy (H1, H2, H3)
- **Landmarks**: Navigation, main content, complementary

#### Alternative Text
- **Images**: Descriptive alt text
- **Icons**: Semantic labels (e.g., "Settings icon" not "Gear")
- **Decorative**: aria-hidden="true" or empty alt

#### Announcements
- **Live regions**: Status changes announced
- **Example**: "Reminder completed" announced on success
- **Politeness**: 
  - Assertive: Errors, critical updates
  - Polite: Success messages, info

#### Semantic Labels
```dart
Semantics(
  label: 'Reminder: Take medication at 9:00 AM, Status: Pending, has voice note',
  button: true,
  child: ReminderCard(...),
)
```

### Internationalization (i18n)

#### Current Support
- **Language**: English (en-US)
- **Date/Time**: Locale-aware formatting (e.g., "Feb 13, 2026" vs "13 Feb 2026")
- **Timezone**: User-selectable, properly converted

#### Future Expansion
- **Target languages**: Spanish, French, Mandarin
- **Right-to-left**: Arabic, Hebrew support
- **Cultural considerations**: Color meanings, icon interpretations

---

## Real-time Communication

### SignalR WebSocket Connection

#### Connection Flow
```
1. App Launch / Login:
   → Establish SignalR connection to /hubs/sync
   → Authenticate with JWT token (Bearer header)
   → Connection established (state: Connected)

2. Subscription Setup:
   → Caregiver: Subscribe to each dependent ID
   → Dependent: Auto-subscribed to own user ID
   → Multiple subscriptions supported

3. Maintain Connection:
   → Ping every 30 seconds (keep-alive)
   → Auto-reconnect on network loss
   → Exponential backoff (2s, 4s, 8s, max 30s)

4. App Lifecycle:
   → Backgrounded: Connection maintained (iOS/Android)
   → Resumed: Verify connection + refresh data
   → Logout: Disconnect + clear subscriptions
```

#### Events Sent by Server

**Link Management**:
```javascript
LinkRequestReceived: {
  caregiverId: string,
  dependentId: string,
  caregiverName: string,
  linkingCode: string
}

LinkVerified: {
  caregiverId: string,
  dependentId: string
}

LinkRemoved: {
  caregiverId: string,
  dependentId: string
}
```

**Reminder Management**:
```javascript
ReminderCreated: {
  reminderId: string,
  dependentId: string,
  reminderData: ReminderDTO
}

ReminderUpdated: {
  reminderId: string,
  reminderData: ReminderDTO
}

ReminderDeleted: {
  reminderId: string
}
```

**Instance Management**:
```javascript
InstanceCreated: {
  instanceId: string,
  reminderId: string,
  dependentId: string,
  scheduledTime: string (ISO 8601)
}

InstanceStatusChanged: {
  instanceId: string,
  status: 'pending' | 'completed' | 'missed' | 'snoozed',
  escalationLevel: number
}
```

**SOS Events**:
```javascript
SosTriggered: {
  sosEventId: string,
  dependentId: string,
  dependentName: string,
  triggeredAt: string (ISO 8601)
}

SosResolved: {
  sosEventId: string,
  resolvedBy: string
}

SosCancelled: {
  sosEventId: string
}
```

**Presence**:
```javascript
UserOnline: {
  userId: string,
  userName: string
}

Pong: (keep-alive response)
```

#### Client Methods (Sent to Server)

```javascript
// Subscribe to dependent's updates (caregiver only)
SubscribeToDependent(dependentId: string)

// Unsubscribe from dependent
UnsubscribeFromDependent(dependentId: string)

// Keep-alive ping
Ping()

// Announce online status
NotifyOnline()
```

#### UI Update Triggers

**Caregiver Home Screen**:
- `LinkRequestReceived` → Show request banner
- `LinkVerified` → Refresh dependents list
- `LinkRemoved` → Remove dependent card

**Dependent Dashboard Screen**:
- `InstanceCreated` → Add to timeline
- `InstanceStatusChanged` → Update card status
- `ReminderCreated/Updated/Deleted` → Refresh reminders list

**Dependent Home Screen**:
- `InstanceCreated` → Add reminder card
- `InstanceStatusChanged` → Update status + progress bar
- `LinkRequestReceived` → Show link banner
- `ReminderCreated` → Show new reminder

#### Offline Handling
```
1. Connection lost:
   → State: Reconnecting
   → Show subtle indicator (optional)
   → Queue events (not implemented, pull-to-refresh instead)

2. Reconnection successful:
   → State: Connected
   → Full data refresh (API calls)
   → Resubscribe to all dependents

3. Extended offline:
   → User can still view cached data
   → Actions queued for later (not implemented)
   → Pull-to-refresh to sync
```

---

## Current Pain Points & Opportunities

### Identified UX Issues

#### 1. Onboarding Complexity
**Problem**: Linking caregiver and dependent requires multiple steps with code exchange

**Current Flow**:
1. Dependent shares 9-character unique code
2. Caregiver enters code to send request
3. System generates 5-digit verification code
4. Caregiver shares verification code (via phone/text)
5. Dependent enters verification code to accept

**Pain Point**: Requires external communication for verification code

**Opportunity**:
- **Option A**: QR code scanning for instant linking
- **Option B**: In-app SMS/push notification for verification code
- **Option C**: One-time password (OTP) sent to both devices

**Design Proposal**:
```
Simplified Flow:
1. Dependent generates QR code (displayed on screen)
2. Caregiver scans QR code in app
3. Dependent receives push notification with approval prompt
4. Tap "Accept" (no code entry required)
5. Instant connection
```

---

#### 2. Voice Note Discovery
**Problem**: Users may not notice voice note feature

**Current State**:
- Voice note recorder hidden in form
- Small microphone icon indicator on cards
- No onboarding tutorial

**Opportunity**:
- Prominent call-to-action in Add Reminder screen
- Animated tutorial on first reminder creation
- Voice note badge on caregiver home screen ("3 reminders with voice notes")

**Design Proposal**:
```
First-Time Experience:
1. Add Reminder Screen opens
2. Tooltip appears over voice note section
   → "💡 Tip: Add your voice to make reminders more personal!"
   → "Try it" button
3. One-tap recording demo
4. Option to use in current reminder or skip
```

---

#### 3. Notification Escalation Visibility
**Problem**: Caregivers don't see escalation levels clearly

**Current State**:
- Escalation happens on backend (Level 0, 1, 2)
- Caregiver only sees "missed" status
- No differentiation between "just missed" and "missed multiple escalations"

**Opportunity**:
- Visual urgency indicators
- Timeline showing escalation history
- Alert severity levels (gentle → repeated → urgent)

**Design Proposal**:
```
Reminder Card Enhancement:
- Level 0 (on-time): Amber border, normal icon
- Level 1 (+5 min): Amber, warning icon, "⚠️" badge
- Level 2 (+10 min): Red, urgent icon, "🔴" badge
- Missed (+30 min): Red, X icon, "MISSED" text

Timeline View:
- Show notification attempt timestamps
- "Notified 3 times: 9:00, 9:05, 9:10"
- Visual history: dots or timeline markers
```

---

#### 4. SOS Feedback Loop
**Problem**: Dependent doesn't know if emergency contacts were actually notified

**Current State**:
- "Help is on the way" message
- List of contacts (names only)
- No confirmation of notification delivery

**Opportunity**:
- Delivery status indicators
- Read receipts (if contacts open notification)
- Fallback mechanisms (SMS if push fails)

**Design Proposal**:
```
SOS Completed Screen:
- Contact cards with status:
  ✓ [Name] - Notified (push)
  ✓ [Name] - Notified (SMS)
  ⏳ [Name] - Sending...
  ⚠️ [Name] - Failed (Retry button)
  
- "X of Y contacts notified"
- Auto-retry failed notifications
- Manual retry button per contact
```

---

#### 5. Reminder Time Confusion
**Problem**: Timezone differences not clearly communicated

**Current State**:
- Times stored in dependent's timezone
- Displayed in local time for each user
- No indicator that times may differ

**Opportunity**:
- Timezone awareness in UI
- Relative time display ("in 30 minutes")
- Explicit timezone labels

**Design Proposal**:
```
Caregiver View (creating reminder):
- Time picker shows: "9:00 AM (Dependent's time)"
- Tooltip: "Reminder will go off at 9:00 AM in [Dependent's Timezone]"

Dependent View:
- Show only local time (no confusion needed)

Timeline View:
- "9:00 AM (30 minutes from now)"
- Count-down timer for imminent reminders
```

---

#### 6. Empty State Engagement
**Problem**: Empty states don't guide users to next action

**Current State**:
- Generic "No reminders" message
- Static illustration
- Action button at bottom

**Opportunity**:
- Contextual suggestions
- Progressive disclosure
- Gamification elements

**Design Proposal**:
```
Empty State Variants:

Caregiver (No Dependents):
- "Let's get started!"
- Step-by-step guide:
  1. ✓ Create account (done)
  2. → Share your code with your loved one
  3. → Add your first reminder
- "Copy My Code" button (primary)

Caregiver (Has Dependent, No Reminders):
- "Ready to set up reminders for [Name]?"
- Suggestion cards:
  - 💊 "Medication reminder"
  - 🍽️ "Meal reminder"
  - 📞 "Daily check-in call"
- Tap card → Pre-filled template

Dependent (No Reminders):
- "Your caregiver hasn't set up reminders yet."
- "Share your code: XXXXXX" (with copy button)
- "While you wait..."
  - "Test the SOS button" (demo mode)
  - "Explore settings"
```

---

#### 7. Progress Tracking Limited
**Problem**: No historical view of completion patterns

**Current State**:
- Only shows today's progress
- No weekly/monthly view
- No trends or insights

**Opportunity**:
- Calendar view with completion heatmap
- Streak tracking ("7-day streak!")
- Weekly summary reports

**Design Proposal**:
```
New Screen: "Activity History"
- Accessible from Dependent Dashboard
- Calendar heatmap:
  - Green: All completed
  - Yellow: Some missed
  - Red: Multiple missed
  - Gray: No reminders
- Stats cards:
  - "92% completion rate this month"
  - "5-day streak!"
  - "Most consistent: Morning reminders"
- Export option (PDF report for doctor visits)
```

---

#### 8. Dependent Autonomy
**Problem**: Dependents can't manage their own reminders

**Current State**:
- Caregivers create/edit all reminders
- Dependents are passive recipients
- No self-service options

**Opportunity**:
- Optional: Dependent self-management mode
- Suggest reminders to caregiver
- Adjust notification preferences

**Design Proposal**:
```
New Feature: "Reminder Suggestions" (Dependent)
- Button: "Suggest a Reminder to [Caregiver]"
- Simple form (title, time, repeat)
- Sent as request to caregiver
- Caregiver approves/edits/declines

Notification Preferences (Dependent):
- "Quiet Hours" (no notifications during sleep)
- Notification style (sound, vibration, both)
- Snooze duration preference (5, 10, 15 min)
```

---

#### 9. Multi-Caregiver Coordination
**Problem**: Multiple caregivers can't coordinate

**Current State**:
- One-to-one relationships only
- No shared visibility
- Duplicate reminders possible

**Opportunity**:
- Caregiver groups
- Shared calendar
- Role assignments (primary vs. backup)

**Design Proposal**:
```
New Feature: "Care Team"
- Primary caregiver invites others
- Roles:
  - Primary: Full access
  - Member: View + emergency contact
  - Guest: Emergency contact only
- Shared view:
  - All caregivers see same dashboard
  - Activity log: "Sarah added reminder", "John completed call"
  - Chat/notes section (optional)
```

---

#### 10. Offline Mode
**Problem**: App requires internet connection

**Current State**:
- All data fetched from API
- Offline = stale data only
- No offline actions

**Opportunity**:
- Local data sync
- Offline-first architecture
- Queue actions for when online

**Design Proposal**:
```
Offline Improvements:
1. Local SQLite database (already exists)
   → Cache all reminders + instances

2. Offline actions:
   → Mark reminder complete (queued)
   → Create reminder (draft)
   → Edit reminder (conflict resolution on sync)

3. Sync Strategy:
   → Pull latest data on app open
   → Push queued actions
   → Conflict resolution: Server wins, notify user

4. Offline Indicator:
   → Small banner: "Offline mode" (dismissible)
   → Badge on actions: "Will sync when online"
```

---

### Accessibility Gaps

#### 1. Voice Control
**Current**: Not supported  
**Opportunity**: "Hey Siri/Google, mark medication reminder as done"

#### 2. Dark Mode
**Current**: Light mode only (theme toggle exists but not fully tested)  
**Opportunity**: Complete dark mode implementation with AMOLED-friendly blacks

#### 3. Font Customization
**Current**: System font scaling only  
**Opportunity**: In-app font size picker (Small, Medium, Large, Extra Large)

#### 4. Colorblind Modes
**Current**: Status indicated by icon + text (good)  
**Opportunity**: Deuteranopia, Protanopia, Tritanopia color filters

---

### Technical Debt

#### 1. SignalR Reliability
**Issue**: Occasional connection drops, manual refresh needed  
**Solution**: Implement automatic reconnection with exponential backoff (partially done)

#### 2. Push Notification Handling
**Issue**: Notification tap doesn't always open correct screen  
**Solution**: Deep linking with proper navigation state restoration

#### 3. Image Caching
**Issue**: Avatar images reload on every screen  
**Solution**: Implement image caching layer (cached_network_image package)

#### 4. Error Handling
**Issue**: Generic error messages, no retry mechanisms  
**Solution**: Contextual error messages with automatic retry + manual retry button

---

### Performance Opportunities

#### 1. List Rendering
**Current**: Full list re-render on data change  
**Opportunity**: Differential updates, virtualized scrolling for large lists

#### 2. Animation Performance
**Current**: Some jank on low-end devices  
**Opportunity**: Reduce animation complexity, use `RepaintBoundary` widgets

#### 3. App Size
**Current**: ~45 MB (estimate)  
**Opportunity**: Asset optimization, code splitting, lazy loading

---

### Design System Inconsistencies

#### 1. Button Styles
**Issue**: 3 different button heights (56dp, 64dp, 72dp) used inconsistently  
**Solution**: Standardize to 64dp for primary, 56dp for secondary, 48dp for tertiary

#### 2. Card Padding
**Issue**: Varies between 12dp, 16dp, 24dp  
**Solution**: Define clear hierarchy: 16dp (dense), 20dp (default), 24dp (spacious)

#### 3. Icon Sizes
**Issue**: 20dp, 24dp, 28dp, 32dp used without clear pattern  
**Solution**: 
- Small (16dp): Inline, badges
- Medium (24dp): Standard buttons, cards
- Large (32dp): App bar, FAB
- XLarge (48dp+): Empty states, heroes

---

## Recommendations for Redesign

### Priority 1: High Impact, Quick Wins

1. **Simplified Linking Flow with QR Codes**
   - Effort: Medium
   - Impact: High (reduces friction by 50%)
   - Design: Add QR code generation + camera scanner

2. **Voice Note Onboarding**
   - Effort: Low
   - Impact: Medium-High (increases feature adoption)
   - Design: First-time tooltip + animated demo

3. **Offline Mode Basics**
   - Effort: Medium
   - Impact: High (improves reliability perception)
   - Design: Local cache + sync queue

4. **Improved Empty States**
   - Effort: Low
   - Impact: Medium (better user guidance)
   - Design: Contextual suggestions + action-oriented copy

### Priority 2: Strategic Enhancements

5. **Multi-Caregiver Support**
   - Effort: High
   - Impact: High (expands user base)
   - Design: Care team feature + role management

6. **Activity History & Insights**
   - Effort: Medium
   - Impact: Medium-High (adds value for compliance tracking)
   - Design: Calendar heatmap + trend charts

7. **Enhanced SOS Feedback**
   - Effort: Medium
   - Impact: High (critical for emergency use case)
   - Design: Delivery status + fallback mechanisms

8. **Escalation Visibility**
   - Effort: Low-Medium
   - Impact: Medium (improves caregiver awareness)
   - Design: Visual urgency indicators + notification history

### Priority 3: Long-term Improvements

9. **Voice Control Integration**
   - Effort: High
   - Impact: Medium (accessibility + convenience)
   - Design: Siri/Google Assistant shortcuts

10. **Advanced Personalization**
    - Effort: High
    - Impact: Medium-Low (nice-to-have)
    - Design: Custom themes, layouts, notification styles

---

## Appendix: Design Assets Needed

### Illustrations
- [ ] Welcome screen hero image
- [ ] Empty state illustrations (4 variants)
- [ ] Success/celebration animations
- [ ] Error state illustrations

### Icons
- [x] Category icons (Medicine, Meal, Exercise, Call, General)
- [x] Status icons (Pending, Completed, Missed, Snoozed)
- [x] SOS icon
- [ ] Onboarding tutorial icons
- [ ] Feature showcase icons

### Animations
- [ ] Lottie: Celebration (reminder completed)
- [ ] Lottie: SOS countdown
- [ ] Lottie: Loading states
- [ ] Lottie: Voice recording waveform

### Prototypes
- [ ] Interactive prototype: Linking flow (QR code)
- [ ] Interactive prototype: Voice note first-time experience
- [ ] Video walkthrough: Caregiver onboarding
- [ ] Video walkthrough: Dependent onboarding

---

## Document Metadata

**Author**: AI UX Analyst (based on codebase review)  
**Source**: ParentalCare Flutter App (MobileApp/)  
**Codebase Version**: Current as of February 13, 2026  
**Screens Analyzed**: 19  
**User Flows Documented**: 8  
**Last Review**: February 13, 2026

**Contact**: For questions about this documentation, refer to development team or product manager.

---

**End of Document**
