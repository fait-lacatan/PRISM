import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/data/narrative_repository.dart';
import '../../../core/models/chapter_data.dart';
import '../../../shared/templates/hero_stat_template.dart';
import '../../../shared/templates/card_stack_template.dart';
import '../../../shared/templates/comparison_grid_template.dart';
import '../../../shared/templates/bar_ranking_template.dart';
import '../../../shared/templates/flow_diagram_template.dart';
import '../../../shared/templates/detail_reveal_template.dart';
import '../../../shared/templates/markdown_prose_template.dart';
import '../../../shared/templates/region_map_template.dart';
import '../../../shared/templates/filterable_card_grid_template.dart';
import '../../../shared/templates/attack_scenario_stepper_template.dart';
import '../../../shared/templates/solution_matrix_template.dart';
import '../../../shared/templates/biometric_accordion_template.dart';
import '../../../shared/templates/fusion_pipeline_template.dart';
import '../../../shared/templates/privacy_explainer_template.dart';
import '../../../shared/templates/blockchain_table_template.dart';
import '../../../shared/templates/limitation_list_template.dart';

import '../../../shared/templates/objectives_template.dart';
import '../../../shared/templates/hypothesis_framework_template.dart';
import '../../../shared/templates/foundational_theories_template.dart';
import '../../../shared/templates/system_map_template.dart';
import '../../../shared/templates/smart_contract_explorer_template.dart';
import '../../../shared/templates/transaction_flow_template.dart';
import '../../../shared/templates/prototype_explorer_template.dart';
import '../../../shared/templates/hardware_components_template.dart';
import '../../../shared/templates/network_topology_template.dart';
import '../../../shared/templates/resource_allocation_template.dart';
import '../../../shared/templates/key_hierarchy_template.dart';
import '../../../shared/templates/device_binding_template.dart';
import '../../../shared/templates/zero_knowledge_storage_template.dart';
import '../../../shared/templates/access_matrix_template.dart';
import '../../../shared/templates/audit_trail_template.dart';
import '../../../shared/templates/metadata_policy_template.dart';
import '../../../shared/templates/threat_landscape_template.dart';
import '../../../shared/templates/attack_vectors_template.dart';
import '../../../shared/templates/temporal_analysis_template.dart';
import '../../../shared/templates/blockchain_guards_template.dart';
import '../../../shared/templates/data_table_template.dart';
import '../../../shared/templates/summary_capstone_template.dart';
import '../../../shared/templates/benchmark_chart_template.dart';

/// Dynamically composes a chapter's UI from its JSON-defined sections.
class ChapterRenderer extends ConsumerWidget {
  final String jsonFile;
  final int chapterIndex;
  final Color accentColor;

