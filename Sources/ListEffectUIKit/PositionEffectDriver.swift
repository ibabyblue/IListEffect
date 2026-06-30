#if canImport(UIKit)
import UIKit
import ListEffectCore

/// 位置型 scroll-linked 驱动器：KVO 监听 contentOffset，把每个可见 cell 的归一化位置
/// 交给 effect.resolve(position:) 并应用。不接管宿主 delegate。
public final class PositionEffectDriver: NSObject {
    private weak var scrollView: UIScrollView?
    private var effect: PositionEffect?
    private var observation: NSKeyValueObservation?

    public init(scrollView: UIScrollView) {
        self.scrollView = scrollView
        super.init()
    }

    public func attach(_ effect: PositionEffect) {
        self.effect = effect
        startObserving()
        apply()
    }

    public func detach() {
        observation?.invalidate()
        observation = nil
        effect = nil
        guard let sv = scrollView else { return }
        resetAll(in: sv)
    }

    /// 主动刷新当前可见 cell。适用于 reload、bounds 变化、静止插入/删除后没有 contentOffset 变化的场景。
    public func applyNow() {
        apply()
    }

    /// 归一化位置：居中 0，到/超视口边缘 ±1+。纯函数，可单测。
    static func normalizedPosition(cellCenter: CGFloat, viewportCenter: CGFloat, viewportHeight: CGFloat) -> CGFloat {
        guard viewportHeight > 0 else { return 0 }
        return (cellCenter - viewportCenter) / (viewportHeight / 2)
    }

    /// 视口中心在 content 坐标系的位置。
    /// UIScrollView 的 bounds.origin == contentOffset，故 bounds.midY 已含 contentOffset——
    /// 直接用 bounds.midY，切勿再 + contentOffset.y（会重复叠加，cell 越滚越偏 → 全淡出）。
    static func viewportCenter(of scrollView: UIScrollView) -> CGFloat {
        scrollView.bounds.midY
    }

    private func startObserving() {
        observation?.invalidate()
        guard let sv = scrollView else { return }
        observation = sv.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
            // contentOffset 的 KVO 回调本就在主线程同步触发，直接同步 apply，
            // 避免把 scroll-linked 效果推后一帧导致 Reveal 跟手滞后。
            self?.apply()
        }
    }

    private func apply() {
        guard let effect = effect, let sv = scrollView, sv.bounds.height > 0 else { return }
        let viewportCenter = Self.viewportCenter(of: sv)
        forEachVisible(in: sv) { cellCenter, cell in
            let position = Self.normalizedPosition(cellCenter: cellCenter,
                                                   viewportCenter: viewportCenter,
                                                   viewportHeight: sv.bounds.height)
            Self.applyEffect(effect, to: cell, at: position)
        }
    }

    /// 把 effect 在指定 position 的输出施加到 **cell 本身**（而非 contentView）。
    /// 可测 seam：cell 的 transform 会被布局保留，contentView 的会被复位、屏幕不可见。
    static func applyEffect(_ effect: PositionEffect, to cell: UIView, at position: CGFloat) {
        applyEffectOutput(effect.resolve(position: position), to: cell)
    }

    /// 遍历可见 cell，回调 (cell.center.y, cell)。变换施加在 cell 本身——
    /// cell.contentView 的 transform 会被 cell 布局复位，故必须用 cell。
    private func forEachVisible(in sv: UIScrollView, _ body: (CGFloat, UIView) -> Void) {
        if let tv = sv as? UITableView {
            for cell in tv.visibleCells { body(cell.center.y, cell) }
        } else if let cv = sv as? UICollectionView {
            for cell in cv.visibleCells { body(cell.center.y, cell) }
        }
    }

    private func resetAll(in sv: UIScrollView) {
        forEachVisible(in: sv) { _, contentView in reset(contentView) }
    }

    private func reset(_ v: UIView) {
        resetEffectOutput(on: v)
    }

    deinit { observation?.invalidate() }
}

private var scrollEffectKey: UInt8 = 0

public extension UIScrollView {
    /// 位置型 scroll-linked 效果入口（关联对象自持）。
    var scrollEffect: PositionEffectDriver {
        if let d = objc_getAssociatedObject(self, &scrollEffectKey) as? PositionEffectDriver {
            return d
        }
        let d = PositionEffectDriver(scrollView: self)
        objc_setAssociatedObject(self, &scrollEffectKey, d, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return d
    }
}
#endif
