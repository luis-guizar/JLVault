# Simple Vault - Offline Password Manager Documentation

## Overview

Simple Vault (JL Vault) is a secure, offline password manager built with Flutter. It provides local storage of encrypted passwords with biometric authentication, ensuring complete privacy without any cloud dependencies.

## Key Features

- **Offline-First**: No internet permissions, all data stored locally
- **AES Encryption**: Passwords encrypted using AES-256 with secure key storage
- **Biometric Authentication**: Fingerprint unlock using device's existing security
- **Cross-Platform**: Built with Flutter for Android/iOS support
- **Material Design**: Clean, intuitive UI following Material Design principles
- **Search Functionality**: Quick search through stored accounts
- **Basic Password Generation**: Simple 16-character password generator

## Architecture

### Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/
│   └── account.dart            # Account data model
├── data/
│   └── db_helper.dart          # SQLite database operations
├── services/
│   ├── encryption_service.dart # AES encryption/decryption
│   └── auth_service.dart       # Biometric authentication
├── screens/
│   ├── lock_screen.dart        # Authentication screen
│   ├── home_screen.dart        # Main account list
│   └── add_edit_screen.dart    # Add/edit account form
└── widgets/
    └── account_title.dart      # Account list item widget
```

### Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Framework** | Flutter | Cross-platform mobile development |
| **Database** | SQLite (sqflite) | Local data persistence |
| **Encryption** | AES-256 (encrypt package) | Password encryption |
| **Key Storage** | Flutter Secure Storage | Secure key management |
| **Authentication** | Local Auth | Device biometric authentication |
| **UI** | Material Design | User interface components |

## Core Components

### 1. Data Model (`Account`)

```dart
class Account {
  final int? id;
  final String name;        // Service name (e.g., "Google")
  final String username;    // Username/email
  final String password;    // Encrypted password
}
```

### 2. Database Layer (`DBHelper`)

- **Database**: SQLite with single `accounts` table
- **Operations**: CRUD operations for account management
- **Schema**: Simple 4-column structure (id, name, username, password)

### 3. Security Services

#### Encryption Service
- **Algorithm**: AES-256 encryption
- **Key Management**: Secure key generation and storage
- **IV Handling**: Random IV for each encryption operation
- **Backward Compatibility**: Supports old format without IV

#### Authentication Service
- **Biometric Support**: Fingerprint, face recognition
- **Fallback**: Uses device's existing PIN/pattern (no app-specific PIN creation)
- **Platform Integration**: Uses device's native authentication system

### 4. User Interface

#### Lock Screen
- **Purpose**: Initial authentication barrier
- **Features**: Biometric prompt, error handling, gradient background
- **Localization**: Spanish interface ("JL Vault", "Desbloquear")

#### Home Screen
- **Features**: Account list, search, pull-to-refresh
- **Actions**: Add, edit, delete accounts
- **Empty State**: Helpful messaging for new users

#### Add/Edit Screen
- **Form Validation**: Required field validation
- **Password Tools**: Show/hide toggle, basic password generator (16 chars)
- **Encryption**: Automatic password encryption on save
- **Password Generator**: Simple timestamp-based generation (not cryptographically secure)

#### Account Tile Widget
- **Display**: Account name and username
- **Actions**: Copy password, edit, delete
- **Security**: Password decryption on copy

## Security Implementation

### Encryption Flow

1. **Key Generation**: 256-bit AES key generated on first use
2. **Key Storage**: Stored securely using Flutter Secure Storage
3. **Encryption**: Each password encrypted with random IV
4. **Storage Format**: `IV:EncryptedData` (base64 encoded)

### Authentication Flow

1. **Device Check**: Verify biometric capability
2. **Authentication**: Prompt for biometric or device PIN/pattern
3. **Success**: Navigate to main app
4. **Failure**: Show error and retry option

### Data Protection

- **Local Only**: No network permissions in manifest
- **Encrypted Storage**: All passwords encrypted at rest
- **Secure Key Management**: Keys stored in Android Keystore/iOS Keychain
- **Memory Safety**: Sensitive data cleared after use

## Dependencies

### Core Dependencies
```yaml
dependencies:
  flutter: sdk
  sqflite: ^2.4.2              # SQLite database
  path_provider: ^2.1.5        # File system paths
  flutter_secure_storage: ^9.2.4 # Secure key storage
  local_auth: ^3.0.0           # Biometric authentication
  encrypt: ^5.0.3              # AES encryption
  path: ^1.9.1                 # Path manipulation
