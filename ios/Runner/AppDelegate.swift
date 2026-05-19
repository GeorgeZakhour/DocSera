import GoogleMaps
import Firebase
import app_links

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Google Maps API key for the iOS SDK.
    GMSServices.provideAPIKey("AIzaSyBL4difcL7ueAbDZv7T6Fqk8QfFhYUMAuo")

    // Firebase Cloud Messaging — must be configured before plugin
    // registration so firebase_messaging can hook into the Apple
    // notification delegate chain. Reads GoogleService-Info.plist
    // bundled in the Runner target.
    FirebaseApp.configure()

    GeneratedPluginRegistrant.register(with: self)

    // Cold-start Universal Link handling. When iOS launches the app
    // because the user tapped a https://docsera.app/... link from
    // outside the app, the URL is in launchOptions BEFORE app_links's
    // plugin handlers are fully wired. Forward it manually via the
    // plugin's documented entry point so the URL reaches the Dart
    // side's DeepLinkService listener.
    if let url = AppLinks.shared.getLink(launchOptions: launchOptions) {
      AppLinks.shared.handleLink(url: url)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Warm-start Universal Link handling. The app_links plugin's own
  // continueUserActivity hook forwards the URL to Dart correctly, but
  // returns `false` to iOS — which makes iOS interpret the link as
  // "unhandled" and fall back to Safari (the symptom: app opens for
  // ~1 second then Safari takes over). Override here to forward the
  // URL ourselves and return `true` so iOS treats it as fully
  // consumed by the app.
  // See: https://github.com/llfbandit/app_links/issues (return-value bug)
  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
      AppLinks.shared.handleLink(url: url)
      return true
    }
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }
}
