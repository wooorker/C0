/*
 Copyright 2017 S
 
 This file is part of C0.
 
 C0 is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 C0 is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with C0.  If not, see <http://www.gnu.org/licenses/>.
 */

import CoreGraphics

func hypot²<T: BinaryFloatingPoint>(_ lhs: T, _ rhs: T) -> T {
    return lhs * lhs + rhs * rhs
}

protocol Interpolatable {
    static func linear(_ f0: Self, _ f1: Self, t: CGFloat) -> Self
    static func firstMonospline(_ f1: Self, _ f2: Self, _ f3: Self,
                                with msx: MonosplineX) -> Self
    static func monospline(_ f0: Self, _ f1: Self, _ f2: Self, _ f3: Self,
                           with msx: MonosplineX) -> Self
    static func endMonospline(_ f0: Self, _ f1: Self, _ f2: Self,
                              with msx: MonosplineX) -> Self
}
extension Comparable {
    func clip(min: Self, max: Self) -> Self {
        return self < min ? min : (self > max ? max : self)
    }
    func isOver(old: Self, new: Self) -> Bool {
        return (new >= self && old < self) || (new <= self && old > self)
    }
}

protocol AdditiveGroup: Equatable {
    static func +(lhs: Self, rhs: Self) -> Self
    static func -(lhs: Self, rhs: Self) -> Self
    prefix static func -(x: Self) -> Self
}
extension AdditiveGroup {
    static func -(lhs: Self, rhs: Self) -> Self {
        return (lhs + (-rhs))
    }
}

extension Int {
    static func gcd(_ m: Int, _ n: Int) -> Int {
        return n == 0 ? m : gcd(n, m % n)
    }
}
extension Int: Interpolatable {
    static func linear(_ f0: Int, _ f1: Int, t: CGFloat) -> Int {
        return Int(CGFloat.linear(CGFloat(f0), CGFloat(f1), t: t))
    }
    static func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) -> Int {
        return Int(CGFloat.firstMonospline(CGFloat(f1), CGFloat(f2), CGFloat(f3), with: msx))
    }
    static func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) -> Int {
        return Int(CGFloat.monospline(CGFloat(f0), CGFloat(f1), CGFloat(f2), CGFloat(f3), with: msx))
    }
    static func endMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with msx: MonosplineX) -> Int {
        return Int(CGFloat.endMonospline(CGFloat(f0), CGFloat(f1), CGFloat(f2), with: msx))
    }
}

typealias Q = RationalNumber
struct RationalNumber: AdditiveGroup, SignedNumeric {
    var p, q: Int
    init(_ p: Int, _ q: Int) {
        if q == 0 {
            fatalError()
        }
        let d = abs(Int.gcd(p, q)) * (q / abs(q))
        (self.p, self.q) = d == 1 ? (p, q) : (p / d, q / d)
    }
    init(_ n: Int) {
        self.init(n, 1)
    }
    init?<T>(exactly source: T) where T : BinaryInteger {
        if let integer = Int(exactly: source) {
            self.init(integer)
        } else {
            return nil
        }
    }
    
    var inversed: RationalNumber? {
        return p == 0 ? nil : RationalNumber(q, p)
    }
    var integralPart: Int {
        return p / q
    }
    var decimalPart: RationalNumber {
        return self - RationalNumber(integralPart)
    }
    
    var magnitude: RationalNumber {
        return RationalNumber(abs(p), q)
    }
    typealias Magnitude = RationalNumber
    
    static func +(lhs: RationalNumber, rhs: RationalNumber) -> RationalNumber {
        return RationalNumber(lhs.p * rhs.q + lhs.q * rhs.p, lhs.q * rhs.q)
    }
    static func +=(lhs: inout RationalNumber, rhs: RationalNumber) {
        lhs = lhs + rhs
    }
    static func -=(lhs: inout RationalNumber, rhs: RationalNumber) {
        lhs = lhs - rhs
    }
    static func *=(lhs: inout RationalNumber, rhs: RationalNumber) {
        lhs = lhs * rhs
    }
    prefix static func -(x: RationalNumber) -> RationalNumber {
        return RationalNumber(-x.p, x.q)
    }
    static func *(lhs: RationalNumber, rhs: RationalNumber) -> RationalNumber {
        return RationalNumber(lhs.p * rhs.p, lhs.q * rhs.q)
    }
    static func /(lhs: RationalNumber, rhs: RationalNumber) -> RationalNumber {
        return RationalNumber(lhs.p * rhs.q, lhs.q * rhs.p)
    }
}
extension RationalNumber: Equatable {
    static func ==(lhs: RationalNumber, rhs: RationalNumber) -> Bool {
        return lhs.p * rhs.q == lhs.q * rhs.p
    }
}
extension RationalNumber: Comparable {
    static func <(lhs: RationalNumber, rhs: RationalNumber) -> Bool {
        return lhs.p * rhs.q < rhs.p * lhs.q
    }
}
extension RationalNumber: Hashable {
    var hashValue: Int {
        return (p.hashValue &* 31) &+ q.hashValue
    }
}
extension RationalNumber: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let p = try container.decode(Int.self)
        let q = try container.decode(Int.self)
        self.init(p, q)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(p)
        try container.encode(q)
    }
}
extension RationalNumber: Referenceable {
    static let name = Localization(english: "Rational Number", japanese: "有理数")
}
extension RationalNumber: Drawable {
    func responder(with bounds: CGRect) -> Respondable {
        return description.responder(with: bounds)
    }
}
extension RationalNumber: CustomStringConvertible {
    var description: String {
        switch q {
        case 1:  return "\(p)"
        default: return "\(p) / \(q)"
        }
    }
}
extension RationalNumber: ExpressibleByIntegerLiteral {
    typealias IntegerLiteralType = Int
    init(integerLiteral value: Int) {
        self.init(value)
    }
}
extension Double {
    init(_ x: RationalNumber) {
        self = Double(x.p) / Double(x.q)
    }
}
func floor(_ x: RationalNumber) -> RationalNumber {
    let integralPart = x.integralPart
    return RationalNumber(x.decimalPart.p == 0 ?
        integralPart : (integralPart < 0 ? integralPart - 1 : integralPart))
}
func ceil(_ x: RationalNumber) -> RationalNumber {
    return RationalNumber(x.decimalPart.p == 0 ? x.integralPart : x.integralPart + 1)
}

