//
//  AppDelegate.swift
//  CalmTrade
//
//  Created by Anas Parekh on 22/08/25.
//

import UIKit
import CoreData
import FirebaseCore
import GoogleSignIn
import IQKeyboardManagerSwift
import FBSDKCoreKit
import BackgroundTasks
import FirebaseCrashlytics

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    var window: UIWindow?
    
    private var bgTask: UIBackgroundTaskIdentifier = .invalid
    
    private var polarSyncService: Polar360SyncService!
    
//    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//        
//        let win = UIWindow(frame: UIScreen.main.bounds)
//        win.rootViewController = initialRootViewController()
//        win.makeKeyAndVisible()
//        self.window = win
//        
//        // Override point for customization after application launch.
//        FirebaseApp.configure()
//        
//        IQKeyboardManager.shared.enableAutoToolbar = true
//        IQKeyboardManager.shared.isEnabled = true
//        
//        //        CalmScoreHub.shared.start()
//        
//        DeviceManager.shared.configureOnLaunch()
//        
//        // Create the sync service with your real fetcher (adapter is shown below)
////        polarSyncService = Polar360SyncService(fetcher: PolarCloudFetcher())
//        let polarSleepSource = PolarBleSleepSource()
//        Polar360SleepIngestor.shared.configure(source: polarSleepSource)
//
//        // Trigger a sleep fetch the moment we ingest any offline PPG from 360/OH1/Verity
//        // In AppDelegate.didFinishLaunching (after DeviceManager.configureOnLaunch())
//        PolarManager.shared.on360OfflinePpg = { ppg, start in
//            guard let devId = PolarManager.shared.connectedDevice?.id else { return }
//            _ = OfflinePPGIngestor.shared.ingest(deviceId: devId, start: start, ppg: ppg, sampleRateHz: 40)
//        }
//        
//        // --- START FACEBOOK SDK CONFIGURATION ---
//        
//        // 1. Manually provide the App ID and other required settings.
//        Settings.shared.appID = "1439790770608266"
//        Settings.shared.clientToken = "893bcbdd5f41249f62748adba97e1687"
//        Settings.shared.displayName = "CalmTrade"
//        
//        // 2. This is the programmatic equivalent of the Info.plist setup.
//        ApplicationDelegate.shared.application(
//            application,
//            didFinishLaunchingWithOptions: launchOptions
//        )
//        
//        // --- END FACEBOOK SDK CONFIGURATION ---
//        
//        BGTaskScheduler.shared.register(
//            forTaskWithIdentifier: "com.calmtrade.calmScore.refresh",
//            using: nil
//        ) { task in
//            self.handleCalmScoreRefresh(task: task as! BGAppRefreshTask)
//        }
//        
//        BGTaskScheduler.shared.register(
//            forTaskWithIdentifier: "com.calmtrade.calmScore.processing",
//            using: nil
//        ) { task in
//            self.handleCalmScoreProcessing(task: task as! BGProcessingTask)
//        }
//        
//        scheduleCalmScoreRefresh()
//        
//        return true
//    }
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // EARLIEST INITIALIZATION - Firebase must be configured before any other Firebase services are accessed
        // Only configure Firebase if it hasn't been configured elsewhere (e.g., SceneDelegate for iOS 13+)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

        // Initialize other lightweight services
        IQKeyboardManager.shared.enableAutoToolbar = true
        IQKeyboardManager.shared.isEnabled = true

        // Request notification permissions
        let center = UNUserNotificationCenter.current()
        center.delegate = self    // REQUIRED
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("Notification permission granted: \(granted)")
        }

        // Check if we're running on iOS 13+ and should defer UI setup to SceneDelegate
        if #available(iOS 13.0, *) {
            // On iOS 13+, UI setup is handled by SceneDelegate
        } else {
            // On iOS 12 and earlier, setup UI in AppDelegate
            let win = UIWindow(frame: UIScreen.main.bounds)
            win.rootViewController = initialRootViewController()
            win.makeKeyAndVisible()
            self.window = win
        }

        // 3. DEFER ALL HEAVY WORK (runs after UI is visible)
        DispatchQueue.global(qos: .userInitiated).async {
            self.initializeBackgroundSystems(application, launchOptions: launchOptions)
        }

        return true
    }

    // MARK: - Deferred initialization
    private func initializeBackgroundSystems(
        _ application: UIApplication,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) {
        // Initialize Core Data in background to prevent blocking main thread
        DispatchQueue.global(qos: .utility).async {
            _ = self.persistentContainer.viewContext
        }

        // Initialize Polar ingestion services
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
            ApplicationDelegate.shared.application(
                application,
                didFinishLaunchingWithOptions: launchOptions
            )
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
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

        // Stop unnecessary background activity to preserve battery and avoid hanging
        CalmScoreHub.shared.stop()  // Stop the continuous heartbeat in background
        // NOTE: HealthKitService keeps running in background for background delivery

        scheduleCalmScoreRefresh()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.

        // Restart services when entering foreground
        CalmScoreHub.shared.start()  // Restart calm score calculations
        HealthKitService.shared.startBackgroundMirroring()  // Resume HealthKit monitoring

        PolarManager.shared.resumeAutoReconnectOnForeground()
        if let token = UserDefaults.standard.string(forKey: "accessToken"), !token.isEmpty {
            SocketClient.shared.connect(with: token)
        }

        // Ask PolarManager to keep the BLE session warm during transition
                bgTask = application.beginBackgroundTask(withName: "BLEStreamStabilize") { [weak self] in
                    // Expiration handler: end task if the system is done with us
                    if let t = self?.bgTask, t != .invalid {
                        application.endBackgroundTask(t)
                        self?.bgTask = .invalid
                    }
                }
                PolarManager.shared.appDidEnterBackground {
                    // Call this once streams are confirmed stable / no pending work
                    if self.bgTask != .invalid {
                        application.endBackgroundTask(self.bgTask)
                        self.bgTask = .invalid
                    }
                }
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
    }
    
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        #if !targetEnvironment(macCatalyst)
        // Handle Facebook URL (only on iOS, not Mac Catalyst)
        if ApplicationDelegate.shared.application(app, open: url, options: options) {
            return true
        }
        #endif

        // Handle Google URL
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }

        // Handle deep links
        DeepLinkRouter.shared.handle(url: url)

        return true
    }
    
    // MARK: - Core Data stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "CalmTrade")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
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
    
    // ✅ Universal Links: https://www.calmtrade.com/verify-email/<token>
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else { return false }
        DeepLinkRouter.shared.handle(url: url)
        return true
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])     // <-- CRITICAL
    }
}

private extension AppDelegate {
    
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
