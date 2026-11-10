import 'update_info.dart';

export 'update_info.dart';

/// Web: the site is always the latest version, nothing to install.
class AppUpdater {
  static bool get supported => false;
  static String get currentBuild => '';

  static Future<UpdateInfo> check(String token) => throw UnsupportedError('web');
  static Stream<double> download(UpdateInfo info, String token) => throw UnsupportedError('web');
  static Future<String?> install() => throw UnsupportedError('web');
}
