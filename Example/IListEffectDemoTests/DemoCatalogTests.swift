import SwiftUI
import UIKit
import XCTest
@testable import IListEffectDemo

/// Verifies that the runnable Example exposes every documented integration scenario.
final class DemoCatalogTests: XCTestCase {
    /// Confirms that application launch installs the four expected scenario controllers.
    @MainActor
    func testApplicationLaunchBuildsCompleteCatalog() throws {
        let delegate = try XCTUnwrap(UIApplication.shared.delegate as? AppDelegate)
        let tabController = try XCTUnwrap(delegate.window?.rootViewController as? UITabBarController)
        let viewControllers = try XCTUnwrap(tabController.viewControllers)

        XCTAssertEqual(viewControllers.count, 4)

        let springyNavigation = try XCTUnwrap(viewControllers[0] as? UINavigationController)
        XCTAssertTrue(springyNavigation.topViewController is SpringyCollectionViewController)
        XCTAssertTrue(viewControllers[1] is CollectionDemoViewController)

        let revealNavigation = try XCTUnwrap(viewControllers[2] as? UINavigationController)
        XCTAssertTrue(revealNavigation.topViewController is RevealCollectionViewController)
        XCTAssertTrue(viewControllers[3] is UIHostingController<SwiftUIDemoView>)
    }
}
