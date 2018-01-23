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

/**
 # Issue
 - セルのトラック間移動
 - 複数セルの重なり判定（複数のセルの上からセルを追加するときにもcontains判定が有効なように修正）
 - セルに文字を実装
 - 文字から口パク生成アクション
 - セルの結合
 - 自動回転補間
 - アクションの保存（変形情報などをセルに埋め込む、セルへの操作の履歴を別のセルに適用するコマンド）
 - 変更通知またはイミュータブル化またはstruct化
 */
final class Cell: NSObject, NSCoding {
    var children: [Cell], geometry: Geometry, material: Material
    var isLocked: Bool, isHidden: Bool, isTranslucentLock: Bool, id: UUID
    var drawGeometry: Geometry, drawMaterial: Material
    
    init(children: [Cell] = [], geometry: Geometry = Geometry(),
         material: Material = Material(color: Color.random()),
         isLocked: Bool = false, isHidden: Bool = false,
         isTranslucentLock: Bool = false, id: UUID = UUID()) {
        
        self.children = children
        self.geometry = geometry
        self.material = material
        self.drawGeometry = geometry
        self.drawMaterial = material
        self.isLocked = isLocked
        self.isHidden = isHidden
        self.isTranslucentLock = isTranslucentLock
        self.id = id
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case
        children, geometry, material, drawGeometry, drawMaterial,
        isLocked, isHidden, isTranslucentLock, id
    }
    init?(coder: NSCoder) {
        children = coder.decodeObject(forKey: CodingKeys.children.rawValue) as? [Cell] ?? []
        geometry = coder.decodeObject(forKey: CodingKeys.geometry.rawValue) as? Geometry ?? Geometry()
        material = coder.decodeObject(forKey: CodingKeys.material.rawValue) as? Material ?? Material()
        drawGeometry = coder.decodeObject(forKey: CodingKeys.drawGeometry.rawValue)
            as? Geometry ?? Geometry()
        drawMaterial = coder.decodeObject(forKey: CodingKeys.drawMaterial.rawValue)
            as? Material ?? Material()
        isLocked = coder.decodeBool(forKey: CodingKeys.isLocked.rawValue)
        isHidden = coder.decodeBool(forKey: CodingKeys.isHidden.rawValue)
        isTranslucentLock = coder.decodeBool(forKey: CodingKeys.isTranslucentLock.rawValue)
        id = coder.decodeObject(forKey: CodingKeys.id.rawValue) as? UUID ?? UUID()
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(children, forKey: CodingKeys.children.rawValue)
        coder.encode(geometry, forKey: CodingKeys.geometry.rawValue)
        coder.encode(material, forKey: CodingKeys.material.rawValue)
        coder.encode(drawGeometry, forKey: CodingKeys.drawGeometry.rawValue)
        coder.encode(drawMaterial, forKey: CodingKeys.drawMaterial.rawValue)
        coder.encode(isLocked, forKey: CodingKeys.isLocked.rawValue)
        coder.encode(isHidden, forKey: CodingKeys.isHidden.rawValue)
        coder.encode(isTranslucentLock, forKey: CodingKeys.isTranslucentLock.rawValue)
        coder.encode(id, forKey: CodingKeys.id.rawValue)
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
        allCells { (cell, stop) in imageBounds = imageBounds.unionNoEmpty(cell.imageBounds) }
        return imageBounds
    }
    var imageBounds: CGRect {
        return path.isEmpty ? CGRect() : path.boundingBoxOfPath.inset(by: -material.lineWidth)
    }
    var isEditable: Bool {
        return !isLocked && !isHidden && !isTranslucentLock
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
    private func depthFirstSearchDuplicateRecursion(
        _ handler: (_ parent: Cell, _ cell: Cell) -> Void) {
        
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
    func allCells(isReversed: Bool = false, usingLock: Bool = false,
                  handler: (Cell, _ stop: inout Bool) -> Void) {
        var stop = false
        allCellsRecursion(&stop, isReversed: isReversed, usingLock: usingLock, handler: handler)
    }
    private func allCellsRecursion(_ aStop: inout Bool, isReversed: Bool, usingLock: Bool,
                                   handler: (Cell, _ stop: inout Bool) -> Void) {
        let children = isReversed ? self.children.reversed() : self.children
        for child in children {
            if usingLock ? child.isEditable : true {
                child.allCellsRecursion(&aStop, isReversed: isReversed, usingLock: usingLock,
                                        handler: handler)
                if aStop {
                    return
                }
                handler(child, &aStop)
                if aStop {
                    return
                }
            } else {
                child.allCellsRecursion(&aStop, isReversed: isReversed, usingLock: usingLock,
                                        handler: handler)
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
    
    func at(_ p: CGPoint, reciprocalScale: CGFloat,
            maxArea: CGFloat = 200.0, maxDistance: CGFloat = 5.0) -> Cell? {
        
        let scaleMaxArea = reciprocalScale * reciprocalScale * maxArea
        let scaleMaxDistance = reciprocalScale * maxDistance
        var minD² = CGFloat.infinity, minCell: Cell? = nil
        var scaleMaxDistance² = scaleMaxDistance * scaleMaxDistance
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
                        let lld = point.distanceWithLineSegment(ap: line.lastPoint,
                                                                bp: nextLine.firstPoint)
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
            if (usingLock ? !isLocked : true) && !path.isEmpty
                && contains(point) && !cells.contains(self) {
                
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
        return !isHidden && !isTranslucentLock && (imageBounds.contains(p) ? path.contains(p) : false)
    }
    func contains(_ cell: Cell) -> Bool {
        if !path.isEmpty && !cell.path.isEmpty && isEditable
            && cell.isEditable && imageBounds.contains(cell.imageBounds) {
            
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
    func contains(_ bounds: CGRect) -> Bool {
        if isEditable && imageBounds.intersects(bounds) {
            let x0y0 = bounds.origin
            let x1y0 = CGPoint(x: bounds.maxX, y: bounds.minY)
            let x0y1 = CGPoint(x: bounds.minX, y: bounds.maxY)
            let x1y1 = CGPoint(x: bounds.maxX, y: bounds.maxY)
            if contains(x0y0) || contains(x1y0) || contains(x0y1) || contains(x1y1) {
                return true
            }
            return  intersects(bounds)
        } else {
            return false
        }
    }
    
    func intersects(_ cell: Cell, usingLock: Bool = true) -> Bool {
        if !path.isEmpty && !cell.path.isEmpty
            && (usingLock ? isEditable && cell.isEditable : true)
            && imageBounds.intersects(cell.imageBounds) {
            
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
    func intersects(_ lasso: LineLasso) -> Bool {
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
                let x0y1 = CGPoint(x: bounds.minX, y: bounds.maxY)
                let x1y1 = CGPoint(x: bounds.maxX, y: bounds.maxY)
                if CGPoint.intersection(p0: lp, p1: fp, q0: x0y0, q1: x1y0)
                    || CGPoint.intersection(p0: lp, p1: fp, q0: x1y0, q1: x1y1)
                    || CGPoint.intersection(p0: lp, p1: fp, q0: x1y1, q1: x0y1)
                    || CGPoint.intersection(p0: lp, p1: fp, q0: x0y1, q1: x0y0) {
                    
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
        let newCell = copied
        _ = newCell.intersectionRecursion(cells)
        if isNewID {
            newCell.allCells { (cell, stop) in
                cell.id = UUID()
            }
        }
        return newCell
    }
    private func intersectionRecursion(_ cells: [Cell]) -> Bool {
        children = children.reduce(into: [Cell]()) {
            $0 += (!$1.intersectionRecursion(cells) ? $1.children : [$1])
        }
        for cell in cells {
            if cell.id == id {
                return true
            }
        }
        return false
    }
    
    func colorAndLineColor(withIsEdit isEdit: Bool) -> (color: Color, lineColor: Color) {
        if isEdit {
            let aColor = material.type == .add || material.type == .luster ?
                material.color.multiply(alpha: 0.5) : material.color.multiply(white: 0.8)
            let aLineColor = isLocked ?
                material.lineColor.multiply(white: 0.8) : material.lineColor
            if isTranslucentLock {
                return (aColor.multiply(alpha: 0.2), aLineColor.multiply(alpha: 0.2))
            } else {
                return (aColor, aLineColor)
            }
        } else {
            return (material.color, material.lineColor)
        }
    }
    func draw(isEdit: Bool = false, reciprocalScale: CGFloat, reciprocalAllScale: CGFloat,
              scale: CGFloat, rotation: CGFloat,in ctx: CGContext) {
        
        if !isHidden, !path.isEmpty {
            let isEditUnlock = isEdit && !isLocked
            if material.opacity < 1 {
                ctx.saveGState()
                ctx.setAlpha(material.opacity)
            }
            let (color, lineColor) = colorAndLineColor(withIsEdit: isEdit)
            if material.type == .normal || material.type == .lineless {
                if children.isEmpty {
                    geometry.fillPath(with: color, path, in: ctx)
                } else {
                    func clipFillPath(color: Color, path: CGPath,
                                      in ctx: CGContext, clipping: () -> Void) {
                        
                        ctx.saveGState()
                        ctx.addPath(path)
                        ctx.clip()
                        let b = ctx.boundingBoxOfClipPath.intersection(imageBounds)
                        ctx.beginTransparencyLayer(in: b, auxiliaryInfo: nil)
                        ctx.setFillColor(color.cgColor)
                        ctx.fill(imageBounds)
                        clipping()
                        ctx.endTransparencyLayer()
                        ctx.restoreGState()
                    }
                    clipFillPath(color: color, path: path, in: ctx) {
                        children.forEach {
                            $0.draw(isEdit: isEdit, reciprocalScale: reciprocalScale,
                                    reciprocalAllScale: reciprocalAllScale,
                                    scale: scale, rotation: rotation,
                                    in: ctx)
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
                    drawStrokePath(path: path, lineWidth: material.lineWidth,
                                   color: lineColor)
                }
            } else {
                ctx.saveGState()
                ctx.setBlendMode(material.type.blendMode)
                ctx.drawBlurWith(color: color, width: material.lineWidth,
                                 strength: 1,
                                 isLuster: material.type == .luster, path: path,
                                 scale: scale, rotation: rotation)
                if !children.isEmpty {
                    ctx.addPath(path)
                    ctx.clip()
                    children.forEach {
                        $0.draw(isEdit: isEdit, reciprocalScale: reciprocalScale,
                                reciprocalAllScale: reciprocalAllScale,
                                scale: scale, rotation: rotation,
                                in: ctx)
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
    }
    
    static func drawCellPaths(cells: [Cell], color: Color,
                              alpha: CGFloat = 0.3, in ctx: CGContext) {
        
        ctx.setAlpha(alpha)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.setFillColor(color.cgColor)
        cells.forEach {
            if !$0.isHidden {
                $0.geometry.fillPath(in: ctx)
            }
        }
        ctx.endTransparencyLayer()
        ctx.setAlpha(1)
    }
    
    func drawMaterialID(in ctx: CGContext) {
        guard !imageBounds.isEmpty else {
            return
        }
        let mus = material.id.uuidString, cus = material.color.id.uuidString
        let materialString = mus[mus.index(mus.endIndex, offsetBy: -6)...]
        let colorString = cus[cus.index(cus.endIndex, offsetBy: -6)...]
        let textFrame = TextFrame(string: "M: \(materialString)\nC: \(colorString)", font: .small)
        textFrame.drawWithCenterOfImageBounds(in: imageBounds, in: ctx)
    }
}
extension Cell: Copying {
    func copied(from copier: Copier) -> Cell {
        return Cell(children: children.map { copier.copied($0) },
                    geometry: geometry, material: material,
                    isLocked: isLocked, isHidden: isHidden,
                    isTranslucentLock: isTranslucentLock, id: id)
    }
}
extension Cell: Referenceable {
    static let name = Localization(english: "Cell", japanese: "セル")
}
extension Cell: Layerable {
    func layer(withBounds bounds: CGRect) -> Layer {
        let layer = DrawLayer()
        layer.drawBlock = { [unowned self, unowned layer] ctx in
            self.draw(with: layer.bounds, in: ctx)
        }
        layer.bounds = bounds
        return layer
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

final class JoiningCell: NSObject, NSCoding {
    let cell: Cell
    init(_ cell: Cell) {
        self.cell = cell
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case cell
    }
    init?(coder: NSCoder) {
        cell = coder.decodeObject(forKey: CodingKeys.cell.rawValue) as? Cell ?? Cell()
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(cell, forKey: CodingKeys.cell.rawValue)
    }
}
extension JoiningCell: Referenceable {
    static let name = Localization(english: "Joining Cell", japanese: "接続セル")
}
extension JoiningCell: Layerable {
    func layer(withBounds bounds: CGRect) -> Layer {
        return cell.layer(withBounds: bounds)
    }
}

final class CellEditor: Layer, Respondable {
    static let name = Localization(english: "Cell Editor", japanese: "セルエディタ")
    
    var cell = Cell() {
        didSet {
            isTranslucentLockButton.selectionIndex = !cell.isTranslucentLock ? 0 : 1
        }
    }
    
    private let nameLabel = Label(text: Cell.name, font: .bold)
    private let isTranslucentLockButton = PulldownButton(
        names: [Localization(english: "Unlock", japanese: "ロックなし"),
                Localization(english: "Translucent Lock", japanese: "半透明ロック")],
        isEnabledCation: true
    )
    
    override init() {
        super.init()
        replace(children: [nameLabel, isTranslucentLockButton])
        
        isTranslucentLockButton.setIndexHandler = { [unowned self] in
            self.setIsTranslucentLock(with: $0)
        }
    }
    
    override var defaultBounds: CGRect {
        let padding = Layout.basicPadding
        return CGRect(x: 0,
                      y: 0,
                      width: nameLabel.frame.width
                        + isTranslucentLockButton.frame.width + padding * 3,
                      height: Layout.basicHeight + padding * 2)
    }
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        let padding = Layout.basicPadding, h = Layout.basicHeight
        nameLabel.frame.origin = CGPoint(x: padding,
                                         y: padding * 2)
        isTranslucentLockButton.frame = CGRect(x: nameLabel.frame.maxX + padding,
                                               y: padding,
                                               width: bounds.width
                                                - nameLabel.frame.width - padding * 3,
                                               height: h)
    }
    func updateWithCell() {
        isTranslucentLockButton.selectionIndex = !cell.isTranslucentLock ? 0 : 1
    }
    
    var disabledRegisterUndo = true
    
    struct Binding {
        let cellEditor: CellEditor
        let isTranslucentLock: Bool, oldIsTranslucentLock: Bool, inCell: Cell, type: Action.SendType
    }
    var setIsTranslucentLockHandler: ((Binding) -> ())?
    
    private var oldCell = Cell()
    
    private func setIsTranslucentLock(with obj: PulldownButton.Binding) {
        if obj.type == .begin {
            oldCell = cell
        } else {
            cell.isTranslucentLock = obj.index == 1
        }
        setIsTranslucentLockHandler?(Binding(cellEditor: self,
                                                   isTranslucentLock: obj.index == 1,
                                                   oldIsTranslucentLock: obj.oldIndex == 1,
                                                   inCell: oldCell,
                                                   type: obj.type))
    }
    
    var copyHandler: ((CellEditor, KeyInputEvent) -> CopiedObject?)?
    func copy(with event: KeyInputEvent) -> CopiedObject? {
        if let copyHandler = copyHandler {
            return copyHandler(self, event)
        } else {
            return CopiedObject(objects: [cell.copied])
        }
    }
}
