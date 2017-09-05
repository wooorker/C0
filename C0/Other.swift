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

import Cocoa

struct BezierIntersection {
    var t: CGFloat, isLeft: Bool, point: CGPoint
}
struct Bezier2 {
    var p0 = CGPoint(), p1 = CGPoint(), p2 = CGPoint()
    
    static func linear(_ p0: CGPoint, _ p1: CGPoint) -> Bezier2 {
        return Bezier2(p0: p0, p1: p0.mid(p1), p2: p1)
    }
    
    var bounds: CGRect {
        var minX = min(p0.x, p2.x), maxX = max(p0.x, p2.x)
        var d = p2.x - 2*p1.x + p0.x
        if d != 0 {
            let t = (p0.x - p1.x)/d
            if t >= 0 && t <= 1 {
                let rt = 1 - t
                let tx = rt*rt*p0.x + 2*rt*t*p1.x + t*t*p2.x
                if tx < minX {
                    minX = tx
                } else if tx > maxX {
                    maxX = tx
                }
            }
        }
        var minY = min(p0.y, p2.y), maxY = max(p0.y, p2.y)
        d = p2.y - 2*p1.y + p0.y
        if d != 0 {
            let t = (p0.y - p1.y)/d
            if t >= 0 && t <= 1 {
                let rt = 1 - t
                let ty = rt*rt*p0.y + 2*rt*t*p1.y + t*t*p2.y
                if ty < minY {
                    minY = ty
                } else if ty > maxY {
                    maxY = ty
                }
            }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    var boundingBox: CGRect {
        return AABB(self).rect
    }
    
    func length(withFlatness flatness: Int = 128) -> CGFloat {
        var d = 0.0.cf, oldP = p0
        let nd = 1/flatness.cf
        for i in 0 ..< flatness {
            let newP = position(withT: (i + 1).cf*nd)
            d += oldP.distance(newP)
            oldP = newP
        }
        return d
    }
    func t(withLength length: CGFloat, flatness: Int = 128) -> CGFloat {
        var d = 0.0.cf, oldP = p0
        let nd = 1/flatness.cf
        for i in 0 ..< flatness {
            let t = (i + 1).cf*nd
            let newP = position(withT: t)
            d += oldP.distance(newP)
            if d > length {
                return t
            }
            oldP = newP
        }
        return 1
    }
    func difference(withT t: CGFloat) -> CGPoint {
        return CGPoint(x: 2*(p1.x - p0.x) + 2*(p0.x - 2*p1.x + p2.x)*t, y: 2*(p1.y - p0.y) + 2*(p0.y - 2*p1.y + p2.y)*t)
    }
    func tangential(withT t: CGFloat) -> CGFloat {
        return atan2(2*(p1.y - p0.y) + 2*(p0.y - 2*p1.y + p2.y)*t, 2*(p1.x - p0.x) + 2*(p0.x - 2*p1.x + p2.x)*t)
    }
    func position(withT t: CGFloat) -> CGPoint {
        let rt = 1 - t
        return CGPoint(x: rt*rt*p0.x + 2*t*rt*p1.x + t*t*p2.x, y: rt*rt*p0.y + 2*t*rt*p1.y + t*t*p2.y)
    }
    func midSplit() -> (b0: Bezier2, b1: Bezier2) {
        let p0p1 = p0.mid(p1), p1p2 = p1.mid(p2)
        let p = p0p1.mid(p1p2)
        return (Bezier2(p0: p0, p1: p0p1, p2: p), Bezier2(p0: p, p1: p1p2, p2: p2))
    }
    func clip(startT t0: CGFloat, endT t1: CGFloat) -> Bezier2 {
        let rt0 = 1 - t0, rt1 = 1 - t1
        let t0p0p1 = CGPoint(x: rt0*p0.x + t0*p1.x, y: rt0*p0.y + t0*p1.y)
        let t0p1p2 = CGPoint(x: rt0*p1.x + t0*p2.x, y: rt0*p1.y + t0*p2.y)
        let np0 = CGPoint(x: rt0*t0p0p1.x + t0*t0p1p2.x, y: rt0*t0p0p1.y + t0*t0p1p2.y)
        let np1 = CGPoint(x: rt1*t0p0p1.x + t1*t0p1p2.x, y: rt1*t0p0p1.y + t1*t0p1p2.y)
        let t1p0p1 = CGPoint(x: rt1*p0.x + t1*p1.x, y: rt1*p0.y + t1*p1.y)
        let t1p1p2 = CGPoint(x: rt1*p1.x + t1*p2.x, y: rt1*p1.y + t1*p2.y)
        let np2 = CGPoint(x: rt1*t1p0p1.x + t1*t1p1p2.x, y: rt1*t1p0p1.y + t1*t1p1p2.y)
        return Bezier2(p0: np0, p1: np1, p2: np2)
    }
    func intersects(_ other: Bezier2) -> Bool {
        return intersects(other, 0, 1, 0, 1, isFlipped: false)
    }
    private let intersectsMinRange = 0.000001.cf
    private func intersects(_ other: Bezier2, _ min0: CGFloat, _ max0: CGFloat, _ min1: CGFloat, _ max1: CGFloat, isFlipped: Bool) -> Bool {
        let aabb0 = AABB(self), aabb1 = AABB(other)
        if !aabb0.intersects(aabb1) {
            return false
        }
        if max(aabb1.maxX - aabb1.minX, aabb1.maxY - aabb1.minY) < intersectsMinRange {
            return true
        }
        let range1 = max1 - min1
        let nb = other.midSplit()
        if nb.b0.intersects(self, min1, min1 + 0.5*range1, min0, max0, isFlipped: !isFlipped) {
            return true
        } else {
            return nb.b1.intersects(self, min1 + 0.5*range1, min1 + range1, min0, max0, isFlipped: !isFlipped)
        }
    }
    func intersections(_ other: Bezier2) -> [BezierIntersection] {
        var results = [BezierIntersection]()
        intersections(other, &results, 0, 1, 0, 1, isFlipped: false)
        return results
    }
    private func intersections(_ other: Bezier2, _ results: inout [BezierIntersection],
                               _ min0: CGFloat, _ max0: CGFloat, _ min1: CGFloat, _ max1: CGFloat, isFlipped: Bool) {
        let aabb0 = AABB(self), aabb1 = AABB(other)
        if !aabb0.intersects(aabb1) {
            return
        }
        let range1 = max1 - min1
        if max(aabb1.maxX - aabb1.minX, aabb1.maxY - aabb1.minY) >= intersectsMinRange {
            let nb = other.midSplit()
            nb.b0.intersections(self, &results, min1, min1 + range1/2, min0, max0, isFlipped: !isFlipped)
            if results.count < 4 {
                nb.b1.intersections(self, &results, min1 + range1/2, min1 + range1, min0, max0, isFlipped: !isFlipped)
            }
            return
        }
        let newP = CGPoint(x: (aabb1.minX + aabb1.maxX)/2, y: (aabb1.minY + aabb1.maxY)/2)
        func isSolution() -> Bool {
            if !results.isEmpty {
                let oldP = results[results.count - 1].point
                let x = newP.x - oldP.x, y = newP.y - oldP.y
                if x*x + y*y < intersectsMinRange {
                    return false
                }
            }
            return true
        }
        if !isSolution() {
            return
        }
        let b0t: CGFloat, b1t: CGFloat, b0: Bezier2, b1:Bezier2
        if !isFlipped {
            b0t = (min0 + max0)/2
            b1t = min1 + range1/2
            b0 = self
            b1 = other
        } else {
            b1t = (min0 + max0)/2
            b0t = min1 + range1/2
            b0 = other
            b1 = self
        }
        let b0dp = b0.difference(withT: b0t), b1dp = b1.difference(withT: b1t)
        let b0b1Cross = b0dp.x*b1dp.y - b0dp.y*b1dp.x
        if b0b1Cross != 0 {
            results.append(BezierIntersection(t: b0t, isLeft: b0b1Cross > 0, point: newP))
        }
    }
}

struct Bezier3 {
    var p0 = CGPoint(), cp0 = CGPoint(), cp1 = CGPoint(), p1 = CGPoint()
    func split(withT t: CGFloat) -> (b0: Bezier3, b1: Bezier3) {
        let b0cp0 = CGPoint.linear(p0, cp0, t: t), cp0cp1 = CGPoint.linear(cp0, cp1, t: t), b1cp1 = CGPoint.linear(cp1, p1, t: t)
        let b0cp1 = CGPoint.linear(b0cp0, cp0cp1, t: t), b1cp0 = CGPoint.linear(cp0cp1, b1cp1, t: t)
        let p = CGPoint.linear(b0cp1, b1cp0, t: t)
        return (Bezier3(p0: p0, cp0: b0cp0, cp1: b0cp1, p1: p), Bezier3(p0: p, cp0: b1cp0, cp1: b1cp1, p1: p1))
    }
    func y(withX x: CGFloat) -> CGFloat {
        var y = 0.0.cf
        let sb = split(withT: 0.5)
        if !sb.b0.y(withX: x, y: &y) {
            _ = sb.b1.y(withX: x, y: &y)
        }
        return y
    }
    private let yMinRange = 0.000001.cf
    private func y(withX x: CGFloat, y: inout CGFloat) -> Bool {
        let aabb = AABB(self)
        if aabb.minX < x && aabb.maxX >= x {
            if aabb.maxY - aabb.minY < yMinRange {
                y = (aabb.minY + aabb.maxY)/2
                return true
            } else {
                let sb = split(withT: 0.5)
                if sb.b0.y(withX: x, y: &y) {
                    return true
                } else {
                    return sb.b1.y(withX: x, y: &y)
                }
            }
        } else {
            return false
        }
    }
    func difference(withT t: CGFloat) -> CGPoint {
        let rt = 1 - t
        let dx = 3*(t*t*(p1.x - cp1.x)+2*t*rt*(cp1.x - cp0.x) + rt*rt*(cp0.x - p0.x))
        let dy = 3*(t*t*(p1.y - cp1.y)+2*t*rt*(cp1.y - cp0.y) + rt*rt*(cp0.y - p0.y))
        return CGPoint(x: dx, y: dy)
    }
}

struct AABB {
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
        minX = min(b.p0.x, b.p1.x, b.p2.x)
        minY = min(b.p0.y, b.p1.y, b.p2.y)
        maxX = max(b.p0.x, b.p1.x, b.p2.x)
        maxY = max(b.p0.y, b.p1.y, b.p2.y)
    }
    init(_ b: Bezier3) {
        minX = min(b.p0.x, b.cp0.x, b.cp1.x, b.p1.x)
        minY = min(b.p0.y, b.cp0.y, b.cp1.y, b.p1.y)
        maxX = max(b.p0.x, b.cp0.x, b.cp1.x, b.p1.x)
        maxY = max(b.p0.y, b.cp0.y, b.cp1.y, b.p1.y)
    }
    
    var position: CGPoint {
        return CGPoint(x: minX, y: minY)
    }
    var rect: CGRect {
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    func nearestSquaredDistance(_ p: CGPoint) -> CGFloat {
        if p.x < minX {
            return p.y < minY ? hypot2(minX - p.x, minY - p.y) : (p.y <= maxY ? (minX - p.x).squared() : hypot2(minX - p.x, maxY - p.y))
        } else if p.x <= maxX {
            return p.y < minY ? (minY - p.y).squared() : (p.y <= maxY ? 0 : (minY - p.y).squared())
        } else {
            return p.y < minY ? hypot2(maxX - p.x, minY - p.y) : (p.y <= maxY ? (maxX - p.x).squared() : hypot2(maxX - p.x, maxY - p.y))
        }
    }
    func intersects(_ other: AABB) -> Bool {
        return minX <= other.maxX && maxX >= other.minX && minY <= other.maxY && maxY >= other.minY
    }
}

final class LockTimer {
    private var count = 0
    private(set) var wait = false
    func begin(_ endTimeLength: TimeInterval, beginHandler: () -> Void, endHandler: @escaping () -> Void) {
        if wait {
            count += 1
        } else {
            beginHandler()
            wait = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + endTimeLength) {
            if self.count == 0 {
                endHandler()
                self.wait = false
            } else {
                self.count -= 1
            }
        }
    }
    private(set) var inUse = false
    private weak var timer: Timer?
    func begin(_ interval: TimeInterval, repeats: Bool = true, tolerance: TimeInterval = TimeInterval(0), handler: @escaping (Void) -> Void) {
        let time = interval + CFAbsoluteTimeGetCurrent()
        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, time, repeats ? interval : 0, 0, 0) { _ in
            handler()
        }
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, .commonModes)
        self.timer = timer
        inUse = true
        self.timer?.tolerance = tolerance
    }
    func stop() {
        inUse = false
        timer?.invalidate()
        timer = nil
    }
}
final class Weak<T: AnyObject> {
    weak var value : T?
    init (value: T) {
        self.value = value
    }
}

