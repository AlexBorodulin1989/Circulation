/// Copyright (c) 2024 Razeware LLC
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

#include <metal_stdlib>
#import "General.h"
using namespace metal;

struct VertexOut {
    float4 pos [[position]];
    float pointsize [[point_size]];
    half4 color;
};

vertex VertexOut frame_vertex(const device float3* vertex_array [[ buffer(0) ]],
                              unsigned int vid [[ vertex_id ]],
                              constant Transform &transform [[buffer(16)]]) {
    auto pos = vertex_array[vid];
    auto transformPos = transform.matrix * pos;
    VertexOut result {
        .pos = float4(transformPos.xy, 0.5, 1.0),
        .pointsize = 10,
        .color = half4(252.0/255.0, 55.0/255.0, 0.0, 1.0)
    };
    return result;
}

vertex VertexOut quadrilateral_vertex(const device float3* vertex_array [[ buffer(0) ]],
                            unsigned int vid [[ vertex_id ]],
                            constant QuadrData &data [[buffer(16)]]) {
    auto pos = vertex_array[vid];
    auto transformedPos = data.transform_matrix * pos;
    auto interpolatedPos = pos + smoothstep(0.0, 1.0, data.animationValue) * (transformedPos - pos);
    auto transformPos = data.basis_matrix * interpolatedPos;
    VertexOut result {
        .pos = float4(transformPos.xy, 0.5, 1.0),
        .pointsize = 10,
        .color = half4(0.0, 168.0/255.0, 72.0, 1.0)
    };
    return result;
}

fragment half4 basic_fragment(VertexOut in [[stage_in]]) {
    return in.color;
}
