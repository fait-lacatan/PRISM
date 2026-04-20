import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

/// System Architecture experience with interactive flowchart, sequence diagram,
/// transaction pipelines, and distributed topology.
class SystemMapTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color accent;

  const SystemMapTemplate({super.key, required this.data, required this.accent});

  @override
  State<SystemMapTemplate> createState() => _SystemMapTemplateState();
}

class _SystemMapTemplateState extends State<SystemMapTemplate>
    with SingleTickerProviderStateMixin {
  static const _panel = Color(0xFF071428);
  static const _panelSoft = Color(0xFF0B1D34);
  static const _line = Color(0xFF1E3A5C);
  static const _input = Color(0xFF38BDF8);
  static const _process = Color(0xFFF97316);
  static const _output = Color(0xFF22C55E);

  late final AnimationController _orbitCtrl;

  // For flowchart / sequence tabs
  int _diagramTab = 0;
  String? _selectedFlowNode;
  int? _selectedSeqStep;

  // Legacy workflow
  String _activeWorkflowNode = 'entry';

  Map<String, dynamic> get _d => widget.data;
  List get _flowchartNodes => (_d['flowchart_nodes'] as List?) ?? const [];
  Map<String, dynamic>? get _seqDiagram => _d['sequence_diagram'] as Map<String, dynamic>?;
  List get _workflow => (_d['workflow'] as List?) ?? const [];
  List get _txPipelines => (_d['transaction_pipelines'] as List?) ?? const [];
  Map<String, dynamic> get _topology =>
      (_d['distributed_topology'] as Map<String, dynamic>?) ?? const {};

  bool get _hasNewDiagrams => _flowchartNodes.isNotEmpty || _seqDiagram != null;

  @override
  void initState() {
    super.initState();
    _orbitCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
  }

  @override
  void dispose() {
    _orbitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selFlowNode = _selectedFlowNode != null
        ? _flowchartNodes.firstWhere((n) => n['id'] == _selectedFlowNode, orElse: () => null)
        : null;

    final seqMessages = (_seqDiagram?['messages'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final selSeqMsg = _selectedSeqStep != null
        ? seqMessages.firstWhere((m) => m['step'] == _selectedSeqStep, orElse: () => <String, dynamic>{})
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasNewDiagrams) ...[
          _sectionTitle(title: 'System Workflow', subtitle: 'Tap any element to inspect details.', color: _input),
          const SizedBox(height: 14),
          _buildDiagramTabs(),
          const SizedBox(height: 16),
          if (_diagramTab == 0 && _flowchartNodes.isNotEmpty) ...[
            if (selFlowNode != null) ...[
              _buildInfoPanel(selFlowNode as Map<String, dynamic>),
              const SizedBox(height: 16),
            ],
            _FlowchartDiagram(
              nodes: _flowchartNodes,
              selectedId: _selectedFlowNode,
              onSelect: (id) => setState(() => _selectedFlowNode = _selectedFlowNode == id ? null : id),
            ),
          ],
          if (_diagramTab == 1 && _seqDiagram != null) ...[
            if (selSeqMsg != null && selSeqMsg.isNotEmpty) ...[
              _buildMsgInfo(selSeqMsg),
              const SizedBox(height: 16),
            ],
            _SequenceDiagram(
              data: _seqDiagram!,
              selectedStep: _selectedSeqStep,
              onSelectStep: (s) => setState(() => _selectedSeqStep = _selectedSeqStep == s ? null : s),
            ),
          ],
          const SizedBox(height: 36),
        ] else if (_workflow.isNotEmpty) ...[
          _sectionTitle(title: 'System Workflow', subtitle: 'Tap a shape to inspect the step and transition details.', color: _input),
          const SizedBox(height: 14),
          _buildLegacyWorkflow(),
          const SizedBox(height: 36),
        ],
        if (_txPipelines.isNotEmpty) ...[
          _sectionTitle(title: 'Transaction Pipelines', subtitle: 'Input -> Process -> Output cards for each operation mode.', color: _process),
          const SizedBox(height: 14),
          _buildTransactionPipelines(),
          const SizedBox(height: 36),
        ],
        if (_topology.isNotEmpty) ...[
          _sectionTitle(title: 'Distributed Topology', subtitle: 'Cluster consensus and sidecar storage in a ring.', color: _output),
          const SizedBox(height: 14),
          _buildTopology(),
        ],
      ],
    );
  }

  // ─── SHARED HELPERS ────────────────────
  Widget _sectionTitle({required String title, required String subtitle, required Color color}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 4),
      Text(subtitle, style: GoogleFonts.inter(fontSize: 14, color: Colors.white60)),
    ]);
  }

  Widget _buildDiagramTabs() {
    final tabs = <String>[];
    if (_flowchartNodes.isNotEmpty) tabs.add('Flowchart');
    if (_seqDiagram != null) tabs.add('Sequence Diagram');
    if (tabs.length <= 1) return const SizedBox.shrink();

    return Row(children: List.generate(tabs.length, (i) {
      final active = _diagramTab == i;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(color: Colors.transparent, child: InkWell(
          onTap: () => setState(() { _diagramTab = i; _selectedFlowNode = null; _selectedSeqStep = null; }),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: active ? _input : _input.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: active ? _input : _input.withValues(alpha: 0.3)),
            ),
            child: Text(tabs[i], style: GoogleFonts.spaceGrotesk(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: active ? const Color(0xFF071428) : _input,
            )),
          ),
        )),
      );
    }));
  }

  Widget _buildInfoPanel(Map<String, dynamic> node) {
    final type = (node['type'] as String?) ?? 'process';
    Color typeColor;
    switch (type) {
      case 'terminal': typeColor = const Color(0xFFA78BFA); break;
      case 'decision': typeColor = const Color(0xFFF59E0B); break;
      case 'storage': typeColor = const Color(0xFFF97316); break;
      default: typeColor = _input;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey(node['id']),
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1D34),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: typeColor.withValues(alpha: 0.4)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: typeColor, borderRadius: BorderRadius.circular(6)),
              child: Text(type.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF071428))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(
              (node['label'] as String? ?? '').replaceAll('\n', ' '),
              style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            )),
          ]),
          const SizedBox(height: 10),
          Text(node['desc'] as String? ?? '', style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, height: 1.6)),
        ]),
      ),
    );
  }

  Widget _buildMsgInfo(Map<String, dynamic> msg) {
    final isSolid = (msg['type'] as String?) == 'solid';
    final color = isSolid ? _input : const Color(0xFFA78BFA);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey(msg['step']),
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1D34),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              child: Center(child: Text('${msg['step']}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF071428)))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(
              msg['label'] as String? ?? '',
              style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            )),
          ]),
          const SizedBox(height: 6),
          Text('${msg['from']} → ${msg['to']}', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: color.withValues(alpha: 0.8))),
          const SizedBox(height: 8),
          Text(msg['desc'] as String? ?? '', style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, height: 1.6)),
        ]),
      ),
    );
  }

  // ─── LEGACY WORKFLOW (for chapters 11, 13) ────────
  Widget _buildLegacyWorkflow() {
    final active = _workflow.cast<Map>().firstWhere(
      (n) => (n['id'] as String?) == _activeWorkflowNode,
      orElse: () => _workflow.isNotEmpty ? _workflow.first as Map : <String, dynamic>{},
    );
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
      child: Column(children: [
        Wrap(spacing: 12, runSpacing: 12, children: _workflow.map<Widget>((raw) {
          final node = raw as Map<String, dynamic>;
          final id = node['id'] as String? ?? '';
          final isActive = id == _activeWorkflowNode;
          final type = (node['type'] as String? ?? 'process').toLowerCase();
          return GestureDetector(
            onTap: () => setState(() => _activeWorkflowNode = id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints: BoxConstraints(minWidth: type == 'decision' ? 160 : 150, minHeight: type == 'decision' ? 84 : 64),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Stack(alignment: Alignment.center, children: [
                Positioned.fill(child: CustomPaint(painter: _WorkflowNodeShapePainter(
                  type: type, borderColor: isActive ? _input : _line, fillColor: isActive ? _input.withValues(alpha: 0.15) : _panelSoft,
                ))),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(node['label'] as String? ?? '', textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: isActive ? _input : Colors.white)),
                  if ((node['type'] as String?) != null) ...[
                    const SizedBox(height: 4),
                    Text((node['type'] as String).toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white54, letterSpacing: 0.9)),
                  ],
                ])),
              ]),
            ),
          );
        }).toList()),
        const SizedBox(height: 14),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF04101E), borderRadius: BorderRadius.circular(12), border: Border.all(color: _line.withValues(alpha: 0.7))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(active['label'] as String? ?? 'Workflow Node', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 8),
            Text(active['desc'] as String? ?? '', style: GoogleFonts.inter(fontSize: 14, height: 1.6, color: Colors.white70)),
            if ((active['next'] as List?) != null && (active['next'] as List).isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Transitions: ${(active['next'] as List).join('  •  ')}', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: _input.withValues(alpha: 0.9))),
            ],
          ]),
        ),
      ]),
    ).animate().fadeIn(duration: 450.ms);
  }

  // ─── TRANSACTION PIPELINES (unchanged) ─────
  Widget _buildTransactionPipelines() {
    return Column(children: _txPipelines.map<Widget>((raw) {
      final pipe = raw as Map<String, dynamic>;
      return Padding(padding: const EdgeInsets.only(bottom: 14), child: _pipelineCard(pipe));
    }).toList());
  }

  Widget _pipelineCard(Map<String, dynamic> p) {
    final inItems = (p['inputs'] as List?)?.cast<String>() ?? const [];
    final procItems = (p['process'] as List?)?.cast<String>() ?? const [];
    final outItems = (p['outputs'] as List?)?.cast<String>() ?? const [];
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p['label'] as String? ?? 'Transaction', style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, constraints) {
          final narrow = constraints.maxWidth < 900;
          if (narrow) {
            return Column(children: [
              _lane('Input', inItems, _input, Icons.fingerprint_rounded),
              const SizedBox(height: 10),
              _lane('Process', procItems, _process, Icons.settings_suggest_rounded),
              const SizedBox(height: 10),
              _lane('Output', outItems, _output, Icons.task_alt_rounded),
            ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _lane('Input', inItems, _input, Icons.fingerprint_rounded)),
            _arrowGlyph(),
            Expanded(child: _lane('Process', procItems, _process, Icons.settings_suggest_rounded)),
            _arrowGlyph(),
            Expanded(child: _lane('Output', outItems, _output, Icons.task_alt_rounded)),
          ]);
        }),
      ]),
    ).animate().fadeIn(delay: 60.ms, duration: 350.ms).slideY(begin: 0.02);
  }

  Widget _lane(String title, List<String> items, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: color), const SizedBox(width: 8),
          Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 8),
        ...items.map((it) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 5, height: 5, margin: const EdgeInsets.only(top: 7), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(it, style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4))),
          ]),
        )),
      ]),
    );
  }

  Widget _arrowGlyph() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 28),
      child: Icon(Icons.arrow_forward_rounded, color: _input.withValues(alpha: 0.9), size: 28),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).moveX(begin: -2, end: 2, duration: 900.ms);
  }

  // ─── TOPOLOGY (unchanged) ──────────────
  Widget _buildTopology() {
    final nodes = (_topology['nodes'] as List?)?.cast<Map>() ?? const [];
    final note = _topology['note'] as String? ?? '';
    final triService = _topology['tri_service'] as String? ?? '';
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
      child: Column(children: [
        SizedBox(height: 360, child: LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          const h = 360.0;
          final center = Offset(w / 2, h / 2 - 8);
          final rx = math.min(w * 0.34, 220.0);
          final ry = math.min(h * 0.26, 130.0);
          return AnimatedBuilder(animation: _orbitCtrl, builder: (context, _) {
            final t = _orbitCtrl.value * 2 * math.pi;
            return CustomPaint(
              painter: _OrbitPainter(progress: t, line: _line, glow: _input, center: center, rx: rx, ry: ry),
              child: Stack(children: [
                Positioned.fill(child: Center(child: Transform.translate(offset: const Offset(0, -8), child: Container(
                  width: 92, height: 92,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _process.withValues(alpha: 0.12), border: Border.all(color: _process, width: 1.2)),
                  child: Center(child: Text('Ledger\nState', textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2))),
                )))),
                ...List.generate(nodes.length, (i) {
                  final node = nodes[i];
                  final angle = t + (2 * math.pi * i / math.max(1, nodes.length));
                  final x = center.dx + rx * math.cos(angle);
                  final y = center.dy + ry * math.sin(angle);
                  return Positioned(left: x - 48, top: y - 26, child: _miniNode(node['label'] as String? ?? 'Node', node['role'] as String? ?? ''));
                }),
              ]),
            );
          });
        })),
        if (note.isNotEmpty || triService.isNotEmpty)
          Container(
            width: double.infinity, margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF04101E), borderRadius: BorderRadius.circular(12), border: Border.all(color: _line.withValues(alpha: 0.7))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (note.isNotEmpty) Text(note, style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.5)),
              if (note.isNotEmpty && triService.isNotEmpty) const SizedBox(height: 10),
              if (triService.isNotEmpty) Text(triService, style: GoogleFonts.inter(fontSize: 13, color: _output.withValues(alpha: 0.9), height: 1.5, fontWeight: FontWeight.w600)),
            ]),
          ),
      ]),
    ).animate().fadeIn(duration: 450.ms);
  }

  Widget _miniNode(String label, String role) {
    return Container(
      width: 96, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(color: const Color(0xFF0B1D34), borderRadius: BorderRadius.circular(10), border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
        Text(role, style: GoogleFonts.inter(fontSize: 10, color: Colors.white54)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════
// FLOWCHART DIAGRAM
// ═══════════════════════════════════════════

class _FlowchartDiagram extends StatefulWidget {
  final List nodes;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _FlowchartDiagram({required this.nodes, this.selectedId, required this.onSelect});

  @override
  State<_FlowchartDiagram> createState() => _FlowchartDiagramState();
}

class _FlowchartDiagramState extends State<_FlowchartDiagram> with SingleTickerProviderStateMixin {
  static const _accent = Color(0xFF38BDF8);
  static const _line = Color(0xFF1E3A5C);
  static const _panel = Color(0xFF071428);

  late final AnimationController _flowCtrl;

  @override
  void initState() {
    super.initState();
    // 6-second loop over the entire flowchart
    _flowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  }

  @override
  void dispose() {
    _flowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine grid bounds and flow orders
    int maxCol = 0, maxRow = 0;
    final nodeMap = <String, Map<String, dynamic>>{};
    for (final raw in widget.nodes) {
      final n = raw as Map<String, dynamic>;
      final c = (n['col'] as int?) ?? 0;
      final r = (n['row'] as int?) ?? 0;
      if (c > maxCol) maxCol = c;
      if (r > maxRow) maxRow = r;
      nodeMap[n['id'] as String] = n;
    }

    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 650;
      // Adjust scale for desktop/mobile views
      final cellW = isNarrow ? 90.0 : 160.0;
      final cellH = isNarrow ? 70.0 : 100.0;
      final totalW = (maxCol + 1) * cellW;
      final totalH = (maxRow + 1) * cellH;

      // Build positioned nodes + arrows
      final nodeWidgets = <Widget>[];
      final arrowData = <_ArrowInfo>[];

      for (final raw in widget.nodes) {
        final n = raw as Map<String, dynamic>;
        final id = n['id'] as String;
        final col = (n['col'] as int?) ?? 0;
        final row = (n['row'] as int?) ?? 0;
        final type = (n['type'] as String?) ?? 'process';
        final label = (n['label'] as String?) ?? '';
        final isSelected = widget.selectedId == id;
        final x = col * cellW;
        final y = row * cellH;
        final w = isNarrow ? 80.0 : 140.0;
        final h = type == 'decision' ? (isNarrow ? 56.0 : 80.0) : (isNarrow ? 44.0 : 64.0);
        final cx = x + cellW / 2;
        final cy = y + cellH / 2;

        // Flow phase roughly correlates to row
        final highlightPhase = row / math.max(1, maxRow);

        // Collect arrow targets
        final nextList = (n['next'] as List?) ?? [];
        for (final edge in nextList) {
          final target = (edge is Map) ? edge['target'] as String : edge as String;
          final edgeLabel = (edge is Map) ? edge['label'] as String? : null;
          final tNode = nodeMap[target];
          if (tNode != null) {
            final tc = (tNode['col'] as int?) ?? 0;
            final tr = (tNode['row'] as int?) ?? 0;
            final th = tNode['type'] == 'decision' ? (isNarrow ? 56.0 : 80.0) : (isNarrow ? 44.0 : 64.0);
            final tw = isNarrow ? 80.0 : 140.0;
            final tcx = tc * cellW + cellW / 2;
            final tcy = tr * cellH + cellH / 2;
            
            Offset from = Offset(cx, cy + h / 2);
            Offset to = Offset(tcx, tcy - th / 2);
            String route = (edge is Map) ? edge['route'] as String? ?? 'step' : 'step';
            
            if (route == 'fail_left') {
              from = Offset(cx - w / 2, cy); // Out of the left tip
              to = Offset(tcx - tw / 2, tcy);  // Into the left edge of target
            } else if (route == 'over_down') {
              from = Offset(tc > col ? cx + w / 2 : cx - w / 2, cy);
            } else if (route == 'down_over') {
              to = Offset(tc > col ? tcx - tw / 2 : tcx + tw / 2, tcy);
            }

            arrowData.add(_ArrowInfo(
              from: from,
              to: to,
              label: edgeLabel,
              phaseStart: highlightPhase,
              phaseEnd: tr / math.max(1, maxRow),
              route: route,
            ));
          }
        }

        nodeWidgets.add(Positioned(
          left: x + (cellW - w) / 2,
          top: y + (cellH - h) / 2,
          width: w,
          height: h,
          child: GestureDetector(
            onTap: () => widget.onSelect(id),
            child: AnimatedBuilder(
              animation: _flowCtrl,
              builder: (context, child) {
                // Determine if this node should glow in the current sub-phase
                final t = _flowCtrl.value;
                // Gaussian pulse around node's phase
                final dist = math.min((t - highlightPhase).abs(), 1.0 - (t - highlightPhase).abs());
                final isHighlightMode = dist < 0.15 && widget.selectedId == null;
                
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: CustomPaint(
                    painter: _FlowchartNodePainter(
                      type: type, 
                      isSelected: isSelected || isHighlightMode,
                      accent: isHighlightMode ? _accent.withValues(alpha: 0.6) : _accent,
                    ),
                    child: Center(child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(label, textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(
                        fontSize: isNarrow ? 9 : 12, fontWeight: FontWeight.w700,
                        color: (isSelected || isHighlightMode) ? _accent : Colors.white,
                        height: 1.2,
                        letterSpacing: isNarrow ? -0.5 : 0,
                      )),
                    )),
                  ),
                );
              }
            ),
          ),
        ));
      }

      return Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth - 64),
            child: Center(
              child: SizedBox(
                width: totalW,
                height: totalH + 16,
                child: AnimatedBuilder(
                  animation: _flowCtrl,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _ArrowPainter(arrows: arrowData, color: _line, progress: widget.selectedId == null ? _flowCtrl.value : -1),
                      child: Stack(clipBehavior: Clip.none, children: nodeWidgets),
                    );
                  }
                ),
              ),
            ),
          ),
        ),
      ).animate().fadeIn(duration: 400.ms);
    });
  }
}