func hypot2(_ lhs: CGFloat, _ rhs: CGFloat) -> CGFloat {
    return lhs*lhs + rhs*rhs
}
protocol Copying: class {
    var deepCopy: Self { get }
}
protocol Interpolatable {
    static func linear(_ f0: Self, _ f1: Self, t: CGFloat) -> Self
    static func firstMonospline(_ f1: Self, _ f2: Self, _ f3: Self, with msx: MonosplineX) -> Self
    static func monospline(_ f0: Self, _ f1: Self, _ f2: Self, _ f3: Self, with msx: MonosplineX) -> Self
    static func endMonospline(_ f0: Self, _ f1: Self, _ f2: Self, with msx: MonosplineX) -> Self
}
extension Comparable {
    func clip(min: Self, max: Self) -> Self {
        return self < min ? min : (self > max ? max : self)
    }
    func isOver(old: Self, new: Self) -> Bool {
        return (new >= self && old < self) || (new <= self && old > self)
    }
}
extension Array {
    func withRemovedLast() -> Array {
        var array = self
        array.removeLast()
        return array
    }
    func withRemoved(at i: Int) -> Array {
        var array = self
        array.remove(at: i)
        return array
    }
    func withAppend(_ element: Element) -> Array {
        var array = self
        array.append(element)
        return array
    }
    func withInserted(_ element: Element, at i: Int) -> Array {
        var array = self
        array.insert(element, at: i)
        return array
    }
    func withReplaced(_ element: Element, at i: Int) -> Array {
        var array = self
        array[i] = element
        return array
    }
}
extension String {
    var localized: String {
        return NSLocalizedString(self, comment: self)
    }
}
extension Int {
    var cf: CGFloat {
        return CGFloat(self)
    }
}
extension Float {
    var cf: CGFloat {
        return CGFloat(self)
    }
    static func linear(_ f0: Float, _ f1: Float, t: CGFloat) -> Float {
        let tf = t.f
        return f0*(1 - tf) + f1*tf
    }
}
extension Double {
    var f: Float {
        return Float(self)
    }
    var cf: CGFloat {
        return CGFloat(self)
    }
}

