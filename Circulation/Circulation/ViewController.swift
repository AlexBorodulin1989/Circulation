/// Copyright (c) 2018 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import MetalKit

class ViewController: UIViewController {
    @IBOutlet weak var metalView: MTKView!

    var device: MTLDevice!
    var metalLayer: CAMetalLayer!
    var vertexBuffer: MTLBuffer!
    var frameVertBuffer: MTLBuffer!
    var framePipelineState: MTLRenderPipelineState!
    var quadrPipelineState: MTLRenderPipelineState!
    var commandQueue: MTLCommandQueue!

    var vertexData: [SIMD3<Float>] = []
    var frameVertices: [SIMD3<Float>] = []

    private let frameWidth: CGFloat = 100
    private let frameHeight: CGFloat = 50

    private let clearColor = MTLClearColor(red: 40.0/255.0,
                                           green: 93.0/255.0,
                                           blue: 102.0/255.0,
                                           alpha: 1.0)

    var directBasis: float3x3 = .init(diagonal: .init(x: 1, y: 1, z: 1))
    var diagonalBasis: float3x3 = .init(diagonal: .init(x: 1, y: 1, z: 1))

    private var transitionMatrix: float3x3 = .init(diagonal: .init(x: 1, y: 1, z: 1))
    private var scaleMatrix: float3x3 = .init(diagonal: .init(x: 1, y: 1, z: 1))
    private var rotateMatrix: float3x3 = .init(diagonal: .init(x: 1, y: 1, z: 1))

    private var animationDuration: Double = 1
    private var startAnimationTimestamp: Double = 0

    private var angle: Float = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        device = MTLCreateSystemDefaultDevice()

        metalView.device = device
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.framebufferOnly = true
        metalView.frame = view.layer.frame

        metalView.delegate = self

        createDataBuffer()
        createPipelineStates()

