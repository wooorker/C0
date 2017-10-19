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

import Foundation

struct BezierIntersection {
    var t: CGFloat, isLeft: Bool, point: CGPoint
}
struct Bezier2 {
    var p0 = CGPoint(), cp = CGPoint(), p1 = CGPoint()
    
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
        return p0.mid(p1) == cp || (p0.x - 2*cp.x + p1.x == 0 && p0.y - 2*cp.y + p1.y == 0)
    }
    
    var bounds: CGRect {
        var minX = min(p0.x, p1.x), maxX = max(p0.x, p1.x)
        var d = p1.x - 2*cp.x + p0.x
        if d != 0 {
            let t = (p0.x - cp.x)/d
            if t >= 0 && t <= 1 {
                let rt = 1 - t
                let tx = rt*rt*p0.x + 2*rt*t*cp.x + t*t*p1.x
                if tx < minX {
                    minX = tx
                } else if tx > maxX {
                    maxX = tx
                }
            }
        }
        var minY = min(p0.y, p1.y), maxY = max(p0.y, p1.y)
        d = p1.y - 2*cp.y + p0.y
        if d != 0 {
            let t = (p0.y - cp.y)/d
            if t >= 0 && t <= 1 {
                let rt = 1 - t
                let ty = rt*rt*p0.y + 2*rt*t*cp.y + t*t*p1.y
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
        return CGPoint(x: 2*(cp.x - p0.x) + 2*(p0.x - 2*cp.x + p1.x)*t, y: 2*(cp.y - p0.y) + 2*(p0.y - 2*cp.y + p1.y)*t)
    }
    func tangential(withT t: CGFloat) -> CGFloat {
        return atan2(2*(cp.y - p0.y) + 2*(p0.y - 2*cp.y + p1.y)*t, 2*(cp.x - p0.x) + 2*(p0.x - 2*cp.x + p1.x)*t)
    }
    func position(withT t: CGFloat) -> CGPoint {
        let rt = 1 - t
        return CGPoint(x: rt*rt*p0.x + 2*t*rt*cp.x + t*t*p1.x, y: rt*rt*p0.y + 2*t*rt*cp.y + t*t*p1.y)
    }
    func midSplit() -> (b0: Bezier2, b1: Bezier2) {
        let p0cp = p0.mid(cp), cpp1 = cp.mid(p1)
        let p = p0cp.mid(cpp1)
        return (Bezier2(p0: p0, cp: p0cp, p1: p), Bezier2(p0: p, cp: cpp1, p1: p1))
    }
    func clip(startT t0: CGFloat, endT t1: CGFloat) -> Bezier2 {
        let rt0 = 1 - t0, rt1 = 1 - t1
        let t0p0cp = CGPoint(x: rt0*p0.x + t0*cp.x, y: rt0*p0.y + t0*cp.y)
        let t0cpp1 = CGPoint(x: rt0*cp.x + t0*p1.x, y: rt0*cp.y + t0*p1.y)
        let np0 = CGPoint(x: rt0*t0p0cp.x + t0*t0cpp1.x, y: rt0*t0p0cp.y + t0*t0cpp1.y)
        let ncp = CGPoint(x: rt1*t0p0cp.x + t1*t0cpp1.x, y: rt1*t0p0cp.y + t1*t0cpp1.y)
        let t1p0cp = CGPoint(x: rt1*p0.x + t1*cp.x, y: rt1*p0.y + t1*cp.y)
        let t1cpp1 = CGPoint(x: rt1*cp.x + t1*p1.x, y: rt1*cp.y + t1*p1.y)
        let np1 = CGPoint(x: rt1*t1p0cp.x + t1*t1cpp1.x, y: rt1*t1p0cp.y + t1*t1cpp1.y)
        return Bezier2(p0: np0, cp: ncp, p1: np1)
    }
    func intersects(_ bounds: CGRect) -> Bool {
        if boundingBox.intersects(bounds) {
            if bounds.contains(p0) {
                return true
            }
            let x0y0 = bounds.origin, x1y0 = CGPoint(x: bounds.maxX, y: bounds.minY)
            let x0y1 = CGPoint(x: bounds.minX, y: bounds.maxY), x1y1 = CGPoint(x: bounds.maxX, y: bounds.maxY)
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
        let c = -a*q1.x - q1.y*b
        let a2 = a*p0.x + a*p1.x + b*p0.y + b*p1.y - 2*a*cp.x - 2*b*cp.y
        let b2 = -2*a*p0.x - 2*b*p0.y + 2*a*cp.x + 2*b*cp.y
        let c2 = a*p0.x + b*p0.y + c
        let d = b2*b2 - 4*a2*c2
        if d > 0 {
            let sqrtD = sqrt(d)
            let t0 = 0.5*(sqrtD - b2)/a2, t1 = 0.5*(-sqrtD - b2)/a2
            if t0 >= 0 && t0 <= 1 {
                return t1 >= 0 && t1 <= 1 ? [position(withT: t0),position(withT: t1)] : [position(withT: t0)]
            } else if t1 >= 0 && t1 <= 1 {
                return [position(withT: t1)]
            }
        } else if d == 0 {
            let t = -0.5*b2/a2
            if t >= 0 && t <= 1 {
                return [position(withT: t)]
            }
        }
        return []
    }
    
    func nearest(at p: CGPoint) -> (t: CGFloat, distance²: CGFloat) {
        guard !isLineaer else {
            let d = p.distanceWithLineSegment(ap: p0, bp: p1)
            return (p.tWithLineSegment(ap: p0, bp: p1), d*d)
        }
        func solveCubic(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat) -> [CGFloat] {
            let p = b - a*a/3, q = a*(2*a*a - 9*b)/27 + c
            let p3 = p*p*p
            let d = q*q + 4*p3/27
            let offset = -a/3
            if d >= 0 {
                let z = sqrt(d)
                let u = cbrt((-q + z)/2), v = cbrt((-q - z)/2)
                return [offset + u + v]
            } else {
                let v = acos(-sqrt(-27/p3)*q/2)/3
                let u = sqrt(-p/3), m = cos(v), n = sin(v)*1.732050808
                return [offset + u*(m + m), offset - u*(n + m), offset + u*(n - m)]
            }
        }
        func dot(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
            return a.x*b.x + a.y*b.y
        }
        let a = p0 - 2*cp + p1, b = 2*(cp - p0), c = p0
        let k0 = dot(c - p, b), k1 = dot(b, b) + 2*dot(c - p, a), k2 = 3*dot(a, b), k3 = 2*dot(a, a)
        let rK3 = 1/k3
        let ts = solveCubic(k2*rK3, k1*rK3, k0*rK3)
        let d0 = p0.distance²(p), d1 = p1.distance²(p)
        var minT = 0.0.cf, minD = d0
        if d1 < minD {
            minD = d1
            minT = 1
        }
        for t in ts {
            if t >= 0 && t <= 1 {
                let dv = c + (b + a*t)*t - p
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
    private let distanceMinRange = 0.0000001.cf
    func maxDistance²(at p: CGPoint) -> CGFloat {
        let d = max(p0.distance²(p), p1.distance²(p)), dcp = cp.distance²(p)
        if d >= dcp {
            return d
        } else if dcp - d < distanceMinRange {
            return (dcp + d)/2
        } else {
            let b = midSplit()
            return max(b.b0.maxDistance²(at: p), b.b1.maxDistance²(at: p))
        }
    }
}

struct Bezier3 {
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
            let a = f3 - 3*(f2 - f1) - f0, b = 3*(f2 - 2*f1 + f0), c = 3*(f1 - f0)
            let delta = b*b - 3*a*c
            if delta > 0 {
                func ts(with t: CGFloat) -> CGFloat {
                    let tp = 1 - t
                    return tp*tp*tp*f0 + 3*tp*tp*t*f1 + 3*tp*t*t*f2 + t*t*t*f3
                }
                let sd = sqrt(delta), ia = 1/(3*a)
                let minT = (-b + sd)*ia, maxT = (-b - sd)*ia
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
        return CGRect(x: minMaxX.min, y: minMaxY.min, width: minMaxX.max - minMaxX.min, height: minMaxY.max - minMaxY.min)
    }
    func length(flatness: Int = 128) -> CGFloat {
        var d = 0.0.cf, oldP = p0
        let nd = 1/flatness.cf
        for i in 0 ..< flatness {
            let newP = position(withT: (i + 1).cf*nd)
            d += oldP.distance(newP)
            oldP = newP
        }
        return d
    }
    func tWith(length: CGFloat, flatness: Int = 128) -> CGFloat {
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
    var boundingBox: CGRect {
        return AABB(self).rect
    }
    func split(withT t: CGFloat) -> (b0: Bezier3, b1: Bezier3) {
        let b0cp0 = CGPoint.linear(p0, cp0, t: t), cp0cp1 = CGPoint.linear(cp0, cp1, t: t), b1cp1 = CGPoint.linear(cp1, p1, t: t)
        let b0cp1 = CGPoint.linear(b0cp0, cp0cp1, t: t), b1cp0 = CGPoint.linear(cp0cp1, b1cp1, t: t)
        let p = CGPoint.linear(b0cp1, b1cp0, t: t)
        return (Bezier3(p0: p0, cp0: b0cp0, cp1: b0cp1, p1: p), Bezier3(p0: p, cp0: b1cp0, cp1: b1cp1, p1: p1))
    }
    func midSplit() -> (b0: Bezier3, b1: Bezier3) {
        let b0cp0 = p0.mid(cp0), cp0cp1 = cp0.mid(cp1), b1cp1 = cp1.mid(p1)
        let b0cp1 = b0cp0.mid(cp0cp1), b1cp0 = cp0cp1.mid(b1cp1)
        let p = b0cp1.mid(b1cp0)
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
    func position(withT t: CGFloat) -> CGPoint {
        let dt = 1 - t
        let x = t*t*t*p1.x + 3*t*t*dt*cp1.x + 3*t*dt*dt*cp0.x + dt*dt*dt*p0.x
        let y = t*t*t*p1.y + 3*t*t*dt*cp1.y + 3*t*dt*dt*cp0.y + dt*dt*dt*p0.y
        return CGPoint(x: x, y: y)
    }
    func difference(withT t: CGFloat) -> CGPoint {
        let tp = 1 - t
        let dx = 3*(t*t*(p1.x - cp1.x) + 2*t*tp*(cp1.x - cp0.x) + tp*tp*(cp0.x - p0.x))
        let dy = 3*(t*t*(p1.y - cp1.y) + 2*t*tp*(cp1.y - cp0.y) + tp*tp*(cp0.y - p0.y))
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
            let x0y1 = CGPoint(x: bounds.minX, y: bounds.maxY), x1y1 = CGPoint(x: bounds.maxX, y: bounds.maxY)
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
    private let intersectsMinRange = 0.000001.cf
    private func intersects(_ other: Bezier3, _ min0: CGFloat, _ max0: CGFloat, _ min1: CGFloat, _ max1: CGFloat, _ isFlipped: Bool) -> Bool {
        let aabb0 = AABB(self), aabb1 = AABB(other)
        if aabb0.minX <= aabb1.maxX && aabb0.maxX >= aabb1.minX && aabb0.minY <= aabb1.maxY && aabb0.maxY >= aabb1.minY {
            let range1 = max1 - min1
            if max(aabb1.maxX - aabb1.minX, aabb1.maxY - aabb1.minY) < intersectsMinRange {
                return true
            } else {
                let nb = other.midSplit()
                if nb.b0.intersects(self, min1, min1 + 0.5*range1, min0, max0, !isFlipped) {
                    return true
                } else {
                    return nb.b1.intersects(self, min1 + 0.5*range1, min1 + range1, min0, max0, !isFlipped)
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
    private func intersections(_ other: Bezier3, _ results: inout [BezierIntersection], _ min0: CGFloat, _ max0: CGFloat, _ min1: CGFloat, _ max1: CGFloat, _ flip: Bool) {
        let aabb0 = AABB(self), aabb1 = AABB(other)
        if aabb0.minX <= aabb1.maxX && aabb0.maxX >= aabb1.minX && aabb0.minY <= aabb1.maxY && aabb0.maxY >= aabb1.minY {
            let range1 = max1 - min1
            if max(aabb1.maxX - aabb1.minX, aabb1.maxY - aabb1.minY) < intersectsMinRange {
                let i = results.count, newP = CGPoint(x: (aabb1.minX + aabb1.maxX)/2, y: (aabb1.minY + aabb1.maxY)/2)
                var isSolution = true
                if i > 0 {
                    let oldP = results[i - 1].point
                    let x = newP.x - oldP.x, y = newP.y - oldP.y
                    if x*x + y*y < intersectsMinRange {
                        isSolution = false
                    }
                }
                if isSolution {
                    let b0t: CGFloat, b1t: CGFloat, b0: Bezier3, b1:Bezier3
                    if !flip {
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
            } else {
                let nb = other.midSplit()
                nb.b0.intersections(self, &results, min1, min1 + range1/2, min0, max0, !flip)
                if results.count < 4 {
                    nb.b1.intersections(self, &results, min1 + range1/2, min1 + range1, min0, max0, !flip)
                }
            }
        }
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
    
    var position: CGPoint {
        return CGPoint(x: minX, y: minY)
    }
    var rect: CGRect {
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    func nearestDistance²(_ p: CGPoint) -> CGFloat {
        if p.x < minX {
            return p.y < minY ? hypot²(minX - p.x, minY - p.y) : (p.y <= maxY ? (minX - p.x).² : hypot²(minX - p.x, maxY - p.y))
        } else if p.x <= maxX {
            return p.y < minY ? (minY - p.y).² : (p.y <= maxY ? 0 : (minY - p.y).²)
        } else {
            return p.y < minY ? hypot²(maxX - p.x, minY - p.y) : (p.y <= maxY ? (maxX - p.x).² : hypot²(maxX - p.x, maxY - p.y))
        }
    }
    func intersects(_ other: AABB) -> Bool {
        return minX <= other.maxX && maxX >= other.minX && minY <= other.maxY && maxY >= other.minY
    }
}

struct ObjectType: Hashable {
    var identifier = ""
    var name = Localization()
    var globalIdentifier: String {
        return GlobalConstant.appIdentifier + "." + identifier
    }
    var hashValue: Int {
        return identifier.hashValue
    }
    static func == (lhs: ObjectType, rhs: ObjectType) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

struct Localization {
    var baseLanguageCode: String, base: String, values: [String: String]
    init(baseLanguageCode: String, base: String, values: [String: String]) {
        self.baseLanguageCode = baseLanguageCode
        self.base = base
        self.values = values
    }
    init(_ noLocalizeString: String) {
        baseLanguageCode = "en"
        base = noLocalizeString
        values = [:]
    }
    init(english: String = "", japanese: String = "") {
        baseLanguageCode = "en"
        base = english
        values = ["ja": japanese]
    }
    var currentString: String {
        return string(with: Locale.current)
    }
    func string(with locale: Locale) -> String {
        if let languageCode = locale.languageCode, let value = values[languageCode] {
            return value
        }
        return base
    }
    var isEmpty: Bool {
        return base.isEmpty
    }
    static func + (left: Localization, right: Localization) -> Localization {
        var values = left.values
        for v in right.values {
            values[v.key] = (left.values[v.key] ?? left.base) + v.value
        }
        return Localization(baseLanguageCode: left.baseLanguageCode, base: left.base + right.base, values: values)
    }
    static func += (left: inout Localization, right: Localization) {
        for v in right.values {
            left.values[v.key] = (left.values[v.key] ?? left.base) + v.value
        }
        left.base += right.base
    }
    static func == (lhs: Localization, rhs: Localization) -> Bool {
        return lhs.base == rhs.base
    }
}

final class LockTimer {
    private var count = 0
    private(set) var wait = false
    func begin(_ endTimeLength: Double, beginHandler: () -> Void, endHandler: @escaping () -> Void) {
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
    func begin(_ interval: Double, repeats: Bool = true, tolerance: Double = 0.0, handler: @escaping (Void) -> Void) {
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

func hypot²(_ lhs: CGFloat, _ rhs: CGFloat) -> CGFloat {
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
    func withRemovedFirst() -> Array {
        var array = self
        array.removeFirst()
        return array
    }
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

struct MonosplineX {
    let h0: CGFloat, h1: CGFloat, h2: CGFloat, reciprocalH0: CGFloat, reciprocalH1: CGFloat, reciprocalH2: CGFloat
    let reciprocalH0H1: CGFloat, reciprocalH1H2: CGFloat, reciprocalH1H1: CGFloat, xx3: CGFloat, xx2: CGFloat, xx1: CGFloat, t: CGFloat
    init(x1: CGFloat, x2: CGFloat, x3: CGFloat, x: CGFloat, t: CGFloat) {
        h0 = 0
        h1 = x2 - x1
        h2 = x3 - x2
        reciprocalH0 = 0
        reciprocalH1 = 1/h1
        reciprocalH2 = 1/h2
        reciprocalH0H1 = 0
        reciprocalH1H2 = 1/(h1 + h2)
        reciprocalH1H1 = 1/(h1*h1)
        self.t = t
        xx1 = x - x1
        xx2 = xx1*xx1
        xx3 = xx1*xx1*xx1
    }
    init(x0: CGFloat, x1: CGFloat, x2: CGFloat, x3: CGFloat, x: CGFloat, t: CGFloat) {
        h0 = x1 - x0
        h1 = x2 - x1
        h2 = x3 - x2
        reciprocalH0 = 1/h0
        reciprocalH1 = 1/h1
        reciprocalH2 = 1/h2
        reciprocalH0H1 = 1/(h0 + h1)
        reciprocalH1H2 = 1/(h1 + h2)
        reciprocalH1H1 = 1/(h1*h1)
        self.t = t
        xx1 = x - x1
        xx2 = xx1*xx1
        xx3 = xx1*xx1*xx1
    }
    init(x0: CGFloat, x1: CGFloat, x2: CGFloat, x: CGFloat, t: CGFloat) {
        h0 = x1 - x0
        h1 = x2 - x1
        h2 = 0
        reciprocalH0 = 1/h0
        reciprocalH1 = 1/h1
        reciprocalH2 = 0
        reciprocalH0H1 = 1/(h0 + h1)
        reciprocalH1H2 = 0
        reciprocalH1H1 = 1/(h1*h1)
        self.t = t
        xx1 = x - x1
        xx2 = xx1*xx1
        xx3 = xx1*xx1*xx1
    }
}

extension String: CopyData, Drawable {
    static var type: ObjectType {
        return ObjectType(identifier: "String", name: Localization(english: "String", japanese: "文字"))
    }
    func draw(with bounds: CGRect, in ctx: CGContext) {
        let textLine = TextLine(string: self, font: Defaults.thumbnailFont, paddingWidth: 2, paddingHeight: 2, frameWidth: bounds.width)
        textLine.draw(in: bounds, in: ctx)
    }
    static func with(_ data: Data) -> String? {
        return String(data: data, encoding: .utf8)
    }
    var data: Data {
        return data(using: .utf8) ?? Data()
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
}
extension Double {
    var cf: CGFloat {
        return CGFloat(self)
    }
}
extension CGFloat: Interpolatable {
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
    
    func isApproximatelyEqual(other: CGFloat, roundingError: CGFloat = 0.0000000001.cf) -> Bool {
        return abs(self - other) < roundingError
    }
    var ²: CGFloat {
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
        let s1 = (f2 - f1)*msx.reciprocalH1, s2 = (f3 - f2)*msx.reciprocalH2
        let signS1: CGFloat = s1 > 0 ? 1 : -1, signS2: CGFloat = s2 > 0 ? 1 : -1
        let yPrime1 = s1
        let yPrime2 = (signS1 + signS2)*Swift.min(abs(s1), abs(s2), 0.5*abs((msx.h2*s1 + msx.h1*s2)*msx.reciprocalH1H2))
        return _monospline(f1, s1, yPrime1, yPrime2, with: msx)
    }
    static func monospline(_ f0: CGFloat, _ f1: CGFloat, _ f2: CGFloat, _ f3: CGFloat, with msx: MonosplineX) -> CGFloat {
        let s0 = (f1 - f0)*msx.reciprocalH0, s1 = (f2 - f1)*msx.reciprocalH1, s2 = (f3 - f2)*msx.reciprocalH2
        let signS0: CGFloat = s0 > 0 ? 1 : -1, signS1: CGFloat = s1 > 0 ? 1 : -1, signS2: CGFloat = s2 > 0 ? 1 : -1
        let yPrime1 = (signS0 + signS1)*Swift.min(abs(s0), abs(s1), 0.5*abs((msx.h1*s0 + msx.h0*s1)*msx.reciprocalH0H1))
        let yPrime2 = (signS1 + signS2)*Swift.min(abs(s1), abs(s2), 0.5*abs((msx.h2*s1 + msx.h1*s2)*msx.reciprocalH1H2))
        return _monospline(f1, s1, yPrime1, yPrime2, with: msx)
    }
    static func endMonospline(_ f0: CGFloat, _ f1: CGFloat, _ f2: CGFloat, with msx: MonosplineX) -> CGFloat {
        let s0 = (f1 - f0)*msx.reciprocalH0, s1 = (f2 - f1)*msx.reciprocalH1
        let signS0: CGFloat = s0 > 0 ? 1 : -1, signS1: CGFloat = s1 > 0 ? 1 : -1
        let yPrime1 = (signS0 + signS1)*Swift.min(abs(s0), abs(s1), 0.5*abs((msx.h1*s0 + msx.h0*s1)*msx.reciprocalH0H1))
        let yPrime2 = s1
        return _monospline(f1, s1, yPrime1, yPrime2, with: msx)
    }
    private static func _monospline(_ f1: CGFloat, _ s1: CGFloat, _ yPrime1: CGFloat, _ yPrime2: CGFloat, with msx: MonosplineX) -> CGFloat {
        let a = (yPrime1 + yPrime2 - 2*s1)*msx.reciprocalH1H1, b = (3*s1 - 2*yPrime1 - yPrime2)*msx.reciprocalH1, c = yPrime1, d = f1
        return a*msx.xx3 + b*msx.xx2 + c*msx.xx1 + d
    }
}

extension CGPoint: Interpolatable, Hashable {
    public var hashValue: Int {
        return (x.hashValue << MemoryLayout<CGFloat>.size) ^ y.hashValue
    }
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
    static func intersectionLineSegment(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ p4: CGPoint, isSegmentP3P4: Bool = true) -> CGPoint? {
        let delta = (p2.x - p1.x)*(p4.y - p3.y) - (p2.y - p1.y)*(p4.x - p3.x)
        if delta != 0 {
            let u = ((p3.x - p1.x)*(p4.y - p3.y) - (p3.y - p1.y)*(p4.x - p3.x))/delta
            if u >= 0 && u <= 1 {
                let v = ((p3.x - p1.x)*(p2.y - p1.y) - (p3.y - p1.y)*(p2.x - p1.x))/delta
                if v >= 0 && v <= 1 || !isSegmentP3P4 {
                    return CGPoint(x: p1.x + u*(p2.x - p1.x), y: p1.y + u*(p2.y - p1.y))
                }
            }
        }
        return nil
    }
    static func intersectionLine(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ p4: CGPoint) -> CGPoint? {
        let d = (p2.x - p1.x)*(p4.y - p3.y) - (p2.y - p1.y)*(p4.x - p3.x)
        if d == 0 {
            return nil
        }
        let u = ((p3.x - p1.x)*(p4.y - p3.y) - (p3.y - p1.y)*(p4.x - p3.x))/d
        return CGPoint(x: p1.x + u*(p2.x - p1.x), y: p1.y + u*(p2.y - p1.y))
    }
    func isApproximatelyEqual(other: CGPoint, roundingError: CGFloat = 0.0000000001.cf) -> Bool {
        return x.isApproximatelyEqual(other: other.x, roundingError: roundingError)
            && y.isApproximatelyEqual(other: other.y, roundingError: roundingError)
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
        return ap == bp ? distance(ap) : abs((bp - ap).crossVector(self - ap))/ap.distance(bp)
    }
    func normalLinearInequality(ap: CGPoint, bp: CGPoint) -> Bool {
        if bp.y - ap.y == 0 {
            return bp.x > ap.x ? x <= ap.x : x >= ap.x
        } else {
            let ny = (-(bp.x - ap.x)/(bp.y - ap.y))*(x - ap.x) + ap.y
            return bp.y > ap.y ? y <= ny : y >= ny
        }
    }
    func tWithLineSegment(ap: CGPoint, bp: CGPoint) -> CGFloat {
        if ap == bp {
            return 0.5
        } else {
            let bav = bp - ap, pav = self - ap
            return ((bav.x*pav.x + bav.y*pav.y)/(bav.x*bav.x + bav.y*bav.y)).clip(min: 0, max: 1)
        }
    }
    static func boundsPointWithLine(ap: CGPoint, bp: CGPoint, bounds: CGRect) -> (p0: CGPoint, p1: CGPoint)? {
        let p0 = CGPoint.intersectionLineSegment(CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.minX, y: bounds.maxY), ap, bp, isSegmentP3P4: false)
        let p1 = CGPoint.intersectionLineSegment(CGPoint(x: bounds.maxX, y: bounds.minY), CGPoint(x: bounds.maxX, y: bounds.maxY), ap, bp, isSegmentP3P4: false)
        let p2 = CGPoint.intersectionLineSegment(CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.maxX, y: bounds.minY), ap, bp, isSegmentP3P4: false)
        let p3 = CGPoint.intersectionLineSegment(CGPoint(x: bounds.minX, y: bounds.maxY), CGPoint(x: bounds.maxX, y: bounds.maxY), ap, bp, isSegmentP3P4: false)
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
    func nearestWithLine(ap: CGPoint, bp: CGPoint) -> CGPoint {
        if ap == bp {
            return ap
        } else {
            let av = bp - ap, bv = self - ap
            let r = (av.x*bv.x + av.y*bv.y)/(av.x*av.x + av.y*av.y)
            return CGPoint(x: ap.x + r*av.x, y: ap.y + r*av.y)
        }
    }
    func perpendicularDeltaPoint(withDistance distance: CGFloat) -> CGPoint {
        if self == CGPoint() {
            return CGPoint(x: distance, y: 0)
        } else {
            let r = distance/hypot(x, y)
            return CGPoint(x: -r*y, y: r*x)
        }
    }
    func distance²(_ other: CGPoint) -> CGFloat {
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
    static func += (left: inout CGPoint, right: CGPoint) {
        left.x += right.x
        left.y += right.y
    }
    static func - (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x - right.x, y: left.y - right.y)
    }
    static func * (left: CGFloat, right: CGPoint) -> CGPoint {
        return CGPoint(x: right.x*left, y: right.y*left)
    }
    static func * (left: CGPoint, right: CGFloat) -> CGPoint {
        return CGPoint(x: left.x*right, y: left.y*right)
    }
    static func / (left: CGPoint, right: CGFloat) -> CGPoint {
        return CGPoint(x: left.x/right, y: left.y/right)
    }
    
    func draw(radius r: CGFloat, lineWidth: CGFloat = 1, inColor: CGColor = Defaults.contentColor.cgColor, outColor: CGColor = Defaults.editColor.cgColor, in ctx: CGContext) {
        let rect = CGRect(x: x - r, y: y - r, width: r*2, height: r*2)
        ctx.setFillColor(outColor)
        ctx.fillEllipse(in: rect.insetBy(dx: -lineWidth, dy: -lineWidth))
        ctx.setFillColor(inColor)
        ctx.fillEllipse(in: rect)
    }
}

extension CGRect {
    func distance²(_ point: CGPoint) -> CGFloat {
        return AABB(self).nearestDistance²(point)
    }
    func unionNoEmpty(_ other: CGRect) -> CGRect {
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
    static func with(hue h: CGFloat, saturation s: CGFloat, brightness v: CGFloat, alpha a: CGFloat = 1.0, colorSpace: CGColorSpace) -> CGColor? {
        if s == 0 {
            return CGColor(colorSpace: colorSpace, components: [v, v, v, a])
        } else {
            let h6 = 6*h
            let hi = Int(h6)
            let nh = h6 - hi.cf
            switch (hi) {
            case 0:
                return CGColor(colorSpace: colorSpace, components: [v, v*(1 - s*(1 - nh)), v*(1 - s), a])
            case 1:
                return CGColor(colorSpace: colorSpace, components: [v*(1 - s*nh), v, v*(1 - s), a])
            case 2:
                return CGColor(colorSpace: colorSpace, components: [v*(1 - s), v, v*(1 - s*(1 - nh)), a])
            case 3:
                return CGColor(colorSpace: colorSpace, components: [v*(1 - s), v*(1 - s*nh), v, a])
            case 4:
                return CGColor(colorSpace: colorSpace, components: [v*(1 - s*(1 - nh)), v*(1 - s), v, a])
            default:
                return CGColor(colorSpace: colorSpace, components: [v, v*(1 - s), v*(1 - s*nh), a])
            }
        }
    }
}

extension CGImage {
    var size: CGSize {
        return CGSize(width: width, height: height)
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
    static func bitmap(with size: CGSize) -> CGContext? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }
        return CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
    }
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

extension CGAffineTransform {
    static func centering(from fromFrame: CGRect, to toFrame: CGRect) -> (scale: CGFloat, affine: CGAffineTransform) {
        guard !fromFrame.isEmpty && !toFrame.isEmpty else {
            return (1, CGAffineTransform.identity)
        }
        var affine = CGAffineTransform.identity
        let fromRatio = fromFrame.width/fromFrame.height, toRatio = toFrame.width/toFrame.height
        if fromRatio > toRatio {
            let xScale = toFrame.width/fromFrame.size.width
            affine = affine.translatedBy(x: toFrame.origin.x, y: toFrame.origin.y + (toFrame.height - fromFrame.height*xScale)/2)
            affine = affine.scaledBy(x: xScale, y: xScale)
            return (xScale, affine.translatedBy(x: -fromFrame.origin.x, y: -fromFrame.origin.y))
        } else {
            let yScale = toFrame.height/fromFrame.size.height
            affine = affine.translatedBy(x: toFrame.origin.x + (toFrame.width - fromFrame.width*yScale)/2, y: toFrame.origin.y)
            affine = affine.scaledBy(x: yScale, y: yScale)
            return (yScale, affine.translatedBy(x: -fromFrame.origin.x, y: -fromFrame.origin.y))
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

extension NSAttributedString {
    static func attributes(_ font: CTFont, color: CGColor) -> [String: Any] {
        return [String(kCTFontAttributeName): font, String(kCTForegroundColorAttributeName): color]
    }
}

extension Bundle {
    var version: Int {
        return Int(infoDictionary?[String(kCFBundleVersionKey)] as? String ?? "0") ?? 0
    }
}
