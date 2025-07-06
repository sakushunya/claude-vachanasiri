import UIKit
import Flutter
import AVFoundation
import FirebaseCore

@UIApplicationMain
class AppDelegate: FlutterAppDelegate {
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        
        // Audio session configuration
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .allowAirPlay, .allowBluetooth]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session configuration failed: \(error)")
        }
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func applicationDidBecomeActive(_ application: UIApplication) {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio reactivation failed: \(error)")
        }
    }

    override func applicationDidEnterBackground(_ application: UIApplication) {
        backgroundTask = application.beginBackgroundTask { [weak self] in
            application.endBackgroundTask(self?.backgroundTask ?? .invalid)
            self?.backgroundTask = .invalid
        }
    }

    override func applicationWillEnterForeground(_ application: UIApplication) {
        if backgroundTask != .invalid {
            application.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}