struct MonosplineX {
    let h0: CGFloat, h1: CGFloat, h2: CGFloat, invertH0: CGFloat, invertH1: CGFloat, invertH2: CGFloat
    let invertH0H1: CGFloat, invertH1H2: CGFloat, invertH1H1: CGFloat, xx3: CGFloat, xx2: CGFloat, xx1: CGFloat
    init(x1: CGFloat, x2: CGFloat, x3: CGFloat, x: CGFloat) {
        h0 = 0
        h1 = x2 - x1
        h2 = x3 - x2
        invertH0 = 0
        invertH1 = 1/h1
        invertH2 = 1/h2
        invertH0H1 = 0
        invertH1H2 = 1/(h1 + h2)
        invertH1H1 = 1/(h1*h1)
        xx1 = x - x1
        xx2 = xx1*xx1
        xx3 = xx1*xx1*xx1
    }
    init(x0: CGFloat, x1: CGFloat, x2: CGFloat, x3: CGFloat, x: CGFloat) {
        h0 = x1 - x0
        h1 = x2 - x1
        h2 = x3 - x2
        invertH0 = 1/h0
        invertH1 = 1/h1
        invertH2 = 1/h2
        invertH0H1 = 1/(h0 + h1)
        invertH1H2 = 1/(h1 + h2)
        invertH1H1 = 1/(h1*h1)
        xx1 = x - x1
        xx2 = xx1*xx1
        xx3 = xx1*xx1*xx1
    }
    init(x0: CGFloat, x1: CGFloat, x2: CGFloat, x: CGFloat) {
        h0 = x1 - x0
        h1 = x2 - x1
        h2 = 0
        invertH0 = 1/h0
        invertH1 = 1/h1
        invertH2 = 0
        invertH0H1 = 1/(h0 + h1)
        invertH1H2 = 0
        invertH1H1 = 1/(h1*h1)
        xx1 = x - x1
        xx2 = xx1*xx1
        xx3 = xx1*xx1*xx1
    }
}

