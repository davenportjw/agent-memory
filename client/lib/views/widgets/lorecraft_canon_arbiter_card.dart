import 'package:flutter/material.dart';
import '../../services/lorecraft_service.dart';
import '../../theme/sepia_theme.dart';

class LoreCraftCanonArbiterCard extends StatelessWidget {
  final CanonRatingResult? rating;
  final VoidCallback? onReevaluate;

  const LoreCraftCanonArbiterCard({
    super.key,
    required this.rating,
    this.onReevaluate,
  });

  @override
  Widget build(BuildContext context) {
    if (rating == null) {
      return Container(
        decoration: BoxDecoration(
          color: SepiaTheme.paper,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: SepiaTheme.border),
        ),
        padding: const EdgeInsets.all(12.0),
        child: Text(
          'Waiting for dialogue completion to run Canon Arbiter benchmark...',
          style: SepiaTheme.sans(fontSize: 12, fontStyle: FontStyle.italic, color: SepiaTheme.inkMuted),
        ),
      );
    }

    final r = rating!;

    return Container(
      decoration: BoxDecoration(
        color: SepiaTheme.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SepiaTheme.border, width: 1.0),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'CANON & VOICE ARBITER',
                  style: SepiaTheme.sans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: SepiaTheme.inkMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => _showRubricDialog(context),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified, size: 14, color: SepiaTheme.sage),
                      const SizedBox(width: 4),
                      Text('Rubrics', style: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w600, color: SepiaTheme.sage)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Total Score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Evaluation Score',
                  style: SepiaTheme.sans(fontSize: 13, fontWeight: FontWeight.w600, color: SepiaTheme.ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: SepiaTheme.sage.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${r.overallScore.toStringAsFixed(1)} / 5.0',
                  style: SepiaTheme.mono(fontSize: 13, fontWeight: FontWeight.w700, color: SepiaTheme.sage),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          _scoreBar('Voice Consistency', r.voiceConsistency),
          _scoreBar('Canon Fidelity', r.canonFidelity),
          _scoreBar('Frame Budget (< 100ms)', r.frameBudgetScore),

          const SizedBox(height: 8),
          const Divider(color: SepiaTheme.border, height: 1),
          const SizedBox(height: 8),

          // Feedback
          Text(
            'Objective Judge (Gemini 3.8 Flash):',
            style: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w600, color: SepiaTheme.inkMuted),
          ),
          const SizedBox(height: 3),
          SelectableText(
            r.raterFeedback,
            style: SepiaTheme.sans(fontSize: 12, height: 1.35, color: SepiaTheme.ink),
          ),
        ],
      ),
    );
  }

  Widget _scoreBar(String label, double score) {
    final ratio = (score / 5.0).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                score.toStringAsFixed(1),
                style: SepiaTheme.mono(fontSize: 11, fontWeight: FontWeight.w600, color: SepiaTheme.ink),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: SepiaTheme.paperSubtle,
              valueColor: const AlwaysStoppedAnimation<Color>(SepiaTheme.sage),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  void _showRubricDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SepiaTheme.paper,
        title: Text('LLM-as-a-Rater Canon Rubric Standards', style: SepiaTheme.sans(fontWeight: FontWeight.w700, fontSize: 16)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _rubricRow('Voice & Persona (35%)', 'Strict adherence to pragmatic tone; penalty for modern slang, engineering jargon, or cartoonish exclamations.'),
              _rubricRow('Canon Fidelity (40%)', 'Concordance with durable knowledge anchors and world state flags without hallucinating absent assets.'),
              _rubricRow('Frame Budget Factor (25%)', 'Time to First Token (TTFT) <= 100ms on-device ensures 60-FPS rendering thread does not stall.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: SepiaTheme.sans(color: SepiaTheme.ink, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  static Widget _rubricRow(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: SepiaTheme.sans(fontSize: 13, fontWeight: FontWeight.w700, color: SepiaTheme.ink)),
          const SizedBox(height: 2),
          Text(desc, style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkMuted, height: 1.3)),
        ],
      ),
    );
  }
}
