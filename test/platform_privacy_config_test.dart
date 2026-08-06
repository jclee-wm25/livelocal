import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile manifests keep release privacy and transport boundaries', () {
    final android =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(android, contains('android.permission.INTERNET'));
    expect(android, contains('android.permission.ACCESS_FINE_LOCATION'));
    expect(android, contains('android.permission.ACCESS_COARSE_LOCATION'));
    expect(
      android,
      contains(
        'android:name="android.hardware.location.gps" android:required="false"',
      ),
    );
    expect(android, contains('android:allowBackup="false"'));
    expect(android, contains('android:usesCleartextTraffic="false"'));

    final debugAndroid =
        File('android/app/src/debug/AndroidManifest.xml').readAsStringSync();
    expect(debugAndroid, contains('android:usesCleartextTraffic="true"'));

    final iosInfo = File('ios/Runner/Info.plist').readAsStringSync();
    expect(iosInfo, contains('NSLocationWhenInUseUsageDescription'));
    expect(iosInfo, contains('select a city manually'));
    expect(iosInfo, contains('NSPhotoLibraryUsageDescription'));

    final iosPrivacy =
        File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
    expect(iosPrivacy, contains('<key>NSPrivacyTracking</key>\n\t<false/>'));
    for (final dataType in [
      'NSPrivacyCollectedDataTypeName',
      'NSPrivacyCollectedDataTypeEmailAddress',
      'NSPrivacyCollectedDataTypeUserID',
      'NSPrivacyCollectedDataTypeCoarseLocation',
      'NSPrivacyCollectedDataTypePreciseLocation',
      'NSPrivacyCollectedDataTypePhotosorVideos',
      'NSPrivacyCollectedDataTypeOtherUserContent',
      'NSPrivacyCollectedDataTypeProductInteraction',
    ]) {
      expect(iosPrivacy, contains(dataType));
    }
  });
}