extension CGFloat: Interpolatable {
    var f: Float {
        return Float(self)
    }
    var d: Double {
        return Double(self)
    }
    
    func interval(scale: CGFloat) -> CGFloat {
        if scale == 0 {
            return self
        } else {
            let t = floor(self / scale)*scale
            return self - t > scale/2 ? t + scale : t
        }
    }
    static func sectionIndex(value v: CGFloat, in values: [CGFloat]) -> (index: Int, interValue: CGFloat, sectionValue: CGFloat)? {
        if let firstValue = values.first {
            var oldV = 0.0.cf
            for i in (0 ..< values.count).reversed() {
                let value = values[i]
                if v >= value {
                    return (i, v - value, oldV - value)
                }
                oldV = value
            }
            return (0, v -  firstValue, oldV - firstValue)
        } else {
            return nil
        }
    }
    
    func differenceRotation(_ other: CGFloat) -> CGFloat {
        let a = self - other
        return a + (a > .pi ? -2*(.pi) : (a < -.pi ? 2*(.pi) : 0))
    }
    static func differenceAngle(_ p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGFloat {
        let pa = p1 - p0
        let pb = p2 - pa
        let ab = hypot(pa.x, pa.y)*hypot(pb.x, pb.y)
        return ab != 0 ? (pa.x*pb.y - pa.y*pb.x > 0 ? 1 : -1)*acos((pa.x*pb.x + pa.y*pb.y)/ab) : 0
    }
    var clipRotation: CGFloat {
        return self < -.pi ? self + 2*(.pi) : (self > .pi ? self - 2*(.pi) : self)
    }
    
    func squared() -> CGFloat {
        return self*self
    }
    func loopValue(other: CGFloat, begin: CGFloat = 0, end: CGFloat = 1) -> CGFloat {
        if other < self {
            return self - other < (other - begin) + (end - self) ? self : self - (end - begin)
        } else {
            return other - self < (self - begin) + (end - other) ? self : self + (end - begin)
        }
    }
    func loopValue(_ begin: CGFloat = 0, end: CGFloat = 1) -> CGFloat {
        return self < begin ? self + (end - begin) : (self > end ? self - (end - begin) : self)
    }
    
    static func random(min: CGFloat, max: CGFloat) -> CGFloat {
        return (max - min)*(CGFloat(arc4random_uniform(UInt32.max))/CGFloat(UInt32.max)) + min
    }
    static func bilinear(x: CGFloat, y: CGFloat, a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat) -> CGFloat {
        return x*y*(a - b - c + d) + x*(b - a) + y*(c - a) + a
    }
    
    static func linear(_ f0: CGFloat, _ f1: CGFloat, t: CGFloat) -> CGFloat {
        return f0*(1 - t) + f1*t
    }
    static func firstMonospline(_ f1: CGFloat, _ f2: CGFloat, _ f3: CGFloat, with msx: MonosplineX) -> CGFloat {
        let s1 = (f2 - f1)*msx.invertH1, s2 = (f3 - f2)*msx.invertH2
        let signS1: CGFloat = s1 > 0 ? 1 : -1, signS2: CGFloat = s2 > 0 ? 1 : -1
        let yPrime1 = s1
        let yPrime2 = (signS1 + signS2)*Swift.min(abs(s1), abs(s2), 0.5*abs((msx.h2*s1 + msx.h1*s2)*msx.invertH1H2))
        return _monospline(f1, s1, yPrime1, yPrime2, with: msx)
    }
    static func monospline(_ f0: CGFloat, _ f1: CGFloat, _ f2: CGFloat, _ f3: CGFloat, with msx: MonosplineX) -> CGFloat {
        let s0 = (f1 - f0)*msx.invertH0, s1 = (f2 - f1)*msx.invertH1, s2 = (f3 - f2)*msx.invertH2
        let signS0: CGFloat = s0 > 0 ? 1 : -1, signS1: CGFloat = s1 > 0 ? 1 : -1, signS2: CGFloat = s2 > 0 ? 1 : -1
        let yPrime1 = (signS0 + signS1)*Swift.min(abs(s0), abs(s1), 0.5*abs((msx.h1*s0 + msx.h0*s1)*msx.invertH0H1))
        let yPrime2 = (signS1 + signS2)*Swift.min(abs(s1), abs(s2), 0.5*abs((msx.h2*s1 + msx.h1*s2)*msx.invertH1H2))
        return _monospline(f1, s1, yPrime1, yPrime2, with: msx)
    }
    static func endMonospline(_ f0: CGFloat, _ f1: CGFloat, _ f2: CGFloat, with msx: MonosplineX) -> CGFloat {
        let s0 = (f1 - f0)*msx.invertH0, s1 = (f2 - f1)*msx.invertH1
        let signS0: CGFloat = s0 > 0 ? 1 : -1, signS1: CGFloat = s1 > 0 ? 1 : -1
        let yPrime1 = (signS0 + signS1)*Swift.min(abs(s0), abs(s1), 0.5*abs((msx.h1*s0 + msx.h0*s1)*msx.invertH0H1))
        let yPrime2 = s1
        return _monospline(f1, s1, yPrime1, yPrime2, with: msx)
    }
    private static func _monospline(_ f1: CGFloat, _ s1: CGFloat, _ yPrime1: CGFloat, _ yPrime2: CGFloat, with msx: MonosplineX) -> CGFloat {
        let a = (yPrime1 + yPrime2 - 2*s1)*msx.invertH1H1, b = (3*s1 - 2*yPrime1 - yPrime2)*msx.invertH1, c = yPrime1, d = f1
        return a*msx.xx3 + b*msx.xx2 + c*msx.xx1 + d
    }
}
extension CGPoint: Interpolatable {
    func mid(_ other: CGPoint) -> CGPoint {
        return CGPoint(x: (x + other.x)/2, y: (y + other.y)/2)
    }
    static func linear(_ f0: CGPoint, _ f1: CGPoint, t: CGFloat) -> CGPoint {
        return CGPoint(x: CGFloat.linear(f0.x, f1.x, t: t), y: CGFloat.linear(f0.y, f1.y, t: t))
    }
    static func firstMonospline(_ f1: CGPoint, _ f2: CGPoint, _ f3: CGPoint, with msx: MonosplineX) -> CGPoint {
        return CGPoint(
            x: CGFloat.firstMonospline(f1.x, f2.x, f3.x, with: msx),
            y: CGFloat.firstMonospline(f1.y, f2.y, f3.y, with: msx)
        )
    }
    static func monospline(_ f0: CGPoint, _ f1: CGPoint, _ f2: CGPoint, _ f3: CGPoint, with msx: MonosplineX) -> CGPoint {
        return CGPoint(
            x: CGFloat.monospline(f0.x, f1.x, f2.x, f3.x, with: msx),
            y: CGFloat.monospline(f0.y, f1.y, f2.y, f3.y, with: msx)
        )
    }
    static func endMonospline(_ f0: CGPoint, _ f1: CGPoint, _ f2: CGPoint, with msx: MonosplineX) -> CGPoint {
        return CGPoint(
            x: CGFloat.endMonospline(f0.x, f1.x, f2.x, with: msx),
            y: CGFloat.endMonospline(f0.y, f1.y, f2.y, with: msx)
        )
    }
    
