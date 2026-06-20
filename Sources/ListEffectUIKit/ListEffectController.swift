#if canImport(UIKit)
import UIKit
import ListEffectCore

/// 滚动动效驱动器。通过 KVO 监听 contentOffset，将效果输出写入可见 cell 的 transform。
/// 不接管宿主的 delegate / dataSource。
public final class ListEffectController {

    enum Attached {
        case position(PositionEffect)
        case tracking(TrackingEffect)
    }

    private weak var host: ListEffectHost?
    var attached: Attached?
    private var offsetObservation: NSKeyValueObservation?

    init(host: ListEffectHost) {
        self.host = host
    }

    public func attach(_ effect: PositionEffect) {
        reset()
        attached = .position(effect)
        startObserving()
        applyPosition()
    }

    public func attach(_ effect: TrackingEffect) {
        reset()
        attached = .tracking(effect)
        // KVO / 累加 / 归位在 Task 7 补全
    }

    public func detach() {
        reset()
    }

    private func startObserving() {
        guard let sv = host?.hostScrollView else { return }
        offsetObservation = sv.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
            self?.onScroll()
        }
    }

    func onScroll() {
        guard let attached = attached else { return }
        switch attached {
        case .position:
            applyPosition()
        case .tracking:
            break   // Task 7
        }
    }

    private func applyPosition() {
        guard let host = host, case .position(let effect)? = attached else { return }
        let sv = host.hostScrollView
        let midY = sv.contentOffset.y + sv.bounds.height / 2
        let half = sv.bounds.height / 2
        for item in host.visibleItems() {
            let position = half == 0 ? 0 : (item.restingCenter.y - midY) / half
            apply(effect.resolve(position: position), to: item.view)
        }
    }

    func apply(_ out: EffectOutput, to view: UIView) {
        if out.rotation == 0 {
            view.transform = CGAffineTransform(translationX: out.translation.x, y: out.translation.y)
                .scaledBy(x: out.scale, y: out.scale)
        } else {
            var t = CATransform3DIdentity
            t.m34 = -1.0 / 800
            t = CATransform3DTranslate(t, out.translation.x, out.translation.y, 0)
            t = CATransform3DScale(t, out.scale, out.scale, 1)
            t = CATransform3DRotate(t, out.rotation, 1, 0, 0)
            view.layer.transform = t
        }
        view.alpha = out.alpha
    }

    func reset() {
        offsetObservation = nil
        if let host = host {
            for item in host.visibleItems() {
                item.view.transform = .identity
                item.view.layer.transform = CATransform3DIdentity
                item.view.alpha = 1
            }
        }
        attached = nil
    }
}
#endif
