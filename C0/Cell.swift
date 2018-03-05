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

final class Cell: NSObject, NSCoding, Copying {
    var children: [Cell], geometry: Geometry, material: Material, isLocked: Bool, isHidden: Bool, isEditHidden: Bool, id: UUID
    var indication = false
    private var path: CGPath {
        return geometry.path
    }
    
    init(children: [Cell] = [], geometry: Geometry = Geometry(), material: Material = Material(color: HSLColor.random()),
         isLocked: Bool = false, isHidden: Bool = false, isEditHidden: Bool = false, id: UUID = UUID()) {
        self.children = children
        self.geometry = geometry
        self.material = material
        self.isLocked = isLocked
        self.isHidden = isHidden
        self.isEditHidden = isEditHidden
        self.id = id
        super.init()
    }
    
    static let dataType = "C0.Cell.1", childrenKey = "0", geometryKey = "1", materialKey = "2", isLockedKey = "3", isHiddenKey = "4", isEditHiddenKey = "5", idKey = "6"
    init?(coder: NSCoder) {
        children = coder.decodeObject(forKey: Cell.childrenKey) as? [Cell] ?? []
        geometry = coder.decodeObject(forKey: Cell.geometryKey) as? Geometry ?? Geometry()
        material = coder.decodeObject(forKey: Cell.materialKey) as? Material ?? Material()
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
        coder.encode(isLocked, forKey: Cell.isLockedKey)
        coder.encode(isHidden, forKey: Cell.isHiddenKey)
        coder.encode(isEditHidden, forKey: Cell.isEditHiddenKey)
        coder.encode(id, forKey: Cell.idKey)
    }
    
    var deepCopy: Cell {
        if let deepCopyedCell = deepCopyedCell {
            return deepCopyedCell
        } else {
            let deepCopyedCell = Cell(children: children.map { $0.deepCopy }, geometry: geometry, material: material, isLocked: isLocked, isHidden: isHidden, isEditHidden: isEditHidden, id: id)
            self.deepCopyedCell = deepCopyedCell
            return deepCopyedCell
        }
    }
    private weak var deepCopyedCell: Cell?
    func resetCopyedCell() {
        deepCopyedCell = nil
        for child in children {
            child.resetCopyedCell()
        }
    }
    
