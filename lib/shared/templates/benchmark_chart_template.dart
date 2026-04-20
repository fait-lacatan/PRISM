import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

/// Interactive benchmark chart template.
///
/// Reads pre-aggregated data from benchmark_chart_data.json and renders
/// one of three chart types based on the `chart_type` key:
///   - network_medium  → LineChart (throughput vs load)
///   - latency_stability → ScatterChart + box-whisker overlay
///   - ipfs_cost → LineChart as slope chart (2-point)
class BenchmarkChartTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color accent;

  const BenchmarkChartTemplate({
    super.key,
    required this.data,
    required this.accent,
  });

  @override
  State<BenchmarkChartTemplate> createState() => _BenchmarkChartTemplateState();
}

class _BenchmarkChartTemplateState extends State<BenchmarkChartTemplate> {
  Map<String, dynamic>? _chartData;
  List<dynamic>? _bftData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final raw = await rootBundle.loadString('assets/content/benchmark_chart_data.json');
      final parsed = json.decode(raw) as Map<String, dynamic>;
      // Load BFT data separately (may not exist for non-BFT charts)
      List<dynamic>? bft;
      try {
        final bftRaw = await rootBundle.loadString('assets/content/bft_health_data.json');
        bft = json.decode(bftRaw) as List<dynamic>;
      } catch (_) {}
      if (mounted) {
        setState(() {
          _chartData = parsed;
          _bftData = bft;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chartType = widget.data['chart_type'] as String? ?? '';
    final title = widget.data['title'] as String? ?? '';
    final subtitle = widget.data['subtitle'] as String? ?? '';
    final isPhone = MediaQuery.of(context).size.width < 500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: isPhone ? 18 : 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: isPhone ? 12 : 13, color: Colors.white54),
              ),
            ),
          const SizedBox(height: 24),
        ],
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_chartData == null)
          Text('Failed to load chart data', style: GoogleFonts.inter(color: Colors.red))
        else
          _buildChart(chartType),
      ],
    );
  }

  Widget _buildChart(String chartType) {
    switch (chartType) {
      case 'network_medium':
        return _NetworkMediumChart(
          data: _chartData!['network_medium'] as Map<String, dynamic>,
          accent: widget.accent,
        );
      case 'latency_stability':
        return _LatencyStabilityChart(
          data: (_chartData!['latency_stability'] as List).cast<Map<String, dynamic>>(),
          accent: widget.accent,
        );
      case 'ipfs_cost':
        return _IpfsCostChart(
          data: (_chartData!['ipfs_cost'] as List).cast<Map<String, dynamic>>(),
          accent: widget.accent,
        );
      case 'protocol_ceiling':
        return _ProtocolCeilingChart(
          data: _chartData!['network_medium'] as Map<String, dynamic>,
          accent: widget.accent,
        );
      case 'bft_health':
        if (_bftData == null) {
          return Text('BFT data not available', style: GoogleFonts.inter(color: Colors.white38));
        }
        return _BftHealthChart(
          scenarios: _bftData!.cast<Map<String, dynamic>>(),
          accent: widget.accent,
        );
      default:
        return Text('Unknown chart type: $chartType',
            style: GoogleFonts.inter(color: Colors.red));
    }
  }
}

// ─── Chart 4: Protocol Ceiling Disparity ─────────────────────────────────────

