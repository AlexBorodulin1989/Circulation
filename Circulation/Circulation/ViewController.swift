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

enum CornerType: Int {
    case left = 0
    case top = 1
    case right = 2
    case bottom = 3
}

class ViewController: UIViewController {
    var device: MTLDevice!
    var metalLayer: CAMetalLayer!
    var vertexBuffer: MTLBuffer!
    var frameVertBuffer: MTLBuffer!
    var pipelineState: MTLRenderPipelineState!
    var commandQueue: MTLCommandQueue!
    var timer: CADisplayLink!

    var vertexData: [SIMD2<Float>] = []
    var frameVertices: [SIMD2<Float>] = []

    private let frameWidth: CGFloat = 100
    private let frameHeight: CGFloat = 50

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
            .init(minX, minY),
            .init(maxX, minY),
            .init(maxX, maxY),
            .init(minX, maxY),
            .init(minX, minY)
        ]

        createDataBuffer()
    }

    func createDataBuffer() {
        if !vertexData.isEmpty {
            let dataSize = vertexData.count * MemoryLayout<SIMD2<Float>>.size
            vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize)
        }

        if !frameVertices.isEmpty {
            let dataSize = frameVertices.count * MemoryLayout<SIMD2<Float>>.size
            frameVertBuffer = device.makeBuffer(bytes: frameVertices, length: dataSize)
        }
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
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0,
                                                                                green: 104.0/255.0,
                                                                                blue: 55.0/255.0,
                                                                                alpha: 1.0)

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
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0,
                                                                                green: 104.0/255.0,
                                                                                blue: 55.0/255.0,
                                                                                alpha: 1.0)

            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!

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
            vertexData.append(.init(Float(location.x), Float(location.y)))

            if vertexData.count == 4 {
                if let first = vertexData.first {
                    vertexData.append(first)
                }
            }

            createDataBuffer()
        }
    }
}