```

### Development Dependencies
```yaml
dev_dependencies:
  flutter_test: sdk
  flutter_lints: ^5.0.0        # Dart linting rules
  flutter_launcher_icons: ^0.13.1 # App icon generation
```

## Setup and Installation

### Prerequisites
- Flutter SDK (3.9.2+)
- Android Studio / VS Code
- Android device/emulator with biometric support

### Installation Steps

1. **Clone Repository**
   ```bash
   git clone <repository-url>
   cd simple_vault
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Setup App Icon** (Optional)
   - Place 1024x1024 PNG icon in `assets/icon.png`
   - Run: `flutter pub run flutter_launcher_icons`

4. **Run Application**
   ```bash
   flutter run
   ```

## Usage Guide

### First Time Setup
1. Launch app and complete biometric setup
2. Tap "+" to add your first account
3. Fill in account details and save

### Adding Accounts
1. Tap floating action button (+)
2. Enter account name, username, and password
3. Optionally use basic password generator (refresh icon)
4. Save to encrypt and store

### Managing Accounts
- **Search**: Use search bar to find accounts quickly
- **Copy Password**: Tap copy icon to copy decrypted password
- **Edit**: Tap edit icon to modify account details
- **Delete**: Tap delete icon with confirmation dialog

### Security Features
- **Auto-lock**: App locks when backgrounded
- **Biometric Unlock**: Use fingerprint/face to access
- **Encrypted Storage**: All passwords encrypted locally

## Configuration

### App Branding
- **App Name**: "Simple Vault" (display name)
- **Package**: `simple_vault`
- **Theme**: Dark theme with blue accent
- **Localization**: Spanish interface elements

### Security Settings
- **Encryption**: AES-256 with random IV
- **Key Storage**: Platform secure storage
- **Authentication**: Biometric + device credentials

## Known Issues and Limitations

### Current Issues
1. **Print Statements**: Development print statements should be replaced with proper logging
2. **BuildContext Usage**: Async context usage in AccountTile needs mounted check
3. **Error Handling**: Some error cases could have better user messaging

### Limitations
- **Platform Support**: Primarily designed for Android
- **Backup**: No backup/restore functionality
- **Sync**: No cloud synchronization
- **Categories**: No account categorization
- **Notes**: No secure notes feature

## Development Notes

### Code Quality
- **Linting**: Uses flutter_lints for code quality
- **Architecture**: Clean separation of concerns
- **Error Handling**: Basic error handling implemented
- **Documentation**: Inline comments for complex logic

### Testing
- **Unit Tests**: Basic test structure in place
- **Integration Tests**: Manual testing recommended
- **Security Testing**: Encryption/decryption validation needed

### Future Enhancements
- **Backup/Restore**: Export/import functionality
- **Categories**: Account organization
- **Secure Notes**: Additional secure storage
- **Password Health**: Weak/duplicate password detection
- **Auto-fill**: Android autofill service integration
- **Secure Password Generation**: Replace timestamp-based generator with cryptographically secure random
- **App-Specific PIN**: Optional app-level PIN creation (independent of device security)

## Troubleshooting

### Common Issues

1. **Biometric Not Working**
   - Ensure device has biometric setup
   - Check app permissions
   - Uses device's existing PIN/pattern (no app PIN setup)

2. **Database Errors**
   - Clear app data and restart
   - Check file permissions
   - Verify SQLite installation

3. **Encryption Errors**
   - Clear secure storage
   - Regenerate encryption keys
   - Check device security settings

### Debug Mode
- Enable debug mode for detailed error logging
- Use Flutter Inspector for UI debugging
- Check device logs for native errors

## Contributing

### Development Setup
1. Fork repository
2. Create feature branch
3. Follow Flutter/Dart style guidelines
4. Add tests for new features
5. Submit pull request

### Code Standards
- Follow Dart style guide
- Use meaningful variable names
- Add documentation for public APIs
- Handle errors gracefully
- Write unit tests for business logic

---

*This documentation covers the current state of Simple Vault v1.0.0. For updates and additional information, refer to the project repository.*