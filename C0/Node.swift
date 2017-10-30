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
import QuartzCore

final class Node: NSObject, ClassCopyData {
    static let name = Localization(english: "Node", japanese: "ノード")
    
    weak var parent: Node?
    var children: [Node] {
        didSet {
            oldValue.forEach { $0.parent = nil }
            children.forEach { $0.parent = self }
        }
    }
    
    func allChildren(_ handler: (Node) -> Void) {
        func allChildrenRecursion(_ node: Node, _ handler: (Node) -> Void) {
            node.children.forEach { allChildrenRecursion($0, handler) }
            handler(node)
        }
        allChildrenRecursion(self, handler)
    }
    
    struct Camera {
        let transform: Transform, wigglePhase: CGFloat, affineTransform: CGAffineTransform?
        
        init(time: Int, animations: [Animation]) {
            var translation = CGPoint(), scale = CGPoint(), rotation = 0.0.cf
            var wiggleSize = CGSize(), hz = 0.0.cf, phase = 0.0.cf, transformCount = 0.0
            for animation in animations {
                if let t = animation.transformItem?.transform {
                    translation.x += t.translation.x
                    translation.y += t.translation.y
                    scale.x += t.scale.x
                    scale.y += t.scale.y
                    rotation += t.rotation
                    wiggleSize.width += t.wiggle.maxSize.width
                    wiggleSize.height += t.wiggle.maxSize.height
                    hz += t.wiggle.hz
                    phase += animation.wigglePhaseWith(time: time, lastHz: t.wiggle.hz)
                    transformCount += 1
                }
            }
            if transformCount > 0 {
                let reciprocalTransformCount = 1/transformCount.cf
                let wiggle = Wiggle(maxSize: wiggleSize, hz: hz*reciprocalTransformCount)
                transform = Transform(translation: translation, scale: scale, rotation: rotation, wiggle: wiggle)
                wigglePhase = phase*reciprocalTransformCount
                affineTransform = transform.isEmpty ? nil : transform.affineTransform
            } else {
                transform = Transform()
                wigglePhase = 0
                affineTransform = nil
            }
        }
    }
    
    var time: Int {
        didSet {
            animations.forEach { $0.update(withTime: time) }
//            updateCamera()
        }
    }
    var timeLength: Int {
        didSet {
            animations.forEach { $0.timeLength = timeLength }
        }
    }
    
    var rootCell: Cell
    var animations: [Animation]
    var editAnimationIndex: Int {
        didSet {
            animations[oldValue].cellItems.forEach { $0.cell.isLocked = true }
            animations[editAnimationIndex].cellItems.forEach { $0.cell.isLocked = false }
        }
    }
    var editAnimation: Animation {
        return animations[editAnimationIndex]
    }
    
    func insertCell(_ cellItem: CellItem, in parents: [(cell: Cell, index: Int)], _ animation: Animation) {
        if !cellItem.cell.children.isEmpty {
            fatalError()
        }
        if cellItem.keyGeometries.count != animation.keyframes.count {
            fatalError()
        }
        if animation.cellItems.contains(cellItem) {
            fatalError()
        }
        for parent in parents {
            parent.cell.children.insert(cellItem.cell, at: parent.index)
        }
        animation.cellItems.append(cellItem)
    }
    func insertCells(_ cellItems: [CellItem], rootCell: Cell, at index: Int, in parent: Cell, _ animation: Animation) {
        for cell in rootCell.children.reversed() {
            parent.children.insert(cell, at: index)
        }
        for cellItem in cellItems {
            if cellItem.keyGeometries.count != animation.keyframes.count {
                fatalError()
            }
            if animation.cellItems.contains(cellItem) {
                fatalError()
            }
            animation.cellItems.append(cellItem)
        }
    }
    func removeCell(_ cellItem: CellItem, in parents: [(cell: Cell, index: Int)], _ animation: Animation) {
        if !cellItem.cell.children.isEmpty {
            fatalError()
        }
        for parent in parents {
            parent.cell.children.remove(at: parent.index)
        }
        animation.cellItems.remove(at: animation.cellItems.index(of: cellItem)!)
    }
    func removeCells(_ cellItems: [CellItem], rootCell: Cell, in parent: Cell, _ animation: Animation) {
        for cell in rootCell.children {
            parent.children.remove(at: parent.children.index(of: cell)!)
        }
        for cellItem in cellItems {
            animation.cellItems.remove(at: animation.cellItems.index(of: cellItem)!)
        }
    }
    
    var imageBounds: CGRect {
        return animations.reduce(rootCell.allImageBounds) { $0.unionNoEmpty($1.imageBounds) }
    }
    