        commandQueue = device.makeCommandQueue()
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)

        let frameCenter = view.center

        let minX = Float(frameCenter.x - frameWidth * 0.5)
        let minY = Float(frameCenter.y - frameHeight * 0.5)
        let maxX = minX + Float(frameWidth)
        let maxY = minY + Float(frameHeight)

        frameVertices = [
            .init(minX, minY, 1),
            .init(maxX, minY, 1),
            .init(maxX, maxY, 1),
            .init(minX, maxY, 1),
            .init(minX, minY, 1)
        ]

        createDataBuffer()
    }

    func startAnimation() {
        startAnimationTimestamp = Date().timeIntervalSince1970
    }

    func createPipelineStates() {
        let constantValues = MTLFunctionConstantValues()
        constantValues.setConstantValue(&animationDuration, type: .float, index: 0)

        let defaultLibrary = device.makeDefaultLibrary()!
        let fragmentProgram = defaultLibrary.makeFunction(name: "basic_fragment")
        let frameVertexProgram = defaultLibrary.makeFunction(name: "frame_vertex")
        let quadrVertexProgram = try! defaultLibrary.makeFunction(name: "quadrilateral_vertex", constantValues: constantValues)

        let framePipelineStateDescriptor = MTLRenderPipelineDescriptor()
        framePipelineStateDescriptor.vertexFunction = frameVertexProgram
        framePipelineStateDescriptor.fragmentFunction = fragmentProgram
        framePipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        let quadrFramePipelineStateDescriptor = MTLRenderPipelineDescriptor()
        quadrFramePipelineStateDescriptor.vertexFunction = quadrVertexProgram
        quadrFramePipelineStateDescriptor.fragmentFunction = fragmentProgram
        quadrFramePipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        framePipelineState = try! device.makeRenderPipelineState(descriptor: framePipelineStateDescriptor)
        quadrPipelineState = try! device.makeRenderPipelineState(descriptor: quadrFramePipelineStateDescriptor)
    }

    func createDataBuffer() {
        if !vertexData.isEmpty {
            if vertexData.count == 1 {
                let dataSize = vertexData.count * MemoryLayout<SIMD3<Float>>.size
                vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize)
            } else {
                var vertices: [SIMD3<Float>] = []
                for index in 0..<(vertexData.count-1) {
                    var dirVector: SIMD2<Float> = .init(vertexData[index+1].x - vertexData[index].x,
                                                        vertexData[index+1].y - vertexData[index].y)
                    dirVector /= dirVector.magnitude()
                    let rightVector = SIMD3<Float>(dirVector.y, -dirVector.x, 0)
                    let leftVector = SIMD3<Float>(-dirVector.y, dirVector.x, 0)

                    let topLeft = vertexData[index] + leftVector
                    let bottomLeft = vertexData[index] + rightVector
                    let topRight = vertexData[index+1] + leftVector
                    let bottomRight = vertexData[index+1] + rightVector

                    vertices.append(contentsOf: [topLeft, bottomRight, bottomLeft, topLeft, topRight, bottomRight])
                }

                let dataSize = vertices.count * MemoryLayout<SIMD3<Float>>.size
                vertexBuffer = device.makeBuffer(bytes: vertices, length: dataSize)
            }
        }

        if !frameVertices.isEmpty {
            var vertices: [SIMD3<Float>] = []
            for index in 0...3 {
                var dirVector: SIMD2<Float> = .init(frameVertices[index+1].x - frameVertices[index].x,
                                                    frameVertices[index+1].y - frameVertices[index].y)
                dirVector /= dirVector.magnitude()
                let rightVector = SIMD3<Float>(dirVector.y, -dirVector.x, 0)
                let leftVector = SIMD3<Float>(-dirVector.y, dirVector.x, 0)

                let topLeft = frameVertices[index] + leftVector
                let bottomLeft = frameVertices[index] + rightVector
                let topRight = frameVertices[index+1] + leftVector
                let bottomRight = frameVertices[index+1] + rightVector

                vertices.append(contentsOf: [topLeft, bottomRight, bottomLeft, topLeft, topRight, bottomRight])
            }

            let dataSize = vertices.count * MemoryLayout<SIMD3<Float>>.size
            frameVertBuffer = device.makeBuffer(bytes: vertices, length: dataSize)
        }
    }

    func rotate() {
        angle += 0.01
        let cosA = cos(angle)
        let sinA = sin(angle)

        rotateMatrix[0][0] = cosA
        rotateMatrix[0][1] = -sinA
        rotateMatrix[1][0] = sinA
        rotateMatrix[1][1] = cosA

        calculateTransforms()
    }

    func calculateTransforms() {
        updateBasises()
        magnetToDirectBasis()
        let scale = getScaleToDiagonalBasis()
        scaleFromDirectBasis(scale: scale)
    }

    func updateBasises() {
        if vertexData.count == 5 {
            var vertices = vertexData

            for index in 0...4 {
                vertices[index] = rotateMatrix * vertices[index]
            }

            var newXBasis = SIMD2<Float>(vertices[3].x - vertices[0].x, vertices[3].y - vertices[0].y)
            var newYBasis = SIMD2<Float>(vertices[1].x - vertices[0].x, vertices[1].y - vertices[0].y)

            newXBasis /= newXBasis.magnitude()
            newYBasis /= newYBasis.magnitude()

            directBasis[0][0] = newXBasis.x
            directBasis[0][1] = newXBasis.y
            directBasis[1][0] = newYBasis.x
            directBasis[1][1] = newYBasis.y
            directBasis[2][0] = vertices[0].x
            directBasis[2][1] = vertices[0].y

            newXBasis = SIMD2<Float>(vertices[3].x - vertices[2].x, vertices[3].y - vertices[2].y)
            newYBasis = SIMD2<Float>(vertices[1].x - vertices[2].x, vertices[1].y - vertices[2].y)

            newXBasis /= newXBasis.magnitude()
            newYBasis /= newYBasis.magnitude()

            diagonalBasis[0][0] = newXBasis.x
            diagonalBasis[0][1] = newXBasis.y
            diagonalBasis[1][0] = newYBasis.x
            diagonalBasis[1][1] = newYBasis.y
            diagonalBasis[2][0] = vertices[2].x
            diagonalBasis[2][1] = vertices[2].y
        }
    }

    func magnetToDirectBasis() {
        let invDirectBasis = directBasis.inverse

        var vertices = frameVertices

        for index in 0...4 {
            vertices[index] = invDirectBasis * vertices[index]
        }

        var minX = Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude

        for frameVertex in vertices {
            let currX = frameVertex.x
            let currY = frameVertex.y

            if currX < minX {
                minX = currX
            }
            if currY < minY {
                minY = currY
            }
        }

        for index in 0...4 {
            vertices[index].x -= minX
            vertices[index].y -= minY
        }

        for index in 0...4 {
            vertices[index] = directBasis * vertices[index]
        }

        transitionMatrix[2][0] = vertices[0].x - frameVertices[0].x
        transitionMatrix[2][1] = vertices[0].y - frameVertices[0].y
    }

    func getScaleToDiagonalBasis() -> Float {
        let invDiagonalBasis = diagonalBasis.inverse

        var vertices = frameVertices

        for index in 0...4 {
            vertices[index] = invDiagonalBasis * transitionMatrix * vertices[index]
        }

        var minX = Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude

        for frameVertex in vertices {
            let currX = frameVertex.x
            let currY = frameVertex.y

            if currX < minX {
                minX = currX
            }
            if currY < minY {
                minY = currY
            }
        }

        let directCorner = invDiagonalBasis * rotateMatrix * vertexData[0]

        let xScale = directCorner.x / (directCorner.x - minX)
        let yScale = directCorner.y / (directCorner.y - minY)

        return min(xScale, yScale)
    }

    func scaleFromDirectBasis(scale: Float) {
        let invDirectBasis = directBasis.inverse

        var vertices = frameVertices

        for index in 0...4 {
            vertices[index] = invDirectBasis * transitionMatrix * vertices[index]
        }

        for index in 0...4 {
            vertices[index].x *= scale
            vertices[index].y *= scale
        }

        for index in 0...4 {
            vertices[index] = directBasis * vertices[index]
        }

        let mainBasisScale = (vertices[1].x - vertices[0].x) / (frameVertices[1].x - frameVertices[0].x)

        transitionMatrix[2][0] = vertices[0].x - frameVertices[0].x * mainBasisScale
        transitionMatrix[2][1] = vertices[0].y - frameVertices[0].y * mainBasisScale

        scaleMatrix[0][0] = mainBasisScale
        scaleMatrix[1][1] = mainBasisScale
    }

    func render() {

    }

    @IBAction func touchScreen(_ sender: UITapGestureRecognizer) {
        if(sender.state == UIGestureRecognizer.State.ended){
            let location = sender.location(in: self.view)

            if vertexData.count == 5 {
                vertexData = []
            }
            vertexData.append(.init(Float(location.x), Float(location.y), 1))

            if vertexData.count == 4 {
                if let first = vertexData.first {
                    vertexData.append(first)
                    angle = 0
                    rotate()
                    startAnimation()
                }
            }

            createDataBuffer()
        }
    }
}

