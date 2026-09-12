import 'package:flutter/foundation.dart';

/// A target app that MATE watches over, combining OS-reported app identity
/// with MATE's own on/off state for it.
///
/// [packageName] is the Android package name (e.g. `com.instagram.android`)
/// and doubles as this app's stable identity. iOS has no equivalent stable,
/// queryable identifier for third-party apps (Screen Time APIs use opaque
/// tokens instead), so cross-platform code should treat this as
/// "best-effort identity on Android today" rather than assume its format
/// generalizes.
@immutable
class GuardedApp {
  const GuardedApp({
    required this.packageName,
    required this.appName,
    required this.isGuarded,
    this.iconBytes,
  });

  final String packageName;
  final String appName;
  final bool isGuarded;
  final Uint8List? iconBytes;

  GuardedApp copyWith({bool? isGuarded}) {
    return GuardedApp(
      packageName: packageName,
      appName: appName,
      isGuarded: isGuarded ?? this.isGuarded,
      iconBytes: iconBytes,
    );
  }
}
