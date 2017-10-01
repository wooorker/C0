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

//# Issue
//「最後の線に適用するコマンド」をすべて「最も近い線に適用するコマンド」に変更する
//着色線の導入（原画時に簡単に塗り分けるための、線を着色線化するコマンドの導入。着色線は囲み消しの範囲と同等）

import Foundation

final class Line: NSObject, NSCoding, Interpolatable {
    struct Control {
        var point = CGPoint(), pressure = 1.0.cf
        func mid(_ other: Control) -> Control {
            return Control(point: point.mid(other.point), pressure: (pressure + other.pressure)/2)
        }
    }
    let controls: [Control], imageBounds: CGRect
    convenience init(bezier: Bezier2, p0Pressure: CGFloat, cpPressure: CGFloat, p1Pressure: CGFloat) {
        self.init(controls: [
            Control(point: bezier.p0, pressure: p0Pressure),
            Control(point: bezier.cp, pressure: cpPressure),
            Control(point: bezier.p1, pressure: p1Pressure)
            ])
    }
    init(controls: [Control]) {
        self.controls = controls
        self.imageBounds = Line.imageBounds(with: controls)
        super.init()
    }
    
    static let dataType = "C0.Line.1", controlsKey = "6", imageBoundsKey = "2"
    init?(coder: NSCoder) {
        controls = coder.decodeStruct(forKey: Line.controlsKey) ?? []
        imageBounds = coder.decodeRect(forKey: Line.imageBoundsKey)
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeStruct(controls, forKey: Line.controlsKey)
        coder.encode(imageBounds, forKey: Line.imageBoundsKey)
    }
    
    func withInsert(_ control: Control, at i: Int) -> Line {
        return Line(controls: controls.withInserted(control, at: i))
    }
    func withRemoveControl(at i: Int) -> Line {
        return Line(controls: controls.withRemoved(at: i))
    }
    func withReplaced(_ control: Control, at i: Int) -> Line {
        return Line(controls: controls.withReplaced(control, at: i))
    }
    
    static func linear(_ f0: Line, _ f1: Line, t: CGFloat) -> Line {
        let count = max(f0.controls.count, f1.controls.count)
        return Line(controls: (0 ..< count).map { i in
            let f0c = f0.control(at: i, maxCount: count), f1c = f1.control(at: i, maxCount: count)
            return Control(
                point: CGPoint.linear(f0c.point, f1c.point, t: t),
                pressure: CGFloat.linear(f0c.pressure, f1c.pressure, t: t)
            )
        })
    }
    static func firstMonospline(_ f1: Line, _ f2: Line, _ f3: Line, with msx: MonosplineX) -> Line {
        let count = max(f1.controls.count, f2.controls.count, f3.controls.count)
        return Line(controls: (0 ..< count).map { i in
            let f1c = f1.control(at: i, maxCount: count), f2c = f2.control(at: i, maxCount: count), f3c = f3.control(at: i, maxCount: count)
            return Control(
                point: CGPoint.firstMonospline(f1c.point, f2c.point, f3c.point, with: msx),
                pressure: CGFloat.firstMonospline(f1c.pressure, f2c.pressure, f3c.pressure, with: msx)
            )
        })
    }
    static func monospline(_ f0: Line, _ f1: Line, _ f2: Line, _ f3: Line, with msx: MonosplineX) -> Line {
        let count = max(f0.controls.count, f1.controls.count, f2.controls.count, f3.controls.count)
        return Line(controls: (0 ..< count).map { i in
            let f0c = f0.control(at: i, maxCount: count), f1c = f1.control(at: i, maxCount: count), f2c = f2.control(at: i, maxCount: count), f3c = f3.control(at: i, maxCount: count)
            return Control(
                point: CGPoint.monospline(f0c.point, f1c.point, f2c.point, f3c.point, with: msx),
                pressure: CGFloat.monospline(f0c.pressure, f1c.pressure, f2c.pressure, f3c.pressure, with: msx)
            )
        })
    }
    static func endMonospline(_ f0: Line, _ f1: Line, _ f2: Line, with msx: MonosplineX) -> Line {
        let count = max(f0.controls.count, f1.controls.count, f2.controls.count)
        return Line(controls: (0 ..< count).map { i in
            let f0c = f0.control(at: i, maxCount: count), f1c = f1.control(at: i, maxCount: count), f2c = f2.control(at: i, maxCount: count)
            return Control(
                point: CGPoint.endMonospline(f0c.point, f1c.point, f2c.point, with: msx),
                pressure: CGFloat.endMonospline(f0c.pressure, f1c.pressure, f2c.pressure, with: msx)
            )
        })
    }
    private func control(at i: Int, maxCount: Int) -> Control {
        if controls.count == maxCount {
            return controls[i]
        } else {
            let d = maxCount - controls.count
            let minD = d/2
            if i < minD {
                return controls[0]
            } else if i > maxCount - (d - minD) - 1 {
                return controls[controls.count - 1]
            } else {
                return controls[i - minD]
            }
        }
    }
    
