import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Transaction Flows stage — mode selector tabs, step-through rail with
/// animated progression, and pseudocode per step.
class TransactionFlowTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color accent;
  const TransactionFlowTemplate({super.key, required this.data, required this.accent});

  @override
  State<TransactionFlowTemplate> createState() => _TransactionFlowTemplateState();
}

class _TransactionFlowTemplateState extends State<TransactionFlowTemplate> {
  static const _surfaceDark = Color(0xFF0a1422);
  static const _borderColor = Color(0xFF1a2d42);

  int _selectedFlow = 0;
  int _currentStep = 0;
  bool _showCode = true;

  Map<String, dynamic> get _d => widget.data;
  List get _flows => (_d['flows'] as List?) ?? [];

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF38BDF8);
    }
  }

  Map<String, dynamic> get _activeFlow =>
      _flows.isNotEmpty ? _flows[_selectedFlow] as Map<String, dynamic> : {};

  List get _activeSteps => (_activeFlow['steps'] as List?) ?? [];

  @override
  Widget build(BuildContext context) {
    if (_flows.isEmpty) return const SizedBox.shrink();

    final flowColor = _parseColor(_activeFlow['color'] ?? '#38BDF8');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFlowSelector(),
        const SizedBox(height: 20),
        _buildStepRail(flowColor),
        const SizedBox(height: 20),
        _buildStepDetail(flowColor),
        const SizedBox(height: 16),
        _buildNavControls(flowColor),
      ],
    );
  }

  // ─── FLOW SELECTOR ──────────────────────
  Widget _buildFlowSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TRANSACTION MODE', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFE97316), letterSpacing: 0.8)),
        const SizedBox(height: 6),
        Text('Select a transaction type to step through its execution pipeline',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white38)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(_flows.length, (i) {
            final f = _flows[i] as Map<String, dynamic>;
            final color = _parseColor(f['color'] ?? '#38BDF8');
            final isActive = _selectedFlow == i;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() { _selectedFlow = i; _currentStep = 0; }),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? color : color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isActive ? color : color.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        f['label'] ?? '',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isActive ? const Color(0xFF0a1422) : color,
                        ),
                      ),
                      if (f['algo'] != null)
                        Text(f['algo'], style: GoogleFonts.inter(
                          fontSize: 10,
                          color: isActive ? const Color(0xFF0a1422).withValues(alpha: 0.6) : color.withValues(alpha: 0.5),
                        )),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ─── STEP RAIL ──────────────────────────
  Widget _buildStepRail(Color flowColor) {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 500;

      if (isNarrow) {
        // Vertical rail for narrow
        return Column(
          children: List.generate(_activeSteps.length, (i) {
            final step = _activeSteps[i] as Map<String, dynamic>;
            final isActive = _currentStep == i;
            final isPast = _currentStep > i;
            return GestureDetector(
              onTap: () => setState(() => _currentStep = i),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? flowColor : isPast ? flowColor.withValues(alpha: 0.3) : _surfaceDark,
                        border: Border.all(color: isActive ? flowColor : isPast ? flowColor.withValues(alpha: 0.3) : _borderColor, width: 1.5),
                      ),
                      child: Center(child: Text('${i + 1}', style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: isActive || isPast ? Colors.white : Colors.white24,
                      ))),
                    ),
                    if (i < _activeSteps.length - 1)
                      Container(width: 1.5, height: 20, color: isPast ? flowColor.withValues(alpha: 0.4) : _borderColor),
                  ]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        step['title'] ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                          color: isActive ? flowColor : Colors.white.withValues(alpha: isPast ? 0.5 : 0.3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      }

      // Horizontal rail for wide
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_activeSteps.length, (i) {
            final step = _activeSteps[i] as Map<String, dynamic>;
            final isActive = _currentStep == i;
            final isPast = _currentStep > i;
            return GestureDetector(
              onTap: () => setState(() => _currentStep = i),
              child: Row(children: [
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? flowColor : isPast ? flowColor.withValues(alpha: 0.3) : _surfaceDark,
                      border: Border.all(color: isActive ? flowColor : isPast ? flowColor.withValues(alpha: 0.3) : _borderColor, width: 1.5),
                      boxShadow: isActive ? [BoxShadow(color: flowColor.withValues(alpha: 0.2), blurRadius: 8)] : [],
                    ),
                    child: Center(child: Text('${i + 1}', style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: isActive || isPast ? Colors.white : Colors.white24,
                    ))),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 80,
                    child: Text(
                      step['title'] ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                        color: isActive ? flowColor : Colors.white.withValues(alpha: isPast ? 0.5 : 0.3),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                if (i < _activeSteps.length - 1)
                  Container(
                    width: 40, height: 1.5, margin: const EdgeInsets.only(bottom: 28),
                    color: isPast ? flowColor.withValues(alpha: 0.4) : _borderColor,
                  ),
              ]),
            );
          }),
        ),
      );
    });
  }

  // ─── STEP DETAIL ────────────────────────
  Widget _buildStepDetail(Color flowColor) {
    if (_activeSteps.isEmpty) return const SizedBox.shrink();
    final step = _activeSteps[_currentStep] as Map<String, dynamic>;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey('${_selectedFlow}_$_currentStep'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: flowColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: flowColor.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: flowColor, borderRadius: BorderRadius.circular(4)),
              child: Text('STEP ${_currentStep + 1}', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF0a1422))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(step['title'] ?? '', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
          ]),
          const SizedBox(height: 12),
          Text(step['desc'] ?? '', style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, height: 1.6)),

          // Pseudocode
          if (_showCode && step['code'] != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0a1422),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderColor),
              ),
              child: Text(step['code'] ?? '', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFFFBBF24), height: 1.5)),
            ),
          ],
        ]),
      ),
    );
  }

  // ─── NAV CONTROLS ──────────────────────
  Widget _buildNavControls(Color flowColor) {
    return Row(
      children: [
        // Previous
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _currentStep > 0 ? () => setState(() => _currentStep--) : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _currentStep > 0 ? flowColor.withValues(alpha: 0.4) : _borderColor),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.arrow_back_ios_rounded, size: 12, color: _currentStep > 0 ? flowColor : Colors.white24),
                const SizedBox(width: 4),
                Text('Previous', style: GoogleFonts.inter(fontSize: 12, color: _currentStep > 0 ? flowColor : Colors.white24)),
              ]),
            ),
          ),
        ),
        const Spacer(),

        // Toggle code
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _showCode = !_showCode),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _showCode ? const Color(0xFFFBBF24).withValues(alpha: 0.3) : _borderColor),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.code_rounded, size: 14, color: _showCode ? const Color(0xFFFBBF24) : Colors.white24),
                const SizedBox(width: 4),
                Text(_showCode ? 'Hide Code' : 'Show Code', style: GoogleFonts.inter(fontSize: 11, color: _showCode ? const Color(0xFFFBBF24) : Colors.white24)),
              ]),
            ),
          ),
        ),
        const Spacer(),

        // Next
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _currentStep < _activeSteps.length - 1 ? () => setState(() => _currentStep++) : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _currentStep < _activeSteps.length - 1 ? flowColor : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: _currentStep >= _activeSteps.length - 1 ? Border.all(color: _borderColor) : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Next', style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _currentStep < _activeSteps.length - 1 ? const Color(0xFF0a1422) : Colors.white24,
                )),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios_rounded, size: 12,
                  color: _currentStep < _activeSteps.length - 1 ? const Color(0xFF0a1422) : Colors.white24),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}
