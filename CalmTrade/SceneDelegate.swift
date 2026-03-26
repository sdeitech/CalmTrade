//
//  SceneDelegate.swift
//  CalmTrade
//
//  Created by Developer on 1/24/26.
//

import UIKit
import GoogleSignIn
import FBSDKCoreKit
import BackgroundTasks

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    private var polarSyncService: Polar360SyncService!

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = initialRootViewController()
        window.makeKeyAndVisible()
        self.window = window
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthExpired),
            name: .authDidExpire,
            object: nil
        )
        
        if let urlContext = connectionOptions.urlContexts.first {
            DeepLinkRouter.shared.handle(url: urlContext.url)
        } else if let activity = connectionOptions.userActivities.first,
                  activity.activityType == NSUserActivityTypeBrowsingWeb,
                  let url = activity.webpageURL {
            DeepLinkRouter.shared.handle(url: url)
        }
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).

        // Stop background mirroring when scene disconnects
        HealthKitService.shared.stopBackgroundMirroring()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.

        // Resume services when becoming active
        DispatchQueue.main.async {
            CalmScoreHub.shared.start()  // Restart calm score calculations
            HealthKitService.shared.startBackgroundMirroring()  // Resume HealthKit monitoring

            // Reconnect socket if needed
            if let token = UserDefaults.standard.string(forKey: "accessToken"), !token.isEmpty {
                SocketClient.shared.connect(with: token)
            }
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.

        // Stop unnecessary background activity to preserve battery and avoid hanging
        CalmScoreHub.shared.stop()  // Stop the continuous heartbeat in background
        // NOTE: HealthKitService keeps running in background for background delivery

        scheduleCalmScoreRefresh()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        scheduleCalmScoreRefresh()
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // Handle incoming URLs
        for context in URLContexts {
            let url = context.url
            
            // Handle Facebook URL
            ApplicationDelegate.shared.application(
                UIApplication.shared,
                open: url,
                sourceApplication: nil,
                annotation: [:]
            )

            // Handle Google URL
            GIDSignIn.sharedInstance.handle(url)

            // Handle deep links
            DeepLinkRouter.shared.handle(url: url)
        }
    }

    // MARK: - Deep Link Support
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        // Handle universal links
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else { return }
        DeepLinkRouter.shared.handle(url: url)
    }

    // MARK: - Background Tasks
    private func scheduleCalmScoreRefresh() {
        let req = BGAppRefreshTaskRequest(identifier: "com.calmtrade.calmScore.refresh")
        req.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // ask iOS: ~15+ min
        try? BGTaskScheduler.shared.submit(req)
    }

    func scheduleCalmScoreProcessing() {
        let req = BGProcessingTaskRequest(identifier: "com.calmtrade.calmScore.processing")
        req.requiresNetworkConnectivity = false
        req.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(req)
    }

    private func handleCalmScoreRefresh(task: BGAppRefreshTask) {
        scheduleCalmScoreRefresh()

        let queue = OperationQueue()
        let op = BlockOperation {

            let inputs = LatestBiometricsCache.shared.snapshot()

            // NEW pure physiological session API
            let session = CalmScoreCalculator().session(from: inputs, phase: .during)

            let source = String(describing: DeviceManager.shared.currentSource)

            CalmScoreStore.shared.save(
                value: session.calmScore,
                at: Date(),
                source: source
            )
        }

        task.expirationHandler = { queue.cancelAllOperations() }
        op.completionBlock = { task.setTaskCompleted(success: !op.isCancelled) }
        queue.addOperation(op)
    }

    private func handleCalmScoreProcessing(task: BGProcessingTask) {
        scheduleCalmScoreProcessing()
        let queue = OperationQueue()
        let op = BlockOperation {
            // Long-running background work here
        }
        task.expirationHandler = { queue.cancelAllOperations() }
        op.completionBlock = { task.setTaskCompleted(success: !op.isCancelled) }
        queue.addOperation(op)
    }
}

private extension SceneDelegate {
    private func isLoggedIn() -> Bool {
        if let token = UserDefaults.standard.string(forKey: "accessToken"), !token.isEmpty { return true }
        return false
    }

    private func initialRootViewController() -> UIViewController {
        if isLoggedIn() {
            // Go straight to dashboard
            let tab = UIStoryboard(name: Constants.Storyboard.Dashboard, bundle: nil).instantiateViewController(withIdentifier: "TabbarController") as! TabbarController
            tab.navigationController?.navigationBar.isHidden = true
            let nav = UINavigationController(rootViewController: tab)
            nav.navigationBar.isHidden = true
            if let token = UserDefaults.standard.string(forKey: "accessToken"), !token.isEmpty {
                SocketClient.shared.connect(with: token)
            }
            return nav
        } else {
            // Show splash/login flow
            let splash = UIStoryboard(name: Constants.Storyboard.Main, bundle: nil).instantiateViewController(withIdentifier: "SplashViewController") as! SplashViewController
            splash.navigationController?.navigationBar.isHidden = true
            let nav = UINavigationController(rootViewController: splash)
            nav.navigationBar.isHidden = true
            return nav
        }
    }
}

// Extension to conform to UNUserNotificationCenterDelegate
extension SceneDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])     // <-- CRITICAL
    }
    
    @objc private func handleAuthExpired(_ notification: Notification) {
        SessionLogoutManager.shared.logout(reason: notification.object)
    }
}

extension Notification.Name {
    static let authDidExpire = Notification.Name("authDidExpire")
}
