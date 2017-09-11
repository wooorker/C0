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
    
    func draw(lineWidth: CGFloat, lineColor lc: CGColor, in ctx: CGContext) {
        ctx.setFillColor(lc)
        for line in lines {
            drawLine(line, lineWidth: lineWidth, in: ctx)
        }
    }
    func drawRough(lineWidth: CGFloat, lineColor lc: CGColor, in ctx: CGContext) {
        ctx.setFillColor(lc)
        for line in roughLines {
            drawLine(line, lineWidth: lineWidth, in: ctx)
        }
    }
    func drawSelectionLines(lineWidth: CGFloat, lineColor lc: CGColor, in ctx: CGContext) {
        ctx.setFillColor(lc)
        for lineIndex in selectionLineIndexes {
            drawLine(lines[lineIndex], lineWidth: lineWidth, in: ctx)
        }
    }
    private func drawLine(_ line: Line, lineWidth: CGFloat, in ctx: CGContext) {
        if line.pressures.isEmpty {
            line.draw(size: lineWidth, firstPressure: 0, lastPressure: 0, in: ctx)
        } else {
            line.draw(size: lineWidth, in: ctx)
        }
    }
}

final class Line: NSObject, NSCoding, Interpolatable {
    let points: [CGPoint], pressures: [Float], imageBounds: CGRect
    private let ps: [PressurePoint]
    
    static func with(_ bezier: Bezier2) -> Line {
        return Line(points: [bezier.p0, bezier.cp, bezier.p1], pressures: [1, 1, 1])
    }
    
    init(points: [CGPoint] = [CGPoint](), pressures: [Float]) {
        self.points = points
        self.pressures = pressures
        self.imageBounds = Line.imageBounds(with: points)
        self.ps = Line.pressurePoints(with: points)
        super.init()
    }
    private init(points: [CGPoint], pressures: [Float], imageBounds: CGRect, ps: [PressurePoint]) {
        self.points = points
        self.pressures = pressures
        self.imageBounds = imageBounds
        self.ps = ps
        super.init()
    }
    
    static let dataType = "C0.Line.1", pointsKey = "0", pressuresKey = "1", imageBoundsKey = "2"
    init?(coder: NSCoder) {
        points = coder.decodeStruct(forKey: Line.pointsKey) ?? []
        pressures = coder.decodeStruct(forKey: Line.pressuresKey) ?? []
        imageBounds = coder.decodeRect(forKey: Line.imageBoundsKey)
        ps = Line.pressurePoints(with: points)
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeStruct(points, forKey: Line.pointsKey)
        coder.encodeStruct(pressures, forKey: Line.pressuresKey)
        coder.encode(imageBounds, forKey: Line.imageBoundsKey)
    }
    
