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

struct BezierIntersection: Codable {
    var t: CGFloat, isLeft: Bool, point: CGPoint
}
struct Bezier2: Equatable, Codable {
    var p0 = CGPoint(), cp = CGPoint(), p1 = CGPoint()
    
    static func ==(lhs: Bezier2, rhs: Bezier2) -> Bool {
        return lhs.p0 == rhs.p0 && lhs.cp == rhs.cp && lhs.p1 == rhs.p1
    }
    
    static func linear(_ p0: CGPoint, _ p1: CGPoint) -> Bezier2 {
        return Bezier2(p0: p0, cp: p0.mid(p1), p1: p1)
    }
    static func firstSpline(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint) -> Bezier2 {
        return Bezier2(p0: p0, cp: p1, p1: p1.mid(p2))
    }
    static func spline(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint) -> Bezier2 {
        return Bezier2(p0: p0.mid(p1), cp: p1, p1: p1.mid(p2))
    }
    static func endSpline(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint) -> Bezier2 {
        return Bezier2(p0: p0.mid(p1), cp: p1, p1: p2)
    }
    
    var isLineaer: Bool {
        return p0.mid(p1) == cp ||
            (p0.x - 2 * cp.x + p1.x == 0 && p0.y - 2 * cp.y + p1.y == 0)
    }
    