    func applying(_ affine: CGAffineTransform) -> Line {
        return Line(controls: controls.map { Control(point: $0.point.applying(affine), pressure: $0.pressure) })
    }
    func reversed() -> Line {
        return Line(controls: controls.reversed())
    }
    func warpedWith(deltaPoint dp: CGPoint, isFirst: Bool) -> Line {
        var allD = 0.0.cf, oldP = firstPoint
        for i in 1 ..< controls.count {
            let p = controls[i].point
            allD += sqrt(p.distance²(oldP))
            oldP = p
        }
        oldP = firstPoint
        let reciprocalAllD = allD > 0 ? 1/allD : 0
        var allAD = 0.0.cf
        return Line(controls: controls.map {
            let p = $0.point
            allAD += sqrt(p.distance²(oldP))
            oldP = p
            let t = isFirst ? 1 - allAD*reciprocalAllD : allAD*reciprocalAllD
            return Control(point: CGPoint(x: $0.point.x + dp.x*t, y: $0.point.y + dp.y*t), pressure: $0.pressure)
        })
    }
    func warpedWith(deltaPoint dp: CGPoint, at index: Int) -> Line {
        var previousAllD = 0.0.cf, nextAllD = 0.0.cf, oldP = firstPoint
        for i in 1 ..< index {
            let p = controls[i].point
            previousAllD += sqrt(p.distance²(oldP))
            oldP = p
        }
        oldP = controls[index].point
        for i in index + 1 ..< controls.count {
            let p = controls[i].point
            nextAllD += sqrt(p.distance²(oldP))
            oldP = p
        }
        oldP = firstPoint
        let reciprocalPreviousAllD = previousAllD > 0 ? 1/previousAllD : 0, reciprocalNextAllD = nextAllD > 0 ? 1/nextAllD : 0
        var previousAllAD = 0.0.cf, nextAllAD = 0.0.cf, newControls = [controls[0]]
        for i in 1 ..< index {
            let p = controls[i].point
            previousAllAD += sqrt(p.distance²(oldP))
            let t = sqrt(previousAllAD*reciprocalPreviousAllD)
            newControls.append(Control(point: CGPoint(x: p.x + dp.x*t, y: p.y + dp.y*t), pressure: controls[i].pressure))
            oldP = p
        }
        let p = controls[index].point
        newControls.append(Control(point: CGPoint(x: p.x + dp.x, y: p.y + dp.y), pressure: controls[index].pressure))
        oldP = controls[index].point
        for i in index + 1 ..< controls.count {
            let p = controls[i].point
            nextAllAD += sqrt(p.distance²(oldP))
            let t = 1 - sqrt(nextAllAD*reciprocalNextAllD)
            newControls.append(Control(point: CGPoint(x: p.x + dp.x*t, y: p.y + dp.y*t), pressure: controls[i].pressure))
            oldP = p
        }
        return Line(controls: newControls)
    }
    func warpedWith(deltaPoint dp: CGPoint, editPoint: CGPoint, minDistance: CGFloat, maxDistance: CGFloat) -> Line {
        return Line(controls: controls.map {
            let d =  hypot²($0.point.x - editPoint.x, $0.point.y - editPoint.y)
            let ds = d > maxDistance ? 0 : (1 - (d - minDistance)/(maxDistance - minDistance))
            return Control(point: CGPoint(x: $0.point.x + dp.x*ds, y: $0.point.y + dp.y*ds), pressure: $0.pressure)
        })
    }
    func autoPressure(minPressure: CGFloat = 0.5) -> Line {
        let maxAngle = .pi/4.cf
        return Line(controls: controls.enumerated().map { i, control in
            if i == 0 || i == controls.count - 1 {
                return Control(point: control.point, pressure: minPressure)
            } else {
                let preControl = controls[i - 1], nextControl = controls[i + 1]
                let angle = abs(CGPoint.differenceAngle(p0: preControl.point, p1: control.point, p2: nextControl.point))
                return Control(point: control.point, pressure: CGFloat.linear(minPressure, 1, t: min(angle, maxAngle)/maxAngle))
            }
        })
    }
    
