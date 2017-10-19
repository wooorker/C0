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
//カメラと変形の統合
//「揺れ」の振動数の設定

import Foundation

final class Cut: NSObject, ClassCopyData {
    static let type = ObjectType(identifier: "Cut", name: Localization(english: "Cut", japanese: "カット"))
    enum ViewType: Int32 {
        case edit, editPoint, editWarpLine, editSnap, editWarp, editTransform, editMoveZ, editMaterial, editingMaterial, preview
    }
    struct Camera {
        let transform: Transform, wigglePhase: CGFloat, affineTransform: CGAffineTransform?
        
        init(bounds: CGRect, time: Int, groups: [Group]) {
            var position = CGPoint(), scale = CGSize(), rotation = 0.0.cf, wiggleSize = CGSize(), hz = 0.0.cf, phase = 0.0.cf, transformCount = 0.0
            for group in groups {
                if let t = group.transformItem?.transform {
                    position.x += t.position.x
                    position.y += t.position.y
                    scale.width += t.scale.width
                    scale.height += t.scale.height
                    rotation += t.rotation
                    wiggleSize.width += t.wiggle.maxSize.width
                    wiggleSize.height += t.wiggle.maxSize.height
                    hz += t.wiggle.hz
                    phase += group.wigglePhaseWith(time: time, lastHz: t.wiggle.hz)
                    transformCount += 1
                }
            }
            if transformCount > 0 {
                let reciprocalTransformCount = 1/transformCount.cf
                let wiggle = Wiggle(maxSize: wiggleSize, hz: hz*reciprocalTransformCount)
                transform = Transform(position: position, scale: scale, rotation: rotation, wiggle: wiggle)
                wigglePhase = phase*reciprocalTransformCount
                affineTransform = transform.isEmpty ? nil : transform.affineTransform(with: bounds)
            } else {
                transform = Transform()
                wigglePhase = 0
                affineTransform = nil
            }
        }
    }
    
    var rootCell: Cell, groups: [Group]
    var editGroup: Group {
        didSet {
            for cellItem in oldValue.cellItems {
                cellItem.cell.isLocked = true
            }
            for cellItem in editGroup.cellItems {
                cellItem.cell.isLocked = false
            }
        }
    }
    var time = 0 {
        didSet {
            for group in groups {
                group.update(withTime: time)
            }
            updateCamera()
        }
    }
    var timeLength: Int {
        didSet {
            for group in groups {
                group.timeLength = timeLength
            }
        }
    }
    var cameraBounds: CGRect {
        didSet {
            updateCamera()
        }
    }
    private(set) var camera: Camera, cells: [Cell]
    func updateCamera() {
        camera = Camera(bounds: cameraBounds, time: time, groups: groups)
    }
    
    func insertCell(_ cellItem: CellItem, in parents: [(cell: Cell, index: Int)], _ group: Group) {
        if !cellItem.cell.children.isEmpty {
            fatalError()
        }
        if cellItem.keyGeometries.count != group.keyframes.count {
            fatalError()
        }
        if cells.contains(cellItem.cell) || group.cellItems.contains(cellItem) {
            fatalError()
        }
        for parent in parents {
            parent.cell.children.insert(cellItem.cell, at: parent.index)
        }
        cells.append(cellItem.cell)
        group.cellItems.append(cellItem)
    }
    func insertCells(_ cellItems: [CellItem], rootCell: Cell, at index: Int, in parent: Cell, _ group: Group) {
        for cell in rootCell.children.reversed() {
            parent.children.insert(cell, at: index)
        }
        for cellItem in cellItems {
            if cellItem.keyGeometries.count != group.keyframes.count {
                fatalError()
            }
            if cells.contains(cellItem.cell) || group.cellItems.contains(cellItem) {
                fatalError()
            }
            cells.append(cellItem.cell)
            group.cellItems.append(cellItem)
        }
    }
    func removeCell(_ cellItem: CellItem, in parents: [(cell: Cell, index: Int)], _ group: Group) {
        if !cellItem.cell.children.isEmpty {
            fatalError()
        }
        for parent in parents {
            parent.cell.children.remove(at: parent.index)
        }
        cells.remove(at: cells.index(of: cellItem.cell)!)
        group.cellItems.remove(at: group.cellItems.index(of: cellItem)!)
    }
    func removeCells(_ cellItems: [CellItem], rootCell: Cell, in parent: Cell, _ group: Group) {
        for cell in rootCell.children {
            parent.children.remove(at: parent.children.index(of: cell)!)
        }
        for cellItem in cellItems {
            cells.remove(at: cells.index(of: cellItem.cell)!)
            group.cellItems.remove(at: group.cellItems.index(of: cellItem)!)
        }
    }
    