class _ProtocolCeilingChart extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color accent;

  const _ProtocolCeilingChart({required this.data, required this.accent});

  @override
  Widget build(BuildContext context) {
    // Filter for Wired only from ingestion and consensus series
    final ingestionSeries = ((data['ingestion'] as List?) ?? [])
        .cast<Map<String, dynamic>>()
        .where((s) => s['medium'] == 'Wired')
        .toList();
    final consensusSeries = ((data['consensus'] as List?) ?? [])
        .cast<Map<String, dynamic>>()
        .where((s) => s['medium'] == 'Wired')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Workload legend
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: _kWorkloadColors.entries.map((e) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(color: e.value, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(e.key[0].toUpperCase() + e.key.substring(1),
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
            ],
          )).toList(),
        ),
        const SizedBox(height: 20),
        // Ingestion sub-chart
        _ProtocolSubLabel(
          label: 'INGESTION',
          color: _kWiredColor,
          suffix: '(API Layer)',
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: _buildLineChart(
            series: ingestionSeries,
            yLabel: 'Ingestion TPS',
          ),
        ),
        const SizedBox(height: 24),
        // Gap callout
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swap_vert_rounded, size: 18,
                    color: const Color(0xFFEF4444).withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                Text(
                  '~8.4× gap · Consensus serialization is the binding constraint',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFEF4444).withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Consensus sub-chart
        _ProtocolSubLabel(
          label: 'CONSENSUS',
          color: const Color(0xFFEF4444),
          suffix: '(QBFT Finality)',
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: _buildLineChart(
            series: consensusSeries,
            yLabel: 'Consensus TPS',
          ),
        ),
      ],
    );
  }

  Widget _buildLineChart({
    required List<Map<String, dynamic>> series,
    required String yLabel,
  }) {
    final lineBars = <LineChartBarData>[];
    double maxX = 0, maxY = 0;

    for (final s in series) {
      final workload = s['workload'] as String;
      final points = (s['points'] as List).cast<Map<String, dynamic>>();
      final color = _kWorkloadColors[workload] ?? Colors.grey;

      final spots = points.map((p) {
        final x = (p['load'] as num).toDouble();
        final y = (p['tps'] as num).toDouble();
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
        return FlSpot(x, y);
      }).toList();

      lineBars.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.15,
        color: color,
        barWidth: 2.5,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (s, d, b, i) =>
              FlDotCirclePainter(radius: 2.5, color: color, strokeWidth: 0),
        ),
        belowBarData: BarAreaData(
          show: true,
          color: color.withValues(alpha: 0.05),
        ),
      ));
    }

    if (lineBars.isEmpty) {
      return Center(child: Text('No data', style: GoogleFonts.inter(color: Colors.white38)));
    }

    // Add ceiling reference line
    lineBars.add(LineChartBarData(
      spots: [FlSpot(0, maxY), FlSpot(maxX, maxY)],
      isCurved: false,
      color: Colors.white.withValues(alpha: 0.15),
      barWidth: 1,
      dashArray: [4, 4],
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    ));

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX * 1.05,
        minY: 0,
        maxY: maxY * 1.15,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: Colors.white.withValues(alpha: 0.06),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            axisNameWidget: Text(yLabel,
                style: GoogleFonts.firaCode(fontSize: 10, color: Colors.white38)),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, meta) => Text(
                v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toInt().toString(),
                style: GoogleFonts.firaCode(fontSize: 10, color: Colors.white30),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 250,
              getTitlesWidget: (v, meta) => Text(
                v.toInt().toString(),
                style: GoogleFonts.firaCode(fontSize: 9, color: Colors.white24),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => const Color(0xFF1E1E2E),
            getTooltipItems: (spots) => spots
                .where((s) => s.bar.dashArray == null)
                .map((s) => LineTooltipItem(
                      '${s.x.toInt()} → ${s.y.toStringAsFixed(1)} TPS',
                      GoogleFonts.firaCode(fontSize: 11, color: Colors.white70),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: lineBars,
      ),
    );
  }
}

class _ProtocolSubLabel extends StatelessWidget {
  final String label;
  final Color color;
  final String suffix;

  const _ProtocolSubLabel({
    required this.label,
    required this.color,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: GoogleFonts.firaCode(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          suffix,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
        ),
      ],
    );
  }
}

// ─── Chart 5: BFT Consensus Health ──────────────────────────────────────────

const _kNodeColors = {
  'node1': Color(0xFF536DFE),
  'node2': Color(0xFFFF9100),
  'node3': Color(0xFF69F0AE),
  'node4': Color(0xFFFF5252),
};

class _BftHealthChart extends StatefulWidget {
  final List<Map<String, dynamic>> scenarios;
  final Color accent;

  const _BftHealthChart({required this.scenarios, required this.accent});

  @override
  State<_BftHealthChart> createState() => _BftHealthChartState();
}

class _BftHealthChartState extends State<_BftHealthChart> {
  int _selectedIdx = 0;

  @override
  Widget build(BuildContext context) {
    final scenario = widget.scenarios[_selectedIdx];
    final faultRel = (scenario['fault_rel'] as num?)?.toDouble();
    final recovRel = (scenario['recov_rel'] as num?)?.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scenario tabs
        _SegmentedToggle(
          options: List.generate(widget.scenarios.length, (i) => i.toString()),
          labels: widget.scenarios.map((s) => s['scenario'] as String).toList(),
          selected: _selectedIdx.toString(),
          onChanged: (v) => setState(() => _selectedIdx = int.parse(v)),
          accent: widget.accent,
        ),
        const SizedBox(height: 16),
        // Node legend
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: _kNodeColors.entries.map((e) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(color: e.value, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(e.key,
                  style: GoogleFonts.firaCode(fontSize: 11, color: Colors.white54)),
            ],
          )).toList(),
        ),
        // Fault window indicator
        if (faultRel != null && recovRel != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Container(width: 16, height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.3)),
                  )),
              const SizedBox(width: 6),
              Text(
                'Fault window: ${faultRel.toInt()}s – ${recovRel.toInt()}s',
                style: GoogleFonts.firaCode(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),

        // Sub-chart 1: Block Height
        _BftSubLabel(label: 'BLOCK HEIGHT', icon: Icons.stacked_bar_chart_rounded),
        const SizedBox(height: 6),
        _BftNodeLineChart(
          nodeData: (scenario['block_height'] as List).cast<Map<String, dynamic>>(),
          faultRel: faultRel,
          recovRel: recovRel,
          yLabel: 'Block #',
        ),
        const SizedBox(height: 24),

        // Sub-chart 2: TPS
        _BftSubLabel(label: 'THROUGHPUT', icon: Icons.speed_rounded),
        const SizedBox(height: 6),
        _BftSingleLineChart(
          points: (scenario['tps'] as List).cast<Map<String, dynamic>>(),
          faultRel: faultRel,
          recovRel: recovRel,
          yLabel: 'TPS',
          lineColor: const Color(0xFF7C4DFF),
        ),
        const SizedBox(height: 24),

        // Sub-chart 3: Latency
        _BftSubLabel(label: 'LATENCY', icon: Icons.timer_outlined),
        const SizedBox(height: 6),
        _BftSingleLineChart(
          points: (scenario['latency_mean'] as List).cast<Map<String, dynamic>>(),
          faultRel: faultRel,
          recovRel: recovRel,
          yLabel: 'ms',
          lineColor: const Color(0xFFFF9100),
        ),
        const SizedBox(height: 24),

        // Sub-chart 4: Peer Count
        _BftSubLabel(label: 'PEER COUNT', icon: Icons.people_outline_rounded),
        const SizedBox(height: 6),
        _BftNodeLineChart(
          nodeData: (scenario['peer_count'] as List).cast<Map<String, dynamic>>(),
          faultRel: faultRel,
          recovRel: recovRel,
          yLabel: 'Peers',
          fixedMaxY: 4.5,
        ),
      ],
    );
  }
}

