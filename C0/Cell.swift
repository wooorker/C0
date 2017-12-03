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

/*
 # Issue
 セルのアニメーション間移動
 複数セルの重なり判定（複数のセルの上からセルを追加するときにもcontains判定が有効なように修正）
 セルに文字を実装
 文字から口パク生成アクション
 セルの結合
 自動回転補間
 アクションの保存（変形情報などをセルに埋め込む、セルへの操作の履歴を別のセルに適用するコマンド）
*/

import Foundation

final class JoiningCell: NSObject, ClassCopyData, Drawable {
    static let name = Localization(english: "Joining Cell", japanese: "接続セル")
    let cell: Cell
    init(_ cell: Cell) {
        self.cell = cell
        super.init()
    }
    static let cellKey = "0"
    init?(coder: NSCoder) {
        cell = coder.decodeObject(forKey: JoiningCell.cellKey) as? Cell ?? Cell()
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(cell, forKey: JoiningCell.cellKey)
    }
    var deepCopy: JoiningCell {
        return self
    }
    func draw(with bounds: CGRect, in ctx: CGContext) {
        cell.draw(with: bounds, in: ctx)
    }
}

final class Cell: NSObject, ClassCopyData, Drawable {
    static let name = Localization(english: "Cell", japanese: "セル")
    
    var children: [Cell], geometry: Geometry, material: Material, isLocked: Bool, isHidden: Bool, isEditHidden: Bool, id: UUID
    var drawGeometry: Geometry, drawMaterial: Material
    init(
        children: [Cell] = [], geometry: Geometry = Geometry(), material: Material = Material(color: Color.random()),
        isLocked: Bool = false, isHidden: Bool = false, isEditHidden: Bool = false, id: UUID = UUID()
    ) {
        self.children = children
        self.geometry = geometry
        self.material = material
        self.isLocked = isLocked
        self.isHidden = isHidden
        self.isEditHidden = isEditHidden
        self.id = id
        self.drawGeometry = geometry
        self.drawMaterial = material
        super.init()
    }
    
    static let childrenKey = "0", geometryKey = "1", materialKey = "2", isLockedKey = "3", isHiddenKey = "4", isEditHiddenKey = "5", idKey = "6", drawGeometryKey = "7", drawMaterialKey = "8"
    init?(coder: NSCoder) {
        children = coder.decodeObject(forKey: Cell.childrenKey) as? [Cell] ?? []
        geometry = coder.decodeObject(forKey: Cell.geometryKey) as? Geometry ?? Geometry()
        material = coder.decodeObject(forKey: Cell.materialKey) as? Material ?? Material()
        drawGeometry = coder.decodeObject(forKey: Cell.drawGeometryKey) as? Geometry ?? Geometry()
        drawMaterial = coder.decodeObject(forKey: Cell.drawMaterialKey) as? Material ?? Material()
        isLocked = coder.decodeBool(forKey: Cell.isLockedKey)
        isHidden = coder.decodeBool(forKey: Cell.isHiddenKey)
        isEditHidden = coder.decodeBool(forKey: Cell.isEditHiddenKey)
        id = coder.decodeObject(forKey: Cell.idKey) as? UUID ?? UUID()
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(children, forKey: Cell.childrenKey)
        coder.encode(geometry, forKey: Cell.geometryKey)
        coder.encode(material, forKey: Cell.materialKey)
        coder.encode(drawGeometry, forKey: Cell.drawGeometryKey)
        coder.encode(drawMaterial, forKey: Cell.drawMaterialKey)
        coder.encode(isLocked, forKey: Cell.isLockedKey)
        coder.encode(isHidden, forKey: Cell.isHiddenKey)
        coder.encode(isEditHidden, forKey: Cell.isEditHiddenKey)
        coder.encode(id, forKey: Cell.idKey)
    }
    
