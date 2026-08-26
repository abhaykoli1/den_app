# 🍎 Rowdy's Den — iOS Setup (ek baar, 10–15 min)

App ka saara source already **iOS-ready** hai (`lib/` poora cross-platform,
saare plugins Android+iOS dono support karte hain). Sirf **iOS platform folder**
banana hai — wo Mac+Flutter pe 2 commands me ban jata hai.

---

## 1) Platform folders generate karo (zip ke andar, terminal me)

```bash
cd flutter_app
flutter create --platforms=ios --org in.rowdysden --project-name rowdys_den_app .
flutter pub get
```

> `--org in.rowdysden` se bundle id banega `in.rowdysden.rowdys_den_app` —
> badalna ho to abhi yahin badlo (baad me Xcode se bhi ho jata hai).
> Android folder nahi chahiye tha is command me — sirf iOS banaya. Dono ek
> saath chahiye to `--platforms=ios,android` likh do.

## 2) iOS Info.plist keys (logo upload + thoda polish)

`ios/Runner/Info.plist` me `<dict>` ke andar yeh keys add karo:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Club logo ki photo gallery se chunne ke liye photo library access chahiye.</string>
<key>CFBundleDisplayName</key>
<string>Rowdy's Den</string>
<key>UIApplicationSupportsIndirectInputEvents</key>
<true/>
```

## 3) Google Sign-In (iOS) — optional, Android jaisa hi

Firebase Console (project wahi wala) me **iOS app** add karo (same bundle id),
`GoogleService-Info.plist` download karke `ios/Runner/` me daalo, aur
Info.plist me reversed-client-id URL scheme add karo:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>REVERSED_CLIENT_ID_yahan</string>
    </array>
  </dict>
</array>
```

> `REVERSED_CLIENT_ID` GoogleService-Info.plist ke andar likha hota hai.
> Jab tak yeh nahi karoge, **Dev Login + email/password iOS pe bhi same
> chalta hai** — Google button hi iOS pe nahi khulega.

## 4) Run / build

```bash
flutter run            # connected iPhone / simulator pe
flutter build ipa      # App Store/TestFlight package (Apple Developer account)
```

**Xcode me ek baar:** `ios/Runner.xcworkspace` kholo → Signing & Capabilities
→ apna Team select karo (free Apple ID bhi chalega device-test ke liye).

---

### iOS readiness checklist (code side) — sab ✅

| Cheez | Status |
|---|---|
| Saara UI Material-only (koi Android-only widget/channel nahi) | ✅ |
| Plugins iOS support: shared_preferences, url_launcher, share_plus, printing, path_provider, image_picker, google_sign_in (7.x iOS-ready), http | ✅ |
| SafeArea har screen + bottom sheets pe | ✅ |
| Logical-pixel sizes (`dimensions.dart`) — iOS/Android same physical | ✅ |
| Min iOS target: plugin set iOS 13+ maangta hai — default runner 13/14 pe fine | ✅ |
| Photo permission string (upar §2) | 🔧 tumhe plist me daalni hai |
| Sign in with Apple | ❌ sirf tab chahiye jab Google login iOS App Store pe jaye (Apple ki guideline — baad me add kar sakte hain, backend me Apple auth lane hogi) |

> **Note:** jab App Store pe Google login doge tab Apple **Sign in with Apple**
> bhi maangta hai (3rd-party login ke saath). Abhi internal/TestFlight use ke
> liye zaroori nahi.
