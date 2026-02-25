import 'package:permission_handler/permission_handler.dart';

class AppPermissions {
  static Future<bool> requestVoicePermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      Permission.speech,
      Permission.notification,
      Permission.ignoreBatteryOptimizations,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }
}
