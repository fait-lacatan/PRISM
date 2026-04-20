import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DeviceBindingTemplate extends StatelessWidget {
  final Map<String, dynamic> data;
  const DeviceBindingTemplate({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final description = data['description'] as String? ?? '';
    final kiosk = data['kiosk'] as Map<String, dynamic>? ?? {};
    final personal = data['personal_device'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(title,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        const SizedBox(height: 12),
        if (description.isNotEmpty)
          Text(description,
              style: GoogleFonts.inter(
                  fontSize: 15, color: Colors.white70, height: 1.6)),
        const SizedBox(height: 24),
        Builder(
          builder: (context) {
            final isNarrow = MediaQuery.of(context).size.width < 700;
            if (isNarrow) {
              return Column(
                children: [
                  _DeviceCard(
                      title: 'Public Kiosk',
                      icon: Icons.storefront,
                      data: kiosk),
                  const SizedBox(height: 16),
                  _DeviceCard(
                      title: 'Personal App',
                      icon: Icons.smartphone,
                      data: personal),
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _DeviceCard(
                        title: 'Public Kiosk',
                        icon: Icons.storefront,
                        data: kiosk),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DeviceCard(
                        title: 'Personal App',
                        icon: Icons.smartphone,
                        data: personal),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Map<String, dynamic> data;

  const _DeviceCard(
      {required this.title, required this.icon, required this.data});

  Color _fromHex(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final color = _fromHex(data['color'] as String? ?? '#38BDF8');
    final capabilities = (data['capabilities'] as List?)?.cast<String>() ?? [];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF071428),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 20,
              spreadRadius: 2)
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...capabilities.map((cap) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle,
                        color: color.withValues(alpha: 0.8), size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        cap,
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ))
        ],
      ),
    );
  }
}