    func splited(at i: Int) -> Line {
        if i == 0 {
            return withInsert(controls[0].mid(controls[1]), at: 1)
        } else if i == controls.count - 1 {
            return withInsert(controls[controls.count - 1].mid(controls[controls.count - 2]), at: controls.count - 1)
        } else {
            var cs = controls
            cs[i] = controls[i - 1].mid(controls[i])
            cs.insert(controls[i].mid(controls[i + 1]), at: i + 1)
            return Line(controls: cs)
        }
    }
    func removedControl(at i: Int) -> Line {
        var cs = controls
        if i == 0 {
            cs.removeFirst()
            cs[0].point = cs[0].point.mid(cs[1].point)
        } else if i == controls.count - 1 {
            cs.removeLast()
            cs[cs.count - 1].point = cs[cs.count - 2].point.mid(cs[cs.count - 1].point)
        } else {
            cs.remove(at: i)
        }
        return Line(controls: cs)
    }
    
    func splited(startIndex: Int, endIndex: Int) -> Line {
        return Line(controls: Array(controls[startIndex...endIndex]))
    }
    func splited(startIndex: Int, startT: CGFloat, endIndex: Int, endT: CGFloat) -> [Line] {
        func pressure(at i: Int, t: CGFloat) -> CGFloat {
            let previousPressure = i == 0 ? controls[0].pressure : (controls[i].pressure + controls[i + 1].pressure)/2
            let nextPressure = i == controls.count - 3 ? controls[controls.count - 1].pressure : (controls[i + 1].pressure + controls[i + 2].pressure)/2
            return i  > 0 ? CGFloat.linear(previousPressure, nextPressure, t: t) : controls[i].pressure
        }
        if startIndex == endIndex {
            let b = bezier(at: startIndex).clip(startT: startT, endT: endT)
            let pr0 = startIndex == 0 && startT == 0 ? controls[0].pressure : pressure(at: startIndex, t: startT)
            let pr1 = endIndex == controls.count - 3 && endT == 1 ? controls[controls.count - 1].pressure : pressure(at: endIndex, t: endT)
            return [Line(bezier: b, p0Pressure: pr0, cpPressure: (pr0 + pr1)/2, p1Pressure: pr1)]
        } else {
            var newLines = [Line]()
            let indexes = startIndex + 1 ..< endIndex + 2
            var cs = Array(controls[indexes])
            if startIndex == 0 && startT == 0 {
                cs.insert(controls[0], at: 0)
            } else {
                cs[0] = controls[startIndex + 1].mid(controls[startIndex + 2])
                let fprs0 = pressure(at: startIndex, t: startT), fprs1 = cs[0].pressure
                newLines.append(Line(bezier: bezier(at: startIndex).clip(startT: startT, endT: 1), p0Pressure: fprs0, cpPressure: (fprs0 + fprs1)/2, p1Pressure: fprs1))
            }
            if endIndex == controls.count - 3 && endT == 1 {
                cs.append(controls[controls.count - 1])
                newLines.append(Line(controls: cs))
            } else {
                cs[cs.count - 1] = controls[endIndex].mid(controls[endIndex + 1])
                newLines.append(Line(controls: cs))
                let eprs0 = cs[cs.count - 1].pressure, eprs1 = pressure(at: endIndex, t: endT)
                newLines.append(Line(bezier: bezier(at: endIndex).clip(startT: 0, endT: endT), p0Pressure: eprs0, cpPressure: (eprs0 + eprs1)/2, p1Pressure: eprs1))
            }
            return newLines
        }
    }
    
    var firstPoint: CGPoint {
        return controls[0].point
    }
    var lastPoint: CGPoint {
        return controls[controls.count - 1].point
    }
    private static func imageBounds(with controls: [Control]) -> CGRect {
        if controls.isEmpty {
            return CGRect()
        } else if controls.count == 1 {
            return CGRect(origin: controls[0].point, size: CGSize())
        } else if controls.count == 2 {
            return Bezier2.linear(controls[0].point, controls[controls.count - 1].point).bounds
        } else if controls.count == 3 {
            return Bezier2(p0: controls[0].point, cp: controls[1].point, p1: controls[controls.count - 1].point).bounds
        } else {
            var connectP = controls[1].point.mid(controls[2].point)
            var b = Bezier2(p0: controls[0].point, cp: controls[1].point, p1: connectP).bounds
            for i in 1 ..< controls.count - 3 {
                let newConnectP = controls[i + 1].point.mid(controls[i + 2].point)
                b = b.union(Bezier2(p0: connectP, cp: controls[i + 1].point, p1: newConnectP).bounds)
                connectP = newConnectP
            }
            b = b.union(Bezier2(p0: connectP, cp: controls[controls.count - 2].point, p1: controls[controls.count - 1].point).bounds)
            return b
        }
    }
    static func imageBounds(with lines: [Line], lineWidth: CGFloat) -> CGRect {
        guard var firstBounds = lines.first?.imageBounds else {
            return CGRect()
        }
        for line in lines {
            firstBounds = firstBounds.union(line.imageBounds)
        }
        return firstBounds.insetBy(dx: -lineWidth/2, dy: -lineWidth/2)
    }
    