    static func intersection(p0: CGPoint, p1: CGPoint, q0: CGPoint, q1: CGPoint) -> Bool {
        let a0 = (p0.x - p1.x)*(q0.y - p0.y) + (p0.y - p1.y)*(p0.x - q0.x), b0 = (p0.x - p1.x)*(q1.y - p0.y) + (p0.y - p1.y)*(p0.x - q1.x)
        if a0*b0 < 0 {
            let a1 = (q0.x - q1.x)*(p0.y - q0.y) + (q0.y - q1.y)*(q0.x - p0.x), b1 = (q0.x - q1.x)*(p1.y - q0.y) + (q0.y - q1.y)*(q0.x - p1.x)
            if a1*b1 < 0 {
                return true
            }
        }
        return false
    }
    func tangential(_ other: CGPoint) -> CGFloat {
        return atan2(other.y - y, other.x - x)
    }
    func crossVector(_ other: CGPoint) -> CGFloat {
        return x*other.y - y*other.x
    }
    func distance(_ other: CGPoint) -> CGFloat {
        return hypot(other.x - x, other.y - y)
    }
    func distanceWithLine(ap: CGPoint, bp: CGPoint) -> CGFloat {
        return abs((bp - ap).crossVector(self - ap))/ap.distance(bp)
    }
    func distanceWithLineSegment(ap: CGPoint, bp: CGPoint) -> CGFloat {
        if ap == bp {
            return distance(ap)
        } else {
            let bav = bp - ap, pav = self - ap
            let r = (bav.x*pav.x + bav.y*pav.y)/(bav.x*bav.x + bav.y*bav.y)
            if r <= 0 {
                return distance(ap)
            } else if r > 1 {
                return distance(bp)
            } else {
                return abs(bav.crossVector(pav))/ap.distance(bp)
            }
        }
    }
    func squaredDistance(other: CGPoint) -> CGFloat {
        let nx = x - other.x, ny = y - other.y
        return nx*nx + ny*ny
    }
    static func differenceAngle(p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGFloat {
        return differenceAngle(a: p1 - p0, b: p2 - p1)
    }
    static func differenceAngle(a: CGPoint, b: CGPoint) -> CGFloat {
        return atan2(a.x*b.y - a.y*b.x, a.x*b.x + a.y*b.y)
    }
    static func + (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x + right.x, y: left.y + right.y)
    }
    static func - (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x - right.x, y: left.y - right.y)
    }
    static func * (left: CGPoint, right: CGFloat) -> CGPoint {
        return CGPoint(x: left.x*right, y: left.y*right)
    }
}
extension CGRect {
    func squaredDistance(_ point: CGPoint) -> CGFloat {
        return AABB(self).nearestSquaredDistance(point)
    }
    func unionNotEmpty(_ other: CGRect) -> CGRect {
        return other.isEmpty ? self : (isEmpty ? other : union(other))
    }
    var circleBounds: CGRect {
        let r = hypot(width, height)/2
        return CGRect(x: midX - r, y: midY - r, width: r*2, height: r*2)
    }
    func inset(by width: CGFloat) -> CGRect {
        return insetBy(dx: width, dy: width)
    }
}
extension CGAffineTransform {
    func flippedHorizontal(by width: CGFloat) -> CGAffineTransform {
        return translatedBy(x: width, y: 0).scaledBy(x: -1, y: 1)
    }
}
extension CGColor {
    final func multiplyAlpha(_ a: CGFloat) -> CGColor {
        return copy(alpha: a*alpha) ?? self
    }
    final func multiplyWhite(_ w: CGFloat) -> CGColor {
        if let components = components, let colorSpace = colorSpace {
            let cs = components.enumerated().map { $0.0 < components.count - 1 ? $0.1 + (1  - $0.1)*w : $0.1 }
            return CGColor(colorSpace: colorSpace, components: cs) ?? self
        } else {
            return self
        }
    }
}
extension CGPath {
    static func checkerboard(with size: CGSize, in frame: CGRect) -> CGPath {
        let path = CGMutablePath()
        let xCount = Int(frame.width/size.width) , yCount = Int(frame.height/(size.height*2))
        for xi in 0 ..< xCount {
            let x = frame.maxX - (xi + 1).cf*size.width
            let fy = xi % 2 == 0 ? size.height : 0
            for yi in 0 ..< yCount {
                let y = frame.minY + yi.cf*size.height*2 + fy
                path.addRect(CGRect(x: x, y: y, width: size.width, height: size.height))
            }
        }
        return path
    }
}
extension CGContext {
    func addBezier(_ b: Bezier3) {
        move(to: b.p0)
        addCurve(to: b.p1, control1: b.cp0, control2: b.cp1)
    }
    func flipHorizontal(by width: CGFloat) {
        translateBy(x: width, y: 0)
        scaleBy(x: -1, y: 1)
    }
    func drawBlurWith(color fillColor: CGColor, width: CGFloat, strength: CGFloat, isLuster: Bool, path: CGPath, with di: DrawInfo) {
        let nFillColor: CGColor
        if fillColor.alpha < 1 {
            saveGState()
            setAlpha(fillColor.alpha)
            nFillColor = fillColor.copy(alpha: 1) ?? fillColor
        } else {
            nFillColor = fillColor
        }
        let pathBounds = path.boundingBoxOfPath.insetBy(dx: -width, dy: -width)
        let lineColor = strength == 1 ? nFillColor : nFillColor.multiplyAlpha(strength)
        beginTransparencyLayer(in: boundingBoxOfClipPath.intersection(pathBounds), auxiliaryInfo: nil)
        if isLuster {
            setShadow(offset: CGSize(), blur: width*di.scale, color: lineColor)
        } else {
            let shadowY = hypot(pathBounds.size.width, pathBounds.size.height)
            translateBy(x: 0, y: shadowY)
            let shadowOffset = CGSize(width: shadowY*di.scale*sin(di.rotation), height: -shadowY*di.scale*cos(di.rotation))
            setShadow(offset: shadowOffset, blur: width*di.scale/2, color: lineColor)
            setLineWidth(width)
            setLineJoin(.round)
            setStrokeColor(lineColor)
            addPath(path)
            strokePath()
            translateBy(x: 0, y: -shadowY)
        }
        setFillColor(nFillColor)
        addPath(path)
        fillPath()
        endTransparencyLayer()
        if fillColor.alpha < 1 {
            restoreGState()
        }
    }
}

