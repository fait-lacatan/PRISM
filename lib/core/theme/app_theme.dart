import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A1A3E),
      brightness: Brightness.light,
      surface: Colors.white,
      onSurface: const Color(0xFF18181B), // Zinc-900
      primary: const Color(0xFF2563EB), // Blue-600
      onPrimary: Colors.white,
      secondary: const Color(0xFF7C3AED), // Violet-600
      onSecondary: Colors.white,
      error: const Color(0xFFDC2626),
      surfaceContainer: const Color(0xFFF4F4F5), // Zinc-100
    );

    return _buildTheme(colorScheme, Brightness.light);
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A1A3E),
      brightness: Brightness.dark,
      surface: const Color(0xFF060608),
      onSurface: Colors.white,
      primary: const Color(0xFF3B82F6),
      onPrimary: Colors.white,
      secondary: const Color(0xFF8B5CF6),
      onSecondary: Colors.white,
      surfaceContainer: const Color(0xFF18181B),
    );

    return _buildTheme(colorScheme, Brightness.dark);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final onSurface = colorScheme.onSurface;
    final muted = isDark ? Colors.white54 : Colors.black54;
    final border = isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: colorScheme.surface,

      // Typography: Space Grotesk for headlines, Inter for body
      textTheme: GoogleFonts.spaceGroteskTextTheme(
        (isDark ? ThemeData.dark() : ThemeData.light()).textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.spaceGrotesk(
          fontSize: 56,
          fontWeight: FontWeight.w900,
          color: onSurface,
          letterSpacing: -2,
        ),
        displayMedium: GoogleFonts.spaceGrotesk(
          fontSize: 40,
          fontWeight: FontWeight.w800,
          color: onSurface,
        ),
        headlineLarge: GoogleFonts.spaceGrotesk(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        headlineMedium: GoogleFonts.spaceGrotesk(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        headlineSmall: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: onSurface.withValues(alpha: 0.8),
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: muted,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: onSurface,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: muted.withValues(alpha: 0.7),
        ),
      ),

      // M3 Card: 28dp radius
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: border, width: 1),
        ),
      ),

      // M3 Filled Button
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // M3 Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: border, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // Navigation Rail
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primary,
        selectedIconTheme: IconThemeData(color: colorScheme.onPrimary, size: 22),
        unselectedIconTheme: IconThemeData(color: muted, size: 22),
        labelType: NavigationRailLabelType.none,
        minWidth: 72,
        minExtendedWidth: 220,
      ),

      // Navigation Bar (mobile)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primary,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? colorScheme.primary : muted,
          );
        }),
      ),

      // AppBar (used in ExhibitShell deep-links)
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        iconTheme: IconThemeData(color: onSurface),
      ),

      // Segmented button / Choice Chips
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: colorScheme.surfaceContainer,
          foregroundColor: muted,
          selectedForegroundColor: colorScheme.onPrimary,
          selectedBackgroundColor: colorScheme.primary,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        selectedColor: colorScheme.primary,
        secondarySelectedColor: colorScheme.primary,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        secondaryLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: border)),
      ),
    );
  }

}
