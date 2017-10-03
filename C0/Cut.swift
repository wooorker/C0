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

import AppKit.NSSound

//# Issue
//前後カメラ表示
//カメラと変形の統合
//「揺れ」の振動数の設定

final class Cut: NSObject, NSCoding, Copying {
    enum ViewType: Int32 {
        case edit, editPoint, editSnap, editWarp, editTransform, editRotation, editMoveZ, editMaterial, editingMaterial, preview
    }
    enum TransformEditorType {
        case scale, rotation, none
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
    
    init(rootCell: Cell = Cell(material: Material(color: HSLColor.white)), groups: [Group] = [Group](), editGroup: Group = Group(), time: Int = 0, timeLength: Int = 24, cameraBounds: CGRect = CGRect(x: 0, y: 0, width: 640, height: 360)) {
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
    
    static let dataType = "C0.Cut.1", rootCellKey = "0", groupsKey = "1", editGroupKey = "2", timeKey = "3", timeLengthKey = "4", cameraBoundsKey = "5", cellsKey = "6"
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
        let copyRootCell = rootCell.deepCopy, copyCells = cells.map { $0.deepCopy }, copyGroups = groups.map() { $0.deepCopy }
        let copyGroup = copyGroups[groups.index(of: editGroup)!]
        rootCell.resetCopyedCell()
        return Cut(rootCell: copyRootCell, groups: copyGroups, editGroup: copyGroup, time: time, timeLength: timeLength, cameraBounds: cameraBounds, cells: copyCells, camera: camera)
    }
    