    func withPoints(_ points: [CGPoint]) -> Line {
        return Line(points: points, pressures: pressures)
    }
    func withPressures(_ pressures: [Float]) -> Line {
        return Line(points: points, pressures: pressures, imageBounds: imageBounds, ps: ps)
    }
    func withAppendPoint(_ point: CGPoint, pressure: Float?) -> Line {
        var points = self.points, pressures = self.pressures
        points.append(point)
        if !pressures.isEmpty, let pre = pressure {
            pressures.append(pre)
        }
        return Line(points: points, pressures: pressures)
    }
    func withInsertPoint(_ point: CGPoint, pressure: Float?, at i: Int) -> Line {
        var points = self.points, pressures = self.pressures
        points.insert(point, at: i)
        if !pressures.isEmpty, let pre = pressure {
            pressures.insert(pre, at: i)
        }
        return Line(points: points, pressures: pressures)
    }
    func withRemovePoint(at i: Int) -> Line {
        var points = self.points, pressures = self.pressures
        points.remove(at: i)
        if !pressures.isEmpty {
            pressures.remove(at: i)
        }
        return Line(points: points, pressures: pressures)
    }
    func withReplacedPoint(_ point : CGPoint, at i: Int) -> Line {
        var points = self.points
        points[i] = point
        return withPoints(points)
    }
    func withReplacedPoint(_ point : CGPoint, pressure: Float, at i: Int) -> Line {
        var points = self.points
        points[i] = point
        var pressures = self.pressures
        if !pressures.isEmpty {
            pressures[i] = pressure
        }
        return Line(points: points, pressures: pressures)
    }
    func transformed(with affine: CGAffineTransform) -> Line {
        let points = self.points.map { $0.applying(affine) }
        return Line(points: points, pressures: pressures)
    }
    func warpedWith(deltaPoint dp: CGPoint, isFirst: Bool) -> Line {
        var allD = 0.0.cf, oldP = firstPoint
        for i in 1 ..< count {
            let p = points[i]
            allD += sqrt(p.squaredDistance(other: oldP))
            oldP = p
        }
        oldP = firstPoint
        let invertAllD = allD > 0 ? 1/allD : 0
        var ps = [CGPoint]()
        var allAD = 0.0.cf
        for i in 0 ..< count {
            let p = points[i]
            allAD += sqrt(p.squaredDistance(other: oldP))
            oldP = p
            let t = isFirst ? 1 - allAD*invertAllD : allAD*invertAllD
            var np = points[i]
            np.x += dp.x*t
            np.y += dp.y*t
            ps.append(np)
        }
        return Line(points: ps, pressures: pressures)
    }
    func warpedWith(deltaPoint dp: CGPoint, editPoint: CGPoint, minDistance: CGFloat, maxDistance: CGFloat) -> Line {
        let ps: [CGPoint] = points.map { p in
            let d =  hypot2(p.x - editPoint.x, p.y - editPoint.y)
            let ds = (1 - (d - minDistance)/(maxDistance - minDistance))
            return CGPoint(x: p.x + dp.x*ds, y: p.y + dp.y*ds)
        }
        return Line(points: ps, pressures: pressures)
    }
    
    static func linear(_ f0: Line, _ f1: Line, t: CGFloat) -> Line {
        let count = max(f0.points.count, f1.points.count)
        let points = (0 ..< count).map { i in
            CGPoint.linear(f0.point(at: i, maxCount: count), f1.point(at: i, maxCount: count), t: t)
        }
        return Line(points: points, pressures: f1.pressures)
    }
    static func firstMonospline(_ f1: Line, _ f2: Line, _ f3: Line, with msx: MonosplineX) -> Line {
        let count = max(f1.points.count, f2.points.count, f3.points.count)
        let points: [CGPoint] = (0 ..< count).map { i in
            let f1i = f1.point(at: i, maxCount: count), f2i = f2.point(at: i, maxCount: count), f3i = f3.point(at: i, maxCount: count)
            return f1i == f2i ? f1i : CGPoint.firstMonospline(f1i, f2i, f3i, with: msx)
        }
        return Line(points: points, pressures: f1.pressures)
    }
    static func monospline(_ f0: Line, _ f1: Line, _ f2: Line, _ f3: Line, with msx: MonosplineX) -> Line {
        let count = max(f0.points.count, f1.points.count, f2.points.count, f3.points.count)
        let points: [CGPoint] = (0 ..< count).map { i in
            let f0i = f0.point(at: i, maxCount: count), f1i = f1.point(at: i, maxCount: count), f2i = f2.point(at: i, maxCount: count), f3i = f3.point(at: i, maxCount: count)
            return f1i == f2i ? f1i : CGPoint.monospline(f0i, f1i, f2i, f3i, with: msx)
        }
        return Line(points: points, pressures: f1.pressures)
    }
    static func endMonospline(_ f0: Line, _ f1: Line, _ f2: Line, with msx: MonosplineX) -> Line {
        let count = max(f0.points.count, f1.points.count, f2.points.count)
        let points: [CGPoint] = (0 ..< count).map { i in
            let f0i = f0.point(at: i, maxCount: count), f1i = f1.point(at: i, maxCount: count), f2i = f2.point(at: i, maxCount: count)
            return f1i == f2i ? f1i : CGPoint.endMonospline(f0i, f1i, f2i, with: msx)
        }
        return Line(points: points, pressures: f1.pressures)
    }
    
