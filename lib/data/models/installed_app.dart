import 'package:flutter/foundation.dart';

/// An app reported by the OS as installed and launchable.
///
/// [iconBytes] is a small PNG rendered natively (Android `PackageManager`
/// today; iOS has no equivalent third-party API and will always report
/// `null` here). UI code must render a fallback icon when it's null.
@immutable
class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.appName,
    this.iconBytes,
  });

  final String packageName;
  final String appName;
  final Uint8List? iconBytes;
}
