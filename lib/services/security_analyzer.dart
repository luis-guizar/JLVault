import '../models/account.dart';
import '../models/security_report.dart';
import '../models/security_issue.dart';
import '../models/security_metrics.dart';
import '../data/db_helper.dart';
import 'password_security_analyzer.dart';
import 'breach_checking_service.dart';
import 'security_scoring_service.dart';

class SecurityAnalyzer {
  /// Analyzes security for a specific vault and generates a comprehensive report
  static Future<SecurityReport> analyzeVault(String vaultId) async {
    var accounts = await DBHelper.getAllForVault(vaultId);

    if (accounts.isEmpty) {
      return SecurityReport(
        vaultId: vaultId,
        overallScore: 0.0, // 0% for empty vault
        issues: [],
        categoryScores: {
          SecurityCategory.passwordStrength: 0,
          SecurityCategory.passwordReuse: 0,
          SecurityCategory.breaches: 0,
          SecurityCategory.passwordAge: 0,
          SecurityCategory.twoFactor: 0,
        },
        recommendations: [],
        generatedAt: DateTime.now(),
        totalAccounts: 0,
        secureAccounts: 0,
      );
    }

    // Check for breaches (this may take some time) - only for premium users
    final breachResultsByPassword = <String, BreachCheckResult>{};
    try {
      final uniquePasswords = accounts
          .map((acc) => acc.password)
          .toSet()
          .toList();
      final breachResults = await BreachCheckingService.checkMultiplePasswords(
        uniquePasswords,
      );

      // Convert to map by password for easier lookup
      for (final password in uniquePasswords) {
        breachResultsByPassword[password] = breachResults[password]!;
      }
    } catch (e) {
      // If breach checking fails (e.g., no premium access), continue without breach data
      // The breach results map will remain empty, which is handled gracefully
    }

    // Calculate overall security score
    final overallScore =
        await SecurityScoringService.calculateVaultSecurityScore(
          accounts,
          breachResultsByPassword,
        );

    // Calculate category scores
    final categoryScores = await SecurityScoringService.calculateCategoryScores(
      accounts,
      breachResultsByPassword,
    );

    // Generate security issues
    final issues = await SecurityScoringService.generateSecurityIssues(
      vaultId,
      accounts,
      breachResultsByPassword,
    );

    // Generate recommendations
    final recommendations = SecurityScoringService.generateRecommendations(
      issues,
    );

    // Count secure accounts (score >= 80)
    int secureAccounts = 0;
    for (final account in accounts) {
      final accountScore =
          await SecurityScoringService.calculateAccountSecurityScore(
            account,
            accounts,
            breachResultsByPassword[account.password],
          );
      if (accountScore >= 80) {
        secureAccounts++;
      }
    }

    return SecurityReport(
      vaultId: vaultId,
      overallScore: overallScore,
      issues: issues,
      categoryScores: categoryScores,
      recommendations: recommendations,
      generatedAt: DateTime.now(),
      totalAccounts: accounts.length,
      secureAccounts: secureAccounts,
    );
  }

  /// Gets security issues for a specific vault
  static Future<List<SecurityIssue>> getIssues(String vaultId) async {
    final accounts = await DBHelper.getAllForVault(vaultId);

    if (accounts.isEmpty) return [];

    // Check for breaches for unique passwords only
    final uniquePasswords = accounts
        .map((acc) => acc.password)
        .toSet()
        .toList();
    final breachResults = await BreachCheckingService.checkMultiplePasswords(
      uniquePasswords,
    );

    final breachResultsByPassword = <String, BreachCheckResult>{};
    for (final password in uniquePasswords) {
      breachResultsByPassword[password] = breachResults[password]!;
    }

    return SecurityScoringService.generateSecurityIssues(
      vaultId,
      accounts,
      breachResultsByPassword,
    );
  }