    var deepCopy: Cell {
        let cell = noResetDeepCopy
        resetCopyedCell()
        return cell
    }
    private weak var deepCopyedCell: Cell?
    var noResetDeepCopy: Cell {
        if let deepCopyedCell = deepCopyedCell {
            return deepCopyedCell
        } else {
            let deepCopyedCell = Cell(
                children: children.map { $0.noResetDeepCopy }, geometry: geometry, material: material,
                isLocked: isLocked, isHidden: isHidden, isEditHidden: isEditHidden, id: id
            )
            self.deepCopyedCell = deepCopyedCell
            return deepCopyedCell
        }
    }
    func resetCopyedCell() {
        deepCopyedCell = nil
        for child in children {
            child.resetCopyedCell()
        }
    }
    
    var lines: [Line] {
        return geometry.lines
    }
    private var path: CGPath {
        return geometry.path
    }
    var isEmpty: Bool {
        for child in children {
            if !child.isEmpty {
                return false
            }
        }
        return geometry.isEmpty
    }
    var isEmptyGeometry: Bool {
        return geometry.isEmpty
    }
    var allImageBounds: CGRect {
        var imageBounds = CGRect()
        allCells { (cell, stop) in
            imageBounds = imageBounds.unionNoEmpty(cell.imageBounds)
        }
        return imageBounds
    }
    var imageBounds: CGRect {
        return path.isEmpty ? CGRect() : path.boundingBoxOfPath.inset(by: -material.lineWidth)
    }
    var isEditable: Bool {
        return !isLocked && !isHidden && !isEditHidden
    }
    
    private var depthFirstSearched = false
    func depthFirstSearch(duplicate: Bool, handler: (_ parent: Cell, _ cell: Cell) -> Void) {
        if duplicate {
            depthFirstSearchDuplicateRecursion(handler)
        } else {
            depthFirstSearchRecursion(handler: handler)
            resetDepthFirstSearch()
        }
    }
    private func depthFirstSearchRecursion(handler: (_ parent: Cell, _ cell: Cell) -> Void) {
        for child in children {
            if !child.depthFirstSearched {
                child.depthFirstSearched = true
                handler(self, child)
                child.depthFirstSearchRecursion(handler: handler)
            }
        }
    }
    private func depthFirstSearchDuplicateRecursion(_ handler: (_ parent: Cell, _ cell: Cell) -> Void) {
        for child in children {
            handler(self, child)
            child.depthFirstSearchDuplicateRecursion(handler)
        }
    }
    private func resetDepthFirstSearch() {
        for child in children {
            if child.depthFirstSearched {
                child.depthFirstSearched = false
                child.resetDepthFirstSearch()
            }
        }
    }
    var allCells: [Cell] {
        var cells = [Cell]()
        depthFirstSearch(duplicate: false) {
            cells.append($1)
        }
        return cells
    }
    func allCells(isReversed: Bool = false, usingLock: Bool = false, handler: (Cell, _ stop: inout Bool) -> Void) {
        var stop = false
        allCellsRecursion(&stop, isReversed: isReversed, usingLock: usingLock, handler: handler)
    }
    private func allCellsRecursion(_ aStop: inout Bool, isReversed: Bool, usingLock: Bool, handler: (Cell, _ stop: inout Bool) -> Void) {
        let children = isReversed ? self.children.reversed() : self.children
        for child in children {
            if usingLock ? child.isEditable : true {
                child.allCellsRecursion(&aStop, isReversed: isReversed, usingLock: usingLock, handler: handler)
                if aStop {
                    return
                }
                handler(child, &aStop)
                if aStop {
                    return
                }
            } else {
                child.allCellsRecursion(&aStop, isReversed: isReversed, usingLock: usingLock, handler: handler)
                if aStop {
                    return
                }
            }
        }
    }
    func parentCells(with cell: Cell) -> [Cell] {
        var parents = [Cell]()
        depthFirstSearch(duplicate: true) { parent, otherCell in
            if cell === otherCell {
                parents.append(otherCell)
            }
        }
        return parents
    }
    func parents(with cell: Cell) -> [(cell: Cell, index: Int)] {
        var parents = [(cell: Cell, index: Int)]()
        depthFirstSearch(duplicate: true) { parent, otherCell in
            if cell === otherCell {
                parents.append((parent, parent.children.index(of: otherCell)!))
            }
        }
        return parents
    }
    