    var lines: [Line] {
        return geometry.lines
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
    var imageBounds: CGRect {
        return path.isEmpty ? CGRect() : path.boundingBoxOfPath.inset(by: -material.lineWidth)
    }
    var arowImageBounds: CGRect {
        return imageBounds.inset(by: -arow.width)
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
    
    func atPoint(_ point: CGPoint) -> Cell? {
        if contains(point) || path.isEmpty {
            for child in children.reversed() {
                if let cell = child.atPoint(point) {
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
                if cell.contains(nb.b0.p2) || cell.contains(nb.b1.p2) {
                    if duplicate || !cells.contains(cell) {
                        cells.append(cell)
                    }
                    stop = true
                }
            }
        }
        return cells
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
                for p in aLine.points {
                    if !contains(p) {
                        return false
                    }
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
        if !path.isEmpty && !cell.path.isEmpty && (usingLock ? isEditable && cell.isEditable : true) && imageBounds.intersects(cell.imageBounds) {
            for line in lines {
                for aLine in cell.lines {
                    if line.intersects(aLine) {
                        return true
                    }
                }
            }
            for aLine in cell.lines {
                for p in aLine.points {
                    if contains(p) {
                        return true
                    }
                }
            }
            for line in lines {
                for p in line.points {
                    if cell.contains(p) {
                        return true
                    }
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
    
    func intersection(_ cells: [Cell]) -> Cell {
        let newCell = deepCopy
        _ = newCell.intersectionRecursion(cells)
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
    
    func isLassoCell(_ cell: Cell) -> Bool {
        if isEditable && imageBounds.intersects(cell.imageBounds) {
            for line in lines {
                for aLine in cell.lines {
                    if line.intersects(aLine) {
                        return true
                    }
                }
            }
            for line in lines {
                for p in line.points {
                    if cell.contains(p) {
                        return true
                    }
                }
            }
        }
        return false
    }
    func isLassoLine(_ line: Line) -> Bool {
        if isEditable && imageBounds.intersects(line.imageBounds) {
            for aLine in lines {
                if aLine.intersects(line) {
                    return true
                }
            }
            for p in line.points {
                if contains(p) {
                    return true
                }
            }
        }
        return false
    }
    
    func lassoSplitLine(_ line: Line) -> [Line]? {
        func intersectsLineImageBounds(_ line: Line) -> Bool {
            for aLine in lines {
                if line.imageBounds.intersects(aLine.imageBounds) {
                    return true
                }
            }
            return false
        }
        if !intersectsLineImageBounds(line) {
            return nil
        }
        
        var newLines = [Line](), oldIndex = 0, oldT = 0.0.cf, splitLine = false, leftIndex = 0
        let firstPointInPath = path.contains(line.firstPoint), lastPointInPath = path.contains(line.lastPoint)
        line.allBeziers { b0, i0, stop in
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
                            newLines.append(line.splited(startIndex: oldIndex, startT: oldT, endIndex: i0, endT: bi.t))
                        } else if leftIndex == 0 && newLeftIndex != 0 {
                            oldIndex = i0
                            oldT = bi.t
                        }
                    } else {
                        if leftIndex != 0 && newLeftIndex == 0 {
                            oldIndex = i0
                            oldT = bi.t
                        } else if leftIndex == 0 && newLeftIndex != 0 {
                            newLines.append(line.splited(startIndex: oldIndex, startT: oldT, endIndex: i0, endT: bi.t))
                        }
                    }
                    leftIndex = newLeftIndex
                }
                splitLine = true
            }
        }
        if splitLine && !lastPointInPath {
            newLines.append(line.splited(startIndex: oldIndex, startT: oldT, endIndex: line.count <= 2 ? 0 : line.count - 3, endT: 1))
        }
        if !newLines.isEmpty {
            return newLines
        } else if !splitLine && firstPointInPath && lastPointInPath {
            return []
        } else {
            return nil
        }
    }
    
    func drawEdit(with editMaterial: Material?, _ di: DrawInfo, in ctx: CGContext) {
        if !isHidden, !path.isEmpty {
            if material.opacity < 1 {
                ctx.saveGState()
                ctx.setAlpha(material.opacity)
            }
            if material.color.id == editMaterial?.color.id {
                if material.id == editMaterial?.id {
                    drawStrokePath(path: path, lineWidth: material.lineWidth + 4*di.invertScale, color: SceneDefaults.editMaterialColor, in: ctx)
                } else {
                    drawStrokePath(path: path, lineWidth: material.lineWidth + 2*di.invertScale, color: SceneDefaults.editMaterialColorColor, in: ctx)
                }
            }
            var fillColor = material.fillColor.multiplyWhite(0.5), lineColor = material.lineColor
            if isLocked {
                fillColor = fillColor.multiplyWhite(0.5)
                lineColor = lineColor.multiplyWhite(0.75)
            }
            if isEditHidden {
                fillColor = fillColor.multiplyAlpha(0.25)
                lineColor = lineColor.multiplyAlpha(0.25)
            }
            if material.type == .normal || material.type == .lineless {
                if children.isEmpty {
                    fillPath(color: fillColor, path: path, in: ctx)
                } else {
                    clipFillPath(color: fillColor, path: path, in: ctx) {
                        for child in children {
                            child.drawEdit(with: editMaterial, di, in: ctx)
                        }
                    }
                }
                if material.type == .normal {
                    ctx.setFillColor(lineColor)
                    geometry.draw(withLineWidth: material.lineWidth*di.invertCameraScale, in: ctx)
                    drawPathLine(with: di, in: ctx)
                } else {
                    if material.lineWidth > SceneDefaults.strokeLineWidth {
                        drawStrokePath(path: path, lineWidth: material.lineWidth, color: fillColor.multiplyAlpha(1 - material.lineStrength), in: ctx)
                    }
                    drawStrokeLine(with: di, in: ctx)
                }
            } else {
                fillPath(color: fillColor.multiplyAlpha(0.5), path: path, in: ctx)
                if !children.isEmpty {
                    ctx.addPath(path)
                    ctx.clip()
                    for child in children {
                        child.drawEdit(with: editMaterial, di, in: ctx)
                    }
                }
                drawStrokeLine(with: di, in: ctx)
            }
            if indication {
                ctx.setFillColor(material.type == .normal ? SceneDefaults.cellIndicationNormalColor : SceneDefaults.cellIndicationColor)
                geometry.draw(withLineWidth: 1*di.invertCameraScale, in: ctx)
            }
            if material.opacity < 1 {
                ctx.restoreGState()
            }
        }
    }
    func draw(with di: DrawInfo, in ctx: CGContext) {
        if !isHidden, !path.isEmpty {
            if material.opacity < 1 {
                ctx.saveGState()
                ctx.setAlpha(material.opacity)
            }
            if material.type == .normal || material.type == .lineless {
                if children.isEmpty {
                    fillPath(color: material.fillColor, path: path, in: ctx)
                } else {
                    clipFillPath(color: material.fillColor, path: path, in: ctx) {
                        for child in children {
                            child.draw(with: di, in: ctx)
                        }
                    }
                }
                if material.type == .normal {
                    ctx.setFillColor(material.lineColor)
                    geometry.draw(withLineWidth: material.lineWidth*di.invertCameraScale, in: ctx)
                } else if material.lineWidth > SceneDefaults.strokeLineWidth {
                    drawStrokePath(path: path, lineWidth: material.lineWidth, color: material.fillColor.multiplyAlpha(1 - material.lineStrength), in: ctx)
                }
            } else {
                ctx.saveGState()
                ctx.setBlendMode(material.type.blendMode)
                ctx.drawBlurWith(color: material.fillColor, width: material.lineWidth, strength: 1 - material.lineStrength, isLuster: material.type == .luster, path: path, with: di)
                if !children.isEmpty {
                    ctx.addPath(path)
                    ctx.clip()
                    for child in children {
                        child.draw(with: di, in: ctx)
                    }
                }
                ctx.restoreGState()
            }
            if material.opacity < 1 {
                ctx.restoreGState()
            }
        }
    }
    private func clipFillPath(color: CGColor, path: CGPath, in ctx: CGContext, clipping: () -> Void) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.beginTransparencyLayer(in: ctx.boundingBoxOfClipPath.intersection(imageBounds), auxiliaryInfo: nil)
        ctx.setFillColor(color)
        ctx.fill(imageBounds)
        clipping()
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }
    func clip(in ctx: CGContext, handler: () -> Void) {
        if !path.isEmpty {
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            handler()
            ctx.restoreGState()
        }
    }
    func addPath(in ctx: CGContext) {
        if !path.isEmpty {
            ctx.addPath(path)
        }
    }
    func fillPath(in ctx: CGContext) {
        if !path.isEmpty {
            ctx.addPath(path)
            ctx.fillPath()
        }
    }
    private func fillPath(_ path: CGPath, in ctx: CGContext) {
        if !path.isEmpty {
            ctx.addPath(path)
            ctx.fillPath()
        }
    }
    private func fillPath(color: CGColor, path: CGPath, in ctx: CGContext) {
        ctx.setFillColor(color)
        ctx.addPath(path)
        ctx.fillPath()
    }
    private func drawStrokePath(path: CGPath, lineWidth: CGFloat, color: CGColor, in ctx: CGContext) {
        ctx.setLineWidth(lineWidth)
        ctx.setStrokeColor(color)
        ctx.setLineJoin(.round)
        ctx.addPath(path)
        ctx.strokePath()
    }
    private func drawStrokeLine(with di: DrawInfo, in ctx: CGContext) {
        ctx.setLineWidth(0.5*di.invertScale)
        ctx.setStrokeColor(SceneDefaults.cellBorderColor)
        ctx.addPath(path)
        ctx.strokePath()
    }
    private func drawPathLine(with di: DrawInfo, in ctx: CGContext) {
        ctx.setLineWidth(0.5*di.invertScale)
        ctx.setStrokeColor(SceneDefaults.cellBorderNormalColor)
        for (i, line) in lines.enumerated() {
            let nextLine = lines[i + 1 < lines.count ? i + 1 : 0]
            if line.lastPoint != nextLine.firstPoint {
                ctx.move(to: line.lastExtensionPoint(withLength: 0.5))
                ctx.addLine(to: nextLine.firstExtensionPoint(withLength: 0.5))
            }
        }
        ctx.strokePath()
    }
    func drawGeometry(_ geometry: Geometry, lineColor lc: CGColor, subColor sc: CGColor, with di: DrawInfo, in ctx: CGContext) {
        ctx.setFillColor(lc)
        geometry.draw(withLineWidth: material.lineWidth*di.invertCameraScale, in: ctx)
    }
    func drawRoughSkin(geometry: Geometry, lineColor lc: CGColor, fillColor sc: CGColor, lineWidth: CGFloat, with di: DrawInfo, in ctx: CGContext) {
        ctx.setFillColor(sc)
        fillPath(geometry.path, in: ctx)
        ctx.setFillColor(lc)
        geometry.draw(withLineWidth: lineWidth*di.invertCameraScale, in: ctx)
    }
    func drawRoughSkin(lineColor lc: CGColor, fillColor sc: CGColor, lineWidth: CGFloat, with di: DrawInfo, in ctx: CGContext) {
        if !path.isEmpty {
            fillPath(color: sc, path: path, in: ctx)
        }
        ctx.setFillColor(lc)
        geometry.draw(withLineWidth: lineWidth*di.invertCameraScale, in: ctx)
    }
    static func drawCellPaths(cells: [Cell], color: CGColor, alpha: CGFloat = 0.4, in ctx: CGContext) {
        ctx.setAlpha(alpha)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.setFillColor(color)
        for cell in cells {
            if !cell.isHidden {
                cell.fillPath(in: ctx)
            }
        }
        ctx.endTransparencyLayer()
        ctx.setAlpha(1)
    }
    private func drawMaterialID(in ctx: CGContext) {
        let mus = material.id.uuidString, cus = material.color.id.uuidString
        let materialString = mus.substring(from: mus.index(mus.endIndex, offsetBy: -4))
        let colorString = cus.substring(from: cus.index(cus.endIndex, offsetBy: -4))
        TextLine(string: "\(materialString), C: \(colorString)", isHorizontalCenter: true, isVerticalCenter: true).draw(in: imageBounds, in: ctx)
    }
    
    private struct Arow {
        let width = 6.0.cf, length = 20.0.cf, minRatioOfLine = 0.4.cf, secondPadding = 6.0.cf, lineWidth = 1.0.cf
    }
    private let arow = Arow(), skinRadius = 3.0.cf
    func drawSkin(lineColor c: CGColor, subColor sc: CGColor, opacity: CGFloat, geometry: Geometry, isDrawArow: Bool = true, with di: DrawInfo, in ctx: CGContext) {
        let lines = geometry.lines
        if let firstLine = lines.first {
            ctx.saveGState()
            ctx.setAlpha(opacity)
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            fillPath(color: sc, path: geometry == self.geometry ? path : geometry.path, in: ctx)
            let backColor = SceneDefaults.selectionSkinLineColor, s = di.invertScale, lineWidth = 1*di.invertCameraScale
            ctx.setFillColor(backColor)
            geometry.draw(withLineWidth: lineWidth + 1*di.invertCameraScale, in: ctx)
            ctx.setFillColor(c)
            geometry.draw(withLineWidth: 1.5*di.invertScale, in: ctx)
            ctx.setLineWidth(arow.lineWidth*s)
            ctx.setStrokeColor(backColor)
            let or = skinRadius*s, mor = skinRadius*s*0.75
            if var oldP = lines.last?.lastPoint {
                for line in lines {
                    let fp = line.firstPoint, lp = line.lastPoint, isUnion = oldP == fp
                    if isUnion {
                        ctx.setFillColor(backColor)
                        ctx.setStrokeColor(c)
                        ctx.addEllipse(in: CGRect(x: fp.x - or, y: fp.y - or, width: or*2, height: or*2))
                        ctx.drawPath(using: .fillStroke)
                    } else {
                        ctx.setFillColor(c)
                        ctx.setStrokeColor(backColor)
                        ctx.addEllipse(in: CGRect(x: oldP.x - mor, y: oldP.y - mor, width: mor*2, height: mor*2))
                        ctx.addEllipse(in: CGRect(x: fp.x - mor, y: fp.y - mor, width: mor*2, height: mor*2))
                        ctx.drawPath(using: .fillStroke)
                    }
                    oldP = lp
                }
            }
            if isDrawArow {
                func drawArow(b: Bezier2, t: CGFloat, lineWidth: CGFloat, color: CGColor) {
                    let aw = arow.width*s, bp = b.position(withT: t), theta = b.tangential(withT: t) - .pi, arowTheta = .pi/4.0.cf
                    ctx.setLineWidth(lineWidth)
                    ctx.setStrokeColor(color)
                    ctx.addLines(between: [CGPoint(x: bp.x + aw*cos(theta + arowTheta), y: bp.y + aw*sin(theta + arowTheta)), CGPoint(x: bp.x, y: bp.y), CGPoint(x: bp.x + aw*cos(theta - arowTheta), y: bp.y + aw*sin(theta - arowTheta))])
                    ctx.strokePath()
                }
                func drawArow(b: Bezier2, t: CGFloat) {
                    drawArow(b: b, t: t, lineWidth: 2*(arow.lineWidth + 0.5)*s, color: backColor)
                    drawArow(b: b, t: t, lineWidth: (arow.lineWidth + 0.5)*s, color: c)
                }
                let length = firstLine.pointsLength
                let l = min(arow.length, length*arow.minRatioOfLine)
                if let bs = firstLine.bezierTWith(length: l) {
                    drawArow(b: bs.b, t: bs.t)
                    let secondL = l + arow.secondPadding*s
                    if secondL < length*(1 - arow.minRatioOfLine), let bs = firstLine.bezierTWith(length: secondL) {
                        drawArow(b: bs.b, t: bs.t)
                    }
                } else {
                    drawArow(b: firstLine.bezier(at: 0), t: arow.minRatioOfLine)
                }
            }
            ctx.endTransparencyLayer()
            ctx.restoreGState()
        }
    }
}

final class Geometry: NSObject, NSCoding, Interpolatable {
    let lines: [Line]
    let path: CGPath
    
    init(lines: [Line] = []) {
        self.lines = lines
        self.path = Geometry.path(with: lines)
        super.init()
    }
    
    static let dataType = "C0.Geometry.1", linesKey = "0"
    init?(coder: NSCoder) {
        lines = coder.decodeObject(forKey: Geometry.linesKey) as? [Line] ?? []
        self.path = Geometry.path(with: lines)
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
    
    func lines(with indexes: [Int]) -> [Line] {
        return indexes.map { lines[$0] }
    }
    var isEmpty: Bool {
        return lines.isEmpty
    }
    static func path(with lines: [Line]) -> CGPath {
        if !lines.isEmpty {
            let path = CGMutablePath()
            for (i, line) in lines.enumerated() {
                line.addPoints(isMove: i == 0, inPath: path)
                let nextLine = lines[i + 1 < lines.count ? i + 1 : 0]
                if line.lastPoint != nextLine.firstPoint {
                    path.addLine(to: line.lastExtensionPoint(withLength: 0.5))
                    path.addLine(to: nextLine.firstExtensionPoint(withLength: 0.5))
                }
            }
            path.closeSubpath()
            return path
        } else {
            return CGMutablePath()
        }
    }
    
    private static let distance = 6.0.cf, vertexLineLength = 10.0.cf, minSnapRatio = 0.0625.cf
    static func snapLinesWith(lines: [Line], scale: CGFloat) -> [Line] {
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
                        let fds = hypot2(firstP.x - oldP.x, firstP.y - oldP.y), lds = hypot2(lastP.x - oldP.x, lastP.y - oldP.y)
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
                let count = 10000/(cellLines.count*cellLines.count)
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
            return snapPointLinesWith(lines: cellLines, scale: scale) ?? cellLines
        } else {
            return []
        }
    }
    private static func snapPointLinesWith(lines: [Line], scale: CGFloat) -> [Line]? {
        guard var oldLine = lines.last else {
            return nil
        }
        let vd = distance*distance/scale
        return lines.map { line in
            let lp = oldLine.lastPoint, fp = line.firstPoint
            let d = lp.squaredDistance(other: fp)
            var points: [CGPoint]
            if d < vd*(line.pointsLength/vertexLineLength).clip(min: 0.1, max: 1) {
                let dp = CGPoint(x: fp.x - lp.x, y: fp.y - lp.y)
                var ps = line.points, dd = 1.0.cf
                for (i, fp) in line.points.enumerated() {
                    ps[i] = CGPoint(x: fp.x - dp.x*dd, y: fp.y - dp.y*dd)
                    dd *= 0.5
                    if dd <= minSnapRatio || i >= line.points.count - 2 {
                        break
                    }
                }
                points = ps
            } else {
                points = line.points
            }
            oldLine = line
            return Line(points: points, pressures: [])
        }
    }
    
    func draw(withLineWidth lw: CGFloat, minPressure: CGFloat = 0.4.cf, in ctx: CGContext) {
        if let oldLine = lines.last, let firstLine = lines.first {
            let lp = oldLine.lastPoint, fp = firstLine.firstPoint, invertPi = 1.0.cf/(.pi)
            var firstPressure = lp != fp ? minPressure : 1 - firstLine.angle(withPreviousLine: oldLine)*invertPi
            for (i, line) in lines.enumerated() {
                let nextLine = lines[i + 1 < lines.count ? i + 1 : 0]
                let lp = line.lastPoint, fp = nextLine.firstPoint
                let lastPressure = lp != fp ? minPressure : 1 - nextLine.angle(withPreviousLine: line)*invertPi
                line.draw(size: lw, firstPressure: firstPressure, lastPressure: lastPressure, in: ctx)
                if lp == fp {
                    let r = lw*lastPressure/2
                    ctx.fillEllipse(in: CGRect(x: fp.x - r, y: fp.y - r, width: r*2, height: r*2))
                }
                firstPressure = lastPressure
            }
        }
    }
}

final class Material: NSObject, NSCoding, Interpolatable {
    enum MaterialType: Int8, ByteCoding {
        case normal, lineless, blur, luster, glow, screen, multiply
        var isDrawLine: Bool {
            return self == .normal
        }
        var blendMode: CGBlendMode {
            switch self {
            case .normal, .lineless, .blur:
                return .normal
            case .luster, .glow:
                return .plusLighter
            case .screen:
                return .screen
            case .multiply:
                return .multiply
            }
        }
    }
    let color: HSLColor, type: MaterialType, lineWidth: CGFloat, lineStrength: CGFloat, opacity: CGFloat, id: UUID, fillColor: CGColor, lineColor: CGColor
    init(color: HSLColor = HSLColor(), type: MaterialType = MaterialType.normal, lineWidth: CGFloat = SceneDefaults.strokeLineWidth, lineStrength: CGFloat = 0, opacity: CGFloat = 1) {
        self.color = color
        self.type = type
        self.lineWidth = lineWidth
        self.lineStrength = lineStrength
        self.opacity = opacity
        self.id = UUID()
        self.fillColor = color.nsColor.cgColor
        self.lineColor = Material.lineColorWith(color: color, lineStrength: lineStrength)
        super.init()
    }
    private init(color: HSLColor = HSLColor(), type: MaterialType = MaterialType.normal, lineWidth: CGFloat = SceneDefaults.strokeLineWidth, lineStrength: CGFloat = 0, opacity: CGFloat = 1, id: UUID = UUID(), fillColor: CGColor) {
        self.color = color
        self.type = type
        self.lineWidth = lineWidth
        self.lineStrength = lineStrength
        self.opacity = opacity
        self.id = id
        self.fillColor = fillColor
        self.lineColor = Material.lineColorWith(color: color, lineStrength: lineStrength)
        super.init()
    }
    private init(color: HSLColor = HSLColor(), type: MaterialType = MaterialType.normal, lineWidth: CGFloat = SceneDefaults.strokeLineWidth, lineStrength: CGFloat = 0, opacity: CGFloat = 1, id: UUID = UUID(), fillColor: CGColor, lineColor: CGColor) {
        self.color = color
        self.type = type
        self.lineWidth = lineWidth
        self.lineStrength = lineStrength
        self.opacity = opacity
        self.id = id
        self.fillColor = fillColor
        self.lineColor = lineColor
        super.init()
    }
    
    static let dataType = "C0.Material.1", colorKey = "0", typeKey = "1", lineWidthKey = "2", lineStrengthKey = "3", opacityKey = "4", idKey = "5"
    init?(coder: NSCoder) {
        color = coder.decodeStruct(forKey: Material.colorKey) ?? HSLColor()
        type = coder.decodeStruct(forKey: Material.typeKey) ?? .normal
        lineWidth = coder.decodeDouble(forKey: Material.lineWidthKey).cf
        lineStrength = coder.decodeDouble(forKey: Material.lineStrengthKey).cf
        opacity = coder.decodeDouble(forKey: Material.opacityKey).cf
        id = coder.decodeObject(forKey: Material.idKey) as? UUID ?? UUID()
        fillColor = color.nsColor.cgColor
        lineColor = Material.lineColorWith(color: color, lineStrength: lineStrength)
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeStruct(color, forKey: Material.colorKey)
        coder.encodeStruct(type, forKey: Material.typeKey)
        coder.encode(lineWidth.d, forKey: Material.lineWidthKey)
        coder.encode(lineStrength.d, forKey: Material.lineStrengthKey)
        coder.encode(opacity.d, forKey: Material.opacityKey)
        coder.encode(id, forKey: Material.idKey)
    }
    
    static func lineColorWith(color: HSLColor, lineStrength: CGFloat) -> CGColor {
        return lineStrength == 0 ? HSLColor().nsColor.cgColor : color.withLightness(CGFloat.linear(0, color.lightness, t: lineStrength)).nsColor.cgColor
    }
    func withNewID() -> Material {
        return Material(color: color, type: type, lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity, id: UUID(), fillColor: fillColor, lineColor: lineColor)
    }
    func withColor(_ color: HSLColor) -> Material {
        return Material(color: color, type: type, lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity)
    }
    func withType(_ type: MaterialType) -> Material {
        return Material(color: color, type: type, lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity, id: UUID(), fillColor: fillColor, lineColor: lineColor)
    }
    func withLineWidth(_ lineWidth: CGFloat) -> Material {
        return Material(color: color, type: type, lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity, id: UUID(), fillColor: fillColor, lineColor: lineColor)
    }
    func withLineStrength(_ lineStrength: CGFloat) -> Material {
        return Material(color: color, type: type, lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity, id: UUID(), fillColor: fillColor)
    }
    func withOpacity(_ opacity: CGFloat) -> Material {
        return Material(color: color, type: type, lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity, id: UUID(), fillColor: fillColor)
    }
    
    static func linear(_ f0: Material, _ f1: Material, t: CGFloat) -> Material {
        let color = HSLColor.linear(f0.color, f1.color, t: t)
        let type = f0.type
        let lineWidth = CGFloat.linear(f0.lineWidth, f1.lineWidth, t: t)
        let lineStrength = CGFloat.linear(f0.lineStrength, f1.lineStrength, t: t)
        let opacity = CGFloat.linear(f0.opacity, f1.opacity, t: t)
        return Material(color: color, type: type, lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity)
    }
    static func firstMonospline(_ f1: Material, _ f2: Material, _ f3: Material, with msx: MonosplineX) -> Material {
        let color = HSLColor.firstMonospline(f1.color, f2.color, f3.color, with: msx)
        let type = f1.type
        let lineWidth = CGFloat.firstMonospline(f1.lineWidth, f2.lineWidth, f3.lineWidth, with: msx)
        let lineStrength = CGFloat.firstMonospline(f1.lineStrength, f2.lineStrength, f3.lineStrength, with: msx)
        let opacity = CGFloat.firstMonospline(f1.opacity, f2.opacity, f3.opacity, with: msx)
        return Material(color: color, type: type, lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity)
    }
    static func monospline(_ f0: Material, _ f1: Material, _ f2: Material, _ f3: Material, with msx: MonosplineX) -> Material {
        let color = HSLColor.monospline(f0.color, f1.color, f2.color, f3.color, with: msx)
        let type = f1.type
        let lineWidth = CGFloat.monospline(f0.lineWidth, f1.lineWidth, f2.lineWidth, f3.lineWidth, with: msx)
        let lineStrength = CGFloat.monospline(f0.lineStrength, f1.lineStrength, f2.lineStrength, f3.lineStrength, with: msx)
        let opacity = CGFloat.monospline(f0.opacity, f1.opacity, f2.opacity, f3.opacity, with: msx)
        return Material(color: color, type: type, lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity)
    }
    static func endMonospline(_ f0: Material, _ f1: Material, _ f2: Material, with msx: MonosplineX) -> Material {
        let color = HSLColor.endMonospline(f0.color, f1.color, f2.color, with: msx)
        let type = f1.type
        let lineWidth = CGFloat.endMonospline(f0.lineWidth, f1.lineWidth, f2.lineWidth, with: msx)
        let lineStrength = CGFloat.endMonospline(f0.lineStrength, f1.lineStrength, f2.lineStrength, with: msx)
        let opacity = CGFloat.endMonospline(f0.opacity, f1.opacity, f2.opacity, with: msx)
        return Material(color: color, type: type, lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity)
    }
}
