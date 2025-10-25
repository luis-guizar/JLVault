# Requirements Document

## Introduction

This feature addresses critical UI issues and localization problems in the Simple Vault Flutter application. The app currently has several broken screens, layout overflow issues, incorrect premium feature gating in debug mode, and incomplete Spanish localization. These issues significantly impact user experience and development workflow.

## Requirements

### Requirement 1

**User Story:** As a developer, I want the TOTP screen to display properly in debug mode, so that I can test TOTP functionality without premium restrictions.

#### Acceptance Criteria

1. WHEN accessing the TOTP screen in debug mode THEN the system SHALL display TOTP generation and management features
2. WHEN in debug mode THEN the system SHALL NOT show "Go Pro" cards on the TOTP screen
3. WHEN TOTP features are accessed THEN the system SHALL provide full functionality without premium restrictions in debug mode

### Requirement 2

**User Story:** As a developer, I want premium feature gating to work correctly in debug mode, so that I can test all features without restrictions during development.

#### Acceptance Criteria

1. WHEN the app runs in debug mode THEN the system SHALL unlock all premium features automatically
2. WHEN in debug mode THEN the system SHALL NOT display "Go Pro" cards on any screen
3. WHEN checking feature availability in debug mode THEN the system SHALL return true for all premium features
4. WHEN displaying password limits in debug mode THEN the system SHALL show unlimited capacity instead of "1/50"

### Requirement 3

**User Story:** As a user, I want the dropdown menu in the home app bar to display without pixel overflow, so that I can access all menu options properly.

#### Acceptance Criteria

1. WHEN opening the dropdown menu in the home app bar THEN the system SHALL display all options without pixel overflow
2. WHEN the dropdown is rendered THEN the system SHALL calculate proper dimensions to fit within screen bounds
3. WHEN dropdown content exceeds available space THEN the system SHALL implement proper scrolling or responsive layout

### Requirement 4

**User Story:** As a user, I want to create and edit vaults without layout overflow when the keyboard appears, so that I can input data comfortably.

#### Acceptance Criteria

1. WHEN the keyboard appears during vault creation THEN the system SHALL adjust the layout to prevent overflow
2. WHEN the keyboard appears during vault editing THEN the system SHALL maintain proper scrolling and input visibility
3. WHEN input fields are focused THEN the system SHALL ensure the active field remains visible above the keyboard
4. WHEN the keyboard dismisses THEN the system SHALL restore the original layout properly

### Requirement 5

**User Story:** As a user, I want the security score to accurately reflect my password strength, so that I can understand my actual security posture.

#### Acceptance Criteria

1. WHEN there are no passwords stored THEN the system SHALL display a security score of 0% or "No data"
2. WHEN passwords are weak THEN the system SHALL calculate and display a low security score
3. WHEN passwords are strong THEN the system SHALL calculate and display a high security score
4. WHEN password strength changes THEN the system SHALL update the security score accordingly
5. WHEN calculating security score THEN the system SHALL consider password complexity, uniqueness, and age

### Requirement 6

**User Story:** As a Spanish-speaking user, I want all UI elements to be displayed in Latin American Spanish, so that I can use the app in my preferred language.

#### Acceptance Criteria

1. WHEN the app loads THEN the system SHALL display all text elements in Latin American Spanish
2. WHEN navigating between screens THEN the system SHALL maintain consistent Spanish localization
3. WHEN error messages appear THEN the system SHALL display them in Spanish
4. WHEN premium features are mentioned THEN the system SHALL use appropriate Spanish terminology
5. WHEN dates and numbers are formatted THEN the system SHALL use Latin American Spanish conventions