    struct CellRemoveManager {
        let animationAndCellItems: [(animation: Animation, cellItems: [CellItem])]
        let rootCell: Cell
        let parents: [(cell: Cell, index: Int)]
        func contains(_ cellItem: CellItem) -> Bool {
            for gac in animationAndCellItems {
                if gac.cellItems.contains(cellItem) {
                    return true
                }
            }
            return false
        }
    }
    func cellRemoveManager(with cellItem: CellItem) -> CellRemoveManager {
        var cells = [cellItem.cell]
        cellItem.cell.depthFirstSearch(duplicate: false, handler: { parent, cell in
            let parents = rootCell.parents(with: cell)
            if parents.count == 1 {
                cells.append(cell)
            }
        })
        var animationAndCellItems = [(animation: Animation, cellItems: [CellItem])]()
        for animation in animations {
            var cellItems = [CellItem]()
            cells = cells.filter {
                if let removeCellItem = animation.cellItem(with: $0) {
                    cellItems.append(removeCellItem)
                    return false
                }
                return true
            }
            if !cellItems.isEmpty {
                animationAndCellItems.append((animation, cellItems))
            }
        }
        if animationAndCellItems.isEmpty {
            fatalError()
        }
        return CellRemoveManager(animationAndCellItems: animationAndCellItems, rootCell: cellItem.cell, parents: rootCell.parents(with: cellItem.cell))
    }
    func insertCell(with crm: CellRemoveManager) {
        for parent in crm.parents {
            parent.cell.children.insert(crm.rootCell, at: parent.index)
        }
        for gac in crm.animationAndCellItems {
            for cellItem in gac.cellItems {
                if cellItem.keyGeometries.count != gac.animation.keyframes.count {
                    fatalError()
                }
                if gac.animation.cellItems.contains(cellItem) {
                    fatalError()
                }
                gac.animation.cellItems.append(cellItem)
            }
        }
    }
    func removeCell(with crm: CellRemoveManager) {
        for parent in crm.parents {
            parent.cell.children.remove(at: parent.index)
        }
        for gac in crm.animationAndCellItems {
            for cellItem in gac.cellItems {
                gac.animation.cellItems.remove(at: gac.animation.cellItems.index(of: cellItem)!)
            }
        }
    }
    
    var transform: Transform
    var material: Material {
        didSet {
//            func bluerFilter() -> [CIFilter]? {
//                let blurFilter = CIFilter()
//                
//            }
//            layer.opacity = Float(material.opacity)
//            switch material.type {
//            case .normal, .lineless:
//                layer.compositingFilter = nil
//                layer.filters = []
//            case .blur:
//                layer.compositingFilter = nil
//                layer.filters = bluerFilter()
//            case .luster:
//                layer.filters = bluerFilter()
//            case .add:
//                layer.compositingFilter = CIFilter(name: "")
//                layer.filters = bluerFilter()
//            case .subtract:
//                layer.compositingFilter = CIFilter(name: "")
//                layer.filters = bluerFilter()
//            }
        }
    }
    
    init(
        parent: Node? = nil, children: [Node] = [Node](),
        rootCell: Cell = Cell(material: Material(color: Color.white)),
        transform: Transform = Transform(), material: Material = Material(),
        animations: [Animation] = [Animation()], editAnimationIndex: Int = 0,
        time: Int = 0, timeLength: Int = 24
    ) {
        guard !animations.isEmpty else {
            fatalError()
        }
        self.parent = parent
        self.children = children
        self.rootCell = rootCell
        self.transform = transform
        self.material = material
        self.animations = animations
        self.editAnimationIndex = editAnimationIndex
        self.time = time
        self.timeLength = timeLength
        animations.forEach { $0.timeLength = timeLength }
//        self.camera = Camera(time: time, animations: animations)
        super.init()
    }
    
    static let parentKey = "7", childrenKey = "8", rootCellKey = "0", animationsKey = "1", editAnimationKey = "2", timeKey = "3", timeLengthKey = "4", cameraBoundsKey = "5", cellsKey = "6", transformKey = "7", materialKey = "8"
    init?(coder: NSCoder) {
        parent = nil
        children = coder.decodeObject(forKey: Node.childrenKey) as? [Node] ?? []
        rootCell = coder.decodeObject(forKey: Node.rootCellKey) as? Cell ?? Cell()
        transform = coder.decodeObject(forKey: Node.transformKey) as? Transform ?? Transform()
        material = coder.decodeObject(forKey: Node.materialKey) as? Material ?? Material()
        animations = coder.decodeObject(forKey: Node.animationsKey) as? [Animation] ?? []
        editAnimationIndex = coder.decodeInteger(forKey: Node.timeKey)
        time = coder.decodeInteger(forKey: Node.timeKey)
        timeLength = coder.decodeInteger(forKey: Node.timeLengthKey)
        super.init()
        children.forEach { $0.parent = self }
    }
    func encode(with coder: NSCoder) {
        coder.encode(children, forKey: Node.childrenKey)
        coder.encode(rootCell, forKey: Node.rootCellKey)
        coder.encode(transform, forKey: Node.transformKey)
        coder.encode(material, forKey: Node.materialKey)
        coder.encode(animations, forKey: Node.animationsKey)
        coder.encode(editAnimation, forKey: Node.editAnimationKey)
        coder.encode(time, forKey: Node.timeKey)
        coder.encode(timeLength, forKey: Node.timeLengthKey)
    }
    
    var deepCopy: Node {
        let node = noResetDeepCopy
        resetCopyedNode()
        return node
    }
    private weak var deepCopyedNode: Node?
    var noResetDeepCopy: Node {
        if let deepCopyedNode = deepCopyedNode {
            return deepCopyedNode
        } else {
            let copyAnimations = animations.map { $0.deepCopy }
            let deepCopyedNode = Node(
                parent: parent?.noResetDeepCopy,
                children: children.map { $0.noResetDeepCopy },
                rootCell: rootCell.noResetDeepCopy,
                transform: transform, material: material,
                animations: copyAnimations, editAnimationIndex: editAnimationIndex,
                time: time, timeLength: timeLength
            )
            self.deepCopyedNode = deepCopyedNode
            rootCell.resetCopyedCell()
            return deepCopyedNode
        }
    }
    func resetCopyedNode() {
        deepCopyedNode = nil
        for child in children {
            child.resetCopyedNode()
        }
    }
    