    func bezier(at i: Int) -> Bezier2 {
        if controls.count < 3 {
            return Bezier2.linear(firstPoint, lastPoint)
        } else if controls.count == 3 {
            return Bezier2(p0: controls[0].point, cp: controls[1].point, p1: controls[2].point)
        } else if i == 0 {
            return Bezier2.firstSpline(controls[0].point, controls[1].point, controls[2].point)
        } else if i == controls.count - 3 {
            return Bezier2.endSpline(controls[controls.count - 3].point, controls[controls.count - 2].point, controls[controls.count - 1].point)
        } else {
            return Bezier2.spline(controls[i].point, controls[i + 1].point, controls[i + 2].point)
        }
    }
    func bezierT(at p: CGPoint) -> (bezierIndex: Int, t: CGFloat, distance: CGFloat) {
        var minD = CGFloat.infinity, minT = 0.0.cf, minBezierIndex = 0
        allBeziers { bezier, i, stop in
            let t = bezier.nearestT(with: p)
            let np = bezier.position(withT: t)
            let d = p.distance(np)
            if d < minD {
                minD = d
                minT = t
                minBezierIndex = i
            }
        }
        return (minBezierIndex, minT, minD)
    }
    func bezierT(withLength length: CGFloat) -> (b: Bezier2, t: CGFloat)? {
        var bs: (b: Bezier2, t: CGFloat)?, allD = 0.0.cf
        allBeziers { b, index, stop in
            let d = b.length()
            let newAllD = allD + d
            if length < newAllD && d > 0 {
                bs = (b, b.t(withLength: length - allD))
                stop = true
            }
            allD = newAllD
        }
        return bs
    }
    func allBeziers(_ handler: (_ bezier: Bezier2, _ index: Int, _ stop: inout Bool) -> Void) {
        var stop = false
        if controls.count < 3 {
            handler(Bezier2.linear(firstPoint, lastPoint), 0, &stop)
        } else if controls.count == 3 {
            handler(Bezier2(p0: controls[0].point, cp: controls[1].point, p1: controls[2].point), 0, &stop)
        } else {
            var connectP = controls[1].point.mid(controls[2].point)
            handler(Bezier2(p0: controls[0].point, cp: controls[1].point, p1: connectP), 0, &stop)
            if stop {
                return
            }
            for i in 1 ..< controls.count - 3 {
                let newConnectP = controls[i + 1].point.mid(controls[i + 2].point)
                handler(Bezier2(p0: connectP, cp: controls[i + 1].point, p1: newConnectP), i, &stop)
                if stop {
                    return
                }
                connectP = newConnectP
            }
            handler(Bezier2(p0: connectP, cp: controls[controls.count - 2].point, p1: controls[controls.count - 1].point), controls.count - 3, &stop)
        }
    }
    func appendBezierCurves(withIsMove isMove: Bool, in path: CGMutablePath) {
        if let fp = controls.first?.point, let lp = controls.last?.point {
            if isMove {
                path.move(to: fp)
            } else {
                path.addLine(to: fp)
            }
            if controls.count >= 3 {
                for i in 2 ..< controls.count - 1 {
                    let control = controls[i], oldControl = controls[i - 1]
                    path.addQuadCurve(to: oldControl.point.mid(control.point), control: oldControl.point)
                }
                path.addQuadCurve(to: lp, control: controls[controls.count - 2].point)
            } else {
                path.addLine(to: lp)
            }
        }
    }
    
    static func maxDistance(at p: CGPoint, with lines: [Line]) -> CGFloat {
        return lines.reduce(0.0.cf) { max($0, $1.maxDistance(at: p)) }
    }
    static func centroidPoint(with lines: [Line]) -> CGPoint {
        let reciprocalCount = 1/lines.reduce(0) { $0 + $1.controls.count }.cf
        let p = lines.reduce(CGPoint()) { $1.controls.reduce($0) { $0 + $1.point } }
        return CGPoint(x: p.x*reciprocalCount, y: p.y*reciprocalCount)
    }
    func maxDistance(at p: CGPoint) -> CGFloat {
        var maxD = 0.0.cf
        allBeziers { b, i ,stop in
            maxD = max(maxD, b.maxDistance(at: p))
        }
        return maxD
    }
    