extension Double {
    static func random(min: Double, max: Double) -> Double {
        return (max - min) * (Double(arc4random_uniform(UInt32.max)) / Double(UInt32.max)) + min
    }
}
extension CGFloat {
    func interval(scale: CGFloat) -> CGFloat {
        if scale == 0 {
            return self
        } else {
            let t = floor(self / scale) * scale
            return self - t > scale / 2 ? t + scale : t
        }
    }
    func differenceRotation(_ other: CGFloat) -> CGFloat {
        let a = self - other
        return a + (a > .pi ? -2 * (.pi) : (a < -.pi ? 2 * (.pi) : 0))
    }
    var clipRotation: CGFloat {
        return self < -.pi ? self + 2 * (.pi) : (self > .pi ? self - 2 * (.pi) : self)
    }
    func isApproximatelyEqual(other: CGFloat, roundingError: CGFloat = 0.0000000001) -> Bool {
        return abs(self - other) < roundingError
    }
    var ²: CGFloat {
        return self * self
    }
    func loopValue(other: CGFloat, begin: CGFloat = 0, end: CGFloat = 1) -> CGFloat {
        if other < self {
            let value = (other - begin) + (end - self)
            return self - other < value ? self : self - (end - begin)
        } else {
            let value = (self - begin) + (end - other)
            return other - self < value ? self : self + (end - begin)
        }
    }
    func loopValue(begin: CGFloat = 0, end: CGFloat = 1) -> CGFloat {
        return self < begin ? self + (end - begin) : (self > end ? self - (end - begin) : self)
    }
    static func random(min: CGFloat, max: CGFloat) -> CGFloat {
        return (max - min) * (CGFloat(arc4random_uniform(UInt32.max)) / CGFloat(UInt32.max)) + min
    }
    static func bilinear(x: CGFloat, y: CGFloat,
                         a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat) -> CGFloat {
        return x * y * (a - b - c + d) + x * (b - a) + y * (c - a) + a
    }
}
extension CGFloat: Interpolatable {
    static func linear(_ f0: CGFloat, _ f1: CGFloat, t: CGFloat) -> CGFloat {
        return f0 * (1 - t) + f1 * t
    }
    static func firstMonospline(_ f1: CGFloat, _ f2: CGFloat, _ f3: CGFloat,
                                with msx: MonosplineX) -> CGFloat {
        
        let s1 = (f2 - f1) * msx.reciprocalH1, s2 = (f3 - f2) * msx.reciprocalH2
        let signS1: CGFloat = s1 > 0 ? 1 : -1, signS2: CGFloat = s2 > 0 ? 1 : -1
        let yPrime1 = s1
        let yPrime2 = (signS1 + signS2) * Swift.min(Swift.abs(s1), Swift.abs(s2),
                                                    0.5 * Swift.abs((msx.h2 * s1 + msx.h1 * s2)
                                                        * msx.reciprocalH1H2))
        return _monospline(f1, s1, yPrime1, yPrime2, with: msx)
    }
    static func monospline(_ f0: CGFloat, _ f1: CGFloat, _ f2: CGFloat, _ f3: CGFloat,
                           with msx: MonosplineX) -> CGFloat {
        
        let s0 = (f1 - f0) * msx.reciprocalH0
        let s1 = (f2 - f1) * msx.reciprocalH1, s2 = (f3 - f2) * msx.reciprocalH2
        let signS0: CGFloat = s0 > 0 ? 1 : -1
        let signS1: CGFloat = s1 > 0 ? 1 : -1, signS2: CGFloat = s2 > 0 ? 1 : -1
        let yPrime1 = (signS0 + signS1) * Swift.min(Swift.abs(s0), Swift.abs(s1),
                                                    0.5 * Swift.abs((msx.h1 * s0 + msx.h0 * s1)
                                                        * msx.reciprocalH0H1))
        let yPrime2 = (signS1 + signS2) * Swift.min(Swift.abs(s1), Swift.abs(s2),
                                                    0.5 * Swift.abs((msx.h2 * s1 + msx.h1 * s2)
                                                        * msx.reciprocalH1H2))
        return _monospline(f1, s1, yPrime1, yPrime2, with: msx)
    }
    static func endMonospline(_ f0: CGFloat, _ f1: CGFloat, _ f2: CGFloat,
                              with msx: MonosplineX) -> CGFloat {
        
        let s0 = (f1 - f0) * msx.reciprocalH0, s1 = (f2 - f1) * msx.reciprocalH1
        let signS0: CGFloat = s0 > 0 ? 1 : -1, signS1: CGFloat = s1 > 0 ? 1 : -1
        let yPrime1 = (signS0 + signS1) * Swift.min(Swift.abs(s0), Swift.abs(s1),
                                                    0.5 * Swift.abs((msx.h1 * s0 + msx.h0 * s1)
                                                        * msx.reciprocalH0H1))
        let yPrime2 = s1
        return _monospline(f1, s1, yPrime1, yPrime2, with: msx)
    }
    private static func _monospline(_ f1: CGFloat, _ s1: CGFloat,
                                    _ yPrime1: CGFloat, _ yPrime2: CGFloat,
                                    with msx: MonosplineX) -> CGFloat {
        
        let a = (yPrime1 + yPrime2 - 2 * s1) * msx.reciprocalH1H1
        let b = (3 * s1 - 2 * yPrime1 - yPrime2) * msx.reciprocalH1, c = yPrime1, d = f1
        return a * msx.xx3 + b * msx.xx2 + c * msx.xx1 + d
    }
}

