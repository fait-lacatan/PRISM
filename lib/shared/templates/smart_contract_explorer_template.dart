import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Smart Contracts & Security stage — contract tabs, function cards,
/// RBAC matrix, 22-guard filterable grid.
class SmartContractExplorerTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color accent;
  const SmartContractExplorerTemplate({super.key, required this.data, required this.accent});

  @override
  State<SmartContractExplorerTemplate> createState() => _SmartContractExplorerTemplateState();
}

class _SmartContractExplorerTemplateState extends State<SmartContractExplorerTemplate> {
  static const _blue = Color(0xFF38BDF8);
  static const _violet = Color(0xFFA78BFA);
  static const _green = Color(0xFF22C55E);
  static const _orange = Color(0xFFE97316);
  static const _yellow = Color(0xFFFBBF24);

  int _selectedContract = 0;
  String _guardFilter = 'all';
  final Set<String> _expandedFns = {};
  final Set<String> _expandedGuards = {};

  Map<String, dynamic> get _d => widget.data;
  List get _contracts => (_d['contracts'] as List?) ?? [];
  List get _guards => (_d['guard_vectors'] as List?) ?? [];
  List get _guardCats => (_d['guard_categories'] as List?) ?? [];

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return _blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildContractSection(),
        const SizedBox(height: 40),
        _buildGuardSection(),
      ],
    );
  }

  // ─── CONTRACT SECTION ────────────────────
  Widget _buildContractSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ON-CHAIN GOVERNANCE', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _violet, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        Text('Three Solidity contracts form the governance layer. Tap functions to expand guard conditions.',
            style: GoogleFonts.inter(
              fontSize: 14, 
              color: Colors.white.withValues(alpha: 0.5)
            )),
        const SizedBox(height: 16),

        // Contract tabs
        LayoutBuilder(
          builder: (context, constraints) {
            final theme = Theme.of(context);
            final surfaceColor = theme.scaffoldBackgroundColor;
            
            Widget scrollView = SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_contracts.length, (i) {
                    final c = _contracts[i] as Map<String, dynamic>;
                    final color = _parseColor(c['color'] ?? '#38BDF8');
                    return Padding(
                      padding: EdgeInsets.only(right: i < _contracts.length - 1 ? 8.0 : 0),
                      child: _CustomChoiceChip(
                        label: c['label'] ?? '',
                        isSelected: _selectedContract == i,
                        onSelected: (selected) {
                          if (selected) setState(() { _selectedContract = i; _expandedFns.clear(); });
                        },
                        selectedColor: color,
                      ),
                    );
                  }),
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

        // Contract detail
        if (_contracts.isNotEmpty) _buildContractDetail(_contracts[_selectedContract] as Map<String, dynamic>),
      ],
    );
  }

  Widget _buildContractDetail(Map<String, dynamic> contract) {
    final color = _parseColor(contract['color'] ?? '#38BDF8');
    final functions = (contract['functions'] as List?) ?? [];
    final dataStructures = (contract['data_structures'] as List?) ?? [];
    final rbac = contract['rbac_matrix'] as Map<String, dynamic>?;
    final stateMachine = (contract['state_machine'] as List?) ?? [];
    final eventNote = contract['event_design_note'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description
        Text(contract['desc'] ?? '', 
            style: GoogleFonts.inter(
              fontSize: 14, 
              color: Colors.white70, 
              height: 1.6
            )),
        const SizedBox(height: 16),

        // Data structures
        if (dataStructures.isNotEmpty) ...[
          Text('DATA STRUCTURES', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.6), letterSpacing: 0.6)),
          const SizedBox(height: 8),
          ...dataStructures.map((ds) {
            final d = ds as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Text(d['name'] ?? '', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: _yellow)),
                const SizedBox(width: 8),
                Text('→', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.2))),
                const SizedBox(width: 8),
                Expanded(child: Text(d['type'] ?? '', style: GoogleFonts.inter(
                  fontSize: 12, 
                  color: Colors.white.withValues(alpha: 0.5)
                ))),
              ]),
            );
          }),
          const SizedBox(height: 16),
        ],

        // Functions
        Text('FUNCTIONS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.6), letterSpacing: 0.6)),
        const SizedBox(height: 8),
        ...List.generate(functions.length, (i) {
          final fn = functions[i] as Map<String, dynamic>;
          final sig = fn['sig'] ?? '';
          final isExpanded = _expandedFns.contains(sig);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() {
                  if (isExpanded) { _expandedFns.remove(sig); } else { _expandedFns.add(sig); }
                }),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(left: BorderSide(
                      color: isExpanded ? color : Theme.of(context).colorScheme.outlineVariant, 
                      width: 2
                    )),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(sig, style: GoogleFonts.jetBrainsMono(fontSize: 12, color: _yellow)),
                    if (fn['algo'] != null && fn['algo'] != '—')
                      Text(fn['algo'], style: GoogleFonts.inter(fontSize: 11, color: color)),
                    if (isExpanded) ...[
                      const SizedBox(height: 8),
                      Container(height: 1, color: const Color(0xFF1a2d42)),
                      const SizedBox(height: 8),
                      ...((fn['guards'] as List?) ?? []).map((g) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Require: ', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _orange)),
                          Expanded(child: Text(g.toString(), style: GoogleFonts.inter(
                            fontSize: 12, 
                            color: Colors.white70
                          ))),
                        ]),
                      )),
                      const SizedBox(height: 4),
                      Text(fn['effects'] ?? '', style: GoogleFonts.inter(
                        fontSize: 12, 
                        color: Colors.white.withValues(alpha: 0.8), 
                        height: 1.5
                      )),
                    ],
                  ]),
                ),
              ),
            ),
          );
        }),

        // RBAC Matrix
        if (rbac != null) ...[
          const SizedBox(height: 20),
          _buildRBACMatrix(rbac, color),
        ],

        // State machine
        if (stateMachine.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('STATE MACHINE', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.6), letterSpacing: 0.6)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 6,
            children: List.generate(stateMachine.length, (i) {
              final state = stateMachine[i].toString();
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.3))),
                  child: Text(state, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                ),
                if (i < stateMachine.length - 1) Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text('→', style: TextStyle(fontSize: 14, color: color.withValues(alpha: 0.4))),
                ),
              ]);
            }),
          ),
        ],

        // Event design note
        if (eventNote != null && eventNote.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest, 
              borderRadius: BorderRadius.circular(10)
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 14, color: _green.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Expanded(child: Text(eventNote, style: GoogleFonts.inter(
                fontSize: 12, 
                color: Colors.white60, 
                height: 1.5
              ))),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _buildRBACMatrix(Map<String, dynamic> rbac, Color color) {
    final columns = (rbac['columns'] as List?) ?? [];
    final rows = (rbac['rows'] as List?) ?? [];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('CAPABILITY MATRIX', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.6), letterSpacing: 0.6)),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 36,
          dataRowMinHeight: 32,
          dataRowMaxHeight: 40,
          columnSpacing: 12,
          horizontalMargin: 8,
          headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainer),
          columns: [
            DataColumn(label: Text('Role', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _orange))),
            ...columns.map((c) => DataColumn(label: Text(c.toString(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _blue)))),
          ],
          rows: rows.map((r) {
            final row = r as Map<String, dynamic>;
            final values = (row['values'] as List?) ?? [];
            return DataRow(cells: [
              DataCell(Text(row['role'] ?? '', style: GoogleFonts.inter(
                fontSize: 11, 
                fontWeight: FontWeight.w700, 
                color: Colors.white
              ))),
              ...values.map((v) {
                final val = v.toString();
                final isCheck = val.contains('✓');
                final isDenied = val.contains('✗') || val.contains('Denied');
                return DataCell(Text(val, style: GoogleFonts.inter(
                  fontSize: 10,
                  color: isCheck 
                      ? _yellow 
                      : isDenied 
                          ? Colors.white.withValues(alpha: 0.2) 
                          : Colors.white.withValues(alpha: 0.55),
                  fontWeight: isCheck ? FontWeight.w700 : FontWeight.w400,
                )));
              }),
            ]);
          }).toList(),
        ),
      ),
    ]);
  }

  // ─── GUARD VECTORS ────────────────────
  Widget _buildGuardSection() {
    final filtered = _guardFilter == 'all'
        ? _guards
        : _guards.where((g) => (g as Map<String, dynamic>)['cat'] == _guardFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('GUARD VECTORS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _orange, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        Text('All 22 tested against live deployed contracts: 22/22 EVM reverts confirmed. Filter by category.',
            style: GoogleFonts.inter(
              fontSize: 14, 
              color: Colors.white.withValues(alpha: 0.5)
            )),
        const SizedBox(height: 12),

        // Filter chips
        LayoutBuilder(
          builder: (context, constraints) {
            final theme = Theme.of(context);
            final surfaceColor = theme.scaffoldBackgroundColor;
            
            Widget scrollView = SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CustomChoiceChip(
                      label: 'All',
                      isSelected: _guardFilter == 'all',
                      onSelected: (v) => v ? setState(() { _guardFilter = 'all'; _expandedGuards.clear(); }) : null,
                      selectedColor: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    ..._guardCats.asMap().entries.map((e) {
                      final i = e.key;
                      final cat = e.value as Map<String, dynamic>;
                      final color = _parseColor(cat['color'] ?? '#38BDF8');
                      return Padding(
                        padding: EdgeInsets.only(right: i < _guardCats.length - 1 ? 8.0 : 0),
                        child: _CustomChoiceChip(
                          label: cat['label'] ?? '',
                          isSelected: _guardFilter == cat['id'],
                          onSelected: (v) => v ? setState(() { _guardFilter = cat['id']; _expandedGuards.clear(); }) : null,
                          selectedColor: color,
                        ),
                      );
                    }),
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

        // Guard cards
        ...filtered.map((g) {
          final guard = g as Map<String, dynamic>;
          final id = guard['id'] ?? '';
          final cat = guard['cat'] ?? '';
          final isExpanded = _expandedGuards.contains(id);
          final catColor = _getCatColor(cat);

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() {
                  if (isExpanded) { _expandedGuards.remove(id); } else { _expandedGuards.add(id); }
                }),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(left: BorderSide(color: catColor, width: 3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(id, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: catColor)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(guard['name'] ?? '', style: GoogleFonts.inter(
                        fontSize: 12, 
                        fontWeight: FontWeight.w700, 
                        color: Colors.white
                      ))),
                    ]),
                    Text(guard['contract'] ?? '', style: GoogleFonts.inter(
                      fontSize: 11, 
                      color: Colors.white.withValues(alpha: 0.3)
                    )),
                    if (isExpanded) ...[
                      const SizedBox(height: 8),
                      Container(height: 1, color: const Color(0xFF1a2d42)),
                      const SizedBox(height: 8),
                      Text(guard['detail'] ?? '', style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, height: 1.5)),
                    ],
                  ]),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }


  Color _getCatColor(String cat) {
    switch (cat) {
      case 'rbac': return _blue;
      case 'nonce': return _violet;
      case 'signature': return _orange;
      case 'lifecycle': return _yellow;
      case 'storage': return _yellow;
      default: return _blue;
    }
  }
}

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
