import 'package:flutter/foundation.dart';
import '../models/account.dart';
import 'search_service.dart';

/// Advanced search optimization with filtering, sorting, and ranking
class SearchOptimizationService {
  static SearchOptimizationService? _instance;
  static SearchOptimizationService get instance =>
      _instance ??= SearchOptimizationService._();

  SearchOptimizationService._();

  /// Search with advanced filtering and sorting options
  Future<List<Account>> advancedSearch({
    required String query,
    String? vaultId,
    List<SearchFilter>? filters,
    SearchSortOption sortBy = SearchSortOption.relevance,
    bool ascending = true,
    int limit = 50,
  }) async {
    // Get base search results
    List<Account> results = await SearchService.instance.search(
      query,
      vaultId: vaultId,
      limit: limit * 2, // Get more results for better filtering
    );

    // Apply additional filters
    if (filters != null && filters.isNotEmpty) {
      results = _applyFilters(results, filters);
    }

    // Calculate relevance scores
    results = _calculateRelevanceScores(results, query);

    // Sort results
    results = _sortResults(results, sortBy, ascending);

    // Apply final limit
    if (results.length > limit) {
      results = results.take(limit).toList();
    }

    return results;
  }

  /// Apply search filters to results
  List<Account> _applyFilters(
    List<Account> accounts,
    List<SearchFilter> filters,
  ) {
    List<Account> filtered = accounts;

    for (final filter in filters) {
      switch (filter.type) {
        case SearchFilterType.hasUsername:
          filtered = filtered
              .where((account) => account.username?.isNotEmpty == true)
              .toList();
          break;

        case SearchFilterType.hasUrl:
          filtered = filtered
              .where((account) => account.url?.isNotEmpty == true)
              .toList();
          break;

        case SearchFilterType.hasNotes:
          filtered = filtered
              .where((account) => account.notes?.isNotEmpty == true)
              .toList();
          break;

        case SearchFilterType.hasTOTP:
          filtered = filtered
              .where((account) => account.totpConfig != null)
              .toList();
          break;

        case SearchFilterType.createdAfter:
          if (filter.dateValue != null) {
            filtered = filtered
                .where(
                  (account) =>
                      account.createdAt?.isAfter(filter.dateValue!) == true,
                )
                .toList();
          }
          break;

        case SearchFilterType.createdBefore:
          if (filter.dateValue != null) {
            filtered = filtered
                .where(
                  (account) =>
                      account.createdAt?.isBefore(filter.dateValue!) == true,
                )
                .toList();
          }
          break;

        case SearchFilterType.modifiedAfter:
          if (filter.dateValue != null) {
            filtered = filtered
                .where(
                  (account) =>
                      account.modifiedAt?.isAfter(filter.dateValue!) == true,
                )
                .toList();
          }
          break;

        case SearchFilterType.nameContains:
          if (filter.stringValue != null) {
            filtered = filtered
                .where(
                  (account) => account.name.toLowerCase().contains(
                    filter.stringValue!.toLowerCase(),
                  ),
                )
                .toList();
          }
          break;

        case SearchFilterType.usernameContains:
          if (filter.stringValue != null) {
            filtered = filtered
                .where(
                  (account) =>
                      account.username?.toLowerCase().contains(
                        filter.stringValue!.toLowerCase(),
                      ) ==
                      true,
                )
                .toList();
          }
          break;
      }
    }

    return filtered;
  }

  /// Calculate relevance scores for search results
  List<Account> _calculateRelevanceScores(
    List<Account> accounts,
    String query,
  ) {
    final queryLower = query.toLowerCase();
    final queryTerms = queryLower.split(RegExp(r'\s+'));

    for (final account in accounts) {
      double score = 0.0;

      final nameLower = account.name.toLowerCase();
      final usernameLower = account.username?.toLowerCase() ?? '';
      final urlLower = account.url?.toLowerCase() ?? '';

      // Exact matches get highest score
      if (nameLower == queryLower) score += 100;
      if (usernameLower == queryLower) score += 80;

      // Starts with matches get high score
      if (nameLower.startsWith(queryLower)) score += 50;
      if (usernameLower.startsWith(queryLower)) score += 40;

      // Contains matches get medium score
      if (nameLower.contains(queryLower)) score += 30;
      if (usernameLower.contains(queryLower)) score += 25;
      if (urlLower.contains(queryLower)) score += 20;

      // Individual term matches
      for (final term in queryTerms) {
        if (term.length < 2) continue;

        if (nameLower.contains(term)) score += 10;
        if (usernameLower.contains(term)) score += 8;
        if (urlLower.contains(term)) score += 5;
      }

      // Boost score for recently accessed accounts
      if (account.lastUsedAt != null) {
        final daysSinceUsed = DateTime.now()
            .difference(account.lastUsedAt!)
            .inDays;
        if (daysSinceUsed < 7)
          score += 15;
        else if (daysSinceUsed < 30)
          score += 10;
        else if (daysSinceUsed < 90)
          score += 5;
      }

      // Boost score for recently created accounts
      if (account.createdAt != null) {
        final daysSinceCreated = DateTime.now()
            .difference(account.createdAt!)
            .inDays;
        if (daysSinceCreated < 7) score += 5;
      }

      account.relevanceScore = score;
    }

    return accounts;
  }