    var wigglePhase: CGFloat = 0
    
    var allEditSelectionCellItemsWithNoEmptyGeometry: [CellItem] {
        return animations.reduce([CellItem]()) { $0 + $1.editSelectionCellItemsWithNoEmptyGeometry }
    }
    var allEditSelectionCellsWithNoEmptyGeometry: [Cell] {
        return animations.reduce([Cell]()) { $0 + $1.editSelectionCellsWithNoEmptyGeometry }
    }
    
    enum IndicationCellType {
        case none, indication, selection
    }
    func indicationCellsTuple(with  point: CGPoint, reciprocalScale: CGFloat, usingLock: Bool = true) -> (cells: [Cell], type: IndicationCellType) {
        if usingLock {
            let allEditSelectionCells = editAnimation.editSelectionCellsWithNoEmptyGeometry
            for selectionCell in allEditSelectionCells {
                if selectionCell.contains(point) {
                    return (allEditSelectionCellsWithNoEmptyGeometry, .selection)
                }
            }
        } else {
            let allEditSelectionCells = allEditSelectionCellsWithNoEmptyGeometry
            for selectionCell in allEditSelectionCells {
                if selectionCell.contains(point) {
                    return (allEditSelectionCells, .selection)
                }
            }
        }
        if let cell = rootCell.at(point, reciprocalScale: reciprocalScale) {
            return ([cell], .indication)
        } else {
            return ([], .none)
        }
    }
    func selectionTuples(
        with point: CGPoint, reciprocalScale: CGFloat, usingLock: Bool = true
        ) -> [(animation: Animation, cellItem: CellItem, geometry: Geometry)] {
        let indicationCellsTuple = self.indicationCellsTuple(with: point, reciprocalScale: reciprocalScale, usingLock: usingLock)
        return indicationCellsTuple.cells.map {
            let gc = animationAndCellItem(with: $0)
            return (animation: gc.animation, cellItem: gc.cellItem, geometry: $0.geometry)
        }
    }
    
    func animation(with cell: Cell) -> Animation {
        for animation in animations {
            if animation.contains(cell) {
                return animation
            }
        }
        fatalError()
    }
    func animationAndCellItem(with cell: Cell) -> (animation: Animation, cellItem: CellItem) {
        for animation in animations {
            if let cellItem = animation.cellItem(with: cell) {
                return (animation, cellItem)
            }
        }
        fatalError()
    }
    @nonobjc func animation(with cellItem: CellItem) -> Animation {
        for animation in animations {
            if animation.contains(cellItem) {
                return animation
            }
        }
        fatalError()
    }
    func isInterpolatedKeyframe(with animation: Animation) -> Bool {
        let keyIndex = animation.loopedKeyframeIndex(withTime: time)
        return animation.editKeyframe.interpolation != .none && keyIndex.interValue != 0 && keyIndex.index != animation.keyframes.count - 1
    }
    func isContainsKeyframe(with animation: Animation) -> Bool {
        let keyIndex = animation.loopedKeyframeIndex(withTime: time)
        return keyIndex.interValue == 0
    }
    var maxTime: Int {
        return animations.reduce(0) { max($0, $1.keyframes.last?.time ?? 0) }
    }
    func maxTimeWithOtherAnimation(_ animation: Animation) -> Int {
        return animations.reduce(0) { $1 !== animation ? max($0, $1.keyframes.last?.time ?? 0) : $0 }
    }
    func cellItem(at point: CGPoint, reciprocalScale: CGFloat, with animation: Animation) -> CellItem? {
        if let cell = rootCell.at(point, reciprocalScale: reciprocalScale) {
            let gc = animationAndCellItem(with: cell)
            return gc.animation == animation ? gc.cellItem : nil
        } else {
            return nil
        }
    }
    
    var allParentsAffineTransform: CGAffineTransform {
        if let parentAffine = parent?.allParentsAffineTransform {
            return transform.affineTransform.concatenating(parentAffine)
        } else {
            return transform.affineTransform
        }
    }
    
//    func convert(_ p: CGPoint, from node: Node) -> CGPoint {
//        
//    }
//    func convert(_ p: CGPoint, to node: Node) -> CGPoint {
//        
//    }
    
    struct LineCap {
        let line: Line, lineIndex: Int, isFirst: Bool
        var pointIndex: Int {
            return isFirst ? 0 : line.controls.count - 1
        }
    }
    struct Nearest {
        var drawingEdit: (drawing: Drawing, line: Line, lineIndex: Int, pointIndex: Int)?
        var cellItemEdit: (cellItem: CellItem, geometry: Geometry, lineIndex: Int, pointIndex: Int)?
        var drawingEditLineCap: (drawing: Drawing, lines: [Line], drawingCaps: [LineCap])?
        var cellItemEditLineCaps: [(cellItem: CellItem, geometry: Geometry, caps: [LineCap])]
        var point: CGPoint
        