struct Point {
    var x = 0.0, y = 0.0
    func with(x: Double) -> Point {
        return Point(x: x, y: y)
    }
    func with(y: Double) -> Point {
        return Point(x: x, y: y)
    }
}
extension Point: Equatable {
    static func ==(lhs: Point, rhs: Point) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
}
extension Point: Hashable {
    var hashValue: Int {
        return (x.hashValue << MemoryLayout<Double>.size) ^ y.hashValue
    }
}
extension Point: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let x = try container.decode(Double.self)
        let y = try container.decode(Double.self)
        self.init(x: x, y: y)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
    }
}
extension Point: Referenceable {
    static let name = Localization(english: "Point", japanese: "ポイント")
}

extension CGPoint {
    func mid(_ other: CGPoint) -> CGPoint {
        return CGPoint(x: (x + other.x) / 2, y: (y + other.y) / 2)
    }
    
    static func intersection(p0: CGPoint, p1: CGPoint, q0: CGPoint, q1: CGPoint) -> Bool {
        let a0 = (p0.x - p1.x) * (q0.y - p0.y) + (p0.y - p1.y) * (p0.x - q0.x)
        let b0 = (p0.x - p1.x) * (q1.y - p0.y) + (p0.y - p1.y) * (p0.x - q1.x)
        if a0 * b0 < 0 {
            let a1 = (q0.x - q1.x) * (p0.y - q0.y) + (q0.y - q1.y) * (q0.x - p0.x)
            let b1 = (q0.x - q1.x) * (p1.y - q0.y) + (q0.y - q1.y) * (q0.x - p1.x)
            if a1 * b1 < 0 {
                return true
            }
        }
        return false
    }
    static func intersectionLineSegment(_ p1: CGPoint, _ p2: CGPoint,
                                        _ p3: CGPoint, _ p4: CGPoint,
                                        isSegmentP3P4: Bool = true) -> CGPoint? {
        
        let delta = (p2.x - p1.x) * (p4.y - p3.y) - (p2.y - p1.y) * (p4.x - p3.x)
        if delta != 0 {
            let u = ((p3.x - p1.x) * (p4.y - p3.y) - (p3.y - p1.y) * (p4.x - p3.x)) / delta
            if u >= 0 && u <= 1 {
                let v = ((p3.x - p1.x) * (p2.y - p1.y) - (p3.y - p1.y) * (p2.x - p1.x)) / delta
                if v >= 0 && v <= 1 || !isSegmentP3P4 {
                    return CGPoint(x: p1.x + u * (p2.x - p1.x), y: p1.y + u * (p2.y - p1.y))
                }
            }
        }
        return nil
    }
    static func intersectionLine(_ p1: CGPoint, _ p2: CGPoint,
                                 _ p3: CGPoint, _ p4: CGPoint) -> CGPoint? {
        
        let d = (p2.x - p1.x) * (p4.y - p3.y) - (p2.y - p1.y) * (p4.x - p3.x)
        if d == 0 {
            return nil
        }
        let u = ((p3.x - p1.x) * (p4.y - p3.y) - (p3.y - p1.y) * (p4.x - p3.x)) / d
        return CGPoint(x: p1.x + u * (p2.x - p1.x), y: p1.y + u * (p2.y - p1.y))
    }
    func isApproximatelyEqual(other: CGPoint, roundingError: CGFloat = 0.0000000001.cf) -> Bool {
        return x.isApproximatelyEqual(other: other.x, roundingError: roundingError)
            && y.isApproximatelyEqual(other: other.y, roundingError: roundingError)
    }
    func tangential(_ other: CGPoint) -> CGFloat {
        return atan2(other.y - y, other.x - x)
    }
    func crossVector(_ other: CGPoint) -> CGFloat {
        return x * other.y - y * other.x
    }
    func distance(_ other: CGPoint) -> CGFloat {
        return hypot(other.x - x, other.y - y)
    }
    func distanceWithLine(ap: CGPoint, bp: CGPoint) -> CGFloat {
        return ap == bp ? distance(ap) : abs((bp - ap).crossVector(self - ap)) / ap.distance(bp)
    }
    func normalLinearInequality(ap: CGPoint, bp: CGPoint) -> Bool {
        if bp.y - ap.y == 0 {
            return bp.x > ap.x ? x <= ap.x : x >= ap.x
        } else {
            let n = -(bp.x - ap.x) / (bp.y - ap.y)
            let ny = n * (x - ap.x) + ap.y
            return bp.y > ap.y ? y <= ny : y >= ny
        }
    }
    func tWithLineSegment(ap: CGPoint, bp: CGPoint) -> CGFloat {
        if ap == bp {
            return 0.5
        } else {
            let bav = bp - ap, pav = self - ap
            return ((bav.x * pav.x + bav.y * pav.y) / (bav.x * bav.x + bav.y * bav.y))
                .clip(min: 0, max: 1)
        }
    }
    static func boundsPointWithLine(ap: CGPoint, bp: CGPoint,
                                    bounds: CGRect) -> (p0: CGPoint, p1: CGPoint)? {
        
        let p0 = CGPoint.intersectionLineSegment(CGPoint(x: bounds.minX, y: bounds.minY),
                                                 CGPoint(x: bounds.minX, y: bounds.maxY),
                                                 ap, bp, isSegmentP3P4: false)
        let p1 = CGPoint.intersectionLineSegment(CGPoint(x: bounds.maxX, y: bounds.minY),
                                                 CGPoint(x: bounds.maxX, y: bounds.maxY),
                                                 ap, bp, isSegmentP3P4: false)
        let p2 = CGPoint.intersectionLineSegment(CGPoint(x: bounds.minX, y: bounds.minY),
                                                 CGPoint(x: bounds.maxX, y: bounds.minY),
                                                 ap, bp, isSegmentP3P4: false)
        let p3 = CGPoint.intersectionLineSegment(CGPoint(x: bounds.minX, y: bounds.maxY),
                                                 CGPoint(x: bounds.maxX, y: bounds.maxY),
                                                 ap, bp, isSegmentP3P4: false)
        if let p0 = p0 {
            if let p1 = p1, p0 != p1 {
                return (p0, p1)
            } else if let p2 = p2, p0 != p2 {
                return (p0, p2)
            } else if let p3 = p3, p0 != p3 {
                return (p0, p3)
            }
        } else if let p1 = p1 {
            if let p2 = p2, p1 != p2 {
                return (p1, p2)
            } else if let p3 = p3, p1 != p3 {
                return (p1, p3)
            }
        } else if let p2 = p2, let p3 = p3, p2 != p3 {
            return (p2, p3)
        }
        return nil
    }
    func distanceWithLineSegment(ap: CGPoint, bp: CGPoint) -> CGFloat {
        if ap == bp {
            return distance(ap)
        } else {
            let bav = bp - ap, pav = self - ap
            let r = (bav.x * pav.x + bav.y * pav.y) / (bav.x * bav.x + bav.y * bav.y)
            if r <= 0 {
                return distance(ap)
            } else if r > 1 {
                return distance(bp)
            } else {
                return abs(bav.crossVector(pav)) / ap.distance(bp)
            }
        }
    }
    func nearestWithLine(ap: CGPoint, bp: CGPoint) -> CGPoint {
        if ap == bp {
            return ap
        } else {
            let av = bp - ap, bv = self - ap
            let r = (av.x * bv.x + av.y * bv.y) / (av.x * av.x + av.y * av.y)
            return CGPoint(x: ap.x + r * av.x, y: ap.y + r * av.y)
        }
    }
    var integral: CGPoint {
        return CGPoint(x: round(x), y: round(y))
    }
    func perpendicularDeltaPoint(withDistance distance: CGFloat) -> CGPoint {
        if self == CGPoint() {
            return CGPoint(x: distance, y: 0)
        } else {
            let r = distance / hypot(x, y)
            return CGPoint(x: -r * y, y: r * x)
        }
    }
    func distance²(_ other: CGPoint) -> CGFloat {
        let nx = x - other.x, ny = y - other.y
        return nx * nx + ny * ny
    }
    static func differenceAngle(_ p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGFloat {
        let pa = p1 - p0
        let pb = p2 - pa
        let ab = hypot(pa.x, pa.y) * hypot(pb.x, pb.y)
        return ab == 0 ? 0 :
            (pa.x * pb.y - pa.y * pb.x > 0 ? 1 : -1) * acos((pa.x * pb.x + pa.y * pb.y) / ab)
    }
    static func differenceAngle(p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGFloat {
        return differenceAngle(a: p1 - p0, b: p2 - p1)
    }
    static func differenceAngle(a: CGPoint, b: CGPoint) -> CGFloat {
        return atan2(a.x * b.y - a.y * b.x, a.x * b.x + a.y * b.y)
    }
    static func +(lhs: CGPoint, rha: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rha.x, y: lhs.y + rha.y)
    }
    static func +=(lhs: inout CGPoint, rhs: CGPoint) {
        lhs.x += rhs.x
        lhs.y += rhs.y
    }
    static func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    prefix static func -(p: CGPoint) -> CGPoint {
        return CGPoint(x: -p.x, y: -p.y)
    }
    static func *(lhs: CGFloat, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: rhs.x * lhs, y: rhs.y * lhs)
    }
    static func *(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
    static func /(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
    }
    
    func draw(radius r: CGFloat, lineWidth: CGFloat = 1,
              inColor: Color = .knob, outColor: Color = .border, in ctx: CGContext) {
        
        let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
        ctx.setFillColor(outColor.cgColor)
        ctx.fillEllipse(in: rect.insetBy(dx: -lineWidth, dy: -lineWidth))
        ctx.setFillColor(inColor.cgColor)
        ctx.fillEllipse(in: rect)
    }
}
extension CGPoint: Hashable {
    public var hashValue: Int {
        return (x.hashValue << MemoryLayout<CGFloat>.size) ^ y.hashValue
    }
}
extension CGPoint: Interpolatable {
    static func linear(_ f0: CGPoint, _ f1: CGPoint, t: CGFloat) -> CGPoint {
        return CGPoint(x: CGFloat.linear(f0.x, f1.x, t: t), y: CGFloat.linear(f0.y, f1.y, t: t))
    }
    static func firstMonospline(_ f1: CGPoint, _ f2: CGPoint, _ f3: CGPoint,
                                with msx: MonosplineX) -> CGPoint {
        return CGPoint(
            x: CGFloat.firstMonospline(f1.x, f2.x, f3.x, with: msx),
            y: CGFloat.firstMonospline(f1.y, f2.y, f3.y, with: msx)
        )
    }
    static func monospline(_ f0: CGPoint, _ f1: CGPoint, _ f2: CGPoint, _ f3: CGPoint,
                           with msx: MonosplineX) -> CGPoint {
        return CGPoint(
            x: CGFloat.monospline(f0.x, f1.x, f2.x, f3.x, with: msx),
            y: CGFloat.monospline(f0.y, f1.y, f2.y, f3.y, with: msx)
        )
    }
    static func endMonospline(_ f0: CGPoint, _ f1: CGPoint, _ f2: CGPoint,
                              with msx: MonosplineX) -> CGPoint {
        return CGPoint(
            x: CGFloat.endMonospline(f0.x, f1.x, f2.x, with: msx),
            y: CGFloat.endMonospline(f0.y, f1.y, f2.y, with: msx)
        )
    }
}
extension CGPoint: Referenceable {
    static let name = Localization(english: "Point", japanese: "ポイント")
}

struct Size {
    var width = 0.0, height = 0.0
    func with(width: Double) -> Size {
        return Size(width: width, height: height)
    }
    func with(h: Double) -> Size {
        return Size(width: width, height: height)
    }
    
