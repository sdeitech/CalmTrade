//
//  ProfileTabsHostViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 27/10/25.
//

import UIKit
import KRProgressHUD

final class ProfileTabsHostViewController: UIViewController {

    // MARK: - Outlets (match your storyboard)
    @IBOutlet weak var tabProfileView: UIView!
    @IBOutlet weak var tabSecurityView: UIView!
    @IBOutlet weak var tabPolarView: UIView!
    @IBOutlet weak var tabSettingsView: UIView!

    @IBOutlet weak var profileIcon: UIImageView!
    @IBOutlet weak var securityIcon: UIImageView!
    @IBOutlet weak var polarIcon: UIImageView!
    @IBOutlet weak var settingsIcon: UIImageView!
    
    @IBOutlet weak var lblProfileTitle: UILabel!
    @IBOutlet weak var lblSecurityTitle: UILabel!
    @IBOutlet weak var lblPolarTitle: UILabel!
    @IBOutlet weak var lblSettingsTitle: UILabel!

    // You created these earlier; they are no longer needed when using PageVC.
    // Keep them optional so IB connections don’t break. We just ignore them.
    @IBOutlet weak var profileContent: UIView!
    @IBOutlet weak var securityContent: UIView!
    @IBOutlet weak var polarContent: UIView!
    @IBOutlet weak var settingsContent: UIView!

    // MARK: - PageVC (embedded via Container View → Embed segue)
    private weak var pageVC: UIPageViewController?
    private var pages: [UIViewController] = []
    private var currentIndex: Int = 0

