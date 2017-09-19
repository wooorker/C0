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
import AppKit.NSColor
import AppKit.NSFont

struct SceneDefaults {
    static let roughColor = NSColor(red: 0, green: 0.5, blue: 1, alpha: 0.15).cgColor
    static let subRoughColor = NSColor(red: 0, green: 0.5, blue: 1, alpha: 0.1).cgColor
    static let previousColor = NSColor(red: 1, green: 0, blue: 0, alpha: 0.1).cgColor
    static let subPreviousColor = NSColor(red: 1, green: 0.2, blue: 0.2, alpha: 0.025).cgColor
    static let previousSkinColor = SceneDefaults.previousColor.copy(alpha: 1)!
    static let subPreviousSkinColor = SceneDefaults.subPreviousColor.copy(alpha: 0.08)!
    static let nextColor = NSColor(red: 0.2, green: 0.8, blue: 0, alpha: 0.1).cgColor
    static let subNextColor = NSColor(red: 0.4, green: 1, blue: 0, alpha: 0.025).cgColor
    static let nextSkinColor = SceneDefaults.nextColor.copy(alpha: 1)!
    static let subNextSkinColor = SceneDefaults.subNextColor.copy(alpha: 0.08)!
    static let selectionColor = NSColor(red: 0.1, green: 0.7, blue: 1, alpha: 1).cgColor
    static let interpolationColor = NSColor(red: 0.1, green: 0.9, blue: 0.5, alpha: 1).cgColor
    static let subSelectionColor = NSColor(red: 0.8, green: 0.95, blue: 1, alpha: 0.6).cgColor
    static let subSelectionSkinColor =  SceneDefaults.subSelectionColor.copy(alpha: 0.3)!
    static let selectionSkinLineColor =  SceneDefaults.subSelectionColor.copy(alpha: 1.0)!
    
    static let editMaterialColor = NSColor(red: 1, green: 0.5, blue: 0, alpha: 0.2).cgColor
    static let editMaterialColorColor = NSColor(red: 1, green: 0.75, blue: 0, alpha: 0.2).cgColor
    
    static let cellBorderNormalColor = NSColor(white: 0, alpha: 0.15).cgColor
    static let cellBorderColor = NSColor(white: 0, alpha: 0.1).cgColor
    static let cellIndicationNormalColor = SceneDefaults.selectionColor.copy(alpha: 0.9)!
    static let cellIndicationColor = SceneDefaults.selectionColor.copy(alpha: 0.4)!
    
    static let controlPointInColor = Defaults.contentColor.cgColor
    static let controlPointOutColor = Defaults.editColor.cgColor
    static let editControlPointInColor = NSColor(red: 1, green: 0, blue: 0, alpha: 0.8).cgColor
    static let editControlPointOutColor = NSColor(red: 1, green: 0.5, blue: 0.5, alpha: 0.3).cgColor
    static let contolLineInColor = NSColor(red: 1, green: 0.5, blue: 0.5, alpha: 0.3).cgColor
    static let contolLineOutColor = NSColor(red: 1, green: 0, blue: 0, alpha: 0.3).cgColor
    static let editLineColor = NSColor(red: 1, green: 0, blue: 0, alpha: 0.8).cgColor
    
    static let moveZColor = NSColor(red: 1, green: 0, blue: 0, alpha: 1).cgColor
    static let moveZSelectionColor = NSColor(red: 1, green: 0.5, blue: 0, alpha: 1).cgColor
    
    static let cameraColor = NSColor(red: 0.7, green: 0.6, blue: 0, alpha: 1).cgColor
    static let cameraBorderColor = NSColor(red: 1, green: 0, blue: 0, alpha: 0.5).cgColor
    static let cutBorderColor = NSColor(red: 0.3, green: 0.46, blue: 0.7, alpha: 0.5).cgColor
    static let cutSubBorderColor = NSColor(white: 1, alpha: 0.5).cgColor
    
    static let backgroundColor = NSColor(red: 1, green: 1, blue: 1, alpha: 1).cgColor
    
    static let strokeLineWidth = 1.25.cf, strokeLineColor = NSColor(white: 0, alpha: 1).cgColor
    static let playBorderColor = NSColor(white: 0.3, alpha: 1).cgColor
    
    static let speechBorderColor = NSColor(white: 0, alpha: 1).cgColor
    static let speechFillColor = NSColor(white: 1, alpha: 1).cgColor
    static let speechFont = NSFont.boldSystemFont(ofSize: 25) as CTFont
}

final class Scene: NSObject, NSCoding {
    var cameraFrame: CGRect {
        didSet {
            affineTransform = viewTransform.affineTransform(with: cameraFrame)
        }
    }
    var frameRate: Int, time: Int, material: Material, isShownPrevious: Bool, isShownNext: Bool, soundItem: SoundItem
    var viewTransform: ViewTransform {
        didSet {
            affineTransform = viewTransform.affineTransform(with: cameraFrame)
        }
    }
    private(set) var affineTransform: CGAffineTransform?
    
    init(cameraFrame: CGRect = CGRect(x: 0, y: 0, width: 640, height: 360), frameRate: Int = 24, time: Int = 0, material: Material = Material(), isShownPrevious: Bool = false, isShownNext: Bool = false, soundItem: SoundItem = SoundItem(), viewTransform: ViewTransform = ViewTransform()) {
        self.cameraFrame = cameraFrame
        self.frameRate = frameRate
        self.time = time
        self.material = material
        self.isShownPrevious = isShownPrevious
        self.isShownNext = isShownNext
        self.soundItem = soundItem
        self.viewTransform = viewTransform
        
        affineTransform = viewTransform.affineTransform(with: cameraFrame)
        super.init()
    }
    
