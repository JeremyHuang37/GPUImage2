import Foundation
import QuartzCore

public func defaultVertexShaderForInputs(_ inputCount: UInt) -> String {
    switch inputCount {
    case 1: return OneInputVertexShader
    case 2: return TwoInputVertexShader
    case 3: return ThreeInputVertexShader
    case 4: return FourInputVertexShader
    case 5: return FiveInputVertexShader
    default: return OneInputVertexShader
    }
}

open class BasicOperation: ImageProcessingOperation {
    public let maximumInputs: UInt
    public var overriddenOutputSize: Size?
    public var overriddenOutputRotation: Rotation?
    public var backgroundColor = Color.black
    public var drawUnmodifiedImageOutsideOfMask = true
    public var mask: ImageSource? {
        didSet {
            if let mask = mask {
                maskImageRelay.newImageCallback = { [weak self] framebuffer in
                    self?.maskFramebuffer?.unlock()
                    framebuffer.lock()
                    self?.maskFramebuffer = framebuffer
                }
                mask.addTarget(maskImageRelay)
            } else {
                maskFramebuffer?.unlock()
                maskImageRelay.removeSourceAtIndex(0)
                maskFramebuffer = nil
            }
        }
    }
    public var activatePassthroughOnNextFrame = false
    public var uniformSettings = ShaderUniformSettings()
    
    // MARK: -
    // MARK: Internal
    
    public let targets = TargetContainer()
    public let sources = SourceContainer()
    public var shader: ShaderProgram
    public var inputFramebuffers = [UInt: Framebuffer]()
    public var renderFramebuffer: Framebuffer!
    open var outputFramebuffer: Framebuffer { get { return renderFramebuffer } }
    open var shouldKeepRenderFramebufferIfNoTarget = false
    /// Set this to true if it needs all input framebuffers to be updated everytime
    public var releaseAllInputFramebuffersAfterRendering = false
    let usesAspectRatio: Bool
    let maskImageRelay = ImageRelay()
    var maskFramebuffer: Framebuffer?
    
    #if DEBUG
    public var debugRenderInfo: String = ""
    #endif
    
    // MARK: -
    // MARK: Initialization and teardown
    
    public init(shader: ShaderProgram, numberOfInputs: UInt = 1) {
        self.maximumInputs = numberOfInputs
        self.shader = shader
        usesAspectRatio = shader.uniformIndex("aspectRatio") != nil
    }
    
    public init(vertexShader: String? = nil, fragmentShader: String, numberOfInputs: UInt = 1, operationName: String = #file) {
        let compiledShader = crashOnShaderCompileFailure(operationName) { try sharedImageProcessingContext.programForVertexShader(vertexShader ?? defaultVertexShaderForInputs(numberOfInputs), fragmentShader: fragmentShader) }
        self.maximumInputs = numberOfInputs
        self.shader = compiledShader
        usesAspectRatio = shader.uniformIndex("aspectRatio") != nil
    }
    
    public init(vertexShaderFile: URL? = nil, fragmentShaderFile: URL, numberOfInputs: UInt = 1, operationName: String = #file) throws {
        let compiledShader: ShaderProgram
        if let vertexShaderFile = vertexShaderFile {
            compiledShader = crashOnShaderCompileFailure(operationName) { try sharedImageProcessingContext.programForVertexShader(vertexShaderFile, fragmentShader: fragmentShaderFile) }
        } else {
            compiledShader = crashOnShaderCompileFailure(operationName) { try sharedImageProcessingContext.programForVertexShader(defaultVertexShaderForInputs(numberOfInputs), fragmentShader: fragmentShaderFile) }
        }
        self.maximumInputs = numberOfInputs
        self.shader = compiledShader
        usesAspectRatio = shader.uniformIndex("aspectRatio") != nil
    }
    
    deinit {
        debugPrint("Deallocating operation: \(self)")
    }
    
    // MARK: -
    // MARK: Rendering
    
    open func newFramebufferAvailable(_ framebuffer: Framebuffer, fromSourceIndex: UInt) {
        if let previousFramebuffer = inputFramebuffers[fromSourceIndex] {
            previousFramebuffer.unlock()
        }
        inputFramebuffers[fromSourceIndex] = framebuffer
        
        guard !activatePassthroughOnNextFrame else { // Use this to allow a bootstrap of cyclical processing, like with a low pass filter
            activatePassthroughOnNextFrame = false
            updateTargetsWithFramebuffer(framebuffer)
            return
        }
        
        if UInt(inputFramebuffers.count) >= maximumInputs {
            #if DEBUG
            let startTime = CACurrentMediaTime()
            var inputsDebugInfo = ""
            for framebuffer in inputFramebuffers {
                inputsDebugInfo.append("\(framebuffer.value.debugRenderInfo), ")
            }
            #endif
            
            renderFrame()
            
            #if DEBUG
            debugRenderInfo = """
    {
        \(Self.self): {
            inputs: [
                \(inputsDebugInfo)
            ],
            output: { size: \(renderFramebuffer.debugRenderInfo), time: \((CACurrentMediaTime() - startTime) * 1000.0)ms }
        }
    },
    """
            #endif
            
            updateTargetsWithFramebuffer(outputFramebuffer, shouldKeepRenderFramebufferIfNoTarget: shouldKeepRenderFramebufferIfNoTarget)
        }
    }
    
