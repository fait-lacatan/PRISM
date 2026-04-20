import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _kLabAccent = Color(0xFFD29922);

class StationBattleView extends StatefulWidget {
  const StationBattleView({super.key});

  @override
  State<StationBattleView> createState() => _StationBattleViewState();
}

class _StationBattleViewState extends State<StationBattleView> {
  int? _activeAttack;
  bool _isAttacking = false;

  static const List<String> _attacks = [
    'Sybil Attack', 'Replay Attack', 'DDoS', 'Biometric Spoofing',
    'Proxy Attendance', 'Smart Contract Reentrancy', 'Eavesdropping',
    'Man-in-the-Middle', 'DB Injection', 'Metadata Tampering',
    'Node Eclipse', 'Routing Loop', '51% Attack', 'Phishing',
    'Physical Tampering', 'Fake Revocation', 'Time-Delay Attack',
    'Credential Theft', 'Gossip Spam', 'Unauthorized Join',
    'Zero-Day Hardware', 'Admin Escalation',
  ];

  void _triggerAttack(int index) {
    setState(() {
      _activeAttack = index;
      _isAttacking = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isAttacking = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '22-Guard Matrix Battle View',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(color: _kLabAccent),
                    ).animate().fadeIn().slideX(),
                    Text(
                      'Select an attack vector to trigger its smart contract mitigation animation.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: Row(
              children: [
                // Attack vector grid (left)
                Expanded(
                  flex: 3,
                  child: GridView.builder(
                    itemCount: _attacks.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemBuilder: (context, i) {
                      final isActive = _activeAttack == i;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isActive
                              ? _kLabAccent.withValues(alpha: 0.15)
                              : const Color(0xFF18181B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? _kLabAccent
                                : const Color(0xFF27272A),
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _triggerAttack(i),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${i + 1}. ${_attacks[i]}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white54,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 24),

                // Animation panel (right)
                Expanded(
                  flex: 2,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E0E0F),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _isAttacking
                            ? _kLabAccent.withValues(alpha: 0.6)
                            : const Color(0xFF27272A),
                        width: _isAttacking ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: _activeAttack == null
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.touch_app_rounded,
                                    size: 36, color: Colors.white12),
                                const SizedBox(height: 12),
                                Text(
                                  'Select an attack\nto simulate.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.white24),
                                ),
                              ],
                            )
                          : _buildDistinctAnimation(_activeAttack!),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Alert bar
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child:
                  SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0, 0.15), end: Offset.zero)
                          .animate(anim),
                      child: child),
            ),
            child: _isAttacking && _activeAttack != null
                ? Container(
                    key: ValueKey(_activeAttack),
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A0000),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7F1D1D),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shield_outlined,
                              color: Color(0xFFEF4444), size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFFFCA5A5)),
                              children: [
                                const TextSpan(
                                    text: 'DETECTED: ',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFEF4444))),
                                TextSpan(
                                    text:
                                        '${_attacks[_activeAttack!]} on Endpoint-${_activeAttack! + 1}. Guard-${_activeAttack! + 1} triggered logic reversal. Transaction blocked.'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(key: ValueKey('empty')),
          ),
        ],
      ),
    );
  }

  Widget _buildDistinctAnimation(int index) {
    IconData threatIcon;
    IconData guardIcon;
    Color threatColor;
    String explanation;

    switch (index % 5) {
      case 0:
        threatIcon = Icons.group_add_rounded;
        guardIcon = Icons.shield_rounded;
        threatColor = const Color(0xFFEF4444);
        explanation = 'Guard 0x${index}A: Sybil mitigation rejects redundant DIDs at gateway.';
        break;
      case 1:
        threatIcon = Icons.replay_circle_filled_rounded;
        guardIcon = Icons.timer_rounded;
        threatColor = const Color(0xFFF97316);
        explanation = 'Guard 0x${index}B: Timestamp nonce validation blocks replay attacks.';
        break;
      case 2:
        threatIcon = Icons.network_locked_rounded;
        guardIcon = Icons.filter_alt_rounded;
        threatColor = const Color(0xFFA855F7);
        explanation = 'Guard 0x${index}C: Rate-limiting throttles volumetric payload spam.';
        break;
      case 3:
        threatIcon = Icons.face_rounded;
        guardIcon = Icons.qr_code_scanner_rounded;
        threatColor = const Color(0xFFF43F5E);
        explanation = 'Guard 0x${index}D: Edge Node liveness detection enforced against spoofing.';
        break;
      default:
        threatIcon = Icons.bug_report_rounded;
        guardIcon = Icons.security_rounded;
        threatColor = const Color(0xFFEF4444);
        explanation = 'Guard 0x${index}E: ZK payload comparison flags anomalous packets.';
    }

    return Column(
      key: ValueKey(index),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: threatColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: threatColor.withValues(alpha: 0.4)),
              ),
              child: Icon(threatIcon, size: 32, color: threatColor),
            ).animate().slideX(begin: -0.5, duration: 350.ms, curve: Curves.easeOutCubic),
            const SizedBox(width: 20),
            Container(
              width: 3,
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [threatColor, _kLabAccent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ).animate(delay: 300.ms).fadeIn(duration: 200.ms),
            const SizedBox(width: 20),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _kLabAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: _kLabAccent.withValues(alpha: 0.5)),
              ),
              child: Icon(guardIcon, size: 36, color: _kLabAccent),
            )
                .animate(delay: 350.ms)
                .scale(
                    begin: const Offset(0.5, 0.5),
                    duration: 300.ms,
                    curve: Curves.easeOutBack),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'BLOCKED',
          style: GoogleFonts.spaceGrotesk(
            color: _kLabAccent,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 3,
          ),
        ).animate(delay: 500.ms).fadeIn(duration: 200.ms),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            explanation,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
          ),
        ).animate(delay: 600.ms).fadeIn(duration: 300.ms),
      ],
    );
  }
}