    var allEditSelectionCellItemsWithNotEmptyGeometry: [CellItem] {
        return groups.reduce([CellItem]()) {
            $0 + $1.editSelectionCellItemsWithNotEmptyGeometry
        }
    }
    var allEditSelectionCellsWithNotEmptyGeometry: [Cell] {
        return groups.reduce([Cell]()) {
            $0 + $1.editSelectionCellsWithNotEmptyGeometry
        }
    }
    var editGroupIndex: Int {
        return groups.index(of: editGroup) ?? 0
    }
    func selectionCellAndLines(with point: CGPoint, usingLock: Bool = true) -> [(cell: Cell, geometry: Geometry)] {
        if usingLock {
            let allEditSelectionCells = editGroup.editSelectionCellsWithNotEmptyGeometry
            for selectionCell in allEditSelectionCells {
                if selectionCell.contains(point) {
                    return allEditSelectionCellsWithNotEmptyGeometry.flatMap {
                        $0.geometry.isEmpty ? nil : ($0, $0.geometry)
                    }
                }
            }
        } else {
            let allEditSelectionCells = allEditSelectionCellsWithNotEmptyGeometry
            for selectionCell in allEditSelectionCells {
                if selectionCell.contains(point) {
                    return allEditSelectionCells.flatMap {
                        $0.geometry.isEmpty ? nil : ($0, $0.geometry)
                    }
                }
            }
        }
        let hitCells = rootCell.cells(at: point, usingLock: usingLock)
        if let cell = hitCells.first {
            let snapCells = [cell] + editGroup.snapCells(with: cell)
            return snapCells.map { ($0, $0.geometry) }
        } else {
            return []
        }
    }
    enum IndicationCellType {
        case none, indication, selection
    }
    func indicationCellsTuple(with  point: CGPoint, usingLock: Bool = true) -> (cells: [Cell], type: IndicationCellType) {
        if usingLock {
            let allEditSelectionCells = editGroup.editSelectionCellsWithNotEmptyGeometry
            for selectionCell in allEditSelectionCells {
                if selectionCell.contains(point) {
                    return (allEditSelectionCellsWithNotEmptyGeometry, .selection)
                }
            }
        } else {
            let allEditSelectionCells = allEditSelectionCellsWithNotEmptyGeometry
            for selectionCell in allEditSelectionCells {
                if selectionCell.contains(point) {
                    return (allEditSelectionCells, .selection)
                }
            }
        }
        let hitCells = rootCell.cells(at: point, usingLock: usingLock)
        if let cell = hitCells.first {
            return ([cell], .indication)
        } else {
            return ([], .none)
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
    func cellItem(at point: CGPoint, with group: Group) -> CellItem? {
        if let cell = rootCell.atPoint(point) {
            let gc = groupAndCellItem(with: cell)
            return gc.group == group ? gc.cellItem : nil
        } else {
            return nil
        }
    }
    var imageBounds: CGRect {
        return groups.reduce(rootCell.imageBounds) { $0.unionNotEmpty($1.imageBounds) }
    }
    
    struct LineCap {
        let line: Line, lineIndex: Int, isFirst: Bool
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
            var minDrawing: Drawing?, minCellItem: CellItem?, minLineCap: LineCap?, minD = CGFloat.infinity
            func minNearest(with lines: [Line]) -> Bool {
                var isMin = false
                for (i, line) in lines.enumerated() {
                    let bezierT = line.bezierT(at: p)
                    if bezierT.distance < minD {
                        let isFirst = line.controls.count == 2 ? bezierT.t < 0.5 : (bezierT.bezierIndex.cf + bezierT.t < (line.controls.count.cf - 2)/2)
                        minLineCap = LineCap(line: line, lineIndex: i, isFirst: isFirst)
                        minD = bezierT.distance
                        isMin = true
                    }
                }
                return isMin
            }
            
            if let e = drawingEditLineCap {
                if minNearest(with: e.drawing.lines) {
                    minDrawing = e.drawing
                }
            }
            for e in cellItemEditLineCaps {
                if minNearest(with: e.cellItem.cell.geometry.lines) {
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
    func nearest(at point: CGPoint) -> Nearest? {
        var minD = CGFloat.infinity, minDrawing: Drawing?, minCellItem: CellItem?, minLine: Line?, minLineIndex = 0, minPointIndex = 0, minPoint = CGPoint()
        func nearestEditPoint(from lines: [Line]) -> Bool {
            var isNearest = false
            for (j, line) in lines.enumerated() {
                line.allEditPoints() { p, i in
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
            return isNearest
        }
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
        
        if nearestEditPoint(from: editGroup.drawingItem.drawing.lines) {
            minDrawing = editGroup.drawingItem.drawing
        }
         var minOldLinePoint: CGPoint?
        for cellItem in editGroup.cellItems {
            if nearestEditPoint(from: cellItem.cell.lines) {
                minDrawing = nil
                minCellItem = cellItem
                minOldLinePoint = nil
            }
            
            let lines = cellItem.cell.lines
            if var oldLine = lines.last {
                for line in lines {
                    let isUnion = oldLine.lastPoint == line.firstPoint
                    if !isUnion {
                        let p = oldLine.lastPoint.mid(line.firstPoint)
                        let d = hypot²(point.x - p.x, point.y - p.y)
                        if d < minD {
                            minD = d
                            minLine = line
                            minPoint = line.firstPoint
                            minOldLinePoint = oldLine.lastPoint
                            minDrawing = nil
                            minCellItem = nil
                        }
                    }
                    oldLine = line
                }
            }
        }
        if let minOldPoint = minOldLinePoint {
            let cellResults: [(cellItem: CellItem, geometry: Geometry, caps: [LineCap])] = editGroup.cellItems.flatMap {
                let aCaps = caps(with: minPoint, $0.cell.geometry.lines) + caps(with: minOldPoint, $0.cell.geometry.lines)
                return aCaps.isEmpty ? nil : ($0, $0.cell.geometry, aCaps)
            }
            return Nearest(drawingEdit: nil, cellItemEdit: nil, drawingEditLineCap: nil, cellItemEditLineCaps: cellResults, point: minPoint)
        }
        
        if let minLine = minLine {
            if minPointIndex == 0 || minPointIndex == minLine.controls.count - 1 {
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
    func nearestLine(at point: CGPoint) -> (drawing: Drawing?, cellItem: CellItem?, line: Line, lineIndex: Int, pointIndex: Int)? {
        guard let nearest = self.nearest(at: point) else {
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
    
    func draw(_ scene: Scene, viewType: Cut.ViewType = .preview, editMaterial: Material? = nil, indicationCellItem: CellItem? = nil, moveZCell: Cell? = nil, editPoint: EditPoint? = nil, isShownPrevious: Bool = false, isShownNext: Bool = false, with di: DrawInfo, in ctx: CGContext) {
        if viewType == .preview && camera.transform.wiggle.isMove {
            let p = camera.transform.wiggle.newPosition(CGPoint(), phase: camera.wigglePhase/scene.frameRate.cf)
            ctx.translateBy(x: p.x, y: p.y)
        }
        if let affine = camera.affineTransform {
            ctx.saveGState()
            ctx.concatenate(affine)
            drawContents(scene, viewType: viewType, editMaterial: editMaterial, indicationCellItem: indicationCellItem, moveZCell: moveZCell, editPoint: editPoint, isShownPrevious: isShownPrevious, isShownNext: isShownNext, with: di, in: ctx)
            ctx.restoreGState()
        } else {
            drawContents(scene, viewType: viewType, editMaterial: editMaterial, indicationCellItem: indicationCellItem, moveZCell: moveZCell, editPoint: editPoint, isShownPrevious: isShownPrevious, isShownNext: isShownNext, with: di, in: ctx)
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
    private func drawContents(_ scene: Scene, viewType: Cut.ViewType, editMaterial: Material?, indicationCellItem: CellItem? = nil, moveZCell: Cell?, editPoint: EditPoint? = nil, isShownPrevious: Bool, isShownNext: Bool, with di: DrawInfo, in ctx: CGContext) {
        let isEdit = viewType != .preview && viewType != .editMaterial && viewType != .editingMaterial
        drawRootCell(isEdit: isEdit, with: editMaterial,di, in: ctx)
        drawGroups(isEdit: isEdit, with: di, in: ctx)
        if isEdit {
            for group in groups {
                if !group.isHidden {
                    group.drawSelectionCells(opacity: group != editGroup ? 0.5 : 1, with: di,  in: ctx)
                }
            }
            if !editGroup.isHidden {
                editGroup.drawPreviousNext(isShownPrevious: isShownPrevious, isShownNext: isShownNext, time: time, with: di, in: ctx)
                if viewType != .editPoint && viewType != .editSnap && viewType != .editWarp, let indicationCellItem = indicationCellItem, editGroup.cellItems.contains(indicationCellItem) {
                    editGroup.drawSkinCellItem(indicationCellItem, with: di, in: ctx)
                }
                if let moveZCell = moveZCell {
                    drawZCell(zCell: moveZCell, in: ctx)
                }
                editGroup.drawTransparentCellLines(with: di, in: ctx)
                if viewType != .editTransform {
                    drawEditPointsWith(editPoint: editPoint, isSnap: viewType == .editSnap, isDrawDrawing: viewType == .editPoint || viewType == .editSnap || viewType == .editWarp, di, in: ctx)
                }
                if viewType == .editTransform {
                    drawTransform(di, in: ctx)
                } else if viewType == .editRotation {
                    drawRotation(di, in: ctx)
                }
            }
        }
    }
    private func drawRootCell(isEdit: Bool, with editMaterial: Material?, _ di: DrawInfo, in ctx: CGContext) {
        if isEdit {
            var isTransparency = false
            for child in rootCell.children {
                if isTransparency {
                    if !child.isLocked {
                        ctx.endTransparencyLayer()
                        ctx.restoreGState()
                        isTransparency = false
                    }
                }
                else if child.isLocked {
                    ctx.saveGState()
                    ctx.setAlpha(0.5)
                    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
                    isTransparency = true
                }
                child.drawEdit(with: editMaterial, di, in: ctx)
            }
            if isTransparency {
                ctx.endTransparencyLayer()
                ctx.restoreGState()
            }
        } else {
            for child in rootCell.children {
                child.draw(with: di, in: ctx)
            }
        }
    }
    private func drawGroups(isEdit: Bool, with di: DrawInfo, in ctx: CGContext) {
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
    
    private func drawZCell(zCell: Cell, in ctx: CGContext) {
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
    
    private func drawCamera(_ cameraBounds: CGRect, in ctx: CGContext) {
        ctx.setLineWidth(1)
        if camera.transform.wiggle.isMove {
            let maxSize = camera.transform.wiggle.maxSize
            drawCameraBorder(bounds: cameraBounds.insetBy(dx: -maxSize.width, dy: -maxSize.height), inColor: SceneDefaults.cameraBorderColor, outColor: SceneDefaults.cutSubBorderColor, in: ctx)
        }
        for group in groups {
            let keyframeIndex = group.loopedKeyframeIndex(withTime: time)
            if keyframeIndex.index > 0 {
                if let t = group.transformItem?.keyTransforms[keyframeIndex.index - 1], !t.isEmpty {
                }
            } else if keyframeIndex.index < group.keyframes.count - 1 {
                if let t = group.transformItem?.keyTransforms[keyframeIndex.index + 1], !t.isEmpty {
                }
            }
        }
        drawCameraBorder(bounds: cameraBounds, inColor: SceneDefaults.cutBorderColor, outColor: SceneDefaults.cutSubBorderColor, in: ctx)
    }
    private func drawCameraBorder(bounds: CGRect, inColor: CGColor, outColor: CGColor, in ctx: CGContext) {
        ctx.setStrokeColor(inColor)
        ctx.stroke(bounds.insetBy(dx: -0.5, dy: -0.5))
        ctx.setStrokeColor(outColor)
        ctx.stroke(bounds.insetBy(dx: -1.5, dy: -1.5))
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
    
    struct EditPoint {
        let nearestLine: Line, lines: [Line], point: CGPoint
        func draw(_ di: DrawInfo, in ctx: CGContext) {
            for line in lines {
                ctx.setFillColor(line === nearestLine ? SceneDefaults.selectionColor : SceneDefaults.subSelectionColor)
                line.draw(size: 2*di.reciprocalScale, in: ctx)
            }
            point.draw(radius: 3*di.reciprocalScale, lineWidth: di.reciprocalScale, inColor: SceneDefaults.selectionColor, outColor: SceneDefaults.controlPointInColor, in: ctx)
        }
    }
    private let editPointRadius = 0.5.cf, lineEditPointRadius = 1.5.cf, pointEditPointRadius = 3.0.cf
    func drawEditPointsWith(editPoint: EditPoint?, isSnap: Bool, isDrawDrawing: Bool, _ di: DrawInfo, in ctx: CGContext) {
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
                    Line.drawEditPointsWith(lines: cellItem.cell.lines, with: di, in: ctx)
                    Line.drawMidCapPointsWith(lines: cellItem.cell.lines, with: di, in: ctx)
                    updateCapPointDic(with: cellItem.cell.lines)
//                    Line.drawCapPointsWith(lines: cellItem.cell.lines, with: di, in: ctx)
                }
            }
        }
        if isDrawDrawing {
            Line.drawEditPointsWith(lines: editGroup.drawingItem.drawing.lines, with: di, in: ctx)
            updateCapPointDic(with: editGroup.drawingItem.drawing.lines)
//            Line.drawCapPointsWith(lines: editGroup.drawingItem.drawing.lines, isDrawMidPath: false, with: di, in: ctx)
        }
        
        let r = lineEditPointRadius*di.reciprocalScale, lw = 0.5*di.reciprocalScale
        for v in capPointDic {
            v.key.draw(radius: r, lineWidth: lw, inColor: v.value ? SceneDefaults.controlPointJointInColor : SceneDefaults.controlPointCapInColor, outColor: SceneDefaults.controlPointPathOutColor, in: ctx)
        }
    }
    
    struct EditTrasnform {
        var drawingTuple: (drawing: Drawing, lineIndexes: [Int], oldLines: [Line])?
        var cellTuples: [(group: Group, cellItem: CellItem, geometry: Geometry)]
    }
    func nearestTransformType(at p: CGPoint, viewAffineTransform t: CGAffineTransform?, isRotation: Bool) -> (edit: EditTrasnform, bounds: CGRect, type: TransformType)? {
        var minD = CGFloat.infinity, minType = TransformType.minXMinY, minBounds = CGRect(), minDrawing: Drawing?, minDrawingLineIndexes = [Int](), minCellItem: CellItem?
        func updateMin(with bounds: CGRect) -> Bool {
            let b = t != nil ? bounds.applying(t!) : bounds
            func updateMinWith(_ boundsPoint: CGPoint, _ type: TransformType) -> Bool {
                let d = boundsPoint.distance²(p)
                if d < minD {
                    minD = d
                    minType = type
                    minBounds = b
                    return true
                } else {
                    return false
                }
            }
            var isUpdate = false
            isUpdate = updateMinWith(CGPoint(x: b.minX, y: b.minY), .minXMinY) == true ? true : isUpdate
            isUpdate = updateMinWith(CGPoint(x: b.minX, y: b.midY), .minXMidY) == true ? true : isUpdate
            isUpdate = updateMinWith(CGPoint(x: b.minX, y: b.maxY), .minXMaxY) == true ? true : isUpdate
            isUpdate = updateMinWith(CGPoint(x: b.midX, y: b.minY), .midXMinY) == true ? true : isUpdate
            isUpdate = updateMinWith(CGPoint(x: b.midX, y: b.maxY), .midXMaxY) == true ? true : isUpdate
            isUpdate = updateMinWith(CGPoint(x: b.maxX, y: b.minY), .maxXMinY) == true ? true : isUpdate
            isUpdate = updateMinWith(CGPoint(x: b.maxX, y: b.midY), .maxXMidY) == true ? true : isUpdate
            isUpdate = updateMinWith(CGPoint(x: b.maxX, y: b.maxY), .maxXMaxY) == true ? true : isUpdate
            return isUpdate
        }
        func updateMinRotation(lines: [Line]) -> Bool {
            let np = t != nil ? p.applying(t!.inverted()) : p
            let centerP = Line.centroidPoint(with: lines)
            let r = Line.maxDistance(at: centerP, with: lines)
            let d = abs(np.distance(centerP) - r)
            if d < minD {
                minD = d
                minType = .rotation
                minBounds = t != nil ? CGRect(origin: centerP, size: CGSize()).applying(t!) : CGRect(origin: centerP, size: CGSize())
                return true
            } else {
                return false
            }
        }
        
        let drawing = editGroup.drawingItem.drawing
        if !drawing.lines.isEmpty {
            if !drawing.selectionLineIndexes.isEmpty {
                let b = drawing.selectionLinesBounds
                if isRotation ? updateMinRotation(lines: drawing.selectionLines) : updateMin(with: b) {
                    minDrawing = drawing
                    minDrawingLineIndexes = drawing.selectionLineIndexes
                }
            }
            let b = drawing.imageBounds(withLineWidth: 0)
            if isRotation ? updateMinRotation(lines: drawing.lines) : updateMin(with: b) {
                minDrawing = drawing
                minDrawingLineIndexes = Array(0 ..< drawing.lines.count)
            }
        }
        for cellItem in editGroup.cellItems {
            if !editGroup.selectionCellItems.contains(cellItem) {
                let b = cellItem.cell.imageBounds
                if isRotation ? updateMinRotation(lines: cellItem.cell.lines) : updateMin(with: b) {
                    minCellItem = cellItem
                    minDrawing = nil
                }
            }
        }
        if !editGroup.selectionCellItems.isEmpty {
            let b = editGroup.selectionCellItems.reduce(CGRect()) { $0.unionNotEmpty($1.cell.imageBounds) }
            if isRotation {
                var lines = [Line]()
                for cellItem in editGroup.selectionCellItems {
                    lines += cellItem.cell.lines
                }
                if updateMinRotation(lines: lines) {
                    let cellItems = allEditSelectionCellItemsWithNotEmptyGeometry
                    return(EditTrasnform(drawingTuple: nil, cellTuples: cellItems.map { (group(with: $0), $0, $0.cell.geometry) }), minBounds, minType)
                }
            } else if updateMin(with: b) {
                let cellItems = allEditSelectionCellItemsWithNotEmptyGeometry
                return(EditTrasnform(drawingTuple: nil, cellTuples: cellItems.map { (group(with: $0), $0, $0.cell.geometry) }), minBounds, minType)
            }
        }
        if let drawing = minDrawing {
            return(EditTrasnform(drawingTuple: (drawing, lineIndexes: minDrawingLineIndexes, drawing.lines), cellTuples: []), minBounds, minType)
        } else if let cellItem = minCellItem {
            return(EditTrasnform(drawingTuple: nil, cellTuples: editGroup.snapCells(with: cellItem.cell).flatMap {
                if let cellItem = editGroup.cellItem(with: $0) {
                    return (editGroup, cellItem, $0.geometry)
                } else {
                    return nil
                }
            }), minBounds, minType)
        }
        return nil
    }
    
    func affineTransform(with transformType: TransformType, bounds b: CGRect, p: CGPoint, oldP: CGPoint, viewAffineTransform: CGAffineTransform?) -> CGAffineTransform {
        var affine = CGAffineTransform.identity
        if let viewAffineTransform = viewAffineTransform {
            affine = viewAffineTransform.inverted().concatenating(affine)
        }
        let dp = CGPoint(x: p.x - oldP.x, y: p.y - oldP.y)
        let dpx = b.width == 0 ? 1 : dp.x/b.width, dpy = b.height == 0 ? 1 : dp.y/b.height
        let skewX = b.height == 0 ? 1 : -dp.x/b.height, skewY = b.width == 0 ? 1 : -dp.y/b.width
        func snapScaleWith(dx: CGFloat, dy: CGFloat) -> CGSize {
            let s = fabs(dx + 1) > fabs(dy + 1) ? dx + 1 : dy + 1
            return CGSize(width: s, height: s)
        }
        func scaleAffineTransformWith(_ affine: CGAffineTransform, anchor: CGPoint, scale: CGSize, skewX: CGFloat = 0, skewY: CGFloat = 0) -> CGAffineTransform {
            var nAffine = affine.translatedBy(x: anchor.x, y: anchor.y)
            nAffine = nAffine.scaledBy(x: scale.width, y: scale.height)
            if skewX != 0 || skewY != 0 {
                nAffine = CGAffineTransform(a: 1, b: skewY, c: skewX, d: 1, tx: 0, ty: 0).concatenating(nAffine)
            }
            return nAffine.translatedBy(x: -anchor.x, y: -anchor.y)
        }
        func rotationAffineTransformWith(_ affine: CGAffineTransform, anchor: CGPoint) -> CGAffineTransform {
            var tAffine = CGAffineTransform(rotationAngle: -atan2(oldP.y - anchor.y, oldP.x - anchor.x))
            tAffine = tAffine.translatedBy(x: -anchor.x, y: -anchor.y)
            let tnp = p.applying(tAffine)
            var nAffine = affine.translatedBy(x: anchor.x, y: anchor.y)
            nAffine = nAffine.rotated(by: atan2(tnp.y, tnp.x))
            nAffine = nAffine.translatedBy(x: -anchor.x, y: -anchor.y)
            return nAffine
        }
        switch transformType {
        case .minXMinY:
            affine = scaleAffineTransformWith(affine, anchor: CGPoint(x: b.maxX, y: b.maxY), scale: CGSize(width: -dpx + 1, height: -dpy + 1))
        case .minXMidY:
            affine = scaleAffineTransformWith(affine, anchor: CGPoint(x: b.maxX, y: b.midY), scale: CGSize(width: -dpx + 1, height: 1), skewY: skewY)
        case .minXMaxY:
            affine = scaleAffineTransformWith(affine, anchor: CGPoint(x: b.maxX, y: b.minY), scale: CGSize(width: -dpx + 1, height: dpy + 1))
        case .midXMinY:
            affine = scaleAffineTransformWith(affine, anchor: CGPoint(x: b.midX, y: b.maxY), scale: CGSize(width: 1, height: -dpy + 1), skewX: skewX)
        case .midXMaxY:
            affine = scaleAffineTransformWith(affine, anchor: CGPoint(x: b.midX, y: b.minY), scale: CGSize(width: 1, height: dpy + 1), skewX: -skewX)
        case .maxXMinY:
            affine = scaleAffineTransformWith(affine, anchor: CGPoint(x: b.minX, y: b.maxY), scale: CGSize(width: dpx + 1, height: -dpy + 1))
        case .maxXMidY:
            affine = scaleAffineTransformWith(affine, anchor: CGPoint(x: b.minX, y: b.midY), scale: CGSize(width: dpx + 1, height: 1), skewY: -skewY)
        case .maxXMaxY:
            affine = scaleAffineTransformWith(affine, anchor: CGPoint(x: b.minX, y: b.minY), scale: CGSize(width: dpx + 1, height: dpy + 1))
        case .rotation:
            affine = rotationAffineTransformWith(affine, anchor: CGPoint(x: b.midX, y: b.midY))
        }
        if let viewAffineTransform = viewAffineTransform {
            affine = viewAffineTransform.concatenating(affine)
        }
        return affine
    }
//    func rotationAffineTransform(_ anchorP: CGPoint, p: CGPoint, oldP: CGPoint, viewAffineTransform: CGAffineTransform?) -> CGAffineTransform {
//        var affine = CGAffineTransform.identity
//        if let viewAffineTransform = viewAffineTransform {
//            affine = viewAffineTransform.inverted().concatenating(affine)
//        }
//        var tAffine = CGAffineTransform(rotationAngle: -atan2(oldP.y - anchorP.y, oldP.x - anchorP.x))
//        tAffine = tAffine.translatedBy(x: -anchorP.x, y: -anchorP.y)
//        let tnp = p.applying(tAffine)
//        affine = affine.translatedBy(x: anchorP.x, y: anchorP.y)
//        affine = affine.rotated(by: atan2(tnp.y, tnp.x))
//        affine = affine.translatedBy(x: -anchorP.x, y: -anchorP.y)
//        if let viewAffineTransform = viewAffineTransform {
//            affine = viewAffineTransform.concatenating(affine)
//        }
//        return affine
//    }
    enum TransformType {
        case minXMinY, minXMidY, minXMaxY, midXMinY, midXMaxY, maxXMinY, maxXMidY, maxXMaxY, rotation
    }
    func drawTransform(_ di: DrawInfo, in ctx: CGContext) {
        func drawTransformBounds(_ bounds: CGRect) {
            let outLineWidth = 2*di.reciprocalScale, inLineWidth = 1*di.reciprocalScale
            ctx.setLineWidth(outLineWidth)
            ctx.setStrokeColor(SceneDefaults.controlPointOutColor.multiplyAlpha(0.5))
            ctx.stroke(bounds)
            ctx.setLineWidth(inLineWidth)
            ctx.setStrokeColor(SceneDefaults.controlPointInColor.multiplyAlpha(0.5))
            ctx.stroke(bounds)
            let radius = 2*di.reciprocalScale, lineWidth = 1*di.reciprocalScale
            CGPoint(x: bounds.minX, y: bounds.minY).draw(radius: radius, lineWidth: lineWidth, in: ctx)
            CGPoint(x: bounds.minX, y: bounds.midY).draw(radius: radius, lineWidth: lineWidth, in: ctx)
            CGPoint(x: bounds.minX, y: bounds.maxY).draw(radius: radius, lineWidth: lineWidth, in: ctx)
            CGPoint(x: bounds.midX, y: bounds.minY).draw(radius: radius, lineWidth: lineWidth, in: ctx)
            CGPoint(x: bounds.midX, y: bounds.maxY).draw(radius: radius, lineWidth: lineWidth, in: ctx)
            CGPoint(x: bounds.maxX, y: bounds.minY).draw(radius: radius, lineWidth: lineWidth, in: ctx)
            CGPoint(x: bounds.maxX, y: bounds.midY).draw(radius: radius, lineWidth: lineWidth, in: ctx)
            CGPoint(x: bounds.maxX, y: bounds.maxY).draw(radius: radius, lineWidth: lineWidth, in: ctx)
        }
        
        if !editGroup.drawingItem.drawing.lines.isEmpty {
            if !editGroup.drawingItem.drawing.selectionLineIndexes.isEmpty {
                drawTransformBounds(editGroup.drawingItem.drawing.selectionLinesBounds)
            }
            drawTransformBounds(editGroup.drawingItem.drawing.imageBounds(withLineWidth: 0))
        }
        for cellItem in editGroup.cellItems {
            if !editGroup.selectionCellItems.contains(cellItem) {
                drawTransformBounds(cellItem.cell.imageBounds)
            }
        }
        if !editGroup.selectionCellItems.isEmpty {
            let bounds = editGroup.selectionCellItems.reduce(CGRect()) { $0.unionNotEmpty($1.cell.imageBounds) }
            drawTransformBounds(bounds)
        }
    }
    func drawRotation(_ di: DrawInfo, in ctx: CGContext) {
        func draw(centerP: CGPoint, r: CGFloat) {
            let cb = CGRect(x: centerP.x - r, y: centerP.y - r, width: r*2, height: r*2)
            let outLineWidth = 3*di.reciprocalScale, inLineWidth = 1.5*di.reciprocalScale
            ctx.setLineWidth(outLineWidth)
            ctx.setStrokeColor(SceneDefaults.controlPointOutColor)
            ctx.strokeEllipse(in: cb)
            ctx.setLineWidth(inLineWidth)
            ctx.setStrokeColor(SceneDefaults.controlPointInColor)
            ctx.strokeEllipse(in: cb)
        }
        func draw(_ lines: [Line], bounds: CGRect) {
            let centerP = Line.centroidPoint(with: lines)
            draw(centerP: centerP, r: Line.maxDistance(at: centerP, with: lines))
        }
        if !editGroup.drawingItem.drawing.lines.isEmpty {
            if !editGroup.drawingItem.drawing.selectionLineIndexes.isEmpty {
                draw(editGroup.drawingItem.drawing.selectionLines, bounds: editGroup.drawingItem.drawing.selectionLinesBounds)
            }
            draw(editGroup.drawingItem.drawing.lines, bounds: editGroup.drawingItem.drawing.imageBounds(withLineWidth: 0))
        }
        for cellItem in editGroup.cellItems {
            if !editGroup.selectionCellItems.contains(cellItem) {
                draw(cellItem.cell.lines, bounds: cellItem.cell.imageBounds)
            }
        }
        if !editGroup.selectionCellItems.isEmpty {
            var lines = [Line]()
            for cellItem in editGroup.selectionCellItems {
                lines += cellItem.cell.lines
            }
            let bounds = editGroup.selectionCellItems.reduce(CGRect()) { $0.unionNotEmpty($1.cell.imageBounds) }
            draw(lines, bounds: bounds)
        }
    }
}

//# Issue
//グループの線を色分け
//グループ選択による選択結合
//グループの半透明表示を廃止して、完成表示の上から選択グループを半透明着色する（描画の高速化が必要）
//グループの最終キーフレームの時間編集問題
//ループを再設計
//イージングを再設計（セルやカメラに直接設定）

final class Group: NSObject, NSCoding, Copying {
    private(set) var keyframes: [Keyframe] {
        didSet {
            self.loopedKeyframeIndexes = Group.loopedKeyframeIndexesWith(keyframes, timeLength: timeLength)
        }
    }
    var editKeyframeIndex: Int, selectionKeyframeIndexes: [Int]
    var timeLength: Int {
        didSet {
            self.loopedKeyframeIndexes = Group.loopedKeyframeIndexesWith(keyframes, timeLength: timeLength)
        }
    }
    var isHidden: Bool {
        didSet {
            for cellItem in cellItems {
                cellItem.cell.isHidden = isHidden
            }
        }
    }
    var selectionCellItems: [CellItem]
    var drawingItem: DrawingItem, cellItems: [CellItem], transformItem: TransformItem?, textItem: TextItem?, isInterporation: Bool
    private(set) var loopedKeyframeIndexes: [(index: Int, time: Int, loopCount: Int, loopingCount: Int)]
    private static func loopedKeyframeIndexesWith(_ keyframes: [Keyframe], timeLength: Int) -> [(index: Int, time: Int, loopCount: Int, loopingCount: Int)] {
        var keyframeIndexes = [(index: Int, time: Int, loopCount: Int, loopingCount: Int)](), previousIndexes = [Int]()
        for (i, keyframe) in keyframes.enumerated() {
            if keyframe.loop.isEnd, let preIndex = previousIndexes.last {
                let loopCount = previousIndexes.count
                previousIndexes.removeLast()
                let time = keyframe.time, nextTime = i + 1 >= keyframes.count ? timeLength : keyframes[i + 1].time
                var t = time, isEndT = false
                while t <= nextTime {
                    for j in preIndex ..< i {
                        let nk = keyframeIndexes[j]
                        keyframeIndexes.append((nk.index, t, loopCount, loopCount))
                        t += keyframeIndexes[j + 1].time - nk.time
                        if t > nextTime {
                            if i == keyframes.count - 1 {
                                keyframeIndexes.append((keyframeIndexes[j + 1].index, t, loopCount, loopCount))
                            }
                            isEndT = true
                            break
                        }
                    }
                    if isEndT {
                        break
                    }
                }
            } else {
                let loopCount = keyframe.loop.isStart ? previousIndexes.count + 1 : previousIndexes.count
                keyframeIndexes.append((i, keyframe.time, loopCount, max(0, loopCount - 1)))
            }
            if keyframe.loop.isStart {
                previousIndexes.append(keyframeIndexes.count - 1)
            }
        }
        return keyframeIndexes
    }
    func update(withTime time: Int) {
        let timeResult = loopedKeyframeIndex(withTime: time)
        let i1 = timeResult.loopedIndex, interTime = max(0, timeResult.interValue)
        let kis1 = loopedKeyframeIndexes[i1]
        editKeyframeIndex = kis1.index
        let k1 = keyframes[kis1.index]
        if interTime == 0 || timeResult.sectionValue == 0 || i1 + 1 >= loopedKeyframeIndexes.count || k1.interpolation == .none {
            isInterporation = false
            step(kis1.index)
            return
        }
        isInterporation = true
        let kis2 = loopedKeyframeIndexes[i1 + 1]
        if k1.interpolation == .linear || keyframes.count <= 2 {
            linear(kis1.index, kis2.index, t: k1.easing.convertT(interTime.cf/timeResult.sectionValue.cf))
        } else {
            let t = k1.easing.isDefault ? time.cf : k1.easing.convertT(interTime.cf/timeResult.sectionValue.cf)*timeResult.sectionValue.cf + kis1.time.cf
            let isUseFirstIndex = i1 - 1 >= 0 && k1.interpolation != .bound, isUseEndIndex = i1 + 2 < loopedKeyframeIndexes.count && keyframes[kis2.index].interpolation != .bound
            if isUseFirstIndex {
                if isUseEndIndex {
                    let kis0 = loopedKeyframeIndexes[i1 - 1], kis3 = loopedKeyframeIndexes[i1 + 2]
                    let msx = MonosplineX(x0: kis0.time.cf, x1: kis1.time.cf, x2: kis2.time.cf, x3: kis3.time.cf, x: t, t: k1.easing.convertT(interTime.cf/timeResult.sectionValue.cf))
                    monospline(kis0.index, kis1.index, kis2.index, kis3.index, with: msx)
                } else {
                    let kis0 = loopedKeyframeIndexes[i1 - 1]
                    let msx = MonosplineX(x0: kis0.time.cf, x1: kis1.time.cf, x2: kis2.time.cf, x: t, t: k1.easing.convertT(interTime.cf/timeResult.sectionValue.cf))
                    endMonospline(kis0.index, kis1.index, kis2.index, with: msx)
                }
            } else if isUseEndIndex {
                let kis3 = loopedKeyframeIndexes[i1 + 2]
                let msx = MonosplineX(x1: kis1.time.cf, x2: kis2.time.cf, x3: kis3.time.cf, x: t, t: k1.easing.convertT(interTime.cf/timeResult.sectionValue.cf))
                firstMonospline(kis1.index, kis2.index, kis3.index, with: msx)
            } else {
                linear(kis1.index, kis2.index, t: k1.easing.convertT(interTime.cf/timeResult.sectionValue.cf))
            }
        }
    }
    
    func step(_ f0: Int) {
        drawingItem.update(with: f0)
        for cellItem in cellItems {
            cellItem.step(f0)
        }
        transformItem?.step(f0)
        textItem?.update(with: f0)
    }
    
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        drawingItem.update(with: f0)
        for cellItem in cellItems {
            cellItem.linear(f0, f1, t: t)
        }
        transformItem?.linear(f0, f1, t: t)
        textItem?.update(with: f0)
    }
    
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        drawingItem.update(with: f1)
        for cellItem in cellItems {
            cellItem.firstMonospline(f1, f2, f3, with: msx)
        }
        transformItem?.firstMonospline(f1, f2, f3, with: msx)
        textItem?.update(with: f1)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        drawingItem.update(with: f1)
        for cellItem in cellItems {
            cellItem.monospline(f0, f1, f2, f3, with: msx)
        }
        transformItem?.monospline(f0, f1, f2, f3, with: msx)
        textItem?.update(with: f1)
    }
    func endMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with msx: MonosplineX) {
        drawingItem.update(with: f1)
        for cellItem in cellItems {
            cellItem.endMonospline(f0, f1, f2, with: msx)
        }
        transformItem?.endMonospline(f0, f1, f2, with: msx)
        textItem?.update(with: f1)
    }
    
    func replaceKeyframe(_ keyframe: Keyframe, at index: Int) {
        keyframes[index] = keyframe
    }
    func replaceKeyframes(_ keyframes: [Keyframe]) {
        if keyframes.count != self.keyframes.count {
            fatalError()
        }
        self.keyframes = keyframes
    }
    func insertKeyframe(_ keyframe: Keyframe, drawing: Drawing, geometries: [Geometry], materials: [Material?], transform: Transform?, text: Text?, at index: Int) {
        keyframes.insert(keyframe, at: index)
        drawingItem.keyDrawings.insert(drawing, at: index)
        if geometries.count > cellItems.count {
            fatalError()
        }
        for (i, cellItem) in cellItems.enumerated() {
            cellItem.keyGeometries.insert(geometries[i], at: index)
        }
        if !materials.isEmpty {
            if materials.count > cellItems.count {
                fatalError()
            }
            for (i, cellItem) in cellItems.enumerated() {
                if let material = materials[i] {
                    cellItem.keyMaterials.insert(material, at: index)
                }
            }
        }
        if let transform = transform {
            transformItem?.keyTransforms.insert(transform, at: index)
        }
        if let text = text {
            textItem?.keyTexts.insert(text, at: index)
        }
    }
    func removeKeyframe(at index: Int) {
        keyframes.remove(at: index)
        drawingItem.keyDrawings.remove(at: index)
        for cellItem in cellItems {
            cellItem.keyGeometries.remove(at: index)
            if !cellItem.keyMaterials.isEmpty {
                cellItem.keyMaterials.remove(at: index)
            }
        }
        transformItem?.keyTransforms.remove(at: index)
        textItem?.keyTexts.remove(at: index)
    }
    func setKeyGeometries(_ keyGeometries: [Geometry], in cellItem: CellItem, isSetGeometryInCell: Bool  = true) {
        if keyGeometries.count != keyframes.count {
            fatalError()
        }
        if isSetGeometryInCell, let i = cellItem.keyGeometries.index(of: cellItem.cell.geometry) {
            cellItem.cell.geometry = keyGeometries[i]
        }
        cellItem.keyGeometries = keyGeometries
    }
    func setKeyTransforms(_ keyTransforms: [Transform], isSetTransformInItem: Bool  = true) {
        if let transformItem = transformItem {
            if keyTransforms.count != keyframes.count {
                fatalError()
            }
            if isSetTransformInItem, let i = transformItem.keyTransforms.index(of: transformItem.transform) {
                transformItem.transform = keyTransforms[i]
            }
            transformItem.keyTransforms = keyTransforms
        }
    }
    var currentItemValues: (drawing: Drawing, geometries: [Geometry], materials: [Material?], transform: Transform?, text: Text?) {
        let geometries = cellItems.map { $0.cell.geometry }
        let materials: [Material?] = cellItems.map { $0.keyMaterials.isEmpty ? nil : $0.cell.material }
        return (drawingItem.drawing, geometries, materials, transformItem?.transform, textItem?.text)
    }
    func keyframeItemValues(at index: Int) -> (drawing: Drawing, geometries: [Geometry], materials: [Material?], transform: Transform?, text: Text?) {
        let geometries = cellItems.map { $0.keyGeometries[index] }
        let materials: [Material?] = cellItems.map {
            index >= $0.keyMaterials.count ? nil : $0.keyMaterials[index]
        }
        return (drawingItem.keyDrawings[index], geometries, materials, transformItem?.keyTransforms[index], textItem?.keyTexts[index])
    }
    
    init(keyframes: [Keyframe] = [Keyframe()], editKeyframeIndex: Int = 0, selectionKeyframeIndexes: [Int] = [], timeLength: Int = 0,
         isHidden: Bool = false, selectionCellItems: [CellItem] = [],
         drawingItem: DrawingItem = DrawingItem(), cellItems: [CellItem] = [], transformItem: TransformItem? = nil, textItem: TextItem? = nil, isInterporation: Bool = false) {
        self.keyframes = keyframes
        self.editKeyframeIndex = editKeyframeIndex
        self.selectionKeyframeIndexes = selectionKeyframeIndexes
        self.timeLength = timeLength
        self.isHidden = isHidden
        self.selectionCellItems = selectionCellItems
        self.drawingItem = drawingItem
        self.cellItems = cellItems
        self.transformItem = transformItem
        self.textItem = textItem
        self.isInterporation = isInterporation
        self.loopedKeyframeIndexes = Group.loopedKeyframeIndexesWith(keyframes, timeLength: timeLength)
        super.init()
    }
    private init(keyframes: [Keyframe], editKeyframeIndex: Int, selectionKeyframeIndexes: [Int], timeLength: Int,
                 isHidden: Bool, selectionCellItems: [CellItem],
                 drawingItem: DrawingItem, cellItems: [CellItem], transformItem: TransformItem?, textItem: TextItem?, isInterporation: Bool,
                 keyframeIndexes: [(index: Int, time: Int, loopCount: Int, loopingCount: Int)]) {
        self.keyframes = keyframes
        self.editKeyframeIndex = editKeyframeIndex
        self.selectionKeyframeIndexes = selectionKeyframeIndexes
        self.timeLength = timeLength
        self.isHidden = isHidden
        self.selectionCellItems = selectionCellItems
        self.drawingItem = drawingItem
        self.cellItems = cellItems
        self.transformItem = transformItem
        self.textItem = textItem
        self.isInterporation = isInterporation
        self.loopedKeyframeIndexes = keyframeIndexes
        super.init()
    }
    
    static let dataType = "C0.Group.1", keyframesKey = "0", editKeyframeIndexKey = "1", selectionKeyframeIndexesKey = "2", timeLengthKey = "3", isHiddenKey = "4"
    static let editCellItemKey = "5", selectionCellItemsKey = "6", drawingItemKey = "7", cellItemsKey = "8", transformItemKey = "9", textItemKey = "10", isInterporationKey = "11"
    init?(coder: NSCoder) {
        keyframes = coder.decodeStruct(forKey: Group.keyframesKey) ?? []
        editKeyframeIndex = coder.decodeInteger(forKey: Group.editKeyframeIndexKey)
        selectionKeyframeIndexes = coder.decodeObject(forKey: Group.selectionKeyframeIndexesKey) as? [Int] ?? []
        timeLength = coder.decodeInteger(forKey: Group.timeLengthKey)
        isHidden = coder.decodeBool(forKey: Group.isHiddenKey)
        selectionCellItems = coder.decodeObject(forKey: Group.selectionCellItemsKey) as? [CellItem] ?? []
        drawingItem = coder.decodeObject(forKey: Group.drawingItemKey) as? DrawingItem ?? DrawingItem()
        cellItems = coder.decodeObject(forKey: Group.cellItemsKey) as? [CellItem] ?? []
        transformItem = coder.decodeObject(forKey: Group.transformItemKey) as? TransformItem
        textItem = coder.decodeObject(forKey: Group.textItemKey) as? TextItem
        isInterporation = coder.decodeBool(forKey: Group.isInterporationKey)
        loopedKeyframeIndexes = Group.loopedKeyframeIndexesWith(keyframes, timeLength: timeLength)
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeStruct(keyframes, forKey: Group.keyframesKey)
        coder.encode(editKeyframeIndex, forKey: Group.editKeyframeIndexKey)
        coder.encode(selectionKeyframeIndexes, forKey: Group.selectionKeyframeIndexesKey)
        coder.encode(timeLength, forKey: Group.timeLengthKey)
        coder.encode(isHidden, forKey: Group.isHiddenKey)
        coder.encode(selectionCellItems, forKey: Group.selectionCellItemsKey)
        coder.encode(drawingItem, forKey: Group.drawingItemKey)
        coder.encode(cellItems, forKey: Group.cellItemsKey)
        coder.encode(transformItem, forKey: Group.transformItemKey)
        coder.encode(textItem, forKey: Group.textItemKey)
        coder.encode(isInterporation, forKey: Group.isInterporationKey)
    }
    
    var deepCopy: Group {
        return Group(keyframes: keyframes, editKeyframeIndex: editKeyframeIndex, selectionKeyframeIndexes: selectionKeyframeIndexes,
                     timeLength: timeLength, isHidden: isHidden, selectionCellItems: selectionCellItems.map { $0.deepCopy },
                     drawingItem: drawingItem.deepCopy, cellItems: cellItems.map { $0.deepCopy }, transformItem: transformItem?.deepCopy,
                     textItem: textItem?.deepCopy, isInterporation: isInterporation, keyframeIndexes: loopedKeyframeIndexes)
    }
    
    var editKeyframe: Keyframe {
        return keyframes[min(editKeyframeIndex, keyframes.count - 1)]
    }
    func loopedKeyframeIndex(withTime t: Int) -> (loopedIndex: Int, index: Int, interValue: Int, sectionValue: Int) {
        var oldT = timeLength
        for i in (0 ..< loopedKeyframeIndexes.count).reversed() {
            let ki = loopedKeyframeIndexes[i]
            let kt = ki.time
            if t >= kt {
                return (i, ki.index, t - kt, oldT - kt)
            }
            oldT = kt
        }
        return (0, 0, t -  loopedKeyframeIndexes.first!.time, oldT - loopedKeyframeIndexes.first!.time)
    }
    var minTimeLength: Int {
        return (keyframes.last?.time ?? 0) + 1
    }
    var lastKeyframeTime: Int {
        return keyframes.isEmpty ? 0 : keyframes[keyframes.count - 1].time
    }
    var lastLoopedKeyframeTime: Int {
        if loopedKeyframeIndexes.isEmpty {
            return 0
        }
        let t = loopedKeyframeIndexes[loopedKeyframeIndexes.count - 1].time
        if t >= timeLength {
            return loopedKeyframeIndexes.count >= 2 ? loopedKeyframeIndexes[loopedKeyframeIndexes.count - 2].time : 0
        } else {
            return t
        }
    }
    
    func contains(_ cell: Cell) -> Bool {
        for cellItem in cellItems {
            if cellItem.cell == cell {
                return true
            }
        }
        return false
    }
    func containsSelection(_ cell: Cell) -> Bool {
        for cellItem in selectionCellItems {
            if cellItem.cell == cell {
                return true
            }
        }
        return false
    }
    func containsEditSelectionWithNotEmptyGeometry(_ cell: Cell) -> Bool {
        for cellItem in editSelectionCellItemsWithNotEmptyGeometry {
            if cellItem.cell == cell {
                return true
            }
        }
        return false
    }
    @nonobjc func contains(_ cellItem: CellItem) -> Bool {
        return cellItems.contains(cellItem)
    }
    func cellItem(with cell: Cell) -> CellItem? {
        for cellItem in cellItems {
            if cellItem.cell == cell {
                return cellItem
            }
        }
        return nil
    }
    var cells: [Cell] {
        return cellItems.map { $0.cell }
    }
    var selectionCells: [Cell] {
        return selectionCellItems.map { $0.cell }
    }
    var editSelectionCellsWithNotEmptyGeometry: [Cell] {
        return selectionCellItems.flatMap { !$0.cell.geometry.isEmpty ? $0.cell : nil }
    }
    var editSelectionCellItems: [CellItem] {
        return selectionCellItems
    }
    var editSelectionCellItemsWithNotEmptyGeometry: [CellItem] {
        return selectionCellItems.filter { !$0.cell.geometry.isEmpty }
    }
    
    var emptyKeyGeometries: [Geometry] {
        return keyframes.map { _ in Geometry() }
    }
    var isEmptyGeometryWithCells: Bool {
        for cellItem in cellItems {
            if cellItem.cell.geometry.isEmpty {
                return false
            }
        }
        return true
    }
    
    func snapCells(with cell: Cell) -> [Cell] {
        var cells = self.cells
        var snapedCells = cells.flatMap { $0 !== cell && $0.isSnaped(cell) ? $0 : nil }
        func snap(_ withCell: Cell) {
            var newSnapedCells = [Cell]()
            cells = cells.flatMap {
                if $0.isSnaped(withCell) {
                    newSnapedCells.append($0)
                    return nil
                } else {
                    return $0
                }
            }
            if !newSnapedCells.isEmpty {
                snapedCells += newSnapedCells
                for newCell in newSnapedCells { snap(newCell) }
            }
        }
        snap(cell)
        return snapedCells
    }
    
    func wigglePhaseWith(time: Int, lastHz: CGFloat) -> CGFloat {
        if let transformItem = transformItem, let firstTransform = transformItem.keyTransforms.first {
            var phase = 0.0.cf, oldHz = firstTransform.wiggle.hz, oldTime = 0
            for i in 1 ..< keyframes.count {
                let newTime = keyframes[i].time
                if time >= newTime {
                    let newHz = transformItem.keyTransforms[i].wiggle.hz
                    phase += (newHz + oldHz)*(newTime - oldTime).cf/2
                    oldTime = newTime
                    oldHz = newHz
                } else {
                    return phase + (lastHz + oldHz)*(time - oldTime).cf/2
                }
            }
            return phase + lastHz*(time - oldTime).cf
        } else {
            return 0
        }
    }
    
    func snapPoint(_ p: CGPoint, with n: Cut.Nearest.BezierSortedResult, snapDistance: CGFloat) -> CGPoint {
        var minD = CGFloat.infinity, minP = p
        func updateMin(with ap: CGPoint) {
            let d0 = p.distance(ap)
            if d0 < snapDistance && d0 < minD {
                minD = d0
                minP = ap
            }
        }
        func update(cellItem: CellItem?) {
            for (i, line) in drawingItem.drawing.lines.enumerated() {
                if i == n.lineCap.lineIndex {
                    updateMin(with: n.lineCap.isFirst ? line.lastPoint : line.firstPoint)
                } else {
                    updateMin(with: line.firstPoint)
                    updateMin(with: line.lastPoint)
                }
            }
            for aCellItem in cellItems {
                for (i, line) in aCellItem.cell.geometry.lines.enumerated() {
                    if aCellItem == cellItem && i == n.lineCap.lineIndex {
                        updateMin(with: n.lineCap.isFirst ? line.lastPoint : line.firstPoint)
                    } else {
                        updateMin(with: line.firstPoint)
                        updateMin(with: line.lastPoint)
                    }
                }
            }
        }
        if n.drawing != nil {
            update(cellItem: nil)
        } else if let cellItem = n.cellItem {
            update(cellItem: cellItem)
        }
        return minP
    }
    
    var imageBounds: CGRect {
        return cellItems.reduce(CGRect()) { $0.unionNotEmpty($1.cell.imageBounds) }.unionNotEmpty(drawingItem.imageBounds)
    }
    
    func drawPreviousNext(isShownPrevious: Bool, isShownNext: Bool, time: Int, with di: DrawInfo, in ctx: CGContext) {
        drawingItem.drawPreviousNext(isShownPrevious: isShownPrevious, isShownNext: isShownNext, index:
            loopedKeyframeIndex(withTime: time).index, with: di, in: ctx)
    }
    func drawSelectionCells(opacity: CGFloat, with di: DrawInfo, in ctx: CGContext) {
        if !isHidden && !selectionCellItems.isEmpty {
            ctx.setAlpha(0.65*opacity)
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            var geometrys = [Geometry]()
            ctx.setFillColor(SceneDefaults.subSelectionColor.copy(alpha: 1)!)
            func setPaths(with cellItem: CellItem) {
                let cell = cellItem.cell
                if !cell.geometry.isEmpty {
                    cell.addPath(in: ctx)
                    ctx.fillPath()
                    geometrys.append(cell.geometry)
                }
            }
            for cellItem in selectionCellItems {
                setPaths(with: cellItem)
            }
            ctx.setFillColor(SceneDefaults.selectionColor)
            for geometry in geometrys {
                geometry.draw(withLineWidth: 1.5*di.reciprocalCameraScale, in: ctx)
            }
            ctx.endTransparencyLayer()
            ctx.setAlpha(1)
        }
    }
    func drawTransparentCellLines(with di: DrawInfo, in ctx: CGContext) {
        ctx.setLineWidth(di.reciprocalScale)
        ctx.setStrokeColor(SceneDefaults.cellBorderColor.multiplyAlpha(0.25))
        for cellItem in cellItems {
            cellItem.cell.addPath(in: ctx)
        }
        ctx.strokePath()
    }
    func drawSkinCellItem(_ cellItem: CellItem, with di: DrawInfo, in ctx: CGContext) {
        cellItem.cell.drawSkin(lineColor: isInterporation ? SceneDefaults.interpolationColor : SceneDefaults.selectionColor.multiplyAlpha(0.5), subColor: SceneDefaults.subSelectionSkinColor.multiplyAlpha(0.5), geometry: cellItem.cell.geometry, with: di, in: ctx)
    }
}
struct Keyframe: ByteCoding {
    enum Interpolation: Int8 {
        case spline, bound, linear, none
    }
    let time: Int, easing: Easing, interpolation: Interpolation, loop: Loop, implicitSplited: Bool
    
    init(time: Int = 0, easing: Easing = Easing(), interpolation: Interpolation = .spline, loop: Loop = Loop(), implicitSplited: Bool = false) {
        self.time = time
        self.easing = easing
        self.interpolation = interpolation
        self.loop = loop
        self.implicitSplited = implicitSplited
    }
    
    func withTime(_ time: Int) -> Keyframe {
        return Keyframe(time: time, easing: easing, interpolation: interpolation, loop: loop, implicitSplited: implicitSplited)
    }
    func withEasing(_ easing: Easing) -> Keyframe {
        return Keyframe(time: time, easing: easing, interpolation: interpolation, loop: loop, implicitSplited: implicitSplited)
    }
    func withInterpolation(_ interpolation: Interpolation) -> Keyframe {
        return Keyframe(time: time, easing: easing, interpolation: interpolation, loop: loop, implicitSplited: implicitSplited)
    }
    func withLoop(_ loop: Loop) -> Keyframe {
        return Keyframe(time: time, easing: easing, interpolation: interpolation, loop: loop, implicitSplited: implicitSplited)
    }
    static func index(time t: Int, with keyframes: [Keyframe]) -> (index: Int, interValue: Int, sectionValue: Int) {
        var oldT = 0
        for i in (0 ..< keyframes.count).reversed() {
            let keyframe = keyframes[i]
            if t >= keyframe.time {
                return (i, t - keyframe.time, oldT - keyframe.time)
            }
            oldT = keyframe.time
        }
        return (0, t -  keyframes.first!.time, oldT - keyframes.first!.time)
    }
    func equalOption(other: Keyframe) -> Bool {
        return easing == other.easing && interpolation == other.interpolation && loop == other.loop
    }
}
struct Loop: Equatable, ByteCoding {
    let isStart: Bool, isEnd: Bool
    
    init(isStart: Bool = false, isEnd: Bool = false) {
        self.isStart = isStart
        self.isEnd = isEnd
    }
    
    static func == (lhs: Loop, rhs: Loop) -> Bool {
        return lhs.isStart == rhs.isStart && lhs.isEnd == rhs.isEnd
    }
}

final class DrawingItem: NSObject, NSCoding, Copying {
    var drawing: Drawing, color: CGColor
    fileprivate(set) var keyDrawings: [Drawing]
    
    func update(with f0: Int) {
        drawing = keyDrawings[f0]
    }
    
    init(drawing: Drawing = Drawing(), keyDrawings: [Drawing] = [], color: CGColor = SceneDefaults.strokeLineColor) {
        self.drawing = drawing
        self.keyDrawings = keyDrawings.isEmpty ? [drawing] : keyDrawings
        self.color = color
    }
    
    static let dataType = "C0.DrawingItem.1", drawingKey = "0", keyDrawingsKey = "1"
    init(coder: NSCoder) {
        drawing = coder.decodeObject(forKey: DrawingItem.drawingKey) as? Drawing ?? Drawing()
        keyDrawings = coder.decodeObject(forKey: DrawingItem.keyDrawingsKey) as? [Drawing] ?? []
        color = SceneDefaults.strokeLineColor
    }
    func encode(with coder: NSCoder) {
        coder.encode(drawing, forKey: DrawingItem.drawingKey)
        coder.encode(keyDrawings, forKey: DrawingItem.keyDrawingsKey)
    }
    
    var deepCopy: DrawingItem {
        let copyDrawings = keyDrawings.map { $0.deepCopy }, copyDrawing: Drawing
        if let i = keyDrawings.index(of: drawing) {
            copyDrawing = copyDrawings[i]
        } else {
            copyDrawing = drawing.deepCopy
        }
        return DrawingItem(drawing: copyDrawing, keyDrawings: copyDrawings, color: color)
    }
    var imageBounds: CGRect {
        return drawing.imageBounds(withLineWidth: SceneDefaults.strokeLineWidth)
    }
    func draw(with di: DrawInfo, in ctx: CGContext) {
        drawing.draw(lineWidth: SceneDefaults.strokeLineWidth*di.reciprocalCameraScale, lineColor: color, in: ctx)
    }
    func drawEdit(with di: DrawInfo, in ctx: CGContext) {
        let lineWidth = SceneDefaults.strokeLineWidth*di.reciprocalCameraScale
        drawing.drawRough(lineWidth: lineWidth, lineColor: SceneDefaults.roughColor, in: ctx)
        drawing.draw(lineWidth: lineWidth, lineColor: color, in: ctx)
        drawing.drawSelectionLines(lineWidth: lineWidth + 1.5, lineColor: SceneDefaults.selectionColor, in: ctx)
    }
    func drawPreviousNext(isShownPrevious: Bool, isShownNext: Bool, index: Int, with di: DrawInfo, in ctx: CGContext) {
        let lineWidth = SceneDefaults.strokeLineWidth*di.reciprocalCameraScale
        if isShownPrevious && index - 1 >= 0 {
            keyDrawings[index - 1].draw(lineWidth: lineWidth, lineColor: SceneDefaults.previousColor, in: ctx)
        }
        if isShownNext && index + 1 <= keyDrawings.count - 1 {
            keyDrawings[index + 1].draw(lineWidth: lineWidth, lineColor: SceneDefaults.nextColor, in: ctx)
        }
    }
}
final class CellItem: NSObject, NSCoding, Copying {
    var cell: Cell
    fileprivate(set) var keyGeometries: [Geometry], keyMaterials: [Material]
    func replaceGeometry(_ geometry: Geometry, at i: Int) {
        keyGeometries[i] = geometry
        cell.geometry = geometry
    }
    
    func step(_ f0: Int) {
        if !keyMaterials.isEmpty {
            cell.material = keyMaterials[f0]
        }
        cell.geometry = keyGeometries[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        if !keyMaterials.isEmpty {
            cell.material = Material.linear(keyMaterials[f0], keyMaterials[f1], t: t)
        }
        cell.geometry = Geometry.linear(keyGeometries[f0], keyGeometries[f1], t: t)
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        if !keyMaterials.isEmpty {
            cell.material = Material.firstMonospline(keyMaterials[f1], keyMaterials[f2], keyMaterials[f3], with: msx)
        }
        cell.geometry = Geometry.firstMonospline(keyGeometries[f1], keyGeometries[f2], keyGeometries[f3], with: msx)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        if !keyMaterials.isEmpty {
            cell.material = Material.monospline(keyMaterials[f0], keyMaterials[f1], keyMaterials[f2], keyMaterials[f3], with: msx)
        }
        cell.geometry = Geometry.monospline(keyGeometries[f0], keyGeometries[f1], keyGeometries[f2], keyGeometries[f3], with: msx)
    }
    func endMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with msx: MonosplineX) {
        if !keyMaterials.isEmpty {
            cell.material = Material.endMonospline(keyMaterials[f0], keyMaterials[f1], keyMaterials[f2], with: msx)
        }
        cell.geometry = Geometry.endMonospline(keyGeometries[f0], keyGeometries[f1], keyGeometries[f2], with: msx)
    }
    
    init(cell: Cell, keyGeometries: [Geometry] = [], keyMaterials: [Material] = []) {
        self.cell = cell
        self.keyGeometries = keyGeometries
        self.keyMaterials = keyMaterials
        super.init()
    }
    
    static let dataType = "C0.CellItem.1", cellKey = "0", keyGeometriesKey = "1", keyMaterialsKey = "2"
    init?(coder: NSCoder) {
        cell = coder.decodeObject(forKey: CellItem.cellKey) as? Cell ?? Cell()
        keyGeometries = coder.decodeObject(forKey: CellItem.keyGeometriesKey) as? [Geometry] ?? []
        keyMaterials = coder.decodeObject(forKey: CellItem.keyMaterialsKey) as? [Material] ?? []
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(cell, forKey: CellItem.cellKey)
        coder.encode(keyGeometries, forKey: CellItem.keyGeometriesKey)
        coder.encode(keyMaterials, forKey: CellItem.keyMaterialsKey)
    }
    
    var deepCopy: CellItem {
        return CellItem(cell: cell.deepCopy, keyGeometries: keyGeometries, keyMaterials: keyMaterials)
    }
    
    var isEmptyKeyGeometries: Bool {
        for keyGeometry in keyGeometries {
            if !keyGeometry.isEmpty {
                return false
            }
        }
        return true
    }
}
final class TransformItem: NSObject, NSCoding, Copying {
    var transform: Transform
    fileprivate(set) var keyTransforms: [Transform]
    func replaceTransform(_ transform: Transform, at i: Int) {
        keyTransforms[i] = transform
        self.transform = transform
    }
    
    func step(_ f0: Int) {
        transform = keyTransforms[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        transform = Transform.linear(keyTransforms[f0], keyTransforms[f1], t: t)
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        transform = Transform.firstMonospline(keyTransforms[f1], keyTransforms[f2], keyTransforms[f3], with: msx)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        transform = Transform.monospline(keyTransforms[f0], keyTransforms[f1], keyTransforms[f2], keyTransforms[f3], with: msx)
    }
    func endMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with msx: MonosplineX) {
        transform = Transform.endMonospline(keyTransforms[f0], keyTransforms[f1], keyTransforms[f2], with: msx)
    }
    
    init(transform: Transform = Transform(), keyTransforms: [Transform] = [Transform()]) {
        self.transform = transform
        self.keyTransforms = keyTransforms
        super.init()
    }
    
    static let dataType = "C0.TransformItem.1", transformKey = "0", keyTransformsKey = "1"
    init(coder: NSCoder) {
        transform = coder.decodeStruct(forKey: TransformItem.transformKey) ?? Transform()
        keyTransforms = coder.decodeStruct(forKey: TransformItem.keyTransformsKey) ?? []
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeStruct(transform, forKey: TransformItem.transformKey)
        coder.encodeStruct(keyTransforms, forKey: TransformItem.keyTransformsKey)
    }
    
    static func empty(with group: Group) ->  TransformItem {
        let transformItem =  TransformItem()
        let transforms = group.keyframes.map { _ in Transform() }
        transformItem.keyTransforms = transforms
        transformItem.transform = transforms[group.editKeyframeIndex]
        return transformItem
    }
    var deepCopy:  TransformItem {
        return TransformItem(transform: transform, keyTransforms: keyTransforms)
    }
    var isEmpty: Bool {
        for t in keyTransforms {
            if !t.isEmpty {
                return false
            }
        }
        return true
    }
}
final class TextItem: NSObject, NSCoding, Copying {
    var text: Text
    fileprivate(set) var keyTexts: [Text]
    func replaceText(_ text: Text, at i: Int) {
        keyTexts[i] = text
        self.text = text
    }
    
    func update(with f0: Int) {
        text = keyTexts[f0]
    }
    
    init(text: Text = Text(), keyTexts: [Text] = [Text()]) {
        self.text = text
        self.keyTexts = keyTexts
        super.init()
    }
    
    static let dataType = "C0.TextItem.1", textKey = "0", keyTextsKey = "1"
    init?(coder: NSCoder) {
        text = coder.decodeObject(forKey: TextItem.textKey) as? Text ?? Text()
        keyTexts = coder.decodeObject(forKey: TextItem.keyTextsKey) as? [Text] ?? []
    }
    func encode(with coder: NSCoder) {
        coder.encode(text, forKey: TextItem.textKey)
        coder.encode(keyTexts, forKey: TextItem.keyTextsKey)
    }
    
    var deepCopy: TextItem {
        return TextItem(text: text, keyTexts: keyTexts)
    }
    var isEmpty: Bool {
        for t in keyTexts {
            if !t.isEmpty {
                return false
            }
        }
        return true
    }
}

final class SoundItem: NSObject, NSCoding, Copying {
    var sound: NSSound?
    var name = ""
    var isHidden = false {
        didSet {
            sound?.volume = isHidden ? 0 : 1
        }
    }
    
    init(sound: NSSound? = nil, name: String = "", isHidden: Bool = false) {
        self.sound = sound
        self.name = name
        self.isHidden = isHidden
        super.init()
    }
    
    static let dataType = "C0.SoundItem.1", soundKey = "0", nameKey = "1", isHiddenKey = "2"
    init?(coder: NSCoder) {
        sound = coder.decodeObject(forKey:SoundItem.soundKey) as? NSSound
        name = coder.decodeObject(forKey: SoundItem.nameKey) as? String ?? ""
        isHidden = coder.decodeBool(forKey: SoundItem.isHiddenKey)
    }
    func encode(with coder: NSCoder) {
        coder.encode(sound, forKey: SoundItem.soundKey)
        coder.encode(name, forKey: SoundItem.nameKey)
        coder.encode(isHidden, forKey: SoundItem.isHiddenKey)
    }
    
    var deepCopy: SoundItem {
        return SoundItem(sound: sound?.copy(with: nil) as? NSSound, name: name, isHidden: isHidden)
    }
}

struct Transform: Equatable, ByteCoding, Interpolatable {
    let position: CGPoint, scale: CGSize, zoomScale: CGSize, rotation: CGFloat, wiggle: Wiggle
    
    init(position: CGPoint = CGPoint(), scale: CGSize = CGSize(), rotation: CGFloat = 0, wiggle: Wiggle = Wiggle()) {
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.wiggle = wiggle
        self.zoomScale = CGSize(width: pow(2, scale.width), height: pow(2, scale.height))
    }
    
     static let dataType = "C0.Transform.1"
    
    func withPosition(_ position: CGPoint) -> Transform {
        return Transform(position: position, scale: scale, rotation: rotation, wiggle: wiggle)
    }
    func withScale(_ scale: CGFloat) -> Transform {
        return Transform(position: position, scale: CGSize(width: scale, height: scale), rotation: rotation, wiggle: wiggle)
    }
    func withScale(_ scale: CGSize) -> Transform {
        return Transform(position: position, scale: scale, rotation: rotation, wiggle: wiggle)
    }
    func withRotation(_ rotation: CGFloat) -> Transform {
        return Transform(position: position, scale: scale, rotation: rotation, wiggle: wiggle)
    }
    func withWiggle(_ wiggle: Wiggle) -> Transform {
        return Transform(position: position, scale: scale, rotation: rotation, wiggle: wiggle)
    }
    
    static func linear(_ f0: Transform, _ f1: Transform, t: CGFloat) -> Transform {
        let newPosition = CGPoint.linear(f0.position, f1.position, t: t)
        let newScaleX = CGFloat.linear(f0.scale.width, f1.scale.width, t: t)
        let newScaleY = CGFloat.linear(f0.scale.height, f1.scale.height, t: t)
        let newRotation = CGFloat.linear(f0.rotation, f1.rotation, t: t)
        let newWiggle = Wiggle.linear(f0.wiggle, f1.wiggle, t: t)
        return Transform(position: newPosition, scale: CGSize(width: newScaleX, height: newScaleY), rotation: newRotation, wiggle: newWiggle)
    }
    static func firstMonospline(_ f1: Transform, _ f2: Transform, _ f3: Transform, with msx: MonosplineX) -> Transform {
        let newPosition = CGPoint.firstMonospline(f1.position, f2.position, f3.position, with: msx)
        let newScaleX = CGFloat.firstMonospline(f1.scale.width, f2.scale.width, f3.scale.width, with: msx)
        let newScaleY = CGFloat.firstMonospline(f1.scale.height, f2.scale.height, f3.scale.height, with: msx)
        let newRotation = CGFloat.firstMonospline(f1.rotation, f2.rotation, f3.rotation, with: msx)
        let newWiggle = Wiggle.firstMonospline(f1.wiggle, f2.wiggle, f3.wiggle, with: msx)
        return Transform(position: newPosition, scale: CGSize(width: newScaleX, height: newScaleY), rotation: newRotation, wiggle: newWiggle)
    }
    static func monospline(_ f0: Transform, _ f1: Transform, _ f2: Transform, _ f3: Transform, with msx: MonosplineX) -> Transform {
        let newPosition = CGPoint.monospline(f0.position, f1.position, f2.position, f3.position, with: msx)
        let newScaleX = CGFloat.monospline(f0.scale.width, f1.scale.width, f2.scale.width, f3.scale.width, with: msx)
        let newScaleY = CGFloat.monospline(f0.scale.height, f1.scale.height, f2.scale.height, f3.scale.height, with: msx)
        let newRotation = CGFloat.monospline(f0.rotation, f1.rotation, f2.rotation, f3.rotation, with: msx)
        let newWiggle = Wiggle.monospline(f0.wiggle, f1.wiggle, f2.wiggle, f3.wiggle, with: msx)
        return Transform(position: newPosition, scale: CGSize(width: newScaleX, height: newScaleY), rotation: newRotation, wiggle: newWiggle)
    }
    static func endMonospline(_ f0: Transform, _ f1: Transform, _ f2: Transform, with msx: MonosplineX) -> Transform {
        let newPosition = CGPoint.endMonospline(f0.position, f1.position, f2.position, with: msx)
        let newScaleX = CGFloat.endMonospline(f0.scale.width, f1.scale.width, f2.scale.width, with: msx)
        let newScaleY = CGFloat.endMonospline(f0.scale.height, f1.scale.height, f2.scale.height, with: msx)
        let newRotation = CGFloat.endMonospline(f0.rotation, f1.rotation, f2.rotation, with: msx)
        let newWiggle = Wiggle.endMonospline(f0.wiggle, f1.wiggle, f2.wiggle, with: msx)
        return Transform(position: newPosition, scale: CGSize(width: newScaleX, height: newScaleY), rotation: newRotation, wiggle: newWiggle)
    }
    
    var isEmpty: Bool {
        return position == CGPoint() && scale == CGSize() && rotation == 0 && !wiggle.isMove
    }
    func affineTransform(with bounds: CGRect) -> CGAffineTransform {
        var affine = CGAffineTransform(translationX: bounds.width/2, y: bounds.height/2)
        if rotation != 0 {
            affine = affine.rotated(by: rotation)
        }
        if scale != CGSize() {
            affine = affine.scaledBy(x: zoomScale.width, y: zoomScale.height)
        }
        return affine.translatedBy(x: position.x - bounds.width/2, y: position.y - bounds.height/2)
    }
    static func == (lhs: Transform, rhs: Transform) -> Bool {
        return lhs.position == rhs.position && lhs.scale == rhs.scale && lhs.rotation == rhs.rotation && lhs.wiggle == rhs.wiggle
    }
}
struct Wiggle: Equatable, Interpolatable {
    let maxSize: CGSize, hz: CGFloat
    
    init(maxSize: CGSize = CGSize(), hz: CGFloat = 8) {
        self.maxSize = maxSize
        self.hz = hz
    }
    
    func withMaxSize(_ maxSize: CGSize) -> Wiggle {
        return Wiggle(maxSize: maxSize, hz: hz)
    }
    func withHz(_ hz: CGFloat) -> Wiggle {
        return Wiggle(maxSize: maxSize, hz: hz)
    }
    
    static func linear(_ f0: Wiggle, _ f1: Wiggle, t: CGFloat) -> Wiggle {
        let newMaxWidth = CGFloat.linear(f0.maxSize.width, f1.maxSize.width, t: t)
        let newMaxHeight = CGFloat.linear(f0.maxSize.height, f1.maxSize.height, t: t)
        let newHz = CGFloat.linear(f0.hz, f1.hz, t: t)
        return Wiggle(maxSize: CGSize(width: newMaxWidth, height: newMaxHeight), hz: newHz)
    }
    static func firstMonospline(_ f1: Wiggle, _ f2: Wiggle, _ f3: Wiggle, with msx: MonosplineX) -> Wiggle {
        let newMaxWidth = CGFloat.firstMonospline(f1.maxSize.width, f2.maxSize.width, f3.maxSize.width, with: msx)
        let newMaxHeight = CGFloat.firstMonospline(f1.maxSize.height, f2.maxSize.height, f3.maxSize.height, with: msx)
        let newHz = CGFloat.firstMonospline(f1.hz, f2.hz, f3.hz, with: msx)
        return Wiggle(maxSize: CGSize(width: newMaxWidth, height: newMaxHeight), hz: newHz)
    }
    static func monospline(_ f0: Wiggle, _ f1: Wiggle, _ f2: Wiggle, _ f3: Wiggle, with msx: MonosplineX) -> Wiggle {
        let newMaxWidth = CGFloat.monospline(f0.maxSize.width, f1.maxSize.width, f2.maxSize.width, f3.maxSize.width, with: msx)
        let newMaxHeight = CGFloat.monospline(f0.maxSize.height, f1.maxSize.height, f2.maxSize.height, f3.maxSize.height, with: msx)
        let newHz = CGFloat.monospline(f0.hz, f1.hz, f2.hz, f3.hz, with: msx)
        return Wiggle(maxSize: CGSize(width: newMaxWidth, height: newMaxHeight), hz: newHz)
    }
    static func endMonospline(_ f0: Wiggle, _ f1: Wiggle, _ f2: Wiggle, with msx: MonosplineX) -> Wiggle {
        let newMaxWidth = CGFloat.endMonospline(f0.maxSize.width, f1.maxSize.width, f2.maxSize.width, with: msx)
        let newMaxHeight = CGFloat.endMonospline(f0.maxSize.height, f1.maxSize.height, f2.maxSize.height, with: msx)
        let newHz = CGFloat.endMonospline(f0.hz, f1.hz, f2.hz, with: msx)
        return Wiggle(maxSize: CGSize(width: newMaxWidth, height: newMaxHeight), hz: newHz)
    }
    
    var isMove: Bool {
        return maxSize != CGSize()
    }
    func newPosition(_ position: CGPoint, phase: CGFloat) -> CGPoint {
        let x = sin(2*(.pi)*phase)
        return CGPoint(x: position.x + maxSize.width*x, y: position.y + maxSize.height*x)
    }
    static func == (lhs: Wiggle, rhs: Wiggle) -> Bool {
        return lhs.maxSize == rhs.maxSize && lhs.hz == rhs.hz
    }
}