  const ChapterRenderer({
    super.key,
    required this.jsonFile,
    this.chapterIndex = 0,
    this.accentColor = const Color(0xFF3B82F6),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(chapterDataProvider(jsonFile));
    final isNarrow = MediaQuery.of(context).size.width < 700;

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text('Error loading chapter: $err',
            style: const TextStyle(color: Colors.white54)),
      ),
      data: (chapterData) {
        final accent = _parseColor(chapterData.accentColor) ?? accentColor;
        final hPad = isNarrow ? 24.0 : 64.0;

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(hPad, 48, hPad, 120),
          // +1 for the title header
          itemCount: chapterData.sections.length + 1,
          itemBuilder: (context, i) {
            // First item = chapter title header
            if (i == 0) {
              return Padding(
                padding: EdgeInsets.only(bottom: isNarrow ? 32 : 64),
                child: _buildTitleHeader(context, chapterData, accent),
              );
            }

            final section = chapterData.sections[i - 1];
            return Padding(
              padding: EdgeInsets.only(bottom: isNarrow ? 40 : 80),
              child: _buildTemplate(section, accent, isNarrow),
            );
          },
        );
      },
    );
  }

  Widget _buildTitleHeader(BuildContext context, ChapterData data, Color accent) {
    final isPhone = MediaQuery.of(context).size.width < 500;
    // Derive label from id: 'chap_01' → strip prefix, but we use title instead
    // for a meaningful label like "SOCIETAL PROBLEM"
    final idLabel = data.id
        .replaceAll(RegExp(r'^chap_\d+$'), '')
        .replaceAll('_', ' ')
        .toUpperCase()
        .trim();
    final label = idLabel.isNotEmpty ? idLabel : data.title.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.firaCode(
            fontSize: isPhone ? 10 : 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFE97316), // orange accent
            letterSpacing: 2,
          ),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 16),
        Text(
          data.title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: isPhone ? 28 : 48,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -1.5,
            height: 1.1,
          ),
        ).animate().fadeIn(delay: 100.ms, duration: 500.ms).slideY(begin: 0.08),
        if (data.subtitle.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            data.subtitle,
            style: GoogleFonts.inter(
              fontSize: isPhone ? 14 : 18,
              fontWeight: FontWeight.w400,
              color: Colors.white38,
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
        ],
        const SizedBox(height: 12),
        Container(
          width: 80,
          height: 4,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFE97316), Color(0xFF8F00FF)]),
            borderRadius: BorderRadius.circular(2),
          ),
        ).animate().fadeIn(delay: 300.ms).scaleX(begin: 0, alignment: Alignment.centerLeft),
      ],
    );
  }

  Widget _buildTemplate(ChapterSection section, Color accent, bool isNarrow) {
    switch (section.template) {
      case 'hero_stat':
        return HeroStatTemplate(data: section.data, accent: accent, isNarrow: isNarrow);
      case 'card_stack':
        return CardStackTemplate(data: section.data, accent: accent);
      case 'comparison_grid':
        return ComparisonGridTemplate(data: section.data, accent: accent);
      case 'bar_ranking':
        return BarRankingTemplate(data: section.data, accent: accent);
      case 'flow_diagram':
        return FlowDiagramTemplate(data: section.data, accent: accent);
      case 'detail_reveal':
        return DetailRevealTemplate(data: section.data, accent: accent);
      case 'markdown_prose':
        return MarkdownProseTemplate(data: section.data, accent: accent);
      case 'region_map':
        return RegionMapTemplate(data: section.data, accent: accent);
      case 'filterable_card_grid':
        return FilterableCardGridTemplate(data: section.data, accent: accent);
      case 'attack_scenario_stepper':
        return AttackScenarioStepperTemplate(data: section.data, accent: accent);
      case 'solution_matrix':
        return SolutionMatrixTemplate(data: section.data, accent: accent);
      case 'biometric_accordion':
        return BiometricAccordionTemplate(data: section.data, accent: accent);
      case 'fusion_pipeline':
        return FusionPipelineTemplate(data: section.data, accent: accent);
      case 'privacy_explainer':
        return PrivacyExplainerTemplate(data: section.data, accent: accent);
      case 'blockchain_table':
        return BlockchainTableTemplate(data: section.data, accent: accent);
      case 'limitation_list':
        return LimitationListTemplate(data: section.data, accent: accent);

      case 'objectives':
        return ObjectivesTemplate(data: section.data, accent: accent);
      case 'hypothesis_framework':
        return HypothesisFrameworkTemplate(data: section.data, accent: accent);
      case 'foundational_theories':
        return FoundationalTheoriesTemplate(data: section.data, accent: accent);
      case 'system_map':
        return SystemMapTemplate(data: section.data, accent: accent);
      case 'smart_contract_explorer':
        return SmartContractExplorerTemplate(data: section.data, accent: accent);
      case 'transaction_flow':
        return TransactionFlowTemplate(data: section.data, accent: accent);
      case 'prototype_explorer':
        return PrototypeExplorerTemplate(data: section.data);
      case 'hardware_components':
        return HardwareComponentsTemplate(data: section.data);
      case 'network_topology':
        return NetworkTopologyTemplate(data: section.data);
      case 'resource_allocation':
        return ResourceAllocationTemplate(data: section.data);
      case 'key_hierarchy':
        return KeyHierarchyTemplate(data: section.data);
      case 'device_binding':
        return DeviceBindingTemplate(data: section.data);
      case 'zero_knowledge_storage':
        return ZeroKnowledgeStorageTemplate(data: section.data);
      case 'access_matrix':
        return AccessMatrixTemplate(data: section.data);
      case 'audit_trail':
        return AuditTrailTemplate(data: section.data);
      case 'metadata_policy':
        return MetadataPolicyTemplate(data: section.data);
      case 'threat_landscape':
        return ThreatLandscapeTemplate(data: section.data);
      case 'attack_vectors':
        return AttackVectorsTemplate(data: section.data);
      case 'temporal_analysis':
        return TemporalAnalysisTemplate(data: section.data);
      case 'blockchain_guards':
        return BlockchainGuardsTemplate(data: section.data);
      case 'data_table':
        return DataTableTemplate(data: section.data, accent: accent);
      case 'summary_capstone':
        return SummaryCapstoneTemplate(data: section.data, accent: accent);
      case 'benchmark_chart':
        return BenchmarkChartTemplate(data: section.data, accent: accent);
      default:
        return Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF27272A)),
          ),
          child: Text(
            'Unknown template: "${section.template}"',
            style: GoogleFonts.firaCode(fontSize: 13, color: Colors.white38),
          ),
        );
    }
  }

  Color? _parseColor(String hex) {
    try {
      final cleaned = hex.replaceFirst('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return null;
    }
  }
}
