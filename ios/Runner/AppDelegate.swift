import Flutter
import UIKit
import GoogleMaps   // ✅ أضف هذه

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // ✅ مرّر مفتاح خرائط iOS هنا
    GMSServices.provideAPIKey("AIzaSyBL4difcL7ueAbDZv7T6Fqk8QfFhYUMAuo")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