    static let dataType = "C0.Scene.1", cameraFrameKey = "0", frameRateKey = "1", timeKey = "2", materialKey = "3", isShownPreviousKey = "4", isShownNextKey = "5", soundItemKey = "7", viewTransformKey = "6"
    init?(coder: NSCoder) {
        cameraFrame = coder.decodeRect(forKey: Scene.cameraFrameKey)
        frameRate = coder.decodeInteger(forKey: Scene.frameRateKey)
        time = coder.decodeInteger(forKey: Scene.timeKey)
        material = coder.decodeObject(forKey: Scene.materialKey) as? Material ?? Material()
        isShownPrevious = coder.decodeBool(forKey: Scene.isShownPreviousKey)
        isShownNext = coder.decodeBool(forKey: Scene.isShownNextKey)
        soundItem = coder.decodeObject(forKey: Scene.soundItemKey) as? SoundItem ?? SoundItem()
        viewTransform = coder.decodeStruct(forKey: Scene.viewTransformKey) ?? ViewTransform()
        affineTransform = viewTransform.affineTransform(with: cameraFrame)
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(cameraFrame, forKey: Scene.cameraFrameKey)
        coder.encode(frameRate, forKey: Scene.frameRateKey)
        coder.encode(time, forKey: Scene.timeKey)
        coder.encode(material, forKey: Scene.materialKey)
        coder.encode(isShownPrevious, forKey: Scene.isShownPreviousKey)
        coder.encode(isShownNext, forKey: Scene.isShownNextKey)
        coder.encode(soundItem, forKey: Scene.soundItemKey)
        coder.encodeStruct(viewTransform, forKey: Scene.viewTransformKey)
    }
    
    func convertTime(frameTime ft: Int) -> TimeInterval {
        return TimeInterval(ft)/TimeInterval(frameRate)
    }
    func convertFrameTime(time t: TimeInterval) -> Int {
        return Int(t*TimeInterval(frameRate))
    }
    var secondTime: (second: Int, frame: Int) {
        let second = time/frameRate
        return (second, time - second*frameRate)
    }
}
struct ViewTransform: ByteCoding {
    var position = CGPoint(), scale = 1.0.cf, rotation = 0.0.cf, isFlippedHorizontal = false
    var isIdentity: Bool {
        return position == CGPoint() && scale == 1 && rotation == 0
    }
    func affineTransform(with bounds: CGRect) -> CGAffineTransform? {
        if scale == 1 && rotation == 0 && position == CGPoint() && !isFlippedHorizontal {
            return nil
        }
        var affine = CGAffineTransform.identity
        affine = affine.translatedBy(x: bounds.midX + position.x, y: bounds.midY + position.y)
        affine = affine.rotated(by: rotation)
        affine = affine.scaledBy(x: scale, y: scale)
        affine = affine.translatedBy(x: -bounds.midX, y: -bounds.midY)
        if isFlippedHorizontal {
            affine = affine.flippedHorizontal(by: bounds.width)
        }
        return affine
    }
}

struct DrawInfo {
    let scale: CGFloat, cameraScale: CGFloat, invertScale: CGFloat, invertCameraScale: CGFloat, rotation: CGFloat
    init(scale: CGFloat = 1, cameraScale: CGFloat = 1, rotation: CGFloat = 0) {
        if scale == 0 || cameraScale == 0 {
            fatalError()
        }
        self.scale = scale
        self.cameraScale = cameraScale
        self.invertScale = 1/scale
        self.invertCameraScale = 1/cameraScale
        self.rotation = rotation
    }
}
final class Cut: NSObject, NSCoding, Copying {
    enum ViewType: Int32 {
        case edit, editPoint, editLine, editTransform, editMoveZ, editMaterial, editingMaterial, preview
    }
    enum TransformViewType {
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
                let invertTransformCount = 1/transformCount.cf
                let wiggle = Wiggle(maxSize: wiggleSize, hz: hz*invertTransformCount)
                transform = Transform(position: position, scale: scale, rotation: rotation, wiggle: wiggle)
                wigglePhase = phase*invertTransformCount
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
            return [(cell, cell.geometry)]
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
    
    struct NearestDrawing {
        let drawing: Drawing, line: Line, lineIndex: Int, pointIndex: Int, controlLineIndex: Int, oldControl: Line.Control
    }
    struct NearestGeometry {
        let cellItem: CellItem, geometry: Geometry, bezierIndex: Int, t: CGFloat, bezierPoint: Bezier2.Point, oldPoint: CGPoint
    }
    func nearestEditPoint(_ point: CGPoint) -> (nearestDrawing: NearestDrawing?, nearestGeometry: NearestGeometry?) {
//        var minD = CGFloat.infinity, lineIndex = 0, pointIndex = 0, minLine: Line?
//        func nearestEditPoint(from lines: [Line]) -> Bool {
//            var isNearest = false
//            for (j, line) in lines.enumerated() {
//                line.allEditPoints() { p, i, stop in
//                    let d = hypot2(point.x - p.x, point.y - p.y)
//                    if d < minD {
//                        minD = d
//                        minLine = line
//                        lineIndex = j
//                        pointIndex = i
//                        isNearest = true
//                    }
//                }
//            }
//            return isNearest
//        }
//        var drawing: Drawing?, cellItem: CellItem?, geometry: Geometry?, bezierIndex = 0, t = 0.0.cf
//        for aCellItem in editGroup.cellItems {
//            if let nb = aCellItem.cell.geometry.nearestBezier(with: point) {
//                if nb.minDistance < minD {
//                    minD = nb.minDistance
//                    cellItem = aCellItem
//                    geometry = aCellItem.cell.geometry
//                    bezierIndex = nb.index
//                    t = nb.t
//                }
//            }
//        }
//        if nearestEditPoint(from: editGroup.drawingItem.drawing.lines) {
//            drawing = editGroup.drawingItem.drawing
//            cellItem = nil
//            geometry = nil
//        }
//        if let cellItem = cellItem {
//            let bezierPoint: Bezier2.Point
//            if t < 0.33 {
//                bezierPoint = .p0
//            } else if t < 0.66 {
//                bezierPoint = .cp
//            } else {
//                bezierPoint = .p1
//            }
//            let bezier = cellItem.cell.geometry.beziers[bezierIndex]
//            return (nil, NearestGeometry(cellItem: cellItem, geometry: cellItem.cell.geometry, bezierIndex: bezierIndex, t: t, bezierPoint: bezierPoint, oldPoint: bezierPoint == .p0 ? bezier.p0 : (bezierPoint == .cp ? bezier.cp : bezier.p1)))
//        } else if let minLine = minLine, let drawing = drawing {
//            func nearestControlLineIndex(line: Line) ->Int {
//                var minD = CGFloat.infinity, minIndex = 0
//                for i in 0 ..< line.points.count - 1 {
//                    let d = point.distance(line.points[i].mid(line.points[i + 1]))
//                    if d < minD {
//                        minD = d
//                        minIndex = i
//                    }
//                }
//                return minIndex
//            }
//            return (NearestDrawing(drawing: drawing, line: minLine, lineIndex: lineIndex, pointIndex: pointIndex, controlLineIndex: nearestControlLineIndex(line: minLine), oldPoint: minLine.points[pointIndex]), nil)
//        }
        return (nil, nil)
    }
    