    open func renderFrame() {
        renderFramebuffer = sharedImageProcessingContext.framebufferCache.requestFramebufferWithProperties(orientation: .portrait, size: sizeOfInitialStageBasedOnFramebuffer(inputFramebuffers[0]!), stencil: mask != nil)
        
        let textureProperties = initialTextureProperties()
        configureFramebufferSpecificUniforms(inputFramebuffers[0]!)
        
        renderFramebuffer.activateFramebufferForRendering()
        clearFramebufferWithColor(backgroundColor)
        if let maskFramebuffer = maskFramebuffer {
            if drawUnmodifiedImageOutsideOfMask {
                renderQuadWithShader(sharedImageProcessingContext.passthroughShader, uniformSettings: nil, vertexBufferObject: sharedImageProcessingContext.standardImageVBO, inputTextures: textureProperties)
            }
            renderStencilMaskFromFramebuffer(maskFramebuffer)
            internalRenderFunction(inputFramebuffers[0]!, textureProperties: textureProperties)
            disableStencil()
        } else {
            internalRenderFunction(inputFramebuffers[0]!, textureProperties: textureProperties)
        }
    }
    
    public func internalRenderFunction(_ inputFramebuffer: Framebuffer, textureProperties: [InputTextureProperties]) {
        renderQuadWithShader(shader, uniformSettings: uniformSettings, vertexBufferObject: sharedImageProcessingContext.standardImageVBO, inputTextures: textureProperties)
        releaseIncomingFramebuffers()
    }
    
    public func releaseIncomingFramebuffers() {
        var remainingFramebuffers = [UInt: Framebuffer]()
        // If all inputs are still images, have this output behave as one
        renderFramebuffer.timingStyle = .stillImage
        
        var latestTimestamp: Timestamp?
        for (key, framebuffer) in inputFramebuffers {
            // When there are multiple transient input sources, use the latest timestamp as the value to pass along
            if let timestamp = framebuffer.timingStyle.timestamp {
                if !(timestamp < (latestTimestamp ?? timestamp)) {
                    latestTimestamp = timestamp
                    renderFramebuffer.timingStyle = .videoFrame(timestamp: timestamp)
                }
                
                // NOTE: when targets is empty, framebuffer will be unlocked inside updateTargetsWithFramebuffer, so skip it
                if targets.count > 0 {
                    framebuffer.unlock()
                }
            } else if framebuffer.shouldReturnToCache && framebuffer.cache != nil {
                if targets.count > 0 {
                    framebuffer.unlock()
                }
            } else {
                remainingFramebuffers[key] = framebuffer
            }
        }
        
        renderFramebuffer.userInfo = inputFramebuffers[0]!.userInfo
        
        if !releaseAllInputFramebuffersAfterRendering {
            // Cache available incoming framebuffers so that the second or later render only need partial framebuffers. ex. maximumInputs is 2, first time it needs 2 buffers, second time it needs only 1 buffer to render.
            inputFramebuffers = remainingFramebuffers
        } else {
            // Remove all framebuffers so that the second or later render won't render when partial framebuffers comes.
            inputFramebuffers.removeAll()
        }
    }
    
    public func sizeOfInitialStageBasedOnFramebuffer(_ inputFramebuffer: Framebuffer) -> GLSize {
        if let outputSize = overriddenOutputSize {
            return GLSize(outputSize)
        } else {
            return inputFramebuffer.sizeForTargetOrientation(.portrait)
        }
    }
    
    public func initialTextureProperties() -> [InputTextureProperties] {
        var inputTextureProperties = [InputTextureProperties]()
        
        if let outputRotation = overriddenOutputRotation {
            for framebufferIndex in 0..<inputFramebuffers.count {
                inputTextureProperties.append(inputFramebuffers[UInt(framebufferIndex)]!.texturePropertiesForOutputRotation(outputRotation))
            }
        } else {
            for framebufferIndex in 0..<inputFramebuffers.count {
                inputTextureProperties.append(inputFramebuffers[UInt(framebufferIndex)]!.texturePropertiesForTargetOrientation(.portrait))
            }
        }
        
        return inputTextureProperties
    }
    
    public func configureFramebufferSpecificUniforms(_ inputFramebuffer: Framebuffer) {
        if usesAspectRatio {
            let outputRotation = overriddenOutputRotation ?? inputFramebuffer.orientation.rotationNeededForOrientation(.portrait)
            uniformSettings["aspectRatio"] = inputFramebuffer.aspectRatioForRotation(outputRotation)
        }
    }
    
    public func transmitPreviousImage(to target: ImageConsumer, atIndex: UInt) {
        // guard let renderFramebuffer = self.renderFramebuffer, (!renderFramebuffer.timingStyle.isTransient()) else { return }
        
        // renderFramebuffer.lock()
        // target.newFramebufferAvailable(renderFramebuffer, fromSourceIndex:atIndex)
    }
}
