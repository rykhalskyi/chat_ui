import 'package:package_info_plus/package_info_plus.dart';

class AppVersion {
  const AppVersion({required this.version, required this.buildNumber});

  static const fallback = AppVersion(version: '0.2.0', buildNumber: '2');

  final String version;
  final String buildNumber;

  String get display =>
      buildNumber.isEmpty ? version : '$version (build $buildNumber)';
}

class AppInfo {
  static Future<AppVersion> current() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return AppVersion(version: info.version, buildNumber: info.buildNumber);
    } catch (_) {
      return AppVersion.fallback;
    }
  }
}
