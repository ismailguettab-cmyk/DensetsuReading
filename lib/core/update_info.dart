/// The APK published on GitHub (release "apk-latest", rebuilt on every push to main).
class UpdateInfo {
  UpdateInfo({required this.commit, required this.assetUrl, required this.size, required this.date, required this.newer});

  /// Commit the APK was built from.
  final String commit;

  /// API address of the APK file (works for a private repository with a token).
  final String assetUrl;
  final int size;
  final DateTime date;

  /// True when it differs from the installed build.
  final bool newer;
}

enum UpdateErrorKind { notFound, network }

class UpdateError implements Exception {
  UpdateError(this.kind, [this.detail]);
  final UpdateErrorKind kind;
  final String? detail;

  @override
  String toString() => 'Update: $kind ${detail ?? ''}';
}
