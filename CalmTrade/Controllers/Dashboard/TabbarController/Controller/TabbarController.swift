//
//  TabbarController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 28/08/25.
//

import UIKit

class TabbarController: UITabBarController {
    
    //MARK: Properties
    var bottomLineView: UIView!

    let spacing: CGFloat = 12

    override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("[Launch] TabbarController viewDidLoad")
        self.delegate = self
        viewControllers?.forEach { vc in
            (vc as? UINavigationController)?
                .interactivePopGestureRecognizer?
                .isEnabled = false
        }
        CalmScoreHub.shared.start()
        DeviceManager.shared.configureOnLaunch()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2){
            self.addTabbarIndicatorView(index: 0, isFirstTime: true)
        }
    }
    

    //MARK: UDF
    func addTabbarIndicatorView(index: Int, isFirstTime: Bool = false){
        guard let tabView = tabBar.items?[index].value(forKey: "view") as? UIView else {
            return
        }
        if !isFirstTime{
            bottomLineView.removeFromSuperview()
        }
        
        bottomLineView = UIView(frame: CGRect(x: tabView.frame.minX + spacing * 3.0, y: tabView.frame.maxY - 0.1, width: tabView.frame.size.width - spacing * 2.0, height: 2))
        bottomLineView.backgroundColor = .init("#008AFF")
        tabBar.addSubview(bottomLineView)
    }

}

extension TabbarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        addTabbarIndicatorView(index: self.selectedIndex)
    }
}