    func at(_ p: CGPoint, reciprocalScale: CGFloat, maxArea: CGFloat = 200.0, maxDistance: CGFloat = 5.0) -> Cell? {
        let scaleMaxArea = reciprocalScale * reciprocalScale * maxArea, scaleMaxDistance = reciprocalScale * maxDistance
        var minD² = CGFloat.infinity, minCell: Cell? = nil, scaleMaxDistance² = scaleMaxDistance * scaleMaxDistance
        func at(_ point: CGPoint, with cell: Cell) -> Cell? {
            if cell.contains(point) || cell.path.isEmpty {
                for child in cell.children.reversed() {
                    if let hitCell = at(point, with: child) {
                        return hitCell
                    }
                }
                return !cell.isLocked && !cell.path.isEmpty && cell.contains(point) ? cell : nil
            } else {
                let area = cell.imageBounds.width * cell.imageBounds.height
                if area < scaleMaxArea && cell.imageBounds.distance²(point) <= scaleMaxDistance² {
                    for (i, line) in cell.lines.enumerated() {
                        let d² = line.minDistance²(at: point)
                        if d² < minD² && d² < scaleMaxDistance² {
                            minD² = d²
                            minCell = cell
                        }
                        let nextLine = cell.lines[i + 1 >= cell.lines.count ? 0 : i + 1]
                        let lld = point.distanceWithLineSegment(ap: line.lastPoint, bp: nextLine.firstPoint)
                        let ld² = lld * lld
                        if ld² < minD² && ld² < scaleMaxDistance² {
                            minD² = ld²
                            minCell = cell
                        }
                    }
                }
            }
            return nil
        }
        let cell = at(p, with: self)
        if let minCell = minCell {
            return minCell
        } else {
            return cell
        }
    }
    func at(_ point: CGPoint) -> Cell? {
        if contains(point) || path.isEmpty {
            for child in children.reversed() {
                if let cell = child.at(point) {
                    return cell
                }
            }
            return !isLocked && !path.isEmpty && contains(point) ? self : nil
        } else {
            return nil
        }
    }
    
    func cells(at point: CGPoint, usingLock: Bool = true) -> [Cell] {
        var cells = [Cell]()
        cellsRecursion(at: point, cells: &cells, usingLock: usingLock)
        return cells
    }
    private func cellsRecursion(at point: CGPoint, cells: inout [Cell], usingLock: Bool = true) {
        if contains(point) || path.isEmpty {
            for child in children.reversed() {
                child.cellsRecursion(at: point, cells: &cells, usingLock: usingLock)
            }
            if (usingLock ? !isLocked : true) && !path.isEmpty && contains(point) && !cells.contains(self) {
                cells.append(self)
            }
        }
    }
    func cells(at line: Line, duplicate: Bool, usingLock: Bool = true) -> [Cell] {
        var cells = [Cell]()
        let fp = line.firstPoint
        allCells(isReversed: true, usingLock: usingLock) { (cell: Cell, stop: inout Bool) in
            if cell.contains(fp) {
                if duplicate || !cells.contains(cell) {
                    cells.append(cell)
                }
                stop = true
            }
        }
        line.allBeziers { b, index, stop2 in
            let nb = b.midSplit()
            allCells(isReversed: true, usingLock: usingLock) { (cell: Cell, stop: inout Bool) in
                if cell.contains(nb.b0.p1) || cell.contains(nb.b1.p1) {
                    if duplicate || !cells.contains(cell) {
                        cells.append(cell)
                    }
                    stop = true
                }
            }
        }
        return cells
    }
    
    func isSnaped(_ other: Cell) -> Bool {
        for line in lines {
            for otherLine in other.lines {
                if line.firstPoint == otherLine.firstPoint ||
                    line.firstPoint == otherLine.lastPoint ||
                    line.lastPoint == otherLine.firstPoint ||
                    line.lastPoint == otherLine.lastPoint {
                    return true
                }
            }
        }
        return false
    }
    
    func maxDistance²(at p: CGPoint) -> CGFloat {
        return Line.maxDistance²(at: p, with: lines)
    }
    