    static func *(lhs: Size, rhs: Double) -> Size {
        return Size(width: lhs.width * rhs, height: lhs.height * rhs)
    }
}
extension Size: Equatable {
    static func ==(lhs: Size, rhs: Size) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height
    }
}
extension Size: Hashable {
    var hashValue: Int {
        return (width.hashValue << MemoryLayout<Double>.size) ^ height.hashValue
    }
}
extension Size: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let width = try container.decode(Double.self)
        let height = try container.decode(Double.self)
        self.init(width: width, height: height)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(width)
        try container.encode(height)
    }
}
extension Size: Referenceable {
    static let name = Localization(english: "Size", japanese: "サイズ")
}

extension CGSize {
    static func *(lhs: CGSize, rhs: CGFloat) -> CGSize {
        return CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
    }
    func with(width: CGFloat) -> CGSize {
        return CGSize(width: width, height: height)
    }
    func with(height: CGFloat) -> CGSize {
        return CGSize(width: width, height: height)
    }
}
extension CGSize: Referenceable {
    static let name = Localization(english: "Size", japanese: "サイズ")
}

struct Rect {
    var origin = Point(), size = Size()
    func with(origin: Point) -> Rect {
        return Rect(origin: origin, size: size)
    }
    func with(_ size: Size) -> Rect {
        return Rect(origin: origin, size: size)
    }
    
//    func distance²(_ point: Point) -> Double {
//        return AABB(self).nearestDistance²(point)
//    }
//    func unionNoEmpty(_ other: Rect) -> Rect {
//        return other.isEmpty ? self : (isEmpty ? other : union(other))
//    }
//    var circleBounds: Rect {
//        let r = hypot(width, height) / 2
//        return Rect(x: midX - r, y: midY - r, width: r * 2, height: r * 2)
//    }
//    func inset(by width: Double) -> Rect {
//        return insetBy(dx: width, dy: width)
//    }
}
extension Rect: Equatable {
    static func ==(lhs: Rect, rhs: Rect) -> Bool {
        return lhs.origin == rhs.origin && lhs.size == rhs.size
    }
}
//extension Rect: Hashable {
//    var hashValue: Int {
//        return (width.hashValue << MemoryLayout<Double>.size) ^ height.hashValue
//    }
//}
extension Rect: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let origin = try container.decode(Point.self)
        let size = try container.decode(Size.self)
        self.init(origin: origin, size: size)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(origin)
        try container.encode(size)
    }
}
extension Rect: Referenceable {
    static let name = Localization(english: "Rect", japanese: "矩形")
}
//func round(_ rect: Rect) -> Rect {
//    let minX = round(rect.minX), maxX = round(rect.maxX)
//    let minY = round(rect.minY), maxY = round(rect.maxY)
//    return AABB(minX: minX, maxX: maxX, minY: minY, maxY: maxY).rect
//}