class _ArrowInfo {
  final Offset from;
  final Offset to;
  final String? label;
  final double phaseStart;
  final double phaseEnd;
  final String route;
  const _ArrowInfo({required this.from, required this.to, this.label, required this.phaseStart, required this.phaseEnd, required this.route});
}

class _ArrowPainter extends CustomPainter {
  final List<_ArrowInfo> arrows;
  final Color color;
  final double progress; // -1 means disabled/paused

  const _ArrowPainter({required this.arrows, required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final headPaint = Paint()..color = color..style = PaintingStyle.fill;
    final particlePaint = Paint()..color = const Color(0xFF38BDF8)..style = PaintingStyle.fill;

    // In order to correctly calculate proportional gutters, we need the raw width of a theoretical column.
    // cellW is implicitly 160 or 90 based on whether the device is narrow.
    // We can infer width safely by bounding or just providing a constant base.
    // Instead of passing cellW into ArrowPainter, we compute explicitly relative to absolute screen coords.
    // cellW was isNarrow ? 90.0 : 160.0. A safe heuristic mapping is relying on bounding values.
    
    for (final a in arrows) {
      // Create path
      final path = Path();
      Offset lastSegStart;
      switch (a.route) {
        case 'fail_left':
          // Col 0 center is at 0.5 * cellW. 
          // If a.from.dx is around 135 (col 1 x 90 + 45) -> cellW 90
          // If a.from.dx is around 240 (col 1 x 160 + 80) -> cellW 160
          // To get cellW safely we can reverse engineer: cx of col 1 is cellW * 1.5
          // Let's just use a hardcoded gutter delta:
          final cellW = a.from.dx > 150 ? 160.0 : 90.0;
          final leftX = cellW * 0.5; // Left gutter line
          path.moveTo(a.from.dx, a.from.dy);
          path.lineTo(leftX, a.from.dy);
          path.lineTo(leftX, a.to.dy);
          path.lineTo(a.to.dx, a.to.dy);
          lastSegStart = Offset(leftX, a.to.dy);
          break;
        case 'over_down':
          path.moveTo(a.from.dx, a.from.dy);
          path.lineTo(a.to.dx, a.from.dy);
          path.lineTo(a.to.dx, a.to.dy);
          lastSegStart = Offset(a.to.dx, a.from.dy);
          break;
        case 'down_over':
          path.moveTo(a.from.dx, a.from.dy);
          path.lineTo(a.from.dx, a.to.dy);
          path.lineTo(a.to.dx, a.to.dy);
          lastSegStart = Offset(a.from.dx, a.to.dy);
          break;
        case 'step':
        default:
          final dx = (a.to.dx - a.from.dx).abs();
          if (dx < 5) {
            path.moveTo(a.from.dx, a.from.dy);
            path.lineTo(a.to.dx, a.to.dy);
            lastSegStart = a.from;
          } else {
            final midY = (a.from.dy + a.to.dy) / 2;
            path.moveTo(a.from.dx, a.from.dy);
            path.lineTo(a.from.dx, midY);
            path.lineTo(a.to.dx, midY);
            path.lineTo(a.to.dx, a.to.dy);
            lastSegStart = Offset(a.to.dx, midY);
          }
          break;
      }
      canvas.drawPath(path, paint);

      // Arrowhead
      const hs = 6.0;
      final dir = (a.to - lastSegStart).direction;
      final tip = a.to;
      final p1 = Offset(tip.dx - hs * math.cos(dir - 0.4), tip.dy - hs * math.sin(dir - 0.4));
      final p2 = Offset(tip.dx - hs * math.cos(dir + 0.4), tip.dy - hs * math.sin(dir + 0.4));
      canvas.drawPath(Path()..moveTo(tip.dx, tip.dy)..lineTo(p1.dx, p1.dy)..lineTo(p2.dx, p2.dy)..close(), headPaint);

      // Edge label
      if (a.label != null && a.label!.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(text: a.label!.replaceAll('\n', ' '), style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
          textDirection: TextDirection.ltr,
        )..layout();
        
        Offset labelCenter;
        if (a.route == 'fail_left') {
          final cellW = a.from.dx > 150 ? 160.0 : 90.0;
          final leftX = cellW * 0.5;
          labelCenter = Offset((a.from.dx + leftX) / 2, a.from.dy - 8);
        } else if (a.route == 'over_down') {
          labelCenter = Offset((a.from.dx + a.to.dx) / 2, a.from.dy - 8);
        } else if (a.route == 'down_over') {
          labelCenter = Offset((a.from.dx + a.to.dx) / 2, a.to.dy - 8);
        } else {
          final dx = (a.to.dx - a.from.dx).abs();
          if (dx < 5) {
            labelCenter = Offset(a.from.dx + 12 + tp.width / 2, (a.from.dy + a.to.dy) / 2);
          } else {
            labelCenter = Offset((a.from.dx + a.to.dx) / 2, (a.from.dy + a.to.dy) / 2 - 8);
          }
        }
        
        // draw background wipe so the line doesn't strike through text
        final bgRect = Rect.fromCenter(center: labelCenter, width: tp.width + 10, height: tp.height + 4);
        canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(4)), Paint()..color = const Color(0xFF071428));
        tp.paint(canvas, Offset(labelCenter.dx - tp.width / 2, labelCenter.dy - tp.height / 2));
      }

      // Animated particle
      if (progress >= 0) {
        // Did the progress pass this arrow's phase?
        // Arrow starts at phaseStart and takes roughly 0.15 of the total animation time
        final dPhase = progress - a.phaseStart;
        if (dPhase > 0 && dPhase < 0.15) {
          final t = dPhase / 0.15;
          final metrics = path.computeMetrics().first;
          final pos = metrics.getTangentForOffset(metrics.length * t)?.position;
          if (pos != null) {
            canvas.drawCircle(pos, 3.5, particlePaint);
            canvas.drawCircle(pos, 6, particlePaint..color = const Color(0xFF38BDF8).withValues(alpha: 0.3));
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter old) => old.progress != progress;
}

class _FlowchartNodePainter extends CustomPainter {
  final String type;
  final bool isSelected;
  final Color accent;
  const _FlowchartNodePainter({required this.type, required this.isSelected, required this.accent});

  static const _line = Color(0xFF1E3A5C);
  static const _panelSoft = Color(0xFF0B1D34);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = isSelected ? accent.withValues(alpha: 0.15) : _panelSoft..style = PaintingStyle.fill;
    final stroke = Paint()..color = isSelected ? accent : _line..strokeWidth = isSelected ? 2.0 : 1.4..style = PaintingStyle.stroke;

    if (isSelected) {
      // Glow effect
      final glow = Paint()..color = accent.withValues(alpha: 0.2)..maskFilter = const MaskFilter.blur(BlurStyle.outer, 12);
      _drawShape(canvas, size, glow, type);
    }

    _drawShape(canvas, size, fill, type);
    _drawShape(canvas, size, stroke, type);
  }

  void _drawShape(Canvas canvas, Size size, Paint paint, String type) {
    switch (type) {
      case 'terminal':
        final r = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
        canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(size.height / 2)), paint);
        break;
      case 'decision':
        final path = Path()
          ..moveTo(size.width / 2, 1)
          ..lineTo(size.width - 1, size.height / 2)
          ..lineTo(size.width / 2, size.height - 1)
          ..lineTo(1, size.height / 2)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case 'storage':
        // Cylinder shape
        const curveH = 8.0;
        final path = Path()
          ..moveTo(1, curveH)
          ..cubicTo(1, 1, size.width - 1, 1, size.width - 1, curveH)
          ..lineTo(size.width - 1, size.height - curveH)
          ..cubicTo(size.width - 1, size.height - 1, 1, size.height - 1, 1, size.height - curveH)
          ..close();
        canvas.drawPath(path, paint);
        // Draw top ellipse again (extra)
        if (paint.style == PaintingStyle.stroke) {
          canvas.drawOval(Rect.fromLTWH(1, 1, size.width - 2, curveH * 2), paint);
        }
        break;
      default:
        final r = RRect.fromRectAndRadius(Rect.fromLTWH(1, 1, size.width - 2, size.height - 2), const Radius.circular(8));
        canvas.drawRRect(r, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _FlowchartNodePainter old) => old.type != type || old.isSelected != isSelected;
}

// ═══════════════════════════════════════════
// SEQUENCE DIAGRAM
// ═══════════════════════════════════════════

class _SequenceDiagram extends StatefulWidget {
  final Map<String, dynamic> data;
  final int? selectedStep;
  final ValueChanged<int> onSelectStep;

  const _SequenceDiagram({required this.data, this.selectedStep, required this.onSelectStep});

  @override
  State<_SequenceDiagram> createState() => _SequenceDiagramState();
}

class _SequenceDiagramState extends State<_SequenceDiagram> with SingleTickerProviderStateMixin {
  static const _panel = Color(0xFF071428);
  static const _line = Color(0xFF1E3A5C);
  static const _accent = Color(0xFF38BDF8);

  late final AnimationController _seqCtrl;

  @override
  void initState() {
    super.initState();
    // 8-second loop through the sequence
    _seqCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }

  @override
  void dispose() {
    _seqCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final participants = (widget.data['participants'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final messages = (widget.data['messages'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final groups = (widget.data['groups'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (participants.isEmpty) return const SizedBox.shrink();

    // Build participant index
    final pIndex = <String, int>{};
    for (var i = 0; i < participants.length; i++) {
      pIndex[participants[i]['id'] as String] = i;
    }

    // Build group map: participantId → group
    final pGroup = <String, Map<String, dynamic>>{};
    for (final g in groups) {
      final ids = (g['participantIds'] as List?)?.cast<String>() ?? [];
      for (final id in ids) {
        pGroup[id] = g;
      }
    }

    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 650;
      final colW = isNarrow ? 90.0 : 140.0;
      final totalW = participants.length * colW;
      final rowH = isNarrow ? 60.0 : 70.0;
      final headerH = 76.0;
      final bodyH = messages.length * rowH + 40; // extra padding for bottom scrolling
      final totalH = headerH + bodyH + headerH;

      return Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth - 64),
            child: Center(
              child: SizedBox(
                width: totalW,
                height: totalH,
                child: AnimatedBuilder(
                  animation: _seqCtrl,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _SeqDiagramPainter(
                        participants: participants, messages: messages, groups: groups,
                        pIndex: pIndex, pGroup: pGroup, colW: colW, rowH: rowH,
                        headerH: headerH, selectedStep: widget.selectedStep, totalWidth: totalW,
                        progress: widget.selectedStep == null ? _seqCtrl.value : -1,
                      ),
                      child: Stack(clipBehavior: Clip.none, children: [
                        // Participant headers (top)
                        ...List.generate(participants.length, (i) {
                          final p = participants[i];
                          final x = _participantX(i, participants.length, colW, totalW);
                          return Positioned(
                            left: x - (colW * 0.45),
                            top: 6,
                            width: colW * 0.9,
                            child: _participantBox(p, isNarrow),
                          );
                        }),
                        // Participant headers (bottom)
                        ...List.generate(participants.length, (i) {
                          final p = participants[i];
                          final x = _participantX(i, participants.length, colW, totalW);
                          return Positioned(
                            left: x - (colW * 0.45),
                            top: totalH - headerH + 6,
                            width: colW * 0.9,
                            child: _participantBox(p, isNarrow),
                          );
                        }),
                        // Step badges — tappable
                        ...messages.map((m) {
                          final step = m['step'] as int;
                          final fromIdx = pIndex[m['from']] ?? 0;
                          final toIdx = pIndex[m['to']] ?? 0;
                          final x1 = _participantX(fromIdx, participants.length, colW, totalW);
                          final y = headerH + (step - 1) * rowH + rowH / 2;

                          final t = _seqCtrl.value;
                          final totalSteps = messages.length;
                          final stepPhase = (step - 1) / math.max(1, totalSteps);
                          final dist = math.min((t - stepPhase).abs(), 1.0 - (t - stepPhase).abs());
                          final isHighlightMode = dist < (1.0 / totalSteps) * 0.6 && widget.selectedStep == null;

                          final isSelected = widget.selectedStep == step || isHighlightMode;
                          // Place badge near the "from" end
                          final badgeX = fromIdx < toIdx ? x1 + 14 : x1 - 14;
                          return Positioned(
                            left: badgeX - 12,
                            top: y - 12,
                            child: GestureDetector(
                              onTap: () => widget.onSelectStep(step),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? _accent : const Color(0xFF3B3B4F),
                                  border: Border.all(color: isSelected ? _accent : const Color(0xFF6B7280), width: 1.5),
                                  boxShadow: isSelected ? [BoxShadow(color: _accent.withValues(alpha: 0.4), blurRadius: 10)] : [],
                                ),
                                child: Center(child: Text('$step', style: GoogleFonts.inter(
                                  fontSize: 10, fontWeight: FontWeight.w700,
                                  color: isSelected ? const Color(0xFF071428) : Colors.white,
                                ))),
                              ),
                            ),
                          );
                        }),
                      ]),
                    );
                  }
                ),
              ),
            ),
          ),
        ),
      ).animate().fadeIn(duration: 400.ms);
    });
  }

  double _participantX(int index, int total, double colW, double totalW) {
    final usable = totalW;
    final spacing = usable / (total);
    return spacing * index + spacing / 2;
  }

  Widget _participantBox(Map<String, dynamic> p, bool isNarrow) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1D34),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Text(
        (p['label'] as String? ?? '').replaceAll('\n', '\n'),
        textAlign: TextAlign.center,
        style: GoogleFonts.spaceGrotesk(fontSize: isNarrow ? 9 : 11, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
      ),
    );
  }
}

