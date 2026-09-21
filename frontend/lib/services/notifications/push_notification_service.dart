/// Hardware/OS abstraction for remote push notifications.
abstract interface class PushNotificationService {
  Future<void> initialize();
  Future<String?> getDeviceToken();
  Stream<Map<String, dynamic>> get onNotificationReceived;
}