extension CGRect {
    func distance²(_ point: CGPoint) -> CGFloat {
        return AABB(self).nearestDistance²(point)
    }
    func unionNoEmpty(_ other: CGRect) -> CGRect {
        return other.isEmpty ? self : (isEmpty ? other : union(other))
    }
    var circleBounds: CGRect {
        let r = hypot(width, height) / 2
        return CGRect(x: midX - r, y: midY - r, width: r * 2, height: r * 2)
    }
    func inset(by width: CGFloat) -> CGRect {
        return insetBy(dx: width, dy: width)
    }
}
func round(_ rect: CGRect) -> CGRect {
    let minX = round(rect.minX), maxX = round(rect.maxX)
    let minY = round(rect.minY), maxY = round(rect.maxY)
    return AABB(minX: minX, maxX: maxX, minY: minY, maxY: maxY).rect
}

struct AABB: Codable {
    var minX = 0.0.cf, maxX = 0.0.cf, minY = 0.0.cf, maxY = 0.0.cf
    init(minX: CGFloat = 0, maxX: CGFloat = 0, minY: CGFloat = 0, maxY: CGFloat = 0) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }
    init(_ rect: CGRect) {
        minX = rect.minX
        minY = rect.minY
        maxX = rect.maxX
        maxY = rect.maxY
    }
    init(_ b: Bezier2) {
        minX = min(b.p0.x, b.cp.x, b.p1.x)
        minY = min(b.p0.y, b.cp.y, b.p1.y)
        maxX = max(b.p0.x, b.cp.x, b.p1.x)
        maxY = max(b.p0.y, b.cp.y, b.p1.y)
    }
    init(_ b: Bezier3) {
        minX = min(b.p0.x, b.cp0.x, b.cp1.x, b.p1.x)
        minY = min(b.p0.y, b.cp0.y, b.cp1.y, b.p1.y)
        maxX = max(b.p0.x, b.cp0.x, b.cp1.x, b.p1.x)
        maxY = max(b.p0.y, b.cp0.y, b.cp1.y, b.p1.y)
    }
    
    var width: CGFloat {
        return maxX - minX
    }
    var height: CGFloat {
        return maxY - minY
    }
    var position: CGPoint {
        return CGPoint(x: minX, y: minY)
    }
    var rect: CGRect {
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    func contains(_ point: CGPoint) -> Bool {
        return (point.x >= minX && point.x <= maxX) && (point.y >= minY && point.y <= maxY)
    }
    func clippedPoint(with point: CGPoint) -> CGPoint {
        return CGPoint(x: point.x.clip(min: minX, max: maxX),
                       y: point.y.clip(min: minY, max: maxY))
    }
    func nearestDistance²(_ p: CGPoint) -> CGFloat {
        if p.x < minX {
            return p.y < minY ?
                hypot²(minX - p.x, minY - p.y) :
                (p.y <= maxY ? (minX - p.x).² : hypot²(minX - p.x, maxY - p.y))
        } else if p.x <= maxX {
            return p.y < minY ?
                (minY - p.y).² :
                (p.y <= maxY ? 0 : (minY - p.y).²)
        } else {
            return p.y < minY ?
                hypot²(maxX - p.x, minY - p.y) :
                (p.y <= maxY ? (maxX - p.x).² : hypot²(maxX - p.x, maxY - p.y))
        }
    }
    func intersects(_ other: AABB) -> Bool {
        return minX <= other.maxX && maxX >= other.minX
            && minY <= other.maxY && maxY >= other.minY
    }
}