class _BftSubLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _BftSubLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white30),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.firaCode(
            fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white30, letterSpacing: 1.2)),
      ],
    );
  }
}

/// Multi-node line chart (for block height and peer count).
class _BftNodeLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> nodeData;
  final double? faultRel;
  final double? recovRel;
  final String yLabel;
  final double? fixedMaxY;

  const _BftNodeLineChart({
    required this.nodeData,
    this.faultRel,
    this.recovRel,
    required this.yLabel,
    this.fixedMaxY,
  });

  @override
  Widget build(BuildContext context) {
    final lineBars = <LineChartBarData>[];
    double maxX = 0, maxY = 0;

    for (final nd in nodeData) {
      final node = nd['node'] as String;
      final points = (nd['points'] as List).cast<Map<String, dynamic>>();
      final color = _kNodeColors[node] ?? Colors.grey;

      final spots = points.map((p) {
        final x = (p['t'] as num).toDouble();
        final y = (p['v'] as num).toDouble();
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
        return FlSpot(x, y);
      }).toList();

      lineBars.add(LineChartBarData(
        spots: spots,
        isCurved: false,
        color: color.withValues(alpha: 0.9),
        barWidth: 2,
        isStepLineChart: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (s, d, b, i) =>
              FlDotCirclePainter(radius: 2, color: color, strokeWidth: 0),
        ),
        belowBarData: BarAreaData(show: false),
      ));
    }

    final effectiveMaxY = fixedMaxY ?? maxY * 1.1;

    return SizedBox(
      height: 160,
      child: CustomPaint(
        foregroundPainter: _FaultShadePainter(
          faultRel: faultRel, recovRel: recovRel,
          maxX: maxX * 1.05, maxY: effectiveMaxY,
          leftPad: 48, bottomPad: 24,
        ),
        child: LineChart(
          LineChartData(
            minX: 0, maxX: maxX * 1.05,
            minY: 0, maxY: effectiveMaxY,
            gridData: FlGridData(
              show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (v) => FlLine(
                color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
            ),
            titlesData: _bftTitles(yLabel),
            borderData: _bftBorder(),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (s) => const Color(0xFF1E1E2E),
                getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                  s.y.toStringAsFixed(0),
                  GoogleFonts.firaCode(fontSize: 11, color: Colors.white70),
                )).toList(),
              ),
            ),
            lineBarsData: lineBars,
          ),
        ),
      ),
    );
  }
}

