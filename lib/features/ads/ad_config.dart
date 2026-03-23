import 'package:flutter/foundation.dart';

class AdConfig {
  static const String _androidBannerTestId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _iosBannerTestId =
      'ca-app-pub-3940256099942544/2934735716';

  // Pode ser sobrescrito no build:
  // --dart-define=ADMOB_ANDROID_BANNER_ID=ca-app-pub-xxxx/yyyy
  static const String androidBannerId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_ID',
    defaultValue: _androidBannerTestId,
  );

  // Pode ser sobrescrito no build:
  // --dart-define=ADMOB_IOS_BANNER_ID=ca-app-pub-xxxx/yyyy
  static const String iosBannerId = String.fromEnvironment(
    'ADMOB_IOS_BANNER_ID',
    defaultValue: _iosBannerTestId,
  );

  static String? bannerAdUnitId() {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return androidBannerId;
      case TargetPlatform.iOS:
        return iosBannerId;
      default:
        return null;
    }
  }
}