    func contains(_ p: CGPoint) -> Bool {
        return !isHidden && !isEditHidden && (imageBounds.contains(p) ? path.contains(p) : false)
    }
    @nonobjc func contains(_ cell: Cell) -> Bool {
        if !path.isEmpty && !cell.path.isEmpty && isEditable && cell.isEditable && imageBounds.contains(cell.imageBounds) {
            for line in lines {
                for aLine in cell.lines {
                    if line.intersects(aLine) {
                        return false
                    }
                }
            }
            for aLine in cell.lines {
                if !contains(aLine.firstPoint) || !contains(aLine.lastPoint) {
                    return false
                }
            }
            return true
        } else {
            return false
        }
    }
    @nonobjc func contains(_ bounds: CGRect) -> Bool {
        if isEditable && imageBounds.intersects(bounds) {
            let x0y0 = bounds.origin, x1y0 = CGPoint(x: bounds.maxX, y: bounds.minY)
            let x0y1 = CGPoint(x: bounds.minX, y: bounds.maxY), x1y1 = CGPoint(x: bounds.maxX, y: bounds.maxY)
            if contains(x0y0) || contains(x1y0) || contains(x0y1) || contains(x1y1) {
                return true
            }
            return  intersects(bounds)
        } else {
            return false
        }
    }
    
    func intersects(_ cell: Cell, usingLock: Bool = true) -> Bool {
        if !path.isEmpty && !cell.path.isEmpty &&
            (usingLock ? isEditable && cell.isEditable : true) && imageBounds.intersects(cell.imageBounds) {
            for line in lines {
                for aLine in cell.lines {
                    if line.intersects(aLine) {
                        return true
                    }
                }
            }
            for aLine in cell.lines {
                if contains(aLine.firstPoint) || contains(aLine.lastPoint) {
                    return true
                }
            }
            for line in lines {
                if cell.contains(line.firstPoint) || cell.contains(line.lastPoint) {
                    return true
                }
            }
        }
        return false
    }
    func intersects(_ lasso: Lasso) -> Bool {
        if isEditable && imageBounds.intersects(lasso.imageBounds) {
            for line in lines {
                for aLine in lasso.lines {
                    if aLine.intersects(line) {
                        return true
                    }
                }
            }
            for line in lines {
                if lasso.contains(line.firstPoint) || lasso.contains(line.lastPoint) {
                    return true
                }
            }
        }
        return false
    }
    func intersects(_ bounds: CGRect) -> Bool {
        if imageBounds.intersects(bounds) {
            if !path.isEmpty {
                if path.contains(bounds.origin) ||
                    path.contains(CGPoint(x: bounds.maxX, y: bounds.minY)) ||
                    path.contains(CGPoint(x: bounds.minX, y: bounds.maxY)) ||
                    path.contains(CGPoint(x: bounds.maxX, y: bounds.maxY)) {
                    return true
                }
            }
            for line in lines {
                
                if line.intersects(bounds) {
                    return true
                }
            }
        }
        return false
    }
    func intersectsLines(_ bounds: CGRect) -> Bool {
        if imageBounds.intersects(bounds) {
            for line in lines {
                if line.intersects(bounds) {
                    return true
                }
            }
            if intersectsClosePathLines(bounds) {
                return true
            }
        }
        return false
    }
    func intersectsClosePathLines(_ bounds: CGRect) -> Bool {
        if var lp = lines.last?.lastPoint {
            for line in lines {
                let fp = line.firstPoint
                let x0y0 = bounds.origin, x1y0 = CGPoint(x: bounds.maxX, y: bounds.minY)
                let x0y1 = CGPoint(x: bounds.minX, y: bounds.maxY), x1y1 = CGPoint(x: bounds.maxX, y: bounds.maxY)
                if CGPoint.intersection(p0: lp, p1: fp, q0: x0y0, q1: x1y0) ||
                    CGPoint.intersection(p0: lp, p1: fp, q0: x1y0, q1: x1y1) ||
                    CGPoint.intersection(p0: lp, p1: fp, q0: x1y1, q1: x0y1) ||
                    CGPoint.intersection(p0: lp, p1: fp, q0: x0y1, q1: x0y0) {
                    return true
                }
                lp = line.lastPoint
            }
        }
        return false
    }
    func intersectsCells(with bounds: CGRect) -> [Cell] {
        var cells = [Cell]()
        intersectsCellsRecursion(with: bounds, cells: &cells)
        return cells
    }
    private func intersectsCellsRecursion(with bounds: CGRect, cells: inout [Cell]) {
        if contains(bounds) {
            for child in children.reversed() {
                child.intersectsCellsRecursion(with: bounds, cells: &cells)
            }
            if !isLocked && !path.isEmpty && intersects(bounds) && !cells.contains(self) {
                cells.append(self)
            }
        }
    }
    