    struct VertexDrawing {
        let drawing: Drawing, line: Line, otherLine: Line?, index: Int, otherIndex: Int, isFirst: Bool, isOtherFirst: Bool, oldPoint: CGPoint
    }
    struct VertexGeometry {
        let vertexs: [(cellItem: CellItem, geometry: Geometry, beziers: [(index: Int, bezierPoint: Bezier2.Point, isMoveCP: Bool)])], oldPoint: CGPoint
    }
    struct VertexControlGeometry {
        let cellItem: CellItem, geometry: Geometry, bezierIndex: Int
        let controls: [(cellItem: CellItem, geometry: Geometry, bezierIndex: Int, connectBezierPoint: Bezier2.Point, controlBezierPoint: Bezier2.Point)], oldPoint: CGPoint
    }
    func nearestVertex(_ point: CGPoint) -> (vertexDrawing: VertexDrawing?, vertexGeometry: VertexGeometry?, vertexControlGeometry: VertexControlGeometry?) {
        var minD = CGFloat.infinity, vertexDrawing: VertexDrawing?
        func nearestVertex(with drawing: Drawing, from lines: [Line]) -> Bool {
            var j = lines.count - 1, isNearest = false
            if var oldLine = lines.last {
                for (i, line) in lines.enumerated() {
                    let lp = oldLine.lastPoint, fp = line.firstPoint
                    if lp != fp {
                        let d = hypot2(point.x - lp.x, point.y - lp.y)
                        if d < minD {
                            minD = d
                            vertexDrawing = VertexDrawing(drawing: drawing, line: oldLine, otherLine: nil, index: j, otherIndex: i, isFirst: false, isOtherFirst: false, oldPoint: lp)
                            isNearest = true
                        }
                    }
                    let d = hypot2(point.x - fp.x, point.y - fp.y)
                    if d < minD {
                        minD = d
                        vertexDrawing = VertexDrawing(drawing: drawing, line: line, otherLine: lp != fp ? nil : oldLine, index: i, otherIndex: j, isFirst: true, isOtherFirst: false, oldPoint: fp)
                        isNearest = true
                    }
                    oldLine = line
                    j = i
                }
            }
            return isNearest
        }
        
        if nearestVertex(with: editGroup.drawingItem.drawing, from: editGroup.drawingItem.drawing.lines) {
        }
        var cellItem: CellItem?, geometry: Geometry?, bezierIndex = 0, t = 0.0.cf
        for aCellItem in editGroup.cellItems {
            if let nb = aCellItem.cell.geometry.nearestBezier(with: point) {
                if nb.minDistance < minD {
                    minD = nb.minDistance
                    cellItem = aCellItem
                    geometry = aCellItem.cell.geometry
                    bezierIndex = nb.index
                    t = nb.t
                    vertexDrawing = nil
                }
            }
        }
        if let v = vertexDrawing {
            return (v, nil, nil)
        } else if let cellItem = cellItem, let geometry = geometry {
            let bezierPoint: Bezier2.Point
            if t < 0.25 {
                bezierPoint = .p0
            } else if t < 0.75 {
                bezierPoint = .cp
            } else {
                bezierPoint = .p1
            }
            let bezier = geometry.beziers[bezierIndex]
            if bezierPoint == .cp {
                let cp = bezier.cp
                var controls: [(cellItem: CellItem, geometry: Geometry, bezierIndex: Int, connectBezierPoint: Bezier2.Point, controlBezierPoint: Bezier2.Point)] = []
                for aCellItem in editGroup.cellItems {
                    for (i, aBezier) in aCellItem.cell.geometry.beziers.enumerated() {
                        if aCellItem == cellItem && i == bezierIndex {
                            continue
                        }
                        if aBezier.p0 == bezier.p0 {
                            if cp.tangential(bezier.p0).isEqualAngle(aBezier.cp.tangential(aBezier.p0)) {
                                controls.append((aCellItem, aCellItem.cell.geometry, i, .p0, .p0))
                            }
                        } else if aBezier.p0 == bezier.p1 {
                            if cp.tangential(bezier.p1).isEqualAngle(aBezier.cp.tangential(aBezier.p0)) {
                                controls.append((aCellItem, aCellItem.cell.geometry, i, .p0, .p1))
                            }
                        } else if aBezier.p1 == bezier.p0 {
                            if cp.tangential(bezier.p0).isEqualAngle(aBezier.cp.tangential(aBezier.p1)) {
                                controls.append((aCellItem, aCellItem.cell.geometry, i, .p1, .p0))
                            }
                        } else if aBezier.p1 == bezier.p1 {
                            if cp.tangential(bezier.p1).isEqualAngle(aBezier.cp.tangential(aBezier.p1)) {
                                controls.append((aCellItem, aCellItem.cell.geometry, i, .p1, .p1))
                            }
                        }
                    }
                }
                return (nil, nil, VertexControlGeometry(cellItem: cellItem, geometry: geometry, bezierIndex: bezierIndex, controls: controls, oldPoint: cp))
            } else {
                let p = bezierPoint == .p0 ? bezier.p0 : bezier.p1
                class Beziers {
                    var index: Int, bezierPoint: Bezier2.Point, isMoveCP: Bool, theta: CGFloat
                    init(index: Int, bezierPoint: Bezier2.Point, isMoveCP: Bool, theta: CGFloat) {
                        self.index = index
                        self.bezierPoint = bezierPoint
                        self.isMoveCP = isMoveCP
                        self.theta = theta
                    }
                }
                class Vertexs {
                    var cellItem: CellItem, geometry: Geometry, beziers: [Beziers]
                    init(cellItem: CellItem, geometry: Geometry, beziers: [Beziers]) {
                        self.cellItem = cellItem
                        self.geometry = geometry
                        self.beziers = beziers
                    }
                }
                var vertexs: [Vertexs] = []
                for aCellItem in editGroup.cellItems {
                    var beziers: [Beziers] = []
                    for (i, aBezier) in aCellItem.cell.geometry.beziers.enumerated() {
                        if aBezier.p0 == p {
                            let theta = aBezier.p0.tangential(aBezier.cp)
                            var isMoveCP = false
                            for v in vertexs {
                                for b in v.beziers {
                                    if b.theta.isEqualAngle(theta) {
                                        b.isMoveCP = true
                                        isMoveCP = true
                                    }
                                }
                            }
                            for b in beziers {
                                if b.theta.isEqualAngle(theta) {
                                    b.isMoveCP = true
                                    isMoveCP = true
                                }
                            }
                            beziers.append(Beziers(index: i, bezierPoint: .p0, isMoveCP: isMoveCP, theta: theta))
                        } else if aBezier.p1 == p {
                            let theta = aBezier.cp.tangential(aBezier.p1)
                            var isMoveCP = false
                            for v in vertexs {
                                for b in v.beziers {
                                    if b.theta.isEqualAngle(theta) {
                                        b.isMoveCP = true
                                        isMoveCP = true
                                    }
                                }
                            }
                            for b in beziers {
                                if b.theta.isEqualAngle(theta) {
                                    b.isMoveCP = true
                                    isMoveCP = true
                                }
                            }
                            beziers.append(Beziers(index: i, bezierPoint: .p1, isMoveCP: isMoveCP, theta: theta))
                        }
                    }
                    vertexs.append(Vertexs(cellItem: aCellItem, geometry: aCellItem.cell.geometry, beziers: beziers))
                }
                return (nil, VertexGeometry(vertexs: vertexs.map { ($0.cellItem, $0.geometry, $0.beziers.map { ($0.index, $0.bezierPoint, $0.isMoveCP) }) }, oldPoint: p), nil)
            }
        } else {
            return (nil, nil, nil)
        }
    }
    
