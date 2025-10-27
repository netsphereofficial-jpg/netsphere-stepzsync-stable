import UIKit
import Flutter

/// SceneDelegate for iOS 13+ UIScene lifecycle support
/// This eliminates the "UIScene lifecycle will soon be required" warning
/// and prepares the app for future iOS requirements (iOS 27+)
@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    // MARK: - Scene Lifecycle

    /// Called when a new scene session is being created
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // Flutter handles window creation, but we need to respond to scene lifecycle
        // Get the Flutter window from AppDelegate
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
           let flutterWindow = appDelegate.window {
            // Update window scene for the existing Flutter window
            self.window = flutterWindow
            self.window?.windowScene = windowScene
        }
    }

    /// Called when scene is disconnecting
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system
        // Use this to release any scene-specific resources
    }

    /// Called when scene becomes active
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Restart any tasks that were paused (or not yet started) when scene was inactive
        // CMPedometer continues tracking automatically
    }

    /// Called when scene will resign active state
    func sceneWillResignActive(_ scene: UIScene) {
        // Pause any ongoing tasks, disable timers if needed
        // CMPedometer continues tracking automatically
    }

    /// Called when scene will enter foreground
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Undo the changes made when entering background
        // CMPedometer step data will be synced by Flutter
    }

    /// Called when scene enters background
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Save application state and release shared resources
        // Background tasks are managed by AppDelegate
    }
}