        struct BezierSortedResult {
            let drawing: Drawing?, cellItem: CellItem?, geometry: Geometry?, lineCap: LineCap, point: CGPoint
        }
        func bezierSortedResult(at p: CGPoint) -> BezierSortedResult? {
            var minDrawing: Drawing?, minCellItem: CellItem?, minLineCap: LineCap?, minD² = CGFloat.infinity
            func minNearest(with caps: [LineCap]) -> Bool {
                var isMin = false
                for cap in caps {
                    let d² = (cap.isFirst ? cap.line.bezier(at: 0) : cap.line.bezier(at: cap.line.controls.count - 3)).minDistance²(at: p)
                    if d² < minD² {
                        minLineCap = cap
                        minD² = d²
                        isMin = true
                    }
                }
                return isMin
            }
            
            if let e = drawingEditLineCap {
                if minNearest(with: e.drawingCaps) {
                    minDrawing = e.drawing
                }
            }
            for e in cellItemEditLineCaps {
                if minNearest(with: e.caps) {
                    minDrawing = nil
                    minCellItem = e.cellItem
                }
            }
            if let drawing = minDrawing, let lineCap = minLineCap {
                return BezierSortedResult(drawing: drawing, cellItem: nil, geometry: nil, lineCap: lineCap, point: point)
            } else if let cellItem = minCellItem, let lineCap = minLineCap {
                return BezierSortedResult(drawing: nil, cellItem: cellItem, geometry: cellItem.cell.geometry, lineCap: lineCap, point: point)
            }
            return nil
        }
    }
    func nearest(at point: CGPoint, isWarp: Bool) -> Nearest? {
        var minD = CGFloat.infinity, minDrawing: Drawing?, minCellItem: CellItem?
        var minLine: Line?, minLineIndex = 0, minPointIndex = 0, minPoint = CGPoint()
        func nearestEditPoint(from lines: [Line]) -> Bool {
            var isNearest = false
            for (j, line) in lines.enumerated() {
                line.allEditPoints() { p, i in
                    if !(isWarp && i != 0 && i != line.controls.count - 1) {
                        let d = hypot²(point.x - p.x, point.y - p.y)
                        if d < minD {
                            minD = d
                            minLine = line
                            minLineIndex = j
                            minPointIndex = i
                            minPoint = p
                            isNearest = true
                        }
                    }
                }
            }
            return isNearest
        }
        
        if nearestEditPoint(from: editAnimation.drawingItem.drawing.lines) {
            minDrawing = editAnimation.drawingItem.drawing
        }
        for cellItem in editAnimation.cellItems {
            if nearestEditPoint(from: cellItem.cell.lines) {
                minDrawing = nil
                minCellItem = cellItem
            }
        }
        
        if let minLine = minLine {
            if minPointIndex == 0 || minPointIndex == minLine.controls.count - 1 {
                func caps(with point: CGPoint, _ lines: [Line]) -> [LineCap] {
                    var caps: [LineCap] = []
                    for (i, line) in lines.enumerated() {
                        if point == line.firstPoint {
                            caps.append(LineCap(line: line, lineIndex: i, isFirst: true))
                        }
                        if point == line.lastPoint {
                            caps.append(LineCap(line: line, lineIndex: i, isFirst: false))
                        }
                    }
                    return caps
                }
                let drawingCaps = caps(with: minPoint, editAnimation.drawingItem.drawing.lines)
                let drawingResult: (drawing: Drawing, lines: [Line], drawingCaps: [LineCap])? = drawingCaps.isEmpty ?
                    nil : (editAnimation.drawingItem.drawing, editAnimation.drawingItem.drawing.lines, drawingCaps)
                let cellResults: [(cellItem: CellItem, geometry: Geometry, caps: [LineCap])] = editAnimation.cellItems.flatMap {
                    let aCaps = caps(with: minPoint, $0.cell.geometry.lines)
                    return aCaps.isEmpty ? nil : ($0, $0.cell.geometry, aCaps)
                }
                return Nearest(
                    drawingEdit: nil, cellItemEdit: nil, drawingEditLineCap: drawingResult,
                    cellItemEditLineCaps: cellResults, point: minPoint
                )
            } else {
                if let drawing = minDrawing {
                    return Nearest(
                        drawingEdit: (drawing, minLine, minLineIndex, minPointIndex), cellItemEdit: nil,
                        drawingEditLineCap: nil, cellItemEditLineCaps: [], point: minPoint
                    )
                } else if let cellItem = minCellItem {
                    return Nearest(
                        drawingEdit: nil, cellItemEdit: (cellItem, cellItem.cell.geometry, minLineIndex, minPointIndex),
                        drawingEditLineCap: nil, cellItemEditLineCaps: [], point: minPoint
                    )
                }
            }
        }
        return nil
    }
    func nearestLine(at point: CGPoint) -> (drawing: Drawing?, cellItem: CellItem?, line: Line, lineIndex: Int, pointIndex: Int)? {
        guard let nearest = self.nearest(at: point, isWarp: false) else {
            return nil
        }
        if let e = nearest.drawingEdit {
            return (e.drawing, nil, e.line, e.lineIndex, e.pointIndex)
        } else if let e = nearest.cellItemEdit {
            return (nil, e.cellItem, e.geometry.lines[e.lineIndex], e.lineIndex, e.pointIndex)
        } else if nearest.drawingEditLineCap != nil || !nearest.cellItemEditLineCaps.isEmpty {
            if let b = nearest.bezierSortedResult(at: point) {
                return (b.drawing, b.cellItem, b.lineCap.line, b.lineCap.lineIndex, b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1)
            }
        }
        return nil
    }
    
    func draw(
        scene: Scene, viewType: Cut.ViewType = .preview,
        indicationCellItem: CellItem? = nil,
        editMaterial: Material? = nil, editZ: EditZ? = nil, editPoint: EditPoint? = nil, editTransform: EditTransform? = nil,
        with di: DrawInfo, in ctx: CGContext
    ) {
        _draw(scene: scene, viewType: viewType, indicationCellItem: indicationCellItem, editMaterial: editMaterial, editZ: editZ, editPoint: editPoint, editTransform: editTransform, with: di, in: ctx)
        
        children.forEach { $0.draw(scene: scene, viewType: viewType, indicationCellItem: indicationCellItem, editMaterial: editMaterial, editZ: editZ, editPoint: editPoint, editTransform: editTransform, with: di, in: ctx) }
    }
    