    private func point(at i: Int, maxCount: Int) -> CGPoint {
        if points.count == maxCount {
            return points[i]
        } else if points.count < 1 {
            return CGPoint()
        } else {
            let d = maxCount - points.count
            let minD = d/2
            if i < minD {
                return points[0]
            } else if i > maxCount - (d - minD) - 1 {
                return points[points.count - 1]
            } else {
                return points[i - minD]
            }
        }
    }
    func reversed() -> Line {
        return Line(points: points.reversed(), pressures: pressures)
    }
    func splited(startIndex: Int, endIndex: Int) -> Line {
        return Line(points: Array(points[startIndex...endIndex]), pressures: pressures.isEmpty ? [] : Array(pressures[startIndex...endIndex]))
    }
    func splited(startIndex: Int, startT: CGFloat, endIndex: Int, endT: CGFloat) -> Line {
        if startIndex == endIndex {
            let b = bezier(at: startIndex).clip(startT: startT, endT: endT)
            let ps = [b.p0, b.cp, b.p1]
            if !pressures.isEmpty {
                let pr0 = startIndex == 0 && startT == 0 ? pressures[0] : pressure(at: startIndex + 1, t: startT)
                let pr1 = endIndex == count - 3 && endT == 1 ? pressures[pressures.count - 1] : pressure(at: endIndex + 1, t: endT)
                let prs = [pr0, (pr0 + pr1)/2, pr1]
                return Line(points: ps, pressures: prs)
            } else {
                return Line(points: ps, pressures: [])
            }
        } else {
            let indexes = startIndex + 1 ..< endIndex + 2
            var ps = Array(points[indexes])
            if endIndex - startIndex >= 1 && ps.count >= 2 {
                ps[0] = CGPoint.linear(ps[0], ps[1], t: startT*0.5)
                ps[ps.count - 1] = CGPoint.linear(ps[ps.count - 2], ps[ps.count - 1], t: endT*0.5 + 0.5)
            }
            let fp = startIndex == 0 && startT == 0 ? points[0] : bezier(at: startIndex).position(withT: startT)
            ps.insert(fp, at: 0)
            let lp = endIndex == count - 3 && endT == 1 ? points[points.count - 1] : bezier(at: endIndex).position(withT: endT)
            ps.append(lp)
            if !pressures.isEmpty {
                var prs = Array(pressures[indexes])
                let fpre = startIndex == 0 && startT == 0 ? pressures[0] : pressure(at: startIndex + 1, t: startT)
                prs.insert(fpre, at: 0)
                let lpre = endIndex == count - 3 && endT == 1 ? pressures[pressures.count - 1] : pressure(at: endIndex + 1, t: endT)
                prs.append(lpre)
                return Line(points: ps, pressures: prs)
            } else {
                return Line(points: ps, pressures: [])
            }
        }
    }
    var count: Int {
        return points.count
    }
    var firstPoint: CGPoint {
        return points[0]
    }
    var lastPoint: CGPoint {
        return points[points.count - 1]
    }
    func pressurePoint(at index: Int) -> (point: CGPoint, pressure: Float) {
        return (points[index], pressures.isEmpty ? 1 : pressures[index])
    }
    func pressure(at index: Int) -> Float {
        return pressures.isEmpty ? 1 : pressures[index]
    }
    func pressure(at i: Int, t: CGFloat) -> Float {
        return pressures.isEmpty ? 1 : (i  > 0 ? Float.linear(pressures[i], pressures[i - 1], t: t) : pressures[i])
    }
    private static func imageBounds(with points: [CGPoint]) -> CGRect {
        if let fp = points.first, let lp = points.last {
            if points.count == 1 {
                return CGRect(origin: fp, size: CGSize())
            } else if points.count == 2 {
                return Bezier2.linear(fp, lp).bounds
            } else if points.count == 3 {
                return Bezier2(p0: fp, cp: points[1], p1: lp).bounds
            } else {
                var midP = points[1].mid(points[2])
                var b = Bezier2(p0: points[0], cp: points[1], p1: midP).bounds
                for i in 1 ..< points.count - 3 {
                    let newMidP = points[i + 1].mid(points[i + 2])
                    b = b.union(Bezier2(p0: midP, cp: points[i + 1], p1: newMidP).bounds)
                    midP = newMidP
                }
                b = b.union(Bezier2(p0: midP, cp: points[points.count - 2], p1: lp).bounds)
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
        if count < 3 {
            return Bezier2.linear(firstPoint, lastPoint)
        } else if count == 3 {
            return Bezier2(p0: points[0], cp: points[1], p1: points[2])
        } else if i == 0 {
            return Bezier2(p0: points[0], cp: points[1], p1: points[1].mid(points[2]))
        } else if i == count - 3 {
            return Bezier2(p0: points[points.count - 3].mid(points[points.count - 2]), cp: points[points.count - 2], p1: points[points.count - 1])
        } else {
            return Bezier2(p0: points[i].mid(points[i + 1]), cp: points[i + 1], p1: points[i + 1].mid(points[i + 2]))
        }
    }
    func angle(withPreviousLine preLine: Line) -> CGFloat {
        let t1 = preLine.count >= 2 ? preLine.points[preLine.count - 2].tangential(preLine.points[preLine.count - 1])  : 0
        let t2 = count >= 2 ? points[0].tangential(points[1])  : 0
        return abs(t1.differenceRotation(t2))
    }
    var strokeLastBoundingBox: CGRect {
        if count <= 4 {
            return imageBounds
        } else {
            let midP = points[points.count - 3].mid(points[points.count - 2])
            let b0 = Bezier2(p0: points[points.count - 4].mid(points[points.count - 3]), cp: points[points.count - 3], p1: midP)
            let b1 = Bezier2(p0: midP, cp: points[points.count - 2], p1: points[points.count - 1])
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
        let l0 = other.points[other.points.count - 1], f1 = points[0], l1 = points[points.count - 1]
        return hypot2(l1.x - l0.x, l1.y - l0.y) < hypot2(f1.x - l0.x, f1.y - l0.y)
    }
    func editPointDistance(at point :CGPoint) -> CGFloat {
        return points.reduce(CGFloat.infinity) { min($0, $1.distance(point)) }
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
        if var oldPoint = points.first {
            for point in points {
                length += hypot(point.x - oldPoint.x, point.y - oldPoint.y)
                oldPoint = point
            }
        }
        return length
    }
    func allEditPoints(_ handler: (_ point: CGPoint) -> Void) {
        if let fp = points.first, let lp = points.last {
            handler(fp)
            if points.count >= 3 {
                allBeziers { bezier, index, stop in
                    handler(bezier.position(withT: 0.5))
                }
            }
            handler(lp)
        }
    }
    func allEditPoints(_ handler: (_ point: CGPoint, _ index: Int, _ stop: inout Bool) -> Void) {
        if let fp = points.first, let lp = points.last {
            var stop = false
            handler(fp, 0, &stop)
            if stop {
                return
            }
            if points.count >= 3 {
                allBeziers { bezier, index, stop in
                    handler(bezier.position(withT: 0.5), index + 1, &stop)
                }
            }
            handler(lp, points.count - 1,&stop)
            if stop {
                return
            }
        }
    }
    
    func allBeziers(_ handler: (_ bezier: Bezier2, _ index: Int, _ stop: inout Bool) -> Void) {
        var stop = false
        if count < 3 {
            handler(Bezier2.linear(firstPoint, lastPoint), 0, &stop)
        } else if count == 3 {
            handler(Bezier2(p0: points[0], cp: points[1], p1: points[2]), 0, &stop)
        } else {
            var midP = points[1].mid(points[2])
            handler(Bezier2(p0: points[0], cp: points[1], p1: midP), 0, &stop)
            if stop {
                return
            }
            for i in 1 ..< points.count - 3 {
                let newMidP = points[i + 1].mid(points[i + 2])
                handler(Bezier2(p0: midP, cp: points[i + 1], p1: newMidP), i, &stop)
                if stop {
                    return
                }
                midP = newMidP
            }
            handler(Bezier2(p0: midP, cp: points[points.count - 2], p1: points[points.count - 1]), points.count - 3, &stop)
        }
    }
    func addPoints(isMove: Bool, inPath: CGMutablePath) {
        if let fp = points.first, let lp = points.last {
            if isMove {
                inPath.move(to: fp)
            } else {
                inPath.addLine(to: fp)
            }
            if points.count >= 3 {
                var oldP = points[1]
                for i in 2 ..< points.count - 1 {
                    let p = points[i]
                    inPath.addQuadCurve(to: CGPoint(x: (oldP.x + p.x)/2, y: (oldP.y + p.y)/2), control: oldP)
                    oldP = p
                }
                inPath.addQuadCurve(to: lp, control: oldP)
            } else {
                inPath.addLine(to: lp)
            }
        }
    }
    func firstExtensionPoint(withLength length: CGFloat) -> CGPoint {
        return extensionPointWith(p0: points[1], p1: points[0], length: length)
    }
    func lastExtensionPoint(withLength length: CGFloat) -> CGPoint {
        return extensionPointWith(p0: points[points.count - 2], p1: points[points.count - 1], length: length)
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
    
    private struct PressurePoint {
        var point: CGPoint, deltaPoint: CGPoint
        var leftPoint: CGPoint {
            return point + deltaPoint
        }
        var rightPoint: CGPoint {
            return point - deltaPoint
        }
    }
    private static func pressurePoints(with points: [CGPoint]) -> [PressurePoint] {
        if points.count <= 2 {
            return []
        }
        let fp = points[0], lp = points[points.count - 1]
        var ps = [PressurePoint]()
        ps.reserveCapacity(points.count)
        var p1 = points[1], midP0P1 = fp, p0p1 = atan2(p1.y - fp.y, p1.x - fp.x)
        let fTheta = .pi/2 + p0p1
        ps.append(PressurePoint(point: fp, deltaPoint: CGPoint(x: cos(fTheta), y: sin(fTheta))))
        for i in 2 ..< points.count - 1 {
            let p2 = points[i]
            let p1p2 = atan2(p2.y - p1.y, p2.x - p1.x), midP1P2 = p1.mid(p2)
            addPressurePointWith(p0: midP0P1, p1: p1, p2: midP1P2, p0p1: p0p1, p1p2: p1p2, in: &ps)
            p1 = p2
            midP0P1 = midP1P2
            p0p1 = p1p2
        }
        let p1p2 = atan2(lp.y - p1.y, lp.x - p1.x)
        addPressurePointWith(p0: midP0P1, p1: p1, p2: lp, p0p1: p0p1, p1p2: p1p2, in: &ps)
        let lTheta = .pi/2 + p1p2
        ps.append(PressurePoint(point: lp, deltaPoint: CGPoint(x: cos(lTheta), y: sin(lTheta))))
        return ps
    }
    private static  func addPressurePointWith(p0: CGPoint, p1: CGPoint, p2: CGPoint, p0p1: CGFloat, p1p2: CGFloat, in ps: inout [PressurePoint]) {
        let p0p2 = atan2(p2.y - p0.y, p2.x - p0.x)
        let theta0 = .pi/2 + (p0p1 + p0p2.loopValue(other: p0p1, begin: -.pi, end: .pi))/2
        ps.append(PressurePoint(point: p0.mid(p1), deltaPoint: CGPoint(x: cos(theta0), y: sin(theta0))))
        let theta1 = .pi/2 + (p0p2 + p1p2.loopValue(other: p0p2, begin: -.pi, end: .pi))/2
        ps.append(PressurePoint(point: p1.mid(p2), deltaPoint: CGPoint(x: cos(theta1), y: sin(theta1))))
    }
    
    func draw(size: CGFloat, in ctx: CGContext) {
        let s = size/2
        if ctx.boundingBoxOfClipPath.intersects(imageBounds.inset(by: -s)), let fp = points.first, let lp = points.last, !pressures.isEmpty {
            if points.count <= 2 {
                addLinearLinePoints(fp: fp, lp: lp, fs: s*pressures[0].cf, ls: s*pressures[pressures.count - 1].cf, in: ctx)
            } else {
                var ps = self.ps, j = 1
                ps[0].deltaPoint = ps[0].deltaPoint*(s*pressures[0].cf)
                for i in 2 ..< points.count - 1 {
                    let ss = s*pressures[i - 1].cf
                    ps[j].deltaPoint = ps[j].deltaPoint*ss
                    ps[j + 1].deltaPoint = ps[j + 1].deltaPoint*ss
                    j += 2
                }
                let ls = s*pressures[pressures.count - 2].cf
                ps[ps.count - 3].deltaPoint = ps[ps.count - 3].deltaPoint*ls
                ps[ps.count - 2].deltaPoint = ps[ps.count - 2].deltaPoint*ls
                ps[ps.count - 1].deltaPoint = ps[ps.count - 1].deltaPoint*(s*pressures[pressures.count - 1].cf)
                addSplinePoints(ps, in: ctx)
            }
            ctx.fillPath()
        }
    }
    func draw(size: CGFloat, firstPressure fprs: CGFloat, lastPressure lprs: CGFloat, in ctx: CGContext) {
        let s = size/2
        if ctx.boundingBoxOfClipPath.intersects(imageBounds.inset(by: -s)), let fp = points.first, let lp = points.last {
            if points.count <= 2 {
                addLinearLinePoints(fp: fp, lp: lp, fs: s*fprs, ls: s*lprs, in: ctx)
            } else {
                let dt = 1/(points.count - 1).cf
                var ps = self.ps, j = 1
                ps[0].deltaPoint = ps[0].deltaPoint*(s*fprs)
                for i in 2 ..< points.count - 1 {
                    let ss = s*autoPressure(dt*(i - 1).cf, fprs: fprs, lprs: lprs)
                    ps[j].deltaPoint = ps[j].deltaPoint*ss
                    ps[j + 1].deltaPoint = ps[j + 1].deltaPoint*ss
                    j += 2
                }
                let ls = s*autoPressure(dt*(points.count - 2).cf, fprs: fprs, lprs: lprs)
                ps[ps.count - 3].deltaPoint = ps[ps.count - 3].deltaPoint*ls
                ps[ps.count - 2].deltaPoint = ps[ps.count - 2].deltaPoint*ls
                ps[ps.count - 1].deltaPoint = ps[ps.count - 1].deltaPoint*(s*lprs)
                addSplinePoints(ps, in: ctx)
            }
            ctx.fillPath()
        }
    }
    private func autoPressure(_ t: CGFloat, fprs: CGFloat, lprs: CGFloat) -> CGFloat {
        return 4*((t < 0.5 ? fprs : lprs) - 1)*(t  - 0.5)*(t - 0.5) + 1
    }
    private func addLinearLinePoints(fp: CGPoint, lp: CGPoint, fs: CGFloat, ls: CGFloat, in ctx: CGContext) {
        let theta = .pi/2 + atan2(lp.y - fp.y, lp.x - fp.x)
        let cf = fs*cos(theta), sf = fs*sin(theta), cf2 = ls*cos(theta), sf2 = ls*sin(theta)
        ctx.move(to: CGPoint(x: fp.x + cf, y: fp.y + sf))
        ctx.addLine(to: CGPoint(x: lp.x + cf2, y: lp.y + sf2))
        ctx.addLine(to: CGPoint(x: lp.x - cf2, y: lp.y - sf2))
        ctx.addLine(to: CGPoint(x: fp.x - cf, y: fp.y - sf))
    }
    private func addSplinePoints(_ ps: [PressurePoint], in ctx: CGContext) {
        var oldP = ps[0].leftPoint
        ctx.move(to: oldP)
        oldP = ps[1].leftPoint
        if ps.count <= 3 {
            let lp = ps[ps.count - 1]
            ctx.addQuadCurve(to: lp.leftPoint, control: oldP)
            ctx.addLine(to: lp.rightPoint)
            oldP = ps[1].rightPoint
        } else {
            for i in 2 ..< ps.count - 1 {
                let p = ps[i].leftPoint
                ctx.addQuadCurve(to: oldP.mid(p), control: oldP)
                oldP = p
            }
            let lp = ps[ps.count - 1]
            ctx.addQuadCurve(to: lp.leftPoint, control: oldP)
            ctx.addLine(to: lp.rightPoint)
            oldP = ps[ps.count - 2].rightPoint
            for i in (1...ps.count - 3).reversed() {
                let p = ps[i].rightPoint
                ctx.addQuadCurve(to: oldP.mid(p), control: oldP)
                oldP = p
            }
        }
        ctx.addQuadCurve(to: ps[0].rightPoint, control: oldP)
    }
}
