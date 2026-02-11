//
//  SceneDelegate.swift
//  CalmTrade
//
//  Created by Developer on 1/24/26.
//

import UIKit
import FirebaseCore
import GoogleSignIn
import IQKeyboardManagerSwift
import FBSDKCoreKit
import BackgroundTasks
import FirebaseCrashlytics
import StoreKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    private var polarSyncService: Polar360SyncService!

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // EARLIEST INITIALIZATION - Firebase must be configured before any other Firebase services are accessed
        // Only configure Firebase if it hasn't been configured elsewhere (e.g., AppDelegate for iOS 12 and earlier)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

        // 1. FASTEST POSSIBLE UI SETUP
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = initialRootViewController()
        window.makeKeyAndVisible()
        self.window = window

        let center = UNUserNotificationCenter.current()
        center.delegate = self    // REQUIRED
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("Notification permission granted: \(granted)")
        }

        // 2. OTHER LIGHTWEIGHT CRITICAL INITIALIZATION
        IQKeyboardManager.shared.enableAutoToolbar = true
        IQKeyboardManager.shared.isEnabled = true

        // Initialize StoreKit helper to prevent authentication errors
//        StoreKitHelper.shared.configureStoreKit()

        // Initialize Core Data without blocking UI (deferring heavy work until after UI is visible)
        DispatchQueue.main.async {
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                _ = appDelegate.persistentContainer.viewContext
            }
        }

        // 3. DEFER ALL HEAVY WORK (runs after UI is visible)
        DispatchQueue.global(qos: .userInitiated).async {
            self.initializeBackgroundSystems(scene, session: session, connectionOptions: connectionOptions)
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthExpired),
            name: .authDidExpire,
            object: nil
        )
    }
    
    // MARK: - Deferred initialization
    private func initializeBackgroundSystems(
        _ scene: UIScene,
        session: UISceneSession,
        connectionOptions: UIScene.ConnectionOptions
    ) {
        // Initialize Polar ingestion services in background
        DispatchQueue.global(qos: .background).async {
            let polarSleepSource = PolarBleSleepSource()
            Polar360SleepIngestor.shared.configure(source: polarSleepSource)

            PolarManager.shared.on360OfflinePpg = { ppg, start in
                guard let devId = PolarManager.shared.connectedDevice?.id else { return }
                _ = OfflinePPGIngestor.shared.ingest(
                    deviceId: devId,
                    start: start,
                    ppg: ppg,
                    sampleRateHz: 40
                )
            }
        }

        // Initialize Facebook SDK asynchronously to prevent blocking
        DispatchQueue.global(qos: .background).async {
            FacebookManager.shared.configureFacebookSDK()
        }

        // Register background tasks
        DispatchQueue.global(qos: .background).async {
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: "com.calmtrade.calmScore.refresh",
                using: nil
            ) { task in
                self.handleCalmScoreRefresh(task: task as! BGAppRefreshTask)
            }

            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: "com.calmtrade.calmScore.processing",
                using: nil
            ) { task in
                self.handleCalmScoreProcessing(task: task as! BGProcessingTask)
            }

            self.scheduleCalmScoreRefresh()
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