    private func _draw(
        scene: Scene, viewType: Cut.ViewType = .preview,
        indicationCellItem: CellItem? = nil,
        editMaterial: Material? = nil, editZ: EditZ? = nil, editPoint: EditPoint? = nil, editTransform: EditTransform? = nil,
        with di: DrawInfo, in ctx: CGContext
        ) {
        if viewType == .preview && transform.wiggle.isMove {
            let p = transform.wiggle.newPosition(CGPoint(), phase: wigglePhase/scene.frameRate.cf)
            ctx.translateBy(x: p.x, y: p.y)
        }
        
        func drawContents() {
            let isEdit = viewType != .preview && viewType != .editMaterial && viewType != .editingMaterial
            
            func drawAnimations() {
                if isEdit {
                    for animation in animations {
                        if !animation.isHidden {
                            if animation === editAnimation {
                                animation.drawingItem.drawEdit(with: di, in: ctx)
                            } else {
                                ctx.setAlpha(0.08)
                                animation.drawingItem.drawEdit(with: di, in: ctx)
                                ctx.setAlpha(1)
                            }
                        }
                    }
                } else {
                    var alpha = 1.0.cf
                    for animation in animations {
                        if !animation.isHidden {
                            ctx.setAlpha(alpha)
                            animation.drawingItem.draw(with: di, in: ctx)
                        }
                        alpha = max(alpha*0.4, 0.25)
                    }
                    ctx.setAlpha(1)
                }
            }
            
            for child in rootCell.children {
                child.draw(isEdit: isEdit, with: di, in: ctx)
            }
            drawAnimations()
            
            if isEdit {
                func drawMaterial(_ material: Material) {
                    rootCell.allCells { cell, stop in
                        if cell.material.id == material.id {
                            ctx.addPath(cell.geometry.path)
                        }
                    }
                    ctx.setLineWidth(3*di.reciprocalScale)
                    ctx.setLineJoin(.round)
                    ctx.setStrokeColor(Color.editMaterial.cgColor)
                    ctx.strokePath()
                    rootCell.allCells { cell, stop in
                        if cell.material.color == material.color && cell.material.id != material.id {
                            ctx.addPath(cell.geometry.path)
                        }
                    }
                    ctx.setLineWidth(3*di.reciprocalScale)
                    ctx.setLineJoin(.round)
                    ctx.setStrokeColor(Color.editMaterialColorOnly.cgColor)
                    ctx.strokePath()
                }
                
                for animation in animations {
                    if !animation.isHidden {
                        animation.drawSelectionCells(opacity: animation != editAnimation ? 0.5 : 1, with: di,  in: ctx)
                    }
                }
                if !editAnimation.isHidden {
                    let isMovePoint = viewType == .editPoint || viewType == .editVertex
                    
                    if let material = editMaterial {
                        drawMaterial(material)
                    }
                    
                    editAnimation.drawTransparentCellLines(with: di, in: ctx)
                    editAnimation.drawPreviousNext(
                        isShownPrevious: scene.isShownPrevious, isShownNext: scene.isShownNext,
                        time: time, with: di, in: ctx
                    )
                    
                    if !isMovePoint, let indicationCellItem = indicationCellItem, editAnimation.cellItems.contains(indicationCellItem) {
                        editAnimation.drawSkinCellItem(indicationCellItem, with: di, in: ctx)
                    }
                    if let editZ = editZ {
                        drawEditZ(editZ, with: di, in: ctx)
                    }
                    if isMovePoint {
                        drawEditPoints(with: editPoint, isEditVertex: viewType == .editVertex, di, in: ctx)
                    }
                    if let editTransform = editTransform {
                        if viewType == .editWarp {
                            drawWarp(with: editTransform, di, in: ctx)
                        } else if viewType == .editTransform {
                            drawTransform(with: editTransform, di, in: ctx)
                        }
                    }
                }
            }
        }
//        if let affine = transform.affineTransform {
            ctx.saveGState()
            ctx.concatenate(transform.affineTransform)
            drawContents()
            ctx.restoreGState()
//        } else {
//            drawContents()
//        }
        
        if viewType != .preview {
            drawCamera(scene.cameraFrame, in: ctx)
        }
        for animation in animations {
            if let text = animation.textItem?.text {
                text.draw(bounds: scene.cameraFrame, in: ctx)
            }
        }
    }
    