    func editCenterPoint(at index: Int) -> CGPoint {
        if index == 0 {
            return firstPoint
        } else if index == controls.count - 1 {
            return lastPoint
        } else {
            return bezier(at: index - 1).position(withT: 0.5)
        }
    }
    func editPoint(withEditCenterPoint xp: CGPoint, at i: Int) -> CGPoint {
        let bi = i - 1
        let m0 = bi == 0 ? 0 : 0.5.cf, m1 = bi == controls.count - 3 ? 1 : 0.5.cf
        let n0 = 1 - m0, n1 = 1 - m1, p0 = controls[bi].point, p2 = controls[bi + 2].point
        return (4*xp - n0*p0 - m1*p2)/(m0 + n1 + 2)
    }
    func allEditPoints(_ handler: (CGPoint, Int) -> Void) {
        handler(firstPoint, 0)
        if controls.count > 2 {
            allBeziers { bezier, i, stop in
                handler(bezier.position(withT: 0.5), i + 1)
            }
        }
        handler(lastPoint, controls.count - 1)
    }
    
    func isReverse(from other: Line) -> Bool {
        let l0 = other.lastPoint, f1 = firstPoint, l1 = lastPoint
        return hypot²(l1.x - l0.x, l1.y - l0.y) < hypot²(f1.x - l0.x, f1.y - l0.y)
    }
    func firstExtensionPoint(withLength length: CGFloat) -> CGPoint {
        return extensionPointWith(p0: controls[1].point, p1: controls[0].point, length: length)
    }
    func lastExtensionPoint(withLength length: CGFloat) -> CGPoint {
        return extensionPointWith(p0: controls[controls.count - 2].point, p1: controls[controls.count - 1].point, length: length)
    }
    private func extensionPointWith(p0: CGPoint, p1: CGPoint, length: CGFloat) -> CGPoint {
        if p0 == p1 {
            return p1
        } else {
            let x = p1.x - p0.x, y = p1.y - p0.y
            let reciprocalD = 1/hypot(x, y)
            return CGPoint(x: p1.x + x*length*reciprocalD, y: p1.y + y*length*reciprocalD)
        }
    }
    func angle(withPreviousLine preLine: Line) -> CGFloat {
        let t1 = preLine.controls.count >= 2 ? preLine.controls[preLine.controls.count - 2].point.tangential(preLine.controls[preLine.controls.count - 1].point)  : 0
        let t2 = controls.count >= 2 ? controls[0].point.tangential(controls[1].point)  : 0
        return abs(t1.differenceRotation(t2))
    }
    var strokeLastBoundingBox: CGRect {
        if controls.count <= 4 {
            return imageBounds
        } else {
            let b0 = Bezier2.spline(controls[controls.count - 4].point, controls[controls.count - 3].point, controls[controls.count - 2].point)
            let b1 = Bezier2.endSpline(controls[controls.count - 3].point, controls[controls.count - 2].point, controls[controls.count - 1].point)
            return b0.boundingBox.union(b1.boundingBox)
        }
    }
    var pointsLength: CGFloat {
        var length = 0.0.cf
        if var oldPoint = controls.first?.point {
            for control in controls {
                length += hypot(control.point.x - oldPoint.x, control.point.y - oldPoint.y)
                oldPoint = control.point
            }
        }
        return length
    }
    