    var bounds: CGRect {
        var minX = min(p0.x, p1.x), maxX = max(p0.x, p1.x)
        var d = p1.x - 2 * cp.x + p0.x
        if d != 0 {
            let t = (p0.x - cp.x) / d
            if t >= 0 && t <= 1 {
                let rt = 1 - t
                let tx = rt * rt * p0.x + 2 * rt * t * cp.x + t * t * p1.x
                if tx < minX {
                    minX = tx
                } else if tx > maxX {
                    maxX = tx
                }
            }
        }
        var minY = min(p0.y, p1.y), maxY = max(p0.y, p1.y)
        d = p1.y - 2 * cp.y + p0.y
        if d != 0 {
            let t = (p0.y - cp.y) / d
            if t >= 0 && t <= 1 {
                let rt = 1 - t
                let ty = rt * rt * p0.y + 2 * rt * t * cp.y + t * t * p1.y
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
        let nd = 1 / flatness.cf
        for i in 0 ..< flatness {
            let newP = position(withT: (i + 1).cf * nd)
            d += oldP.distance(newP)
            oldP = newP
        }
        return d
    }
    func t(withLength length: CGFloat, flatness: Int = 128) -> CGFloat {
        var d = 0.0.cf, oldP = p0
        let nd = 1 / flatness.cf
        for i in 0 ..< flatness {
            let t = (i + 1).cf * nd
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
        return CGPoint(x: 2 * (cp.x - p0.x) + 2 * (p0.x - 2 * cp.x + p1.x) * t,
                       y: 2 * (cp.y - p0.y) + 2 * (p0.y - 2 * cp.y + p1.y) * t)
    }
    func tangential(withT t: CGFloat) -> CGFloat {
        return atan2(2 * (cp.y - p0.y) + 2 * (p0.y - 2 * cp.y + p1.y) * t,
                     2 * (cp.x - p0.x) + 2 * (p0.x - 2 * cp.x + p1.x) * t)
    }
    func position(withT t: CGFloat) -> CGPoint {
        let rt = 1 - t
        return CGPoint(x: rt * rt * p0.x + 2 * t * rt * cp.x + t * t * p1.x,
                       y: rt * rt * p0.y + 2 * t * rt * cp.y + t * t * p1.y)
    }
    func midSplit() -> (b0: Bezier2, b1: Bezier2) {
        let p0cp = p0.mid(cp), cpp1 = cp.mid(p1)
        let p = p0cp.mid(cpp1)
        return (Bezier2(p0: p0, cp: p0cp, p1: p), Bezier2(p0: p, cp: cpp1, p1: p1))
    }
    func clip(startT t0: CGFloat, endT t1: CGFloat) -> Bezier2 {
        let rt0 = 1 - t0, rt1 = 1 - t1
        let t0p0cp = CGPoint(x: rt0 * p0.x + t0 * cp.x, y: rt0 * p0.y + t0 * cp.y)
        let t0cpp1 = CGPoint(x: rt0 * cp.x + t0 * p1.x, y: rt0 * cp.y + t0 * p1.y)
        let np0 = CGPoint(x: rt0 * t0p0cp.x + t0 * t0cpp1.x, y: rt0 * t0p0cp.y + t0 * t0cpp1.y)
        let ncp = CGPoint(x: rt1 * t0p0cp.x + t1 * t0cpp1.x, y: rt1 * t0p0cp.y + t1 * t0cpp1.y)
        let t1p0cp = CGPoint(x: rt1 * p0.x + t1 * cp.x, y: rt1 * p0.y + t1 * cp.y)
        let t1cpp1 = CGPoint(x: rt1 * cp.x + t1 * p1.x, y: rt1 * cp.y + t1 * p1.y)
        let np1 = CGPoint(x: rt1 * t1p0cp.x + t1 * t1cpp1.x, y: rt1 * t1p0cp.y + t1 * t1cpp1.y)
        return Bezier2(p0: np0, cp: ncp, p1: np1)
    }
    func intersects(_ bounds: CGRect) -> Bool {
        if boundingBox.intersects(bounds) {
            if bounds.contains(p0) {
                return true
            }
            let x0y0 = bounds.origin, x1y0 = CGPoint(x: bounds.maxX, y: bounds.minY)
            let x0y1 = CGPoint(x: bounds.minX, y: bounds.maxY)
            let x1y1 = CGPoint(x: bounds.maxX, y: bounds.maxY)
            if intersects(Bezier2.linear(x0y0, x1y0)) ||
                intersects(Bezier2.linear(x1y0, x1y1)) ||
                intersects(Bezier2.linear(x1y1, x0y1)) ||
                intersects(Bezier2.linear(x0y1, x0y0)) {
                return true
            }
        }
        return false
    }
    func intersects(_ other: Bezier2) -> Bool {
        guard self != other else {
            return false
        }
        return intersects(other, 0, 1, 0, 1, isFlipped: false)
    }
    private static let intersectsMinRange = 0.000001.cf
    private func intersects(_ other: Bezier2, _ min0: CGFloat, _ max0: CGFloat,
                            _ min1: CGFloat, _ max1: CGFloat, isFlipped: Bool) -> Bool {
        
        let aabb0 = AABB(self), aabb1 = AABB(other)
        if !aabb0.intersects(aabb1) {
            return false
        }
        if max(aabb1.maxX - aabb1.minX, aabb1.maxY - aabb1.minY) < Bezier2.intersectsMinRange {
            return true
        }
        let range1 = max1 - min1
        let nb = other.midSplit()
        if nb.b0.intersects(self, min1, min1 + 0.5 * range1,
                            min0, max0, isFlipped: !isFlipped) {
            return true
        } else {
            return nb.b1.intersects(self, min1 + 0.5 * range1, min1 + range1,
                                    min0, max0, isFlipped: !isFlipped)
        }
    }
    func intersections(_ other: Bezier2) -> [BezierIntersection] {
        guard self != other else {
            return []
        }
        var results = [BezierIntersection]()
        intersections(other, &results, 0, 1, 0, 1, isFlipped: false)
        return results
    }
    private func intersections(
        _ other: Bezier2, _ results: inout [BezierIntersection],
        _ min0: CGFloat, _ max0: CGFloat, _ min1: CGFloat, _ max1: CGFloat, isFlipped: Bool
        ) {
        let aabb0 = AABB(self), aabb1 = AABB(other)
        if !aabb0.intersects(aabb1) {
            return
        }
        let range1 = max1 - min1
        if max(aabb1.maxX - aabb1.minX, aabb1.maxY - aabb1.minY) >= Bezier2.intersectsMinRange {
            let nb = other.midSplit()
            nb.b0.intersections(self, &results, min1, min1 + range1 / 2,
                                min0, max0, isFlipped: !isFlipped)
            if results.count < 4 {
                nb.b1.intersections(self, &results, min1 + range1 / 2, min1 + range1,
                                    min0, max0, isFlipped: !isFlipped)
            }
            return
        }
        let newP = CGPoint(x: (aabb1.minX + aabb1.maxX) / 2, y: (aabb1.minY + aabb1.maxY) / 2)
        func isSolution() -> Bool {
            if !results.isEmpty {
                let oldP = results[results.count - 1].point
                let x = newP.x - oldP.x, y = newP.y - oldP.y
                if x * x + y * y < Bezier2.intersectsMinRange {
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
            b0t = (min0 + max0) / 2
            b1t = min1 + range1 / 2
            b0 = self
            b1 = other
        } else {
            b1t = (min0 + max0) / 2
            b0t = min1 + range1 / 2
            b0 = other
            b1 = self
        }
        let b0dp = b0.difference(withT: b0t), b1dp = b1.difference(withT: b1t)
        let b0b1Cross = b0dp.x * b1dp.y - b0dp.y * b1dp.x
        if b0b1Cross != 0 {
            results.append(BezierIntersection(t: b0t, isLeft: b0b1Cross > 0, point: newP))
        }
    }
    
    func intersections(q0: CGPoint, q1: CGPoint) -> [CGPoint] {
        guard q0 != q1 else {
            return []
        }
        if isLineaer {
            if let p = CGPoint.intersectionLineSegment(p0, p1, q0, q1, isSegmentP3P4: false) {
                return [p]
            } else {
                return []
            }
        }
        let a = q1.y - q0.y, b = q0.x - q1.x
        let c = -a * q1.x - q1.y * b
        let a2 = a * p0.x + a * p1.x + b * p0.y + b * p1.y - 2 * a * cp.x - 2 * b * cp.y
        let b2 = -2 * a * p0.x - 2 * b * p0.y + 2 * a * cp.x + 2 * b * cp.y
        let c2 = a * p0.x + b * p0.y + c
        let d = b2 * b2 - 4 * a2 * c2
        if d > 0 {
            let sqrtD = sqrt(d)
            let t0 = 0.5 * (sqrtD - b2) / a2, t1 = 0.5 * (-sqrtD - b2) / a2
            if t0 >= 0 && t0 <= 1 {
                return t1 >= 0 && t1 <= 1 ?
                    [position(withT: t0),position(withT: t1)] : [position(withT: t0)]
            } else if t1 >= 0 && t1 <= 1 {
                return [position(withT: t1)]
            }
        } else if d == 0 {
            let t = -0.5 * b2 / a2
            if t >= 0 && t <= 1 {
                return [position(withT: t)]
            }
        }
        return []
    }
    
    func nearest(at p: CGPoint) -> (t: CGFloat, distance²: CGFloat) {
        guard !isLineaer else {
            let d = p.distanceWithLineSegment(ap: p0, bp: p1)
            return (p.tWithLineSegment(ap: p0, bp: p1), d * d)
        }
        func solveCubic(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat) -> [CGFloat] {
            let p = b - a * a / 3, q = a * (2 * a * a - 9 * b) / 27 + c
            let p3 = p * p * p
            let d = q * q + 4 * p3 / 27
            let offset = -a / 3
            if d >= 0 {
                let z = sqrt(d)
                let u = cbrt((-q + z) / 2), v = cbrt((-q - z) / 2)
                return [offset + u + v]
            } else {
                let v = acos(-sqrt(-27 / p3) * q / 2) / 3
                let u = sqrt(-p / 3), m = cos(v), n = sin(v) * 1.732050808
                return [offset + u * (m + m), offset - u * (n + m), offset + u * (n - m)]
            }
        }
        func dot(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
            return a.x * b.x + a.y * b.y
        }
        let a = p0 - 2 * cp + p1, b = 2 * (cp - p0), c = p0
        let k0 = dot(c - p, b), k1 = dot(b, b) + 2 * dot(c - p, a)
        let k2 = 3 * dot(a, b), k3 = 2 * dot(a, a)
        let rK3 = 1 / k3
        let ts = solveCubic(k2 * rK3, k1 * rK3, k0 * rK3)
        let d0 = p0.distance²(p), d1 = p1.distance²(p)
        var minT = 0.0.cf, minD = d0
        if d1 < minD {
            minD = d1
            minT = 1
        }
        for t in ts {
            if t >= 0 && t <= 1 {
                let dv = c + (b + a * t) * t - p
                let d = dot(dv,dv)
                if d < minD {
                    minD = d
                    minT = t
                }
            }
        }
        return (minT, minD)
    }
    func minDistance²(at p: CGPoint) -> CGFloat {
        return nearest(at: p).distance²
    }
    private static let distanceMinRange = 0.0000001.cf
    func maxDistance²(at p: CGPoint) -> CGFloat {
        let d = max(p0.distance²(p), p1.distance²(p)), dcp = cp.distance²(p)
        if d >= dcp {
            return d
        } else if dcp - d < Bezier2.distanceMinRange {
            return (dcp + d) / 2
        } else {
            let b = midSplit()
            return max(b.b0.maxDistance²(at: p), b.b1.maxDistance²(at: p))
        }
    }
}

struct Bezier3: Codable {
    var p0 = CGPoint(), cp0 = CGPoint(), cp1 = CGPoint(), p1 = CGPoint()
    static func linear(_ p0: CGPoint, _ p1: CGPoint) -> Bezier3 {
        return Bezier3(p0: p0, cp0: p0, cp1: p1, p1: p1)
    }
    var bounds: CGRect {
        struct MinMax {
            var min: CGFloat, max: CGFloat
        }
        func minMaxWith(_ f0: CGFloat, _ f1: CGFloat, _ f2: CGFloat, _ f3: CGFloat) -> MinMax {
            var minMax = MinMax(min: min(f0, f3), max: max(f0, f3))
            let a = f3 - 3 * (f2 - f1) - f0, b = 3 * (f2 - 2 * f1 + f0), c = 3 * (f1 - f0)
            let delta = b * b - 3 * a * c
            if delta > 0 {
                func ts(with t: CGFloat) -> CGFloat {
                    let tp = 1 - t
                    return tp * tp * tp * f0 + 3 * tp * tp * t * f1
                        + 3 * tp * t * t * f2 + t * t * t * f3
                }
                let sd = sqrt(delta), ia = 1 / (3 * a)
                let minT = (-b + sd) * ia, maxT = (-b - sd) * ia
                if minT >= 0 && minT <= 1 {
                    minMax.min = min(minMax.min, ts(with: minT))
                }
                if maxT >= 0 && maxT <= 1 {
                    minMax.max = max(minMax.max, ts(with: maxT))
                }
            }
            return minMax
        }
        let minMaxX = minMaxWith(p0.x, cp0.x, cp1.x, p1.x)
        let minMaxY = minMaxWith(p0.y, cp0.y, cp1.y, p1.y)
        return CGRect(x: minMaxX.min, y: minMaxY.min,
                      width: minMaxX.max - minMaxX.min, height: minMaxY.max - minMaxY.min)
    }
    func length(flatness: Int = 128) -> CGFloat {
        var d = 0.0.cf, oldP = p0
        let nd = 1 / flatness.cf
        for i in 0 ..< flatness {
            let newP = position(withT: (i + 1).cf * nd)
            d += oldP.distance(newP)
            oldP = newP
        }
        return d
    }
    func tWith(length: CGFloat, flatness: Int = 128) -> CGFloat {
        var d = 0.0.cf, oldP = p0
        let nd = 1 / flatness.cf
        for i in 0 ..< flatness {
            let t = (i + 1).cf * nd
            let newP = position(withT: t)
            d += oldP.distance(newP)
            if d > length {
                return t
            }
            oldP = newP
        }
        return 1
    }
    var boundingBox: CGRect {
        return AABB(self).rect
    }
    func split(withT t: CGFloat) -> (b0: Bezier3, b1: Bezier3) {
        let b0cp0 = CGPoint.linear(p0, cp0, t: t)
        let cp0cp1 = CGPoint.linear(cp0, cp1, t: t)
        let b1cp1 = CGPoint.linear(cp1, p1, t: t)
        let b0cp1 = CGPoint.linear(b0cp0, cp0cp1, t: t)
        let b1cp0 = CGPoint.linear(cp0cp1, b1cp1, t: t)
        let p = CGPoint.linear(b0cp1, b1cp0, t: t)
        return (Bezier3(p0: p0, cp0: b0cp0, cp1: b0cp1, p1: p),
                Bezier3(p0: p, cp0: b1cp0, cp1: b1cp1, p1: p1))
    }
    func midSplit() -> (b0: Bezier3, b1: Bezier3) {
        let b0cp0 = p0.mid(cp0), cp0cp1 = cp0.mid(cp1), b1cp1 = cp1.mid(p1)
        let b0cp1 = b0cp0.mid(cp0cp1), b1cp0 = cp0cp1.mid(b1cp1)
        let p = b0cp1.mid(b1cp0)
        return (Bezier3(p0: p0, cp0: b0cp0, cp1: b0cp1, p1: p),
                Bezier3(p0: p, cp0: b1cp0, cp1: b1cp1, p1: p1))
    }
    func y(withX x: CGFloat) -> CGFloat {
        var y = 0.0.cf
        let sb = split(withT: 0.5)
        if !sb.b0.y(withX: x, y: &y) {
            _ = sb.b1.y(withX: x, y: &y)
        }
        return y
    }
    static private let yMinRange = 0.000001.cf
    private func y(withX x: CGFloat, y: inout CGFloat) -> Bool {
        let aabb = AABB(self)
        if aabb.minX < x && aabb.maxX >= x {
            if aabb.maxY - aabb.minY < Bezier3.yMinRange {
                y = (aabb.minY + aabb.maxY) / 2
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
    func position(withT t: CGFloat) -> CGPoint {
        let dt = 1 - t, t³ = t * t * t, t² = t * t, dt³ = dt * dt * dt, dt² = dt * dt
        let x = t³ * p1.x + 3 * t² * dt * cp1.x + 3 * t * dt² * cp0.x + dt³ * p0.x
        let y = t³ * p1.y + 3 * t² * dt * cp1.y + 3 * t * dt² * cp0.y + dt³ * p0.y
        return CGPoint(x: x, y: y)
    }
    func difference(withT t: CGFloat) -> CGPoint {
        let tp = 1 - t
        let dx = 3 * (t * t * (p1.x - cp1.x) + 2 * t * tp * (cp1.x - cp0.x) + tp * tp * (cp0.x - p0.x))
        let dy = 3 * (t * t * (p1.y - cp1.y) + 2 * t * tp * (cp1.y - cp0.y) + tp * tp * (cp0.y - p0.y))
        return CGPoint(x: dx, y: dy)
    }
    func tangential(withT t: CGFloat) -> CGFloat {
        let dp = difference(withT: t)
        return atan2(dp.y, dp.x)
    }
    func intersects(_ bounds: CGRect) -> Bool {
        if boundingBox.intersects(bounds) {
            if bounds.contains(p0) {
                return true
            }
            let x0y0 = bounds.origin, x1y0 = CGPoint(x: bounds.maxX, y: bounds.minY)
            let x0y1 = CGPoint(x: bounds.minX, y: bounds.maxY)
            let x1y1 = CGPoint(x: bounds.maxX, y: bounds.maxY)
            if intersects(Bezier3.linear(x0y0, x1y0)) ||
                intersects(Bezier3.linear(x1y0, x1y1)) ||
                intersects(Bezier3.linear(x1y1, x0y1)) ||
                intersects(Bezier3.linear(x0y1, x0y0)) {
                return true
            }
        }
        return false
    }
    func intersects(_ other: Bezier3) -> Bool {
        return intersects(other, 0, 1, 0, 1, false)
    }
    private static let intersectsMinRange = 0.000001.cf
    private func intersects(_ other: Bezier3,
                            _ min0: CGFloat, _ max0: CGFloat,
                            _ min1: CGFloat, _ max1: CGFloat, _ isFlipped: Bool) -> Bool {
        
        let aabb0 = AABB(self), aabb1 = AABB(other)
        if aabb0.minX <= aabb1.maxX && aabb0.maxX >= aabb1.minX
            && aabb0.minY <= aabb1.maxY && aabb0.maxY >= aabb1.minY {
            
            let range1 = max1 - min1
            if max(aabb1.maxX - aabb1.minX, aabb1.maxY - aabb1.minY) < Bezier3.intersectsMinRange {
                return true
            } else {
                let nb = other.midSplit()
                if nb.b0.intersects(self, min1, min1 + 0.5 * range1,
                                    min0, max0, !isFlipped) {
                    return true
                } else {
                    return nb.b1.intersects(self, min1 + 0.5 * range1, min1 + range1,
                                            min0, max0, !isFlipped)
                }
            }
        } else {
            return false
        }
    }
    func intersections(_ other: Bezier3) -> [BezierIntersection] {
        var results = [BezierIntersection]()
        intersections(other, &results, 0, 1, 0, 1, false)
        return results
    }
    private func intersections(_ other: Bezier3, _ results: inout [BezierIntersection],
                               _ min0: CGFloat, _ max0: CGFloat,
                               _ min1: CGFloat, _ max1: CGFloat, _ flip: Bool) {
        
        let aabb0 = AABB(self), aabb1 = AABB(other)
        if aabb0.minX <= aabb1.maxX && aabb0.maxX >= aabb1.minX
            && aabb0.minY <= aabb1.maxY && aabb0.maxY >= aabb1.minY {
            
            let range1 = max1 - min1
            if max(aabb1.maxX - aabb1.minX, aabb1.maxY - aabb1.minY) < Bezier3.intersectsMinRange {
                let i = results.count, newP = CGPoint(x: (aabb1.minX + aabb1.maxX) / 2,
                                                      y: (aabb1.minY + aabb1.maxY) / 2)
                var isSolution = true
                if i > 0 {
                    let oldP = results[i - 1].point
                    let x = newP.x - oldP.x, y = newP.y - oldP.y
                    if x * x + y * y < Bezier3.intersectsMinRange {
                        isSolution = false
                    }
                }
                if isSolution {
                    let b0t: CGFloat, b1t: CGFloat, b0: Bezier3, b1:Bezier3
                    if !flip {
                        b0t = (min0 + max0) / 2
                        b1t = min1 + range1 / 2
                        b0 = self
                        b1 = other
                    } else {
                        b1t = (min0 + max0) / 2
                        b0t = min1 + range1 / 2
                        b0 = other
                        b1 = self
                    }
                    let b0dp = b0.difference(withT: b0t), b1dp = b1.difference(withT: b1t)
                    let b0b1Cross = b0dp.x * b1dp.y - b0dp.y * b1dp.x
                    if b0b1Cross != 0 {
                        results.append(BezierIntersection(t: b0t, isLeft: b0b1Cross > 0,
                                                          point: newP))
                    }
                }
            } else {
                let nb = other.midSplit()
                nb.b0.intersections(self, &results, min1,
                                    min1 + range1 / 2, min0, max0, !flip)
                if results.count < 4 {
                    nb.b1.intersections(self, &results, min1 + range1 / 2,
                                        min1 + range1, min0, max0, !flip)
                }
            }
        }
    }
}

