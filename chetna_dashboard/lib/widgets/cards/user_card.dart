// widgets/cards/user_card.dart - A++ PROFESSIONAL VERSION
import 'package:flutter/material.dart';

class EnhancedUserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onEdit;

  const EnhancedUserCard({super.key, required this.user, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isOnline = user['isOnline'] ?? false;
    final statusColor =
        isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8);
    final statusText = isOnline ? 'Online' : 'Offline';
    final lastActive = user['lastActive'];
    final timeSinceActive = user['timeSinceLastActivity'] ?? 999;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Show user details
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withOpacity(0.2),
                            statusColor.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isOnline
                            ? Icons.person_rounded
                            : Icons.person_outline_rounded,
                        color: statusColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _truncateName(
                                    user['name']?.toString() ?? 'Unknown User',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: Color(0xFF1E293B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: statusColor.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: statusColor.withOpacity(0.5),
                                            blurRadius: 4,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (user['phone']?.toString().isNotEmpty ??
                              false) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone_rounded,
                                  size: 14,
                                  color: const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _truncatePhone(
                                    user['phone']?.toString() ?? '',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Caregiver Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Caregiver Contact',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _truncatePhone(
                                user['caregiverPhone']?.toString() ?? 'Not Set',
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF0A4DA2).withOpacity(0.1),
                              const Color(0xFF4A6FA5).withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.phone_rounded,
                            size: 16,
                            color: Color(0xFF0A4DA2),
                          ),
                          onPressed: () {
                            // Call caregiver
                          },
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Last Active & Health Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color:
                              timeSinceActive < 5
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatLastActive(lastActive, timeSinceActive),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color:
                                timeSinceActive < 5
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.monitor_heart_rounded,
                            size: 12,
                            color: const Color(0xFF3B82F6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user['healthStatus']?.toString() ?? 'Normal',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _truncateName(String name) {
    if (name.length > 18) {
      return '${name.substring(0, 18)}...';
    }
    return name;
  }

  String _truncatePhone(String phone) {
    if (phone.length > 15) {
      return '${phone.substring(0, 15)}...';
    }
    return phone;
  }

  String _formatLastActive(DateTime? lastActive, int minutesSince) {
    if (lastActive == null) return 'Never active';
    if (minutesSince < 1) return 'Just now';
    if (minutesSince < 60) return '$minutesSince min ago';
    if (minutesSince < 1440) {
      final hours = (minutesSince / 60).floor();
      return '$hours hour${hours > 1 ? 's' : ''} ago';
    } else {
      final days = (minutesSince / 1440).floor();
      return '$days day${days > 1 ? 's' : ''} ago';
    }
  }
}
