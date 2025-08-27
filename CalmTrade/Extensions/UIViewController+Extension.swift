//
//  UIViewController+Extension.swift
//  CalmTrade
//
//  Created by Anas Parekh on 27/08/25.
//

import UIKit

// MARK: - TransitionType Enum

/// Defines the type and direction of the transition animation.
enum TransitionType {
    case push(from: CATransitionSubtype)
    case pop(from: CATransitionSubtype)
    case fade
    case reveal
    case moveIn(direction: CATransitionSubtype)
    
    
    /// The Core Animation transition type.
    var animationType: CATransitionType {
        switch self {
        case .push, .pop:
            return .push
        case .fade:
            return .fade
        case .reveal:
            return .reveal
        case .moveIn:
            return .moveIn
        }
    }
}

// MARK: - UINavigationController Extension

/// This extension adds custom, animated transition methods to UINavigationController.
extension UINavigationController {

    // MARK: - Public Transition Methods

    /// Pushes a view controller onto the receiver’s stack with a custom animation.
    /// This method also prevents pushing a view controller of the same class if one already exists.
    ///
    /// - Parameters:
    ///   - viewController: The view controller to push onto the stack.
    ///   - transitionType: The type of transition to use. Defaults to a fade.
    ///   - duration: The duration of the transition animation. Defaults to 0.4 seconds.
    func pushViewController(_ viewController: UIViewController,
                            transitionType: TransitionType = .fade,
                            duration: CFTimeInterval = 0.4) {
        
        // Prevent pushing a duplicate view controller of the same class.
        if let existingVC = self.viewControllers.first(where: { type(of: $0) == type(of: viewController) }) {
            // If it exists, just pop back to it.
            self.popToViewController(existingVC, animated: true)
            return
        }
        self.addTransition(transitionType: transitionType, duration: duration)
        pushViewController(viewController, animated: false)
    }

    /// Pops the top view controller from the navigation stack with a custom animation.
    ///
    /// - Parameters:
    ///   - transitionType: The type of transition to use. Defaults to a fade.
    ///   - duration: The duration of the transition animation. Defaults to 0.4 seconds.
    func popViewController(transitionType: TransitionType = .fade,
                           duration: CFTimeInterval = 0.4) {
        
        self.addTransition(transitionType: transitionType, duration: duration)
        popViewController(animated: false)
    }
    
    /// Pops view controllers until the specified view controller is at the top of the navigation stack, using a custom animation.
    ///
    /// - Parameters:
    ///   - viewController: The view controller to pop to.
    ///   - transitionType: The type of transition to use. Defaults to a fade.
    ///   - duration: The duration of the transition animation. Defaults to 0.4 seconds.
    func popToViewController(_ viewController: UIViewController,
                             transitionType: TransitionType = .fade,
                             duration: CFTimeInterval = 0.4) {
        
        self.addTransition(transitionType: transitionType, duration: duration)
        popToViewController(viewController, animated: false)
    }

    // MARK: - Private Helper

    /// A private helper function to create and add the CATransition to the view's layer.
    private func addTransition(transitionType: TransitionType, duration: CFTimeInterval) {
        let transition = CATransition()
        transition.duration = duration
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        transition.type = transitionType.animationType
        
        // Set the direction of the transition (subtype) if applicable.
        switch transitionType {
        case .push(let subtype):
            transition.subtype = subtype
        case .pop(let subtype):
            transition.subtype = subtype
        case .fade:
            // Fade transitions don't have a subtype.
            break
        case .reveal:
            break
        case .moveIn(direction: let direction):
            transition.subtype = direction
        }
        
        self.view.layer.add(transition, forKey: kCATransition)
    }
}
