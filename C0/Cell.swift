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
    
    var lines: [Bezier2] {
        return geometry.beziers
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
    var imageBounds: CGRect {
        return path.isEmpty ? CGRect() : path.boundingBoxOfPath.inset(by: -material.lineWidth)
    }
    var arowImageBounds: CGRect {
        return imageBounds.inset(by: -skinRadius)
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
                if !contains(aLine.p0) || !contains(aLine.p1) {
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
        if !path.isEmpty && !cell.path.isEmpty && (usingLock ? isEditable && cell.isEditable : true) && imageBounds.intersects(cell.imageBounds) {
            for line in lines {
                for aLine in cell.lines {
                    if line.intersects(aLine) {
                        return true
                    }
                }
            }
            for aLine in cell.lines {
                if contains(aLine.p0) || contains(aLine.p1) {
                    return true
                }
            }
            for line in lines {
                if cell.contains(line.p0) || cell.contains(line.p1) {
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
                if lasso.contains(line.p0) || lasso.contains(line.p1) {
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
        if var lp = lines.last?.p1 {
            for line in lines {
                let fp = line.p0
                let x0y0 = bounds.origin, x1y0 = CGPoint(x: bounds.maxX, y: bounds.minY)
                let x0y1 = CGPoint(x: bounds.minX, y: bounds.maxY), x1y1 = CGPoint(x: bounds.maxX, y: bounds.maxY)
                if CGPoint.intersection(p0: lp, p1: fp, q0: x0y0, q1: x1y0) ||
                    CGPoint.intersection(p0: lp, p1: fp, q0: x1y0, q1: x1y1) ||
                    CGPoint.intersection(p0: lp, p1: fp, q0: x1y1, q1: x0y1) ||
                    CGPoint.intersection(p0: lp, p1: fp, q0: x0y1, q1: x0y0) {
                    return true
                }
                lp = line.p1
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
    
    func beziers(_ fromCells: [(cell: Cell, bezierIndexes: [Int])]) -> [Bezier2] {
        var lines = [Bezier2]()
        for fromCell in fromCells {
            for j in fromCell.bezierIndexes {
                lines.append(fromCell.cell.geometry.beziers[j])
            }
        }
        return geometry.beziers
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
            var fillColor = material.fillColor.multiplyWhite(0.7), lineColor = material.lineColor
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
    private func clipFillPath(color: CGColor, path: CGPath, in ctx: CGContext, clipping: (Void) -> Void) {
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
    func clip(in ctx: CGContext, handler: (Void) -> Void) {
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
            if line.p1 != nextLine.p0 {
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
    
    func drawPointsWith(color1: CGColor, color2: CGColor, color3: CGColor, with di: DrawInfo, in ctx: CGContext) {
        let s = di.invertScale
        let beziers = geometry.beziers
        ctx.setLineWidth(skinLineWidth*s)
        ctx.setStrokeColor(color2)
        let or = skinRadius*s, mor = skinRadius*s*0.75
        if var oldBezier = beziers.last {
            for bezier in beziers {
                ctx.move(to: bezier.p0)
                ctx.addLine(to: bezier.cp)
                ctx.addLine(to: bezier.p1)
                ctx.setStrokeColor(SceneDefaults.moveZColor)
                ctx.setLineWidth(1)
                ctx.strokePath()
                
                let isUnion = oldBezier.p1 == bezier.p0
                if isUnion {
                    if oldBezier.cp.tangential(oldBezier.p1).isEqualAngle(bezier.p0.tangential(bezier.cp)) {
                        ctx.setFillColor(color3)
                        ctx.setStrokeColor(color2)
                        ctx.addEllipse(in: CGRect(x: bezier.p0.x - mor, y: bezier.p0.y - mor, width: mor*2, height: mor*2))
                        ctx.drawPath(using: .fillStroke)
                    } else {
                        ctx.setFillColor(color2)
                        ctx.setStrokeColor(color1)
                        ctx.addEllipse(in: CGRect(x: bezier.p0.x - or, y: bezier.p0.y - or, width: or*2, height: or*2))
                        ctx.drawPath(using: .fillStroke)
                    }
                } else {
                    ctx.setFillColor(color1)
                    ctx.setStrokeColor(color2)
                    ctx.addEllipse(in: CGRect(x: oldBezier.p1.x - mor, y: oldBezier.p1.y - mor, width: mor*2, height: mor*2))
                    ctx.addEllipse(in: CGRect(x: bezier.p0.x - mor, y: bezier.p0.y - mor, width: mor*2, height: mor*2))
                    ctx.drawPath(using: .fillStroke)
                }
                oldBezier = bezier
            }
        }
    }
    
    private let skinLineWidth = 1.0.cf, skinRadius = 2.0.cf
    func drawSkin(lineColor c: CGColor, subColor sc: CGColor, opacity: CGFloat, geometry: Geometry, with di: DrawInfo, in ctx: CGContext) {
        let lines = geometry.beziers
        ctx.saveGState()
        ctx.setAlpha(opacity)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        fillPath(color: sc, path: geometry == self.geometry ? path : geometry.path, in: ctx)
        let backColor = SceneDefaults.selectionSkinLineColor, s = di.invertScale, lineWidth = 1*di.invertCameraScale
        ctx.setFillColor(backColor)
        geometry.draw(withLineWidth: lineWidth + 1*di.invertCameraScale, in: ctx)
        ctx.setFillColor(c)
        geometry.draw(withLineWidth: di.invertScale, in: ctx)
        ctx.setLineWidth(skinLineWidth*s)
        ctx.setStrokeColor(backColor)
        let or = skinRadius*s, mor = skinRadius*s*0.75
        if var oldP = lines.last?.p1 {
            for line in lines {
                let fp = line.p0, lp = line.p1, isUnion = oldP == fp
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
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }
}

final class Geometry: NSObject, NSCoding, Interpolatable {
    let beziers: [Bezier2]
    let path: CGPath
    init(beziers: [Bezier2] = []) {
        self.beziers = beziers
        self.path = Geometry.path(with: beziers)
        super.init()
    }
    static func path(with beziers: [Bezier2]) -> CGPath {
        guard !beziers.isEmpty else {
            return CGMutablePath()
        }
        let path = CGMutablePath()
        for (i, line) in beziers.enumerated() {
            if i == 0 {
                path.move(to: line.p0)
            } else {
                path.addLine(to: line.p0)
            }
            path.addQuadCurve(to: line.p1, control: line.cp)
            let nextLine = beziers[i + 1 < beziers.count ? i + 1 : 0]
            if line.p1 != nextLine.p0 {
                path.addLine(to: line.lastExtensionPoint(withLength: 0.5))
                path.addLine(to: nextLine.firstExtensionPoint(withLength: 0.5))
            }
        }
        path.closeSubpath()
        return path
    }
    
    static let dataType = "C0.Geometry.1", beziersKey = "2r"
    init?(coder: NSCoder) {
        beziers = coder.decodeStruct(forKey: Geometry.beziersKey) ?? []
        self.path = Geometry.path(with: beziers)
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeStruct(beziers, forKey: Geometry.beziersKey)
    }
    
    static func linear(_ f0: Geometry, _ f1: Geometry, t: CGFloat) -> Geometry {
        if f0 === f1 {
            return f0
        } else if f0.beziers.isEmpty {
            return Geometry()
        } else {
            return Geometry(beziers: f0.beziers.enumerated().map { i, l0 in
                i >= f1.beziers.count ? l0 : Bezier2.linear(l0, f1.beziers[i], t: t)
            }).connected(with: f0, f1: f1, t: t)
        }
    }
    static func firstMonospline(_ f1: Geometry, _ f2: Geometry, _ f3: Geometry, with msx: MonosplineX) -> Geometry {
        if f1 === f2 {
            return f1
        } else if f1.beziers.isEmpty {
            return Geometry()
        } else {
            return Geometry(beziers: f1.beziers.enumerated().map { i, l1 in
                if i >= f2.beziers.count {
                    return l1
                } else {
                    let l2 = f2.beziers[i]
                    return Bezier2.firstMonospline(l1, l2, i >= f3.beziers.count ? l2 : f3.beziers[i], with: msx)
                }
            }).connected(with: f1, f1: f2, t: msx.t)
        }
    }
    static func monospline(_ f0: Geometry, _ f1: Geometry, _ f2: Geometry, _ f3: Geometry, with msx: MonosplineX) -> Geometry {
        if f1 === f2 {
            return f1
        } else if f1.beziers.isEmpty {
            return Geometry()
        } else {
            return Geometry(beziers: f1.beziers.enumerated().map { i, l1 in
                if i >= f2.beziers.count {
                    return l1
                } else {
                    let l2 = f2.beziers[i]
                    return Bezier2.monospline(i >= f0.beziers.count ? l1 : f0.beziers[i], l1, l2, i >= f3.beziers.count ? l2 : f3.beziers[i], with: msx)
                }
            }).connected(with: f1, f1: f2, t: msx.t)
        }
    }
    static func endMonospline(_ f0: Geometry, _ f1: Geometry, _ f2: Geometry, with msx: MonosplineX) -> Geometry {
        if f1 === f2 {
            return f1
        } else if f1.beziers.isEmpty {
            return Geometry()
        } else {
            return Geometry(beziers: f1.beziers.enumerated().map { i, l1 in
                if i >= f2.beziers.count {
                    return l1
                } else {
                    return Bezier2.endMonospline(i >= f0.beziers.count ? l1 : f0.beziers[i], l1, f2.beziers[i], with: msx)
                }
            }).connected(with: f1, f1: f2, t: msx.t)
        }
    }
    func connected(with f0: Geometry, f1: Geometry, t: CGFloat) -> Geometry {
        var newBeziers = beziers, isChanged = false
        for (i, f0Bezier) in f0.beziers.enumerated() {
            let preIndex = i == 0 ? f0.beziers.count - 1 : i - 1
            let f0PreBezier = f0.beziers[preIndex]
            if preIndex < f1.beziers.count && i < f1.beziers.count {
                let f1Bezier = f1.beziers[i], f1PreBezier = f1.beziers[preIndex]
                if f0PreBezier.p1 == f0Bezier.p0 && f0PreBezier.cp.tangential(f0PreBezier.p1).isEqualAngle(f0Bezier.p0.tangential(f0Bezier.cp)) &&
                f1PreBezier.p1 == f1Bezier.p0 && f1PreBezier.cp.tangential(f1PreBezier.p1).isEqualAngle(f1Bezier.p0.tangential(f1Bezier.cp)) {
                    let d0 = f0PreBezier.cp.distance(f0Bezier.cp), d1 = f1PreBezier.cp.distance(f1Bezier.cp)
                    let nt = d0 == 0 || d1 == 0 ? 0.5 : CGFloat.linear(f0PreBezier.cp.distance(f0Bezier.p0)/d0, f1PreBezier.cp.distance(f1Bezier.p0)/d1, t: t)
                    if preIndex < newBeziers.count && i < newBeziers.count {
                        let newPreBezier = newBeziers[preIndex], newBezier = newBeziers[i]
                        let newP = CGPoint.linear(newPreBezier.cp, newBezier.cp, t: nt)
                        newBeziers[i].p0 = newP
                        newBeziers[preIndex].p1 = newP
                        isChanged = true
                    }
                }
            }
        }
//        if var oldBezier = beziers.last {
//            for bezier in beziers {
//                let isUnion = oldBezier.p1 == bezier.p0
//                if isUnion {
//                    if oldBezier.cp.tangential(oldBezier.p1).isEqualAngle(bezier.p0.tangential(bezier.cp)) {
//                        
//                    }
//                }
//                oldBezier = bezier
//            }
//        }
        return isChanged ? Geometry(beziers: newBeziers) : self
    }
    
    func transformed(with affine: CGAffineTransform) -> Geometry {
        return Geometry(beziers: beziers.map { $0.applying(affine) })
    }
    func warpedWith(deltaPoint dp: CGPoint, editPoint: CGPoint, minDistance: CGFloat, maxDistance: CGFloat) -> Geometry {
        func warped(p: CGPoint) -> CGPoint {
            let d =  hypot2(p.x - editPoint.x, p.y - editPoint.y)
            let ds = d > maxDistance ? 0 : (1 - (d - minDistance)/(maxDistance - minDistance))
            return CGPoint(x: p.x + dp.x*ds, y: p.y + dp.y*ds)
        }
        
        var newBeziers = beziers.map { Bezier2(p0: warped(p: $0.p0), cp: warped(p: $0.cp), p1: warped(p: $0.p1)) }
        for (i, bezier) in beziers.enumerated() {
            let preIndex = i == 0 ? beziers.count - 1 : i - 1
            let preBezier = beziers[preIndex]
            if preBezier.p1 == bezier.p0 && preBezier.cp.tangential(preBezier.p1).isEqualAngle(bezier.p0.tangential(bezier.cp)) {
                let t = preBezier.cp.distance(bezier.p0)/preBezier.cp.distance(bezier.cp)
                let newPreBezier = newBeziers[preIndex], newBezier = newBeziers[i]
                let newP = CGPoint.linear(newPreBezier.cp, newBezier.cp, t: t)
                newBeziers[i].p0 = newP
                newBeziers[preIndex].p1 = newP
            }
        }
        return Geometry(beziers: newBeziers)
    }
    
    static func splitedGeometries(with geometries: [Geometry], t: CGFloat, at i: Int) -> [Geometry] {
        return geometries.map {
            if i < $0.beziers.count {
                let b = $0.beziers[i]
                let b0 = b.clip(startT: 0, endT: t), b1 = b.clip(startT: t, endT: 1)
                var bs = $0.beziers
                bs.remove(at: i)
                bs.insert(b0, at: i)
                bs.insert(b1, at: i + 1)
                return Geometry(beziers: bs)
            } else {
                return $0
            }
        }
    }
    static func JoinedGeometries(with geometries: [Geometry], bezierPoint: Bezier2.Point, at i: Int) -> [Geometry] {
        return geometries.map {
            if i < $0.beziers.count {
                let b0Index = bezierPoint == .p0 ? (i == 0 ? $0.beziers.count - 1 : i - 1) : i
                if b0Index < $0.beziers.count - 1 {
                    let b0 = $0.beziers[b0Index], b1 = $0.beziers[b0Index + 1]
//                    let b0d = b0.p0.distance(b0.cp), b1d = b1.cp.distance(b1.p1)
                    
//                    let np = b0d + b1d == 0 ? b0.p0.mid(b1.p1) : CGPoint.linear(b0.p0, b1.p1, t: b0d/(b0d + b1d))
                    
                    let ncp = CGPoint.intersectionLine(b0.p0, b0.cp, b1.cp, b1.p1) ?? b0.cp.mid(b1.cp)
                    let np = b0.p1.nearestWithLine(ap: b0.p0, bp: b1.p1)
                    let dp = (np - b0.p1)*2
                    let d = ncp.distanceWithLine(ap: b0.p0 - dp, bp: b1.p1 - dp), minD = np.distance(b0.p1)/2
                    let cp = d > minD ? b0.p1*2 - np : ncp
                    
//                    let cp = CGPoint.intersectionLine(b0.p0, b0.cp, b1.cp, b1.p1) ?? b0.cp.mid(b1.cp)
                    let nb = Bezier2(p0: b0.p0, cp: cp, p1: b1.p1)
                    return Geometry(beziers: $0.beziers.withRemoved(at: b0Index + 1).withReplaced(nb, at: b0Index))
                } else {
                    return Geometry(beziers: $0.beziers.withRemoved(at: b0Index))
                }
            } else {
                return $0
            }
        }
    }
    static func removedBezierWithGeometries(_ geometries: [Geometry], at i: Int) -> [Geometry] {
        return geometries.map {
            if i < $0.beziers.count {
                return Geometry(beziers: $0.beziers.withRemoved(at: i))
            } else {
                return $0
            }
        }
    }
    func warped(dp: CGPoint, bezierPointIndexs: [(index: Int, bezierPoint: Bezier2.Point, isMoveCP: Bool)]) -> Geometry {
        var beziers = self.beziers
        for bpi in bezierPointIndexs {
            let b = beziers[bpi.index]
            if bpi.bezierPoint == .p0 {
                let np = b.p0 + dp
                let newCP = bpi.isMoveCP ? CGPoint.intersectionLine(b.p1, b.cp, b.cp + dp, np) ?? b.p0.mid(b.p1) : b.cp
                beziers[bpi.index] = Bezier2(p0: np, cp: newCP, p1: b.p1)
            } else {
                let np = b.p1 + dp
                let newCP = bpi.isMoveCP ? CGPoint.intersectionLine(b.p0, b.cp, b.cp + dp, np) ?? b.p0.mid(b.p1) : b.cp
                beziers[bpi.index] = Bezier2(p0: b.p0, cp: newCP, p1: np)
            }
        }
        return Geometry(beziers: beziers)
    }
    
    func nearestBezier(with point: CGPoint) -> (bezier: Bezier2, index: Int, t: CGFloat, minDistance: CGFloat)? {
        if beziers.isEmpty {
            return nil
        }
        var minD = CGFloat.infinity, minT = 0.0.cf, minIndex = 0
        for (i, bezier) in beziers.enumerated() {
            let t = bezier.nearestT(with: point)
            let d = point.distance(bezier.position(withT: t))
            if d < minD {
                minT = t
                minIndex = i
                minD = d
            }
        }
        return (beziers[minIndex], minIndex, minT, minD)
    }
    
    func beziers(with indexes: [Int]) -> [Bezier2] {
        return indexes.map { beziers[$0] }
    }
    var isEmpty: Bool {
        return beziers.isEmpty
    }
    var lines: [Line] {
        return beziers.map { Line.with($0) }
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
            
            var beziers = [Bezier2]()
            let snapLines = Geometry.snapPointLinesWith(lines: cellLines, scale: scale) ?? cellLines
            for line in snapLines {
                if line.controls.count <= 2 {
                    beziers.append(Bezier2(p0: line.firstPoint, cp: line.firstPoint.mid(line.lastPoint), p1: line.lastPoint))
                } else {
                    let minDifferenceAngle = .pi*0.1.cf, minDifferenceRotation = .pi*0.5.cf
                    let fp0 = line.controls[0].point, fp1 = line.controls[1].point
                    var oldTheta = atan2(fp1.y - fp0.y, fp1.x - fp0.x)
                    var oldDifferenceAngle = CGFloat.differenceAngle(line.controls[0].point, p1: line.controls[1].point, p2: line.controls[2].point)
                    var oldIsClockwise = oldDifferenceAngle < 0
                    var p0 = fp0, p0p1 = fp1
                    for i in (3 ..< line.controls.count) {
                        let p = line.controls[i].point, op = line.controls[i - 1].point, oop = line.controls[i - 2].point
                        let theta = atan2(p.y - op.y, p.x - op.x)
                        let differenceAngle = CGPoint.differenceAngle(p0: oop, p1: op, p2: p)
                        let isClockwise = differenceAngle < 0
                        if abs(theta.differenceRotation(oldTheta)) > minDifferenceRotation {
                            let cp = CGPoint.intersectionLine(p0, p0p1, oop, op) ?? p0p1.mid(oop), p1 = oop.mid(op)
                            beziers.append(Bezier2(p0: p0, cp: cp, p1: p1))
                            oldTheta = atan2(op.y - oop.y, op.x - oop.x)
                            oldIsClockwise = isClockwise
                            oldDifferenceAngle = differenceAngle
                            p0 = p1
                            p0p1 = op
                        } else {
                            if isClockwise != oldIsClockwise && abs(differenceAngle - oldDifferenceAngle) > minDifferenceAngle {
                                let cp = CGPoint.intersectionLine(p0, p0p1, oop, op) ?? p0p1.mid(oop), p1 = oop.mid(op)
                                beziers.append(Bezier2(p0: p0, cp: cp, p1: p1))
                                oldIsClockwise = isClockwise
                                oldDifferenceAngle = differenceAngle
                                p0 = p1
                                p0p1 = op
                            }
                        }
                    }
                    let op = line.controls[line.controls.count - 2].point, p = line.lastPoint
                    let cp = CGPoint.intersectionLine(p0, p0p1, op, p) ?? p0p1.mid(op)
                    beziers.append(Bezier2(p0: p0, cp: cp, p1: p))
                }
            }
            self.beziers = beziers
            path = Geometry.path(with: beziers)
        } else {
            beziers = []
            path = CGMutablePath()
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
            let controls: [Line.Control]
            if d < vd*(line.pointsLength/vertexLineLength).clip(min: 0.1, max: 1) {
                let dp = CGPoint(x: fp.x - lp.x, y: fp.y - lp.y)
                var cs = line.controls, dd = 1.0.cf
                for (i, fp) in line.controls.enumerated() {
                    cs[i].point = CGPoint(x: fp.point.x - dp.x*dd, y: fp.point.y - dp.y*dd)
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
    
    func draw(withLineWidth lw: CGFloat, minPressure: CGFloat = 0.5.cf, in ctx: CGContext) {
        if let oldLine = beziers.last, let firstLine = beziers.first {
            let lp = oldLine.p1, fp = firstLine.p0, invertPi = 1.0.cf/(.pi)
            var firstPressure = lp != fp ? minPressure : 1 - firstLine.angle(withPreviousLine: oldLine)*invertPi
            for (i, line) in beziers.enumerated() {
                let nextLine = beziers[i + 1 < beziers.count ? i + 1 : 0]
                let lp = line.p1, fp = nextLine.p0
                let lastPressure = lp != fp ? minPressure : max(minPressure, 1 - nextLine.angle(withPreviousLine: line)*invertPi)
                line.draw(haldSize: lw/2, p0Pressure: firstPressure, p1Pressure: lastPressure, in: ctx)
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
