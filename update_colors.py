import re

with open('lib/features/dashboard/dashboard_screen.dart', 'r') as f:
    text = f.read()

# Make card shells use vibrant violet gradients
text = text.replace(
    '        color: _kCard,\n        borderRadius: BorderRadius.circular(24),\n        border: Border.all(color: accentColor.withValues(alpha: 0.12)),',
    '''        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.6),
            accentColor.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),'''
)

# Reassign accent colors for all the cards to a range of violets
text = text.replace('      accentColor: _kViolet, // _FactorialHeroCard', '      accentColor: const Color(0xFF6D28D9),') # wait, need to target exactly
text = text.replace('accentColor: const Color(0xFF3B82F6),', 'accentColor: const Color(0xFF5B21B6),') # Blockchain
text = text.replace('accentColor: _kAmber,', 'accentColor: const Color(0xFF8B5CF6),') # Latency (except inside other widgets, wait. Latency uses it.)
text = text.replace('accentColor: _kGreen,', 'accentColor: const Color(0xFF7C3AED),') # Security
text = text.replace('accentColor: _sentimentColor,', 'accentColor: const Color(0xFF4C1D95),') # Hero Stats
text = text.replace('accentColor: _kViolet,', 'accentColor: const Color(0xFF9333EA),') # Factorial & Biometrics will share or similar.

# Brighten font colors globally in this file ONLY
text = text.replace('Colors.white24', 'Colors.white.withValues(alpha: 0.6)')
text = text.replace('Colors.white30', 'Colors.white.withValues(alpha: 0.7)')
text = text.replace('Colors.white38', 'Colors.white.withValues(alpha: 0.8)')
text = text.replace('Colors.white54', 'Colors.white.withValues(alpha: 0.9)')
text = text.replace('Colors.white60', 'Colors.white.withValues(alpha: 0.95)')
text = text.replace('Colors.white70', 'Colors.white')

# Update specific _kMuted to white70
text = text.replace('color: _kMuted,', 'color: Colors.white.withValues(alpha: 0.8),')

# Brighten specific highlight texts where contrast might be low
text = text.replace('color: _sentimentColor.withValues(alpha: 0.7),', 'color: Colors.white.withValues(alpha: 0.9),')

with open('lib/features/dashboard/dashboard_screen.dart', 'w') as f:
    f.write(text)
