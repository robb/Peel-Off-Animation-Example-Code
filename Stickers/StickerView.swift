import SceneKit
import UIKit

public class StickerView: UIView {
    /// The size of `sceneView` relative to `bounds`.
    ///
    /// By exceeding the receiver, `sceneView` can capture the translation of the `shadowNode`.
    static let scaleFactor: CGFloat = 1.7

    public static let animationDuration = 0.8

    let sceneView: SCNView

    let reflection: SCNNode

    let sticker: SCNNode

    var image: UIImage? {
        didSet {
            sticker.geometry?.firstMaterial?.diffuse.contents = image
            reflection.geometry?.firstMaterial?.diffuse.contents = image
        }
    }

    private(set) var isPeeledOff: Bool = false

    override init(frame: CGRect) {
        sceneView = SCNView(frame: frame)
        sceneView.frame.origin = .zero

        var scaled = frame.size
        scaled.width  /= StickerView.scaleFactor
        scaled.height /= StickerView.scaleFactor

        sticker = SCNNode(geometry: SCNPlane(size: scaled))
        reflection = SCNNode(geometry: SCNPlane(size: scaled))

        super.init(frame: frame)

        clipsToBounds = false

        sceneView.isPlaying = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.backgroundColor = .clear

        let scene = SCNScene()
        sceneView.scene = scene

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()

        let fov = cameraNode.camera!.fieldOfView

        let cameraDistance = max(frame.size.width, frame.size.height) / (2 * tan(fov / 2 * .pi / 180))

        cameraNode.position = SCNVector3(x: 0, y: 0, z: Float(cameraDistance))
        cameraNode.camera!.zFar = ceil(Double(cameraDistance))

        scene.rootNode.addChildNode(cameraNode)

        let parent = SCNNode()
        scene.rootNode.addChildNode(parent)

        parent.addChildNode(sticker)

        let geometryModifier = """
            #pragma arguments
            float peeled;
            float liftDistance;

            #pragma transparent
            #pragma body

            // How far are we in the animation.
            float t = 2 * clamp(peeled - _geometry.texcoords[0].y / 2, 0.0, 0.5);

            // Quadratic ease in out
            if (t < 0.5) {
                t = (4 * t * t * t);
            } else {
                t = ((t - 1) * (2 * t - 2) * (2 * t - 2) + 1);
            }

            // Quantize the displacement. I got rendering artifacts without
            // this step. Is this actually necessary?
            t = round(t * 1000.0) / 1000.0;

            _geometry.position.xyz += _geometry.normal * liftDistance * t;
        """

        let surfaceModifier = """
            #pragma arguments
            float peeled;

            #pragma transparent
            #pragma body

            float t = 2 * clamp(peeled - _surface.diffuseTexcoord.y / 2, 0.0, 0.5);

            _surface.diffuse.rgb += float3(pow(sin(3.14159 * t), 12) / 8.0);
        """

        sticker.geometry?.firstMaterial?.setValue(0.0, forKey: "peeled")
        sticker.geometry?.firstMaterial?.setValue(cameraDistance * 0.25, forKey: "liftDistance")
        sticker.geometry?.firstMaterial?.shaderModifiers = [
            .geometry: geometryModifier,
            .surface: surfaceModifier
        ]

        let tesselator = SCNGeometryTessellator()
        tesselator.edgeTessellationFactor   = 50
        tesselator.insideTessellationFactor = 50

        sticker.geometry?.tessellator = tesselator
        sticker.renderingOrder = 1
        sticker.geometry?.firstMaterial?.readsFromDepthBuffer = false

        parent.addChildNode(reflection)

        let gaussianBlurFilter = CIFilter(name: "CIGaussianBlur")!
        gaussianBlurFilter.name = "blur"
        gaussianBlurFilter.setValue(0.0, forKey: "inputRadius")

        reflection.filters = [ gaussianBlurFilter ]

        addSubview(sceneView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        let transform = CGAffineTransform(
            scaleX: StickerView.scaleFactor,
            y: StickerView.scaleFactor
        )

        sceneView.frame = bounds.applying(transform)
        sceneView.center.x = bounds.midX
        sceneView.center.y = bounds.midY
    }

    public func setIsPeeledOff(isPeeledOff: Bool, animated: Bool = false, start: @escaping () -> Void = {}, completion: @escaping () -> Void = {}) {
        self.isPeeledOff = isPeeledOff

        let peel: CAAnimation = {
            let (fromValue, toValue) = isPeeledOff ? (0.0, 1.0) : (1.0, 0.0)

            sticker.geometry?.firstMaterial?.setValue(toValue, forKey: "peeled")

            let animation = CABasicAnimation(keyPath: "geometry.firstMaterial.peeled")
            animation.fromValue = fromValue
            animation.toValue   = toValue
            animation.duration  = StickerView.animationDuration

            return animation
        }()

        sticker.addAnimation(peel, forKey: nil)

        let shadowTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let blur: CAAnimation = {
            let (fromValue, toValue) = isPeeledOff ? (0.0, 11.0) : (11.0, 0.0)

            reflection.filters?.first?.setValue(toValue, forKey: "inputRadius")

            let animation = CABasicAnimation(keyPath: "filters.blur.inputRadius")
            animation.duration       = StickerView.animationDuration
            animation.fillMode       = .backwards
            animation.fromValue      = fromValue
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            animation.toValue        = toValue

            return animation
        }()

        let delay = isPeeledOff ? StickerView.animationDuration / 2.5 : 0

        let transparency: CAAnimation = {
            let (fromValue, toValue) = isPeeledOff ? (0.6, 0.4) : (0.4, 0.6) as (CGFloat, CGFloat)

            reflection.geometry?.firstMaterial?.transparency = toValue

            let animation = CABasicAnimation(keyPath: "geometry.firstMaterial.transparency")
            animation.beginTime      = delay
            animation.duration       = StickerView.animationDuration - delay
            animation.fillMode       = .backwards
            animation.fromValue      = fromValue
            animation.timingFunction = shadowTimingFunction
            animation.toValue        = toValue

            return animation
        }()

        let transform: CAAnimation = {
            let identity   = SCNMatrix4Identity
            let translated = SCNMatrix4MakeTranslation(0, -30, 0)

            let (fromValue, toValue) = isPeeledOff ? (identity, translated) : (translated, identity)

            reflection.transform = toValue

            let animation = CABasicAnimation(keyPath: "transform")
            animation.beginTime      = delay
            animation.timingFunction = shadowTimingFunction
            animation.fromValue      = fromValue
            animation.toValue        = toValue
            animation.duration       = StickerView.animationDuration - delay
            animation.fillMode       = .backwards

            return animation
        }()

        let group = CAAnimationGroup()
        group.animations = [ blur, transparency, transform ]
        group.duration   = StickerView.animationDuration

        reflection.addAnimation(group, forKey: nil)

        // For some reason, `animationDidStart` and `animationDidStop` are not
        // being called if we wrap `group` in an `SCNAction`.
        //
        // Instead, let's manually time actions alongside them. This seems to
        // work reasonably well.
        sceneView.scene?.rootNode.runAction(SCNAction()) {
            DispatchQueue.main.async {
                start()
            }
        }

        sceneView.scene?.rootNode.runAction(SCNAction.wait(duration: StickerView.animationDuration)) {
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}

private extension SCNPlane {
    convenience init(size: CGSize) {
        self.init(width: size.width, height: size.height)
    }
}