/// Single-series line chart (for TPS and latency).
class _BftSingleLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> points;
  final double? faultRel;
  final double? recovRel;
  final String yLabel;
  final Color lineColor;

  const _BftSingleLineChart({
    required this.points,
    this.faultRel,
    this.recovRel,
    required this.yLabel,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    double maxX = 0, maxY = 0;
    final spots = points.map((p) {
      final x = (p['t'] as num).toDouble();
      final y = (p['v'] as num).toDouble();
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
      return FlSpot(x, y);
    }).toList();

    return SizedBox(
      height: 160,
      child: CustomPaint(
        foregroundPainter: _FaultShadePainter(
          faultRel: faultRel, recovRel: recovRel,
          maxX: maxX * 1.05, maxY: maxY * 1.2,
          leftPad: 48, bottomPad: 24,
        ),
        child: LineChart(
          LineChartData(
            minX: 0, maxX: maxX * 1.05,
            minY: 0, maxY: maxY * 1.2,
            gridData: FlGridData(
              show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (v) => FlLine(
                color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
            ),
            titlesData: _bftTitles(yLabel),
            borderData: _bftBorder(),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (s) => const Color(0xFF1E1E2E),
                getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                  '${s.y.toStringAsFixed(0)} $yLabel',
                  GoogleFonts.firaCode(fontSize: 11, color: Colors.white70),
                )).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.2,
                color: lineColor,
                barWidth: 2.5,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: lineColor.withValues(alpha: 0.06),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints red shading for the fault injection window.
class _FaultShadePainter extends CustomPainter {
  final double? faultRel;
  final double? recovRel;
  final double maxX;
  final double maxY;
  final double leftPad;
  final double bottomPad;

  _FaultShadePainter({
    this.faultRel,
    this.recovRel,
    required this.maxX,
    required this.maxY,
    required this.leftPad,
    required this.bottomPad,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (faultRel == null || recovRel == null) return;
    final chartW = size.width - leftPad;
    final chartH = size.height - bottomPad;

    final x1 = leftPad + (faultRel! / maxX) * chartW;
    final x2 = leftPad + (recovRel! / maxX) * chartW;

    // Shading
    canvas.drawRect(
      Rect.fromLTRB(x1, 0, x2, chartH),
      Paint()..color = const Color(0xFFFF5252).withValues(alpha: 0.06),
    );
    // Fault line
    canvas.drawLine(
      Offset(x1, 0), Offset(x1, chartH),
      Paint()
        ..color = const Color(0xFFFF5252).withValues(alpha: 0.4)
        ..strokeWidth = 1,
    );
    // Recovery line
    canvas.drawLine(
      Offset(x2, 0), Offset(x2, chartH),
      Paint()
        ..color = const Color(0xFF69F0AE).withValues(alpha: 0.4)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

FlTitlesData _bftTitles(String yLabel) => FlTitlesData(
  leftTitles: AxisTitles(
    axisNameWidget: Text(yLabel,
        style: GoogleFonts.firaCode(fontSize: 10, color: Colors.white38)),
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 44,
      getTitlesWidget: (v, meta) => Text(
        v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toInt().toString(),
        style: GoogleFonts.firaCode(fontSize: 9, color: Colors.white24),
      ),
    ),
  ),
  bottomTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 20,
      getTitlesWidget: (v, meta) => Text(
        '${v.toInt()}s',
        style: GoogleFonts.firaCode(fontSize: 8, color: Colors.white24),
      ),
    ),
  ),
  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
);

FlBorderData _bftBorder() => FlBorderData(
  show: true,
  border: Border(
    left: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
  ),
);

// ─── Color Constants ─────────────────────────────────────────────────────────

const _kWiredColor = Color(0xFF3B82F6);
const _kWirelessColor = Color(0xFFE97316);
const _kZeroInfraColor = Color(0xFF8B5CF6);

const _kWorkloadColors = {
  'enroll': Color(0xFF3B82F6),
  'record': Color(0xFFEF4444),
  'reissue': Color(0xFF10B981),
  'revoke': Color(0xFF8B5CF6),
};

Color _mediumColor(String medium) {
  switch (medium.toLowerCase()) {
    case 'wired': return _kWiredColor;
    case 'wireless': return _kWirelessColor;
    case 'zero-infra': return _kZeroInfraColor;
    default: return Colors.grey;
  }
}

// ─── Chart 1: Network Medium Impact ──────────────────────────────────────────

class _NetworkMediumChart extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color accent;

  const _NetworkMediumChart({required this.data, required this.accent});

  @override
  State<_NetworkMediumChart> createState() => _NetworkMediumChartState();
}

class _NetworkMediumChartState extends State<_NetworkMediumChart> {
  String _mode = 'ingestion';
  String _workloadFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final seriesList = (widget.data[_mode] as List?) ?? [];

    // Get unique workloads for filter
    final workloads = <String>{};
    for (final s in seriesList) {
      workloads.add((s as Map<String, dynamic>)['workload'] as String);
    }

    // Filter series
    final filteredSeries = _workloadFilter == 'all'
        ? seriesList
        : seriesList.where((s) => (s as Map<String, dynamic>)['workload'] == _workloadFilter).toList();

    // Build line data
    final lineBars = <LineChartBarData>[];
    double maxX = 0, maxY = 0;

    for (final s in filteredSeries) {
      final series = s as Map<String, dynamic>;
      final medium = series['medium'] as String;
      final points = (series['points'] as List).cast<Map<String, dynamic>>();
      final color = _mediumColor(medium);

      final spots = points.map((p) {
        final x = (p['load'] as num).toDouble();
        final y = (p['tps'] as num).toDouble();
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
        return FlSpot(x, y);
      }).toList();

      lineBars.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.15,
        color: color,
        barWidth: 2.5,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (s, d, b, i) =>
              FlDotCirclePainter(radius: 3, color: color, strokeWidth: 0),
        ),
        belowBarData: BarAreaData(
          show: true,
          color: color.withValues(alpha: 0.06),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle: Ingestion / Consensus
        _SegmentedToggle(
          options: const ['ingestion', 'consensus'],
          labels: const ['Ingestion', 'Consensus'],
          selected: _mode,
          onChanged: (v) => setState(() => _mode = v),
          accent: const Color(0xFF38BDF8),
        ),
        const SizedBox(height: 12),
        // Workload filter chips
        LayoutBuilder(
          builder: (context, constraints) {
            final theme = Theme.of(context);
            final surfaceColor = theme.scaffoldBackgroundColor;
            final sortedWorkloads = workloads.toList()..sort();
            
            Widget scrollView = SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CustomChoiceChip(
                      label: 'All',
                      isSelected: _workloadFilter == 'all',
                      onSelected: (s) { if (s) setState(() => _workloadFilter = 'all'); },
                      selectedColor: const Color(0xFFFBBF24),
                    ),
                    const SizedBox(width: 8),
                    for (int i = 0; i < sortedWorkloads.length; i++) ...[
                      _CustomChoiceChip(
                        label: sortedWorkloads[i][0].toUpperCase() + sortedWorkloads[i].substring(1),
                        isSelected: _workloadFilter == sortedWorkloads[i],
                        onSelected: (s) { if (s) setState(() => _workloadFilter = sortedWorkloads[i]); },
                        selectedColor: const Color(0xFFFBBF24),
                      ),
                      if (i < sortedWorkloads.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            );

            if (constraints.maxWidth >= 600) return scrollView;

            return SizedBox(
              width: double.infinity,
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [surfaceColor, surfaceColor, surfaceColor.withValues(alpha: 0.0)],
                    stops: const [0.0, 0.85, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: scrollView,
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        // Legend
        _MediumLegend(series: filteredSeries.cast<Map<String, dynamic>>()),
        const SizedBox(height: 12),
        // Chart
        SizedBox(
          height: 340,
          child: lineBars.isEmpty
              ? Center(child: Text('No data', style: GoogleFonts.inter(color: Colors.white38)))
              : LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: maxX * 1.05,
                    minY: 0,
                    maxY: maxY * 1.1,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (v) => FlLine(
                        color: Colors.white.withValues(alpha: 0.06),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        axisNameWidget: Text('TPS',
                            style: GoogleFonts.firaCode(fontSize: 10, color: Colors.white38)),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (v, meta) => Text(
                            v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toInt().toString(),
                            style: GoogleFonts.firaCode(fontSize: 10, color: Colors.white30),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        axisNameWidget: Text('Target Load (TPS)',
                            style: GoogleFonts.firaCode(fontSize: 10, color: Colors.white38)),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: _mode == 'consensus' ? 50 : 250,
                          getTitlesWidget: (v, meta) => Text(
                            v.toInt().toString(),
                            style: GoogleFonts.firaCode(fontSize: 9, color: Colors.white24),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        left: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (spot) => const Color(0xFF1E1E2E),
                        getTooltipItems: (spots) => spots.map((s) {
                          return LineTooltipItem(
                            '${s.x.toInt()} TPS → ${s.y.toStringAsFixed(1)} TPS',
                            GoogleFonts.firaCode(fontSize: 11, color: Colors.white70),
                          );
                        }).toList(),
                      ),
                    ),
                    lineBarsData: lineBars,
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Chart 2: Latency Stability (Violin Plot) ──────────────────────────────

class _LatencyStabilityChart extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final Color accent;

  const _LatencyStabilityChart({required this.data, required this.accent});

  @override
  State<_LatencyStabilityChart> createState() => _LatencyStabilityChartState();
}

class _LatencyStabilityChartState extends State<_LatencyStabilityChart> {
  String _medium = 'all';
  int? _tappedIdx;

  List<_ViolinGroup> _buildGroups() {
    final filtered = _medium == 'all'
        ? widget.data
        : widget.data.where((d) => d['medium'] == _medium).toList();

    return filtered.map((g) {
      final workload = g['workload'] as String;
      final medium = g['medium'] as String;
      final stats = g['stats'] as Map<String, dynamic>?;
      final points = (g['points'] as List).cast<Map<String, dynamic>>();
      final latencies = points.map((p) => (p['latency'] as num).toDouble()).toList()..sort();

      return _ViolinGroup(
        workload: workload,
        medium: medium,
        latencies: latencies,
        color: _kWorkloadColors[workload] ?? Colors.grey,
        mediumColor: _mediumColor(medium),
        min: stats != null ? (stats['min'] as num).toDouble() : latencies.first,
        q1: stats != null ? (stats['q1'] as num).toDouble() : latencies.first,
        median: stats != null ? (stats['median'] as num).toDouble() : latencies.first,
        q3: stats != null ? (stats['q3'] as num).toDouble() : latencies.first,
        max: stats != null ? (stats['max'] as num).toDouble() : latencies.last,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _buildGroups();
    double globalMaxLat = 0;
    for (final g in groups) {
      for (final l in g.latencies) {
        if (l > globalMaxLat) globalMaxLat = l;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Medium filter
        _SegmentedToggle(
          options: const ['all', 'Wired', 'Wireless'],
          labels: const ['All', 'Wired', 'Wireless'],
          selected: _medium,
          onChanged: (v) => setState(() { _medium = v; _tappedIdx = null; }),
          accent: widget.accent,
        ),
        const SizedBox(height: 16),
        // Legend
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: _kWorkloadColors.entries.map((e) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(color: e.value, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(e.key[0].toUpperCase() + e.key.substring(1),
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
            ],
          )).toList(),
        ),
        const SizedBox(height: 8),
        // Indicator key
        Row(
          children: [
            Container(width: 14, height: 2, color: Colors.white54),
            const SizedBox(width: 4),
            Text('Median', style: GoogleFonts.firaCode(fontSize: 9, color: Colors.white30)),
            const SizedBox(width: 12),
            Container(width: 14, height: 1, color: Colors.white24),
            const SizedBox(width: 4),
            Text('Q1 / Q3', style: GoogleFonts.firaCode(fontSize: 9, color: Colors.white30)),
          ],
        ),
        const SizedBox(height: 16),
        // Violin chart
        SizedBox(
          height: 380,
          child: groups.isEmpty
              ? Center(child: Text('No data', style: GoogleFonts.inter(color: Colors.white38)))
              : LayoutBuilder(builder: (context, constraints) {
                  return GestureDetector(
                    onTapDown: (details) {
                      const leftPad = 48.0;
                      final usableW = constraints.maxWidth - leftPad;
                      final groupW = usableW / groups.length;
                      final idx = ((details.localPosition.dx - leftPad) / groupW).floor();
                      setState(() => _tappedIdx = (idx >= 0 && idx < groups.length) ? (_tappedIdx == idx ? null : idx) : null);
                    },
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, 380),
                      painter: _ViolinPainter(
                        groups: groups,
                        maxY: globalMaxLat * 1.1,
                        hoveredIdx: _tappedIdx,
                        showMediumLabel: _medium == 'all',
                      ),
                    ),
                  );
                }),
        ),
        // Tooltip
        if (_tappedIdx != null && _tappedIdx! < groups.length) ...[
          const SizedBox(height: 12),
          _buildTooltip(groups[_tappedIdx!]),
        ],
      ],
    );
  }

  Widget _buildTooltip(_ViolinGroup g) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: g.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 4, height: 48,
            decoration: BoxDecoration(color: g.color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${g.medium} / ${g.workload}',
                    style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  'Min: ${g.min.toInt()} ms  ·  Q1: ${g.q1.toInt()} ms  ·  Med: ${g.median.toInt()} ms  ·  Q3: ${g.q3.toInt()} ms  ·  Max: ${g.max.toInt()} ms',
                  style: GoogleFonts.firaCode(fontSize: 10, color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ViolinGroup {
  final String workload, medium;
  final List<double> latencies;
  final Color color, mediumColor;
  final double min, q1, median, q3, max;

  _ViolinGroup({
    required this.workload, required this.medium,
    required this.latencies, required this.color, required this.mediumColor,
    required this.min, required this.q1, required this.median, required this.q3, required this.max,
  });
}

class _ViolinPainter extends CustomPainter {
  final List<_ViolinGroup> groups;
  final double maxY;
  final int? hoveredIdx;
  final bool showMediumLabel;

  _ViolinPainter({required this.groups, required this.maxY, this.hoveredIdx, required this.showMediumLabel});

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 48.0;
    const bottomPad = 48.0;
    final chartW = size.width - leftPad;
    final chartH = size.height - bottomPad;
    final groupW = chartW / groups.length;
    final maxHalfW = groupW * 0.35;

    // Grid
    final gridP = Paint()..color = const Color(0x10FFFFFF)..strokeWidth = 1;
    for (int i = 1; i <= 5; i++) {
      final y = chartH * (1 - i / 5.0);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridP);
    }

    // Y labels
    for (int i = 0; i <= 5; i++) {
      final v = maxY * i / 5;
      final y = chartH * (1 - i / 5.0);
      final tp = TextPainter(
        text: TextSpan(text: v.toInt().toString(),
            style: const TextStyle(fontSize: 9, color: Color(0x50FFFFFF), fontFamily: 'monospace')),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 6, y - tp.height / 2));
    }

    // Y-axis name
    canvas.save();
    canvas.translate(12, chartH / 2);
    canvas.rotate(-math.pi / 2);
    final yLbl = TextPainter(
      text: const TextSpan(text: 'Latency (ms)',
          style: TextStyle(fontSize: 10, color: Color(0x60FFFFFF), fontFamily: 'monospace')),
      textDirection: TextDirection.ltr,
    )..layout();
    yLbl.paint(canvas, Offset(-yLbl.width / 2, 0));
    canvas.restore();

    // Borders
    final bP = Paint()..color = const Color(0x1AFFFFFF)..strokeWidth = 1;
    canvas.drawLine(Offset(leftPad, 0), Offset(leftPad, chartH), bP);
    canvas.drawLine(Offset(leftPad, chartH), Offset(size.width, chartH), bP);

    double yOf(double v) => chartH * (1 - v / maxY);

    for (int gi = 0; gi < groups.length; gi++) {
      final g = groups[gi];
      final xC = leftPad + groupW * (gi + 0.5);
      final isHov = gi == hoveredIdx;
      final a = isHov ? 1.0 : (hoveredIdx != null ? 0.3 : 0.8);

      // KDE
      final kde = _kde(g.latencies, 50);
      final peak = kde.fold<double>(0, (m, p) => math.max(m, p.$2));
      if (peak == 0) continue;

      // Violin path
      final path = Path();
      for (int i = 0; i < kde.length; i++) {
        final y = yOf(kde[i].$1);
        final hw = (kde[i].$2 / peak) * maxHalfW;
        if (i == 0) {
          path.moveTo(xC - hw, y);
        } else {
          path.lineTo(xC - hw, y);
        }
      }
      for (int i = kde.length - 1; i >= 0; i--) {
        path.lineTo(xC + (kde[i].$2 / peak) * maxHalfW, yOf(kde[i].$1));
      }
      path.close();

      canvas.drawPath(path, Paint()..color = g.color.withValues(alpha: 0.25 * a));
      canvas.drawPath(path, Paint()..color = g.color.withValues(alpha: 0.6 * a)..strokeWidth = 1.5..style = PaintingStyle.stroke);

      // Q1 / Q3 lines
      for (final qv in [g.q1, g.q3]) {
        final qw = _densAt(kde, qv, peak) * maxHalfW;
        canvas.drawLine(Offset(xC - qw, yOf(qv)), Offset(xC + qw, yOf(qv)),
            Paint()..color = Color.fromRGBO(255, 255, 255, 0.2 * a)..strokeWidth = 1);
      }

      // Median
      final mw = _densAt(kde, g.median, peak) * maxHalfW;
      canvas.drawLine(Offset(xC - mw, yOf(g.median)), Offset(xC + mw, yOf(g.median)),
          Paint()..color = Color.fromRGBO(255, 255, 255, 0.6 * a)..strokeWidth = 2);

      // X labels
      final wlTp = TextPainter(
        text: TextSpan(text: g.workload.substring(0, math.min(3, g.workload.length)),
            style: TextStyle(fontSize: 9, color: Color.fromRGBO(255, 255, 255, 0.3 * a), fontFamily: 'monospace')),
        textDirection: TextDirection.ltr,
      )..layout();
      wlTp.paint(canvas, Offset(xC - wlTp.width / 2, chartH + 6));

      if (showMediumLabel) {
        final mTp = TextPainter(
          text: TextSpan(text: g.medium.substring(0, math.min(4, g.medium.length)),
              style: TextStyle(fontSize: 7, color: g.mediumColor.withValues(alpha: 0.5 * a), fontFamily: 'monospace')),
          textDirection: TextDirection.ltr,
        )..layout();
        mTp.paint(canvas, Offset(xC - mTp.width / 2, chartH + 20));
      }
    }
  }

  List<(double, double)> _kde(List<double> data, int res) {
    if (data.isEmpty) return [];
    final lo = data.first, hi = data.last, range = hi - lo;
    final n = data.length;
    final std = _std(data);
    final h = std > 0 ? 1.06 * std * math.pow(n.toDouble(), -0.2) : range * 0.1;
    final start = lo - 2 * h;
    final step = (range + 4 * h) / res;
    final out = <(double, double)>[];
    for (int i = 0; i <= res; i++) {
      final x = start + step * i;
      if (x < 0) continue;
      double d = 0;
      for (final v in data) {
        final z = (x - v) / h;
        d += math.exp(-0.5 * z * z);
      }
      d /= (n * h * math.sqrt(2 * math.pi));
      out.add((x, d));
    }
    return out;
  }

  double _densAt(List<(double, double)> kde, double val, double peak) {
    if (kde.isEmpty || peak == 0) return 0;
    double best = 0, bestDist = double.infinity;
    for (final p in kde) {
      final d = (p.$1 - val).abs();
      if (d < bestDist) { bestDist = d; best = p.$2; }
    }
    return best / peak;
  }

  double _std(List<double> d) {
    if (d.length < 2) return 0;
    final m = d.reduce((a, b) => a + b) / d.length;
    return math.sqrt(d.map((v) => (v - m) * (v - m)).reduce((a, b) => a + b) / (d.length - 1));
  }

  @override
  bool shouldRepaint(covariant _ViolinPainter o) => hoveredIdx != o.hoveredIdx || groups.length != o.groups.length;
}

// ─── Chart 3: IPFS Integration Cost ─────────────────────────────────────────

class _IpfsCostChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final Color accent;

  const _IpfsCostChart({required this.data, required this.accent});

  @override
  Widget build(BuildContext context) {
    // Build slope lines
    final lineBars = <LineChartBarData>[];
    double maxY = 0;

    for (final d in data) {
      final medium = d['medium'] as String;
      final noIpfs = (d['no_ipfs'] as num).toDouble();
      final withIpfs = (d['with_ipfs'] as num).toDouble();
      final color = _mediumColor(medium);

      if (noIpfs > maxY) maxY = noIpfs;
      if (withIpfs > maxY) maxY = withIpfs;

      lineBars.add(LineChartBarData(
        spots: [FlSpot(0, noIpfs), FlSpot(1, withIpfs)],
        isCurved: false,
        color: color.withValues(alpha: 0.7),
        barWidth: 2,
        dotData: FlDotData(
          show: true,
          getDotPainter: (s, d, b, i) =>
              FlDotCirclePainter(radius: 5, color: color, strokeWidth: 1.5, strokeColor: Colors.white24),
        ),
        belowBarData: BarAreaData(show: false),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Row(
          children: [
            _legendDot(_kWiredColor, 'Wired'),
            const SizedBox(width: 16),
            _legendDot(_kWirelessColor, 'Wireless'),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 380,
          child: LineChart(
            LineChartData(
              minX: -0.15,
              maxX: 1.15,
              minY: 0,
              maxY: maxY * 1.15,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: Colors.white.withValues(alpha: 0.06),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  axisNameWidget: Text('Peak TPS',
                      style: GoogleFonts.firaCode(fontSize: 10, color: Colors.white38)),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (v, meta) => Text(
                      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toInt().toString(),
                      style: GoogleFonts.firaCode(fontSize: 10, color: Colors.white30),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (v, meta) {
                      if (v == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('No IPFS',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54)),
                        );
                      } else if (v == 1) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('With IPFS',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54)),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  left: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => const Color(0xFF1E1E2E),
                  getTooltipItems: (spots) => spots.map((s) {
                    final idx = lineBars.indexOf(s.bar);
                    if (idx >= 0 && idx < data.length) {
                      final d = data[idx];
                      final penalty = d['penalty_pct'] as num;
                      final workload = d['workload'] as String;
                      return LineTooltipItem(
                        '${d['medium']}/$workload\n${s.y.toStringAsFixed(0)} TPS (${penalty > 0 ? '+' : ''}${penalty.toStringAsFixed(1)}%)',
                        GoogleFonts.firaCode(fontSize: 11, color: Colors.white70),
                      );
                    }
                    return LineTooltipItem(
                      '${s.y.toStringAsFixed(0)} TPS',
                      GoogleFonts.firaCode(fontSize: 11, color: Colors.white70),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: lineBars,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Penalty summary table
        _IpfsPenaltyTable(data: data),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
      ],
    );
  }
}

class _IpfsPenaltyTable extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _IpfsPenaltyTable({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white.withValues(alpha: 0.03),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('Config',
                    style: GoogleFonts.firaCode(fontSize: 10, fontWeight: FontWeight.w700,
                        color: Colors.white38, letterSpacing: 0.8))),
                Expanded(child: Text('No IPFS',
                    style: GoogleFonts.firaCode(fontSize: 10, fontWeight: FontWeight.w700,
                        color: Colors.white38), textAlign: TextAlign.right)),
                Expanded(child: Text('w/ IPFS',
                    style: GoogleFonts.firaCode(fontSize: 10, fontWeight: FontWeight.w700,
                        color: Colors.white38), textAlign: TextAlign.right)),
                Expanded(child: Text('Penalty',
                    style: GoogleFonts.firaCode(fontSize: 10, fontWeight: FontWeight.w700,
                        color: Colors.white38), textAlign: TextAlign.right)),
              ],
            ),
          ),
          for (final d in data)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
              ),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text('${d['medium']}/${d['workload']}',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)))),
                  Expanded(child: Text((d['no_ipfs'] as num).toStringAsFixed(0),
                      style: GoogleFonts.firaCode(fontSize: 12, color: Colors.white70),
                      textAlign: TextAlign.right)),
                  Expanded(child: Text((d['with_ipfs'] as num).toStringAsFixed(0),
                      style: GoogleFonts.firaCode(fontSize: 12, color: Colors.white70),
                      textAlign: TextAlign.right)),
                  Expanded(child: Text('${(d['penalty_pct'] as num).toStringAsFixed(1)}%',
                      style: GoogleFonts.firaCode(fontSize: 12,
                          color: (d['penalty_pct'] as num) < -20
                              ? const Color(0xFFEF4444)
                              : Colors.white54),
                      textAlign: TextAlign.right)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ──────────────────────────────────────────────────────────

class _CustomChoiceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;
  final Color selectedColor;

  const _CustomChoiceChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
    required this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelected(!isSelected),
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? selectedColor.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? selectedColor.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(Icons.check_circle_rounded, size: 14, color: selectedColor),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? selectedColor : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  final List<String> options;
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onChanged;
  final Color accent;

  const _SegmentedToggle({
    required this.options,
    required this.labels,
    required this.selected,
    required this.onChanged,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.scaffoldBackgroundColor;
    
    Widget scrollView = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < options.length; i++) ...[
              _CustomChoiceChip(
                label: labels[i],
                isSelected: options[i] == selected,
                onSelected: (isSelected) => isSelected ? onChanged(options[i]) : null,
                selectedColor: accent,
              ),
              if (i < options.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) return scrollView;

        return SizedBox(
          width: double.infinity,
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [surfaceColor, surfaceColor, surfaceColor.withValues(alpha: 0.0)],
                stops: const [0.0, 0.85, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: scrollView,
          ),
        );
      },
    );
  }
}

class _MediumLegend extends StatelessWidget {
  final List<Map<String, dynamic>> series;

  const _MediumLegend({required this.series});

  @override
  Widget build(BuildContext context) {
    final mediums = <String>{};
    for (final s in series) {
      mediums.add(s['medium'] as String);
    }
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: mediums.map((m) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 14, height: 3,
              decoration: BoxDecoration(color: _mediumColor(m), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 6),
          Text(m, style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
        ],
      )).toList(),
    );
  }
}
