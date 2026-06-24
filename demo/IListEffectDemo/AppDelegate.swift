import UIKit
import SwiftUI

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let tab = UITabBarController()
        let springy = UINavigationController(rootViewController: SpringyCollectionViewController())
        springy.tabBarItem = UITabBarItem(title: "Springy", image: UIImage(systemName: "wave.3.right"), tag: 0)
        let collection = CollectionDemoViewController()
        collection.tabBarItem = UITabBarItem(title: "Slide In", image: UIImage(systemName: "square.grid.2x2"), tag: 1)
        let reveal = UINavigationController(rootViewController: RevealCollectionViewController())
        reveal.tabBarItem = UITabBarItem(title: "Reveal", image: UIImage(systemName: "rectangle.dashed"), tag: 2)
        let swiftuiReveal = UIHostingController(rootView: SwiftUIDemoView())
        swiftuiReveal.tabBarItem = UITabBarItem(title: "SwiftUI Reveal", image: UIImage(systemName: "swift"), tag: 3)
        tab.viewControllers = [springy, collection, reveal, swiftuiReveal]

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = tab
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
