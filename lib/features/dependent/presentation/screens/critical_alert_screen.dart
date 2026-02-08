import 'package:flutter/material.dart';
import '../../../../core/models/critical_alert_payload.dart';
import '../../../../core/services/critical_alert_service.dart';

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
    return Scaffold(
      backgroundColor: Colors.red.shade900,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_rounded, size: 80, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                payload.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                payload.body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  await CriticalAlertService().stopAlert(payload.alertId);
                  onSeeDetails();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red.shade900,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                ),
                child: const Text('See Details'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  await CriticalAlertService().stopAlert(payload.alertId);
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
