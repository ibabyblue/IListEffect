#if canImport(UIKit)
import UIKit

private var listEffectControllerKey: UInt8 = 0

public extension UIScrollView {
    /// 滚动动效入口。仅对 `UITableView` / `UICollectionView` 有效。
    /// 控制器由 scrollView 通过 associated-object 自持有，使用者无需保存引用。
    /// - Important: 本库会接管可见 cell 的 transform / layer.transform / alpha，请勿再对同一 cell 施加自定义 transform。
    var listEffect: ListEffectController {
        if let c = objc_getAssociatedObject(self, &listEffectControllerKey) as? ListEffectController {
            return c
        }
        guard let host = self as? ListEffectHost else {
            fatalError("listEffect 仅支持 UITableView / UICollectionView")
        }
        let c = ListEffectController(host: host)
        objc_setAssociatedObject(self, &listEffectControllerKey, c, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return c
    }
}
#endif
