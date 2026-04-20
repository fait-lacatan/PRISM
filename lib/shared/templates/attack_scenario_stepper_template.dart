import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// S1: Attack scenario stepper — card grid + step-through animation.
class AttackScenarioStepperTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color accent;
  const AttackScenarioStepperTemplate({super.key, required this.data, required this.accent});

  @override
  State<AttackScenarioStepperTemplate> createState() => _AttackScenarioStepperTemplateState();
}

class _AttackScenarioStepperTemplateState extends State<AttackScenarioStepperTemplate> {
  int _selectedAttack = -1;
  int _currentStep = 0;

  static const _orange = Color(0xFFE97316);

  static const Map<String, IconData> _iconMap = {
    'group': Icons.group_rounded,
    'person_off': Icons.person_off_rounded,
    'image': Icons.image_rounded,
    'schedule': Icons.schedule_rounded,
    'edit_note': Icons.edit_note_rounded,
    'badge': Icons.badge_rounded,
    'security': Icons.security_rounded,
  };

  Map<String, dynamic> get _d => widget.data;
  List get _attacks => (_d['attacks'] as List?) ?? [];

  void _selectAttack(int i) {
    setState(() {
      if (_selectedAttack == i) {
        _selectedAttack = -1;
      } else {
        _selectedAttack = i;
        _currentStep = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _d['title'] ?? '';
    final subtitle = _d['subtitle'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 14, color: Colors.white38)),
          ],
          const SizedBox(height: 24),
        ],

        // Attack card grid
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final cols = w >= 700 ? 5 : (w >= 500 ? 3 : 2);
            final spacing = 10.0;
            final cardW = (w - spacing * (cols - 1)) / cols;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: List.generate(_attacks.length, (i) {
                final atk = _attacks[i] as Map<String, dynamic>;
                final isSelected = i == _selectedAttack;
                final iconName = atk['icon'] as String? ?? 'security';
                final icon = _iconMap[iconName] ?? Icons.warning_rounded;

                return SizedBox(
                  width: cardW,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _selectAttack(i),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF102540) : const Color(0xFF0f1e30),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? _orange : Colors.white.withValues(alpha: 0.06),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF152a40),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, size: 20, color: isSelected ? _orange : widget.accent),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              atk['title'] ?? '',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: (i * 70).ms, duration: 350.ms).slideY(begin: 0.06);
              }),
            );
          },
        ),

        // Stepper
        AnimatedSize(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _selectedAttack >= 0 ? _buildStepper() : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildStepper() {
    final atk = _attacks[_selectedAttack] as Map<String, dynamic>;
    final steps = (atk['steps'] as List?) ?? [];
    if (steps.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0f1e30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step dots + lines
          Row(
            children: List.generate(steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                // Line
                final lineIdx = i ~/ 2;
                final isDone = lineIdx < _currentStep;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 2,
                    color: isDone ? _orange : Colors.white.withValues(alpha: 0.08),
                  ),
                );
              }
              // Dot
              final dotIdx = i ~/ 2;
              final isDone = dotIdx < _currentStep;
              final isCurrent = dotIdx == _currentStep;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? _orange : (isCurrent ? _orange.withValues(alpha: 0.15) : const Color(0xFF152a40)),
                  border: Border.all(
                    color: isDone || isCurrent ? _orange : Colors.white10,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${dotIdx + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDone ? Colors.black : (isCurrent ? _orange : Colors.white38),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          // Step description
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              _currentStep < steps.length ? steps[_currentStep].toString() : '',
              key: ValueKey('$_selectedAttack-$_currentStep'),
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.75), height: 1.55),
            ),
          ),
          const SizedBox(height: 14),
          // Nav buttons
          Row(
            children: [
              if (_currentStep > 0)
                OutlinedButton(
                  onPressed: () => setState(() => _currentStep--),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _orange.withValues(alpha: 0.3)),
                    foregroundColor: _orange,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('← Back', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              const SizedBox(width: 8),
              if (_currentStep < steps.length - 1)
                FilledButton(
                  onPressed: () => setState(() => _currentStep++),
                  style: FilledButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Next →', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.03);
  }
}
