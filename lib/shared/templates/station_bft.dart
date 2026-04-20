import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _kLabAccent = Color(0xFFD29922);

class StationBft extends StatefulWidget {
  const StationBft({super.key});

  @override
  State<StationBft> createState() => _StationBftState();
}

class _StationBftState extends State<StationBft> {
  String _faultType = 'none';
  Set<int> _crashedNodes = {};
  Set<int> _maliciousNodes = {};

  static const int _totalNodes = 4;

  int get activeNodes =>
      _totalNodes - _crashedNodes.length - _maliciousNodes.length;
  bool get hasQuorum => activeNodes >= 3;

  void _updateFaults(String type) {
    setState(() {
      _faultType = type;
      _crashedNodes = {};
      _maliciousNodes = {};
      if (type == 'crash') _crashedNodes = {3};          // Node 4
      if (type == 'malicious') _maliciousNodes = {3};    // Node 4
      if (type == 'partition') _crashedNodes = {2, 3};   // Nodes 3 & 4
    });
  }

  String get _statusText {
    switch (_faultType) {
      case 'malicious':
        return '> ALERT: Node 4 proposing invalid transaction batch. QBFT observing 2/3+1 consensus. Liveness maintained.';
      case 'crash':
        return '> ALERT: Node 4 unresponsive. Minimum 3/4 validators active. Consistency guaranteed.';
      case 'partition':
        return '> WARNING: Network split detected. Quorum (N1, N2) cannot reach (N3, N4). Finality halted.';
      default:
        return '> STATUS: QBFT Consensus Cluster Optimal. Latency: 12ms. f = ⌊(4-1)/3⌋ = 1.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '4-Node Quorum BFT Simulator',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: _kLabAccent),
          ).animate().fadeIn().slideX(),
          const SizedBox(height: 8),
          Text(
            'Toggle fault type to observe consensus behavior. Requires ≥ 3 active nodes.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),

          // Fault type segmented button
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'none',
                  label: Text('Normal'),
                  icon: Icon(Icons.check_circle_outline_rounded, size: 16)),
              ButtonSegment(
                  value: 'crash',
                  label: Text('Crash'),
                  icon: Icon(Icons.power_off_rounded, size: 16)),
              ButtonSegment(
                  value: 'malicious',
                  label: Text('Malicious'),
                  icon: Icon(Icons.warning_amber_rounded, size: 16)),
              ButtonSegment(
                  value: 'partition',
                  label: Text('Partition'),
                  icon: Icon(Icons.call_split_rounded, size: 16)),
            ],
            selected: {_faultType},
            onSelectionChanged: (v) => _updateFaults(v.first),
          ),
          const SizedBox(height: 32),

          // Consensus status chip
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: hasQuorum
                    ? const Color(0xFF052E16)
                    : const Color(0xFF1A0000),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: hasQuorum
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFEF4444),
                ),
              ),
              child: Text(
                hasQuorum
                    ? '✓  QUORUM REACHED  —  $activeNodes / $_totalNodes nodes active'
                    : '✕  CONSENSUS HALTED  —  Insufficient validators',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: hasQuorum
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFFF87171),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Node grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 2.4,
              children: List.generate(_totalNodes, (i) => _buildNode(i)),
            ),
          ),

          const SizedBox(height: 20),

          // Terminal readout
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _statusText,
                key: ValueKey(_faultType),
                style: GoogleFonts.firaCode(
                  fontSize: 12,
                  color: _faultType == 'none'
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFFFBBF24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNode(int i) {
    final isCrashed = _crashedNodes.contains(i);
    final isMalicious = _maliciousNodes.contains(i);
    final isActive = !isCrashed && !isMalicious;

    Color borderColor;
    Color bgColor;
    IconData icon;
    Color iconColor;
    String statusLabel;

    if (isCrashed) {
      borderColor = const Color(0xFF71717A);
      bgColor = const Color(0xFF0A0A0A);
      icon = Icons.power_off_rounded;
      iconColor = Colors.white24;
      statusLabel = 'OFFLINE';
    } else if (isMalicious) {
      borderColor = const Color(0xFFEF4444);
      bgColor = const Color(0xFF1A0000);
      icon = Icons.security_update_warning_rounded;
      iconColor = const Color(0xFFEF4444);
      statusLabel = 'MALICIOUS';
    } else {
      borderColor = _kLabAccent;
      bgColor = const Color(0xFF1A1400);
      icon = Icons.dns_rounded;
      iconColor = _kLabAccent;
      statusLabel = 'ACTIVE';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 350),
              opacity: isCrashed ? 0.3 : 1.0,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: borderColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Node ${i + 1}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            if (isActive && hasQuorum) ...[
              const Spacer(),
              Icon(Icons.sync_rounded,
                      size: 16, color: _kLabAccent.withValues(alpha: 0.6))
                  .animate(onPlay: (c) => c.repeat())
                  .rotate(duration: 3.seconds, curve: Curves.linear),
            ],
          ],
        ),
      ),
    );
  }
}