    func intersection(_ cells: [Cell], isNewID: Bool) -> Cell {
        let newCell = deepCopy
        _ = newCell.intersectionRecursion(cells)
        if isNewID {
            newCell.allCells(handler: { (cell, stop) in
                cell.id = UUID()
            })
        }
        return newCell
    }
    private func intersectionRecursion(_ cells: [Cell]) -> Bool {
        children = children.reduce([Cell]()) {
            $0 + (!$1.intersectionRecursion(cells) ? $1.children : [$1])
        }
        for cell in cells {
            if cell.id == id {
                return true
            }
        }
        return false
    }
    
    func draw(
        isEdit: Bool = false, reciprocalScale: CGFloat, reciprocalAllScale: CGFloat,
        scale: CGFloat, rotation: CGFloat,
        in ctx: CGContext
    ) {
        if !isHidden, !path.isEmpty {
            let isEditUnlock = isEdit && !isLocked
            if material.opacity < 1 {
                ctx.saveGState()
                ctx.setAlpha(material.opacity)
            }
            let color: Color, lineColor: Color
            if isEdit {
                let aColor = material.type == .add || material.type == .luster ? material.color.multiply(alpha: 0.5) : material.color.multiply(white: 0.8)
                let aLineColor = isLocked ? material.lineColor.multiply(white: 0.8) : material.lineColor
                if isEditHidden {
                    color = aColor.multiply(alpha: 0.2)
                    lineColor = aLineColor.multiply(alpha: 0.2)
                } else {
                    color = aColor
                    lineColor = aLineColor
                }
            } else {
                color = material.color
                lineColor = material.lineColor
            }
            if material.type == .normal || material.type == .lineless {
                if children.isEmpty {
                    geometry.fillPath(with: color, path, in: ctx)
                } else {
                    func clipFillPath(color: Color, path: CGPath, in ctx: CGContext, clipping: (Void) -> Void) {
                        ctx.saveGState()
                        ctx.addPath(path)
                        ctx.clip()
                        ctx.beginTransparencyLayer(in: ctx.boundingBoxOfClipPath.intersection(imageBounds), auxiliaryInfo: nil)
                        ctx.setFillColor(color.cgColor)
                        ctx.fill(imageBounds)
                        clipping()
                        ctx.endTransparencyLayer()
                        ctx.restoreGState()
                    }
                    clipFillPath(color: color, path: path, in: ctx) {
                        for child in children {
                            child.draw(
                                isEdit: isEdit, reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalAllScale,
                                scale: scale, rotation: rotation,
                                in: ctx
                            )
                        }
                    }
                }
                if material.type == .normal {
                    ctx.setFillColor(lineColor.cgColor)
                    geometry.draw(withLineWidth: material.lineWidth * reciprocalScale, in: ctx)
                } else if material.lineWidth > Material.defaultLineWidth {
                    func drawStrokePath(path: CGPath, lineWidth: CGFloat, color: Color) {
                        ctx.setLineWidth(lineWidth)
                        ctx.setStrokeColor(color.cgColor)
                        ctx.setLineJoin(.round)
                        ctx.addPath(path)
                        ctx.strokePath()
                    }
                    drawStrokePath(path: path, lineWidth: material.lineWidth, color: color.multiply(alpha: 1 - Double(material.lineStrength)))
                }
            } else {
                ctx.saveGState()
                ctx.setBlendMode(material.type.blendMode)
                ctx.drawBlurWith(
                    color: color, width: material.lineWidth, strength: 1 - material.lineStrength,
                    isLuster: material.type == .luster, path: path,
                    scale: scale, rotation: rotation
                )
                if !children.isEmpty {
                    ctx.addPath(path)
                    ctx.clip()
                    for child in children {
                        child.draw(
                            isEdit: isEdit, reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalAllScale,
                            scale: scale, rotation: rotation,
                            in: ctx
                        )
                    }
                }
                ctx.restoreGState()
            }
            if isEditUnlock {
                ctx.setFillColor(Color.border.cgColor)
                if material.type != .normal {
                    geometry.draw(withLineWidth: 0.5 * reciprocalScale, in: ctx)
                }
                geometry.drawPathLine(withReciprocalScale: reciprocalScale, in: ctx)
            }
            if material.opacity < 1 {
                ctx.restoreGState()
            }
        }
        drawMaterialID(in: ctx)
    }
    