struct MonosplineX {
    let h0: CGFloat, h1: CGFloat, h2: CGFloat
    let reciprocalH0: CGFloat, reciprocalH1: CGFloat, reciprocalH2: CGFloat
    let reciprocalH0H1: CGFloat, reciprocalH1H2: CGFloat, reciprocalH1H1: CGFloat
    let xx3: CGFloat, xx2: CGFloat, xx1: CGFloat, t: CGFloat
    init(x1: CGFloat, x2: CGFloat, x3: CGFloat, x: CGFloat, t: CGFloat) {
        self.h0 = 0
        self.h1 = x2 - x1
        self.h2 = x3 - x2
        self.reciprocalH0 = 0
        self.reciprocalH1 = 1 / h1
        self.reciprocalH2 = 1 / h2
        self.reciprocalH0H1 = 0
        self.reciprocalH1H2 = 1 / (h1 + h2)
        self.reciprocalH1H1 = 1 / (h1 * h1)
        self.t = t
        self.xx1 = x - x1
        self.xx2 = xx1 * xx1
        self.xx3 = xx1 * xx1 * xx1
    }
    init(x0: CGFloat, x1: CGFloat, x2: CGFloat, x3: CGFloat, x: CGFloat, t: CGFloat) {
        self.h0 = x1 - x0
        self.h1 = x2 - x1
        self.h2 = x3 - x2
        self.reciprocalH0 = 1 / h0
        self.reciprocalH1 = 1 / h1
        self.reciprocalH2 = 1 / h2
        self.reciprocalH0H1 = 1 / (h0 + h1)
        self.reciprocalH1H2 = 1 / (h1 + h2)
        self.reciprocalH1H1 = 1 / (h1 * h1)
        self.t = t
        self.xx1 = x - x1
        self.xx2 = xx1 * xx1
        self.xx3 = xx1 * xx1 * xx1
    }
    init(x0: CGFloat, x1: CGFloat, x2: CGFloat, x: CGFloat, t: CGFloat) {
        self.h0 = x1 - x0
        self.h1 = x2 - x1
        self.h2 = 0
        self.reciprocalH0 = 1 / h0
        self.reciprocalH1 = 1 / h1
        self.reciprocalH2 = 0
        self.reciprocalH0H1 = 1 / (h0 + h1)
        self.reciprocalH1H2 = 0
        self.reciprocalH1H1 = 1 / (h1 * h1)
        self.t = t
        self.xx1 = x - x1
        self.xx2 = xx1 * xx1
        self.xx3 = xx1 * xx1 * xx1
    }
}

