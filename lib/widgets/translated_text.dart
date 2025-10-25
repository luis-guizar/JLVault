import 'package:flutter/material.dart';
import '../services/app_translations.dart';
import '../services/language_service.dart';

class TranslatedText extends StatelessWidget {
  final String translationKey;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const TranslatedText(
    this.translationKey, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService.instance,
      builder: (context, child) {
        return Text(
          AppTranslations.instance[translationKey],
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
}

// Extension to make it easier to get translations
extension TranslationExtension on String {
  String get tr => AppTranslations.instance[this];
}