class _SeqDiagramPainter extends CustomPainter {
  final List<Map<String, dynamic>> participants;
  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> groups;
  final Map<String, int> pIndex;
  final Map<String, Map<String, dynamic>> pGroup;
  final double colW, rowH, headerH, totalWidth;
  final int? selectedStep;
  final double progress; // -1 means no animation

  const _SeqDiagramPainter({
    required this.participants, required this.messages, required this.groups,
    required this.pIndex, required this.pGroup, required this.colW,
    required this.rowH, required this.headerH, required this.selectedStep,
    required this.totalWidth, required this.progress,
  });

  double _px(int idx) {
    final spacing = totalWidth / participants.length;
    return spacing * idx + spacing / 2;
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF38BDF8);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bodyTop = headerH;
    final bodyBot = size.height - headerH;

    // Draw group backgrounds
    for (final g in groups) {
      final ids = (g['participantIds'] as List?)?.cast<String>() ?? [];
      if (ids.isEmpty) continue;
      final indices = ids.map((id) => pIndex[id] ?? 0).toList()..sort();
      final gColor = _parseColor(g['color'] as String? ?? '#6366F1');
      final x1 = _px(indices.first) - colW * 0.5;
      final x2 = _px(indices.last) + colW * 0.5;
      final rect = Rect.fromLTRB(x1, 0, x2, size.height);
      canvas.drawRect(rect, Paint()..color = gColor.withValues(alpha: 0.04));
      // Group label
      final tp = TextPainter(
        text: TextSpan(text: g['label'] as String? ?? '', style: TextStyle(color: gColor.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((x1 + x2) / 2 - tp.width / 2, bodyTop - 14));
    }

    // Draw lifelines
    final lifePaint = Paint()
      ..color = const Color(0xFF1E3A5C).withValues(alpha: 0.5)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const dashLen = 6.0;
    for (var i = 0; i < participants.length; i++) {
      final x = _px(i);
      var y = bodyTop;
      while (y < bodyBot) {
        canvas.drawLine(Offset(x, y), Offset(x, math.min(y + dashLen, bodyBot)), lifePaint);
        y += dashLen * 2;
      }
    }

    // Draw message arrows
    for (final m in messages) {
      final step = m['step'] as int;
      final fromIdx = pIndex[m['from']] ?? 0;
      final toIdx = pIndex[m['to']] ?? 0;
      final y = bodyTop + (step - 1) * rowH + rowH / 2;
      final x1 = _px(fromIdx);
      final x2 = _px(toIdx);
      final isSolid = (m['type'] as String?) == 'solid';

      // Animation phase logic
      final stepPhase = (step - 1) / math.max(1, messages.length);
      final dist = math.min((progress - stepPhase).abs(), 1.0 - (progress - stepPhase).abs());
      final isHighlightMode = progress >= 0 && selectedStep == null && dist < (1.0 / messages.length) * 0.6;
      final isSelected = selectedStep == step || isHighlightMode;

      final arrowColor = isSelected
          ? const Color(0xFF38BDF8)
          : (isSolid ? Colors.white.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.35));

      final arrowPaint = Paint()
        ..color = arrowColor
        ..strokeWidth = isSelected ? 2.0 : 1.2
        ..style = PaintingStyle.stroke;

      if (isSolid) {
        canvas.drawLine(Offset(x1, y), Offset(x2, y), arrowPaint);
      } else {
        // Dashed
        final totalDist = (x2 - x1).abs();
        final dir = x2 > x1 ? 1.0 : -1.0;
        var cx = x1;
        while ((cx - x1).abs() < totalDist) {
          final end = cx + dir * dashLen;
          canvas.drawLine(Offset(cx, y), Offset(end.clamp(math.min(x1, x2).toDouble(), math.max(x1, x2).toDouble()), y), arrowPaint);
          cx += dir * dashLen * 2;
        }
      }

      // Arrowhead
      const hs = 7.0;
      final tipX = x2;
      final dir2 = x2 > x1 ? 1.0 : -1.0;
      final headPaint = Paint()..color = arrowColor..style = PaintingStyle.fill;
      final headPath = Path()
        ..moveTo(tipX, y)
        ..lineTo(tipX - dir2 * hs, y - hs * 0.45)
        ..lineTo(tipX - dir2 * hs, y + hs * 0.45)
        ..close();
      canvas.drawPath(headPath, headPaint);

      // Message label
      final label = m['label'] as String? ?? '';
      if (label.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(text: label, style: TextStyle(
            color: isSelected ? const Color(0xFF38BDF8) : Colors.white.withValues(alpha: 0.7),
            fontSize: 10, fontFamily: 'Inter',
          )),
          textDirection: TextDirection.ltr,
        )..layout();
        final labelX = (x1 + x2) / 2 - tp.width / 2;
        tp.paint(canvas, Offset(labelX, y - 16));
      }

      // Animated particle traversing arrow
      if (progress >= 0 && isHighlightMode) {
        // sub-phase from 0.0 to 1.0 mapping the duration of this specific step
        final dPhase = (progress - stepPhase);
        // Normalize against the ~0.6 window length we allocated
        final t = (dPhase / ((1.0 / messages.length) * 0.6)).clamp(0.0, 1.0);
        
        final pX = x1 + (x2 - x1) * t;
        final particlePaint = Paint()..color = const Color(0xFF38BDF8)..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(pX, y), 3.5, particlePaint);
        canvas.drawCircle(Offset(pX, y), 8, particlePaint..color = const Color(0xFF38BDF8).withValues(alpha: 0.3));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SeqDiagramPainter old) =>
      old.selectedStep != selectedStep || old.progress != progress;
}

