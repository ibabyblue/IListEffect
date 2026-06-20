#if canImport(UIKit)
import UIKit
import ListEffectCore

/// Breaks the CADisplayLink -> target strong reference. The run loop retains
/// the proxy, the proxy holds the controller weakly, so the controller is free
/// to deinit once its scroll view releases it.
private final class DisplayLinkProxy: NSObject {
    weak var controller: ListEffectController?
    init(controller: ListEffectController) {
        self.controller = controller
        super.init()
    }
    @objc func tick() { controller?.tick() }
}

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
    private var lastOffsetY: CGFloat = 0
    private var accumulated: [ObjectIdentifier: CGFloat] = [:]
    private var displayLink: CADisplayLink?
    private var displayLinkProxy: DisplayLinkProxy?
    private let relaxation: CGFloat = 0.82
    /// 跟随位移上限（pt），防止快速滚动时偏移超过行高导致 cell 重叠。
    private let maxLag: CGFloat = 24

    init(host: ListEffectHost) {
        self.host = host
    }

    deinit {
        offsetObservation = nil
        displayLink?.invalidate()
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
        lastOffsetY = host?.hostScrollView.contentOffset.y ?? 0
        startObserving()
        let proxy = DisplayLinkProxy(controller: self)
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick))
        link.add(to: .main, forMode: .common)
        displayLinkProxy = proxy
        displayLink = link
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
        case .tracking(let effect):
            guard let host = host else { return }
            let sv = host.hostScrollView
            let newY = sv.contentOffset.y
            let delta = newY - lastOffsetY
            lastOffsetY = newY
            let touch = sv.panGestureRecognizer.location(in: sv)
            var visibleIDs = Set<ObjectIdentifier>()
            for item in host.visibleItems() {
                let id = ObjectIdentifier(item.view)
                visibleIDs.insert(id)
                let out = effect.resolve(delta: delta,
                                         itemCenter: item.restingCenter,
                                         touch: touch,
                                         container: sv.bounds.size)
                // 累加本帧滞后增量，但夹到 ±maxLag，避免位移超过行高导致 cell 重叠。
                let x = (accumulated[id] ?? 0) + out.translation.y
                accumulated[id] = max(-maxLag, min(maxLag, x))
            }
            // 丢弃已离屏 cell 的条目，复用的 cell 不会继承陈旧偏移。
            accumulated = accumulated.filter { visibleIDs.contains($0.key) }
            applyTracking()
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

    private func applyTracking() {
        guard let host = host else { return }
        for item in host.visibleItems() {
            let y = accumulated[ObjectIdentifier(item.view)] ?? 0
            apply(EffectOutput(translation: CGPoint(x: 0, y: y)), to: item.view)
        }
    }

    func tick() {
        guard case .tracking? = attached, let host = host else { return }
        var changed = false
        for item in host.visibleItems() {
            let id = ObjectIdentifier(item.view)
            var y = accumulated[id] ?? 0
            guard y != 0 else { continue }
            y *= relaxation
            if abs(y) < 0.5 { y = 0 }
            accumulated[id] = y
            changed = true
        }
        if changed { applyTracking() }
    }

    func apply(_ out: EffectOutput, to view: UIView) {
        if out.rotation == 0 {
            // 仿射通道：给 view.transform 赋值会同时归一化 layer.transform
            view.transform = CGAffineTransform(translationX: out.translation.x, y: out.translation.y)
                .scaledBy(x: out.scale, y: out.scale)
        } else {
            // 3D 通道：先清掉仿射状态，避免两条通道叠加
            view.transform = .identity
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
        displayLink?.invalidate()
        displayLink = nil
        displayLinkProxy = nil
        accumulated.removeAll()
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