  /// Sort search results based on specified criteria
  List<Account> _sortResults(
    List<Account> accounts,
    SearchSortOption sortBy,
    bool ascending,
  ) {
    accounts.sort((a, b) {
      int comparison = 0;

      switch (sortBy) {
        case SearchSortOption.relevance:
          comparison = (b.relevanceScore ?? 0).compareTo(a.relevanceScore ?? 0);
          break;

        case SearchSortOption.name:
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;

        case SearchSortOption.username:
          final aUsername = a.username?.toLowerCase() ?? '';
          final bUsername = b.username?.toLowerCase() ?? '';
          comparison = aUsername.compareTo(bUsername);
          break;

        case SearchSortOption.createdDate:
          final aCreated = a.createdAt ?? DateTime(1970);
          final bCreated = b.createdAt ?? DateTime(1970);
          comparison = aCreated.compareTo(bCreated);
          break;

        case SearchSortOption.modifiedDate:
          final aModified = a.modifiedAt ?? DateTime(1970);
          final bModified = b.modifiedAt ?? DateTime(1970);
          comparison = aModified.compareTo(bModified);
          break;

        case SearchSortOption.lastUsed:
          final aUsed = a.lastUsedAt ?? DateTime(1970);
          final bUsed = b.lastUsedAt ?? DateTime(1970);
          comparison = aUsed.compareTo(bUsed);
          break;
      }

      return ascending ? comparison : -comparison;
    });

    return accounts;
  }

  /// Get search suggestions based on query
  Future<List<String>> getSearchSuggestions(
    String query, {
    int limit = 10,
  }) async {
    if (query.length < 2) return [];

    try {
      // Get recent search results to generate suggestions
      final results = await SearchService.instance.search(query, limit: 20);

      final suggestions = <String>{};

      for (final account in results) {
        // Add account name if it contains the query
        if (account.name.toLowerCase().contains(query.toLowerCase())) {
          suggestions.add(account.name);
        }

        // Add username if it contains the query
        if (account.username != null &&
            account.username!.toLowerCase().contains(query.toLowerCase())) {
          suggestions.add(account.username!);
        }

        // Add domain from URL if it contains the query
        if (account.url != null) {
          final domain = _extractDomain(account.url!);
          if (domain.toLowerCase().contains(query.toLowerCase())) {
            suggestions.add(domain);
          }
        }
      }

      return suggestions.take(limit).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting search suggestions: $e');
      }
      return [];
    }
  }

  /// Extract domain from URL
  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
      return uri.host;
    } catch (e) {
      return url;
    }
  }

  /// Get search analytics
  Map<String, dynamic> getSearchAnalytics() {
    return {
      'searchCacheStats': SearchService.instance.getStats(),
      'optimizationEnabled': true,
      'supportedFilters': SearchFilterType.values.map((e) => e.name).toList(),
      'supportedSortOptions': SearchSortOption.values
          .map((e) => e.name)
          .toList(),
    };
  }
}

/// Search filter for advanced search
class SearchFilter {
  final SearchFilterType type;
  final String? stringValue;
  final DateTime? dateValue;
  final bool? boolValue;

  const SearchFilter({
    required this.type,
    this.stringValue,
    this.dateValue,
    this.boolValue,
  });
}

/// Available search filter types
enum SearchFilterType {
  hasUsername,
  hasUrl,
  hasNotes,
  hasTOTP,
  createdAfter,
  createdBefore,
  modifiedAfter,
  nameContains,
  usernameContains,
}

/// Search sort options
enum SearchSortOption {
  relevance,
  name,
  username,
  createdDate,
  modifiedDate,
  lastUsed,
}
