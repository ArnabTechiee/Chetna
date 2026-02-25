import 'package:flutter/material.dart';

class EnhancedStatusIndicator extends StatelessWidget {
  final int criticalCount;
  final int warningCount;

  const EnhancedStatusIndicator({
    super.key,
    required this.criticalCount,
    required this.warningCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alert Status',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          // FIXED: Added MainAxisSize.min and removed Flexible wrappers to handle unconstrained parents
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusIndicator(
                count: criticalCount,
                label: 'Critical',
                color: const Color(0xFFDC2626),
                icon: Icons.warning_amber_rounded,
              ),
              const SizedBox(width: 20),
              _buildStatusIndicator(
                count: warningCount,
                label: 'Warning',
                color: const Color(0xFFF59E0B),
                icon: Icons.info_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator({
    required int count,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      // Optional: Add a width constraint if you want them to be uniform
      // width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min, // Wrap content tightly
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              // FIXED: Replaced Spacer() with SizedBox. Spacer() crashes in unconstrained widths.
              const SizedBox(width: 16),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'alerts active',
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}