    static func drawCellPaths(cells: [Cell], color: Color, alpha: CGFloat = 0.3, in ctx: CGContext) {
        ctx.setAlpha(alpha)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.setFillColor(color.cgColor)
        for cell in cells {
            if !cell.isHidden {
                cell.geometry.fillPath(in: ctx)
            }
        }
        ctx.endTransparencyLayer()
        ctx.setAlpha(1)
    }
    
    func drawMaterialID(in ctx: CGContext) {
        let mus = material.id.uuidString, cus = material.color.id.uuidString
        let materialString = mus.substring(from: mus.index(mus.endIndex, offsetBy: -6))
        let colorString = cus.substring(from: cus.index(cus.endIndex, offsetBy: -6))
        let textFrame = TextFrame(string: "M: \(materialString)\nC: \(colorString)", font: .division)
        textFrame.drawWithCenterOfImageBounds(in: imageBounds, in: ctx)
    }
    
    func draw(with bounds: CGRect, in ctx: CGContext) {
        var imageBounds = CGRect()
        allCells { cell, stop in
            imageBounds = imageBounds.unionNoEmpty(cell.imageBounds)
        }
        let c = CGAffineTransform.centering(from: imageBounds, to: bounds.inset(by: 3))
        ctx.concatenate(c.affine)
        let scale = 3 * c.scale, rotation = 0.0.cf
        if path.isEmpty {
            children.forEach {
                $0.draw(
                    reciprocalScale: 1 / scale, reciprocalAllScale: 1 / scale,
                    scale: scale, rotation: rotation,
                    in: ctx
                )
            }
        } else {
            draw(
                reciprocalScale: 1 / scale, reciprocalAllScale: 1 / scale,
                scale: scale, rotation: rotation,
                in: ctx
            )
        }
    }
}

final class Geometry: NSObject, NSCoding, Interpolatable {
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
                    var minLine = oldLines[0], minFirstEnd = FirstEnd.first, minIndex = 0, minD = CGFloat.infinity
                    for (i, aLine) in oldLines.enumerated() {
                        let firstP = aLine.firstPoint, lastP = aLine.lastPoint
                        let fds = hypot²(firstP.x - oldP.x, firstP.y - oldP.y), lds = hypot²(lastP.x - oldP.x, lastP.y - oldP.y)
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
                            let a0Line = cellLines[ai0], a0IsFirst = firstEnds[ai0] == .first, a1Line = cellLines[ai1], a1IsFirst = firstEnds[ai1] == .first
                            let b0Line = cellLines[bi0], b0IsFirst = firstEnds[bi0] == .first, b1Line = cellLines[bi1], b1IsFirst = firstEnds[bi1] == .first
                            let a0 = a0IsFirst ? a0Line.lastPoint : a0Line.firstPoint, a1 = a1IsFirst ? a1Line.firstPoint : a1Line.lastPoint
                            let b0 = b0IsFirst ? b0Line.lastPoint : b0Line.firstPoint, b1 = b1IsFirst ? b1Line.firstPoint : b1Line.lastPoint
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
            
            let newLines = Geometry.snapPointLinesWith(lines: cellLines.map { $0.autoPressure() }, scale: scale) ?? cellLines
            self.lines = newLines
            self.path = Line.path(with: newLines)
        } else {
            self.lines = []
            self.path = CGMutablePath()
        }
        super.init()
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
    
