//
//  General.h
//  CutView_SwiftUI
//
//  Created by Aleksandr Borodulin on 21.12.2023.
//

#ifndef General_h
#define General_h

#import <simd/simd.h>

typedef struct {
    matrix_float3x3 matrix;
} Transform;

typedef struct {
    matrix_float3x3 basis_matrix;
    matrix_float3x3 transform_matrix;
    float animationValue;
} QuadrData;

#endif /* General_h */