extension CTLine {
    var typographicBounds: CGRect {
        var ascent = 0.0.cf, descent = 0.0.cf, leading = 0.0.cf
        let width = CTLineGetTypographicBounds(self, &ascent, &descent, &leading).cf
        return CGRect(x: 0, y: descent + leading, width: width, height: ascent + descent)
    }
}

extension Bundle {
    var version: Int {
        return Int(infoDictionary?[String(kCFBundleVersionKey)] as? String ?? "0") ?? 0
    }
}

extension NSCoding {
    static func with(_ data: Data) -> Self? {
        return data.isEmpty ? nil : NSKeyedUnarchiver.unarchiveObject(with: data) as? Self
    }
    var data: Data {
        return NSKeyedArchiver.archivedData(withRootObject: self)
    }
}
extension NSCoder {
    func decodeStruct<T: ByteCoding>(forKey key: String) -> T? {
        return T(coder: self, forKey: key)
    }
    func encodeStruct(_ byteCoding: ByteCoding, forKey key: String) {
        byteCoding.encode(in: self, forKey: key)
    }
}
protocol ByteCoding {
    init?(coder: NSCoder, forKey key: String)
    func encode(in coder: NSCoder, forKey key: String)
    init(data: Data)
    var data: Data { get }
}
extension ByteCoding {
    init?(coder: NSCoder, forKey key: String) {
        var length = 0
        if let ptr = coder.decodeBytes(forKey: key, returnedLength: &length) {
            self = UnsafeRawPointer(ptr).assumingMemoryBound(to: Self.self).pointee
        } else {
            return nil
        }
    }
    func encode(in coder: NSCoder, forKey key: String) {
        var t = self
        withUnsafePointer(to: &t) {
            coder.encodeBytes(UnsafeRawPointer($0).bindMemory(to: UInt8.self, capacity: 1), length: MemoryLayout<Self>.size, forKey: key)
        }
    }
    init(data: Data) {
        self = data.withUnsafeBytes {
            UnsafeRawPointer($0).assumingMemoryBound(to: Self.self).pointee
        }
    }
    var data: Data {
        var t = self
        return Data(buffer: UnsafeBufferPointer(start: &t, count: 1))
    }
}
extension Array: ByteCoding {
    init?(coder: NSCoder, forKey key: String) {
        var length = 0
        if let ptr = coder.decodeBytes(forKey: key, returnedLength: &length) {
            let count = length/MemoryLayout<Element>.stride
            self = count == 0 ? [] : ptr.withMemoryRebound(to: Element.self, capacity: 1) {
                Array(UnsafeBufferPointer<Element>(start: $0, count: count))
            }
        } else {
            return nil
        }
    }
    func encode(in coder: NSCoder, forKey key: String) {
        withUnsafeBufferPointer { ptr in
            ptr.baseAddress?.withMemoryRebound(to: UInt8.self, capacity: 1) {
                coder.encodeBytes($0, length: ptr.count*MemoryLayout<Element>.stride, forKey: key)
            }
        }
    }
}

