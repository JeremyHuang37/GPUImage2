import Foundation

#if os(iOS)
import UIKit
#endif

public struct Position {
    public let x: Float
    public let y: Float
    public let z: Float?
    
    public init (_ x: Float, _ y: Float, _ z: Float? = nil) {
        self.x = x
        self.y = y
        self.z = z
    }
    
#if !os(Linux)
    public init(point: CGPoint) {
        self.x = Float(point.x)
        self.y = Float(point.y)
        self.z = nil
    }
#endif
	
    public static let center = Position(0.5, 0.5)
    public static let zero = Position(0.0, 0.0)
}

public extension Position {
    func distance(to otherPosition: Position) -> Float {
        let z = z ?? 0.0
        let otherZ = otherPosition.z ?? 0.0
        return sqrt(pow(x - otherPosition.x, 2.0) + pow(y - otherPosition.y, 2.0) + pow(z - otherZ, 2.0))
    }
    
    func appliedTransform(_ t: Matrix4x4) -> Position {
        let z = z ?? 0.0
        let newX = t.m11 * x + t.m21 * y + t.m31 * z + t.m41
        let newY = t.m12 * x + t.m22 * y + t.m32 * z + t.m42
        let newZ = t.m13 * x + t.m23 * y + t.m33 * z + t.m43
        return Position(newX, newY, newZ)
    }
    
    func appliedProjection(_ t: Matrix4x4) -> Position {
        let z = z ?? 0.0
        let newX = t.m11 * x + t.m21 * y + t.m31 * z + t.m41
        let newY = t.m12 * x + t.m22 * y + t.m32 * z + t.m42
        let newZ = t.m13 * x + t.m23 * y + t.m33 * z + t.m43
        let newW = t.m14 * x + t.m24 * y + t.m34 * z + t.m44
        return Position(newX / newW, newY / newW, newZ / newW)
    }
    
    func appliedUnProjection(_ t: Matrix4x4) -> Position {
        let ti = t.inverted()
        return appliedProjection(ti)
    }
    
    func ndcToTextureCoordinate() -> Position {
        if let z = z {
            return Position(x * 0.5 + 0.5, y * 0.5 + 0.5, z * 0.5 + 0.5)
        } else {
            return Position(x * 0.5 + 0.5, y * 0.5 + 0.5)
        }
    }
    
    func textureToNDCCoordinate() -> Position {
        if let z = z {
            return Position(x * 2.0 - 1.0, y * 2.0 - 1.0, z * 2.0 - 1.0)
        } else {
            return Position(x * 2.0 - 1.0, y * 2.0 - 1.0)
        }
    }
    
    func ndcToScreen(size: CGSize) -> CGPoint {
        let texturePoint = ndcToTextureCoordinate()
        return CGPoint(x: CGFloat(texturePoint.x) * size.width, y: CGFloat(texturePoint.y) * size.height)
    }
}

public extension CGPoint {
    var position: Position {
        Position(Float(x), Float(y))
    }
}