    func intersects(_ bezier: Bezier2) -> Bool {
        if imageBounds.intersects(bezier.boundingBox) {
            var intersects = false
            allBeziers { ob, index, stop in
                if bezier.intersects(ob) {
                    intersects = true
                    stop = true
                }
            }
            return intersects
        } else {
            return false
        }
    }
    func intersects(_ other: Line) -> Bool {
        if imageBounds.intersects(other.imageBounds) {
            var intersects = false
            allBeziers { bezier, index, stop in
                if other.intersects(bezier) {
                    intersects = true
                    stop = true
                }
            }
            return intersects
        } else {
            return false
        }
    }
    @nonobjc func intersects(_ bounds: CGRect) -> Bool {
        if imageBounds.intersects(bounds) {
            if bounds.contains(firstPoint) {
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
    
    func drawEditPoint(_ point: CGPoint, inColor: CGColor, outColor: CGColor, radius: CGFloat, in ctx: CGContext) {
        ctx.setFillColor(inColor)
        ctx.setStrokeColor(outColor)
        ctx.addEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius*2, height: radius*2))
        ctx.drawPath(using: .fillStroke)
    }
    
    static func drawEditPointsWith(lines: [Line], inColor: CGColor = SceneDefaults.controlPointInColor, outColor: CGColor = SceneDefaults.controlPointOutColor, skinLineWidth: CGFloat = 1.0.cf, skinRadius: CGFloat = 1.5.cf, with di: DrawInfo, in ctx: CGContext) {
        let s = di.reciprocalScale
        let lineWidth = skinLineWidth*s*0.5, mor = skinRadius*s
        for line in lines {
            line.allEditPoints { p, i in
                if i != 0 && i != line.controls.count {
                    p.draw(radius: mor, lineWidth: lineWidth, inColor: inColor, outColor: outColor, in: ctx)
                }
            }
        }
    }
    static func drawCapPointsWith(lines: [Line],
                                  inColor: CGColor = SceneDefaults.controlPointCapInColor, outColor: CGColor = SceneDefaults.controlPointCapOutColor,
                                  jointInColor: CGColor = SceneDefaults.controlPointJointInColor, jointOutColor: CGColor = SceneDefaults.controlPointJointOutColor,
                                  unionInColor: CGColor = SceneDefaults.controlPointUnionInColor,  unionOutColor: CGColor = SceneDefaults.controlPointUnionOutColor,
                                  pathInColor: CGColor = SceneDefaults.controlPointPathInColor,  pathOutColor: CGColor = SceneDefaults.controlPointPathOutColor,
                                  skinLineWidth: CGFloat = 1.0.cf, skinRadius: CGFloat = 1.5.cf, isDrawMidPath: Bool = true, with di: DrawInfo, in ctx: CGContext) {
        let s = di.reciprocalScale
        let lineWidth = skinLineWidth*s*0.5, mor = skinRadius*s
        if var oldLine = lines.last {
            for line in lines {
                let isUnion = oldLine.lastPoint == line.firstPoint
                if isUnion {
                    if oldLine.controls[oldLine.controls.count - 2].point.mid(line.controls[1].point).isApproximatelyEqual(other: line.firstPoint) {
                        line.firstPoint.draw(radius: mor, lineWidth: lineWidth, inColor: unionInColor, outColor: unionOutColor, in: ctx)
                    } else {
                        line.firstPoint.draw(radius: mor, lineWidth: lineWidth, inColor:  jointInColor, outColor: jointOutColor, in: ctx)
                    }
                } else {
                    oldLine.lastPoint.draw(radius: mor, lineWidth: lineWidth, inColor: inColor, outColor: outColor, in: ctx)
                    line.firstPoint.draw(radius: mor, lineWidth: lineWidth, inColor: inColor, outColor: outColor, in: ctx)
                    if isDrawMidPath {
                        oldLine.lastPoint.mid(line.firstPoint).draw(radius: mor, lineWidth: lineWidth, inColor: pathInColor, outColor: pathOutColor, in: ctx)
                    }
                }
                oldLine = line
            }
        }
    }
    static func drawMidCapPointsWith(lines: [Line], pathInColor: CGColor = SceneDefaults.controlPointPathInColor,  pathOutColor: CGColor = SceneDefaults.controlPointPathOutColor,
                                  skinLineWidth: CGFloat = 1.0.cf, skinRadius: CGFloat = 1.5.cf, isDrawMidPath: Bool = true, with di: DrawInfo, in ctx: CGContext) {
        let s = di.reciprocalScale
        let lineWidth = skinLineWidth*s*0.5, mor = skinRadius*s
        if var oldLine = lines.last {
            for line in lines {
                let isUnion = oldLine.lastPoint == line.firstPoint
                if !isUnion {
                    oldLine.lastPoint.mid(line.firstPoint).draw(radius: mor, lineWidth: lineWidth, inColor: pathInColor, outColor: pathOutColor, in: ctx)
                }
                oldLine = line
            }
        }
    }
    
    func draw(size: CGFloat, in ctx: CGContext) {
        let s = size/2
        if ctx.boundingBoxOfClipPath.intersects(imageBounds.inset(by: -s)) {
            if controls.count == 2 {
                let theta = controls[0].point.tangential(controls[1].point) + .pi/2, pres = s*controls[0].pressure, pres2 = s*controls[1].pressure
                let dp = CGPoint(x: pres*cos(theta), y: pres*sin(theta))
                ctx.move(to: controls[0].point + dp)
                ctx.addArc(center: controls[controls.count - 1].point, radius: pres2, startAngle: theta, endAngle: theta - .pi, clockwise: true)
                ctx.addArc(center: controls[0].point, radius: pres, startAngle: theta - .pi, endAngle: theta - .pi*2, clockwise: true)
                ctx.fillPath()
            } else if controls.count >= 3 {
                let theta = controls[0].point.tangential(controls[1].point) + .pi/2, pres = s*controls[0].pressure
                var ps = [CGPoint](), previousPressure = controls[0].pressure
                ctx.move(to: controls[0].point + CGPoint(x: pres*cos(theta), y: pres*sin(theta)))
                if controls.count == 3 {
                    let bezier = self.bezier(at: 0), pr0 = s*controls[0].pressure, pr1 = s*controls[1].pressure, pr2 = s*controls[2].pressure
                    let length = bezier.p0.distance(bezier.cp) + bezier.cp.distance(bezier.p1)
                    let count = Int(length)
                    if count != 0 {
                        let splitDeltaT = 1/length
                        var t = 0.0.cf
                        for _ in 0 ..< count {
                            t += splitDeltaT
                            let p = bezier.position(withT: t)
                            let pres = t < 0.5 ? CGFloat.linear(pr0, pr1, t: t*2) : CGFloat.linear(pr1, pr2, t: (t - 0.5)*2)
                            let dp = bezier.difference(withT: t).perpendicularDeltaPoint(withDistance: pres)
                            ctx.addLine(to: p + dp)
                            ps.append(p - dp)
                        }
                    }
                } else {
                    allBeziers({ (bezier, i, stop) in
                        let length = bezier.p0.distance(bezier.cp) + bezier.cp.distance(bezier.p1)
                        let nextPressure = i == controls.count - 3 ? controls[controls.count - 1].pressure : (controls[i + 1].pressure + controls[i + 2].pressure)/2
                        let count = Int(length)
                        if count != 0 {
                            let splitDeltaT = 1/length
                            var t = 0.0.cf
                            for _ in 0 ..< count {
                                t += splitDeltaT
                                let p = bezier.position(withT: t)
                                let pres = CGFloat.linear(s*previousPressure, s*nextPressure, t: t)
                                let dp = bezier.difference(withT: t).perpendicularDeltaPoint(withDistance: pres)
                                ctx.addLine(to: p + dp)
                                ps.append(p - dp)
                            }
                        }
                        previousPressure = nextPressure
                    })
                }
                let theta2 = controls[controls.count - 2].point.tangential(controls[controls.count - 1].point) + .pi/2, pres2 = s*controls[controls.count - 1].pressure
                ctx.addArc(center: controls[controls.count - 1].point, radius: pres2, startAngle: theta2, endAngle: theta2 - .pi, clockwise: true)
                for p in ps.reversed() {
                    ctx.addLine(to: p)
                }
                ctx.addArc(center: controls[0].point, radius: pres, startAngle: theta - .pi, endAngle: theta - .pi*2, clockwise: true)
                ctx.fillPath()
            }
        }
    }
}

struct Lasso {
    let lines: [Line]
    private let path: CGPath
    init(lines: [Line]) {
        self.lines = lines
        self.path = Lasso.path(with: lines)
    }
    static func path(with lines: [Line]) -> CGPath {
        if !lines.isEmpty {
            let path = CGMutablePath()
            for (i, line) in lines.enumerated() {
                line.appendBezierCurves(withIsMove: i == 0, in: path)
            }
            path.closeSubpath()
            return path
        } else {
            return CGMutablePath()
        }
    }
    var imageBounds: CGRect {
        return path.boundingBox
    }
    func contains(_ p: CGPoint) -> Bool {
        return (imageBounds.contains(p) ? path.contains(p) : false)
    }
    