extension NSImage {
    convenience init(size: CGSize, handler: (CGContext) -> Void) {
        self.init(size: size)
        lockFocus()
        if let ctx = NSGraphicsContext.current()?.cgContext {
            handler(ctx)
        }
        unlockFocus()
    }
    final var bitmapSize: CGSize {
        if let tiffRepresentation = tiffRepresentation {
            if let bitmap = NSBitmapImageRep(data: tiffRepresentation) {
                return CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
            }
        }
        return CGSize()
    }
    final var PNGRepresentation: Data? {
        if let tiffRepresentation = tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffRepresentation) {
            return bitmap.representation(using: .PNG, properties: [NSImageInterlaced: false])
        } else {
            return nil
        }
    }
    static func exportAppIcon() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.begin { [unowned panel] result in
            if result == NSFileHandlingPanelOKButton, let url = panel.url {
                for s in [16.0.cf, 32.0.cf, 64.0.cf, 128.0.cf, 256.0.cf, 512.0.cf, 1024.0.cf] {
                    try? NSImage(size: CGSize(width: s, height: s), flipped: false) { rect -> Bool in
                        let ctx = NSGraphicsContext.current()!.cgContext, c = s*0.5, r = s*0.43, l = s*0.008, fs = s*0.45, fillColor = NSColor(white: 1, alpha: 1), fontColor = NSColor(white: 0.4, alpha: 1)
                        ctx.setFillColor(fillColor.cgColor)
                        ctx.setStrokeColor(fontColor.cgColor)
                        ctx.setLineWidth(l)
                        ctx.addEllipse(in: CGRect(x: c - r, y: c - r, width: r*2, height: r*2))
                        ctx.drawPath(using: .fillStroke)
                        var textLine = TextLine()
                        textLine.string = "C\u{2080}"
                        textLine.font = NSFont(name: "Avenir Next Regular", size: fs) ?? NSFont.systemFont(ofSize: fs)
                        textLine.color = fontColor.cgColor
                        textLine.isHorizontalCenter = true
                        textLine.isCenterWithImageBounds = true
                        textLine.draw(in: rect, in: ctx)
                        return true
                    }.PNGRepresentation?.write(to: url.appendingPathComponent("\(String(Int(s))).png"))
                }
            }
        }
    }
}

extension NSAttributedString {
    static func attributes(_ font: NSFont, color: CGColor) -> [String: Any] {
        return [String(kCTFontAttributeName): font, String(kCTForegroundColorAttributeName): color]
    }
}
