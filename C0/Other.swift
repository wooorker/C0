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
    var p0 = CGPoint(), cp = CGPoint(), p1 = CGPoint()
    
    static func linear(_ p0: CGPoint, _ p1: CGPoint) -> Bezier2 {
        return Bezier2(p0: p0, cp: p0.mid(p1), p1: p1)
    }
    static func firstSpline(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, p1p2Weight: CGFloat) -> Bezier2 {
        return Bezier2(p0: p0, cp: p1, p1: CGPoint.linear(p1, p2, t: p1p2Weight))
    }
    static func spline(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, p0p1Weight: CGFloat, p1p2Weight: CGFloat) -> Bezier2 {
        return Bezier2(p0: CGPoint.linear(p0, p1, t: p0p1Weight), cp: p1, p1: CGPoint.linear(p1, p2, t: p1p2Weight))
    }
    static func endSpline(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, p0p1Weight: CGFloat) -> Bezier2 {
        return Bezier2(p0: CGPoint.linear(p0, p1, t: p0p1Weight), cp: p1, p1: p2)
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
    
    func nearestT(with p: CGPoint) -> CGFloat {
        let p0x = p0.x - p.x, p0y = p0.y - p.y, p1x = p1.x - p.x, p1y = p1.y - p.y
        let cpx = cp.x - p.x, cpy = cp.y - p.y
        let xx = p0x + p1x, yy = p0y + p1y
        let cc = cpx*cpx + cpy*cpy
        let a = 4*(xx*xx + yy*yy + 4*cc - 4*cpx*xx - 4*cpy*yy)
        let b = -12*(p0x*xx + p0y*yy + 2*cc + (-3*p0x - p1x)*cpx + (-3*p0y - p1y)*cpy)
        let c = 4*((3*p0x + p1x - 6*cpx)*p0x + (3*p0y + p1y - 6*cpy)*p0y + 2*cc)
        let d = -4*(p0y*p0y - cpy*p0y + p0x*p0x - cpx*p0x)
        let ta = 27*a*a*d*d + (4*b*b*b - 18*a*b*c)*d + 4*a*c*c*c - b*b*c*c
        if ta > 0 {
            let ta2 = sqrt(ta)/(6*sqrt(3)*a*a) - (27*a*a*d - 9*a*b*c + 2*b*b*b)/(54*a*a*a)
            let ta3 = ta2 < 0 ? -pow(-ta2,1/3) : pow(ta2,1/3)
            return max(0, min(1, (ta3 - (3*a*c - b*b)/(9*a*a*ta3) - b/(3*a))))
        } else if ta < 0 {
            func diff(_ t: CGFloat) -> CGFloat {
                return a*t*t*t + b*t*t + c*t + d
            }
            let tt0 = (-b - sqrt(b*b - 3*a*c))/(3*a), tt1 = (-b + sqrt(b*b - 3*a*c))/(3*a)
            var t0 = 0.cf, t1 = 1.0.cf
            if tt0 > 0 && diff(0) < 0 {
                var ot0 = 0.0.cf, ot1 = tt0
                t0 = (ot0 + ot1)/2
                while true {
                    let dt = diff(t0)
                    if abs(dt) <= 0.000001 {
                        break
                    }
                    if dt > 0 {
                        ot1 = t0
                        t0 = (ot0 + ot1)/2
                    } else {
                        ot0 = t0
                        t0 = (ot0 + ot1)/2
                    }
                }
            }
            if tt1 < 1 && diff(1) > 0 {
                var ot0 = tt1, ot1 = 1.0.cf
                t1 = (ot0 + ot1)/2
                while true {
                    let dt = diff(t1)
                    if abs(dt) <= 0.000001 {
                        break
                    }
                    if dt < 0 {
                        ot0 = t1
                        t1 = (ot0 + ot1)/2
                    } else {
                        ot1 = t1
                        t1 = (ot0 + ot1)/2
                    }
                }
            }
            let dv0 = CGPoint(x: t0*t0*(p1x + p0x - 2*cpx) + t0*(2*cpx - 2*p0x) + p0x, y: t0*t0*(p1y + p0y - 2*cpy) + t0*(2*cpy - 2*p0y) + p0y)
            let dv1 = CGPoint(x: t1*t1*(p1x + p0x - 2*cpx) + t1*(2*cpx - 2*p0x) + p0x, y: t1*t1*(p1y + p0y - 2*cpy) + t1*(2*cpy - 2*p0y) + p0y)
            return hypot(dv0.x, dv0.y) < hypot(dv1.x, dv1.y) ? t0 : t1
        } else {
            return -d/c
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
}
extension Double {
    var cf: CGFloat {
        return CGFloat(self)
    }
}

struct MonosplineX {
    let h0: CGFloat, h1: CGFloat, h2: CGFloat, invertH0: CGFloat, invertH1: CGFloat, invertH2: CGFloat
    let invertH0H1: CGFloat, invertH1H2: CGFloat, invertH1H1: CGFloat, xx3: CGFloat, xx2: CGFloat, xx1: CGFloat, t: CGFloat
    init(x1: CGFloat, x2: CGFloat, x3: CGFloat, x: CGFloat, t: CGFloat) {
        h0 = 0
        h1 = x2 - x1
        h2 = x3 - x2
        invertH0 = 0
        invertH1 = 1/h1
        invertH2 = 1/h2
        invertH0H1 = 0
        invertH1H2 = 1/(h1 + h2)
        invertH1H1 = 1/(h1*h1)
        self.t = t
        xx1 = x - x1
        xx2 = xx1*xx1
        xx3 = xx1*xx1*xx1
    }
    init(x0: CGFloat, x1: CGFloat, x2: CGFloat, x3: CGFloat, x: CGFloat, t: CGFloat) {
        h0 = x1 - x0
        h1 = x2 - x1
        h2 = x3 - x2
        invertH0 = 1/h0
        invertH1 = 1/h1
        invertH2 = 1/h2
        invertH0H1 = 1/(h0 + h1)
        invertH1H2 = 1/(h1 + h2)
        invertH1H1 = 1/(h1*h1)
        self.t = t
        xx1 = x - x1
        xx2 = xx1*xx1
        xx3 = xx1*xx1*xx1
    }
    init(x0: CGFloat, x1: CGFloat, x2: CGFloat, x: CGFloat, t: CGFloat) {
        h0 = x1 - x0
        h1 = x2 - x1
        h2 = 0
        invertH0 = 1/h0
        invertH1 = 1/h1
        invertH2 = 0
        invertH0H1 = 1/(h0 + h1)
        invertH1H2 = 0
        invertH1H1 = 1/(h1*h1)
        self.t = t
        xx1 = x - x1
        xx2 = xx1*xx1
        xx3 = xx1*xx1*xx1
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
    
    func isEqualAngle(_ other: CGFloat) -> Bool {
        let roundingError = 0.0000000001.cf
        return abs(self - other) < roundingError
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
    static func intersectionLineSegment(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ p4: CGPoint) -> CGPoint? {
        let delta = (p2.x - p1.x)*(p4.y - p3.y) - (p2.y - p1.y)*(p4.x - p3.x)
        if delta != 0 {
            let u = ((p3.x - p1.x)*(p4.y - p3.y) - (p3.y - p1.y)*(p4.x - p3.x))/delta
            if u >= 0 && u <= 1 {
                let v = ((p3.x - p1.x)*(p2.y - p1.y) - (p3.y - p1.y)*(p2.x - p1.x))/delta
                if v >= 0 && v <= 1 {
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
    func tWithLineSegment(ap: CGPoint, bp: CGPoint) -> CGFloat {
        if ap == bp {
            return 0.5
        } else {
            let bav = bp - ap, pav = self - ap
            return (bav.x*pav.x + bav.y*pav.y)/(bav.x*bav.x + bav.y*bav.y)
        }
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
    func perpendicularWith(deltaPoint dp: CGPoint, distance: CGFloat) -> CGPoint {
        if dp == CGPoint() {
            return CGPoint(x: x + distance, y: y)
        } else {
            let r = distance/sqrt(dp.x*dp.x + dp.y*dp.y)
            return CGPoint(x: x + r*y, y: y + r*x)
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

extension NSColor {
    final class func checkerboardColor(_ color: NSColor, subColor: NSColor, size s: CGFloat = 5.0) -> NSColor {
        let size = NSSize(width: s*2,  height: s*2)
        let image = NSImage(size: size) { ctx in
            let rect = CGRect(origin: CGPoint(), size: size)
            ctx.setFillColor(color.cgColor)
            ctx.fill(rect)
            ctx.fill(CGRect(x: 0, y: s, width: s, height: s))
            ctx.fill(CGRect(x: s, y: 0, width: s, height: s))
            ctx.setFillColor(subColor.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))
            ctx.fill(CGRect(x: s, y: s, width: s, height: s))
        }
        return NSColor(patternImage: image)
    }
    static func polkaDotColorWith(color: NSColor?, dotColor: NSColor, radius r: CGFloat = 1.0, distance d: CGFloat = 4.0) -> NSColor {
        let tw = (2*r + d)*cos(.pi/3), th = (2*r + d)*sin(.pi/3)
        let bw = (tw - 2*r)/2, bh = (th - 2*r)/2
        let size = CGSize(width: floor(bw*2 + tw + r*2), height: floor(bh*2 + th + r*2))
        let image = NSImage(size: size) { ctx in
            if let color = color {
                ctx.setFillColor(color.cgColor)
                ctx.fill(CGRect(origin: CGPoint(), size: size))
            }
            ctx.setFillColor(dotColor.cgColor)
            ctx.fillEllipse(in: CGRect(x: bw, y: bh, width: r*2, height: r*2))
            ctx.fillEllipse(in: CGRect(x: bw + tw, y: bh + th, width: r*2, height: r*2))
        }
        return NSColor(patternImage: image)
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
