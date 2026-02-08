import 'api_client.dart';

class CriticalAlertApi {
  final ApiClient _client;

  CriticalAlertApi(this._client);

  Future<void> acknowledgeAlert({
    required String alertId,
    required String status,
  }) async {
    await _client.post(
      '/api/critical-alerts/$alertId/ack',
      body: {
        'status': status,
      },
    );
  }
}
