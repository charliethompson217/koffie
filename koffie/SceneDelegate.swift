//
//  SceneDelegate.swift
//  koffie
//
//  Created by charles thompson on 5/8/24.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // Create a UIWindow using the windowScene
        let window = UIWindow(windowScene: windowScene)

        // Set the root view controller to your ViewController
        let viewController = ViewController()
        window.rootViewController = viewController

        // Make this window the key window and visible
        self.window = window
        window.makeKeyAndVisible()
    }
}