    func drawCamera(_ cameraFrame: CGRect, in ctx: CGContext) {
        func drawCameraBorder(bounds: CGRect, inColor: Color, outColor: Color) {
            ctx.setStrokeColor(inColor.cgColor)
            ctx.stroke(bounds.insetBy(dx: -0.5, dy: -0.5))
            ctx.setStrokeColor(outColor.cgColor)
            ctx.stroke(bounds.insetBy(dx: -1.5, dy: -1.5))
        }
        ctx.setLineWidth(1)
        if transform.wiggle.isMove {
            let maxSize = transform.wiggle.maxSize
            drawCameraBorder(
                bounds: cameraFrame.insetBy(dx: -maxSize.width, dy: -maxSize.height),
                inColor: Color.cameraBorder, outColor: Color.cutSubBorder
            )
        }
        let animation = editAnimation
        func drawPreviousNextCamera(t: Transform, color: Color) {
            let affine: CGAffineTransform
//            if let ca = transform.affineTransform {
                affine = transform.affineTransform.inverted().concatenating(t.affineTransform)
//            } else {
//                affine = t.affineTransform
//            }
            ctx.saveGState()
            ctx.concatenate(affine)
            drawCameraBorder(bounds: cameraFrame, inColor: color, outColor: Color.cutSubBorder)
            ctx.restoreGState()
            func strokeBounds() {
                ctx.move(to: CGPoint(x: cameraFrame.minX, y: cameraFrame.minY))
                ctx.addLine(to: CGPoint(x: cameraFrame.minX, y: cameraFrame.minY).applying(affine))
                ctx.move(to: CGPoint(x: cameraFrame.minX, y: cameraFrame.maxY))
                ctx.addLine(to: CGPoint(x: cameraFrame.minX, y: cameraFrame.maxY).applying(affine))
                ctx.move(to: CGPoint(x: cameraFrame.maxX, y: cameraFrame.minY))
                ctx.addLine(to: CGPoint(x: cameraFrame.maxX, y: cameraFrame.minY).applying(affine))
                ctx.move(to: CGPoint(x: cameraFrame.maxX, y: cameraFrame.maxY))
                ctx.addLine(to: CGPoint(x: cameraFrame.maxX, y: cameraFrame.maxY).applying(affine))
            }
            ctx.setStrokeColor(color.cgColor)
            strokeBounds()
            ctx.strokePath()
            ctx.setStrokeColor(Color.cutSubBorder.cgColor)
            strokeBounds()
            ctx.strokePath()
        }
        let keyframeIndex = animation.loopedKeyframeIndex(withTime: time)
        if keyframeIndex.interValue == 0 && keyframeIndex.index > 0 {
            if let t = animation.transformItem?.keyTransforms[keyframeIndex.index - 1], transform != t {
                drawPreviousNextCamera(t: t, color: Color.red)
            }
        }
        if let t = animation.transformItem?.keyTransforms[keyframeIndex.index], transform != t {
            drawPreviousNextCamera(t: t, color: Color.red)
        }
        if keyframeIndex.index < animation.keyframes.count - 1 {
            if let t = animation.transformItem?.keyTransforms[keyframeIndex.index + 1], transform != t {
                drawPreviousNextCamera(t: t, color: Color.green)
            }
        }
        drawCameraBorder(bounds: cameraFrame, inColor: Color.cutBorder, outColor: Color.cutSubBorder)
    }
    
    func drawStrokeLine(_ line: Line, lineColor: Color, lineWidth: CGFloat, in ctx: CGContext) {
//        if let affine = allParentsTransform.affineTransform {
            ctx.saveGState()
            ctx.concatenate(allParentsAffineTransform)
            ctx.setFillColor(lineColor.cgColor)
            line.draw(size: lineWidth, in: ctx)
            ctx.restoreGState()
//        } else {
//            ctx.setFillColor(lineColor.cgColor)
//            line.draw(size: lineWidth, in: ctx)
//        }
    }
    
