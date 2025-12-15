import 'package:flutter/material.dart';

/// Widget que exibe um indicador visual de progresso durante o teste de velocidade
class TestProgressIndicator extends StatelessWidget {
  const TestProgressIndicator({
    super.key,
    required this.status,
    required this.isTesting,
    this.progress,
  });

  final String status;
  final bool isTesting;
  final double? progress; // 0.0 a 1.0

  @override
  Widget build(BuildContext context) {
    if (!isTesting) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blueAccent,
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (progress != null) ...[
            const SizedBox(width: 12),
            Text(
              '${(progress! * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