    func draw(_ scene: Scene, viewType: Cut.ViewType = .preview, editMaterial: Material? = nil, indicationCellItem: CellItem? = nil, moveZCell: Cell? = nil, isShownPrevious: Bool = false, isShownNext: Bool = false, with di: DrawInfo, in ctx: CGContext) {
        if viewType == .preview && camera.transform.wiggle.isMove {
            let p = camera.transform.wiggle.newPosition(CGPoint(), phase: camera.wigglePhase/scene.frameRate.cf)
            ctx.translateBy(x: p.x, y: p.y)
        }
        if let affine = camera.affineTransform {
            ctx.saveGState()
            ctx.concatenate(affine)
            drawContents(scene, viewType: viewType, editMaterial: editMaterial, indicationCellItem: indicationCellItem, moveZCell: moveZCell, isShownPrevious: isShownPrevious, isShownNext: isShownNext, with: di, in: ctx)
            ctx.restoreGState()
        } else {
            drawContents(scene, viewType: viewType, editMaterial: editMaterial, indicationCellItem: indicationCellItem, moveZCell: moveZCell, isShownPrevious: isShownPrevious, isShownNext: isShownNext, with: di, in: ctx)
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
    private func drawContents(_ scene: Scene, viewType: Cut.ViewType, editMaterial: Material?, indicationCellItem: CellItem? = nil, moveZCell: Cell?, isShownPrevious: Bool, isShownNext: Bool, with di: DrawInfo, in ctx: CGContext) {
        let isEdit = viewType != .preview && viewType != .editMaterial && viewType != .editingMaterial
        drawRootCell(isEdit: isEdit, with: editMaterial,di, in: ctx)
        if isEdit {
            for group in groups {
                if !group.isHidden {
                    group.drawSelectionCells(opacity: group != editGroup ? 0.5 : 1, with: di,  in: ctx)
                }
            }
            if !editGroup.isHidden {
//                if viewType == .editPoint || viewType == .editLine {
//                    drawTransparentCellLines(with: di, in: ctx)
//                }
//                drawEditPointsWith(di, in: ctx)
                editGroup.drawPreviousNext(isShownPrevious: isShownPrevious, isShownNext: isShownNext, time: time, with: di, in: ctx)
                if viewType == .edit, let indicationCellItem = indicationCellItem, editGroup.cellItems.contains(indicationCellItem) {
                    editGroup.drawSkinCellItem(indicationCellItem, with: di, in: ctx)
                }
                if let moveZCell = moveZCell {
                    drawZCell(zCell: moveZCell, in: ctx)
                }
            }
        }
        drawGroups(isEdit: isEdit, with: di, in: ctx)
        if !editGroup.isHidden {
            //                if viewType == .editPoint || viewType == .editLine {
            drawTransparentCellLines(with: di, in: ctx)
            //                }
            drawEditPointsWith(di, in: ctx)
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
                ctx.setFillColor(SceneDefaults.moveZSelectionColor.multiplyAlpha(0.3))
                cell.fillPath(in: ctx)
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
    private func drawPadding(_ scene: Scene, bounds: CGRect,  cameraAffineTransform t: CGAffineTransform?, color: CGColor, in ctx: CGContext) {
        let transformedCameraBounds: CGRect
        if let t = t {
            transformedCameraBounds = cameraBounds.applying(t)
        } else {
            transformedCameraBounds = cameraBounds
        }
        ctx.setFillColor(color)
        ctx.addRect(bounds)
        ctx.addRect(transformedCameraBounds)
        ctx.fillPath(using: .evenOdd)
    }
    func drawTransparentCellLines(lineIndicationCells: [Cell], viewAffineTransform t: CGAffineTransform?, with di: DrawInfo, in ctx: CGContext) {
        if let t = t {
            ctx.saveGState()
            ctx.concatenate(t)
        }
        ctx.setLineWidth(di.invertScale)
        ctx.setStrokeColor(SceneDefaults.cellBorderColor)
        for cell in lineIndicationCells {
            if !cell.isLocked && !cell.isHidden {
                cell.addPath(in: ctx)
            }
        }
        ctx.strokePath()
        if t != nil {
            ctx.restoreGState()
        }
    }
    
    func drawTransparentCellLines(with di: DrawInfo, in ctx: CGContext) {
//        if let t = t {
//            ctx.saveGState()
//            ctx.concatenate(t)
//        }
        ctx.setLineWidth(di.invertScale)
        ctx.setStrokeColor(SceneDefaults.cellBorderColor)
        for cellItem in editGroup.cellItems {
            cellItem.cell.addPath(in: ctx)
        }
        ctx.strokePath()
//        if t != nil {
//            ctx.restoreGState()
//        }
    }
    
    struct EditPoint {
        var line: Line, pointIndex: Int, controlLineIndex: Int
    }
    struct EditLine {
        var line: Line, otherLine: Line?, isFirst: Bool, isOtherFirst: Bool
    }
    private let editPointRadius = 0.5.cf, lineEditPointRadius = 1.5.cf, pointEditPointRadius = 3.0.cf
    
    func drawEditPointsWith(_ di: DrawInfo, in ctx: CGContext) {
        for cellItem in editGroup.cellItems {
            cellItem.cell.drawPointsWith(color1: SceneDefaults.previousSkinColor, color2: SceneDefaults.selectionSkinLineColor, color3: NSColor.green.cgColor, with: di, in: ctx)
        }
        
        for line in editGroup.drawingItem.drawing.lines {
//            ctx.setLineWidth(1)
//            ctx.setStrokeColor(SceneDefaults.contolLineInColor)
//            ctx.addLines(between: line.points)
//            ctx.strokePath()            
            if line.controls.count > 3 {
                let mor = 1.0.cf
                ctx.setFillColor(NSColor.green.cgColor)
                ctx.setStrokeColor(SceneDefaults.selectionSkinLineColor)
                for i in 2 ..< line.controls.count - 1 {
                    let p = line.controls[i].point.mid(line.controls[i - 1].point)
                    ctx.addEllipse(in: CGRect(x: p.x - mor, y: p.y - mor, width: mor*2, height: mor*2))
                    ctx.drawPath(using: .fillStroke)
                }
            }
        }
    }
    
//    func drawEditPointsWith(editPoint: EditPoint?, indicationCells: [Cell], drawingIndicationLines: [Line], viewAffineTransform t: CGAffineTransform?, _ di: DrawInfo, in ctx: CGContext) {
//        for line in editGroup.drawingItem.drawing.lines {
////            let line = editPoint.line
//            drawEditLine(line, with: t, di, in: ctx)
//            if let t = t {
////                ctx.setLineWidth(1.5)
////                ctx.setStrokeColor(SceneDefaults.contolLineOutColor)
////                ctx.move(to: line.points[editPoint.controlLineIndex].applying(t))
////                ctx.addLine(to: line.points[editPoint.controlLineIndex + 1].applying(t))
////                ctx.strokePath()
//                ctx.setLineWidth(1)
//                ctx.setStrokeColor(SceneDefaults.contolLineInColor)
//                ctx.addLines(between: line.points.map { $0.applying(t) })
////                line.allEditPoints { point, index, stop in
////                    ctx.move(to: point.applying(t))
////                    ctx.addLine(to: line.points[index].applying(t))
////                }
//                ctx.strokePath()
//            } else {
////                ctx.setLineWidth(1.5)
////                ctx.setStrokeColor(SceneDefaults.contolLineOutColor)
////                ctx.move(to: line.points[editPoint.controlLineIndex])
////                ctx.addLine(to: line.points[editPoint.controlLineIndex + 1])
////                ctx.strokePath()
//                ctx.setLineWidth(1)
//                ctx.setStrokeColor(SceneDefaults.contolLineInColor)
//                ctx.addLines(between: line.points)
////                line.allEditPoints { point, index, stop in
////                    ctx.move(to: point)
////                    ctx.addLine(to: line.points[index])
////                }
//                ctx.strokePath()
//            }
//            func drawControlPoints(from lines: [Line], in ctx: CGContext) {
//                for line in lines {
//                    if line === editPoint.line {
//                        for (i, p) in line.points.enumerated() {
//                            let cp = t != nil ? p.applying(t!) : p
//                            drawControlPoint(cp, radius: i == editPoint.pointIndex ? lineEditPointRadius : editPointRadius,
//                                             inColor: SceneDefaults.editControlPointInColor, outColor: SceneDefaults.editControlPointOutColor, in: ctx)
//                        }
//                    }
//                    line.allEditPoints { point, index, stop in
//                        let cp = t != nil ? point.applying(t!) : point
//                        let r = line === editPoint.line ? (index == editPoint.pointIndex ? pointEditPointRadius : lineEditPointRadius) : editPointRadius
//                        drawControlPoint(cp, radius: r, in: ctx)
//                    }
//                }
//            }
            
//            for cell in indicationCells {
//                if !cell.isLocked {
//                    drawControlPoints(from: cell.lines, in: ctx)
//                }
//            }
//            drawControlPoints(from: drawingIndicationLines, in: ctx)
//        } else {
//            func drawControlPoints(from lines: [Line], in ctx: CGContext) {
//                for line in lines {
//                    line.allEditPoints { point, index, stop in
//                        drawControlPoint(t != nil ? point.applying(t!) : point, radius: editPointRadius, in: ctx)
//                    }
//                }
//            }
////            for cell in indicationCells {
////                if !cell.isLocked {
////                    drawControlPoints(from: cell.lines, in: ctx)
////                }
////            }
//            drawControlPoints(from: drawingIndicationLines, in: ctx)
//        }
//    }
    func drawEditLine(_ editLine: EditLine?, withIndicationCells indicationCells: [Cell], drawingIndicationLines: [Line], viewAffineTransform t: CGAffineTransform?, _ di: DrawInfo, in ctx: CGContext) {
        if let editLine = editLine {
            drawEditLine(editLine.line, with: t, di, in: ctx)
            if let line = editLine.otherLine {
                drawEditLine(line, with: t, di, in: ctx)
            }
            func drawVertices(from lines: [Line], in ctx: CGContext) {
                if var oldLine = lines.last {
                    for line in lines {
                        let lp: CGPoint, fp: CGPoint
                        if let t = t {
                            lp = oldLine.lastPoint.applying(t)
                            fp = line.firstPoint.applying(t)
                        } else {
                            lp = oldLine.lastPoint
                            fp = line.firstPoint
                        }
                        if lp != fp {
                            drawControlPoint(lp, radius: editLine.line === oldLine && !editLine.isFirst ? pointEditPointRadius : lineEditPointRadius, in: ctx)
                        }
                        drawControlPoint(fp, radius: editLine.line === line && editLine.isFirst ? pointEditPointRadius : lineEditPointRadius, in: ctx)
                        oldLine = line
                    }
                }
            }
//            for cell in indicationCells {
//                if !cell.isLocked {
//                    drawVertices(from: cell.lines, in: ctx)
//                }
//            }
            drawVertices(from: drawingIndicationLines, in: ctx)
        } else {
            func drawVertices(from lines: [Line], in ctx: CGContext) {
                if var oldLine = lines.last {
                    for line in lines {
                        let lp: CGPoint, fp: CGPoint
                        if let t = t {
                            lp = oldLine.lastPoint.applying(t)
                            fp = line.firstPoint.applying(t)
                        } else {
                            lp = oldLine.lastPoint
                            fp = line.firstPoint
                        }
                        if lp != fp {
                            drawControlPoint(lp, radius: lineEditPointRadius, in: ctx)
                        }
                        drawControlPoint(fp, radius: lineEditPointRadius, in: ctx)
                        oldLine = line
                    }
                }
            }
//            for cell in indicationCells {
//                if !cell.isLocked {
//                    drawVertices(from: cell.lines, in: ctx)
//                }
//            }
            drawVertices(from: drawingIndicationLines, in: ctx)
        }
    }
    private func drawEditLine(_ line: Line, with viewAffineTransform: CGAffineTransform?, _ di: DrawInfo, in ctx: CGContext) {
        let lw = di.invertScale
        if let t = viewAffineTransform {
            ctx.saveGState()
            ctx.concatenate(t)
        }
        ctx.setFillColor(SceneDefaults.editLineColor)
        line.draw(size: lw, in: ctx)
        if viewAffineTransform != nil {
            ctx.restoreGState()
        }
    }
    private func drawControlPoint(_ p: CGPoint, radius r: CGFloat, lineWidth: CGFloat = 1,
                                  inColor: CGColor = SceneDefaults.controlPointInColor, outColor: CGColor = SceneDefaults.controlPointOutColor, in ctx: CGContext) {
        let rect = CGRect(x: p.x - r, y: p.y - r, width: r*2, height: r*2)
        ctx.setFillColor(outColor)
        ctx.fillEllipse(in: rect.insetBy(dx: -lineWidth, dy: -lineWidth))
        ctx.setFillColor(inColor)
        ctx.fillEllipse(in: rect)
    }
    
    enum TransformType {
        case scaleXY, scaleX, scaleY, rotate, skewX, skewY
    }
    private let transformXYTextLine = TextLine(string: "XY", isHorizontalCenter: true, isVerticalCenter: true, isCenterWithImageBounds: true)
    private let transformXTextLine = TextLine(string: "X", isHorizontalCenter: true, isVerticalCenter: true, isCenterWithImageBounds: true)
    private let transformYTextLine = TextLine(string: "Y", isHorizontalCenter: true, isVerticalCenter: true, isCenterWithImageBounds: true)
    private let transformRotateTextLine = TextLine(string: "θ", isHorizontalCenter: true, isVerticalCenter: true, isCenterWithImageBounds: true)
    private let transformSkewXTextLine = TextLine(string: "Skew ".localized + "X", isHorizontalCenter: true, isVerticalCenter: true, isCenterWithImageBounds: true)
    private let transformSkewYTextLine = TextLine(string: "Skew ".localized + "Y", isHorizontalCenter: true, isVerticalCenter: true, isCenterWithImageBounds: true)
    private let transformOpacity = 0.5.cf
    func transformTypeWith(y: CGFloat, height: CGFloat) -> TransformType {
        if y > -height*0.5 {
            return .scaleXY
        } else if y > -height*1.5 {
            return .scaleX
        } else if y > -height*2.5 {
            return .scaleY
        } else if y > -height*3.5 {
            return .rotate
        } else if y > -height*4.5 {
            return .skewX
        } else {
            return .skewY
        }
    }
    func drawTransform(type: TransformType, startPosition: CGPoint, editPosition: CGPoint, firstWidth: CGFloat, valueWidth: CGFloat, height: CGFloat, in ctx: CGContext) {
        drawControlPoint(startPosition, radius: 2, in: ctx)
        
        ctx.saveGState()
        ctx.setAlpha(transformOpacity)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        
        let x = startPosition.x - firstWidth/2, firstFrame: CGRect
        switch type {
        case .scaleXY:
            firstFrame = CGRect(x: x, y: startPosition.y - height*0.5, width: firstWidth, height: height)
        case .scaleX:
            firstFrame = CGRect(x: x, y: startPosition.y - height*1.5, width: firstWidth, height: height)
        case .scaleY:
            firstFrame = CGRect(x: x, y: startPosition.y - height*2.5, width: firstWidth, height: height)
        case .rotate:
            firstFrame = CGRect(x: x, y: startPosition.y - height*3.5, width: firstWidth, height: height)
        case .skewX:
            firstFrame = CGRect(x: x, y: startPosition.y - height*4.5, width: firstWidth, height: height)
        case .skewY:
            firstFrame = CGRect(x: x, y: startPosition.y - height*5.5, width: firstWidth, height: height)
        }
        let opacity = 0.25.cf
        ctx.setFillColor(Defaults.subBackgroundColor.cgColor)
        ctx.fill(CGRect(x: x, y: startPosition.y - height*5.5, width: firstWidth, height: height*6.5))
        let scaleXYFrame = CGRect(x: x, y: startPosition.y - height*0.5 + height*0.5, width: firstWidth, height: height)
        drawTransformLabelWith(textLine: transformXYTextLine, frame: scaleXYFrame, opacity: type == .scaleXY ? 1.0 : opacity, in: ctx)
        let scaleXFrame = CGRect(x: x, y: startPosition.y - height*1.5 + height*0.5, width: firstWidth, height: height)
        drawTransformLabelWith(textLine: transformXTextLine, frame: scaleXFrame, opacity: type == .scaleX ? 1.0 : opacity, in: ctx)
        let scaleYFrame = CGRect(x: x, y: startPosition.y - height*2.5 + height*0.5, width: firstWidth, height: height)
        drawTransformLabelWith(textLine: transformYTextLine, frame: scaleYFrame, opacity: type == .scaleY ? 1.0 : opacity,in: ctx)
        let rotateFrame = CGRect(x: x, y: startPosition.y - height*3.5 + height*0.5, width: firstWidth, height: height)
        drawTransformLabelWith(textLine: transformRotateTextLine, frame: rotateFrame, opacity: type == .rotate ? 1.0 : opacity, in: ctx)
        let skewXFrame = CGRect(x: x, y: startPosition.y - height*4.5 + height*0.5, width: firstWidth, height: height)
        drawTransformLabelWith(textLine: transformSkewXTextLine, frame: skewXFrame, opacity: type == .skewX ? 1.0 : opacity, in: ctx)
        let skewYFrame = CGRect(x: x, y: startPosition.y - height*5.5 + height*0.5, width: firstWidth, height: height)
        drawTransformLabelWith(textLine: transformSkewYTextLine, frame: skewYFrame, opacity: type == .skewY ? 1.0 : opacity, in: ctx)
        
        drawTranformSlider(firstFrame: firstFrame, editPosition: editPosition, valueWidth: valueWidth, in: ctx)
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }
    private func drawTransformLabelWith(textLine: TextLine, frame: CGRect, opacity: CGFloat, in ctx: CGContext) {
        if opacity != 1.0 {
            ctx.saveGState()
            ctx.setAlpha(opacity)
            textLine.draw(in: frame, in: ctx)
            ctx.restoreGState()
        } else {
            textLine.draw(in: frame, in: ctx)
        }
    }
    private func drawTranformSlider(firstFrame: CGRect, editPosition: CGPoint, valueWidth: CGFloat, in ctx: CGContext) {
        let b = ctx.boundingBoxOfClipPath
        ctx.setFillColor(Defaults.subBackgroundColor.cgColor)
        ctx.fill(CGRect(x: firstFrame.maxX, y: firstFrame.minY, width: max(b.width - firstFrame.maxX, 0), height: firstFrame.height))
        ctx.fill(CGRect(x: b.minX, y: firstFrame.minY, width: max(firstFrame.minX - b.minX, 0), height: firstFrame.height))
        ctx.setFillColor(Defaults.contentEditColor.cgColor)
        ctx.fill(CGRect(x: b.minX, y: firstFrame.midY - 1, width: b.width, height: 2))
        
        var x = firstFrame.midX
        ctx.fill(CGRect(x: x - 1, y: firstFrame.minY + 6, width: 1, height: firstFrame.height - 12))
        while x < b.maxX {
            x += valueWidth
            ctx.fill(CGRect(x: x - 1, y: firstFrame.minY + 4, width: 1, height: firstFrame.height - 8))
        }
        x = firstFrame.midX
        while x > b.minX {
            x -= valueWidth
            ctx.fill(CGRect(x: x - 1, y: firstFrame.minY + 4, width: 1, height: firstFrame.height - 8))
        }
        drawControlPoint(CGPoint(x: editPosition.x, y : firstFrame.midY), radius: 4, in: ctx)
    }
}

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
    func snapPoint(_ p: CGPoint, snapDistance: CGFloat, otherLines: [(line: Line, isFirst: Bool)]) -> CGPoint {
        let sd = snapDistance*snapDistance
        var minD = CGFloat.infinity, minP = p
        func snap(with lines: [Line]) {
            for line in lines {
                var isFirst = true, isLast = true
                for ol in otherLines {
                    if ol.line === line {
                        if ol.isFirst {
                            isFirst = false
                        } else {
                            isLast = false
                        }
                    }
                }
                if isFirst {
                    let fp = line.firstPoint
                    let d = p.squaredDistance(other: fp)
                    if d < sd && d < minD {
                        minP = fp
                        minD = d
                    }
                }
                if isLast {
                    let lp = line.lastPoint
                    let d = p.squaredDistance(other: lp)
                    if d < sd && d < minD {
                        minP = lp
                        minD = d
                    }
                }
            }
        }
        for cellItem in cellItems {
            snap(with: cellItem.cell.geometry.lines)
        }
        snap(with: drawingItem.drawing.lines)
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
            ctx.setAlpha(0.6*opacity)
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
                geometry.draw(withLineWidth: 1.5*di.invertCameraScale, in: ctx)
            }
            ctx.endTransparencyLayer()
            ctx.setAlpha(1)
        }
    }
    func drawSkinCellItem(_ cellItem: CellItem, with di: DrawInfo, in ctx: CGContext) {
        if editKeyframeIndex == 0 && isInterporation {
            if !cellItem.keyGeometries[0].isEmpty {
                cellItem.cell.drawSkin(lineColor: SceneDefaults.previousSkinColor, subColor: SceneDefaults.subPreviousSkinColor, opacity: 0.2, geometry: cellItem.keyGeometries[0], with: di, in: ctx)
            }
        } else {
            for i in (0 ..< editKeyframeIndex).reversed() {
                if !cellItem.keyGeometries[i].isEmpty {
                    cellItem.cell.drawSkin(lineColor: SceneDefaults.previousSkinColor, subColor: SceneDefaults.subPreviousSkinColor, opacity: i != editKeyframeIndex - 1 ? 0.1 : 0.2, geometry: cellItem.keyGeometries[i], with: di, in: ctx)
                    break
                }
            }
        }
//        if editKeyframeIndex + 1 < cellItem.keyGeometries.count {
            for i in editKeyframeIndex + 1 ..< cellItem.keyGeometries.count {
                if !cellItem.keyGeometries[i].isEmpty {
                    cellItem.cell.drawSkin(lineColor: SceneDefaults.nextSkinColor, subColor: SceneDefaults.subNextSkinColor, opacity: i != editKeyframeIndex + 1 ? 0.1 : 0.2, geometry: cellItem.keyGeometries[i], with: di, in: ctx)
                    break
                }
            }
//        }
        cellItem.cell.drawSkin(lineColor: isInterporation ? SceneDefaults.interpolationColor : SceneDefaults.selectionColor, subColor: SceneDefaults.subSelectionSkinColor, opacity: 0.8, geometry: cellItem.cell.geometry, with: di, in: ctx)
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
        return drawing.imageBounds(with: SceneDefaults.strokeLineWidth)
    }
    func draw(with di: DrawInfo, in ctx: CGContext) {
        drawing.draw(lineWidth: SceneDefaults.strokeLineWidth*di.invertScale, lineColor: color, in: ctx)
    }
    func drawEdit(with di: DrawInfo, in ctx: CGContext) {
        let lineWidth = SceneDefaults.strokeLineWidth*di.invertScale
        drawing.drawRough(lineWidth: lineWidth, lineColor: SceneDefaults.roughColor, in: ctx)
        drawing.draw(lineWidth: lineWidth, lineColor: color, in: ctx)
        drawing.drawSelectionLines(lineWidth: lineWidth + 1.5, lineColor: SceneDefaults.selectionColor, in: ctx)
    }
    func drawPreviousNext(isShownPrevious: Bool, isShownNext: Bool, index: Int, with di: DrawInfo, in ctx: CGContext) {
        let lineWidth = SceneDefaults.strokeLineWidth*di.invertScale
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

final class Text: NSObject, NSCoding {
    let string: String
    
    init(string: String = "") {
        self.string = string
        super.init()
    }
    
    static let dataType = "C0.Text.1", stringKey = "0"
    init?(coder: NSCoder) {
        string = coder.decodeObject(forKey: Text.stringKey) as? String ?? ""
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(string, forKey: Text.stringKey)
    }
    
    var isEmpty: Bool {
        return string.isEmpty
    }
    let borderColor = SceneDefaults.speechBorderColor, fillColor = SceneDefaults.speechFillColor
    func draw(bounds: CGRect, in ctx: CGContext) {
        let attString = NSAttributedString(string: string, attributes: [
            String(kCTFontAttributeName): SceneDefaults.speechFont,
            String(kCTForegroundColorFromContextAttributeName): true
            ])
        let framesetter = CTFramesetterCreateWithAttributedString(attString)
        let range = CFRange(location: 0, length: attString.length), ratio = bounds.size.width/640
        let lineBounds = CGRect(origin: CGPoint(), size: CTFramesetterSuggestFrameSizeWithConstraints(framesetter, range, nil, CGSize(width: CGFloat.infinity, height: CGFloat.infinity), nil))
        let ctFrame = CTFramesetterCreateFrame(framesetter, range, CGPath(rect: lineBounds, transform: nil), nil)
        ctx.saveGState()
        ctx.translateBy(x: round(bounds.midX - lineBounds.midX),  y: round(bounds.minY + 20*ratio))
        ctx.setTextDrawingMode(.stroke)
        ctx.setLineWidth(ceil(3*ratio))
        ctx.setStrokeColor(borderColor)
        CTFrameDraw(ctFrame, ctx)
        ctx.setTextDrawingMode(.fill)
        ctx.setFillColor(fillColor)
        CTFrameDraw(ctFrame, ctx)
        ctx.restoreGState()
    }
}
