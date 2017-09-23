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
                line.addPoints(isMove: i == 0, inPath: path)
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
                            newLines.append(otherLine.splited(startIndex: oldIndex, startT: oldT, endIndex: i0, endT: bi.t))
                        } else if leftIndex == 0 && newLeftIndex != 0 {
                            oldIndex = i0
                            oldT = bi.t
                        }
                    } else {
                        if leftIndex != 0 && newLeftIndex == 0 {
                            oldIndex = i0
                            oldT = bi.t
                        } else if leftIndex == 0 && newLeftIndex != 0 {
                            newLines.append(otherLine.splited(startIndex: oldIndex, startT: oldT, endIndex: i0, endT: bi.t))
                        }
                    }
                    leftIndex = newLeftIndex
                }
                splitLine = true
            }
        }
        if splitLine && !lastPointInPath {
            newLines.append(otherLine.splited(startIndex: oldIndex, startT: oldT, endIndex: otherLine.controls.count <= 2 ? 0 : otherLine.controls.count - 3, endT: 1))
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
    
    func imageBounds(with lineWidth: CGFloat) -> CGRect {
        return Line.imageBounds(with: lines, lineWidth: lineWidth).unionNotEmpty(Line.imageBounds(with: roughLines, lineWidth: lineWidth))
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

final class Line: NSObject, NSCoding, Interpolatable {
    struct Control {
        var point: CGPoint = CGPoint(), pressure: CGFloat = 1, weight: CGFloat = 0.5
        func mid(_ other: Control) -> Control {
            return Control(point: point.mid(other.point), pressure: (pressure + other.pressure)/2, weight: (weight + other.weight)/2)
        }
        static func autoPressureControls(with controls: [Control], minPressure: CGFloat = 0.5) -> [Control] {
            func autoPressure(_ t: CGFloat, fprs: CGFloat, lprs: CGFloat) -> CGFloat {
                return 4*((t < 0.5 ? fprs : lprs) - 1)*(t  - 0.5)*(t - 0.5) + 1
            }
            return controls.enumerated().map { i, control in
                let t = i.cf/(controls.count.cf - 1)
                return Control(point: control.point, pressure: autoPressure(t, fprs: minPressure, lprs: minPressure), weight: control.weight)
            }
        }
    }
    let controls: [Control], imageBounds: CGRect
//    private let trigonometrys: [Trigonometry]
    
    static func with(_ bezier: Bezier2) -> Line {
        return Line(controls: [
            Control(point: bezier.p0, pressure: 1, weight: 0.5),
            Control(point: bezier.cp, pressure: 1, weight: 0.5),
            Control(point: bezier.p1, pressure: 1, weight: 0.5)
            ])
    }
    init(controls: [Control]) {
        self.controls = controls
        self.imageBounds = Line.imageBounds(with: controls)
//        self.trigonometrys = Line.trigonometrys(with: controls)
        super.init()
    }
    
    static let dataType = "C0.Line.1", controlsKey = "4", imageBoundsKey = "2"
    init?(coder: NSCoder) {
        controls = coder.decodeStruct(forKey: Line.controlsKey) ?? []
        imageBounds = coder.decodeRect(forKey: Line.imageBoundsKey)
//        trigonometrys = Line.trigonometrys(with: controls)
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeStruct(controls, forKey: Line.controlsKey)
        coder.encode(imageBounds, forKey: Line.imageBoundsKey)
    }
    
    func with(_ controls: [Control]) -> Line {
        return Line(controls: controls)
    }
    func withAppend(_ control: Control) -> Line {
        return Line(controls: controls.withAppend(control))
    }
    func withInsert(_ control: Control, at i: Int) -> Line {
        return Line(controls: controls.withInserted(control, at: i))
    }
    func withRemoveControl(at i: Int) -> Line {
        return Line(controls: controls.withRemoved(at: i))
    }
    func withReplaced(_ control: Control, at i: Int) -> Line {
        return with(controls.withReplaced(control, at: i))
    }
    func applying(_ affine: CGAffineTransform) -> Line {
        return Line(controls: controls.map { Control(point: $0.point.applying(affine), pressure: $0.pressure, weight: $0.weight) })
    }
    func reversed() -> Line {
        return Line(controls: controls.reversed())
    }
    func warpedWith(deltaPoint dp: CGPoint, isFirst: Bool) -> Line {
        var allD = 0.0.cf, oldP = firstPoint
        for i in 1 ..< controls.count {
            let p = controls[i].point
            allD += sqrt(p.squaredDistance(other: oldP))
            oldP = p
        }
        oldP = firstPoint
        let invertAllD = allD > 0 ? 1/allD : 0
        var allAD = 0.0.cf
        return Line(controls: controls.map {
            let p = $0.point
            allAD += sqrt(p.squaredDistance(other: oldP))
            oldP = p
            let t = isFirst ? 1 - allAD*invertAllD : allAD*invertAllD
            return Control(point: CGPoint(x: $0.point.x + dp.x*t, y: $0.point.y + dp.y*t), pressure: $0.pressure, weight: $0.weight)
        })
    }
    func warpedWith(deltaPoint dp: CGPoint, editPoint: CGPoint, minDistance: CGFloat, maxDistance: CGFloat) -> Line {
        return Line(controls: controls.map {
            let d =  hypot2($0.point.x - editPoint.x, $0.point.y - editPoint.y)
            let ds = d > maxDistance ? 0 : (1 - (d - minDistance)/(maxDistance - minDistance))
            return Control(point: CGPoint(x: $0.point.x + dp.x*ds, y: $0.point.y + dp.y*ds), pressure: $0.pressure, weight: $0.weight)
        })
    }
    
    static func linear(_ f0: Line, _ f1: Line, t: CGFloat) -> Line {
        let count = max(f0.controls.count, f1.controls.count)
        return Line(controls: (0 ..< count).map { i in
            let f0c = f0.control(at: i, maxCount: count), f1c = f1.control(at: i, maxCount: count)
            return Control(
                point: CGPoint.linear(f0c.point, f1c.point, t: t),
                pressure: CGFloat.linear(f0c.pressure, f1c.pressure, t: t),
                weight:  CGFloat.linear(f0c.weight, f1c.weight, t: t)
            )
        })
    }
    static func firstMonospline(_ f1: Line, _ f2: Line, _ f3: Line, with msx: MonosplineX) -> Line {
        let count = max(f1.controls.count, f2.controls.count, f3.controls.count)
        return Line(controls: (0 ..< count).map { i in
            let f1c = f1.control(at: i, maxCount: count), f2c = f2.control(at: i, maxCount: count), f3c = f3.control(at: i, maxCount: count)
            return Control(
                point: CGPoint.firstMonospline(f1c.point, f2c.point, f3c.point, with: msx),
                pressure: CGFloat.firstMonospline(f1c.pressure, f2c.pressure, f3c.pressure, with: msx),
                weight:  CGFloat.firstMonospline(f1c.weight, f2c.weight, f3c.weight, with: msx)
            )
        })
    }
    static func monospline(_ f0: Line, _ f1: Line, _ f2: Line, _ f3: Line, with msx: MonosplineX) -> Line {
        let count = max(f0.controls.count, f1.controls.count, f2.controls.count, f3.controls.count)
        return Line(controls: (0 ..< count).map { i in
            let f0c = f0.control(at: i, maxCount: count), f1c = f1.control(at: i, maxCount: count), f2c = f2.control(at: i, maxCount: count), f3c = f3.control(at: i, maxCount: count)
            return Control(
                point: CGPoint.monospline(f0c.point, f1c.point, f2c.point, f3c.point, with: msx),
                pressure: CGFloat.monospline(f0c.pressure, f1c.pressure, f2c.pressure, f3c.pressure, with: msx),
                weight:  CGFloat.monospline(f0c.weight, f1c.weight, f2c.weight, f3c.weight, with: msx)
            )
        })
    }
    static func endMonospline(_ f0: Line, _ f1: Line, _ f2: Line, with msx: MonosplineX) -> Line {
        let count = max(f0.controls.count, f1.controls.count, f2.controls.count)
        return Line(controls: (0 ..< count).map { i in
            let f0c = f0.control(at: i, maxCount: count), f1c = f1.control(at: i, maxCount: count), f2c = f2.control(at: i, maxCount: count)
            return Control(
                point: CGPoint.endMonospline(f0c.point, f1c.point, f2c.point, with: msx),
                pressure: CGFloat.endMonospline(f0c.pressure, f1c.pressure, f2c.pressure, with: msx),
                weight:  CGFloat.endMonospline(f0c.weight, f1c.weight, f2c.weight, with: msx)
            )
        })
    }
    private func control(at i: Int, maxCount: Int) -> Control {
        if controls.count == maxCount {
            return controls[i]
        } else if controls.count < 1 {
            return Control()
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
    
    func splited(atBezierIndex bi: Int, t: CGFloat) -> Line {
        if controls.count < 2 || bi >= controls.count {
            return self
        } else if controls.count == 2 {
            var cs = controls
            cs.insert(controls[0].mid(controls[1]), at: 1)
            return Line(controls: cs)
        } else {
            var cs = controls
            let p0cp0 = bi == 0 ? controls[bi].point : CGPoint.linear(controls[bi].point, controls[bi + 1].point, t: controls[bi].weight)
            let cpp11 = bi + 2 == controls.count - 1 ? controls[bi + 2].point : CGPoint.linear(controls[bi + 1].point, controls[bi + 2].point, t: controls[bi + 1].weight)
            let p0 = CGPoint.linear(p0cp0, controls[bi + 1].point, t: t)
            let p1 = CGPoint.linear(controls[bi + 1].point, cpp11, t: t)
            let pressure = controls[bi + 1].pressure
            let d0  = controls[bi].point.distance(p0), d1 = p1.distance(controls[bi + 2].point)
            let w0 = bi == 0 ? 0.5 : (d0 == 0 ? 0.5 : controls[bi].point.distance(p0cp0)/d0)
            let w1 = bi + 2 == controls.count - 1 ? 0.5 : (d1 == 0 ? 0.5 : p1.distance(cpp11)/d1)
            cs[bi] = Control(point: cs[bi].point, pressure: cs[bi].pressure, weight: w0)
            cs[bi + 1] = Control(point: p0, pressure: pressure, weight: t)
            cs.insert(Control(point: p1, pressure: pressure, weight: w1), at: bi + 2)
            return Line(controls: cs)
        }
    }
    func removedControl(at i: Int, type: PointType) -> Line {
        if type == .first {
            return removedFirst()
        } else if type == .last {
            return removedLast()
        } else {
            return jointed(atBezierIndex: i)
        }
    }
    func removedFirst() -> Line {
        if controls.count <= 2 {
            return self
        } else {
            var cs = controls
            cs.removeFirst()
            cs[0].point = CGPoint.linear(cs[0].point, cs[1].point, t: cs[0].weight)
            cs[0].weight = 0.5
            return Line(controls: cs)
        }
    }
    func removedLast() -> Line {
        if controls.count <= 2 {
            return self
        } else {
            var cs = controls
            cs.removeLast()
            cs[cs.count - 1].point = CGPoint.linear(cs[cs.count - 2].point, cs[cs.count - 1].point, t: cs[cs.count - 2].weight)
            cs[cs.count - 1].weight = 0.5
            return Line(controls: cs)
        }
    }
    func jointed(atBezierIndex bi: Int) -> Line {
        if controls.count <= 2 || bi >= controls.count - 3 {
            return self
        } else if controls.count == 3 {
            var cs = controls
            cs.remove(at: 1)
            return Line(controls: cs)
        } else {
            var cs = controls
            let p0cp0 = bi == 0 ? controls[bi].point : CGPoint.linear(controls[bi].point, controls[bi + 1].point, t: controls[bi].weight)
            let cpp11 = bi + 3 == controls.count - 1 ? controls[bi + 2].point : CGPoint.linear(controls[bi + 2].point, controls[bi + 3].point, t: controls[bi + 2].weight)
            let pressure = (controls[bi + 1].pressure + controls[bi + 2].pressure)/2
            let cp = controls[bi + 1].point.mid(controls[bi + 2].point)
            let d0 = controls[bi].point.distance(cp), d1 = cp.distance(controls[bi + 3].point)
            let w0 = bi == 0 ? 0.5 : (d0 == 0 ? 0.5 : controls[bi].point.distance(p0cp0)/d0)
            let w1 = bi + 3 == controls.count - 1 ? 0.5 : (d1 == 0 ? 0.5 : cp.distance(cpp11)/d1)
            cs.remove(at: bi + 2)
            cs[bi] = Control(point: cs[bi].point, pressure: cs[bi].pressure, weight: w0)
            cs[bi + 1] = Control(point: cp, pressure: pressure, weight: w1)
            return Line(controls: cs)
        }
    }
    func splited(startIndex: Int, endIndex: Int) -> Line {
        return Line(controls: Array(controls[startIndex...endIndex]))
    }
    func splited(startIndex: Int, startT: CGFloat, endIndex: Int, endT: CGFloat) -> Line {
        func pressure(at i: Int, t: CGFloat) -> CGFloat {
            return i  > 0 ? CGFloat.linear(controls[i].pressure, controls[i - 1].pressure, t: t) : controls[i].pressure
        }
        if startIndex == endIndex {
            let b = bezier(at: startIndex).clip(startT: startT, endT: endT)
            let pr0 = startIndex == 0 && startT == 0 ? controls[0].pressure : pressure(at: startIndex + 1, t: startT)
            let pr1 = endIndex == controls.count - 3 && endT == 1 ? controls[controls.count - 1].pressure : pressure(at: endIndex + 1, t: endT)
            return Line(controls: [
                Control(point: b.p0, pressure: pr0, weight: 0.5),
                Control(point: b.cp, pressure: (pr0 + pr1)/2, weight: 0.5),
                Control(point: b.p1, pressure: pr1, weight: 0.5)
                ])
        } else {
            let indexes = startIndex + 1 ..< endIndex + 2
            var cs = Array(controls[indexes])
            let oldFirstControl = cs[0], oldLastControl = cs[cs.count - 2]
            let csFirstL = 1 - oldFirstControl.weight*startT, csLastL = (1 - oldLastControl.weight)*endT + oldLastControl.weight
            cs[0].point = CGPoint.linear(oldFirstControl.point, cs[1].point, t: oldFirstControl.weight*startT)
            cs[0].weight = csFirstL == 0 ? 0.5 : (oldFirstControl.weight - oldFirstControl.weight*startT)/csFirstL
            cs[cs.count - 2].weight = csLastL == 0 ? 0.5 : oldLastControl.weight/csLastL
            cs[cs.count - 1].point = CGPoint.linear(cs[cs.count - 2].point, cs[cs.count - 1].point, t: (1 - oldLastControl.weight)*endT + oldLastControl.weight)
            cs[cs.count - 1].weight = 0.5
            let fc = startIndex == 0 && startT == 0 ? Control(point: controls[0].point, pressure: controls[0].pressure, weight: 0.5) : Control(point: bezier(at: startIndex).position(withT: startT), pressure: pressure(at: startIndex + 1, t: startT), weight: 0.5)
            cs.insert(fc, at: 0)
            let lc = endIndex == controls.count - 3 && endT == 1 ? Control(point: controls[controls.count - 1].point, pressure: controls[controls.count - 1].pressure, weight: 0.5) : Control(point: bezier(at: endIndex).position(withT: endT), pressure: pressure(at: endIndex + 1, t: endT), weight: 0.5)
            cs.append(lc)
            return Line(controls: cs)
        }
    }
    
    var firstPoint: CGPoint {
        return controls[0].point
    }
    var lastPoint: CGPoint {
        return controls[controls.count - 1].point
    }
    private static func imageBounds(with controls: [Control]) -> CGRect {
        if let fc = controls.first, let lc = controls.last {
            if controls.count == 1 {
                return CGRect(origin: fc.point, size: CGSize())
            } else if controls.count == 2 {
                return Bezier2.linear(fc.point, lc.point).bounds
            } else if controls.count == 3 {
                return Bezier2(p0: fc.point, cp: controls[1].point, p1: lc.point).bounds
            } else {
                var weightP = CGPoint.linear(controls[1].point, controls[2].point, t: controls[1].weight)
                var b = Bezier2(p0: controls[0].point, cp: controls[1].point, p1: weightP).bounds
                for i in 1 ..< controls.count - 3 {
                    let newWeightP = CGPoint.linear(controls[i + 1].point, controls[i + 2].point, t: controls[i + 1].weight)
                    b = b.union(Bezier2(p0: weightP, cp: controls[i + 1].point, p1: newWeightP).bounds)
                    weightP = newWeightP
                }
                b = b.union(Bezier2(p0: weightP, cp: controls[controls.count - 2].point, p1: lc.point).bounds)
                return b
            }
        } else {
            return CGRect()
        }
    }
    static func imageBounds(with lines: [Line], lineWidth: CGFloat) -> CGRect {
        if var firstBounds = lines.first?.imageBounds {
            for line in lines {
                firstBounds = firstBounds.union(line.imageBounds)
            }
            return firstBounds.insetBy(dx: -lineWidth/2, dy: -lineWidth/2)
        } else {
            return CGRect()
        }
    }
    func bezier(at i: Int) -> Bezier2 {
        if controls.count < 3 {
            return Bezier2.linear(firstPoint, lastPoint)
        } else if controls.count == 3 {
            return Bezier2(p0: controls[0].point, cp: controls[1].point, p1: controls[2].point)
        } else if i == 0 {
            return Bezier2.firstSpline(controls[0].point, controls[1].point, controls[2].point, p1p2Weight: controls[1].weight)
        } else if i == controls.count - 3 {
            return Bezier2.endSpline(controls[controls.count - 3].point, controls[controls.count - 2].point, controls[controls.count - 1].point, p0p1Weight: controls[controls.count - 3].weight)
        } else {
            return Bezier2.spline(controls[i].point, controls[i + 1].point, controls[i + 2].point, p0p1Weight: controls[i].weight, p1p2Weight: controls[i + 1].weight)
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
    func editPoint(withEditCenterPoint xp: CGPoint, at i: Int) -> CGPoint {
        let m0 = i == 0 ? 0 : controls[i].weight, m1 = i == controls.count - 3 ? 1 : controls[i + 1].weight
        let n0 = 1 - m0, n1 = 1 - m1, p0 = controls[i].point, p2 = controls[i + 2].point
        return (4*xp - n0*p0 - m1*p2)/(m0 + n1 + 2)
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
            let b0 = Bezier2.spline(controls[controls.count - 4].point, controls[controls.count - 3].point, controls[controls.count - 2].point, p0p1Weight: controls[controls.count - 4].weight, p1p2Weight: controls[controls.count - 3].weight)
            let b1 = Bezier2.endSpline(controls[controls.count - 3].point, controls[controls.count - 2].point, controls[controls.count - 1].point, p0p1Weight: controls[controls.count - 3].weight)
            return b0.boundingBox.union(b1.boundingBox)
        }
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
    func isReverse(from other: Line) -> Bool {
        let l0 = other.lastPoint, f1 = firstPoint, l1 = lastPoint
        return hypot2(l1.x - l0.x, l1.y - l0.y) < hypot2(f1.x - l0.x, f1.y - l0.y)
    }
    func editPointDistance(at point :CGPoint) -> CGFloat {
        return controls.reduce(CGFloat.infinity) { min($0, $1.point.distance(point)) }
    }
    func bezierTWith(length: CGFloat) -> (b: Bezier2, t: CGFloat)? {
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
    
    func allBeziers(_ handler: (_ bezier: Bezier2, _ index: Int, _ stop: inout Bool) -> Void) {
        var stop = false
        if controls.count < 3 {
            handler(Bezier2.linear(firstPoint, lastPoint), 0, &stop)
        } else if controls.count == 3 {
            handler(Bezier2(p0: controls[0].point, cp: controls[1].point, p1: controls[2].point), 0, &stop)
        } else {
            var weightP = CGPoint.linear(controls[1].point, controls[2].point, t: controls[1].weight)
            handler(Bezier2(p0: controls[0].point, cp: controls[1].point, p1: weightP), 0, &stop)
            if stop {
                return
            }
            for i in 1 ..< controls.count - 3 {
                let newWeightP = CGPoint.linear(controls[i + 1].point, controls[i + 2].point, t: controls[i + 1].weight)
                handler(Bezier2(p0: weightP, cp: controls[i + 1].point, p1: newWeightP), i, &stop)
                if stop {
                    return
                }
                weightP = newWeightP
            }
            handler(Bezier2(p0: weightP, cp: controls[controls.count - 2].point, p1: controls[controls.count - 1].point), controls.count - 3, &stop)
        }
    }
    func addPoints(isMove: Bool, inPath: CGMutablePath) {
        if let fp = controls.first?.point, let lp = controls.last?.point {
            if isMove {
                inPath.move(to: fp)
            } else {
                inPath.addLine(to: fp)
            }
            if controls.count >= 3 {
                for i in 2 ..< controls.count - 1 {
                    let control = controls[i], oldControl = controls[i - 1]
                    inPath.addQuadCurve(to: CGPoint.linear(oldControl.point, control.point, t: oldControl.weight), control: oldControl.point)
                }
                inPath.addQuadCurve(to: lp, control: controls[controls.count - 2].point)
            } else {
                inPath.addLine(to: lp)
            }
        }
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
            let invertD = 1/hypot(x, y)
            return CGPoint(x: p1.x + x*length*invertD, y: p1.y + y*length*invertD)
        }
    }
    
    func allEditPoints(_ handler: (CGPoint) -> Void) {
        if controls.count > 3 {
            for i in 2 ..< controls.count - 1 {
                handler(CGPoint.linear(controls[i - 1].point, controls[i].point, t: controls[i - 1].weight))
            }
        }
    }
    enum PointType {
        case first, edit, weightEdit, last
    }
    func allPoints(_ handler: (CGPoint, Int, PointType) -> Void) {
        handler(firstPoint, 0, .first)
        if controls.count > 2 {
            allBeziers { bezier, i, stop in
                handler(bezier.position(withT: 0.5), i, .edit)
                if i < controls.count - 3 {
                    handler(bezier.p1, i, .weightEdit)
                }
            }
        }
        handler(lastPoint, controls.count - 1, .last)
    }
    
    func drawEditPoint(_ point: CGPoint, inColor: CGColor, outColor: CGColor, radius: CGFloat, in ctx: CGContext) {
        ctx.setFillColor(inColor)
        ctx.setStrokeColor(outColor)
        ctx.addEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius*2, height: radius*2))
        ctx.drawPath(using: .fillStroke)
    }
    
    static func drawEditPointsWith(lines: [Line], color1: CGColor, color2: CGColor, color3: CGColor, weightColor: CGColor, skinLineWidth: CGFloat = 1.0.cf, skinRadius: CGFloat = 2.0.cf, with di: DrawInfo, in ctx: CGContext) {
        let s = di.invertScale
        let lineWidth = skinLineWidth*s, or = skinRadius*s, mor = skinRadius*s*0.75
        if var oldLine = lines.last {
            for line in lines {
                line.allPoints { p, i, type in
                    switch type {
                    case .edit:
                        p.draw(radius: or, lineWidth: lineWidth, inColor: color3, outColor: color2, in: ctx)
                    case  .weightEdit:
                        p.draw(radius: mor, lineWidth: lineWidth, inColor: weightColor, outColor: color2, in: ctx)
                    default: break
                    }
                }
                let isUnion = oldLine.lastPoint == line.firstPoint
                if isUnion {
                    if oldLine.controls[oldLine.controls.count - 2].point.tangential(oldLine.lastPoint).isEqualAngle(line.firstPoint.tangential(line.controls[1].point)) {
                        line.firstPoint.draw(radius: mor, lineWidth: lineWidth, inColor: color3, outColor: color2, in: ctx)
                    } else {
                        line.firstPoint.draw(radius: or, lineWidth: lineWidth, inColor: color2, outColor: color1, in: ctx)
                    }
                } else {
                    oldLine.lastPoint.draw(radius: mor, lineWidth: lineWidth, inColor: color1, outColor: color2, in: ctx)
                    line.firstPoint.draw(radius: mor, lineWidth: lineWidth, inColor: color1, outColor: color2, in: ctx)
                }
                oldLine = line
            }
        }
    }
    
    func draw(size: CGFloat, in ctx: CGContext) {
        let s = size/2
        if ctx.boundingBoxOfClipPath.intersects(imageBounds.inset(by: -s)) {
            if controls.count == 2 {
                ctx.setLineWidth(1)
                ctx.setStrokeColor(SceneDefaults.strokeLineColor)
                ctx.move(to: controls[0].point)
                ctx.addLine(to: controls[1].point)
                ctx.strokePath()
            } else if controls.count >= 3 {
                ctx.setLineWidth(1)
                ctx.setStrokeColor(SceneDefaults.strokeLineColor)
                ctx.move(to: controls[0].point)
                allBeziers({ (bezier, i, stop) in
                    ctx.addQuadCurve(to: bezier.p1, control: bezier.cp)
//                    let length = bezier.p0.distance(bezier.cp) + bezier.cp.distance(bezier.p1)
//                    if length != 0 {
//                        let splitDeltaT = 1/length
//                    }
                })
                ctx.strokePath()
            }
        }
    }
    
//    private struct PressurePoint {
//        var point: CGPoint, deltaPoint: CGPoint
//        var leftPoint: CGPoint {
//            return point + deltaPoint
//        }
//        var rightPoint: CGPoint {
//            return point - deltaPoint
//        }
//    }
//    private static func pressurePoints(with controls: [Control]) -> [PressurePoint] {
//        if controls.count < 2 {
//            return []
//        } else if controls.count == 2 {
//            
//        } else {
//            func addPressurePointWith(p0: CGPoint, p1: CGPoint, p2: CGPoint, p0p1: CGFloat, p1p2: CGFloat, in ps: inout [PressurePoint]) {
////                let ncp = bezier.p0.mid(bezier.cp).mid(bezier.cp.mid(bezier.p1))
////                let theta0 = bezier.p0.tangential(ncp) + .pi/2, theta1 = ncp.tangential(bezier.p1) + .pi/2
////                trigonometrys.append(Trigonometry(cosTheta0: cos(theta0), sinTheta0: sin(theta0), cosTheta1: cos(theta1), sinTheta1: sin(theta1)))
//                
//                let p0p2 = atan2(p2.y - p0.y, p2.x - p0.x)
//                let theta0 = .pi/2 + (p0p1 + p0p2.loopValue(other: p0p1, begin: -.pi, end: .pi))/2
//                ps.append(PressurePoint(point: p0.mid(p1), deltaPoint: CGPoint(x: cos(theta0), y: sin(theta0))))
//                let theta1 = .pi/2 + (p0p2 + p1p2.loopValue(other: p0p2, begin: -.pi, end: .pi))/2
//                ps.append(PressurePoint(point: p1.mid(p2), deltaPoint: CGPoint(x: cos(theta1), y: sin(theta1))))
//            }
//            let fp = controls[0].point, lp = controls[controls.count - 1].point
//            var ps = [PressurePoint]()
//            ps.reserveCapacity(controls.count)
//            var p1 = controls[1].point, midP0P1 = fp, p0p1 = atan2(p1.y - fp.y, p1.x - fp.x)
//            let fTheta = .pi/2 + p0p1
//            ps.append(PressurePoint(point: fp, deltaPoint: CGPoint(x: cos(fTheta), y: sin(fTheta))))
//            for i in 2 ..< controls.count - 1 {
//                let p2 = controls[i].point
//                let p1p2 = atan2(p2.y - p1.y, p2.x - p1.x), midP1P2 = p1.mid(p2)
//                addPressurePointWith(p0: midP0P1, p1: p1, p2: midP1P2, p0p1: p0p1, p1p2: p1p2, in: &ps)
//                p1 = p2
//                midP0P1 = midP1P2
//                p0p1 = p1p2
//            }
//            let p1p2 = atan2(lp.y - p1.y, lp.x - p1.x)
//            addPressurePointWith(p0: midP0P1, p1: p1, p2: lp, p0p1: p0p1, p1p2: p1p2, in: &ps)
//            let lTheta = .pi/2 + p1p2
//            ps.append(PressurePoint(point: lp, deltaPoint: CGPoint(x: cos(lTheta), y: sin(lTheta))))
//            return ps
//        }
//    }
//    private var ps: [PressurePoint]
//    func draw(size: CGFloat, in ctx: CGContext) {
//        let s = size/2
//        if ctx.boundingBoxOfClipPath.intersects(imageBounds.inset(by: -s)) {
//            if controls.count == 2 {
//                
//            } else if controls.count >= 3 {
//                let firstControl = controls[0], lastControl = controls[controls.count - 1]
//                let firstTheta = controls[1].point.tangential(firstControl.point), lastTheta = controls[controls.count - 2].point.tangential(lastControl.point)
//                ctx.move(to: firstControl.point + ps[0].deltaPoint*(s*firstControl.pressure))
//                var j = 1, connectPoint = firstControl.point
//                for i in 2 ..< controls.count - 1 {
//                    let control = controls[i - 1], nextControl = controls[i]
//                    let pres = s*control.pressure
//                    let newConnectPoint = CGPoint.linear(control.point, nextControl.point, t: control.weight)
//                    let np0cp = control.point.mid(connectPoint) + ps[j].deltaPoint*pres
//                    let ncpp1 = newConnectPoint.mid(control.point) + ps[j + 1].deltaPoint*pres
//                    ctx.addQuadCurve(to: np0cp.mid(ncpp1), control: np0cp)
//                    ctx.addQuadCurve(to: (newConnectPoint.mid(nextControl.point) + ps[j + 2].deltaPoint*s*nextControl.pressure), control: ncpp1)
//                    connectPoint = newConnectPoint
//                    j += 2
//                }
//                let lp = ps[ps.count - 1]
//                ctx.addQuadCurve(to: lastControl.point + ps[ps.count - 1].deltaPoint*lastControl.pressure, control: oldP)
//                ctx.addArc(center: lastControl.point, radius: size*lastControl.pressure, startAngle: lastTheta, endAngle: lastTheta - .pi, clockwise: true)
//                
//                
////                var oldP = ps[0].leftPoint
////                ctx.move(to: oldP)
////                oldP = ps[1].leftPoint
////                for i in 2 ..< ps.count - 1 {
////                    let p = ps[i].leftPoint
////                    ctx.addQuadCurve(to: oldP.mid(p), control: oldP)
////                    oldP = p
////                }
////                let lp = ps[ps.count - 1]
////                ctx.addQuadCurve(to: lp.leftPoint, control: oldP)
////                ctx.addLine(to: lp.rightPoint)
////                
////                oldP = ps[ps.count - 2].rightPoint
////                for i in (1...ps.count - 3).reversed() {
////                    let p = ps[i].rightPoint
////                    ctx.addQuadCurve(to: oldP.mid(p), control: oldP)
////                    oldP = p
////                }
////                ctx.addQuadCurve(to: ps[0].rightPoint, control: oldP)
//            }
//            ctx.fillPath()
//        }
//    }
//    
//    private struct Trigonometry {
//        let cosTheta0: CGFloat, sinTheta0: CGFloat, cosTheta1: CGFloat, sinTheta1: CGFloat, cosTheta2: CGFloat, sinTheta2: CGFloat
//    }
//    private static func trigonometrys(with controls: [Control]) -> [Trigonometry] {
//        if controls.count < 2 {
//            return []
//        } else if controls.count == 2 {
//            let theta = controls[0].point.tangential(controls[1].point) + .pi/2
//            let cosTheta = cos(theta), sinTheta = sin(theta)
//            return [Trigonometry(cosTheta: cos(theta), sinTheta: sin(theta))]
//        } else {
//            var trigonometrys = [Trigonometry]()
//            func addTrigonometry(with bezier: Bezier2) {
//                let ncp = bezier.p0.mid(bezier.cp).mid(bezier.cp.mid(bezier.p1))
//                let theta0 = bezier.p0.tangential(ncp) + .pi/2, theta1 = ncp.tangential(bezier.p1) + .pi/2
//                trigonometrys.append(Trigonometry(cosTheta0: cos(theta0), sinTheta0: sin(theta0), cosTheta1: cos(theta1), sinTheta1: sin(theta1)))
//            }
//            var weightP = CGPoint.linear(controls[1].point, controls[2].point, t: controls[1].weight)
//            addTrigonometry(with: Bezier2(p0: controls[0].point, cp: controls[1].point, p1: weightP))
//            for i in 1 ..< controls.count - 3 {
//                let newWeightP = CGPoint.linear(controls[i + 1].point, controls[i + 2].point, t: controls[i + 1].weight)
//                addTrigonometry(with: Bezier2(p0: weightP, cp: controls[i + 1].point, p1: newWeightP))
//                weightP = newWeightP
//            }
//            addTrigonometry(with: Bezier2(p0: weightP, cp: controls[controls.count - 2].point, p1: controls[controls.count - 1].point))
//            return trigonometrys
//        }
//    }
//    func draw(size: CGFloat, in ctx: CGContext) {
//        let s = size/2
//        if ctx.boundingBoxOfClipPath.intersects(imageBounds.inset(by: -s)) {
//            if controls.count == 2 {
//                let firstControl = controls[0], lastControl = controls[controls.count - 1]
//                let firstTheta = controls[1].point.tangential(firstControl.point), lastTheta = controls[controls.count - 2].point.tangential(lastControl.point)
////                (firstControl.pressure + lastControl.pressure)/2 > 0.5 ?
//                ctx.addArc(center: lastControl.point, radius: size*lastControl.pressure, startAngle: lastTheta, endAngle: lastTheta - .pi, clockwise: true)
//                ctx.addArc(center: firstControl.point, radius: size*firstControl.pressure, startAngle: firstTheta + .pi, endAngle: firstTheta, clockwise: true)
//            } else if controls.count >= 3 {
//                var cs = [(p: CGPoint, cp: CGPoint)]()
//                cs.reserveCapacity((controls.count - 1)*2)
//                func addPoints(with bezier: Bezier2, _ trigonometry: Trigonometry) {
//                    let p0cp = bezier.p0.mid(bezier.cp), cpp1 = bezier.cp.mid(bezier.p1)
//                    let sp0 = CGPoint(x: s*trigonometry.cosTheta0, y: s*trigonometry.sinTheta0)
//                    let sp1 = CGPoint(x: s*trigonometry.cosTheta1, y: s*trigonometry.sinTheta1)
//                    let sp2 = CGPoint(x: s*trigonometry.cosTheta2, y: s*trigonometry.sinTheta2)
//                    let np0cp = p0cp + sp0, ncpp1 = cpp1 + sp1, ncpp2 = bezier.p1 + sp2
//                    ctx.addQuadCurve(to: np0cp.mid(ncpp1), control: np0cp)
//                    ctx.addQuadCurve(to: ncpp2, control: ncpp1)
//                    let np0cpm = p0cp - sp0, ncpp1m = cpp1 - sp1, ncpp2m = bezier.p1 - sp2
//                    cs.append((np0cpm.mid(ncpp1m), np0cpm))
//                    cs.append((ncpp2m, ncpp1m))
//                }
//                ctx.move(to: CGPoint(x: controls[0].point.x + s*controls[0].pressure*trigonometrys[0].cosTheta0, y: controls[0].point.y + s*controls[0].pressure*trigonometrys[0].sinTheta0))
//                var weightP = CGPoint.linear(controls[1].point, controls[2].point, t: controls[1].weight)
//                addPoints(with: Bezier2(p0: controls[0].point, cp: controls[1].point, p1: weightP), trigonometrys[0])
//                for i in 1 ..< controls.count - 3 {
//                    let newWeightP = CGPoint.linear(controls[i + 1].point, controls[i + 2].point, t: controls[i + 1].weight)
//                    addPoints(with: Bezier2(p0: weightP, cp: controls[i + 1].point, p1: newWeightP), trigonometrys[i])
//                    weightP = newWeightP
//                }
//                addPoints(with: Bezier2(p0: weightP, cp: controls[controls.count - 2].point, p1: controls[controls.count - 1].point), trigonometrys[controls.count - 1])
//                
//                let firstControl = controls[0], lastControl = controls[controls.count - 1]
//                let firstTheta = controls[1].point.tangential(firstControl.point), lastTheta = controls[controls.count - 2].point.tangential(lastControl.point)
//                ctx.addArc(center: lastControl.point, radius: size*lastControl.pressure, startAngle: lastTheta, endAngle: lastTheta - .pi, clockwise: true)
//                for c in cs.reversed() {
//                    ctx.addQuadCurve(to: c.p, control: c.cp)
//                }
//                ctx.addArc(center: firstControl.point, radius: size*firstControl.pressure, startAngle: firstTheta + .pi, endAngle: firstTheta, clockwise: true)
//            }
//            ctx.fillPath()
//        }
//    }
    
//    private struct PressurePoint {
//        var point: CGPoint, deltaPoint: CGPoint
//        var leftPoint: CGPoint {
//            return point + deltaPoint
//        }
//        var rightPoint: CGPoint {
//            return point - deltaPoint
//        }
//    }
//    private static func pressurePoints(with controls: [Control]) -> [PressurePoint] {
//        if controls.count <= 2 {
//            return []
//        }
//        let fp = controls[0].point, lp = controls[controls.count - 1].point
//        var ps = [PressurePoint]()
//        ps.reserveCapacity(controls.count)
//        var p1 = controls[1].point, midP0P1 = fp, p0p1 = atan2(p1.y - fp.y, p1.x - fp.x)
//        let fTheta = .pi/2 + p0p1
//        ps.append(PressurePoint(point: fp, deltaPoint: CGPoint(x: cos(fTheta), y: sin(fTheta))))
//        for i in 2 ..< controls.count - 1 {
//            let p2 = controls[i].point
//            let p1p2 = atan2(p2.y - p1.y, p2.x - p1.x), midP1P2 = p1.mid(p2)
//            addPressurePointWith(p0: midP0P1, p1: p1, p2: midP1P2, p0p1: p0p1, p1p2: p1p2, in: &ps)
//            p1 = p2
//            midP0P1 = midP1P2
//            p0p1 = p1p2
//        }
//        let p1p2 = atan2(lp.y - p1.y, lp.x - p1.x)
//        addPressurePointWith(p0: midP0P1, p1: p1, p2: lp, p0p1: p0p1, p1p2: p1p2, in: &ps)
//        let lTheta = .pi/2 + p1p2
//        ps.append(PressurePoint(point: lp, deltaPoint: CGPoint(x: cos(lTheta), y: sin(lTheta))))
//        return ps
//    }
//    private static  func addPressurePointWith(p0: CGPoint, p1: CGPoint, p2: CGPoint, p0p1: CGFloat, p1p2: CGFloat, in ps: inout [PressurePoint]) {
//        let p0p2 = atan2(p2.y - p0.y, p2.x - p0.x)
//        let theta0 = .pi/2 + (p0p1 + p0p2.loopValue(other: p0p1, begin: -.pi, end: .pi))/2
//        ps.append(PressurePoint(point: p0.mid(p1), deltaPoint: CGPoint(x: cos(theta0), y: sin(theta0))))
//        let theta1 = .pi/2 + (p0p2 + p1p2.loopValue(other: p0p2, begin: -.pi, end: .pi))/2
//        ps.append(PressurePoint(point: p1.mid(p2), deltaPoint: CGPoint(x: cos(theta1), y: sin(theta1))))
//    }
//    func draw(size: CGFloat, in ctx: CGContext) {
//        let s = size/2
//        if ctx.boundingBoxOfClipPath.intersects(imageBounds.inset(by: -s)), let fc = controls.first, let lc = controls.last {
//            if controls.count <= 2 {
//                addLinearLinePoints(fp: fc.point, lp: lc.point, fs: s*fc.pressure, ls: s*lc.pressure, in: ctx)
//            } else {
//                var ps = self.ps, j = 1
//                ps[0].deltaPoint = ps[0].deltaPoint*(s*controls[0].pressure)
//                for i in 2 ..< controls.count - 1 {
//                    let ss = s*controls[i - 1].pressure
//                    ps[j].deltaPoint = ps[j].deltaPoint*ss
//                    ps[j + 1].deltaPoint = ps[j + 1].deltaPoint*ss
//                    j += 2
//                }
//                let ls = s*controls[controls.count - 2].pressure
//                ps[ps.count - 3].deltaPoint = ps[ps.count - 3].deltaPoint*ls
//                ps[ps.count - 2].deltaPoint = ps[ps.count - 2].deltaPoint*ls
//                ps[ps.count - 1].deltaPoint = ps[ps.count - 1].deltaPoint*(s*controls[controls.count - 1].pressure)
//                addSplinePoints(ps, in: ctx)
//            }
//            ctx.fillPath()
//        }
//    }
//    private func autoPressure(_ t: CGFloat, fprs: CGFloat, lprs: CGFloat) -> CGFloat {
//        return 4*((t < 0.5 ? fprs : lprs) - 1)*(t  - 0.5)*(t - 0.5) + 1
//    }
//    private func addLinearLinePoints(fp: CGPoint, lp: CGPoint, fs: CGFloat, ls: CGFloat, in ctx: CGContext) {
//        let theta = .pi/2 + atan2(lp.y - fp.y, lp.x - fp.x)
//        let cf = fs*cos(theta), sf = fs*sin(theta), cf2 = ls*cos(theta), sf2 = ls*sin(theta)
//        ctx.move(to: CGPoint(x: fp.x + cf, y: fp.y + sf))
//        ctx.addLine(to: CGPoint(x: lp.x + cf2, y: lp.y + sf2))
//        ctx.addLine(to: CGPoint(x: lp.x - cf2, y: lp.y - sf2))
//        ctx.addLine(to: CGPoint(x: fp.x - cf, y: fp.y - sf))
//    }
//    private func addSplinePoints(_ ps: [PressurePoint], in ctx: CGContext) {
//        var oldP = ps[0].leftPoint
//        ctx.move(to: oldP)
//        oldP = ps[1].leftPoint//FloatPoint.linear(f0: lp1, f1: flp2, t: startT)
//        if ps.count <= 3 {
//            let lp = ps[ps.count - 1]
//            ctx.addQuadCurve(to: lp.leftPoint, control: oldP)
//            ctx.addLine(to: lp.rightPoint)
//            oldP = ps[1].rightPoint
//        } else {
//            for i in 2 ..< ps.count - 1 {
//                let p = ps[i].leftPoint
//                ctx.addQuadCurve(to: oldP.mid(p), control: oldP)
//                oldP = p
//            }
//            let lp = ps[ps.count - 1]
//            ctx.addQuadCurve(to: lp.leftPoint, control: oldP)
//            ctx.addLine(to: lp.rightPoint)
//            oldP = ps[ps.count - 2].rightPoint//FloatPoint.linear(f0: lp0, f1: lp1, t: endT)
//            for i in (1...ps.count - 3).reversed() {
//                let p = ps[i].rightPoint
//                ctx.addQuadCurve(to: oldP.mid(p), control: oldP)
//                oldP = p
//            }
//        }
//        ctx.addQuadCurve(to: ps[0].rightPoint, control: oldP)
//    }
}