    // MARK: - ViewModels
    private let tabsVM = TabsHostViewModel(initial: .profile)
    private let deleteAccountViewModel = DeleteAccountViewModel()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Gestures → VM
        tabProfileView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTapProfile)))
        tabSecurityView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTapSecurity)))
        tabPolarView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTapPolar)))
        tabSettingsView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTapSettings)))
        [tabProfileView, tabSecurityView, tabPolarView, tabSettingsView].forEach { $0?.isUserInteractionEnabled = true }

        // Bind VM → UI
        bindViewModels()

        // Build pages after pageVC is ready (see prepare(for segue:))
        // But still push initial icons/state right away:
        tabsVM.bootstrap()
    }

    // The Container View’s embed segue will hit here, giving us the UIPageViewController.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let pvc = segue.destination as? UIPageViewController {
            pageVC = pvc
            pageVC?.dataSource = self
            pageVC?.delegate = self

            // Build pages from the SAME storyboard this VC lives in
            pages = [
                makeProfilePage(),
                makeSecurityPage(),
                makePolarUpgradePage(),
                makeSettingPage()
            ]
            currentIndex = tabsVM.selectedIndex

            // Set initial page instantly (no animation)
            pageVC?.setViewControllers([pages[currentIndex]], direction: .forward, animated: false)
        }
    }

    // MARK: - VM bindings
    private func bindViewModels() {
        // Icons for the 4 tabs (single image view per tab)
        tabsVM.onTabIconNames = { [weak self] prof, sec, pol, set in
            self?.profileIcon.image  = UIImage(named: prof)
            self?.securityIcon.image = UIImage(named: sec)
            self?.polarIcon.image    = UIImage(named: pol)
            self?.settingsIcon.image = UIImage(named: set)
        }

        // Change page when VM tab changes
        tabsVM.onTabChange = { [weak self] tab in
            guard let self = self,
                  let pageVC = self.pageVC,
                  !self.pages.isEmpty
            else { return }
            
            lblProfileTitle.textColor = tab == .profile ? self.profileContent.backgroundColor : .white
            lblSecurityTitle.textColor = tab == .security ? self.securityContent.backgroundColor : .white
            lblPolarTitle.textColor    = tab == .polar ? self.polarContent.backgroundColor : .white
            lblSettingsTitle.textColor = tab == .settings ? self.settingsContent.backgroundColor : .white
            
            profileContent.isHidden  = tab != .profile
            securityContent.isHidden = tab != .security
            polarContent.isHidden    = tab != .polar
            settingsContent.isHidden = tab != .settings

            let newIndex = self.tabsVM.index(for: tab)
            guard newIndex != self.currentIndex else { return }

            let direction: UIPageViewController.NavigationDirection = (newIndex > self.currentIndex) ? .forward : .reverse
            let vc = self.pages[newIndex]
            pageVC.setViewControllers([vc], direction: direction, animated: true)

            self.currentIndex = newIndex
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        deleteAccountViewModel.onLoading = { isLoading in
            isLoading ? KRProgressHUD.show() : KRProgressHUD.dismiss()
        }

        deleteAccountViewModel.onSuccess = { [weak self] in
            guard let self else { return }

            // Clear everything
            UserDefaults.standard.removePersistentDomain(
                forName: Bundle.main.bundleIdentifier!
            )
            SocketClient.shared.disconnect()

            let loginVC = UIStoryboard(
                name: Constants.Storyboard.Main,
                bundle: nil
            ).instantiateViewController(withIdentifier: "LoginViewController") as! LoginViewController

            self.navigationController?.setViewControllers([loginVC], animated: true)
        }

        deleteAccountViewModel.onError = { [weak self] msg in
            let alert = UIAlertController(
                title: "Error",
                message: msg,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }

    }

    // MARK: - Page builders
    private func makeProfilePage() -> UIViewController {
        let vc = storyboard!.instantiateViewController(withIdentifier: "ProfileListViewController") as! ProfileListViewController
        let vm = ProfileListViewModel()
        vc.viewModel = vm

        // Navigation from Profile rows → host/router
        vm.onRoute = { [weak self] action in
            guard let self = self else { return }
            switch action {
            case .manageSubscriptions:
                self.navigationController?.pushViewController(UIStoryboard(name: Constants.Storyboard.Profile, bundle: nil).instantiateViewController(withIdentifier: "SubscriptionViewController") as! SubscriptionViewController, transitionType: .moveIn(direction: .fromLeft))
            case .setAccountBalance:
                let balanceVC = UIStoryboard(name: Constants.Storyboard.Profile, bundle: nil).instantiateViewController(withIdentifier: "SetBalanceViewController") as! SetBalanceViewController
                self.navigationController?.pushViewController(balanceVC, transitionType: .moveIn(direction: .fromLeft))
            case .emotionalTags:
                let manageEmotionVC = UIStoryboard(name: Constants.Storyboard.Profile, bundle: nil).instantiateViewController(withIdentifier: "ManageEmotionsViewController") as! ManageEmotionsViewController
                self.navigationController?.pushViewController(manageEmotionVC, transitionType: .moveIn(direction: .fromLeft))
            case .accountDetails:
                let accountDetailVC = UIStoryboard(name: Constants.Storyboard.Profile, bundle: nil).instantiateViewController(withIdentifier: "AccountDetailsViewController") as! AccountDetailsViewController
                accountDetailVC.configure(accessToken: UserDefaults.standard.string(forKey: "access_token") ?? "")
                self.navigationController?.pushViewController(accountDetailVC, transitionType: .moveIn(direction: .fromLeft))
            case .setLocalTimeZone:
                let timeZone = UIStoryboard(name: Constants.Storyboard.Profile, bundle: nil).instantiateViewController(withIdentifier: "LocalTimeZoneViewController") as! LocalTimeZoneViewController
                timeZone.hidesBackButton = false
                self.navigationController?.pushViewController(timeZone, transitionType: .moveIn(direction: .fromLeft))
            case .device:
                let device = UIStoryboard(name: Constants.Storyboard.Devices, bundle: nil).instantiateViewController(withIdentifier: "DeviceManagementViewController") as! DeviceManagementViewController
                self.navigationController?.pushViewController(device, animated: true)
            }
        }
        return vc
    }

    private func makeSecurityPage() -> UIViewController {
        let vc = storyboard!.instantiateViewController(withIdentifier: "SecurityListViewController") as! SecurityListViewController
        let handler = UserDefaults.standard.string(forKey: kLoginHandler)
        let isEmailLogin = handler == LoginHandler.email.rawValue
        let vm = SecurityListViewModel()
        vc.viewModel = vm

        vm.onRoute = { [weak self] action in
            guard let self = self else { return }
            switch action {
            case .changePassword:
                if isEmailLogin {
                    let changePasswordVC = UIStoryboard(name: Constants.Storyboard.Security, bundle: nil)
                        .instantiateViewController(withIdentifier: "ChangePasswordViewController") as! ChangePasswordViewController
                    self.navigationController?.pushViewController(changePasswordVC)
                } else {
                    self.showAlert(
                        message: "This action isn’t available for social sign-in accounts. Please use an email login to manage this setting."
                    )
                }
            case .changeEmail:
                if isEmailLogin {
                    let changeEmailVC = UIStoryboard(name: Constants.Storyboard.Security, bundle: nil)
                        .instantiateViewController(withIdentifier: "ChangeEmailViewController") as! ChangeEmailViewController
                    self.navigationController?.pushViewController(changeEmailVC)
                } else {
                    self.showAlert(
                        message: "This action isn’t available for social sign-in accounts. Please use an email login to manage this setting."
                    )
                }
            case .twoFactor:
                if isEmailLogin {
                    let twoFactorVC = UIStoryboard(name: Constants.Storyboard.Security, bundle: nil)
                        .instantiateViewController(withIdentifier: "TwoFactorViewController") as! TwoFactorViewController
                    self.navigationController?.pushViewController(twoFactorVC)
                } else {
                    self.showAlert(
                        message: "This action isn’t available for social sign-in accounts. Please use an email login to manage this setting."
                    )
                }
            case .dataManagement:
                let dataManageVC = UIStoryboard(name: Constants.Storyboard.Security, bundle: nil)
                    .instantiateViewController(withIdentifier: "DataManagementViewController") as! DataManagementViewController
                self.navigationController?.pushViewController(dataManageVC)
            }
        }
        return vc
    }
    
    private func makeSettingPage() -> UIViewController {
        let vc = storyboard!.instantiateViewController(withIdentifier: "AppSettingViewController") as! AppSettingViewController
        let handler = UserDefaults.standard.string(forKey: kLoginHandler)
        let isEmailLogin = handler == LoginHandler.email.rawValue
        let vm = AppSettingViewModel()
        vc.viewModel = vm

        vm.onRoute = { [weak self] action in
            guard let self = self else { return }
            switch action {
            case .notification:
                let notificationSettingVC = UIStoryboard(name: Constants.Storyboard.Setting, bundle: nil)
                    .instantiateViewController(withIdentifier: "NotificationSettingsViewController") as! NotificationSettingsViewController
                self.navigationController?.pushViewController(notificationSettingVC)
            case .connectWearable:
                let twoFactorVC = UIStoryboard(name: Constants.Storyboard.Devices, bundle: nil)
                    .instantiateViewController(withIdentifier: "PolarConnectionViewController") as! PolarConnectionViewController
                self.navigationController?.pushViewController(twoFactorVC)
            case .deleteAccount:
                let sheet = DeleteAccountBottomSheetViewController()
                sheet.modalPresentationStyle = .overFullScreen
                sheet.modalTransitionStyle = .crossDissolve

                sheet.onConfirm = { [weak self] in
                    guard let self else { return }

                    let userId = SessionManager.shared.current?.id
                    self.deleteAccountViewModel.deleteAccount(userId: userId ?? "")
                }

                present(sheet, animated: true)
            case .logout:
                let sheet = LogoutBottomSheetViewController()
                sheet.modalPresentationStyle = .overFullScreen
                sheet.modalTransitionStyle = .crossDissolve

                sheet.onConfirm = { [weak self] in
                    UserDefaults.standard.removeObject(forKey: "accessToken")
                    SocketClient.shared.disconnect()

                    let loginVC = UIStoryboard(
                        name: Constants.Storyboard.Main,
                        bundle: nil
                    ).instantiateViewController(withIdentifier: "LoginViewController") as! LoginViewController

                    self?.navigationController?.setViewControllers([loginVC], animated: true)
                }

                present(sheet, animated: true)
            }
        }
        return vc
    }

    private func makePolarUpgradePage() -> UIViewController {
        // Your UICollectionViewController storyboard ID
        let vc = storyboard!.instantiateViewController(withIdentifier: "PolarBundleViewController") as! PolarBundleViewController
        return vc
    }

//    private func makeSettingsPage() -> UIViewController {
//        storyboard!.instantiateViewController(withIdentifier: "SecurityListViewController")
//    }

    // MARK: - Tab actions → VM
    @objc private func onTapProfile()  { tabsVM.select(tab: .profile) }
    @objc private func onTapSecurity() { tabsVM.select(tab: .security) }
    @objc private func onTapPolar()    { tabsVM.select(tab: .polar) }
    @objc private func onTapSettings() { tabsVM.select(tab: .settings) }
    
    
    //MARK: - Actions
    @IBAction func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController()
    }
}

// MARK: - PageVC DS/Delegate
extension ProfileTabsHostViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let i = pages.firstIndex(of: viewController), i > 0 else { return nil }
        return pages[i - 1]
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let i = pages.firstIndex(of: viewController), i < pages.count - 1 else { return nil }
        return pages[i + 1]
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed, let vc = pageViewController.viewControllers?.first,
              let idx = pages.firstIndex(of: vc) else { return }
        currentIndex = idx
        // Keep VM in sync so icons update when user swipes
        tabsVM.select(index: idx)
    }
}
