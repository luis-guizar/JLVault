import 'package:flutter/material.dart';
import '../services/language_service.dart';

import 'translated_text.dart';

class LanguageSwitcher extends StatelessWidget {
  final bool showLabel;
  final bool isCompact;

  const LanguageSwitcher({
    super.key,
    this.showLabel = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService.instance,
      builder: (context, child) {
        if (isCompact) {
          return IconButton(
            onPressed: () => LanguageService.instance.toggleLanguage(),
            icon: const Icon(Icons.language),
            tooltip: 'changeLanguage'.tr,
          );
        }

        return ListTile(
          leading: const Icon(Icons.language),
          title: showLabel ? const TranslatedText('language') : null,
          subtitle: Text(LanguageService.instance.languageName),
          trailing: Switch(
            value: LanguageService.instance.isEnglish,
            onChanged: (value) {
              LanguageService.instance.setLanguage(
                value ? AppLanguage.english : AppLanguage.spanish,
              );
            },
          ),
          onTap: () => LanguageService.instance.toggleLanguage(),
        );
      },
    );
  }
}

class LanguageDropdown extends StatelessWidget {
  const LanguageDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService.instance,
      builder: (context, child) {
        return DropdownButton<AppLanguage>(
          value: LanguageService.instance.currentLanguage,
          onChanged: (AppLanguage? newLanguage) {
            if (newLanguage != null) {
              LanguageService.instance.setLanguage(newLanguage);
            }
          },
          items: AppLanguage.values.map((AppLanguage language) {
            return DropdownMenuItem<AppLanguage>(
              value: language,
              child: Text(_getLanguageName(language)),
            );
          }).toList(),
        );
      },
    );
  }

  String _getLanguageName(AppLanguage language) {
    switch (language) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.spanish:
        return 'Español';
    }
  }
}
