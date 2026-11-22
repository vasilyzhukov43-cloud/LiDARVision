
import SwiftUI
import SceneKit
import simd

struct PointCloudView: UIViewRepresentable {

    let points: [SIMD3<Float>]

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()

        view.backgroundColor = UIColor.black
        view.scene = SCNScene()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true

        let camera = SCNCamera()
        camera.zNear = 0.01
        camera.zFar = 20

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 5)

        view.scene?.rootNode.addChildNode(cameraNode)

        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        guard let scene = view.scene else { return }

        scene.rootNode.childNodes
            .filter { $0.name == "pointCloud" }
            .forEach { $0.removeFromParentNode() }

        guard !points.isEmpty else { return }

        let vertices = points.map {
            SCNVector3($0.x, $0.y, $0.z)
        }

        let source = SCNGeometrySource(vertices: vertices)

        let indices = Array(0..<points.count).map {
            UInt32($0)
        }

        let element = SCNGeometryElement(
            indices: indices,
            primitiveType: .point
        )

        element.pointSize = 4
        element.minimumPointScreenSpaceRadius = 2
        element.maximumPointScreenSpaceRadius = 6

        let geometry = SCNGeometry(
        sources: [source, colorSource],
        elements: [element]
        )

        let colors = points.map { point -> SIMD4<Float> in
            let distance = simd_length(point)
            let t = min(max(distance / 10.0, 0), 1)

            return SIMD4<Float>(
                t,
                0.2,
                1.0 - t,
                1.0
            )
        }

        let colorData = Data(
            bytes: colors,
            count: colors.count * MemoryLayout<SIMD4<Float>>.stride
        )

        let colorSource = SCNGeometrySource(
            data: colorData,
            semantic: .color,
            vectorCount: colors.count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD4<Float>>.stride
        )


        let node = SCNNode(geometry: geometry)
        node.name = "pointCloud"

        scene.rootNode.addChildNode(node)
    }
}
