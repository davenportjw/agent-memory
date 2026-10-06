import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/sepia_theme.dart';

class RadarChartWidget extends StatelessWidget {
  final double semanticFidelity;       // 1-5
  final double instructionCompliance;  // 1-5
  final double safetyPii;              // 1-5
  final double efficiencyFactor;       // 1-5
  final double compositeScore;         // 1-5
  final double size;

  const RadarChartWidget({
    super.key,
    required this.semanticFidelity,
    required this.instructionCompliance,
    required this.safetyPii,
    required this.efficiencyFactor,
    required this.compositeScore,
    this.size = 220,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RadarChartPainter(
              scores: [
                semanticFidelity,
                instructionCompliance,
                safetyPii,
                efficiencyFactor,
              ],
              labels: const [
                'Semantic\n(35%)',
                'Compliance\n(25%)',
                'Safety PII\n(25%)',
                'Efficiency\n(15%)',
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: SepiaTheme.sageBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SepiaTheme.sageBorder),
          ),
          child: Text(
            'Composite Rater Score: ${compositeScore.toStringAsFixed(2)} / 5.00',
            style: SepiaTheme.mono(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SepiaTheme.sage,
            ),
          ),
        ),
      ],
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final List<double> scores; // 1.0 to 5.0
  final List<String> labels;

  _RadarChartPainter({
    required this.scores,
    required this.labels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.36;
    final angleStep = (2 * pi) / scores.length;

    final gridPaint = Paint()
      ..color = SepiaTheme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw 4 concentric polygon rings (representing score scales 1.25, 2.5, 3.75, 5.0)
    for (int ring = 1; ring <= 4; ring++) {
      final r = radius * (ring / 4.0);
      final ringPath = Path();
      for (int i = 0; i < scores.length; i++) {
        final angle = (i * angleStep) - (pi / 2);
        final x = center.dx + r * cos(angle);
        final y = center.dy + r * sin(angle);
        if (i == 0) {
          ringPath.moveTo(x, y);
        } else {
          ringPath.lineTo(x, y);
        }
      }
      ringPath.close();
      canvas.drawPath(ringPath, gridPaint);
    }

    // Draw radial spoke lines
    final spokePaint = Paint()
      ..color = SepiaTheme.borderSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < scores.length; i++) {
      final angle = (i * angleStep) - (pi / 2);
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      canvas.drawLine(center, Offset(x, y), spokePaint);
    }

    // Draw score polygon
    final scorePath = Path();
    final pointList = <Offset>[];

    for (int i = 0; i < scores.length; i++) {
      final normalized = (scores[i] / 5.0).clamp(0.0, 1.0);
      final r = radius * normalized;
      final angle = (i * angleStep) - (pi / 2);
      final pt = Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
      pointList.add(pt);
      if (i == 0) {
        scorePath.moveTo(pt.dx, pt.dy);
      } else {
        scorePath.lineTo(pt.dx, pt.dy);
      }
    }
    scorePath.close();

    final fillPaint = Paint()
      ..color = SepiaTheme.sage.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawPath(scorePath, fillPaint);

    final strokePaint = Paint()
      ..color = SepiaTheme.sage
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(scorePath, strokePaint);

    // Draw vertex dots
    final dotPaint = Paint()
      ..color = SepiaTheme.sage
      ..style = PaintingStyle.fill;
    for (final pt in pointList) {
      canvas.drawCircle(pt, 3.5, dotPaint);
    }

    // Draw axis labels
    for (int i = 0; i < labels.length; i++) {
      final angle = (i * angleStep) - (pi / 2);
      final labelR = radius + 22;
      final lx = center.dx + labelR * cos(angle);
      final ly = center.dy + labelR * sin(angle);

      final textSpan = TextSpan(
        text: '${labels[i]}\n${scores[i].toStringAsFixed(1)}/5',
        style: const TextStyle(
          fontFamily: SepiaTheme.fontMono,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: SepiaTheme.inkSecondary,
          height: 1.1,
        ),
      );
      final tp = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.scores != scores;
  }
}
