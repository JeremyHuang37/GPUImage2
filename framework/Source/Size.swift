public struct Size {
    public let width: Float
    public let height: Float
    
    public init(width: Float, height: Float) {
        self.width = width
        self.height = height
    }
    
    #if DEBUG
    public var debugRenderInfo: String { "\(width)x\(height)" }
    #endif
}
