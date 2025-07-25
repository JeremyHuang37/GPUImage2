import UIKit
import OpenGLES

public enum PictureFileFormat {
    case png
    case jpeg
}

public class PictureOutput: ImageConsumer {
    public var encodedImageAvailableCallback: ((Data) -> Void)?
    public var encodedImageFormat: PictureFileFormat = .png
    public var encodedJPEGImageCompressionQuality: CGFloat = 0.8
    public var imageAvailableCallback: ((UIImage) -> Void)?
    public var cgImageAvailableCallback: ((CGImage) -> Void)?
    public var onlyCaptureNextFrame = true
    public var keepImageAroundForSynchronousCapture = false
    public var exportWithAlpha = false
    var storedFramebuffer: Framebuffer?
    
    public let sources = SourceContainer()
    public let maximumInputs: UInt = 1
    var url: URL!
    
    #if DEBUG
    public var debugRenderInfo: String = ""
    #endif
    
    public init() {
        debugPrint("PictureOutput init")
    }
    
    deinit {
        debugPrint("PictureOutput deinit")
    }
    
    public func saveNextFrameToURL(_ url: URL, format: PictureFileFormat) {
        onlyCaptureNextFrame = true
        encodedImageFormat = format
        self.url = url // Create an intentional short-term retain cycle to prevent deallocation before next frame is captured
        encodedImageAvailableCallback = {imageData in
            do {
                try imageData.write(to: self.url, options: .atomic)
            } catch {
                // TODO: Handle this better
                print("WARNING: Couldn't save image with error:\(error)")
            }
        }
    }
    
    // TODO: Replace with texture caches
    func cgImageFromFramebuffer(_ framebuffer: Framebuffer) -> CGImage {
        let renderFramebuffer = sharedImageProcessingContext.framebufferCache.requestFramebufferWithProperties(orientation: framebuffer.orientation, size: framebuffer.size)
        renderFramebuffer.lock()
        renderFramebuffer.activateFramebufferForRendering()
        clearFramebufferWithColor(Color.red)
        renderQuadWithShader(sharedImageProcessingContext.passthroughShader, uniformSettings: ShaderUniformSettings(), vertexBufferObject: sharedImageProcessingContext.standardImageVBO, inputTextures: [framebuffer.texturePropertiesForOutputRotation(.noRotation)])
        framebuffer.unlock()
        
        let imageByteSize = Int(framebuffer.size.width * framebuffer.size.height * 4)
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: imageByteSize)
        glReadPixels(0, 0, framebuffer.size.width, framebuffer.size.height, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), data)
        renderFramebuffer.unlock()
        guard let dataProvider = CGDataProvider(dataInfo: nil, data: data, size: imageByteSize, releaseData: dataProviderReleaseCallback) else { fatalError("Could not allocate a CGDataProvider") }
        let defaultRGBColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = exportWithAlpha ? CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue) : CGBitmapInfo()
        return CGImage(width: Int(framebuffer.size.width), height: Int(framebuffer.size.height), bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4 * Int(framebuffer.size.width), space: defaultRGBColorSpace, bitmapInfo: bitmapInfo, provider: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }
    
    public func newFramebufferAvailable(_ framebuffer: Framebuffer, fromSourceIndex: UInt) {
        #if DEBUG
        let startTime = CACurrentMediaTime()
        defer {
            debugRenderInfo = """
{
    PictureOutput: {
        input: \(framebuffer.debugRenderInfo),
        output: { type: ImageOutput, time: \((CACurrentMediaTime() - startTime) * 1000.0)ms }
    }
},
"""
        }
        #endif
        
        if keepImageAroundForSynchronousCapture {
            storedFramebuffer?.unlock()
            storedFramebuffer = framebuffer
        }
        
        if let imageCallback = cgImageAvailableCallback {
            let cgImageFromBytes = cgImageFromFramebuffer(framebuffer)
            
            imageCallback(cgImageFromBytes)
            
            if onlyCaptureNextFrame {
                cgImageAvailableCallback = nil
            }
        }
        
        if let imageCallback = imageAvailableCallback {
            let cgImageFromBytes = cgImageFromFramebuffer(framebuffer)
            
            // TODO: Let people specify orientations
            let image = UIImage(cgImage: cgImageFromBytes, scale: 1.0, orientation: .up)
            
            imageCallback(image)
            
            if onlyCaptureNextFrame {
                imageAvailableCallback = nil
            }
        }
        
        if let imageCallback = encodedImageAvailableCallback {
            let cgImageFromBytes = cgImageFromFramebuffer(framebuffer)
            let image = UIImage(cgImage: cgImageFromBytes, scale: 1.0, orientation: .up)
            let imageData: Data
            switch encodedImageFormat {
            case .png: imageData = image.pngData()! // TODO: Better error handling here
            case .jpeg: imageData = image.jpegData(compressionQuality: encodedJPEGImageCompressionQuality)!
            }
            
            imageCallback(imageData)
            
            if onlyCaptureNextFrame {
                encodedImageAvailableCallback = nil
            }
        }
    }
    
    public func synchronousImageCapture() -> UIImage {
        var outputImage: UIImage!
        sharedImageProcessingContext.runOperationSynchronously {
            guard let currentFramebuffer = storedFramebuffer else { fatalError("Synchronous access requires keepImageAroundForSynchronousCapture to be set to true") }
            
            let cgImageFromBytes = cgImageFromFramebuffer(currentFramebuffer)
            outputImage = UIImage(cgImage: cgImageFromBytes, scale: 1.0, orientation: .up)
        }
        
        return outputImage
    }
}

public extension ImageSource {
    func saveNextFrameToURL(_ url: URL, format: PictureFileFormat) {
        let pictureOutput = PictureOutput()
        pictureOutput.saveNextFrameToURL(url, format: format)
        self --> pictureOutput
    }
}

public extension UIImage {
    func filterWithOperation<T: ImageProcessingOperation>(_ operation: T) throws -> UIImage {
        return try filterWithPipeline {input, output in
            input --> operation --> output
        }
    }
    
    func filterWithPipeline(_ pipeline: (PictureInput, PictureOutput) -> Void) throws -> UIImage {
        let picture = try PictureInput(image: self)
        var outputImage: UIImage?
        let pictureOutput = PictureOutput()
        pictureOutput.onlyCaptureNextFrame = true
        pictureOutput.imageAvailableCallback = {image in
            outputImage = image
        }
        pipeline(picture, pictureOutput)
        picture.processImage(synchronously: true)
        return outputImage!
    }
}

// Why are these flipped in the callback definition?
func dataProviderReleaseCallback(_ context: UnsafeMutableRawPointer?, data: UnsafeRawPointer, size: Int) {
    data.deallocate()
}