    func intersects(_ otherLine: Line) -> Bool {
        if imageBounds.intersects(otherLine.imageBounds) {
            for line in lines {
                if line.intersects(otherLine) {
                    return true
                }
            }
            for control in otherLine.controls {
                if contains(control.point) {
                    return true
                }
            }
        }
        return false
    }
    
    func split(_ otherLine: Line) -> [Line]? {
        func intersectsLineImageBounds(_ otherLine: Line) -> Bool {
            for line in lines {
                if otherLine.imageBounds.intersects(line.imageBounds) {
                    return true
                }
            }
            return false
        }
        if !intersectsLineImageBounds(otherLine) {
            return nil
        }
        
        var newLines = [Line](), oldIndex = 0, oldT = 0.0.cf, splitLine = false, leftIndex = 0
        let firstPointInPath = path.contains(otherLine.firstPoint), lastPointInPath = path.contains(otherLine.lastPoint)
        otherLine.allBeziers { b0, i0, stop in
            var bis = [BezierIntersection]()
            if var oldLassoLine = lines.last {
                for lassoLine in lines {
                    let lp = oldLassoLine.lastPoint, fp = lassoLine.firstPoint
                    if lp != fp {
                        bis += b0.intersections(Bezier2.linear(lp, fp))
                    }
                    lassoLine.allBeziers { b1, i1, stop in
                        bis += b0.intersections(b1)
                    }
                    oldLassoLine = lassoLine
                }
            }
            if !bis.isEmpty {
                bis.sort { $0.t < $1.t }
                for bi in bis {
                    let newLeftIndex = leftIndex + (bi.isLeft ? 1 : -1)
                    if firstPointInPath {
                        if leftIndex != 0 && newLeftIndex == 0 {
                            newLines += otherLine.splited(startIndex: oldIndex, startT: oldT, endIndex: i0, endT: bi.t)
                        } else if leftIndex == 0 && newLeftIndex != 0 {
                            oldIndex = i0
                            oldT = bi.t
                        }
                    } else {
                        if leftIndex != 0 && newLeftIndex == 0 {
                            oldIndex = i0
                            oldT = bi.t
                        } else if leftIndex == 0 && newLeftIndex != 0 {
                            newLines += otherLine.splited(startIndex: oldIndex, startT: oldT, endIndex: i0, endT: bi.t)
                        }
                    }
                    leftIndex = newLeftIndex
                }
                splitLine = true
            }
        }
        if splitLine && !lastPointInPath {
            newLines += otherLine.splited(startIndex: oldIndex, startT: oldT, endIndex: otherLine.controls.count <= 2 ? 0 : otherLine.controls.count - 3, endT: 1)
        }
        if !newLines.isEmpty {
            return newLines
        } else if !splitLine && firstPointInPath && lastPointInPath {
            return []
        } else {
            return nil
        }
    }
}

final class Drawing: NSObject, NSCoding, Copying {
    var lines: [Line], roughLines: [Line], selectionLineIndexes: [Int]
    