extension ViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            return
        }

        var invertedYBasis: float3x3 = .init(diagonal: .init(x: 1, y: 1, z: 1))
        invertedYBasis[1][1] = -1

        var ndcBasis: float3x3 = .init(diagonal: .init(x: 1, y: 1, z: 1))
        ndcBasis[0][0] = 2 / Float(self.view.frame.size.width)
        ndcBasis[1][1] = 2 / Float(self.view.frame.size.height)
        ndcBasis[2][0] = -1
        ndcBasis[2][1] = -1

        var transform = Transform(matrix: invertedYBasis.inverse * ndcBasis)

        if !vertexData.isEmpty {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = clearColor

            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!

            renderEncoder.setRenderPipelineState(quadrPipelineState)

            let vertexCount = vertexData.count

            if vertexCount == 5 {
                let animValue = (Date().timeIntervalSince1970 - startAnimationTimestamp) / animationDuration
                var data = QuadrData(basis_matrix: transform.matrix, transform_matrix: (transitionMatrix * scaleMatrix).inverse * rotateMatrix, animationValue: Float(animValue))
                renderEncoder.setVertexBytes(&data, length: MemoryLayout<QuadrData>.size, index: 16)
                if animValue > 1 {
                    rotate()
                }
            } else {
                var data = QuadrData(basis_matrix: transform.matrix, transform_matrix: .init(diagonal: .init(x: 1, y: 1, z: 1)), animationValue: 0)
                renderEncoder.setVertexBytes(&data, length: MemoryLayout<QuadrData>.size, index: 16)
            }

            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            if vertexCount == 1 {
                renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: vertexData.count)
            } else {
                renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: (vertexData.count - 1) * 6)
            }

            renderEncoder.endEncoding()
        }

        if !frameVertices.isEmpty {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = vertexData.isEmpty ? .clear : .load
            renderPassDescriptor.colorAttachments[0].clearColor = clearColor

            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(framePipelineState)
            renderEncoder.setVertexBytes(&transform, length: MemoryLayout<Transform>.size, index: 16)
            renderEncoder.setVertexBuffer(frameVertBuffer, offset: 0, index: 0)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: (frameVertices.count - 1) * 6)

            renderEncoder.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
