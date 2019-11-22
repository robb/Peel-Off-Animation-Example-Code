import UIKit

public final class PeelOffInteraction: NSObject, UIInteraction {
    public let gestureRecognizer = UILongPressGestureRecognizer()

    private var offset: CGPoint = .zero

    private var stickerView: StickerView?

    public var view: UIView?

    override public init() {
        super.init()

        gestureRecognizer.addTarget(self, action: #selector(gestureRecognizerDidUpdate))
        gestureRecognizer.delegate = self
        gestureRecognizer.minimumPressDuration = 0.2
    }

    public func willMove(to view: UIView?) {
        if view == nil {
            self.view?.removeGestureRecognizer(gestureRecognizer)
        }

        self.view = view
    }

    public func didMove(to view: UIView?) {
        self.view = view

        view?.addGestureRecognizer(gestureRecognizer)
    }

    @objc
    func gestureRecognizerDidUpdate(sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            guard let view = sender.view else { return }

            stickerView = StickerView(frame: view.bounds)

            let renderer = UIGraphicsImageRenderer(bounds: view.bounds)

            stickerView!.image = renderer.image { rendererContext in
                view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
            }

            stickerView!.frame = view.window!.convert(view.frame, from: view.superview!)
            view.window!.addSubview(stickerView!)

            stickerView!.setIsPeeledOff(isPeeledOff: true, animated: false, start: {
                view.isHidden = true
            })

            offset = sender.location(in: view)
        case .changed:
            guard let view = sender.view else { return }

            stickerView?.frame.origin = sender.location(in: view.window!)
            stickerView?.frame.origin.x -= offset.x
            stickerView?.frame.origin.y -= offset.y
        case .cancelled, .ended, .failed:
            UIView.animate(
                withDuration: StickerView.animationDuration,
                delay: 0,
                usingSpringWithDamping: 1,
                initialSpringVelocity: 0,
                options: [],
                animations: {
                    guard let view = sender.view else { return }

                    self.stickerView?.frame = view.window!.convert(view.frame, from: view.superview!)
                },
                completion: nil
            )

            stickerView?.setIsPeeledOff(isPeeledOff: false, animated: true, completion: { [weak self] in
                sender.view?.isHidden = false
                self?.stickerView?.removeFromSuperview()
                self?.stickerView = nil
            })
        default:
            break
        }
    }
}

extension PeelOffInteraction: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        otherGestureRecognizer is UIPanGestureRecognizer
    }
}

extension NSDirectionalEdgeInsets {
    init(uniform: CGFloat) {
        self.init(top: uniform, leading: uniform, bottom: uniform, trailing: uniform)
    }
}
