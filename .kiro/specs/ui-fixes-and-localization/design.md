# Design Document

## Overview

This design addresses critical UI and functionality issues in the Simple Vault Flutter application. The main problems identified are:

1. TOTP screen showing only "Go Pro" cards instead of functionality in debug mode
2. Premium feature gating not working correctly in debug mode
3. UI overflow issues in dropdown menus and keyboard interactions
4. Security score calculation always showing 100%
5. Incomplete Spanish localization with mixed English text

## Architecture

### Feature Gating System Architecture

The current feature gating system uses a factory pattern with different implementations:
- `DevelopmentFeatureGate`: Should unlock all features in debug mode
- `AndroidFeatureGate`: Handles Play Store integration for production
- `FeatureGateWrapper`: UI component that shows/hides premium content

**Issue**: The TOTP screen is wrapped in `FeatureGateWrapper` but still shows upgrade prompts in debug mode, indicating the development feature gate isn't working correctly.

### TOTP Screen Architecture

The TOTP functionality is split across:
- `TOTPManagementScreen`: Main TOTP interface
- `TOTPSetupScreen`: Configuration interface
- `FeatureGateWrapper`: Controls access to TOTP features

**Issue**: The entire TOTP screen body is wrapped in a `FeatureGateWrapper`, causing the whole screen to show upgrade prompts instead of functionality.

### Security Score System

Based on code analysis, the security score calculation appears to be handled by:
- `ComprehensiveSecurityService`: Main security assessment service
- `SecurityAuditService`: Performs security audits
- Various security monitoring services

**Issue**: The security score calculation logic may have hardcoded values or incorrect assessment algorithms.

## Components and Interfaces

### 1. Feature Gate System Fixes

**DevelopmentFeatureGate Enhancement**
- Ensure `canAccess()` method always returns `true` for all premium features in debug mode
- Add logging to verify the development gate is being used
- Fix any conditional logic that might bypass development mode

**FeatureGateWrapper Improvements**
- Add debug mode detection to bypass premium checks
- Implement proper fallback behavior for development builds
- Add visual indicators when development mode is active

### 2. TOTP Screen Restructuring

**TOTPManagementScreen Modifications**
- Remove the outer `FeatureGateWrapper` that wraps the entire body
- Apply feature gating only to specific premium TOTP features (if any)
- Ensure basic TOTP functionality is always available in debug mode

**Conditional Feature Gating**
- Implement granular feature gating for advanced TOTP features only
- Keep core TOTP generation and management unrestricted in debug mode

### 3. UI Layout Fixes

**Dropdown Overflow Resolution**
- Implement proper constraints and scrolling for dropdown menus
- Add responsive design patterns for different screen sizes
- Use `ConstrainedBox` and `SingleChildScrollView` where needed

**Keyboard Interaction Improvements**
- Implement `Scaffold.resizeToAvoidBottomInset` properly
- Add `SingleChildScrollView` with proper padding for keyboard avoidance
- Use `MediaQuery.of(context).viewInsets.bottom` for dynamic padding

### 4. Security Score Calculation

**Security Assessment Logic**
- Review and fix the `_calculateSecurityPosture` method in `ComprehensiveSecurityService`
- Implement proper password strength analysis
- Add checks for empty password databases
- Create realistic scoring algorithms based on actual security metrics

**Score Display Components**
- Create dedicated security score widgets
- Implement proper state management for score updates
- Add loading states and error handling

### 5. Spanish Localization System

**Localization Architecture**
- Implement Flutter's `Intl` package for proper localization
- Create `AppLocalizations` class with Spanish translations
- Set up `MaterialApp.localizationsDelegates` and `supportedLocales`

**Translation Management**
- Create `lib/l10n/app_es.arb` file with Spanish translations
- Generate type-safe localization classes
- Replace all hardcoded English strings with localized versions

## Data Models

### LocalizationKeys Model
```dart
class LocalizationKeys {
  static const String appTitle = 'app_title';
  static const String addAccount = 'add_account';
  static const String deleteAccount = 'delete_account';
  // ... all UI strings
}
```

### SecurityScoreModel Enhancement
```dart
class SecurityScore {
  final double score;
  final List<SecurityFactor> factors;
  final DateTime calculatedAt;
  final bool hasPasswords;
}
```

### DebugModeConfig
```dart
class DebugModeConfig {
  final bool unlockAllFeatures;
  final bool showDebugIndicators;
  final bool bypassPremiumChecks;
}
```

## Error Handling

### Feature Gate Error Handling
- Add fallback behavior when feature gate initialization fails
- Implement graceful degradation for premium feature access
- Add logging for feature gate decision tracking

### UI Overflow Error Prevention
- Implement proper constraint handling in all scrollable areas
- Add overflow detection and automatic scrolling
- Create responsive breakpoints for different screen sizes

### Security Score Error Handling
- Handle cases where no passwords exist
- Implement fallback scoring when calculation fails
- Add proper error states in security score UI

## Testing Strategy

### Feature Gate Testing
- Unit tests for `DevelopmentFeatureGate` to ensure all features return `true`
- Integration tests for feature gate factory selection
- UI tests to verify premium content is accessible in debug mode

### TOTP Screen Testing
- Widget tests for TOTP screen rendering in debug mode
- Integration tests for TOTP functionality without premium restrictions
- End-to-end tests for TOTP setup and code generation

### UI Layout Testing
- Widget tests for dropdown menu rendering with various content sizes
- Keyboard interaction tests for form screens
- Responsive design tests across different screen sizes

### Security Score Testing
- Unit tests for security score calculation with various password scenarios
- Tests for empty password database handling
- Integration tests for real-time score updates

### Localization Testing
- Tests to verify all UI strings are properly localized
- Tests for Spanish text rendering and layout
- Tests for date/time formatting in Spanish locale

## Implementation Approach

### Phase 1: Feature Gate Fixes
1. Fix `DevelopmentFeatureGate` implementation
2. Update `FeatureGateWrapper` to respect debug mode
3. Remove inappropriate feature gates from TOTP screens

### Phase 2: UI Layout Fixes
1. Fix dropdown overflow issues in app bar
2. Implement proper keyboard avoidance in forms
3. Add responsive design improvements

### Phase 3: Security Score Implementation
1. Review and fix security score calculation logic
2. Implement proper empty state handling
3. Add real-time score updates

### Phase 4: Spanish Localization
1. Set up Flutter localization infrastructure
2. Create comprehensive Spanish translation files
3. Replace all hardcoded strings with localized versions
4. Test and refine translations for Latin American Spanish

### Phase 5: Testing and Validation
1. Comprehensive testing of all fixes
2. User acceptance testing for Spanish localization
3. Performance testing for UI improvements
4. Security validation for score calculations