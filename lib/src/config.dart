/// Build-time configuration.
///
/// flutter run --dart-define=API_URL=http://10.0.2.2:8000/api   (Android emulator)
/// flutter run --dart-define=API_URL=http://localhost:8000/api  (iOS sim / desktop)
/// prod: https://den-server-omega.vercel.app/api
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://api.3.236.91.37.nip.io/api',
    // defaultValue: 'http://localhost:8001/api',
  );
  // https://api.34.232.210.39.nip.io/api

  /// Google OAuth WEB client id — yahi React website ka bhi hai.
  /// ⚠️ App ke Android/iOS client IDs yahan NAHI daalne — wo sirf Google
  /// Console mein register hote hain (package name + SHA-1) aur backend ke
  /// GOOGLE_CLIENT_IDS mein. serverClientId hamesha WEB client hi rahega,
  /// warna Android sign-in ApiException: 10 (DEVELOPER_ERROR) se fail hota hai.
  static const googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '375395125425-st5ba3fcsu5nqkcioovofa2ib1s21gmh.apps.googleusercontent.com',
  );

  /// iOS OAuth client id — SIRF iOS build ke liye. Android par ignore hota hai
  /// (wahan console ka Android client SHA-1+package se auto-match hota hai).
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  static const appName = "Rowdy's Den";
  static const appTagline = 'Club Billing';
  static const appVersion = '1.0.0';
}