struct RotateRect: Codable {
    let centerPoint: CGPoint, size: CGSize, angle: CGFloat
    init(convexHullPoints chps: [CGPoint]) {
        guard !chps.isEmpty else {
            fatalError()
        }
        guard chps.count > 1 else {
            self.centerPoint = chps[0]
            self.size = CGSize()
            self.angle = 0.0
            return
        }
        var minArea = CGFloat.infinity, minAngle = 0.0.cf, minBounds = CGRect()
        for (i, p) in chps.enumerated() {
            let nextP = chps[i == chps.count - 1 ? 0 : i + 1]
            let angle = p.tangential(nextP)
            let affine = CGAffineTransform(rotationAngle: -angle)
            let ps = chps.map { $0.applying(affine) }
            let bounds = CGPoint.boundingBox(with: ps)
            let area = bounds.width * bounds.height
            if area < minArea {
                minArea = area
                minAngle = angle
                minBounds = bounds
            }
        }
        centerPoint = CGPoint(x: minBounds.midX,
                              y: minBounds.midY).applying(CGAffineTransform(rotationAngle: minAngle))
        size = minBounds.size
        angle = minAngle
    }
    var bounds: CGRect {
        return CGRect(x: 0, y: 0, width: size.width, height: size.height)
    }
    var affineTransform: CGAffineTransform {
        return CGAffineTransform(translationX: centerPoint.x, y: centerPoint.y)
            .rotated(by: angle)
            .translatedBy(x: -size.width / 2, y: -size.height / 2)
    }
    func convertToLocal(p: CGPoint) -> CGPoint {
        return p.applying(affineTransform.inverted())
    }
    var minXMidYPoint: CGPoint {
        return CGPoint(x: 0, y: size.height / 2).applying(affineTransform)
    }
    var maxXMidYPoint: CGPoint {
        return CGPoint(x: size.width, y: size.height / 2).applying(affineTransform)
    }
    var midXMinYPoint: CGPoint {
        return CGPoint(x: size.width / 2, y: 0).applying(affineTransform)
    }
    var midXMaxYPoint: CGPoint {
        return CGPoint(x: size.width / 2, y: size.height).applying(affineTransform)
    }
    var midXMidYPoint: CGPoint {
        return CGPoint(x: size.width / 2, y: size.height / 2).applying(affineTransform)
    }
}
extension RotateRect: Equatable {
    static func ==(lhs: RotateRect, rhs: RotateRect) -> Bool {
        return lhs.centerPoint == rhs.centerPoint
            && lhs.size == rhs.size && lhs.angle == lhs.angle
    }
}
extension CGPoint {
    static func convexHullPoints(with points: [CGPoint]) -> [CGPoint] {
        guard points.count > 3 else {
            return points
        }
        let minY = (points.min { $0.y < $1.y })!.y
        let firstP = points.filter { $0.y == minY }.min { $0.x < $1.x }!
        var ap = firstP, chps = [CGPoint]()
        repeat {
            chps.append(ap)
            var bp = points[0]
            for i in 1 ..< points.count {
                let cp = points[i]
                if bp == ap {
                    bp = cp
                } else {
                    let v = (bp - ap).crossVector(cp - ap)
                    if v > 0 || (v == 0 && ap.distance²(cp) > ap.distance²(bp)) {
                        bp = cp
                    }
                }
            }
            ap = bp
        } while ap != firstP
        return chps
    }
    static func rotatedBoundingBox(withConvexHullPoints chps: [CGPoint]
        ) -> (centerPoint: CGPoint, size: CGSize, angle: CGFloat) {
        
        guard !chps.isEmpty else {
            fatalError()
        }
        guard chps.count > 1 else {
            return (chps[0], CGSize(), 0.0)
        }
        var minArea = CGFloat.infinity, minAngle = 0.0.cf, minBounds = CGRect()
        for (i, p) in chps.enumerated() {
            let nextP = chps[i == chps.count - 1 ? 0 : i + 1]
            let angle = p.tangential(nextP)
            let affine = CGAffineTransform(rotationAngle: -angle)
            let ps = chps.map { $0.applying(affine) }
            let bounds = boundingBox(with: ps)
            let area = bounds.width * bounds.height
            if area < minArea {
                minArea = area
                minAngle = angle
                minBounds = bounds
            }
        }
        let centerPoint = CGPoint(x: minBounds.midX, y: minBounds.midY)
            .applying(CGAffineTransform(rotationAngle: minAngle))
        return (centerPoint, minBounds.size, minAngle)
    }
    static func boundingBox(with points: [CGPoint]) -> CGRect {
        guard points.count > 1 else {
            return CGRect()
        }
        let minX = points.min { $0.x < $1.x }!.x, maxX = points.max { $0.x < $1.x }!.x
        let minY = points.min { $0.y < $1.y }!.y, maxY = points.max { $0.y < $1.y }!.y
        return AABB(minX: minX, maxX: maxX, minY: minY, maxY: maxY).rect
    }
}

