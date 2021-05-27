//
//  RootViewController.swift
//  F1TV
//
//  Created by Adam Bell on 10/10/20.
//

import Foundation
import UIKit
import TVUIKit

class RootViewController: UINavigationController {

    let optionsButton: UIButton

    var seasonViewControllers: [SeasonViewController]!

    var weekendGrandPrixEventViewController: EventViewController?

    init() {
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [UIViewController()]
        self.optionsButton = UIButton(type: .system)
        super.init(rootViewController: tabBarController)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        optionsButton.addTarget(self, action: #selector(logout), for: [.touchUpInside, .primaryActionTriggered])
        let configuration = UIImage.SymbolConfiguration(pointSize: 44.0, weight: .regular, scale: .small)
        optionsButton.setImage( UIImage(systemName: "gearshape.fill", withConfiguration: configuration), for: .normal)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard let tabBarController = self.viewControllers.first as? UITabBarController else {
            return
        }
        if optionsButton.superview == nil {
            tabBarController.view.addSubview(optionsButton)
        }
        optionsButton.sizeToFit()
        optionsButton.frame = CGRect(x: tabBarController.tabBar.bounds.size.width - 54.0 - optionsButton.bounds.size.width, y: (tabBarController.tabBar.frame.maxY + ((tabBarController.tabBar.bounds.size.height - optionsButton.bounds.size.height) / 2.0)), width: optionsButton.bounds.size.width, height: optionsButton.bounds.size.height)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if LoginManager.shared.loggedIn {
            loadSeasons()
        } else {
            login()
        }
    }

    // MARK: - Login Handling

    private func login() {
        LoginManager.shared.login(parentViewController: self) { [weak self] (successful) in
            if successful {
                self?.loadSeasons()
            } else {
                self?.login()
            }
        }
    }

    @objc private func logout() {
        LoginManager.shared.logout(parentViewController: self) { [weak self] in
            self?.login()
        }
    }

    private func loadSeasons() {
        if !LoginManager.shared.loggedIn {
            return
        }

        F1TV.shared.login(username: LoginManager.shared.username!, password: LoginManager.shared.password!) { [weak self] (authorizedSuccessfully) in
            if authorizedSuccessfully {
                let currentYear = Calendar.current.component(.year, from: Date())
                F1TV.shared.getSeasons { [weak self] (seasons) in
                    guard let seasons = seasons else {
                        print("error loading seasons")
                        return
                    }

                    let seasonsFilteredAndSorted = seasons
                        .filter { (currentYear-5...currentYear).contains($0.year) }
                        .sorted { $0.year > $1.year }

                    let seasonViewControllers = seasonsFilteredAndSorted.map { (partialSeason) -> SeasonViewController in
                        return SeasonViewController(partialSeason: partialSeason)
                    }
                    self?.seasonViewControllers = seasonViewControllers

                    self?.updateTabBarController()
                }
            }
        }

        refreshWeekendGrandPrixItem()
    }

    // MARK: - Weekend Grand Prix

    func refreshWeekendGrandPrixItem() {
        if !LoginManager.shared.loggedIn {
            return
        }

        if weekendGrandPrixEventViewController != nil {
            tabBarController?.viewControllers?.removeAll { $0 == weekendGrandPrixEventViewController }
            weekendGrandPrixEventViewController = nil
        }

        F1TV.shared.getRaceWeekend_v2() { [weak self] event in
            if let event = event {
                let eventViewController = EventViewController(partialEvent: event)
                eventViewController.tabBarItem = UITabBarItem(title: event.name, image: nil, selectedImage: nil)

                self?.weekendGrandPrixEventViewController = eventViewController

                self?.updateTabBarController()
            }
        }
    }

    private func updateTabBarController() {
        guard let tabBarController = self.viewControllers.first as? UITabBarController else {
            fatalError()
        }

        var viewControllers = [UIViewController]()
        if let weekendGrandPrixEventViewController = weekendGrandPrixEventViewController {
            viewControllers.append(weekendGrandPrixEventViewController)
        }

        if let seasonViewControllers = seasonViewControllers {
            viewControllers.append(contentsOf: seasonViewControllers)
        }

        tabBarController.viewControllers = viewControllers
    }

}
