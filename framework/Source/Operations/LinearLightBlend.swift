//
//  LinearLightBlendFilter.swift
//  GPUImage
//
//  Created by 陈品霖 on 2021/6/30.
//  Copyright © 2021 Sunset Lake Software LLC. All rights reserved.
//

import Foundation
import UIKit

let LinearLightBlendFragmentShader = """
varying highp vec2 textureCoordinate;

uniform sampler2D inputImageTexture;
uniform sampler2D inputImageTexture2;
uniform highp float texture2Alpha;
uniform highp float brightnessThreshold;

//******************************************************************************
// Looks at the color information in each channel and darkens the base color to
// reflect the blend color by decreasing the brightness.
//******************************************************************************
highp float linearBurn(highp float base, highp float blend)
{
    return max(0.0, base + blend - 1.0);
}

//******************************************************************************
// Looks at the color information in each channel and brightens the base color
// to reflect the blend color by decreasing contrast between the two.
//******************************************************************************
highp float linearDodge(highp float base, highp float blend)
{
    return min(1.0, base + blend);
}

//******************************************************************************
// Burns or dodges the colors by decreasing or increasing the brightness,
// depending on the blend color.
//******************************************************************************
highp float linearLight(highp float base, highp float blend)
{
    return (blend <= brightnessThreshold) ? linearBurn(base, 2.0 * blend) : linearDodge(base, 2.0 * (blend - 0.5));
}

highp vec3 linearLight(highp vec3 base, highp vec3 blend)
{
    return vec3(linearLight(base.r, blend.r), linearLight(base.g, blend.g), linearLight(base.b, blend.b));
}

highp vec3 linearLight(highp vec3 base, highp vec3 blend, highp float alpha)
{
    return linearLight(base, blend) * alpha + base * (1.0 - alpha);
}

void main()
{
    highp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
    highp vec4 textureColor2 = texture2D(inputImageTexture2, textureCoordinate);
    highp vec3 blendColor = linearLight(textureColor.rgb, textureColor2.rgb, textureColor2.a * texture2Alpha);
    gl_FragColor = vec4(blendColor, 1.0);
}
"""

public class LinearLightBlend: BasicOperation {
    public var texture2Alpha: Float = 1.0 {
        didSet {
            uniformSettings["texture2Alpha"] = GLfloat(texture2Alpha)
        }
    }
    
    public var brightnessThreshold: Float = 0.5 {
        didSet {
            uniformSettings["brightnessThreshold"] = GLfloat(brightnessThreshold)
        }
    }
    
    public init() {
        super.init(fragmentShader: LinearLightBlendFragmentShader, numberOfInputs: 2)
        ({
            self.texture2Alpha = 1.0
            self.brightnessThreshold = 0.5
        })()
    }
}