extension CGAffineTransform {
    static func centering(from fromFrame: CGRect,
                          to toFrame: CGRect) -> (scale: CGFloat, affine: CGAffineTransform) {
        
        guard !fromFrame.isEmpty && !toFrame.isEmpty else {
            return (1, CGAffineTransform.identity)
        }
        var affine = CGAffineTransform.identity
        let fromRatio = fromFrame.width / fromFrame.height
        let toRatio = toFrame.width / toFrame.height
        if fromRatio > toRatio {
            let xScale = toFrame.width / fromFrame.size.width
            let y = toFrame.origin.y + (toFrame.height - fromFrame.height * xScale) / 2
            affine = affine.translatedBy(x: toFrame.origin.x, y: y)
            affine = affine.scaledBy(x: xScale, y: xScale)
            return (xScale, affine.translatedBy(x: -fromFrame.origin.x, y: -fromFrame.origin.y))
        } else {
            let yScale = toFrame.height / fromFrame.size.height
            let x = toFrame.origin.x + (toFrame.width - fromFrame.width * yScale) / 2
            affine = affine.translatedBy(x: x, y: toFrame.origin.y)
            affine = affine.scaledBy(x: yScale, y: yScale)
            return (yScale, affine.translatedBy(x: -fromFrame.origin.x, y: -fromFrame.origin.y))
        }
    }
    func flippedHorizontal(by width: CGFloat) -> CGAffineTransform {
        return translatedBy(x: width, y: 0).scaledBy(x: -1, y: 1)
    }
}

extension Int {
    var cf: CGFloat {
        return CGFloat(self)
    }
    var d: Double {
        return Double(self)
    }
}
extension Float {
    var cf: CGFloat {
        return CGFloat(self)
    }
    var d: Double {
        return Double(self)
    }
}
extension Double {
    var cf: CGFloat {
        return CGFloat(self)
    }
}
extension CGFloat {
    var d: Double {
        return Double(self)
    }
}
