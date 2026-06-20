import UIKit
import SwiftUI

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let tab = UITabBarController()
        let table = UINavigationController(rootViewController: TableDemoViewController())
        table.tabBarItem = UITabBarItem(title: "Table", image: UIImage(systemName: "list.bullet"), tag: 0)
        let collection = UINavigationController(rootViewController: CollectionDemoViewController())
        collection.tabBarItem = UITabBarItem(title: "Collection", image: UIImage(systemName: "square.grid.2x2"), tag: 1)
        let swiftui = UIHostingController(rootView: SwiftUIDemoView())
        swiftui.tabBarItem = UITabBarItem(title: "SwiftUI", image: UIImage(systemName: "swift"), tag: 2)
        tab.viewControllers = [table, collection, swiftui]

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = tab
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
