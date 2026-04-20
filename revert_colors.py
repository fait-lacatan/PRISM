import re

with open('lib/features/dashboard/dashboard_screen.dart', 'r') as f:
    text = f.read()

# Revert CardShell gradient back to original
text = re.sub(
    r'gradient: LinearGradient\(\s*begin: Alignment\.topLeft,\s*end: Alignment\.bottomRight,\s*colors: \[\s*accentColor\.withValues\(alpha: 0\.6\),\s*accentColor\.withValues\(alpha: 0\.2\),\s*\],\s*\),\s*borderRadius: BorderRadius\.circular\(24\),\s*border: Border\.all\(color: accentColor\.withValues\(alpha: 0\.4\)\)',
    'color: _kCard,\n        borderRadius: BorderRadius.circular(24),\n        border: Border.all(color: accentColor.withValues(alpha: 0.12))',
    text
)

# Revert accent colors
text = text.replace('accentColor: const Color(0xFF6D28D9),', 'accentColor: _kViolet,')
text = text.replace('accentColor: const Color(0xFF5B21B6),', 'accentColor: const Color(0xFF3B82F6),')
text = text.replace('accentColor: const Color(0xFF8B5CF6),', 'accentColor: _kAmber,')
text = text.replace('accentColor: const Color(0xFF7C3AED),', 'accentColor: _kGreen,')
text = text.replace('accentColor: const Color(0xFF4C1D95),', 'accentColor: _sentimentColor,')
text = text.replace('accentColor: const Color(0xFF9333EA),', 'accentColor: _kViolet,')

# Revert font colors
text = text.replace('Colors.white.withValues(alpha: 0.6)', 'Colors.white24')
text = text.replace('Colors.white.withValues(alpha: 0.7)', 'Colors.white30')
text = text.replace('Colors.white.withValues(alpha: 0.8)', 'Colors.white38')
text = text.replace('Colors.white.withValues(alpha: 0.9)', 'Colors.white54')
text = text.replace('Colors.white.withValues(alpha: 0.95)', 'Colors.white60')
# text.replace('Colors.white', 'Colors.white70') -> NO, this would corrupt pure white. I won't revert white70->white blindly.

# Muted text
text = text.replace('color: Colors.white.withValues(alpha: 0.8),', 'color: _kMuted,')
text = text.replace('color: Colors.white.withValues(alpha: 0.9),', 'color: _sentimentColor.withValues(alpha: 0.7),')

with open('lib/features/dashboard/dashboard_screen.dart', 'w') as f:
    f.write(text)
