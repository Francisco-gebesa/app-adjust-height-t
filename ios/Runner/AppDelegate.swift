import UIKit
import Flutter
import Firebase
import FirebaseMessaging
import AVFoundation


@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()

      if #available(iOS 10.0, *) {
          UNUserNotificationCenter.current().delegate = self
      }
      
    // Configurar AVAudioSession para permitir el uso del micrófono en WebView
    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.allowBluetooth, .defaultToSpeaker])
      try audioSession.setActive(true)
    } catch {
      print("Error configurando AVAudioSession: \(error)")
    }

    application.registerForRemoteNotifications()
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "audio_session", binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        guard call.method == "setAudioSession" else {
            result(FlutterMethodNotImplemented)
            return
        }
        self?.setAudioSession()
        result(nil)
    })

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setAudioSession() {
    do {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.allowBluetooth, .defaultToSpeaker])
        try audioSession.setActive(true)
        print("Audio session configured successfully for recording")
    } catch {
        print("Error setting up audio session: \(error)")
    }
  }

   override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
    
    
}
