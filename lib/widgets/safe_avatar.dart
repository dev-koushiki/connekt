import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';

/// Validate if string is a non-empty, well-formed HTTP/HTTPS URL with host
bool isValidHttpUrl(String? url) {
  if (url == null) return false;
  final clean = url.trim();
  if (clean.isEmpty) return false;
  if (!clean.startsWith('http://') && !clean.startsWith('https://')) return false;
  try {
    final uri = Uri.tryParse(clean);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    final host = uri.host;
    if (host.isEmpty) return false;
    return host.contains('.') || host == 'localhost';
  } catch (_) {
    return false;
  }
}

/// Resolve an absolute HTTP(S) or backend-relative avatar path into a safe URL.
String? resolveAvatarUrl(String? url) {
  final resolved = ApiConfig.resolveMediaUrl(url);
  if (resolved == null) return null;
  return isValidHttpUrl(resolved) ? resolved : null;
}

/// A bulletproof Avatar widget that handles empty, malformed, or offline image URLs safely
class SafeAvatar extends StatelessWidget {
  final String? url;
  final String fallbackText;
  final double size;
  final double radius;
  final IconData? fallbackIcon;

  const SafeAvatar({
    super.key,
    required this.url,
    this.fallbackText = '',
    this.size = 36,
    this.radius = 18,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final resolvedUrl = resolveAvatarUrl(url);
      if (resolvedUrl != null) {
        return SizedBox(
          width: size,
          height: size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.network(
              resolvedUrl,
              headers: ApiConfig.mediaHeaders,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallback(context),
            ),
          ),
        );
      }
    } catch (_) {
      // Fall through to fallback
    }
    return _buildFallback(context);
  }

  Widget _buildFallback(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initial = fallbackText.trim().isNotEmpty
        ? fallbackText.trim()[0].toUpperCase()
        : '';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: fallbackIcon != null
          ? Icon(
              fallbackIcon,
              size: size * 0.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            )
          : Text(
              initial.isNotEmpty ? initial : '?',
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.brandBlue,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.42,
              ),
            ),
    );
  }
}
