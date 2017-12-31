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

final class Geometry: NSObject, NSCoding {
    static let name = Localization(english: "Geometry", japanese: "ジオメトリ")
    
    let lines: [Line], path: CGPath
    init(lines: [Line] = []) {
        self.lines = lines
        self.path = Line.path(with: lines, length: 0.5)
        super.init()
    }
    
    private static let distance = 6.0.cf, vertexLineLength = 10.0.cf, minSnapRatio = 0.0625.cf
    init(lines: [Line], scale: CGFloat) {
        if let firstLine = lines.first {
            enum FirstEnd {
                case first, end
            }
            var cellLines = [firstLine]
            if lines.count > 1 {
                var oldLines = lines, firstEnds = [FirstEnd.first], oldP = firstLine.lastPoint
                oldLines.removeFirst()
                while !oldLines.isEmpty {
                    var minLine = oldLines[0], minFirstEnd = FirstEnd.first
                    var minIndex = 0, minD = CGFloat.infinity
                    for (i, aLine) in oldLines.enumerated() {
                        let firstP = aLine.firstPoint, lastP = aLine.lastPoint
                        let fds = hypot²(firstP.x - oldP.x, firstP.y - oldP.y)
                        let lds = hypot²(lastP.x - oldP.x, lastP.y - oldP.y)
                        if fds < lds {
                            if fds < minD {
                                minD = fds
                                minLine = aLine
                                minIndex = i
                                minFirstEnd = .first
                            }
                        } else {
                            if lds < minD {
                                minD = lds
                                minLine = aLine
                                minIndex = i
                                minFirstEnd = .end
                            }
                        }
                    }
                    oldLines.remove(at: minIndex)
                    cellLines.append(minLine)
                    firstEnds.append(minFirstEnd)
                    oldP = minFirstEnd == .first ? minLine.lastPoint : minLine.firstPoint
                }
                let count = 10000 / (cellLines.count * cellLines.count)
                for _ in 0 ..< count {
                    var isChanged = false
                    for ai0 in 0 ..< cellLines.count - 1 {
                        for bi0 in ai0 + 1 ..< cellLines.count {
                            let ai1 = ai0 + 1, bi1 = bi0 + 1 < cellLines.count ? bi0 + 1 : 0
                            let a0Line = cellLines[ai0], a0IsFirst = firstEnds[ai0] == .first
                            let a1Line = cellLines[ai1], a1IsFirst = firstEnds[ai1] == .first
                            let b0Line = cellLines[bi0], b0IsFirst = firstEnds[bi0] == .first
                            let b1Line = cellLines[bi1], b1IsFirst = firstEnds[bi1] == .first
                            let a0 = a0IsFirst ? a0Line.lastPoint : a0Line.firstPoint
                            let a1 = a1IsFirst ? a1Line.firstPoint : a1Line.lastPoint
                            let b0 = b0IsFirst ? b0Line.lastPoint : b0Line.firstPoint
                            let b1 = b1IsFirst ? b1Line.firstPoint : b1Line.lastPoint
                            if a0.distance(a1) + b0.distance(b1) > a0.distance(b0) + a1.distance(b1) {
                                cellLines[ai1] = b0Line
                                firstEnds[ai1] = b0IsFirst ? .end : .first
                                cellLines[bi0] = a1Line
                                firstEnds[bi0] = a1IsFirst ? .end : .first
                                isChanged = true
                            }
                        }
                    }
                    if !isChanged {
                        break
                    }
                }
                for (i, line) in cellLines.enumerated() {
                    if firstEnds[i] == .end {
                        cellLines[i] = line.reversed()
                    }
                }
            }
            
            let newLines = Geometry.snapPointLinesWith(lines: cellLines.map { $0.autoPressure() },
                                                       scale: scale) ?? cellLines
            self.lines = newLines
            self.path = Line.path(with: newLines)
        } else {
            self.lines = []
            self.path = CGMutablePath()
        }
    }
    static func snapPointLinesWith(lines: [Line], scale: CGFloat) -> [Line]? {
        guard var oldLine = lines.last else {
            return nil
        }
        let vd = distance * distance / scale
        return lines.map { line in
            let lp = oldLine.lastPoint, fp = line.firstPoint
            let d = lp.distance²(fp)
            let controls: [Line.Control]
            if d < vd * (line.pointsLength / vertexLineLength).clip(min: 0.1, max: 1) {
                let dp = CGPoint(x: fp.x - lp.x, y: fp.y - lp.y)
                var cs = line.controls, dd = 1.0.cf
                for (i, fp) in line.controls.enumerated() {
                    cs[i].point = CGPoint(x: fp.point.x - dp.x * dd, y: fp.point.y - dp.y * dd)
                    dd *= 0.5
                    if dd <= minSnapRatio || i >= line.controls.count - 2 {
                        break
                    }
                }
                controls = cs
            } else {
                controls = line.controls
            }
            oldLine = line
            return Line(controls: controls)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case lines
    }
    init?(coder: NSCoder) {
        lines = coder.decodeDecodable([Line].self, forKey: CodingKeys.lines.rawValue) ?? []
        path = Line.path(with: lines, length: 0.5)
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeEncodable(lines, forKey: CodingKeys.lines.rawValue)
    }
    
    func applying(_ affine: CGAffineTransform) -> Geometry {
        return Geometry(lines: lines.map { $0.applying(affine) })
    }
    func warpedWith(deltaPoint dp: CGPoint, editPoint: CGPoint,
                    minDistance: CGFloat, maxDistance: CGFloat) -> Geometry {
        func warped(p: CGPoint) -> CGPoint {
            let d =  hypot²(p.x - editPoint.x, p.y - editPoint.y)
            let ds = d > maxDistance ? 0 : (1 - (d - minDistance) / (maxDistance - minDistance))
            return CGPoint(x: p.x + dp.x * ds, y: p.y + dp.y * ds)
        }
        let newLines = lines.map { $0.warpedWith(deltaPoint: dp, editPoint: editPoint,
                                                 minDistance: minDistance, maxDistance: maxDistance) }
        return Geometry(lines: newLines)
    }
    
    static func geometriesWithInserLines(with geometries: [Geometry],
                                         lines: [Line], atLinePathIndex pi: Int) -> [Geometry] {
        let i = pi + 1
        return geometries.map {
            if i == $0.lines.count {
                return Geometry(lines: $0.lines + lines)
            } else if i < $0.lines.count {
                return Geometry(lines: Array($0.lines[..<i]) + lines + Array($0.lines[i...]))
            } else {
                return $0
            }
        }
    }
    static func geometriesWithSplitedControl(with geometries: [Geometry],
                                             at i: Int, pointIndex: Int) -> [Geometry] {
        return geometries.map {
            if i < $0.lines.count {
                var lines = $0.lines
                lines[i] = lines[i].splited(at: pointIndex).autoPressure()
                return Geometry(lines: lines)
            } else {
                return $0
            }
        }
    }
    static func geometriesWithRemovedControl(with geometries: [Geometry],
                                             atLineIndex li: Int, index i: Int) -> [Geometry] {
        return geometries.map {
            if li < $0.lines.count {
                var lines = $0.lines
                if lines[li].controls.count == 2 {
                    lines.remove(at: li)
                } else {
                    lines[li] = lines[li].removedControl(at: i).autoPressure()
                }
                return Geometry(lines: lines)
            } else {
                return $0
            }
        }
    }
    static func bezierLineGeometries(with geometries: [Geometry], scale: CGFloat) -> [Geometry] {
        return geometries.map {
            return Geometry(lines: $0.lines.map { $0.bezierLine(withScale: scale) })
        }
    }
    static func geometriesWithSplited(with geometries: [Geometry],
                                      lineSplitIndexes sils: [[Lasso.SplitIndex]?]) -> [Geometry] {
        return geometries.map {
            var lines = [Line]()
            for (i, line) in $0.lines.enumerated() {
                if let sis = sils[i] {
                    var splitLines = [Line]()
                    for si in sis {
                        if si.endIndex < line.controls.count {
                            splitLines += line.splited(startIndex: si.startIndex, startT: si.startT,
                                                       endIndex: si.endIndex, endT: si.endT,
                                                       isMultiLine: false)
                        } else {
                            
                        }
                    }
                    
                } else {
                    lines.append(line)
                }
            }
            return Geometry(lines: lines)
        }
    }
    
    func nearestBezier(with point: CGPoint
        )-> (lineIndex: Int, bezierIndex: Int, t: CGFloat, minDistance²: CGFloat)? {
        
        guard !lines.isEmpty else {
            return nil
        }
        var minD² = CGFloat.infinity, minT = 0.0.cf, minLineIndex = 0, minBezierIndex = 0
        for (li, line) in lines.enumerated() {
            line.allBeziers() { bezier, i, stop in
                let nearest = bezier.nearest(at: point)
                if nearest.distance² < minD² {
                    minT = nearest.t
                    minBezierIndex = i
                    minLineIndex = li
                    minD² = nearest.distance²
                }
            }
        }
        return (minLineIndex, minBezierIndex, minT, minD²)
    }
    func nearestPathLineIndex(at p: CGPoint) -> Int {
        var minD = CGFloat.infinity, minIndex = 0
        for (i, line) in lines.enumerated() {
            let nextLine = lines[i + 1 < lines.count ? i + 1 : 0]
            let d = p.distanceWithLineSegment(ap: line.lastPoint, bp: nextLine.firstPoint)
            if d < minD {
                minD = d
                minIndex = i
            }
        }
        return minIndex
    }
    
    func beziers(with indexes: [Int]) -> [Line] {
        return indexes.map { lines[$0] }
    }
    var isEmpty: Bool {
        return lines.isEmpty
    }
    
    func clip(in ctx: CGContext, handler: () -> Void) {
        guard !path.isEmpty else {
            return
        }
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        handler()
        ctx.restoreGState()
    }
    func addPath(in ctx: CGContext) {
        guard !path.isEmpty else {
            return
        }
        ctx.addPath(path)
    }
    func fillPath(in ctx: CGContext) {
        guard !path.isEmpty else {
            return
        }
        ctx.addPath(path)
        ctx.fillPath()
    }
    func fillPath(with color: Color, _ path: CGPath, in ctx: CGContext) {
        ctx.setFillColor(color.cgColor)
        ctx.addPath(path)
        ctx.fillPath()
    }
    
    func drawLines(withColor color: Color, reciprocalScale: CGFloat, in ctx: CGContext) {
        ctx.setFillColor(color.cgColor)
        draw(withLineWidth: 0.5 * reciprocalScale, in: ctx)
    }
    func drawPathLine(withReciprocalScale reciprocalScale: CGFloat, in ctx: CGContext) {
        ctx.setLineWidth(0.5 * reciprocalScale)
        ctx.setStrokeColor(Color.border.cgColor)
        for (i, line) in lines.enumerated() {
            let nextLine = lines[i + 1 < lines.count ? i + 1 : 0]
            if line.lastPoint != nextLine.firstPoint {
                ctx.move(to: line.lastExtensionPoint(withLength: 0.5))
                ctx.addLine(to: nextLine.firstExtensionPoint(withLength: 0.5))
            }
        }
        ctx.strokePath()
    }
    func drawSkin(lineColor: Color, subColor: Color, backColor: Color = .border,
                  skinLineWidth: CGFloat = 1,
                  reciprocalScale: CGFloat, reciprocalAllScale: CGFloat, in ctx: CGContext) {
        fillPath(with: subColor, path, in: ctx)
        ctx.setFillColor(backColor.cgColor)
        draw(withLineWidth: 1 * reciprocalAllScale, in: ctx)
        ctx.setFillColor(lineColor.cgColor)
        draw(withLineWidth: skinLineWidth * reciprocalScale, in: ctx)
    }
    func draw(withLineWidth lineWidth: CGFloat, in ctx: CGContext) {
        lines.forEach { $0.draw(size: lineWidth, in: ctx) }
    }
}
extension Geometry: Interpolatable {
    static func linear(_ f0: Geometry, _ f1: Geometry, t: CGFloat) -> Geometry {
        if f0 === f1 {
            return f0
        } else if f0.lines.isEmpty {
            return Geometry()
        } else {
            return Geometry(lines: f0.lines.enumerated().map { i, l0 in
                i >= f1.lines.count ? l0 : Line.linear(l0, f1.lines[i], t: t)
            })
        }
    }
    static func firstMonospline(_ f1: Geometry, _ f2: Geometry, _ f3: Geometry,
                                with msx: MonosplineX) -> Geometry {
        if f1 === f2 {
            return f1
        } else if f1.lines.isEmpty {
            return Geometry()
        } else {
            return Geometry(lines: f1.lines.enumerated().map { i, l1 in
                if i >= f2.lines.count {
                    return l1
                } else {
                    let l2 = f2.lines[i]
                    return Line.firstMonospline(l1, l2, i >= f3.lines.count ?
                        l2 : f3.lines[i], with: msx)
                }
            })
        }
    }
    static func monospline(_ f0: Geometry, _ f1: Geometry, _ f2: Geometry, _ f3: Geometry,
                           with msx: MonosplineX) -> Geometry {
        if f1 === f2 {
            return f1
        } else if f1.lines.isEmpty {
            return Geometry()
        } else {
            return Geometry(lines: f1.lines.enumerated().map { i, l1 in
                if i >= f2.lines.count {
                    return l1
                } else {
                    let l2 = f2.lines[i]
                    return Line.monospline(i >= f0.lines.count ? l1 : f0.lines[i],
                                           l1,
                                           l2,
                                           i >= f3.lines.count ? l2 : f3.lines[i],
                                           with: msx)
                }
            })
        }
    }
    static func endMonospline(_ f0: Geometry, _ f1: Geometry, _ f2: Geometry,
                              with msx: MonosplineX) -> Geometry {
        if f1 === f2 {
            return f1
        } else if f1.lines.isEmpty {
            return Geometry()
        } else {
            return Geometry(lines: f1.lines.enumerated().map { i, l1 in
                if i >= f2.lines.count {
                    return l1
                } else {
                    return Line.endMonospline(i >= f0.lines.count ? l1 : f0.lines[i],
                                              l1,
                                              f2.lines[i],
                                              with: msx)
                }
            })
        }
    }
}