    struct EditPoint: Equatable {
        let nearestLine: Line, nearestPointIndex: Int, lines: [Line], point: CGPoint, isSnap: Bool
        func draw(_ di: DrawInfo, in ctx: CGContext) {
            for line in lines {
                ctx.setFillColor((line === nearestLine ? Color.selection : Color.subSelection).cgColor)
                line.draw(size: 2*di.reciprocalScale, in: ctx)
            }
            point.draw(
                radius: 3*di.reciprocalScale, lineWidth: di.reciprocalScale,
                inColor: isSnap ? Color.snap : Color.selection, outColor: Color.controlPointIn, in: ctx
            )
        }
        static func == (lhs: EditPoint, rhs: EditPoint) -> Bool {
            return lhs.nearestLine == rhs.nearestLine && lhs.nearestPointIndex == rhs.nearestPointIndex
                && lhs.lines == rhs.lines && lhs.point == rhs.point && lhs.isSnap == lhs.isSnap
        }
    }
    private let editPointRadius = 0.5.cf, lineEditPointRadius = 1.5.cf, pointEditPointRadius = 3.0.cf
    func drawEditPoints(with editPoint: EditPoint?, isEditVertex: Bool, _ di: DrawInfo, in ctx: CGContext) {
        if let editPoint = editPoint, editPoint.isSnap {
            let p: CGPoint?, np: CGPoint?
            if editPoint.nearestPointIndex == 1 {
                p = editPoint.nearestLine.firstPoint
                np = editPoint.nearestLine.controls.count == 2 ? nil : editPoint.nearestLine.controls[2].point
            } else if editPoint.nearestPointIndex == editPoint.nearestLine.controls.count - 2 {
                p = editPoint.nearestLine.lastPoint
                np = editPoint.nearestLine.controls.count == 2 ? nil : editPoint.nearestLine.controls[editPoint.nearestLine.controls.count - 3].point
            } else {
                p = nil
                np = nil
            }
            if let p = p {
                func drawSnap(with point: CGPoint, capPoint: CGPoint) {
                    if let ps = CGPoint.boundsPointWithLine(ap: point, bp: capPoint, bounds: ctx.boundingBoxOfClipPath) {
                        ctx.move(to: ps.p0)
                        ctx.addLine(to: ps.p1)
                        ctx.setLineWidth(1*di.reciprocalScale)
                        ctx.setStrokeColor(Color.selection.cgColor)
                        ctx.strokePath()
                    }
                    if let np = np, editPoint.nearestLine.controls.count > 2 {
                        let p1 = editPoint.nearestPointIndex == 1 ? editPoint.nearestLine.controls[1].point : editPoint.nearestLine.controls[editPoint.nearestLine.controls.count - 2].point
                        ctx.move(to: p1.mid(np))
                        ctx.addLine(to: p1)
                        ctx.addLine(to: capPoint)
                        ctx.setLineWidth(0.5*di.reciprocalScale)
                        ctx.setStrokeColor(Color.selection.cgColor)
                        ctx.strokePath()
                        p1.draw(radius: 2*di.reciprocalScale, lineWidth: di.reciprocalScale, inColor: Color.selection, outColor: Color.controlPointIn, in: ctx)
                    }
                }
                func drawSnap(with lines: [Line]) {
                    for line in lines {
                        if line != editPoint.nearestLine {
                            if editPoint.nearestLine.controls.count == 3 {
                                if line.firstPoint == editPoint.nearestLine.firstPoint {
                                    drawSnap(with: line.controls[1].point, capPoint: editPoint.nearestLine.firstPoint)
                                } else if line.lastPoint == editPoint.nearestLine.firstPoint {
                                    drawSnap(with: line.controls[line.controls.count - 2].point, capPoint: editPoint.nearestLine.firstPoint)
                                }
                                if line.firstPoint == editPoint.nearestLine.lastPoint {
                                    drawSnap(with: line.controls[1].point, capPoint: editPoint.nearestLine.lastPoint)
                                } else if line.lastPoint == editPoint.nearestLine.lastPoint {
                                    drawSnap(with: line.controls[line.controls.count - 2].point, capPoint: editPoint.nearestLine.lastPoint)
                                }
                            } else {
                                if line.firstPoint == p {
                                    drawSnap(with: line.controls[1].point, capPoint: p)
                                } else if line.lastPoint == p {
                                    drawSnap(with: line.controls[line.controls.count - 2].point, capPoint: p)
                                }
                            }
                        }
                    }
                }
                drawSnap(with: editAnimation.drawingItem.drawing.lines)
                for cellItem in editAnimation.cellItems {
                    drawSnap(with: cellItem.cell.lines)
                }
            }
        }
        editPoint?.draw(di, in: ctx)
        
        var capPointDic = [CGPoint: Bool]()
        func updateCapPointDic(with lines: [Line]) {
            for line in lines {
                let fp = line.firstPoint, lp = line.lastPoint
                if capPointDic[fp] != nil {
                    capPointDic[fp] = true
                } else {
                    capPointDic[fp] = false
                }
                if capPointDic[lp] != nil {
                    capPointDic[lp] = true
                } else {
                    capPointDic[lp] = false
                }
            }
        }
        if !editAnimation.cellItems.isEmpty {
            for cellItem in editAnimation.cellItems {
                if !cellItem.cell.isEditHidden {
                    if !isEditVertex {
                        Line.drawEditPointsWith(lines: cellItem.cell.lines, with: di, in: ctx)
                    }
                    updateCapPointDic(with: cellItem.cell.lines)
                }
            }
        }
        if !isEditVertex {
            Line.drawEditPointsWith(lines: editAnimation.drawingItem.drawing.lines, with: di, in: ctx)
        }
        updateCapPointDic(with: editAnimation.drawingItem.drawing.lines)
        
        let r = lineEditPointRadius*di.reciprocalScale, lw = 0.5*di.reciprocalScale
        for v in capPointDic {
            v.key.draw(
                radius: r, lineWidth: lw,
                inColor: v.value ? .controlPointJointIn : Color.controlPointCapIn, outColor: Color.controlPointOut, in: ctx
            )
        }
    }
    
    struct EditZ: Equatable {
        let cell: Cell, point: CGPoint, firstPoint: CGPoint
        static func == (lhs: EditZ, rhs: EditZ) -> Bool {
            return lhs.cell == rhs.cell && lhs.point == rhs.point && lhs.firstPoint == rhs.firstPoint
        }
    }
    let editZHeight = 5.0.cf
    func drawEditZ(_ editZ: EditZ, with di: DrawInfo, in ctx: CGContext) {
        rootCell.depthFirstSearch(duplicate: true) { parent, cell in
            if cell === editZ.cell, let index = parent.children.index(of: cell) {
                if !parent.isEmptyGeometry {
                    parent.clip(in: ctx) {
                        Cell.drawCellPaths(cells: Array(parent.children[index + 1 ..< parent.children.count]), color: Color.moveZ, in: ctx)
                    }
                } else {
                    Cell.drawCellPaths(cells: Array(parent.children[index + 1 ..< parent.children.count]), color: Color.moveZ, in: ctx)
                }
            }
        }
        //        rootCell.depthFirstSearch(duplicate: true) { parent, cell in
        //            if cell === editZ.cell, let index = parent.children.index(of: cell) {
        //                var y = editZ.point.y
        //                parent.children.forEach {
        //                    $0
        //                }
        //                
        //            }
        //        }
    }
    
