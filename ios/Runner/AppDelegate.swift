import Flutter
import UIKit
import GoogleMaps
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
  private let locationManager = CLLocationManager()
  private var geofenceChannel: FlutterMethodChannel?
  private var notificationChannel: FlutterMethodChannel?
  private var pendingNotificationPayload: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
    
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    geofenceChannel = FlutterMethodChannel(name: "oasis/geofence",
                                              binaryMessenger: controller.binaryMessenger)
    notificationChannel = FlutterMethodChannel(name: "oasis/notification_tap",
                                              binaryMessenger: controller.binaryMessenger)
    
    notificationChannel?.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "getPendingNotificationPayload" {
        result(self?.pendingNotificationPayload)
        self?.pendingNotificationPayload = nil
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    let stealthChannel = FlutterMethodChannel(name: "oasis/stealth_mode",
                                             binaryMessenger: controller.binaryMessenger)
    stealthChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "setStealthMode" {
        guard let args = call.arguments as? [String: Any],
              let enable = args["enable"] as? Bool else {
          result(FlutterError(code: "INVALID_ARGS", message: "Arguments must contain enable", details: nil))
          return
        }
        
        if #available(iOS 10.3, *) {
          let iconName = enable ? "decoy_icon" : nil
          UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
              print("Error setting alternate icon: \(error.localizedDescription)")
              result(FlutterError(code: "ICON_ERROR", message: error.localizedDescription, details: nil))
            } else {
              print("Successfully changed app icon to: \(String(describing: iconName))")
              result(true)
            }
          }
        } else {
          result(FlutterError(code: "UNSUPPORTED", message: "iOS version does not support alternate icons", details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    UNUserNotificationCenter.current().delegate = self
    
    geofenceChannel?.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      // ... existing geofence handler
      guard let self = self else { return }
      
      switch call.method {
      case "addGeofence":
        if let args = call.arguments as? [String: Any],
           let id = args["id"] as? String,
           let lat = args["lat"] as? Double,
           let lon = args["lon"] as? Double,
           let radius = args["radius"] as? Double {
          self.addGeofence(id: id, lat: lat, lon: lon, radius: radius)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
        }
      case "removeGeofence":
        if let args = call.arguments as? [String: Any],
           let id = args["id"] as? String {
          self.removeGeofence(id: id)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
        }
      case "removeAllGeofences":
        self.removeAllGeofences()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    })

    locationManager.delegate = self
    locationManager.requestAlwaysAuthorization()

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    
    if let jsonData = try? JSONSerialization.data(withJSONObject: userInfo, options: []),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        pendingNotificationPayload = jsonString
        notificationChannel?.invokeMethod("onNotificationTap", arguments: jsonString)
    }
    
    completionHandler()
  }

  private func addGeofence(id: String, lat: Double, lon: Double, radius: Double) {
    let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    let region = CLCircularRegion(center: center, radius: radius, identifier: id)
    region.notifyOnEntry = true
    region.notifyOnExit = true
    locationManager.startMonitoring(for: region)
  }

  private func removeGeofence(id: String) {
    for region in locationManager.monitoredRegions {
      if region.identifier == id {
        locationManager.stopMonitoring(for: region)
      }
    }
  }

  private func removeAllGeofences() {
    for region in locationManager.monitoredRegions {
      locationManager.stopMonitoring(for: region)
    }
  }

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    if region is CLCircularRegion {
      print("Entered region: \(region.identifier)")
      geofenceChannel?.invokeMethod("onEnterRegion", arguments: ["id": region.identifier])
    }
  }

  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    if region is CLCircularRegion {
      print("Exited region: \(region.identifier)")
      geofenceChannel?.invokeMethod("onExitRegion", arguments: ["id": region.identifier])
    }
  }
}
