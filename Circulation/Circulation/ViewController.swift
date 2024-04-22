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
import Metal

class ViewController: UIViewController {
    var device: MTLDevice!
    var metalLayer: CAMetalLayer!
    var vertexBuffer: MTLBuffer!
    var frameVertBuffer: MTLBuffer!
    var pipelineState: MTLRenderPipelineState!
    var commandQueue: MTLCommandQueue!
    var timer: CADisplayLink!

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

    override func viewDidLoad() {
        super.viewDidLoad()

        device = MTLCreateSystemDefaultDevice()

        metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.frame = view.layer.frame
        view.layer.addSublayer(metalLayer)

        createDataBuffer()

        let defaultLibrary = device.makeDefaultLibrary()!
        let fragmentProgram = defaultLibrary.makeFunction(name: "basic_fragment")
        let vertexProgram = defaultLibrary.makeFunction(name: "basic_vertex")

        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)

        commandQueue = device.makeCommandQueue()

        timer = CADisplayLink(target: self, selector: #selector(gameloop))
        timer.add(to: .main, forMode: .default)
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

    func createDataBuffer() {
        if !vertexData.isEmpty {
            let dataSize = vertexData.count * MemoryLayout<SIMD3<Float>>.size
            vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize)
        }

        if !frameVertices.isEmpty {
            let dataSize = frameVertices.count * MemoryLayout<SIMD3<Float>>.size
            frameVertBuffer = device.makeBuffer(bytes: frameVertices, length: dataSize)
        }
    }

    func updateBasises() {
        if vertexData.count == 5 {
            var newXBasis = SIMD2<Float>(vertexData[3].x - vertexData[0].x, vertexData[3].y - vertexData[0].y)
            var newYBasis = SIMD2<Float>(vertexData[1].x - vertexData[0].x, vertexData[1].y - vertexData[0].y)

            newXBasis /= newXBasis.magnitude()
            newYBasis /= newYBasis.magnitude()

            directBasis[0][0] = newXBasis.x
            directBasis[0][1] = newXBasis.y
            directBasis[1][0] = newYBasis.x
            directBasis[1][1] = newYBasis.y
            directBasis[2][0] = vertexData[0].x
            directBasis[2][1] = vertexData[0].y

            newXBasis = SIMD2<Float>(vertexData[3].x - vertexData[2].x, vertexData[3].y - vertexData[2].y)
            newYBasis = SIMD2<Float>(vertexData[1].x - vertexData[2].x, vertexData[1].y - vertexData[2].y)

            newXBasis /= newXBasis.magnitude()
            newYBasis /= newYBasis.magnitude()

            diagonalBasis[0][0] = newXBasis.x
            diagonalBasis[0][1] = newXBasis.y
            diagonalBasis[1][0] = newYBasis.x
            diagonalBasis[1][1] = newYBasis.y
            diagonalBasis[2][0] = vertexData[2].x
            diagonalBasis[2][1] = vertexData[2].y
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

        print(transitionMatrix)
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

        let directCorner = invDiagonalBasis * vertexData[0]

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
        guard let drawable = metalLayer?.nextDrawable() else { return }
        let commandBuffer = commandQueue.makeCommandBuffer()!

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

            renderEncoder.setRenderPipelineState(pipelineState)

            renderEncoder.setVertexBytes(&transform, length: MemoryLayout<Transform>.size, index: 16)

            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            if vertexData.count == 1 {
                renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: vertexData.count)
            } else if vertexData.count == 2 {
                renderEncoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: vertexData.count)
            } else if vertexData.count == 3 {
                renderEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: vertexData.count)
            } else if vertexData.count == 5 {
                renderEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: vertexData.count)
            }

            renderEncoder.endEncoding()
        }

        if !frameVertices.isEmpty {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = vertexData.isEmpty ? .clear : .load
            renderPassDescriptor.colorAttachments[0].clearColor = clearColor

            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!

            transform.matrix *= (transitionMatrix * scaleMatrix)

            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.setVertexBytes(&transform, length: MemoryLayout<Transform>.size, index: 16)
            renderEncoder.setVertexBuffer(frameVertBuffer, offset: 0, index: 0)
            renderEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: frameVertices.count)

            renderEncoder.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    @objc func gameloop() {
        autoreleasepool {
            render()
        }
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
                    updateBasises()
                    magnetToDirectBasis()
                    let scale = getScaleToDiagonalBasis()
                    scaleFromDirectBasis(scale: scale)
                }
            }

            createDataBuffer()
        }
    }
}