// ═══════════════════════════════════════════
// LEGACY PAINTERS
// ═══════════════════════════════════════════

class _WorkflowNodeShapePainter extends CustomPainter {
  final String type;
  final Color borderColor;
  final Color fillColor;
  const _WorkflowNodeShapePainter({required this.type, required this.borderColor, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = fillColor..style = PaintingStyle.fill;
    final stroke = Paint()..color = borderColor..strokeWidth = 1.4..style = PaintingStyle.stroke;
    switch (type) {
      case 'input': case 'output': case 'start': case 'end':
        final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
        canvas.drawOval(rect, fill);
        canvas.drawOval(rect, stroke);
        break;
      case 'decision':
        final path = Path()..moveTo(size.width / 2, 1)..lineTo(size.width - 1, size.height / 2)..lineTo(size.width / 2, size.height - 1)..lineTo(1, size.height / 2)..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
        break;
      default:
        final rect = RRect.fromRectAndRadius(Rect.fromLTWH(1, 1, size.width - 2, size.height - 2), const Radius.circular(6));
        canvas.drawRRect(rect, fill);
        canvas.drawRRect(rect, stroke);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _WorkflowNodeShapePainter old) =>
      old.type != type || old.borderColor != borderColor || old.fillColor != fillColor;
}

class _OrbitPainter extends CustomPainter {
  final double progress;
  final Color line;
  final Color glow;
  final Offset center;
  final double rx;
  final double ry;
  const _OrbitPainter({required this.progress, required this.line, required this.glow, required this.center, required this.rx, required this.ry});

  @override
  void paint(Canvas canvas, Size size) {
    final orbit = Rect.fromCenter(center: center, width: rx * 2, height: ry * 2);
    canvas.drawOval(orbit, Paint()..color = line..style = PaintingStyle.stroke..strokeWidth = 1.2);
    final pulse = Paint()..color = glow.withValues(alpha: 0.45)..style = PaintingStyle.fill;
    for (var i = 0; i < 4; i++) {
      final a = progress + (2 * math.pi * i / 4);
      canvas.drawCircle(Offset(center.dx + rx * math.cos(a), center.dy + ry * math.sin(a)), 3, pulse);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) => old.progress != progress;
}
