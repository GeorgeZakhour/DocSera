# iOS Privacy Manifest (`PrivacyInfo.xcprivacy`)

**Status:** Authored. Lives at [`ios/Runner/PrivacyInfo.xcprivacy`](../../ios/Runner/PrivacyInfo.xcprivacy).
**Wired into:** Xcode `Runner` target → Resources build phase (`ios/Runner.xcodeproj/project.pbxproj`).
**Last audit:** 2026-05-10.

## What it is

Apple requires a privacy manifest in every iOS app bundle since May 2024. It's
a property-list (`.xcprivacy`) declaring two things up front:

1. **`NSPrivacyAccessedAPITypes`** — every "fingerprinting-prone" Apple API
   the app or its bundled plugins call, with a reason code from Apple's
   published list.
2. **`NSPrivacyCollectedDataTypes`** — the privacy nutrition label, restated
   inside the binary so App Store Connect can statically cross-check it
   against the answers entered in the App Privacy section.

App Store Connect rejects uploads where:
- A declared API category is used without a reason code, OR
- An SDK ships its own manifest and the app's manifest contradicts it, OR
- The aggregated data-type list doesn't match the App Privacy answers.

## How DocSera's manifest was built

### API categories (with reasons)

Cross-checked against each pod's own `PrivacyInfo.xcprivacy` in `ios/Pods/*`
plus what the Flutter plugins (most without their own manifest) actually
call from the `flutter_assets` runtime.

| Category | Reason | Source |
|---|---|---|
| `UserDefaults` | `CA92.1` (app-only access) | `shared_preferences`, internal plugin state, mirrors Pushy + Sentry pod manifests |
| `FileTimestamp` | `C617.1` (modification detection) | `path_provider`, `file_picker`, `image_picker`, `cached_network_image` |
| `DiskSpace` | `E174.1` (display free space) | Used when surfacing "not enough space" toasts during medical-doc upload |
| `SystemBootTime` | `35F9.1` (time-since-event measurement) | `sentry_flutter` for crash correlation; mirrors Sentry pod manifest |

### Data-type declarations

Source of truth: [`14-app-store-assets.md` §4](./14-app-store-assets.md#4-privacy-nutrition-labels-app-store).
Any change to either must update the other.

| Data type | Linked | Tracking | Purpose | Why DocSera collects it |
|---|---|---|---|---|
| Name | ✅ | ❌ | App Functionality | Account profile + appointment booking |
| Email Address | ✅ | ❌ | App Functionality | Account auth + transactional notifications |
| Phone Number | ✅ | ❌ | App Functionality | OTP login, doctor contact channel |
| Health | ✅ | ❌ | App Functionality | Medical records, conditions, body-map entries |
| Photos or Videos | ✅ | ❌ | App Functionality | Profile picture + uploaded medical documents |
| Audio Data | ✅ | ❌ | App Functionality | Voice messages in doctor conversations |
| Customer Support | ✅ | ❌ | App Functionality | Encrypted messages with doctors |
| Precise Location | ✅ | ❌ | App Functionality | "Find nearby doctors" map (geolocator, `LocationAccuracy.high`) |
| User ID | ✅ | ❌ | App Functionality | Supabase `auth.users.id` linkage |
| Device ID | ✅ | ❌ | App Functionality | Pushy device token for push delivery |
| Product Interaction | ✅ | ❌ | Analytics | Sentry performance traces (route changes, span timings) |
| Crash Data | ❌ | ❌ | App Functionality | Sentry, with PII scrubber (see [`05-security-review.md`](./05-security-review.md)) |
| Performance Data | ❌ | ❌ | App Functionality | Sentry, same scrubber |

**Tracking: `false` everywhere.** DocSera doesn't share data with third
parties for advertising or cross-app tracking. `NSPrivacyTrackingDomains` is
empty.

## Plugin manifest coverage

Pods that ship their own manifest (Apple aggregates these):
- `Sentry` — UserDefaults, SystemBootTime, FileTimestamp + CrashData, PerformanceData, OtherDiagnosticData
- `Pushy` — UserDefaults
- `GoogleMaps`, `SDWebImage`, `SwiftyGif`, `DKImagePickerController`, `DKPhotoGallery` — minimal API declarations

Flutter plugins WITHOUT their own manifest (the app's manifest declares on
their behalf):
- `shared_preferences_foundation`, `path_provider_foundation`, `file_picker`,
  `image_picker_ios`, `connectivity_plus`, `device_info_plus`,
  `package_info_plus`, `local_auth_darwin`, `geolocator_apple`,
  `flutter_local_notifications`, `audioplayers_darwin`, `record_ios`,
  `flutter_secure_storage`, `url_launcher_ios`, `share_plus`, `app_links`,
  `permission_handler_apple`, `webview_flutter_wkwebview`

If any of these later ships its own manifest in a future version, the app's
declarations will still be valid (App Store accepts redundant declarations).

## How to verify before submission

```bash
# Plist syntax
plutil -lint ios/Runner/PrivacyInfo.xcprivacy

# Confirm it's bundled into the app target (must show "PrivacyInfo.xcprivacy")
grep PrivacyInfo.xcprivacy ios/Runner.xcodeproj/project.pbxproj
```

After uploading the build to App Store Connect, the **App Privacy** section
of the listing must answer the same questions the manifest declares. Apple's
upload pipeline will warn if there's a mismatch.

## Sources

- Apple's "Privacy manifest files" docs:
  https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
- Apple's required reason API list:
  https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api
- Apple's data type taxonomy:
  https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_data_use_in_privacy_manifests

## What's left

Nothing for this round. The manifest is comprehensive, validated, and
bundled. Re-audit if:

- New plugin added to `pubspec.yaml` (especially analytics SDKs)
- New data type collected (e.g., adding payments → Financial Info)
- Sentry / Pushy major version bump (their manifests may shift)
- Apple expands the required-reason API list (check their May / Aug release notes)