    struct EditTransform: Equatable {
        let rotateRect: RotateRect, anchorPoint: CGPoint, point: CGPoint, oldPoint: CGPoint
        func withPoint(_ point: CGPoint) -> EditTransform {
            return EditTransform(rotateRect: rotateRect, anchorPoint: anchorPoint, point: point, oldPoint: oldPoint)
        }
        static func == (lhs: EditTransform, rhs: EditTransform) -> Bool {
            return lhs.rotateRect == rhs.rotateRect && lhs.anchorPoint == rhs.anchorPoint && lhs.point == rhs.point && lhs.oldPoint == lhs.oldPoint
        }
    }
    func warpAffineTransform(with et: EditTransform) -> CGAffineTransform {
        guard et.oldPoint != et.anchorPoint else {
            return CGAffineTransform.identity
        }
        let theta = et.oldPoint.tangential(et.anchorPoint)
        let angle = theta < 0 ? theta + .pi : theta - .pi
        var pAffine = CGAffineTransform(rotationAngle: -angle)
        pAffine = pAffine.translatedBy(x: -et.anchorPoint.x, y: -et.anchorPoint.y)
        let newOldP = et.oldPoint.applying(pAffine), newP = et.point.applying(pAffine)
        let scaleX = newP.x/newOldP.x, skewY = (newP.y - newOldP.y)/newOldP.x
        var affine = CGAffineTransform(translationX: et.anchorPoint.x, y: et.anchorPoint.y)
        affine = affine.rotated(by: angle)
        affine = affine.scaledBy(x: scaleX, y: 1)
        if skewY != 0 {
            affine = CGAffineTransform(a: 1, b: skewY, c: 0, d: 1, tx: 0, ty: 0).concatenating(affine)
        }
        affine = affine.rotated(by: -angle)
        return affine.translatedBy(x: -et.anchorPoint.x, y: -et.anchorPoint.y)
    }
    func transformAffineTransform(with et: EditTransform) -> CGAffineTransform {
        guard et.oldPoint != et.anchorPoint else {
            return CGAffineTransform.identity
        }
        let r = et.point.distance(et.anchorPoint), oldR = et.oldPoint.distance(et.anchorPoint)
        let scale = r/oldR
        var affine = CGAffineTransform(translationX: et.anchorPoint.x, y: et.anchorPoint.y)
        affine = affine.rotated(by: et.anchorPoint.tangential(et.point).differenceRotation(et.anchorPoint.tangential(et.oldPoint)))
        affine = affine.scaledBy(x: scale, y: scale)
        affine = affine.translatedBy(x: -et.anchorPoint.x, y: -et.anchorPoint.y)
        return affine
    }
    func drawWarp(with et: EditTransform, _ di: DrawInfo, in ctx: CGContext) {
        drawLine(firstPoint: et.anchorPoint, lastPoint: et.point, di, in: ctx)
        
        drawRotateRect(with: et, di, in: ctx)
        et.anchorPoint.draw(radius: lineEditPointRadius*di.reciprocalScale, lineWidth: di.reciprocalScale, in: ctx)
    }
    func drawTransform(with et: EditTransform, _ di: DrawInfo, in ctx: CGContext) {
        ctx.setAlpha(0.5)
        drawLine(firstPoint: et.anchorPoint, lastPoint: et.oldPoint, di, in: ctx)
        drawCircleWith(radius: et.oldPoint.distance(et.anchorPoint), anchorPoint: et.anchorPoint, di, in: ctx)
        ctx.setAlpha(1)
        drawLine(firstPoint: et.anchorPoint, lastPoint: et.point, di, in: ctx)
        drawCircleWith(radius: et.point.distance(et.anchorPoint), anchorPoint: et.anchorPoint, di, in: ctx)
        
        drawRotateRect(with: et, di, in: ctx)
        et.anchorPoint.draw(radius: lineEditPointRadius*di.reciprocalScale, lineWidth: di.reciprocalScale, in: ctx)
    }
    func drawRotateRect(with et: EditTransform, _ di: DrawInfo, in ctx: CGContext) {
        ctx.setLineWidth(di.reciprocalScale)
        ctx.setStrokeColor(Color.camera.cgColor)
        ctx.saveGState()
        ctx.concatenate(et.rotateRect.affineTransform)
        ctx.stroke(CGRect(x: 0, y: 0, width: et.rotateRect.size.width, height: et.rotateRect.size.height))
        ctx.restoreGState()
    }
    
    func drawCircleWith(radius r: CGFloat, anchorPoint: CGPoint, _ di: DrawInfo, in ctx: CGContext) {
        let cb = CGRect(x: anchorPoint.x - r, y: anchorPoint.y - r, width: r*2, height: r*2)
        let outLineWidth = 3*di.reciprocalScale, inLineWidth = 1.5*di.reciprocalScale
        ctx.setLineWidth(outLineWidth)
        ctx.setStrokeColor(Color.controlPointOut.cgColor)
        ctx.strokeEllipse(in: cb)
        ctx.setLineWidth(inLineWidth)
        ctx.setStrokeColor(Color.controlPointIn.cgColor)
        ctx.strokeEllipse(in: cb)
    }
    func drawLine(firstPoint: CGPoint, lastPoint: CGPoint, _ di: DrawInfo, in ctx: CGContext) {
        let outLineWidth = 3*di.reciprocalScale, inLineWidth = 1.5*di.reciprocalScale
        ctx.setLineWidth(outLineWidth)
        ctx.setStrokeColor(Color.controlPointOut.cgColor)
        ctx.move(to: firstPoint)
        ctx.addLine(to: lastPoint)
        ctx.strokePath()
        ctx.setLineWidth(inLineWidth)
        ctx.setStrokeColor(Color.controlPointIn.cgColor)
        ctx.move(to: firstPoint)
        ctx.addLine(to: lastPoint)
        ctx.strokePath()
    }
}
