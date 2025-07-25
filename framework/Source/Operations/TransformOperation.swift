#if os(Linux)
#if GLES
    import COpenGLES.gles2
    #else
    import COpenGL
#endif
#else
#if GLES
    import OpenGLES
    #else
    import OpenGL.GL3
#endif
#endif

open class TransformOperation: BasicOperation {
    public var transform = Matrix4x4.identity { didSet { uniformSettings["transformMatrix"] = transform } }
    public var anchorTopLeft = false
    public var ignoreAspectRatio = false
    var normalizedImageVertices: [GLfloat]!
    
    public init() {
        super.init(vertexShader: TransformVertexShader, fragmentShader: PassthroughFragmentShader, numberOfInputs: 1)
        
        ({ transform = Matrix4x4.identity })()
    }
    
    public override func internalRenderFunction(_ inputFramebuffer: Framebuffer, textureProperties: [InputTextureProperties]) {
        renderQuadWithShader(shader, uniformSettings: uniformSettings, vertices: normalizedImageVertices, inputTextures: textureProperties)
        releaseIncomingFramebuffers()
    }

    override open func configureFramebufferSpecificUniforms(_ inputFramebuffer: Framebuffer) {
        let outputRotation = overriddenOutputRotation ?? inputFramebuffer.orientation.rotationNeededForOrientation(.portrait)
        var aspectRatio = inputFramebuffer.aspectRatioForRotation(outputRotation)
        if ignoreAspectRatio {
            aspectRatio = 1
        }
        let orthoMatrix = orthographicMatrix(-1.0, right: 1.0, bottom: -1.0 * aspectRatio, top: 1.0 * aspectRatio, near: -1.0, far: 1.0, anchorTopLeft: anchorTopLeft)
        normalizedImageVertices = normalizedImageVerticesForAspectRatio(aspectRatio)
        
        uniformSettings["orthographicMatrix"] = orthoMatrix
    }
    
    func normalizedImageVerticesForAspectRatio(_ aspectRatio: Float) -> [GLfloat] {
        // [TopLeft.x, TopLeft.y, TopRight.x, TopRight.y, BottomLeft.x, BottomLeft.y, BottomRight.x, BottomRight.y]
        if anchorTopLeft {
            return [0.0, 0.0, 1.0, 0.0, 0.0, GLfloat(aspectRatio), 1.0, GLfloat(aspectRatio)]
        } else {
            return [-1.0, GLfloat(-aspectRatio), 1.0, GLfloat(-aspectRatio), -1.0, GLfloat(aspectRatio), 1.0, GLfloat(aspectRatio)]
        }
    }
}
