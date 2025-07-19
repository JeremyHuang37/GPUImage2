#if !os(Linux)
import QuartzCore
#endif

public struct Matrix4x4 {
    public var m11: Float, m12: Float, m13: Float, m14: Float
    public var m21: Float, m22: Float, m23: Float, m24: Float
    public var m31: Float, m32: Float, m33: Float, m34: Float
    public var m41: Float, m42: Float, m43: Float, m44: Float
    
    public init(rowMajorValues: [Float]) {
        guard rowMajorValues.count > 15 else { fatalError("Tried to initialize a 4x4 matrix with fewer than 16 values") }
        
        self.m11 = rowMajorValues[0]
        self.m12 = rowMajorValues[1]
        self.m13 = rowMajorValues[2]
        self.m14 = rowMajorValues[3]

        self.m21 = rowMajorValues[4]
        self.m22 = rowMajorValues[5]
        self.m23 = rowMajorValues[6]
        self.m24 = rowMajorValues[7]

        self.m31 = rowMajorValues[8]
        self.m32 = rowMajorValues[9]
        self.m33 = rowMajorValues[10]
        self.m34 = rowMajorValues[11]

        self.m41 = rowMajorValues[12]
        self.m42 = rowMajorValues[13]
        self.m43 = rowMajorValues[14]
        self.m44 = rowMajorValues[15]
    }
    
    public static let identity = Matrix4x4(rowMajorValues: [1.0, 0.0, 0.0, 0.0,
                                                           0.0, 1.0, 0.0, 0.0,
                                                           0.0, 0.0, 1.0, 0.0,
                                                           0.0, 0.0, 0.0, 1.0])
    
    var transform3D: CATransform3D {
        CATransform3D(m11: CGFloat(m11), m12: CGFloat(m12), m13: CGFloat(m13), m14: CGFloat(m14),
                      m21: CGFloat(m21), m22: CGFloat(m22), m23: CGFloat(m23), m24: CGFloat(m24),
                      m31: CGFloat(m31), m32: CGFloat(m32), m33: CGFloat(m33), m34: CGFloat(m34),
                      m41: CGFloat(m41), m42: CGFloat(m42), m43: CGFloat(m43), m44: CGFloat(m44))
    }
}

public struct Matrix3x3 {
    public var m11: Float, m12: Float, m13: Float
    public var m21: Float, m22: Float, m23: Float
    public var m31: Float, m32: Float, m33: Float
    
    public init(rowMajorValues: [Float]) {
        guard rowMajorValues.count > 8 else { fatalError("Tried to initialize a 3x3 matrix with fewer than 9 values") }
        
        self.m11 = rowMajorValues[0]
        self.m12 = rowMajorValues[1]
        self.m13 = rowMajorValues[2]
        
        self.m21 = rowMajorValues[3]
        self.m22 = rowMajorValues[4]
        self.m23 = rowMajorValues[5]
        
        self.m31 = rowMajorValues[6]
        self.m32 = rowMajorValues[7]
        self.m33 = rowMajorValues[8]
    }
    
    public static let identity = Matrix3x3(rowMajorValues: [1.0, 0.0, 0.0,
                                                           0.0, 1.0, 0.0,
                                                           0.0, 0.0, 1.0])
    
    public static let centerOnly = Matrix3x3(rowMajorValues: [0.0, 0.0, 0.0,
                                                             0.0, 1.0, 0.0,
                                                             0.0, 0.0, 0.0])
}

public func orthographicMatrix(_ left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float, anchorTopLeft: Bool = false) -> Matrix4x4 {
    let r_l = right - left
    let t_b = top - bottom
    let f_n = far - near
    var tx = -(right + left) / (right - left)
    var ty = -(top + bottom) / (top - bottom)
    let tz = -(far + near) / (far - near)
    
    let scale: Float
    if anchorTopLeft {
        scale = 4.0
        tx = -1.0
        ty = -1.0
    } else {
        scale = 2.0
    }
    
    return Matrix4x4(rowMajorValues: [
        scale / r_l, 0.0, 0.0, tx,
        0.0, scale / t_b, 0.0, ty,
        0.0, 0.0, scale / f_n, tz,
        0.0, 0.0, 0.0, 1.0])
}

/** -----------------------------------------------------------------
 * Set a perspective projection matrix based on limits of a frustum.
 * @param left   Number Farthest left on the x-axis
 * @param right  Number Farthest right on the x-axis
 * @param bottom Number Farthest down on the y-axis
 * @param top    Number Farthest up on the y-axis
 * @param near   Number Distance to the near clipping plane along the -Z axis
 * @param far    Number Distance to the far clipping plane along the -Z axis
 * @return A perspective transformation matrix
 */
