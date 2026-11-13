import 'package:flutter/material.dart';
import '../i18n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/i18n_service.dart';

/// Reusable widget for user-generated content (posts, chat messages, emails, bios)
/// Provides:
/// - Clean display of original content
/// - Optional "Translate" action button
/// - Inline translated content display with clear "Translated to [Language]" badge
/// - "Show original" toggle
/// - Never overwrites original text
class TranslatableTextWidget extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool showTranslateButton;

  const TranslatableTextWidget({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
    this.showTranslateButton = true,
  });

  @override
  State<TranslatableTextWidget> createState() => _TranslatableTextWidgetState();
}

class _TranslatableTextWidgetState extends State<TranslatableTextWidget> {
  bool _isTranslating = false;
  bool _isTranslated = false;
  String? _translatedText;
  String? _sourceLang;

  Future<void> _handleTranslate() async {
    if (_isTranslated) {
      // Toggle back to original
      setState(() => _isTranslated = false);
      return;
    }

    if (_translatedText != null) {
      // Already translated before, just show it
      setState(() => _isTranslated = true);
      return;
    }

    setState(() => _isTranslating = true);

    final targetLang = I18nService.currentLanguageCode;
    final res = await ApiService.translateText(
      text: widget.text,
      targetLang: targetLang,
    );

    if (mounted) {
      setState(() {
        _isTranslating = false;
        if (res != null && res['translatedText'] != null) {
          _translatedText = res['translatedText'] as String;
          _sourceLang = res['sourceLang'] as String?;
          _isTranslated = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayText = _isTranslated && _translatedText != null ? _translatedText! : widget.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Display Text
        Text(
          displayText,
          style: widget.style,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
        ),

        // Optional translation toggle pill
        if (widget.showTranslateButton && widget.text.trim().length > 3) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isTranslating)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              else
                InkWell(
                  onTap: _handleTranslate,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.g_translate_rounded,
                          size: 13,
                          color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isTranslated
                              ? context.tr('common.show_original')
                              : context.tr('common.translate'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_isTranslated) ...[
                const SizedBox(width: 8),
                Text(
                  '•  ${context.tr('common.translated_from', {'lang': _sourceLang ?? I18nService.currentLanguage.nativeName})}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
