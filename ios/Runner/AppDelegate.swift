import GoogleMaps   // ✅ أضف هذه
import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // ✅ مرّر مفتاح خرائط iOS هنا
    GMSServices.provideAPIKey("AIzaSyBL4difcL7ueAbDZv7T6Fqk8QfFhYUMAuo")

    // Firebase Cloud Messaging — must be configured before plugin
    // registration so firebase_messaging can hook into the Apple
    // notification delegate chain. Reads GoogleService-Info.plist
    // bundled in the Runner target.
    FirebaseApp.configure()

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
