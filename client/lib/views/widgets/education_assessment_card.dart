import 'package:flutter/material.dart';
import '../../models/education_eval_rater.dart';
import '../../services/local_memory_service.dart';
import '../../theme/sepia_theme.dart';

/// An easy-to-digest Educational Assessment Scorecard
/// Evaluates the educational efficacy of the distributed AI and edge memory components.
class EducationAssessmentCard extends StatefulWidget {
  final LocalMemoryService memoryService;
  final bool initialExpanded;

  const EducationAssessmentCard({
    super.key,
    required this.memoryService,
    this.initialExpanded = false,
  });

  @override
  State<EducationAssessmentCard> createState() => _EducationAssessmentCardState();
}

class _EducationAssessmentCardState extends State<EducationAssessmentCard> {
  late EducationAssessmentReport _report;
  final EducationEvalRater _rater = const EducationEvalRater();
  bool _isBreakdownExpanded = false;

  @override
  void initState() {
    super.initState();
    _isBreakdownExpanded = widget.initialExpanded;
    _runEvaluation();
  }

  void _runEvaluation() {
    final bootState = widget.memoryService.bootState;
    setState(() {
      _report = _rater.evaluate(
        bootState: bootState,
        isToolFetchTested: true,
        isTaskEvictionTested: true,
        isPrefetchTested: widget.memoryService.prefetchHistory.isNotEmpty,
        isDreamSyncTested: widget.memoryService.dreamSyncHistory.isNotEmpty,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SepiaTheme.paper,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SepiaTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildExecutiveSummary(),
                const SizedBox(height: 14),
                _buildDimensionMeters(),
                const SizedBox(height: 14),
                _buildTakeaways(),
                const SizedBox(height: 12),
                _buildBreakdownToggle(),
                if (_isBreakdownExpanded) ...[
                  const SizedBox(height: 12),
                  ..._report.componentResults.map(_buildComponentItem),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SepiaTheme.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
        border: Border(bottom: BorderSide(color: SepiaTheme.borderSubtle)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school_outlined, size: 18, color: SepiaTheme.amber),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'EDUCATIONAL EFFICACY RATER',
                  style: SepiaTheme.serif(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: SepiaTheme.ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: SepiaTheme.sageBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: SepiaTheme.sageBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'GRADE: ${_report.letterGrade} (${_report.overallScore}%)',
                      style: SepiaTheme.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: SepiaTheme.sage,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('btn_refresh_education_rater'),
                icon: const Icon(Icons.refresh, size: 16, color: SepiaTheme.inkSecondary),
                tooltip: 'Re-evaluate educational score',
                onPressed: _runEvaluation,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SepiaTheme.canvas,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.borderSubtle),
      ),
      child: Text(
        _report.executiveSummary,
        style: SepiaTheme.sans(
          fontSize: 12,
          color: SepiaTheme.inkSecondary,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _buildDimensionMeters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 680;
        final items = [
          _buildMeterPill('Concept Retention', _report.conceptRetentionScore, 0.30),
          _buildMeterPill('Tactile Interactivity', _report.interactiveAffordanceScore, 0.30),
          _buildMeterPill('Cognitive Simplicity', _report.cognitiveSimplicityScore, 0.20),
          _buildMeterPill('Gameplay Cohesion', _report.gameplayIntegrationScore, 0.20),
        ];

        if (isNarrow) {
          return Column(
            children: items.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w)).toList(),
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 10,
          children: items.map((w) => SizedBox(width: (constraints.maxWidth - 12) / 2 - 1, child: w)).toList(),
        );
      },
    );
  }

  Widget _buildMeterPill(String label, double score, double weight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: SepiaTheme.canvas,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(
                label,
                style: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w600, color: SepiaTheme.ink),
              ),
              Text(
                '${score.toStringAsFixed(0)}% (wt ${(weight * 100).toInt()}%)',
                style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.sage, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: score / 100.0,
              backgroundColor: SepiaTheme.borderSubtle,
              valueColor: const AlwaysStoppedAnimation<Color>(SepiaTheme.sage),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTakeaways() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CORE CONCEPT TAKEAWAYS FOR PLAYERS',
          style: SepiaTheme.mono(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: SepiaTheme.inkMuted,
          ),
        ),
        const SizedBox(height: 8),
        ..._report.playerGraspedTakeaways.map((takeaway) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3, right: 6),
                  child: Icon(Icons.check_circle_outline, size: 13, color: SepiaTheme.sage),
                ),
                Expanded(
                  child: Text(
                    takeaway,
                    style: SepiaTheme.sans(
                      fontSize: 11,
                      color: SepiaTheme.ink,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBreakdownToggle() {
    return InkWell(
      key: const Key('btn_toggle_education_breakdown'),
      onTap: () {
        setState(() {
          _isBreakdownExpanded = !_isBreakdownExpanded;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                _isBreakdownExpanded ? '▲ HIDE 4-PHASE PEDAGOGICAL BREAKDOWN' : '▼ VIEW 4-PHASE PEDAGOGICAL BREAKDOWN',
                style: SepiaTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: SepiaTheme.amber,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _isBreakdownExpanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: SepiaTheme.amber,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComponentItem(EducationalComponentResult c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SepiaTheme.canvas,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  c.title,
                  style: SepiaTheme.sans(fontSize: 12, fontWeight: FontWeight.bold, color: SepiaTheme.ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: SepiaTheme.sageBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: SepiaTheme.sageBorder),
                ),
                child: Text(
                  '${c.statusLabel} (${c.score.toInt()}%)',
                  style: SepiaTheme.mono(fontSize: 9, fontWeight: FontWeight.bold, color: SepiaTheme.sage),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Core Lesson: ${c.coreLesson}',
            style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Game Analogy: ${c.gameAnalogy}',
            style: SepiaTheme.sans(fontSize: 11, fontStyle: FontStyle.italic, color: SepiaTheme.amber),
          ),
        ],
      ),
    );
  }
}
