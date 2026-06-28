import 'package:flutter/material.dart';

class ScoreIndicator extends StatelessWidget {
  final int score;
  final String label;
  final bool reverseColor;
  final double size;

  const ScoreIndicator({
    super.key,
    required this.score,
    required this.label,
    this.reverseColor = false,
    this.size = 60,
  });

  Color _getColor() {
    if (reverseColor) {
      // عكس الألوان (للثغرات - الأقل أفضل)
      if (score <= 30) return Colors.red;
      if (score <= 60) return Colors.orange;
      if (score <= 80) return Colors.yellow.shade700;
      return Colors.green;
    } else {
      // ألوان عادية (للأمان - الأعلى أفضل)
      if (score >= 75) return Colors.green;
      if (score >= 50) return Colors.yellow.shade700;
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    
    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 6,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$score',
                    style: TextStyle(
                      fontSize: size * 0.3,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    '/100',
                    style: TextStyle(
                      fontSize: size * 0.15,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