    static let linesKey = "5"
    init?(coder: NSCoder) {
        lines = coder.decodeObject(forKey: Geometry.linesKey) as? [Line] ?? []
        path = Line.path(with: lines)
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(lines, forKey: Geometry.linesKey)
    }
    
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
    static func firstMonospline(_ f1: Geometry, _ f2: Geometry, _ f3: Geometry, with msx: MonosplineX) -> Geometry {
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
                    return Line.firstMonospline(l1, l2, i >= f3.lines.count ? l2 : f3.lines[i], with: msx)
                }
            })
        }
    }
    static func monospline(_ f0: Geometry, _ f1: Geometry, _ f2: Geometry, _ f3: Geometry, with msx: MonosplineX) -> Geometry {
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
                    return Line.monospline(i >= f0.lines.count ? l1 : f0.lines[i], l1, l2, i >= f3.lines.count ? l2 : f3.lines[i], with: msx)
                }
            })
        }
    }
    static func endMonospline(_ f0: Geometry, _ f1: Geometry, _ f2: Geometry, with msx: MonosplineX) -> Geometry {
        if f1 === f2 {
            return f1
        } else if f1.lines.isEmpty {
            return Geometry()
        } else {
            return Geometry(lines: f1.lines.enumerated().map { i, l1 in
                if i >= f2.lines.count {
                    return l1
                } else {
                    return Line.endMonospline(i >= f0.lines.count ? l1 : f0.lines[i], l1, f2.lines[i], with: msx)
                }
            })
        }
    }
    
    func applying(_ affine: CGAffineTransform) -> Geometry {
        return Geometry(lines: lines.map { $0.applying(affine) })
    }
    func warpedWith(deltaPoint dp: CGPoint, editPoint: CGPoint, minDistance: CGFloat, maxDistance: CGFloat) -> Geometry {
        func warped(p: CGPoint) -> CGPoint {
            let d =  hypot²(p.x - editPoint.x, p.y - editPoint.y)
            let ds = d > maxDistance ? 0 : (1 - (d - minDistance) / (maxDistance - minDistance))
            return CGPoint(x: p.x + dp.x * ds, y: p.y + dp.y * ds)
        }
        let newLines = lines.map { $0.warpedWith(deltaPoint: dp, editPoint: editPoint, minDistance: minDistance, maxDistance: maxDistance) }
         return Geometry(lines: newLines)
    }
    
    static func geometriesWithInserLines(with geometries: [Geometry], lines: [Line], atLinePathIndex pi: Int) -> [Geometry] {
        let i = pi + 1
        return geometries.map {
            if i == $0.lines.count {
                return Geometry(lines: $0.lines + lines)
            } else if i < $0.lines.count {
                return Geometry(lines: Array($0.lines[0 ..< i]) + lines + Array($0.lines[i ..< $0.lines.count]))
            } else {
                return $0
            }
        }
    }
    static func geometriesWithSplitedControl(with geometries: [Geometry], at i: Int, pointIndex: Int) -> [Geometry] {
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
    static func geometriesWithRemovedControl(with geometries: [Geometry], atLineIndex li: Int, index i: Int) -> [Geometry] {
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
    static func geometriesWithSplited(with geometries: [Geometry], lineSplitIndexes sils: [[Lasso.SplitIndex]?]) -> [Geometry] {
        return geometries.map {
            var lines = [Line]()
            for (i, line) in $0.lines.enumerated() {
                if let sis = sils[i] {
                    var splitLines = [Line]()
                    for si in sis {
                        if si.endIndex < line.controls.count {
                            splitLines += line.splited(startIndex: si.startIndex, startT: si.startT, endIndex: si.endIndex, endT: si.endT, isMultiLine: false)
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
    
    func nearestBezier(with point: CGPoint) -> (lineIndex: Int, bezierIndex: Int, t: CGFloat, minDistance²: CGFloat)? {
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
    
    func clip(in ctx: CGContext, handler: (Void) -> Void) {
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
    func drawSkin(
        lineColor: Color, subColor: Color, backColor: Color = .border, skinLineWidth: CGFloat = 1,
        reciprocalScale: CGFloat, reciprocalAllScale: CGFloat, in ctx: CGContext
        ) {
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
