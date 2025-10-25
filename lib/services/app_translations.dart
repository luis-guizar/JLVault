import 'language_service.dart';

class AppTranslations {
  static final AppTranslations _instance = AppTranslations._internal();
  static AppTranslations get instance => _instance;

  AppTranslations._internal();

  final Map<String, Map<AppLanguage, String>> _translations = {
    // App Title
    'appTitle': {
      AppLanguage.english: 'Simple Vault',
      AppLanguage.spanish: 'Simple Vault',
    },

    // Home Screen
    'homeTitle': {
      AppLanguage.english: 'Password Manager',
      AppLanguage.spanish: 'Administrador de Contraseñas',
    },
    'addAccount': {
      AppLanguage.english: 'Add Account',
      AppLanguage.spanish: 'Agregar Cuenta',
    },
    'editAccount': {
      AppLanguage.english: 'Edit Account',
      AppLanguage.spanish: 'Editar Cuenta',
    },
    'deleteAccount': {
      AppLanguage.english: 'Delete Account',
      AppLanguage.spanish: 'Eliminar Cuenta',
    },
    'search': {AppLanguage.english: 'Search', AppLanguage.spanish: 'Buscar'},
    'noAccountsFound': {
      AppLanguage.english: 'No accounts found',
      AppLanguage.spanish: 'No se encontraron cuentas',
    },

    // Form Fields
    'username': {
      AppLanguage.english: 'Username',
      AppLanguage.spanish: 'Usuario',
    },
    'password': {
      AppLanguage.english: 'Password',
      AppLanguage.spanish: 'Contraseña',
    },
    'website': {
      AppLanguage.english: 'Website',
      AppLanguage.spanish: 'Sitio Web',
    },
    'notes': {AppLanguage.english: 'Notes', AppLanguage.spanish: 'Notas'},

    // Buttons
    'save': {AppLanguage.english: 'Save', AppLanguage.spanish: 'Guardar'},
    'cancel': {AppLanguage.english: 'Cancel', AppLanguage.spanish: 'Cancelar'},
    'delete': {AppLanguage.english: 'Delete', AppLanguage.spanish: 'Eliminar'},
    'confirm': {
      AppLanguage.english: 'Confirm',
      AppLanguage.spanish: 'Confirmar',
    },
    'edit': {AppLanguage.english: 'Edit', AppLanguage.spanish: 'Editar'},
    'copy': {AppLanguage.english: 'Copy', AppLanguage.spanish: 'Copiar'},

    // TOTP Management
    'totpManagement': {
      AppLanguage.english: 'TOTP Management',
      AppLanguage.spanish: 'Gestión TOTP',
    },
    'generateCode': {
      AppLanguage.english: 'Generate Code',
      AppLanguage.spanish: 'Generar Código',
    },
    'copyCode': {
      AppLanguage.english: 'Copy Code',
      AppLanguage.spanish: 'Copiar Código',
    },

    // Security Dashboard
    'securityScore': {
      AppLanguage.english: 'Security Score',
      AppLanguage.spanish: 'Puntuación de Seguridad',
    },
    'weakPasswords': {
      AppLanguage.english: 'Weak Passwords',
      AppLanguage.spanish: 'Contraseñas Débiles',
    },
    'duplicatePasswords': {
      AppLanguage.english: 'Duplicate Passwords',
      AppLanguage.spanish: 'Contraseñas Duplicadas',
    },
    'oldPasswords': {
      AppLanguage.english: 'Old Passwords',
      AppLanguage.spanish: 'Contraseñas Antiguas',
    },
    'securityDashboard': {
      AppLanguage.english: 'Security Dashboard',
      AppLanguage.spanish: 'Panel de Seguridad',
    },

    // Premium Features
    'goPro': {AppLanguage.english: 'Go Pro', AppLanguage.spanish: 'Hazte Pro'},
    'premiumFeature': {
      AppLanguage.english: 'Premium Feature',
      AppLanguage.spanish: 'Función Premium',
    },
    'unlockPremium': {
      AppLanguage.english: 'Unlock Premium Features',
      AppLanguage.spanish: 'Desbloquear Funciones Premium',
    },
    'passwordLimit': {
      AppLanguage.english: 'Password Limit',
      AppLanguage.spanish: 'Límite de Contraseñas',
    },
    'unlimited': {
      AppLanguage.english: 'Unlimited',
      AppLanguage.spanish: 'Ilimitado',
    },

    // Vault Management
    'vaultManagement': {
      AppLanguage.english: 'Vault Management',
      AppLanguage.spanish: 'Gestión de Bóveda',
    },
    'createVault': {
      AppLanguage.english: 'Create Vault',
      AppLanguage.spanish: 'Crear Bóveda',
    },
    'switchVault': {
      AppLanguage.english: 'Switch Vault',
      AppLanguage.spanish: 'Cambiar Bóveda',
    },

    // Navigation
    'home': {AppLanguage.english: 'Home', AppLanguage.spanish: 'Inicio'},
    'security': {
      AppLanguage.english: 'Security',
      AppLanguage.spanish: 'Seguridad',
    },
    'settings': {
      AppLanguage.english: 'Settings',
      AppLanguage.spanish: 'Configuración',
    },

    // Development Mode
    'developmentMode': {
      AppLanguage.english: 'Development Mode',
      AppLanguage.spanish: 'Modo de Desarrollo',
    },

    // Language Settings
    'language': {
      AppLanguage.english: 'Language',
      AppLanguage.spanish: 'Idioma',
    },
    'changeLanguage': {
      AppLanguage.english: 'Change Language',
      AppLanguage.spanish: 'Cambiar Idioma',
    },
    'lockApp': {
      AppLanguage.english: 'Lock App',
      AppLanguage.spanish: 'Bloquear Aplicación',
    },
    'appDescription': {
      AppLanguage.english:
          'A secure offline password manager that stores your credentials locally with encryption.',
      AppLanguage.spanish:
          'Un gestor de contraseñas seguro y offline que almacena tus credenciales localmente con cifrado.',
    },
    'about': {AppLanguage.english: 'About', AppLanguage.spanish: 'Acerca de'},
    'timeSyncInfo': {
      AppLanguage.english: 'Time sync info',
      AppLanguage.spanish: 'Info de sincronización',
    },
    'addTotpToAccount': {
      AppLanguage.english: 'Add TOTP to account',
      AppLanguage.spanish: 'Agregar TOTP a cuenta',
    },

    // Error Messages
    'error': {AppLanguage.english: 'Error', AppLanguage.spanish: 'Error'},
    'success': {AppLanguage.english: 'Success', AppLanguage.spanish: 'Éxito'},
    'warning': {
      AppLanguage.english: 'Warning',
      AppLanguage.spanish: 'Advertencia',
    },
    'info': {
      AppLanguage.english: 'Information',
      AppLanguage.spanish: 'Información',
    },

    // Validation Messages
    'fieldRequired': {
      AppLanguage.english: 'This field is required',
      AppLanguage.spanish: 'Este campo es obligatorio',
    },
    'invalidEmail': {
      AppLanguage.english: 'Invalid email format',
      AppLanguage.spanish: 'Formato de email inválido',
    },
    'passwordTooShort': {
      AppLanguage.english: 'Password is too short',
      AppLanguage.spanish: 'La contraseña es muy corta',
    },

    // Dialog Messages
    'confirmDelete': {
      AppLanguage.english: 'Are you sure you want to delete this item?',
      AppLanguage.spanish:
          '¿Estás seguro de que quieres eliminar este elemento?',
    },
    'itemDeleted': {
      AppLanguage.english: 'Item deleted successfully',
      AppLanguage.spanish: 'Elemento eliminado exitosamente',
    },
    'itemSaved': {
      AppLanguage.english: 'Item saved successfully',
      AppLanguage.spanish: 'Elemento guardado exitosamente',
    },

    // Premium Feature Descriptions
    'unlimitedPasswords': {
      AppLanguage.english: 'Store unlimited passwords',
      AppLanguage.spanish: 'Almacena contraseñas ilimitadas',
    },
    'advancedSecurity': {
      AppLanguage.english: 'Advanced security features',
      AppLanguage.spanish: 'Funciones de seguridad avanzadas',
    },
    'prioritySupport': {
      AppLanguage.english: 'Priority customer support',
      AppLanguage.spanish: 'Soporte al cliente prioritario',
    },

    // Security Messages
    'securityAnalysis': {
      AppLanguage.english: 'Security Analysis',
      AppLanguage.spanish: 'Análisis de Seguridad',
    },
    'passwordStrength': {
      AppLanguage.english: 'Password Strength',
      AppLanguage.spanish: 'Fortaleza de Contraseña',
    },
    'strong': {AppLanguage.english: 'Strong', AppLanguage.spanish: 'Fuerte'},
    'medium': {AppLanguage.english: 'Medium', AppLanguage.spanish: 'Medio'},
    'weak': {AppLanguage.english: 'Weak', AppLanguage.spanish: 'Débil'},

    // Vault Management
    'manageVaults': {
      AppLanguage.english: 'Manage Vaults',
      AppLanguage.spanish: 'Gestionar Bóvedas',
    },
    'createNewVault': {
      AppLanguage.english: 'Create New Vault',
      AppLanguage.spanish: 'Crear Nueva Bóveda',
    },
    'deleteVault': {
      AppLanguage.english: 'Delete Vault',
      AppLanguage.spanish: 'Eliminar Bóveda',
    },
    'editVault': {
      AppLanguage.english: 'Edit Vault',
      AppLanguage.spanish: 'Editar Bóveda',
    },
    'vaultName': {
      AppLanguage.english: 'Vault Name',
      AppLanguage.spanish: 'Nombre de Bóveda',
    },
    'enterVaultName': {
      AppLanguage.english: 'Enter vault name',
      AppLanguage.spanish: 'Ingresa nombre de bóveda',
    },
    'pleaseEnterVaultName': {
      AppLanguage.english: 'Please enter a vault name',
      AppLanguage.spanish: 'Por favor ingresa un nombre de bóveda',
    },
    'vaultNameTooShort': {
      AppLanguage.english: 'Vault name must be at least 2 characters',
      AppLanguage.spanish: 'El nombre debe tener al menos 2 caracteres',
    },
    'noVaultsFound': {
      AppLanguage.english: 'No vaults found',
      AppLanguage.spanish: 'No se encontraron bóvedas',
    },
    'createFirstVault': {
      AppLanguage.english: 'Create your first vault to get started',
      AppLanguage.spanish: 'Crea tu primera bóveda para comenzar',
    },
    'errorLoadingVaults': {
      AppLanguage.english: 'Error loading vaults',
      AppLanguage.spanish: 'Error cargando bóvedas',
    },
    'retry': {AppLanguage.english: 'Retry', AppLanguage.spanish: 'Reintentar'},
    'update': {
      AppLanguage.english: 'Update',
      AppLanguage.spanish: 'Actualizar',
    },
    'create': {AppLanguage.english: 'Create', AppLanguage.spanish: 'Crear'},
    'icon': {AppLanguage.english: 'Icon', AppLanguage.spanish: 'Icono'},
    'color': {AppLanguage.english: 'Color', AppLanguage.spanish: 'Color'},
    'chooseIcon': {
      AppLanguage.english: 'Choose Icon',
      AppLanguage.spanish: 'Elegir Icono',
    },
    'chooseColor': {
      AppLanguage.english: 'Choose Color',
      AppLanguage.spanish: 'Elegir Color',
    },

    // TOTP Management
    'editTotp': {
      AppLanguage.english: 'Edit TOTP',
      AppLanguage.spanish: 'Editar TOTP',
    },
    'setupTotp': {
      AppLanguage.english: 'Setup TOTP',
      AppLanguage.spanish: 'Configurar TOTP',
    },
    'removeTotp': {
      AppLanguage.english: 'Remove TOTP',
      AppLanguage.spanish: 'Eliminar TOTP',
    },
    'addTotp': {
      AppLanguage.english: 'Add TOTP',
      AppLanguage.spanish: 'Agregar TOTP',
    },
    'selectAccount': {
      AppLanguage.english: 'Select Account',
      AppLanguage.spanish: 'Seleccionar Cuenta',
    },
    'timeSynchronization': {
      AppLanguage.english: 'Time Synchronization',
      AppLanguage.spanish: 'Sincronización de Tiempo',
    },
    'checkAgain': {
      AppLanguage.english: 'Check Again',
      AppLanguage.spanish: 'Verificar Nuevamente',
    },
    'ok': {AppLanguage.english: 'OK', AppLanguage.spanish: 'OK'},
    'synchronized': {
      AppLanguage.english: 'Synchronized',
      AppLanguage.spanish: 'Sincronizado',
    },
    'unknown': {
      AppLanguage.english: 'Unknown',
      AppLanguage.spanish: 'Desconocido',
    },
    'timeZoneIssue': {
      AppLanguage.english: 'Time Zone Issue',
      AppLanguage.spanish: 'Problema de Zona Horaria',
    },
    'incorrectTime': {
      AppLanguage.english: 'Incorrect Time',
      AppLanguage.spanish: 'Hora Incorrecta',
    },
    'syncIssue': {
      AppLanguage.english: 'Sync Issue',
      AppLanguage.spanish: 'Problema de Sincronización',
    },
    'networkUnavailable': {
      AppLanguage.english: 'Network Unavailable',
      AppLanguage.spanish: 'Red No Disponible',
    },
    'checkFailed': {
      AppLanguage.english: 'Check Failed',
      AppLanguage.spanish: 'Verificación Falló',
    },

    // General UI
    'maybelater': {
      AppLanguage.english: 'Maybe Later',
      AppLanguage.spanish: 'Tal Vez Después',
    },
    'restore': {
      AppLanguage.english: 'Restore',
      AppLanguage.spanish: 'Restaurar',
    },
    'upgradetoPremium': {
      AppLanguage.english: 'Upgrade to Premium',
      AppLanguage.spanish: 'Actualizar a Premium',
    },
    'authenticate': {
      AppLanguage.english: 'Authenticate',
      AppLanguage.spanish: 'Autenticar',
    },
    'authenticationSuccessful': {
      AppLanguage.english: 'Authentication successful',
      AppLanguage.spanish: 'Autenticación exitosa',
    },
    'copyCodeTooltip': {
      AppLanguage.english: 'Copy code',
      AppLanguage.spanish: 'Copiar código',
    },
    'expiringSoon': {
      AppLanguage.english: 'EXPIRING SOON',
      AppLanguage.spanish: 'EXPIRA PRONTO',
    },
    'timeSyncWarning': {
      AppLanguage.english: 'Time Sync Warning',
      AppLanguage.spanish: 'Advertencia de Sincronización',
    },
    'timeSynchronized': {
      AppLanguage.english: 'Time Synchronized',
      AppLanguage.spanish: 'Tiempo Sincronizado',
    },
    'learnMore': {
      AppLanguage.english: 'Learn more',
      AppLanguage.spanish: 'Saber más',
    },
    'justNow': {
      AppLanguage.english: 'Just now',
      AppLanguage.spanish: 'Ahora mismo',
    },
    'switchedToVault': {
      AppLanguage.english: 'Switched to vault',
      AppLanguage.spanish: 'Cambiado a bóveda',
    },
    'errorSwitchingVault': {
      AppLanguage.english: 'Error switching vault',
      AppLanguage.spanish: 'Error cambiando bóveda',
    },
    'authenticationFailed': {
      AppLanguage.english: 'Authentication failed',
      AppLanguage.spanish: 'Autenticación falló',
    },
    'errorDeletingVault': {
      AppLanguage.english: 'Error deleting vault',
      AppLanguage.spanish: 'Error eliminando bóveda',
    },
    'totpCodeCopied': {
      AppLanguage.english: 'TOTP code copied to clipboard',
      AppLanguage.spanish: 'Código TOTP copiado al portapapeles',
    },
  };

  String translate(String key, [AppLanguage? language]) {
    final lang = language ?? LanguageService.instance.currentLanguage;
    return _translations[key]?[lang] ?? key;
  }

  String operator [](String key) => translate(key);
}