public func frustumMatrix(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> Matrix4x4 {
    assert(left != right, "left == right")
    assert(top != bottom, "top == bottom")
    assert(near != far, "near == far")
    assert(near > 0.0, "near <= 0.0")
    assert(far > 0.0, "far <= 0.0")
    
    let r_width: Float = 1.0 / (right - left)
    let r_height: Float = 1.0 / (top - bottom)
    let r_depth: Float  = 1.0 / (near - far)
    let x: Float = 2.0 * (near * r_width)
    let y: Float = 2.0 * (near * r_height)
    let A: Float = (right + left) * r_width
    let B: Float = (top + bottom) * r_height
    let C: Float = (far + near) * r_depth
    let D: Float = 2.0 * (far * near * r_depth)
    return Matrix4x4(rowMajorValues: [
                        x, 0, 0, 0,
                        0, y, 0, 0,
                        A, B, C, -1.0,
                        0, 0, D, 0])
}

/**
 * Defines a viewing transformation in terms of an eye point, a center of
 * view, and an up vector.
 *
 * @param eyeX eye point X
 * @param eyeY eye point Y
 * @param eyeZ eye point Z
 * @param centerX center of view X
 * @param centerY center of view Y
 * @param centerZ center of view Z
 * @param upX up vector X
 * @param upY up vector Y
 * @param upZ up vector Z
 */
public func lookAtMatrix(eyeX: Float, eyeY: Float, eyeZ: Float, centerX: Float, centerY: Float, centerZ: Float, upX: Float, upY: Float, upZ: Float) -> Matrix4x4 {
    // See the OpenGL GLUT documentation for gluLookAt for a description
    // of the algorithm. We implement it in a straightforward way:
    
    var fx = centerX - eyeX
    var fy = centerY - eyeY
    var fz = centerZ - eyeZ
    
    // Normalize f
    let rlf = 1.0 / sqrt(fx * fx + fy * fy + fz * fz)
    fx *= rlf
    fy *= rlf
    fz *= rlf
    
    // compute s = f x up (x means "cross product")
    var sx = fy * upZ - fz * upY
    var sy = fz * upX - fx * upZ
    var sz = fx * upY - fy * upX
    
    // and normalize s
    let rls = 1.0 / sqrt(sx * sx + sy * sy + sz * sz)
    sx *= rls
    sy *= rls
    sz *= rls
    
    // compute u = s x f
    let ux = sy * fz - sz * fy
    let uy = sz * fx - sx * fz
    let uz = sx * fy - sy * fx
    
    let matrix = Matrix4x4(rowMajorValues: [
                            sx, ux, -fx, 0.0,
                            sy, uy, -fy, 0.0,
                            sz, uz, -fz, 0.0,
                            0.0, 0.0, 0.0, 1.0])
    
    return matrix.translatedBy(x: -eyeX, y: -eyeY, z: -eyeZ)
}

#if !os(Linux)
public extension Matrix4x4 {
    init(_ transform3D: CATransform3D) {
        self.m11 = Float(transform3D.m11)
        self.m12 = Float(transform3D.m12)
        self.m13 = Float(transform3D.m13)
        self.m14 = Float(transform3D.m14)
        
        self.m21 = Float(transform3D.m21)
        self.m22 = Float(transform3D.m22)
        self.m23 = Float(transform3D.m23)
        self.m24 = Float(transform3D.m24)
        
        self.m31 = Float(transform3D.m31)
        self.m32 = Float(transform3D.m32)
        self.m33 = Float(transform3D.m33)
        self.m34 = Float(transform3D.m34)
        
        self.m41 = Float(transform3D.m41)
        self.m42 = Float(transform3D.m42)
        self.m43 = Float(transform3D.m43)
        self.m44 = Float(transform3D.m44)
    }
    
    init(_ transform: CGAffineTransform) {
        self.init(CATransform3DMakeAffineTransform(transform))
    }
    
    func translatedBy(x: Float, y: Float, z: Float) -> Matrix4x4 {
        return CATransform3DTranslate(transform3D, CGFloat(x), CGFloat(y), CGFloat(z)).matrix4x4
    }
    
    func rotatedBy(by angle: Float, x: Float, y: Float, z: Float) -> Matrix4x4 {
        return CATransform3DRotate(transform3D, CGFloat(angle), CGFloat(x), CGFloat(y), CGFloat(z)).matrix4x4
    }
    
    func scaledBy(sx: Float, sy: Float, sz: Float) -> Matrix4x4 {
        return CATransform3DScale(transform3D, CGFloat(sx), CGFloat(sy), CGFloat(sz)).matrix4x4
    }
    
    /// NOTE: In theory, it should be result = lhs x rhs. But in OpenGL, result = rhs x lhs.
    func multiplied(by rhs: Matrix4x4) -> Matrix4x4 {
        return CATransform3DConcat(rhs.transform3D, transform3D).matrix4x4
    }
    
    func inverted() -> Matrix4x4 {
        return CATransform3DInvert(transform3D).matrix4x4
    }
}

extension CATransform3D {
    var matrix4x4: Matrix4x4 {
        Matrix4x4(self)
    }
}
#endif
