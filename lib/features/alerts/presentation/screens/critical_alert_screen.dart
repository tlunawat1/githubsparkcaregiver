import 'package:flutter/material.dart';

import '../../../../core/alerts/critical_alert.dart';

class CriticalAlertScreen extends StatelessWidget {
  final CriticalAlertPayload payload;
  final VoidCallback onSeeDetails;

  const CriticalAlertScreen({
    super.key,
    required this.payload,
    required this.onSeeDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4C1D95), Color(0xFF7C3AED), Color(0xFFEC5B13)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _glassIcon(Icons.priority_high_rounded),
                    Text(
                      payload.isSosEvent ? 'SOS ALERT' : 'CRITICAL ALERT',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    _glassIcon(Icons.notifications_active_outlined),
                  ],
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Icon(
                        payload.isSosEvent ? Icons.sos_rounded : Icons.medication_rounded,
                        color: Colors.white,
                        size: 84,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      payload.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      payload.body.isEmpty
                          ? (payload.isSosEvent
                              ? 'Immediate attention required'
                              : 'Urgent caregiver action required')
                          : payload.body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if ((payload.dependentName ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        payload.dependentName!,
                        style: const TextStyle(
                          color: Color(0xFFFFB088),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    _glassCard(),
                  ],
                ),
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onSeeDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(62),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                          ),
                        ),
                        icon: const Icon(Icons.visibility_rounded),
                        label: const Text(
                          'See Details',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ringing will stop when you open details',
                      style: TextStyle(color: Colors.white70),
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

  Widget _glassIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }

  Widget _glassCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.campaign_outlined, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Urgent message',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              18,
              (index) => Container(
                width: 3,
                height: 6 + ((index * 7) % 18).toDouble(),
                decoration: BoxDecoration(
                  color: const Color(0xFFEC5B13),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
