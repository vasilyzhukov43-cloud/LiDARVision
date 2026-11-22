
import Foundation
import ARKit
import CoreVideo
import Combine
import simd

final class LiDARScanner: NSObject, ObservableObject, ARSessionDelegate {

    private let session = ARSession()

    @Published private(set) var isScanning = false
    @Published private(set) var status = "Ожидание запуска"
    @Published private(set) var points: [SIMD3<Float>] = []

    private let maxDistance: Float = 10.0
    private let sampleStep = 8

    func startScanning() {
        guard ARWorldTrackingConfiguration.isSupported else {
            status = "ARKit не поддерживается"
            return
        }

        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) else {
            status = "LiDAR Depth недоступен"
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics.insert(.sceneDepth)

        session.delegate = self
        session.run(configuration)

        isScanning = true
        status = "Запуск LiDAR..."
    }

    func stopScanning() {
        session.pause()

        DispatchQueue.main.async {
            self.isScanning = false
            self.status = "Сканирование остановлено"
        }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let depthData = frame.sceneDepth else {
            return
        }

        let depthMap = depthData.depthMap

        guard CVPixelBufferLockBaseAddress(depthMap, .readOnly)
                == kCVReturnSuccess else {
            return
        }

        defer {
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
        }

        guard let depthBase = CVPixelBufferGetBaseAddress(depthMap) else {
            return
        }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let rowStride = CVPixelBufferGetBytesPerRow(depthMap) / MemoryLayout<Float>.size

        let depthPointer = depthBase.assumingMemoryBound(to: Float.self)

        let confidenceMap = depthData.confidenceMap
        var confidencePointer: UnsafeMutablePointer<UInt8>?
        var confidenceWidth = 0
        var confidenceHeight = 0
        var confidenceStride = 0

        if let confidenceMap,
           CVPixelBufferLockBaseAddress(confidenceMap, .readOnly) == kCVReturnSuccess {

            if let base = CVPixelBufferGetBaseAddress(confidenceMap) {
                confidencePointer = base.assumingMemoryBound(to: UInt8.self)
                confidenceWidth = CVPixelBufferGetWidth(confidenceMap)
                confidenceHeight = CVPixelBufferGetHeight(confidenceMap)
                confidenceStride = CVPixelBufferGetBytesPerRow(confidenceMap)
            } else {
                CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly)
            }
        }

        defer {
            if let confidenceMap, confidencePointer != nil {
                CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly)
            }
        }

        let intrinsics = frame.camera.intrinsics

        let fx = intrinsics.columns.0.x
        let fy = intrinsics.columns.1.y
        let cx = intrinsics.columns.2.x
        let cy = intrinsics.columns.2.y

        guard fx > 0, fy > 0 else {
            return
        }

        var newPoints: [SIMD3<Float>] = []
        newPoints.reserveCapacity((width / sampleStep) * (height / sampleStep))

        for y in stride(from: 0, to: height, by: sampleStep) {
            for x in stride(from: 0, to: width, by: sampleStep) {

                if let confidencePointer {
                    let confidenceX = min(
                        confidenceWidth - 1,
                        x * confidenceWidth / width
                    )

                    let confidenceY = min(
                        confidenceHeight - 1,
                        y * confidenceHeight / height
                    )

                    let confidence = confidencePointer[
                        confidenceY * confidenceStride + confidenceX
                    ]

                    if confidence < UInt8(ARConfidenceLevel.medium.rawValue) {
                        continue
                    }
                }

                let depth = depthPointer[y * rowStride + x]

                guard depth.isFinite,
                      depth > 0.15,
                      depth <= maxDistance else {
                    continue
                }

                let pointX = (Float(x) - cx) * depth / fx
                let pointY = -(Float(y) - cy) * depth / fy
                let pointZ = -depth

                newPoints.append(
                    SIMD3<Float>(pointX, pointY, pointZ)
                )
            }
        }

        DispatchQueue.main.async {
            self.points = newPoints
            self.status = "LiDAR работает: \(newPoints.count) точек"
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.status = "Ошибка: \(error.localizedDescription)"
            self.isScanning = false
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async {
            self.status = "Сканирование прервано"
        }
    }
}
