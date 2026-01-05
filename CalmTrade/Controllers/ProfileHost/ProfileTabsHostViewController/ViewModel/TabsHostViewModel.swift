//
//  TabsHostViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 27/10/25.
//

import Foundation

final class TabsHostViewModel {

    enum Tab: Int { case profile = 0, security, polar, settings }

    // MARK: - Outputs
    var onTabChange: ((Tab) -> Void)?
    /// Emits the asset names for the 4 tab icons (in order: profile, security, polar, settings)
    var onTabIconNames: ((_ profile: String, _ security: String, _ polar: String, _ settings: String) -> Void)?

    // MARK: - State
    private(set) var selected: Tab
    var selectedIndex: Int { selected.rawValue }

    // MARK: - Assets
    private let selectedImgs: [Tab: String] = [
        .profile:  "profile_selected",
        .security: "security_selected",
        .polar:    "polar_bundle_selected",
        .settings: "setting_selected"
    ]
    private let unselectedImgs: [Tab: String] = [
        .profile:  "profile_unselected",
        .security: "security_unselected",
        .polar:    "polar_bundle_unselected",
        .settings: "setting_unselected"
    ]

    // MARK: - Init
    init(initial: Tab = .profile) {
        self.selected = initial
    }

    // MARK: - Public API
    func index(for tab: Tab) -> Int { tab.rawValue }

    func select(index: Int) {
        guard let t = Tab(rawValue: index) else { return }
        select(tab: t)
    }

    func select(tab: Tab) {
        // Update state then emit changes
        selected = tab
        emitIcons(for: tab)
        onTabChange?(tab)
    }

    /// Call once after wiring closures to push initial state to the VC
    func bootstrap() {
        emitIcons(for: selected)
        onTabChange?(selected) // emit once so VC can sync UI if needed
    }

    // MARK: - Private
    private func emitIcons(for tab: Tab) {
        let prof = (tab == .profile)  ? selectedImgs[.profile]!  : unselectedImgs[.profile]!
        let sec  = (tab == .security) ? selectedImgs[.security]! : unselectedImgs[.security]!
        let pol  = (tab == .polar)    ? selectedImgs[.polar]!    : unselectedImgs[.polar]!
        let set  = (tab == .settings) ? selectedImgs[.settings]! : unselectedImgs[.settings]!
        onTabIconNames?(prof, sec, pol, set)
    }
}
