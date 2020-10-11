//
//  LoginManager.swift
//  F1TV
//
//  Created by Adam Bell on 10/10/20.
//

import Foundation
import KeychainAccess
import UIKit

class LoginManager {

    private enum KeychainItems: String {
        case username
        case password
    }

    static let shared = LoginManager()

    let keychain = Keychain(service: "ca.adambell.f1tv")

    var loggedIn: Bool {
        return username != nil && password != nil
    }

    private(set) var username: String? {
        get {
            return keychain[KeychainItems.username.rawValue]
        }
        set {
            keychain[KeychainItems.username.rawValue] = newValue
        }
    }

    private(set) var password: String? {
        get {
            return keychain[KeychainItems.password.rawValue]
        }
        set {
            keychain[KeychainItems.password.rawValue] = newValue
        }
    }

    func login(parentViewController: UIViewController, completion: @escaping (Bool) -> Void) {
        logout()

        let alertController = UIAlertController(title: "F1TV", message: "Enter your login credentials for F1TV. You must be a subscriber to use this application.", preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.placeholder = "Email Address"
            textField.keyboardType = .emailAddress
        }

        alertController.addTextField { (textField) in
            textField.placeholder = "Password"
            textField.isSecureTextEntry = true
        }

        let loginAction = UIAlertAction(title: "Sign In", style: .default) { [weak alertController, weak self] (action) in
            let failure = { [weak alertController] in
                let failureAlertController = UIAlertController(title: "Failed to Sign In", message: "Please double check your login credentials and try again.", preferredStyle: .alert)
                failureAlertController.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                alertController?.present(failureAlertController, animated: true, completion: nil)
            }

            guard let username = alertController?.textFields?[0].text, let password = alertController?.textFields?[1].text else {
                failure()
                return
            }

            F1TV.shared.login(username: username, password: password) { [weak self] (successful) in
                if successful {
                    self?.username = username
                    self?.password = password

                    alertController?.parent?.dismiss(animated: true, completion: nil)
                    completion(successful)
                    return
                } else {
                    failure()
                    completion(false)
                }
            }
        }

        alertController.addAction(loginAction)
        parentViewController.present(alertController, animated: true, completion: nil)
    }

    private func logout() {
        self.username = nil
        self.password = nil
    }

    func logout(parentViewController: UIViewController, completion: @escaping () -> Void) {
        let alertController = UIAlertController(title: "F1TV", message: "Are you sure you want to sign out?", preferredStyle: .alert)

        let logoutAction = UIAlertAction(title: "Sign Out", style: .destructive) { [weak self] (action) in
            self?.logout()
            completion()
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

        alertController.addAction(logoutAction)
        alertController.addAction(cancelAction)
        
        parentViewController.present(alertController, animated: true, completion: nil)
    }


}