    struct CellRemoveManager {
        let groupAndCellItems: [(group: Group, cellItems: [CellItem])]
        let rootCell: Cell
        let parents: [(cell: Cell, index: Int)]
        func contains(_ cellItem: CellItem) -> Bool {
            for gac in groupAndCellItems {
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
        var groupAndCellItems = [(group: Group, cellItems: [CellItem])]()
        for group in groups {
            var cellItems = [CellItem]()
            cells = cells.filter {
                if let removeCellItem = group.cellItem(with: $0) {
                    cellItems.append(removeCellItem)
                    return false
                }
                return true
            }
            if !cellItems.isEmpty {
                groupAndCellItems.append((group, cellItems))
            }
        }
        if groupAndCellItems.isEmpty {
            fatalError()
        }
        return CellRemoveManager(groupAndCellItems: groupAndCellItems, rootCell: cellItem.cell, parents: rootCell.parents(with: cellItem.cell))
    }
    func insertCell(with crm: CellRemoveManager) {
        for parent in crm.parents {
            parent.cell.children.insert(crm.rootCell, at: parent.index)
        }
        for gac in crm.groupAndCellItems {
            for cellItem in gac.cellItems {
                if cellItem.keyGeometries.count != gac.group.keyframes.count {
                    fatalError()
                }
                if cells.contains(cellItem.cell) || gac.group.cellItems.contains(cellItem) {
                    fatalError()
                }
                cells.append(cellItem.cell)
                gac.group.cellItems.append(cellItem)
            }
        }
    }
    func removeCell(with crm: CellRemoveManager) {
        for parent in crm.parents {
            parent.cell.children.remove(at: parent.index)
        }
        for gac in crm.groupAndCellItems {
            for cellItem in gac.cellItems {
                cells.remove(at:  cells.index(of: cellItem.cell)!)
                gac.group.cellItems.remove(at: gac.group.cellItems.index(of: cellItem)!)
            }
        }
    }
    
    init(rootCell: Cell = Cell(material: Material(color: Color.white)), groups: [Group] = [Group](), editGroup: Group = Group(), time: Int = 0, timeLength: Int = 24, cameraBounds: CGRect = CGRect(x: 0, y: 0, width: 640, height: 360)) {
        self.rootCell = rootCell
        self.groups = groups.isEmpty ? [editGroup] : groups
        self.editGroup = editGroup
        self.time = time
        self.timeLength = timeLength
        self.cameraBounds = cameraBounds
        editGroup.timeLength = timeLength
        self.camera = Camera(bounds: cameraBounds, time: time, groups: groups)
        self.cells = groups.reduce([Cell]()) { $0 + $1.cells }
        super.init()
    }
    init(rootCell: Cell, groups: [Group], editGroup: Group, time: Int, timeLength: Int, cameraBounds: CGRect, cells: [Cell]) {
        self.rootCell = rootCell
        self.groups = groups
        self.editGroup = editGroup
        self.time = time
        self.timeLength = timeLength
        self.cameraBounds = cameraBounds
        self.cells = cells
        self.camera = Camera(bounds: cameraBounds, time: time, groups: groups)
        super.init()
    }
    private init(rootCell: Cell, groups: [Group], editGroup: Group, time: Int, timeLength: Int, cameraBounds: CGRect, cells: [Cell], camera: Camera) {
        self.rootCell = rootCell
        self.groups = groups
        self.editGroup = editGroup
        self.time = time
        self.timeLength = timeLength
        self.cameraBounds = cameraBounds
        self.cells = cells
        self.camera = camera
        super.init()
    }
    
    static let rootCellKey = "0", groupsKey = "1", editGroupKey = "2", timeKey = "3", timeLengthKey = "4", cameraBoundsKey = "5", cellsKey = "6"
    init?(coder: NSCoder) {
        rootCell = coder.decodeObject(forKey: Cut.rootCellKey) as? Cell ?? Cell()
        groups = coder.decodeObject(forKey: Cut.groupsKey) as? [Group] ?? []
        editGroup = coder.decodeObject(forKey: Cut.editGroupKey) as? Group ?? Group()
        time = coder.decodeInteger(forKey: Cut.timeKey)
        timeLength = coder.decodeInteger(forKey: Cut.timeLengthKey)
        cameraBounds = coder.decodeRect(forKey: Cut.cameraBoundsKey)
        cells = coder.decodeObject(forKey: Cut.cellsKey) as? [Cell] ?? []
        camera = Camera(bounds: cameraBounds, time: time, groups: groups)
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(rootCell, forKey: Cut.rootCellKey)
        coder.encode(groups, forKey: Cut.groupsKey)
        coder.encode(editGroup, forKey: Cut.editGroupKey)
        coder.encode(time, forKey: Cut.timeKey)
        coder.encode(timeLength, forKey: Cut.timeLengthKey)
        coder.encode(cameraBounds, forKey: Cut.cameraBoundsKey)
        coder.encode(cells, forKey: Cut.cellsKey)
    }
    var cellIDDictionary: [UUID: Cell] {
        var dic = [UUID: Cell]()
        for cell in cells {
            dic[cell.id] = cell
        }
        return dic
    }
    var materialCellIDs: [MaterialCellID] {
        get {
            var materialCellIDDictionary = [UUID: MaterialCellID]()
            for cell in cells {
                if let mci = materialCellIDDictionary[cell.material.id] {
                    mci.cellIDs.append(cell.id)
                } else {
                    materialCellIDDictionary[cell.material.id] = MaterialCellID(material: cell.material, cellIDs: [cell.id])
                }
            }
            return Array(materialCellIDDictionary.values)
        }
        set {
            let cellIDDictionary = self.cellIDDictionary
            for materialCellID in newValue {
                for cellId in materialCellID.cellIDs {
                    cellIDDictionary[cellId]?.material = materialCellID.material
                }
            }
        }
    }
    
    var deepCopy: Cut {
        let copyRootCell = rootCell.noResetDeepCopy, copyCells = cells.map { $0.noResetDeepCopy }, copyGroups = groups.map() { $0.deepCopy }
        let copyGroup = copyGroups[groups.index(of: editGroup)!]
        rootCell.resetCopyedCell()
        return Cut(rootCell: copyRootCell, groups: copyGroups, editGroup: copyGroup, time: time, timeLength: timeLength, cameraBounds: cameraBounds, cells: copyCells, camera: camera)
    }
    
    var allEditSelectionCellItemsWithNoEmptyGeometry: [CellItem] {
        return groups.reduce([CellItem]()) {
            $0 + $1.editSelectionCellItemsWithNoEmptyGeometry
        }
    }
    var allEditSelectionCellsWithNoEmptyGeometry: [Cell] {
        return groups.reduce([Cell]()) {
            $0 + $1.editSelectionCellsWithNoEmptyGeometry
        }
    }
    var editGroupIndex: Int {
        return groups.index(of: editGroup) ?? 0
    }
    
    enum IndicationCellType {
        case none, indication, selection
    }
    func indicationCellsTuple(with  point: CGPoint, reciprocalScale: CGFloat, usingLock: Bool = true) -> (cells: [Cell], type: IndicationCellType) {
        if usingLock {
            let allEditSelectionCells = editGroup.editSelectionCellsWithNoEmptyGeometry
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
    func selectionTuples(with point: CGPoint, reciprocalScale: CGFloat, usingLock: Bool = true) -> [(group: Group, cellItem: CellItem, geometry: Geometry)] {
        let indicationCellsTuple = self.indicationCellsTuple(with: point, reciprocalScale: reciprocalScale, usingLock: usingLock)
        return indicationCellsTuple.cells.map {
            let gc = groupAndCellItem(with: $0)
            return (group: gc.group, cellItem: gc.cellItem, geometry: $0.geometry)
        }
    }
    
    func group(with cell: Cell) -> Group {
        for group in groups {
            if group.contains(cell) {
                return group
            }
        }
        fatalError()
    }
    func groupAndCellItem(with cell: Cell) -> (group: Group, cellItem: CellItem) {
        for group in groups {
            if let cellItem = group.cellItem(with: cell) {
                return (group, cellItem)
            }
        }
        fatalError()
    }
    @nonobjc func group(with cellItem: CellItem) -> Group {
        for group in groups {
            if group.contains(cellItem) {
                return group
            }
        }
        fatalError()
    }
    func isInterpolatedKeyframe(with group: Group) -> Bool {
        let keyIndex = group.loopedKeyframeIndex(withTime: time)
        return group.editKeyframe.interpolation != .none && keyIndex.interValue != 0 && keyIndex.index != group.keyframes.count - 1
    }
    func isContainsKeyframe(with group: Group) -> Bool {
        let keyIndex = group.loopedKeyframeIndex(withTime: time)
        return keyIndex.interValue == 0
    }
    var maxTime: Int {
        return groups.reduce(0) {
            max($0, $1.keyframes.last?.time ?? 0)
        }
    }
    func maxTimeWithOtherGroup(_ group: Group) -> Int {
        return groups.reduce(0) {
            $1 !== group ? max($0, $1.keyframes.last?.time ?? 0) : $0
        }
    }
    func cellItem(at point: CGPoint, reciprocalScale: CGFloat, with group: Group) -> CellItem? {
        if let cell = rootCell.at(point, reciprocalScale: reciprocalScale) {
            let gc = groupAndCellItem(with: cell)
            return gc.group == group ? gc.cellItem : nil
        } else {
            return nil
        }
    }
    var imageBounds: CGRect {
        return groups.reduce(rootCell.imageBounds) { $0.unionNoEmpty($1.imageBounds) }//no
    }
    
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
    func nearest(at point: CGPoint, isWarp: Bool, isUseCells: Bool) -> Nearest? {
        var minD = CGFloat.infinity, minDrawing: Drawing?, minCellItem: CellItem?, minLine: Line?, minLineIndex = 0, minPointIndex = 0, minPoint = CGPoint()
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
        
        if nearestEditPoint(from: editGroup.drawingItem.drawing.lines) {
            minDrawing = editGroup.drawingItem.drawing
        }
        if isUseCells {
            for cellItem in editGroup.cellItems {
                if nearestEditPoint(from: cellItem.cell.lines) {
                    minDrawing = nil
                    minCellItem = cellItem
                }
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
                let drawingCaps = caps(with: minPoint, editGroup.drawingItem.drawing.lines)
                let drawingResult: (drawing: Drawing, lines: [Line], drawingCaps: [LineCap])? = drawingCaps.isEmpty ? nil : (editGroup.drawingItem.drawing, editGroup.drawingItem.drawing.lines, drawingCaps)
                let cellResults: [(cellItem: CellItem, geometry: Geometry, caps: [LineCap])] = editGroup.cellItems.flatMap {
                    let aCaps = caps(with: minPoint, $0.cell.geometry.lines)
                    return aCaps.isEmpty ? nil : ($0, $0.cell.geometry, aCaps)
                }
                return Nearest(drawingEdit: nil, cellItemEdit: nil, drawingEditLineCap: drawingResult, cellItemEditLineCaps: cellResults, point: minPoint)
            } else {
                if let drawing = minDrawing {
                    return Nearest(drawingEdit: (drawing, minLine, minLineIndex, minPointIndex), cellItemEdit: nil, drawingEditLineCap: nil, cellItemEditLineCaps: [], point: minPoint)
                } else if let cellItem = minCellItem {
                    return Nearest(drawingEdit: nil, cellItemEdit: (cellItem, cellItem.cell.geometry, minLineIndex, minPointIndex), drawingEditLineCap: nil, cellItemEditLineCaps: [], point: minPoint)
                }
            }
        }
        return nil
    }
    func nearestLine(at point: CGPoint, isUseCells: Bool) -> (drawing: Drawing?, cellItem: CellItem?, line: Line, lineIndex: Int, pointIndex: Int)? {
        guard let nearest = self.nearest(at: point, isWarp: false, isUseCells: isUseCells) else {
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
    
    func draw(_ scene: Scene, viewType: Cut.ViewType = .preview, editMaterial: Material? = nil, indicationCellItem: CellItem? = nil, moveZCell: Cell? = nil, editPoint: EditPoint? = nil, editTransform: EditTransform? = nil, isShownPrevious: Bool = false, isShownNext: Bool = false, with di: DrawInfo, in ctx: CGContext) {
        if viewType == .preview && camera.transform.wiggle.isMove {
            let p = camera.transform.wiggle.newPosition(CGPoint(), phase: camera.wigglePhase/scene.frameRate.cf)
            ctx.translateBy(x: p.x, y: p.y)
        }
        if let affine = camera.affineTransform {
            ctx.saveGState()
            ctx.concatenate(affine)
            drawContents(scene, viewType: viewType, editMaterial: editMaterial, indicationCellItem: indicationCellItem, moveZCell: moveZCell, editPoint: editPoint, editTransform: editTransform, isShownPrevious: isShownPrevious, isShownNext: isShownNext, with: di, in: ctx)
            ctx.restoreGState()
        } else {
            drawContents(scene, viewType: viewType, editMaterial: editMaterial, indicationCellItem: indicationCellItem, moveZCell: moveZCell, editPoint: editPoint, editTransform: editTransform, isShownPrevious: isShownPrevious, isShownNext: isShownNext, with: di, in: ctx)
        }
        if viewType != .preview {
            drawCamera(cameraBounds, in: ctx)
        }
        for group in groups {
            if let text = group.textItem?.text {
                text.draw(bounds: cameraBounds, in: ctx)
            }
        }
    }
    private func drawContents(_ scene: Scene, viewType: Cut.ViewType, editMaterial: Material?, indicationCellItem: CellItem? = nil, moveZCell: Cell?, editPoint: EditPoint? = nil, editTransform: EditTransform? = nil, isShownPrevious: Bool, isShownNext: Bool, with di: DrawInfo, in ctx: CGContext) {
        let isEdit = viewType != .preview && viewType != .editMaterial && viewType != .editingMaterial
        
        func drawGroups() {
            if isEdit {
                for group in groups {
                    if !group.isHidden {
                        if group === editGroup {
                            group.drawingItem.drawEdit(with: di, in: ctx)
                        } else {
                            ctx.setAlpha(0.08)
                            group.drawingItem.drawEdit(with: di, in: ctx)
                            ctx.setAlpha(1)
                        }
                    }
                }
            } else {
                var alpha = 1.0.cf
                for group in groups {
                    if !group.isHidden {
                        ctx.setAlpha(alpha)
                        group.drawingItem.draw(with: di, in: ctx)
                    }
                    alpha = max(alpha*0.4, 0.25)
                }
                ctx.setAlpha(1)
            }
        }
        
        for child in rootCell.children {
            child.draw(isEdit: isEdit, with: di, in: ctx)
        }
        drawGroups()
        
        if isEdit {
            func drawZCell(zCell: Cell) {
                rootCell.depthFirstSearch(duplicate: true, handler: { parent, cell in
                    if cell === zCell, let index = parent.children.index(of: cell) {
                        if !parent.isEmptyGeometry {
                            parent.clip(in: ctx) {
                                Cell.drawCellPaths(cells: Array(parent.children[index + 1 ..< parent.children.count]), color: SceneDefaults.moveZColor, in: ctx)
                            }
                        } else {
                            Cell.drawCellPaths(cells: Array(parent.children[index + 1 ..< parent.children.count]), color: SceneDefaults.moveZColor, in: ctx)
                        }
                    }
                })
            }
            func drawMaterial(_ material: Material) {
                rootCell.allCells { cell, stop in
                    if cell.material == material {
                        ctx.addPath(cell.geometry.path)
                    }
                }
                ctx.setLineWidth(3*di.reciprocalScale)
                ctx.setLineJoin(.round)
                ctx.setStrokeColor(SceneDefaults.editMaterialColor)
                ctx.strokePath()
            }
            
            for group in groups {
                if !group.isHidden {
                    group.drawSelectionCells(opacity: group != editGroup ? 0.5 : 1, with: di,  in: ctx)
                }
            }
            if !editGroup.isHidden {
                let isMovePoint = viewType == .editPoint || viewType == .editSnap || viewType == .editWarpLine
                
                if let material = editMaterial {
                    drawMaterial(material)
                }
                
                editGroup.drawTransparentCellLines(with: di, in: ctx)
                editGroup.drawPreviousNext(isShownPrevious: isShownPrevious, isShownNext: isShownNext, time: time, with: di, in: ctx)
                
                if !isMovePoint, let indicationCellItem = indicationCellItem, editGroup.cellItems.contains(indicationCellItem) {
                    editGroup.drawSkinCellItem(indicationCellItem, with: di, in: ctx)
                }
                if let moveZCell = moveZCell {
                    drawZCell(zCell: moveZCell)
                }
                if isMovePoint {
                    drawEditPointsWith(editPoint: editPoint, isSnap: viewType == .editSnap, isWarp: viewType == .editWarpLine, di, in: ctx)
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
    
    func drawCamera(_ cameraBounds: CGRect, in ctx: CGContext) {
        func drawCameraBorder(bounds: CGRect, inColor: CGColor, outColor: CGColor) {
            ctx.setStrokeColor(inColor)
            ctx.stroke(bounds.insetBy(dx: -0.5, dy: -0.5))
            ctx.setStrokeColor(outColor)
            ctx.stroke(bounds.insetBy(dx: -1.5, dy: -1.5))
        }
        ctx.setLineWidth(1)
        if camera.transform.wiggle.isMove {
            let maxSize = camera.transform.wiggle.maxSize
            drawCameraBorder(bounds: cameraBounds.insetBy(dx: -maxSize.width, dy: -maxSize.height), inColor: SceneDefaults.cameraBorderColor, outColor: SceneDefaults.cutSubBorderColor)
        }
        let group = editGroup
        func drawPreviousNextCamera(t: Transform, color: CGColor) {
            let affine: CGAffineTransform
            if let ca = camera.affineTransform {
                affine = ca.inverted().concatenating(t.affineTransform(with: cameraBounds))
            } else {
                affine = t.affineTransform(with: cameraBounds)
            }
            ctx.saveGState()
            ctx.concatenate(affine)
            drawCameraBorder(bounds: cameraBounds, inColor: color, outColor: SceneDefaults.cutSubBorderColor)
            ctx.restoreGState()
            func strokeBounds() {
                ctx.move(to: CGPoint(x: cameraBounds.minX, y: cameraBounds.minY))
                ctx.addLine(to: CGPoint(x: cameraBounds.minX, y: cameraBounds.minY).applying(affine))
                ctx.move(to: CGPoint(x: cameraBounds.minX, y: cameraBounds.maxY))
                ctx.addLine(to: CGPoint(x: cameraBounds.minX, y: cameraBounds.maxY).applying(affine))
                ctx.move(to: CGPoint(x: cameraBounds.maxX, y: cameraBounds.minY))
                ctx.addLine(to: CGPoint(x: cameraBounds.maxX, y: cameraBounds.minY).applying(affine))
                ctx.move(to: CGPoint(x: cameraBounds.maxX, y: cameraBounds.maxY))
                ctx.addLine(to: CGPoint(x: cameraBounds.maxX, y: cameraBounds.maxY).applying(affine))
            }
            ctx.setStrokeColor(color)
            strokeBounds()
            ctx.strokePath()
            ctx.setStrokeColor(SceneDefaults.cutSubBorderColor)
            strokeBounds()
            ctx.strokePath()
        }
        let keyframeIndex = group.loopedKeyframeIndex(withTime: time)
        if keyframeIndex.interValue == 0 && keyframeIndex.index > 0 {
            if let t = group.transformItem?.keyTransforms[keyframeIndex.index - 1], camera.transform != t {
                drawPreviousNextCamera(t: t, color: CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            }
        }
        if let t = group.transformItem?.keyTransforms[keyframeIndex.index], camera.transform != t {
            drawPreviousNextCamera(t: t, color: CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        }
        if keyframeIndex.index < group.keyframes.count - 1 {
            if let t = group.transformItem?.keyTransforms[keyframeIndex.index + 1], camera.transform != t {
                drawPreviousNextCamera(t: t, color: CGColor(red: 0, green: 1, blue: 0, alpha: 1))
            }
        }
        drawCameraBorder(bounds: cameraBounds, inColor: SceneDefaults.cutBorderColor, outColor: SceneDefaults.cutSubBorderColor)
    }
    
    func drawStrokeLine(_ line: Line, lineColor: CGColor, lineWidth: CGFloat, in ctx: CGContext) {
        if let affine = camera.affineTransform {
            ctx.saveGState()
            ctx.concatenate(affine)
        }
        ctx.setFillColor(lineColor)
        line.draw(size: lineWidth, in: ctx)
        if camera.affineTransform != nil {
            ctx.restoreGState()
        }
    }
    
    struct EditPoint: Equatable {
        let nearestLine: Line, nearestPointIndex: Int, lines: [Line], point: CGPoint, isSnap: Bool
        func draw(_ di: DrawInfo, in ctx: CGContext) {
            for line in lines {
                ctx.setFillColor(line === nearestLine ? SceneDefaults.selectionColor : SceneDefaults.subSelectionColor)
                line.draw(size: 2*di.reciprocalScale, in: ctx)
            }
            point.draw(radius: 3*di.reciprocalScale, lineWidth: di.reciprocalScale, inColor: isSnap ? SceneDefaults.snapColor : SceneDefaults.selectionColor, outColor: SceneDefaults.controlPointInColor, in: ctx)
        }
        static func == (lhs: EditPoint, rhs: EditPoint) -> Bool {
            return lhs.nearestLine == rhs.nearestLine && lhs.nearestPointIndex == rhs.nearestPointIndex
                && lhs.lines == rhs.lines && lhs.point == rhs.point && lhs.isSnap == lhs.isSnap
        }
    }
    private let editPointRadius = 0.5.cf, lineEditPointRadius = 1.5.cf, pointEditPointRadius = 3.0.cf
    func drawEditPointsWith(editPoint: EditPoint?, isSnap: Bool, isWarp: Bool, _ di: DrawInfo, in ctx: CGContext) {
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
                        ctx.setStrokeColor(SceneDefaults.selectionColor)
                        ctx.strokePath()
                    }
                    if let np = np, editPoint.nearestLine.controls.count > 2 {
                        let p1 = editPoint.nearestPointIndex == 1 ? editPoint.nearestLine.controls[1].point : editPoint.nearestLine.controls[editPoint.nearestLine.controls.count - 2].point
                        ctx.move(to: p1.mid(np))
                        ctx.addLine(to: p1)
                        ctx.addLine(to: capPoint)
                        ctx.setLineWidth(0.5*di.reciprocalScale)
                        ctx.setStrokeColor(SceneDefaults.selectionColor)
                        ctx.strokePath()
                        p1.draw(radius: 2*di.reciprocalScale, lineWidth: di.reciprocalScale, inColor: SceneDefaults.selectionColor, outColor: SceneDefaults.controlPointInColor, in: ctx)
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
                drawSnap(with: editGroup.drawingItem.drawing.lines)
                for cellItem in editGroup.cellItems {
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
        if !editGroup.cellItems.isEmpty {
            for cellItem in editGroup.cellItems {
                if !cellItem.cell.isEditHidden {
                    if !isWarp {
                        Line.drawEditPointsWith(lines: cellItem.cell.lines, with: di, in: ctx)
                    }
                    updateCapPointDic(with: cellItem.cell.lines)
                }
            }
        }
        if !isWarp {
            Line.drawEditPointsWith(lines: editGroup.drawingItem.drawing.lines, with: di, in: ctx)
        }
        updateCapPointDic(with: editGroup.drawingItem.drawing.lines)
        
        let r = lineEditPointRadius*di.reciprocalScale, lw = 0.5*di.reciprocalScale
        for v in capPointDic {
            v.key.draw(radius: r, lineWidth: lw, inColor: v.value ? SceneDefaults.controlPointJointInColor : SceneDefaults.controlPointCapInColor, outColor: SceneDefaults.controlPointPathOutColor, in: ctx)
        }
    }
    
    struct EditTransform: Equatable {
        let anchorPoint: CGPoint, point: CGPoint, oldPoint: CGPoint
        func withPoint(_ point: CGPoint) -> EditTransform {
            return EditTransform(anchorPoint: anchorPoint, point: point, oldPoint: oldPoint)
        }
        static func == (lhs: EditTransform, rhs: EditTransform) -> Bool {
            return lhs.anchorPoint == rhs.anchorPoint && lhs.point == rhs.point && lhs.oldPoint == lhs.oldPoint
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
        ctx.setAlpha(0.5)
        drawLine(firstPoint: et.anchorPoint, lastPoint: et.oldPoint, di, in: ctx)
        ctx.setAlpha(1)
        drawLine(firstPoint: et.anchorPoint, lastPoint: et.point, di, in: ctx)
        et.anchorPoint.draw(radius: lineEditPointRadius*di.reciprocalScale, lineWidth: di.reciprocalScale, in: ctx)
    }
    func drawTransform(with et: EditTransform, _ di: DrawInfo, in ctx: CGContext) {
        ctx.setAlpha(0.5)
        drawLine(firstPoint: et.anchorPoint, lastPoint: et.oldPoint, di, in: ctx)
        drawCircleWith(radius: et.oldPoint.distance(et.anchorPoint), anchorPoint: et.anchorPoint, di, in: ctx)
        ctx.setAlpha(1)
        drawLine(firstPoint: et.anchorPoint, lastPoint: et.point, di, in: ctx)
        drawCircleWith(radius: et.point.distance(et.anchorPoint), anchorPoint: et.anchorPoint, di, in: ctx)
        et.anchorPoint.draw(radius: lineEditPointRadius*di.reciprocalScale, lineWidth: di.reciprocalScale, in: ctx)
    }
    func drawCircleWith(radius r: CGFloat, anchorPoint: CGPoint, _ di: DrawInfo, in ctx: CGContext) {
        let cb = CGRect(x: anchorPoint.x - r, y: anchorPoint.y - r, width: r*2, height: r*2)
        let outLineWidth = 3*di.reciprocalScale, inLineWidth = 1.5*di.reciprocalScale
        ctx.setLineWidth(outLineWidth)
        ctx.setStrokeColor(SceneDefaults.controlPointOutColor)
        ctx.strokeEllipse(in: cb)
        ctx.setLineWidth(inLineWidth)
        ctx.setStrokeColor(SceneDefaults.controlPointInColor)
        ctx.strokeEllipse(in: cb)
    }
    func drawLine(firstPoint: CGPoint, lastPoint: CGPoint, _ di: DrawInfo, in ctx: CGContext) {
        let outLineWidth = 3*di.reciprocalScale, inLineWidth = 1.5*di.reciprocalScale
        ctx.setLineWidth(outLineWidth)
        ctx.setStrokeColor(SceneDefaults.controlPointOutColor)
        ctx.move(to: firstPoint)
        ctx.addLine(to: lastPoint)
        ctx.strokePath()
        ctx.setLineWidth(inLineWidth)
        ctx.setStrokeColor(SceneDefaults.controlPointInColor)
        ctx.move(to: firstPoint)
        ctx.addLine(to: lastPoint)
        ctx.strokePath()
    }
}