    init(lines: [Line] = [], roughLines: [Line] = [], selectionLineIndexes: [Int] = []) {
        self.lines = lines
        self.roughLines = roughLines
        self.selectionLineIndexes = selectionLineIndexes
        super.init()
    }
    
    static let dataType = "C0.Drawing.1", linesKey = "0", roughLinesKey = "1", selectionLineIndexesKey = "2"
    init?(coder: NSCoder) {
        lines = coder.decodeObject(forKey: Drawing.linesKey) as? [Line] ?? []
        roughLines = coder.decodeObject(forKey: Drawing.roughLinesKey) as? [Line] ?? []
        selectionLineIndexes = coder.decodeObject(forKey: Drawing.selectionLineIndexesKey) as? [Int] ?? []
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(lines, forKey: Drawing.linesKey)
        coder.encode(roughLines, forKey: Drawing.roughLinesKey)
        coder.encode(selectionLineIndexes, forKey: Drawing.selectionLineIndexesKey)
    }
    
    var deepCopy: Drawing {
        return Drawing(lines: lines, roughLines: roughLines, selectionLineIndexes: selectionLineIndexes)
    }
    
    func imageBounds(withLineWidth lineWidth: CGFloat) -> CGRect {
        return Line.imageBounds(with: lines, lineWidth: lineWidth).unionNotEmpty(Line.imageBounds(with: roughLines, lineWidth: lineWidth))
    }
    var selectionLinesBounds: CGRect {
        if selectionLineIndexes.isEmpty {
            return CGRect()
        } else {
            return selectionLineIndexes.reduce(CGRect()) { $0.unionNotEmpty(lines[$1].imageBounds) }
        }
    }
    var editLinesBounds: CGRect {
        if selectionLineIndexes.isEmpty {
            return lines.reduce(CGRect()) { $0.unionNotEmpty($1.imageBounds) }
        } else {
            return selectionLineIndexes.reduce(CGRect()) { $0.unionNotEmpty(lines[$1].imageBounds) }
        }
    }
    var editLineIndexes: [Int] {
        return selectionLineIndexes.isEmpty ? Array(0 ..< lines.count) : selectionLineIndexes
    }
    var selectionLines: [Line] {
        return selectionLineIndexes.isEmpty ? lines : selectionLineIndexes.map { lines[$0] }
    }
    var unselectionLines: [Line] {
        return selectionLineIndexes.isEmpty ? [] : (0 ..< lines.count)
            .filter { !selectionLineIndexes.contains($0) }
            .map { lines[$0] }
    }
    
    func draw(lineWidth: CGFloat, lineColor: CGColor, in ctx: CGContext) {
        ctx.setFillColor(lineColor)
        for line in lines {
            draw(line, lineWidth: lineWidth, in: ctx)
        }
    }
    func drawRough(lineWidth: CGFloat, lineColor: CGColor, in ctx: CGContext) {
        ctx.setFillColor(lineColor)
        for line in roughLines {
            draw(line, lineWidth: lineWidth, in: ctx)
        }
    }
    func drawSelectionLines(lineWidth: CGFloat, lineColor: CGColor, in ctx: CGContext) {
        ctx.setFillColor(lineColor)
        for lineIndex in selectionLineIndexes {
            draw(lines[lineIndex], lineWidth: lineWidth, in: ctx)
        }
    }
    private func draw(_ line: Line, lineWidth: CGFloat, in ctx: CGContext) {
        line.draw(size: lineWidth, in: ctx)
    }
}