  /// Calculates security score for a specific vault
  static Future<double> calculateSecurityScore(String vaultId) async {
    final accounts = await DBHelper.getAllForVault(vaultId);

    if (accounts.isEmpty) return 0.0; // Changed from 100.0 to 0.0

    // For quick score calculation, we'll skip breach checking
    // and use cached results if available
    final breachResultsByPassword = <String, BreachCheckResult>{};
    final uniquePasswords = accounts.map((acc) => acc.password).toSet();

    for (final password in uniquePasswords) {
      final cachedResult = BreachCheckingService.getCachedResult(password);
      if (cachedResult != null) {
        breachResultsByPassword[password] = cachedResult;
      }
    }

    return SecurityScoringService.calculateVaultSecurityScore(
      accounts,
      breachResultsByPassword.isEmpty ? null : breachResultsByPassword,
    );
  }

  /// Analyzes a single account's security
  static Future<SecurityMetrics> analyzeAccount(
    Account account,
    List<Account> allVaultAccounts,
  ) async {
    // Check if password is breached (use cached result if available)
    final cachedBreachResult = BreachCheckingService.getCachedResult(
      account.password,
    );
    bool isBreached = false;
    DateTime? lastBreachCheck;

    if (cachedBreachResult != null) {
      isBreached = cachedBreachResult.isBreached;
      lastBreachCheck = cachedBreachResult.checkedAt;
    } else {
      // Perform breach check
      final breachResult = await BreachCheckingService.checkPasswordBreach(
        account.password,
      );
      isBreached = breachResult.isBreached;
      lastBreachCheck = breachResult.checkedAt;
    }

    return PasswordSecurityAnalyzer.generateSecurityMetrics(
      account,
      allVaultAccounts,
      isBreached: isBreached,
      lastBreachCheck: lastBreachCheck,
    );
  }

  /// Gets quick security overview without detailed analysis
  static Future<Map<String, dynamic>> getSecurityOverview(
    String vaultId,
  ) async {
    final accounts = await DBHelper.getAllForVault(vaultId);

    if (accounts.isEmpty) {
      return {
        'totalAccounts': 0,
        'weakPasswords': 0,
        'reusedPasswords': 0,
        'accountsWithTwoFactor': 0,
        'estimatedScore': 0.0, // Changed from 100.0 to 0.0
      };
    }

    int weakPasswords = 0;
    int accountsWithTwoFactor = 0;

    for (final account in accounts) {
      final strength = PasswordSecurityAnalyzer.analyzePasswordStrength(
        account.password,
      );
      if (strength < 60) weakPasswords++;
      if (account.totpConfig != null) accountsWithTwoFactor++;
    }

    final passwordGroups = PasswordSecurityAnalyzer.detectPasswordReuse(
      accounts,
    );
    final reusedAccountIds = <int>{};
    for (final group in passwordGroups.values) {
      reusedAccountIds.addAll(group.map((acc) => acc.id!));
    }

    // Quick score estimation without breach checking
    double estimatedScore = 100.0;
    if (weakPasswords > 0) {
      estimatedScore -= (weakPasswords / accounts.length) * 40;
    }
    if (reusedAccountIds.isNotEmpty) {
      estimatedScore -= (reusedAccountIds.length / accounts.length) * 25;
    }

    return {
      'totalAccounts': accounts.length,
      'weakPasswords': weakPasswords,
      'reusedPasswords': reusedAccountIds.length,
      'accountsWithTwoFactor': accountsWithTwoFactor,
      'estimatedScore': estimatedScore.clamp(0.0, 100.0),
    };
  }

  /// Refreshes breach check data for all passwords in a vault
  static Future<void> refreshBreachData(String vaultId) async {
    final accounts = await DBHelper.getAllForVault(vaultId);
    final uniquePasswords = accounts
        .map((acc) => acc.password)
        .toSet()
        .toList();

    // This will update the cache with fresh breach data
    await BreachCheckingService.checkMultiplePasswords(uniquePasswords);
  }

  /// Clears all cached security data
  static void clearSecurityCache() {
    BreachCheckingService.clearCache();
  }
}
