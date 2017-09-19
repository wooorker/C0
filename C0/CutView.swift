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

import Cocoa

final class CutView: View {
    enum Quasimode {
        case none, movePoint, warpLine, moveZ, move, warp, transform
    }
    
    weak var sceneView: SceneView!
    
    var strokeLine: Line?, lineColor = SceneDefaults.strokeLineColor, lineWidth = SceneDefaults.strokeLineWidth
    var scene = Scene() {
        didSet {
            updateViewAffineTransform()
        }
    }
    var cutEntity = CutEntity() {
        didSet {
            updateViewAffineTransform()
            setNeedsDisplay(in: oldValue.cut.imageBounds)
            setNeedsDisplay(in: cutEntity.cut.imageBounds)
        }
    }
    var cut: Cut {
        return cutEntity.cut
    }
    
    var isUpdate: Bool {
        get {
            return cutEntity.isUpdate
        }
        set {
            cutEntity.isUpdate = newValue
            setNeedsDisplay()
            sceneView.timeline.setNeedsDisplay()
        }
    }
    
    private let drawLayer = DrawLayer()
    
    override init(layer: CALayer = CALayer.interfaceLayer()) {
        super.init(layer: layer)
        description = "Canvas: When indicated cell is selected display, apply command to all selected cells".localized
        drawLayer.bounds = cameraFrame.insetBy(dx: -outsidePadding, dy: -outsidePadding)
        drawLayer.frame.origin = drawLayer.bounds.origin
        drawLayer.drawBlock = { [unowned self] ctx in
            self.draw(in: ctx)
        }
        layer.addSublayer(drawLayer)
        layer.backgroundColor = SceneDefaults.playBorderColor
        bounds = drawLayer.bounds
    }
    
    override var contentsScale: CGFloat {
        didSet {
            drawLayer.contentsScale = contentsScale
        }
    }
    
    static let strokeCurosr = NSCursor.circleCursor(size: 2)
    var cursor = CutView.strokeCurosr {
        didSet {
            screen?.updateCursor(with: currentPoint)
        }
    }
    override func cursor(with p: CGPoint) -> NSCursor {
        return cursor
    }
    
    override var cutQuasimode: CutView.Quasimode {
        didSet {
            updateViewType()
        }
    }
    var materialViewType = MaterialView.ViewType.none {
        didSet {
            updateViewType()
        }
    }
    var isPlaying = false {
        didSet {
            isHiddenOutside = isPlaying
            updateViewType()
        }
    }
    private func updateViewType() {
        if isPlaying {
            viewType = .preview
            cursor = NSCursor.arrow()
        } else if materialViewType == .selection {
            viewType = .editMaterial
            cursor = CutView.strokeCurosr
        } else if materialViewType == .preview {
            viewType = .editingMaterial
            cursor = CutView.strokeCurosr
        } else {
            switch cutQuasimode {
            case .none:
                viewType = .edit
                cursor = CutView.strokeCurosr
                moveZCell = nil
            case .movePoint:
                viewType = .editPoint
            case .warpLine:
                viewType = .editLine
            case .moveZ:
                viewType = .editMoveZ
                cursor = Defaults.upDownCursor
                moveZCell = cut.rootCell.atPoint(convertToCut(currentPoint))
            case .move:
                cursor = NSCursor.arrow()
            case .warp:
                cursor = NSCursor.arrow()
            case .transform:
                viewType = .editTransform
                cursor = NSCursor.arrow()
            }
            updateEditView(with: convertToCut(currentPoint))
        }
    }
    var viewType = Cut.ViewType.edit {
        didSet {
            updateViewAffineTransform()
            setNeedsDisplay()
        }
    }
    var outsidePadding = 100.0.cf
    private var outsideOldBounds = CGRect(), outsideOldFrame = CGRect(), timeLabelWidth = 40.0.cf
    private var outsideStopLabel = StringView(string: "Playing(Stop at the Click)".localized, font: Defaults.smallFont, color: Defaults.smallFontColor.cgColor, backgroundColor: SceneDefaults.playBorderColor, height: 24)
    var timeLabel = StringView(string: "00:00", color: Defaults.smallFontColor.cgColor, backgroundColor: SceneDefaults.playBorderColor, height: 30)
    var cutLabel = StringView(string: "C1", color: Defaults.smallFontColor.cgColor, backgroundColor: SceneDefaults.playBorderColor, height: 30)
    var fpsLabel = StringView(string: "0fps", color: Defaults.smallFontColor.cgColor, backgroundColor: SceneDefaults.playBorderColor, height: 30)
    private var isHiddenOutside = false {
        didSet {
            if isHiddenOutside != oldValue {
                CATransaction.disableAnimation {
                    if isHiddenOutside {
                        outsideOldBounds = drawLayer.bounds
                        outsideOldFrame = drawLayer.frame
                        drawLayer.bounds = cameraFrame
                        drawLayer.frame = CGRect(origin: CGPoint(x: drawLayer.frame.origin.x - outsideOldBounds.origin.x, y: drawLayer.frame.origin.y - outsideOldBounds.origin.y), size: drawLayer.bounds.size)
                        let w = ceil(outsideStopLabel.textLine.stringBounds.width + 4)
                        let alltw = timeLabelWidth*3
                        outsideStopLabel.frame = CGRect(x: bounds.midX - floor(w/2), y: bounds.maxY + bounds.origin.y/2 - 12, width: w, height: 24)
                        timeLabel.frame = CGRect(x: bounds.midX - floor(alltw/2), y: bounds.origin.y/2 - 15, width: timeLabelWidth, height: 30)
                        cutLabel.frame = CGRect(x: bounds.midX - floor(alltw/2) + timeLabelWidth, y: bounds.origin.y/2 - 15, width: timeLabelWidth, height: 30)
                        fpsLabel.frame = CGRect(x: bounds.midX - floor(alltw/2) + timeLabelWidth*2, y: bounds.origin.y/2 - 15, width: timeLabelWidth, height: 30)
                        children = [outsideStopLabel, timeLabel, cutLabel, fpsLabel]
                    } else {
                        drawLayer.bounds = outsideOldBounds
                        drawLayer.frame = outsideOldFrame
                        children = []
                    }
                }
            }
        }
    }
    var cameraFrame: CGRect {
        get {
            return scene.cameraFrame
        }
        set {
            scene.cameraFrame = frame
            updateWithScene()
            drawLayer.bounds.origin = CGPoint(x: -ceil((frame.width - frame.width)/2), y: -ceil((frame.height - frame.height)/2))
            drawLayer.frame.origin = drawLayer.bounds.origin
            bounds = drawLayer.bounds
        }
    }
    var time: Int {
        get {
            return scene.time
        }
        set {
            sceneView.timeline.time = newValue
        }
    }
    var isShownPrevious: Bool {
        get {
            return scene.isShownPrevious
        }
        set {
            scene.isShownPrevious = newValue
            updateWithScene()
        }
    }
    var isShownNext: Bool {
        get {
            return scene.isShownNext
        }
        set {
            scene.isShownNext = newValue
            updateWithScene()
        }
    }
    var viewTransform: ViewTransform {
        get {
            return scene.viewTransform
        }
        set {
            scene.viewTransform = newValue
            updateViewAffineTransform()
            updateWithScene()
        }
    }
    private func updateWithScene() {
        setNeedsDisplay()
        sceneView.sceneEntity.isUpdatePreference = true
    }
    func updateViewAffineTransform() {
        let cameraScale = cut.camera.transform.zoomScale.width
        var affine = CGAffineTransform.identity
        if viewType != .preview, let t = scene.affineTransform {
            affine = affine.concatenating(t)
            drawInfo = DrawInfo(scale: cameraScale*viewTransform.scale, cameraScale: cameraScale, rotation: cut.camera.transform.rotation + viewTransform.rotation)
        } else {
            drawInfo = DrawInfo(scale: cut.camera.transform.zoomScale.width, cameraScale: cameraScale, rotation:cut.camera.transform.rotation)
        }
        if let cameraAffine = cut.camera.affineTransform {
            affine = cameraAffine.concatenating(affine)
        }
        viewAffineTransform = affine
    }
    private var drawInfo = DrawInfo()
    private(set) var viewAffineTransform: CGAffineTransform? {
        didSet {
            setNeedsDisplay()
        }
    }
    func convertFromCut(_ point: CGPoint) -> CGPoint {
        return layer.convert(convertFromInternal(point), from: drawLayer)
    }
    func convertToCut(_ viewPoint: CGPoint) -> CGPoint {
        return convertToInternal(drawLayer.convert(viewPoint, from: layer))
    }
    func convertToInternal(_ r: CGRect) -> CGRect {
        if let affine = viewAffineTransform {
            return r.applying(affine.inverted())
        } else {
            return r
        }
    }
    func convertFromInternal(_ r: CGRect) -> CGRect {
        if let affine = viewAffineTransform {
            return r.applying(affine)
        } else {
            return r
        }
    }
    func convertToInternal(_ point: CGPoint) -> CGPoint {
        if let affine = viewAffineTransform {
            return point.applying(affine.inverted())
        } else {
            return point
        }
    }
    func convertFromInternal(_ p: CGPoint) -> CGPoint {
        if let affine = viewAffineTransform {
            return p.applying(affine)
        } else {
            return p
        }
    }
    
    func setNeedsDisplay() {
        drawLayer.setNeedsDisplay()
    }
    func setNeedsDisplay(in rect: CGRect) {
        if let affine = viewAffineTransform {
            drawLayer.setNeedsDisplayIn(rect.applying(affine))
        } else {
            drawLayer.setNeedsDisplayIn(rect)
        }
    }
    func draw(in ctx: CGContext) {
        if viewType == .preview {
            if viewTransform.isFlippedHorizontal {
                ctx.flipHorizontal(by: cameraFrame.width)
            }
            cut.draw(sceneView.scene, with: drawInfo, in: ctx)
            drawStroke(in: ctx)
        } else {
            if let affine = scene.affineTransform {
                ctx.saveGState()
                ctx.concatenate(affine)
                cut.draw(sceneView.scene, viewType: viewType, editMaterial: viewType == .editMaterial ? nil : sceneView.materialView.material,
                         indicationCellItem: indicationCellItem, moveZCell: moveZCell, isShownPrevious: isShownPrevious, isShownNext: isShownNext, with: drawInfo, in: ctx)
                drawStroke(in: ctx)
                ctx.restoreGState()
            } else {
                cut.draw(sceneView.scene, viewType: viewType, editMaterial: viewType == .editMaterial ? nil : sceneView.materialView.material,
                         indicationCellItem: indicationCellItem, moveZCell: moveZCell, isShownPrevious: isShownPrevious, isShownNext: isShownNext, with: drawInfo, in: ctx)
                drawStroke(in: ctx)
            }
            drawEditInterfaces(in: ctx)
            drawCautionBorder(in: ctx)
        }
    }
    private func drawEditInterfaces(in ctx: CGContext) {
        switch viewType {
        case .editPoint: break
//            cut.drawTransparentCellLines(lineIndicationCells: editIndicationCells, viewAffineTransform: viewAffineTransform, with: drawInfo, in: ctx)
//            cut.drawEditPointsWith(drawInfo, in: ctx)
//            cut.drawEditPointsWith(editPoint: editPoint, indicationCells: editIndicationCells, drawingIndicationLines: editIndicationLines, viewAffineTransform: viewAffineTransform, drawInfo, in: ctx)
        case .editLine: break
//            cut.drawTransparentCellLines(lineIndicationCells: editIndicationCells, viewAffineTransform: viewAffineTransform, with: drawInfo, in: ctx)
//            cut.drawEditPointsWith(drawInfo, in: ctx)
//            cut.drawEditLine(editLine, withIndicationCells: editIndicationCells, drawingIndicationLines: editIndicationLines, viewAffineTransform: viewAffineTransform, drawInfo, in: ctx)
        case .editTransform:
            cut.drawTransform(type: transformType, startPosition: moveEditing ? moveTransformOldPoint : currentPoint, editPosition: currentPoint, firstWidth: transformFirstWidth, valueWidth: moveTranformValueWidth, height: moveTransformValueHeight, in: ctx)
        case .editMaterial:
            break
        default:
            break
        }
    }
    private func drawCautionBorder(in ctx: CGContext) {
        let borderWidth = 2.0.cf, bounds = self.bounds
        if viewTransform.isFlippedHorizontal {
            drawBorderWith(bounds: bounds, width: borderWidth*3, color: NSColor.orange.cgColor, in: ctx)
        }
        if viewTransform.rotation > .pi/2 || viewTransform.rotation < -.pi/2 {
            drawBorderWith(bounds: bounds, width: borderWidth*2, color: NSColor.red.cgColor, in: ctx)
        }
    }
    private func drawBorderWith(bounds: CGRect, width: CGFloat, color: CGColor, in ctx: CGContext) {
        ctx.setFillColor(color)
        ctx.fill([
            CGRect(x: bounds.minX, y: bounds.minY, width: width, height: bounds.height),
            CGRect(x: bounds.minX + width, y: bounds.minY, width: bounds.width - width*2, height: width),
            CGRect(x: bounds.minX + width, y: bounds.maxY - width, width: bounds.width - width*2, height: width),
            CGRect(x: bounds.maxX - width, y: bounds.minY, width: width, height: bounds.height)
            ])
    }
    private func drawStroke(in ctx: CGContext) {
        if let strokeLine = strokeLine {
            cut.drawStrokeLine(strokeLine, lineColor: lineColor, lineWidth: lineWidth/drawInfo.scale, in: ctx)
        }
    }
    
    private func registerUndo(_ handler: @escaping (CutView, Int) -> Void) {
        undoManager?.registerUndo(withTarget: self) { [oldTime = time] in handler($0, oldTime) }
    }
    
    override func copy() {
        let indicationCellsTuple = cut.indicationCellsTuple(with : convertToCut(currentPoint))
        switch indicationCellsTuple.type {
        case .none:
            let copySelectionLines = cut.editGroup.drawingItem.drawing.selectionLines
            if !copySelectionLines.isEmpty {
                screen?.copy(Drawing(lines: copySelectionLines).data, forType: Drawing.dataType, from: self)
            } else {
                screen?.tempNotAction()
            }
        case .indication, .selection:
//            screen?.copy(cut.rootCell.intersection(indicationCellsTuple.cells).deepCopy.data, forType: Cell.dataType, from: self)
            let cellPasteboardItem = NSPasteboardItem(), materialPasteboardItem = NSPasteboardItem()
            cellPasteboardItem.setData(cut.rootCell.intersection(indicationCellsTuple.cells).deepCopy.data, forType: Cell.dataType)
            materialPasteboardItem.setData(indicationCellsTuple.cells[0].material.data, forType: Material.dataType)
            let pasteboard = NSPasteboard.general()
            pasteboard.clearContents()
            pasteboard.writeObjects([cellPasteboardItem, materialPasteboardItem])
            highlight()
        }
    }
    override func paste() {
        if isPlaying {
            screen?.tempNotAction()
            return
        }
        let pasteboard = NSPasteboard.general()
        if let data = pasteboard.data(forType: HSLColor.dataType) {
            let color = HSLColor(data: data)
            paste(color)
        } else if let data = pasteboard.data(forType: Drawing.dataType), let copyDrawing = Drawing.with(data) {
            let drawing = cut.editGroup.drawingItem.drawing, oldCount = drawing.lines.count
            let lineIndexes = Set((0 ..< copyDrawing.lines.count).map { $0 + oldCount })
            setLines(drawing.lines + copyDrawing.lines, oldLines: drawing.lines, drawing: drawing, time: time)
            setSelectionLineIndexes(Array(Set(drawing.selectionLineIndexes).union(lineIndexes)), in: drawing, time: time)
        } else if let data = pasteboard.data(forType: Cell.dataType), let copyRootCell = Cell.with(data) {
            var isChanged = false
            for copyCell in copyRootCell.allCells {
                for group in cut.groups {
                    for ci in group.cellItems {
                        if ci.cell.id == copyCell.id {
                            if sceneView.timeline.isInterpolatedKeyframe(with: group) {
                                sceneView.timeline.splitKeyframe(with: group)
                            }
                            setGeometry(copyCell.geometry, oldGeometry: ci.cell.geometry, at: group.editKeyframeIndex, in: ci, time: time)
                            isChanged = true
                        }
                    }
                }
            }
            if !isChanged {
                screen?.tempNotAction()
            }
        } else {
            screen?.tempNotAction()
        }
    }
    func paste(_ color: HSLColor) {
        let indicationCellsTuple = cut.indicationCellsTuple(with : convertToCut(currentPoint))
        if indicationCellsTuple.type != .none {
            let selectionMaterial = indicationCellsTuple.cells.first!.material
            if color != selectionMaterial.color {
                sceneView.materialView.paste(color, withSelection: selectionMaterial, useSelection: indicationCellsTuple.type == .selection)
            } else {
                screen?.tempNotAction()
            }
        } else {
            screen?.tempNotAction()
        }
    }
    func paste(_ material: Material) {
        let indicationCellsTuple = cut.indicationCellsTuple(with : convertToCut(currentPoint))
        if indicationCellsTuple.type != .none {
            let selectionMaterial = indicationCellsTuple.cells.first!.material
            if material != selectionMaterial {
                sceneView.materialView.paste(material, withSelection: selectionMaterial, useSelection: indicationCellsTuple.type == .selection)
            } else {
                screen?.tempNotAction()
            }
        } else {
            screen?.tempNotAction()
        }
    }
    override func delete() {
        if isPlaying {
            screen?.tempNotAction()
            return
        }
        if deleteSelectionDrawingLines() {
            return
        }
        if deleteCells() {
            return
        }
        if deleteDrawingLines() {
            return
        }
        screen?.tempNotAction()
    }
    func deleteSelectionDrawingLines() -> Bool {
        let drawingItem = cut.editGroup.drawingItem
        if !drawingItem.drawing.selectionLineIndexes.isEmpty {
            let unseletionLines = drawingItem.drawing.unselectionLines
            setSelectionLineIndexes([], in: drawingItem.drawing, time: time)
            setLines(unseletionLines, oldLines: drawingItem.drawing.lines, drawing: drawingItem.drawing, time: time)
            return true
        } else {
            return false
        }
    }
    func deleteDrawingLines() -> Bool {
        let drawingItem = cut.editGroup.drawingItem
        if !drawingItem.drawing.lines.isEmpty {
            setLines([], oldLines: drawingItem.drawing.lines, drawing: drawingItem.drawing, time: time)
            return true
        } else {
            return false
        }
    }
    func deleteCells() -> Bool {
        let point = convertToCut(currentPoint)
        let indicationCellsTuple = cut.indicationCellsTuple(with: point)
        switch indicationCellsTuple.type {
        case .selection:
            var isChanged = false
            for group in cut.groups {
                let removeSelectionCellItems = group.editSelectionCellItemsWithNotEmptyGeometry.filter {
                    if !$0.cell.geometry.isEmpty {
                        setGeometry(Geometry(), oldGeometry: $0.cell.geometry, at: group.editKeyframeIndex, in: $0, time: time)
                        isChanged = true
                        if $0.isEmptyKeyGeometries {
                            return true
                        }
                    }
                    return false
                }
                if !removeSelectionCellItems.isEmpty {
                    removeCellItems(removeSelectionCellItems)
                }
            }
            if isChanged {
                return true
            }
        case .indication:
            if let cellItem = cut.cellItem(at: point, with: cut.editGroup) {
                if !cellItem.cell.geometry.isEmpty {
                    setGeometry(Geometry(), oldGeometry: cellItem.cell.geometry, at: cut.editGroup.editKeyframeIndex, in: cellItem, time: time)
                    if cellItem.isEmptyKeyGeometries {
                        removeCellItems([cellItem])
                    }
                    return true
                }
            }
        case .none:
            break
        }
        return false
    }
    
    private func removeCellItems(_ cellItems: [CellItem]) {
        var cellItems = cellItems
        while !cellItems.isEmpty {
            let cellRemoveManager = cut.cellRemoveManager(with: cellItems.first!)
            for groupAndCellItems in cellRemoveManager.groupAndCellItems {
                let group = groupAndCellItems.group, cellItems = groupAndCellItems.cellItems
                let removeSelectionCellItems = Array(Set(group.selectionCellItems).subtracting(cellItems))
                if removeSelectionCellItems.count != cut.editGroup.selectionCellItems.count {
                    setSelectionCellItems(removeSelectionCellItems, in: group, time: time)
                }
            }
            removeCell(with: cellRemoveManager, time: time)
            cellItems = cellItems.filter { !cellRemoveManager.contains($0) }
        }
    }
    private func insertCell(with cellRemoveManager: Cut.CellRemoveManager, time: Int) {
        registerUndo { $0.removeCell(with: cellRemoveManager, time: $1) }
        self.time = time
        cut.insertCell(with: cellRemoveManager)
        isUpdate = true
    }
    private func removeCell(with cellRemoveManager: Cut.CellRemoveManager, time: Int) {
        registerUndo { $0.insertCell(with: cellRemoveManager, time: $1) }
        self.time = time
        cut.removeCell(with: cellRemoveManager)
        isUpdate = true
    }
    
    private func setGeometries(_ keyGeometries: [Geometry], oldKeyGeometries: [Geometry], in cellItem: CellItem, _ group: Group, time: Int) {
        registerUndo { $0.setGeometries(oldKeyGeometries, oldKeyGeometries: keyGeometries, in: cellItem, group, time: $1) }
        self.time = time
        group.setKeyGeometries(keyGeometries, in: cellItem)
        isUpdate = true
    }
    private func setGeometry(_ geometry: Geometry, oldGeometry: Geometry, at i: Int, in cellItem: CellItem, time: Int) {
        registerUndo { $0.setGeometry(oldGeometry, oldGeometry: geometry, at: i, in: cellItem, time: $1) }
        self.time = time
        cellItem.replaceGeometry(geometry, at: i)
        isUpdate = true
    }
    
    override func addCellWithLines() {
        if isPlaying {
            screen?.tempNotAction()
            return
        }
        let drawingItem = cut.editGroup.drawingItem, rootCell = cut.rootCell
        let geometry = Geometry(lines: drawingItem.drawing.selectionLines, scale: drawInfo.scale)
        if !geometry.isEmpty {
            let isDrawingSelectionLines = !drawingItem.drawing.selectionLineIndexes.isEmpty
            let unselectionLines = drawingItem.drawing.unselectionLines
            if isDrawingSelectionLines {
                setSelectionLineIndexes([], in: drawingItem.drawing, time: time)
            }
            setLines(unselectionLines, oldLines: drawingItem.drawing.lines, drawing: drawingItem.drawing, time: time)
            if sceneView.timeline.isInterpolatedKeyframe(with: cut.editGroup) {
                sceneView.timeline.splitKeyframe(with: cut.editGroup)
            }
            let lki = cut.editGroup.loopedKeyframeIndex(withTime: cut.time)
            let keyGeometries = cut.editGroup.emptyKeyGeometries.withReplaced(geometry, at: lki.index)
            let newCellItem = CellItem(cell: Cell(geometry: geometry, material: Material(color: HSLColor.random())), keyGeometries: keyGeometries)
            insertCell(newCellItem, in: [(rootCell, addCellIndex(with: newCellItem.cell, in: rootCell))], cut.editGroup, time: time)
        } else {
            screen?.tempNotAction()
        }
    }
    override func addAndClipCellWithLines() {
        if isPlaying {
            screen?.tempNotAction()
            return
        }
        let drawingItem = cut.editGroup.drawingItem
        let geometry = Geometry(lines: drawingItem.drawing.selectionLines, scale: drawInfo.scale)
        if !geometry.isEmpty {
            let isDrawingSelectionLines = !drawingItem.drawing.selectionLineIndexes.isEmpty
            let unselectionLines = drawingItem.drawing.unselectionLines
            if isDrawingSelectionLines {
                setSelectionLineIndexes([], in: drawingItem.drawing, time: time)
            }
            setLines(unselectionLines, oldLines: drawingItem.drawing.lines, drawing: drawingItem.drawing, time: time)
            
            if sceneView.timeline.isInterpolatedKeyframe(with: cut.editGroup) {
                sceneView.timeline.splitKeyframe(with: cut.editGroup)
            }
            let lki = cut.editGroup.loopedKeyframeIndex(withTime: cut.time)
            let keyGeometries = cut.editGroup.emptyKeyGeometries.withReplaced(geometry, at: lki.index)
            let newCellItem = CellItem(cell: Cell(geometry: geometry, material: Material(color: HSLColor.random())), keyGeometries: keyGeometries)
            let ict = cut.indicationCellsTuple(with: convertToCut(currentPoint), usingLock: false)
            if ict.type == .selection {
                insertCell(newCellItem, in: ict.cells.map { ($0, addCellIndex(with: newCellItem.cell, in: $0)) }, cut.editGroup, time: time)
            } else {
                let ict = cut.indicationCellsTuple(with: convertToCut(currentPoint), usingLock: true)
                if ict.type != .none {
                    insertCell(newCellItem, in: ict.cells.map { ($0, addCellIndex(with: newCellItem.cell, in: $0)) }, cut.editGroup, time: time)
                } else {
                    screen?.tempNotAction()
                }
            }
        } else {
            screen?.tempNotAction()
        }
    }
    private func addCellIndex(with cell: Cell, in parent: Cell) -> Int {
        let editCells = cut.editGroup.cells
        for i in (0 ..< parent.children.count).reversed() {
            if editCells.contains(parent.children[i]) && parent.children[i].contains(cell) {
                return i + 1
            }
        }
        for i in 0 ..< parent.children.count {
            if editCells.contains(parent.children[i]) && parent.children[i].intersects(cell) {
                return i
            }
        }
        for i in 0 ..< parent.children.count {
            if editCells.contains(parent.children[i]) && !parent.children[i].isLocked {
                return i
            }
        }
        return cellIndex(withGroupIndex: cut.editGroupIndex, in: parent)
    }
    
    func cellIndex(withGroupIndex groupIndex: Int, in parent: Cell) -> Int {
        for i in groupIndex + 1 ..< cut.groups.count {
            let group = cut.groups[i]
            var maxIndex = 0, isMax = false
            for cellItem in group.cellItems {
                if let j = parent.children.index(of: cellItem.cell) {
                    isMax = true
                    maxIndex = max(maxIndex, j)
                }
            }
            if isMax {
                return maxIndex + 1
            }
        }
        return 0
    }
    
    func moveCell(_ cell: Cell, from fromParents: [(cell: Cell, index: Int)], to toParents: [(cell: Cell, index: Int)], time: Int) {
        registerUndo { $0.moveCell(cell, from: toParents, to: fromParents, time: $1) }
        self.time = time
        for fromParent in fromParents {
            fromParent.cell.children.remove(at: fromParent.index)
        }
        for toParent in toParents {
            toParent.cell.children.insert(cell, at: toParent.index)
        }
        isUpdate = true
    }
    override func lassoDelete() {
        if isPlaying {
            screen?.tempNotAction()
            return
        }
        let drawing = cut.editGroup.drawingItem.drawing, group = cut.editGroup
        if let lastLine = drawing.lines.last {
            removeLastLine(in: drawing, time: time)
            if !drawing.selectionLineIndexes.isEmpty {
                setSelectionLineIndexes([], in: drawing, time: time)
            }
            var isRemoveLineInDrawing = false, isRemoveLineInCell = false
            let lasso = Lasso(lines: [lastLine])
            let newDrawingLines = drawing.lines.reduce([Line]()) {
                if let splitLines = lasso.split($1) {
                    isRemoveLineInDrawing = true
                    return $0 + splitLines
                } else {
                    return $0 + [$1]
                }
            }
            if isRemoveLineInDrawing {
                setLines(newDrawingLines, oldLines: drawing.lines, drawing: drawing, time: time)
            }
            var removeCellItems: [CellItem] = group.cellItems.filter { cellItem in
                if cellItem.cell.intersects(lasso) {
                    if sceneView.timeline.isInterpolatedKeyframe(with: group) {
                        sceneView.timeline.splitKeyframe(with: group)
                    }
                    setGeometry(Geometry(), oldGeometry: cellItem.cell.geometry, at: group.editKeyframeIndex, in: cellItem, time: time)
                    if cellItem.isEmptyKeyGeometries {
                        return true
                    }
                    isRemoveLineInCell = true
                }
                return false
            }
            if !isRemoveLineInDrawing && !isRemoveLineInCell {
                if let hitCellItem = cut.cellItem(at: lastLine.firstPoint, with: group) {
                    if sceneView.timeline.isInterpolatedKeyframe(with: group) {
                        sceneView.timeline.splitKeyframe(with: group)
                    }
                    let lines = hitCellItem.cell.geometry.lines
                    setGeometry(Geometry(), oldGeometry: hitCellItem.cell.geometry, at: group.editKeyframeIndex, in: hitCellItem, time: time)
                    if hitCellItem.isEmptyKeyGeometries {
                        removeCellItems.append(hitCellItem)
                    }
                    setLines(drawing.lines + lines, oldLines: drawing.lines, drawing: drawing, time: time)
                }
            }
            if !removeCellItems.isEmpty {
                self.removeCellItems(removeCellItems)
            }
        } else {
            screen?.tempNotAction()
        }
    }
    override func lassoSelect() {
        lassoSelect(isDelete: false)
    }
    override func lassoDeleteSelect() {
        lassoSelect(isDelete: true)
    }
    private func lassoSelect(isDelete: Bool) {
        if isPlaying {
            screen?.tempNotAction()
            return
        }
        let group = cut.editGroup
        let drawing = group.drawingItem.drawing
        if let lastLine = drawing.lines.last {
            if let index = drawing.selectionLineIndexes.index(of: drawing.lines.count - 1) {
                setSelectionLineIndexes(drawing.selectionLineIndexes.withRemoved(at: index), in: drawing, time: time)
            }
            removeLastLine(in: drawing, time: time)
            let lasso = Lasso(lines: [lastLine])
            let intersectionCellItems = Set(group.cellItems.filter { $0.cell.intersects(lasso) })
            let selectionCellItems = Array(isDelete ? Set(group.selectionCellItems).subtracting(intersectionCellItems) : Set(group.selectionCellItems).union(intersectionCellItems))
            let drawingLineIndexes = Set(drawing.lines.enumerated().flatMap { lasso.intersects($1) ? $0 : nil })
            let selectionLineIndexes = Array(isDelete ? Set(drawing.selectionLineIndexes).subtracting(drawingLineIndexes) : Set(drawing.selectionLineIndexes).union(drawingLineIndexes))
            if selectionCellItems != group.selectionCellItems {
                setSelectionCellItems(selectionCellItems, in: group, time: time)
            }
            if selectionLineIndexes != drawing.selectionLineIndexes {
                setSelectionLineIndexes(selectionLineIndexes, in: drawing, time: time)
            }
        } else {
            screen?.tempNotAction()
        }
    }
    
    override func clipCellInSelection() {
        if isPlaying {
            screen?.tempNotAction()
            return
        }
        var isChanged = false
        let point = convertToCut(currentPoint)
        if let fromCell = cut.rootCell.atPoint(point) {
            let selectionCells = cut.allEditSelectionCellsWithNotEmptyGeometry
            if selectionCells.isEmpty {
                if !cut.rootCell.children.contains(fromCell) {
                    let fromParents = cut.rootCell.parents(with: fromCell)
                    moveCell(fromCell, from: fromParents, to: [(cut.rootCell, cut.rootCell.children.count)], time: time)
                    isChanged = true
                }
            } else if !selectionCells.contains(fromCell) {
                let fromChildrens = fromCell.allCells
                var newFromParents = cut.rootCell.parents(with: fromCell)
                let newToParents: [(cell: Cell, index: Int)] = selectionCells.flatMap { toCell in
                    for fromChild in fromChildrens {
                        if fromChild == toCell {
                            return nil
                        }
                    }
                    for (i, newFromParent) in newFromParents.enumerated() {
                        if toCell == newFromParent.cell {
                            newFromParents.remove(at: i)
                            return nil
                        }
                    }
                    return (toCell, toCell.children.count)
                }
                if !(newToParents.isEmpty && newFromParents.isEmpty) {
                    moveCell(fromCell, from: newFromParents, to: newToParents, time: time)
                    isChanged = true
                }
            }
        }
        if !isChanged {
            screen?.tempNotAction()
        }
    }
    
    private func insertCell(_ cellItem: CellItem, in parents: [(cell: Cell, index: Int)], _ group: Group, time: Int) {
        registerUndo { $0.removeCell(cellItem, in: parents, group, time: $1) }
        self.time = time
        cut.insertCell(cellItem, in: parents, group)
        isUpdate = true
    }
    private func removeCell(_ cellItem: CellItem, in parents: [(cell: Cell, index: Int)], _ group: Group, time: Int) {
        registerUndo { $0.insertCell(cellItem, in: parents, group, time: $1) }
        self.time = time
        cut.removeCell(cellItem, in: parents, group)
        isUpdate = true
    }
    private func insertCells(_ cellItems: [CellItem], rootCell: Cell, at index: Int, in parent: Cell, _ group: Group, time: Int) {
        registerUndo { $0.removeCells(cellItems, rootCell: rootCell, at: index, in: parent, group, time: $1) }
        self.time = time
        cut.insertCells(cellItems, rootCell: rootCell, at: index, in: parent, group)
        isUpdate = true
    }
    private func removeCells(_ cellItems: [CellItem], rootCell: Cell, at index: Int, in parent: Cell, _ group: Group, time: Int) {
        registerUndo { $0.insertCells(cellItems, rootCell: rootCell, at: index, in: parent, group, time: $1) }
        self.time = time
        cut.removeCells(cellItems, rootCell: rootCell, in: parent, group)
        isUpdate = true
    }
    
    override func hideCell() {
        if isPlaying {
            screen?.tempNotAction()
            return
        }
        let seletionCells = cut.indicationCellsTuple(with : convertToCut(currentPoint))
        var isChanged = false
        for cell in seletionCells.cells {
            if !cell.isEditHidden {
                setIsEditHidden(true, in: cell, time: time)
                isChanged = true
            }
        }
        if !isChanged {
            screen?.tempNotAction()
        }
    }
    override func showCell() {
        if isPlaying {
            screen?.tempNotAction()
            return
        }
        var isChanged = false
        for cell in cut.cells {
            if cell.isEditHidden {
                setIsEditHidden(false, in: cell, time: time)
                isChanged = true
            }
        }
        if !isChanged {
            screen?.tempNotAction()
        }
    }
    func setIsEditHidden(_ isEditHidden: Bool, in cell: Cell, time: Int) {
        registerUndo { [oldIsEditHidden = cell.isEditHidden] in $0.setIsEditHidden(oldIsEditHidden, in: cell, time: $1) }
        self.time = time
        cell.isEditHidden = isEditHidden
        isUpdate = true
    }
    
    override func pasteCell() {
        let pasteboard = NSPasteboard.general()
        if let data = pasteboard.data(forType: Cell.dataType), let copyRootCell = Cell.with(data) {
            let keyframeIndex = cut.editGroup.loopedKeyframeIndex(withTime: cut.time)
            var newCellItems = [CellItem]()
            copyRootCell.depthFirstSearch(duplicate: false) { parent, cell in
                cell.id = UUID()
                let keyGeometrys = cut.editGroup.emptyKeyGeometries.withReplaced(cell.geometry, at: keyframeIndex.index)
                newCellItems.append(CellItem(cell: cell, keyGeometries: keyGeometrys, keyMaterials: []))
            }
            let index = cellIndex(withGroupIndex: cut.editGroupIndex, in: cut.rootCell)
            insertCells(newCellItems, rootCell: copyRootCell, at: index, in: cut.rootCell, cut.editGroup, time: time)
            setSelectionCellItems(cut.editGroup.selectionCellItems + newCellItems, in: cut.editGroup, time: time)
        }
    }
    override func pasteMaterial() {
        if let data = NSPasteboard.general().data(forType: Material.dataType), let material = Material.with(data) {
            paste(material)
        }
    }
    override func copyAndBindMaterial() {
        let point = convertToCut(currentPoint)
        sceneView.materialView.copy(cut.rootCell.atPoint(point)?.material ?? Material(), from: self)
    }
    override func splitColor() {
        let point = convertToCut(currentPoint)
        let ict = cut.indicationCellsTuple(with: point)
        if !ict.cells.isEmpty {
            sceneView.materialView.splitColor(with: ict.cells)
            highlight()
        } else {
            screen?.tempNotAction()
        }
    }
    override func splitOtherThanColor() {
        let point = convertToCut(currentPoint)
        let ict = cut.indicationCellsTuple(with: point)
        if !ict.cells.isEmpty {
            sceneView.materialView.splitOtherThanColor(with: ict.cells)
            highlight()
        } else {
            screen?.tempNotAction()
        }
    }
    
    override func changeToRough() {
        if isPlaying {
            screen?.tempNotAction()
            return
        }
        let drawing = cut.editGroup.drawingItem.drawing
        if !drawing.roughLines.isEmpty || !drawing.lines.isEmpty {
            setRoughLines(drawing.selectionLines, oldLines: drawing.roughLines, drawing: drawing, time: time)
            setLines(drawing.unselectionLines, oldLines: drawing.lines, drawing: drawing, time: time)
            if !drawing.selectionLineIndexes.isEmpty {
                setSelectionLineIndexes([], in: drawing, time: time)
            }
        } else {
            screen?.tempNotAction()
        }
    }
    override func removeRough() {
        if isPlaying {
            screen?.tempNotAction()
            return
        }
        let drawing = cut.editGroup.drawingItem.drawing
        if !drawing.roughLines.isEmpty {
            setRoughLines([], oldLines: drawing.roughLines, drawing: drawing, time: time)
        } else {
            screen?.tempNotAction()
        }
    }
    override func swapRough() {
        if isPlaying {
            screen?.tempNotAction()
            return
        }
        let drawing = cut.editGroup.drawingItem.drawing
        if !drawing.roughLines.isEmpty || !drawing.lines.isEmpty {
            if !drawing.selectionLineIndexes.isEmpty {
                setSelectionLineIndexes([], in: drawing, time: time)
            }
            let newLines = drawing.roughLines, newRoughLines = drawing.lines
            setRoughLines(newRoughLines, oldLines: drawing.roughLines, drawing: drawing, time: time)
            setLines(newLines, oldLines: drawing.lines, drawing: drawing, time: time)
        } else {
            screen?.tempNotAction()
        }
    }
    private func setRoughLines(_ lines: [Line], oldLines: [Line], drawing: Drawing, time: Int) {
        registerUndo { $0.setRoughLines(oldLines, oldLines: lines, drawing: drawing, time: $1) }
        self.time = time
        drawing.roughLines = lines
        isUpdate = true
    }
    private func setLines(_ lines: [Line], oldLines: [Line], drawing: Drawing, time: Int) {
        registerUndo { $0.setLines(oldLines, oldLines: lines, drawing: drawing, time: $1) }
        self.time = time
        drawing.lines = lines
        isUpdate = true
    }
    
    override var indication: Bool {
        didSet {
            if !indication {
                editIndicationCells = []
                indicationCellItem = nil
                setNeedsDisplay()
            }
        }
    }
    override func moveCursor(with event: MoveEvent) {
        updateEditView(with: convertToCut(point(from: event)))
    }
    func updateEditView(with p : CGPoint) {
        switch viewType {
        case .edit, .editMaterial, .editingMaterial, .preview:
            break
        case .editPoint:
            updateEditCells(with: p)
            updateEditIndicationLines(with: p)
            updateEditPoint(with: p)
        case .editLine:
            updateEditCells(with: p)
            updateEditIndicationLines(with: p)
            updateEditVertex(with: p)
        case .editMoveZ:
            updateMoveZ(with: p)
        case .editTransform:
            updateTransform(with: p)
        }
//        let hitIndicationCellItem = viewType == .editPoint || viewType == .editLine ? editPointCellItem : cut.cellItem(at: p, with: cut.editGroup)
        let hitIndicationCellItem = cut.cellItem(at: p, with: cut.editGroup)
        if hitIndicationCellItem !== indicationCellItem {
            indicationCellItem = hitIndicationCellItem
            setNeedsDisplay()
        }
    }
    func updateEditCells(with p: CGPoint) {
        let indicationRadius = 30.0.cf/drawInfo.scale
        let indicationBounds = CGRect(x: p.x - indicationRadius, y: p.y - indicationRadius, width: indicationRadius*2, height: indicationRadius*2)
        var hitCells = [Cell]()
        cut.rootCell.depthFirstSearch(duplicate: false) { parent, cell in
            if cell.intersects(indicationBounds) && cell.isEditable {
                hitCells.append(cell)
            }
        }
        if hitCells != editIndicationCells {
            editIndicationCells = hitCells
            setNeedsDisplay()
        }
    }
    func updateEditIndicationLines(with p: CGPoint) {
        let indicationRadius = 50.0.cf/drawInfo.scale
        let indicationBounds = CGRect(x: p.x - indicationRadius, y: p.y - indicationRadius, width: indicationRadius*2, height: indicationRadius*2)
        let hitLines = cut.editGroup.drawingItem.drawing.lines.filter {
            $0.intersects(indicationBounds) || $0.editPointDistance(at: p) < indicationRadius
        }
        if hitLines != editIndicationLines {
            editIndicationLines = hitLines
            setNeedsDisplay()
        }
    }
    func updateEditPoint(with point: CGPoint) {
        if let ep = cut.nearestEditPoint(point).nearestDrawing {
            editPoint = Cut.EditPoint(line: ep.line, pointIndex: ep.pointIndex, controlLineIndex: ep.controlLineIndex)
        } else {
            editPoint = nil
        }
    }
    func updateEditVertex(with point: CGPoint) {
//        if let ep = cut.nearestVertex(point) {
//            editLine = Cut.EditLine(line: ep.line, otherLine: ep.otherLine, isFirst: ep.isFirst, isOtherFirst: ep.isOtherFirst)
//        } else {
//            editLine = nil
//        }
    }
    var transformViewType = Cut.TransformViewType.none, transformRotationBounds = CGRect()
    func updateTransform(with point: CGPoint) {
        setNeedsDisplay()
    }
    
    var editPoint: Cut.EditPoint? {
        didSet {
            setNeedsDisplay()
        }
    }
    var editLine: Cut.EditLine? {
        didSet {
            setNeedsDisplay()
        }
    }
    weak var editPointCellItem: CellItem?
    var editIndicationCells = [Cell](), editIndicationLines = [Line]()
    var indicationCellItem: CellItem? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func willDrag(with event: DragEvent) -> Bool {
        if isPlaying {
            sceneView.timeline.stop()
            return false
        } else {
            return true
        }
    }
    private var strokeOldPoint = CGPoint(), strokeOldTime = TimeInterval(0), strokeOldLastBounds = CGRect(), strokeIsDrag = false, strokeControls: [Line.Control] = []
    private let strokeSplitAngle = 1.5*(.pi)/2.0.cf, strokeLowSplitAngle = 0.9*(.pi)/2.0.cf, strokeDistance = 1.2.cf, strokeTime = TimeInterval(0.1), strokeSlowDistance = 3.5.cf, strokeSlowTime = TimeInterval(0.25)
    override func drag(with event: DragEvent) {
        drag(with: event, lineWidth: lineWidth, strokeDistance: strokeDistance, strokeTime: strokeTime)
    }
    override func slowDrag(with event: DragEvent) {
        drag(with: event, lineWidth: lineWidth, strokeDistance: strokeSlowDistance, strokeTime: strokeSlowTime, splitAcuteAngle: false)
    }
    func drag(with event: DragEvent, lineWidth: CGFloat, strokeDistance: CGFloat, strokeTime: TimeInterval, splitAcuteAngle: Bool = true) {
        let p = convertToCut(point(from: event))
        switch event.sendType {
        case .begin:
            let firstControl = Line.Control(point: p, pressure: event.pressure.cf, weight: 0.5)
            let line = Line(controls: [firstControl, firstControl])
            strokeLine = line
            strokeOldPoint = p
            strokeOldTime = event.time
            strokeOldLastBounds = line.strokeLastBoundingBox
            strokeIsDrag = false
            strokeControls = [firstControl]
        case .sending:
            if var line = strokeLine {
                if p != strokeOldPoint {
                    strokeIsDrag = true
                    let ac = strokeControls.first!, bp = p, lc = strokeControls.last!, scale = drawInfo.scale
                    let control = Line.Control(point: p, pressure: event.pressure.cf, weight: 0.5)
                    strokeControls.append(control)
                    if splitAcuteAngle && line.controls.count >= 3 {
                        let c0 = line.controls[line.controls.count - 3], c1 = line.controls[line.controls.count - 2], c2 = lc
                        if c0.point != c1.point && c1.point != c2.point {
                            let dr = abs(CGPoint.differenceAngle(p0: c0.point, p1: c1.point, p2: c2.point))
                            if dr > strokeLowSplitAngle {
                                if dr > strokeSplitAngle {
                                    line = line.withInsert(c1, at: line.count - 1)
                                    let  lastBounds = line.strokeLastBoundingBox
                                    strokeLine = line
                                    setNeedsDisplay(in: lastBounds.union(strokeOldLastBounds).inset(by: -lineWidth/2))
                                    strokeOldLastBounds = lastBounds
                                } else {
                                    let t = 1 - (dr - strokeLowSplitAngle)/strokeSplitAngle
                                    let tp = CGPoint.linear(c1.point, c2.point, t: t)
                                    if c1.point != tp {
                                        line = line.withInsert(Line.Control(point: tp, pressure: CGFloat.linear(c1.pressure, c2.pressure, t:  t), weight: 0.5), at: line.count - 1)
                                        let  lastBounds = line.strokeLastBoundingBox
                                        strokeLine = line
                                        setNeedsDisplay(in: lastBounds.union(strokeOldLastBounds).inset(by: -lineWidth/2))
                                        strokeOldLastBounds = lastBounds
                                    }
                                }
                            }
                        }
                    }
                    if line.controls[line.controls.count - 2].point != lc.point {
                        for (i, sp) in strokeControls.enumerated() {
                            if i > 0 {
                                if sp.point.distanceWithLine(ap: ac.point, bp: bp)*scale > strokeDistance || event.time - strokeOldTime > strokeTime {
                                    line = line.withInsert(lc, at: line.count - 1)
                                    strokeLine = line
                                    let lastBounds = line.strokeLastBoundingBox
                                    setNeedsDisplay(in: lastBounds.union(strokeOldLastBounds).inset(by: -lineWidth/2))
                                    strokeOldLastBounds = lastBounds
                                    strokeControls = [lc]
                                    strokeOldTime = event.time
                                    break
                                }
                            }
                        }
                    }
                    
                    line = line.withReplaced(control, at: line.count - 1)
                    strokeLine = line
                    let lastBounds = line.strokeLastBoundingBox
                    setNeedsDisplay(in: lastBounds.union(strokeOldLastBounds).inset(by: -lineWidth/2))
                    strokeOldLastBounds = lastBounds
                    strokeOldPoint = p
                }
            }
        case .end:
            if let line = strokeLine {
                strokeLine = nil
                if strokeIsDrag {
                    func lastRevisionLine(line: Line) -> Line {
                        if line.count > 3 {
                            let ap = line.controls[line.count - 3].point, bp = p, lp = line.controls[line.count - 2].point, scale = drawInfo.scale
                            if !(lp.distanceWithLine(ap: ap, bp: bp)*scale > strokeDistance || event.time - strokeOldTime > strokeTime) {
                                return line.withRemoveControl(at: line.count - 2)
                            }
                        }
                        return line
                    }
                    let newLine = lastRevisionLine(line: line)
                    addLine(newLine.withReplaced(Line.Control(point: p, pressure: newLine.controls.last!.pressure, weight: 0.5), at: newLine.count - 1), in: cut.editGroup.drawingItem.drawing, time: time)
                }
            }
        }
    }
    private func addLine(_ line: Line, in drawing: Drawing, time: Int) {
        registerUndo { $0.removeLastLine(in: drawing, time: $1) }
        self.time = time
        drawing.lines.append(line)
        isUpdate = true
    }
    private func removeLastLine(in drawing: Drawing, time: Int) {
        registerUndo { [lastLine = drawing.lines.last!] in $0.addLine(lastLine, in: drawing, time: $1) }
        self.time = time
        drawing.lines.removeLast()
        isUpdate = true
    }
    private func insertLine(_ line: Line, at i: Int, in drawing: Drawing, time: Int) {
        registerUndo { $0.removeLine(at: i, in: drawing, time: $1) }
        self.time = time
        drawing.lines.insert(line, at: i)
        isUpdate = true
    }
    private func removeLine(at i: Int, in drawing: Drawing, time: Int) {
        let oldLine = drawing.lines[i]
        registerUndo { $0.insertLine(oldLine, at: i, in: drawing, time: $1) }
        self.time = time
        drawing.lines.remove(at: i)
        isUpdate = true
    }
    private func setSelectionLineIndexes(_ lineIndexes: [Int], in drawing: Drawing, time: Int) {
        registerUndo { [os = drawing.selectionLineIndexes] in $0.setSelectionLineIndexes(os, in: drawing, time: $1) }
        self.time = time
        drawing.selectionLineIndexes = lineIndexes
        isUpdate = true
    }
    
    override func click(with event: DragEvent) {
        selectCell(convertToCut(point(from: event)))
    }
    func selectCell(_ p: CGPoint) {
        var isChanged = false
        let selectionCell = cut.rootCell.cells(at: p).first
        if let selectionCell = selectionCell {
            if selectionCell.material.id != sceneView.materialView.material.id {
                setMaterial(selectionCell.material, time: time)
                isChanged = true
            }
        } else {
            if MaterialView.emptyMaterial != sceneView.materialView.material {
                setMaterial(MaterialView.emptyMaterial, time: time)
                isChanged = true
            }
            for group in cut.groups {
                if !group.selectionCellItems.isEmpty {
                    setSelectionCellItems([], in: group, time: time)
                    isChanged = true
                }
            }
            for group in cut.groups {
                if !group.drawingItem.drawing.selectionLineIndexes.isEmpty {
                    setSelectionLineIndexes([], in: group.drawingItem.drawing, time: time)
                }
            }
        }
        if !isChanged {
            screen?.tempNotAction()
        }
    }
    private func setMaterial(_ material: Material, time: Int) {
        registerUndo { [om = sceneView.materialView.material] in $0.setMaterial(om, time: $1) }
        self.time = time
        sceneView.materialView.material = material
    }
    private func setSelectionCellItems(_ cellItems: [CellItem], in group: Group, time: Int) {
        registerUndo { [os = group.selectionCellItems] in $0.setSelectionCellItems(os, in: group, time: $1) }
        self.time = time
        group.selectionCellItems = cellItems
        setNeedsDisplay()
        sceneView.timeline.setNeedsDisplay()
        isUpdate = true
    }
    
    override func addPoint() {
        let p = convertToCut(currentPoint)
        let e = cut.nearestEditPoint(p)
        if let nd = e.nearestDrawing {
            let c = Line.Control(
                point: nd.line.controls[nd.controlLineIndex].point.mid(nd.line.controls[nd.controlLineIndex + 1].point),
                pressure: (nd.line.controls[nd.controlLineIndex].pressure + nd.line.controls[nd.controlLineIndex + 1].pressure)/2,
                weight: 0.5
            )
            insert(c, at: nd.controlLineIndex + 1, in: nd.drawing, nd.lineIndex, time: time)
            updateEditIndicationLines(with: p)
            updateEditPoint(with: p)
        } else if let ng = e.nearestGeometry {
            if sceneView.timeline.isInterpolatedKeyframe(with: cut.editGroup) {
                sceneView.timeline.splitKeyframe(with: cut.editGroup)
            }
            setGeometries(Geometry.splitedGeometries(with: ng.cellItem.keyGeometries, t: ng.t, at: ng.bezierIndex), oldKeyGeometries: ng.cellItem.keyGeometries, in: ng.cellItem, cut.editGroup, time: time)
            updateEditIndicationLines(with: p)
            updateEditPoint(with: p)
        } else {
            screen?.tempNotAction()
        }
    }
    override func deletePoint() {
        let p = convertToCut(currentPoint)
        let e = cut.nearestEditPoint(p)
        if let nd = e.nearestDrawing {
            if nd.line.count > 2 {
                removeControl(at: nd.pointIndex, in: nd.drawing, nd.lineIndex, time: time)
            } else {
                removeLine(at: nd.lineIndex, in: nd.drawing, time: time)
            }
            updateEditIndicationLines(with: p)
            updateEditPoint(with: p)
        } else if let ng = e.nearestGeometry {
            if sceneView.timeline.isInterpolatedKeyframe(with: cut.editGroup) {
                sceneView.timeline.splitKeyframe(with: cut.editGroup)
            }
            setGeometries(ng.bezierPoint == .cp ? Geometry.removedBezierWithGeometries(ng.cellItem.keyGeometries, at: ng.bezierIndex) : Geometry.JoinedGeometries(with: ng.cellItem.keyGeometries, bezierPoint: ng.bezierPoint, at: ng.bezierIndex), oldKeyGeometries: ng.cellItem.keyGeometries, in: ng.cellItem, cut.editGroup, time: time)
            if ng.cellItem.isEmptyKeyGeometries {
                removeCellItems([ng.cellItem])
            }
            updateEditIndicationLines(with: p)
            updateEditPoint(with: p)
        } else {
            screen?.tempNotAction()
        }
    }
    private func insert(_ control: Line.Control, at index: Int, in drawing: Drawing, _ lineIndex: Int, time: Int) {
        registerUndo { $0.removeControl(at: index, in: drawing, lineIndex, time: $1) }
        self.time = time
        drawing.lines[lineIndex] = drawing.lines[lineIndex].withInsert(control, at: index)
        isUpdate = true
    }
    private func removeControl(at index: Int, in drawing: Drawing, _ lineIndex: Int, time: Int) {
        let line = drawing.lines[lineIndex]
        registerUndo { [oc = line.controls[index]] in $0.insert(oc, at: index, in: drawing, lineIndex, time: $1) }
        self.time = time
        drawing.lines[lineIndex] = line.withRemoveControl(at: index)
        isUpdate = true
    }
    
    private var movePointNearestDrawing: Cut.NearestDrawing?, movePointNearestGeometry: Cut.NearestGeometry?, movePointOldPoint = CGPoint()
    private let movePointSnapDistance = 8.0.cf
    override func movePoint(with event: DragEvent) {
        let p = convertToCut(point(from: event))
        switch event.sendType {
        case .begin:
            undoManager?.beginUndoGrouping()
            let e = cut.nearestEditPoint(p)
            if let nd = e.nearestDrawing {
                movePointNearestDrawing = nd
            } else if let ng = e.nearestGeometry {
                if cut.isInterpolatedKeyframe(with: cut.editGroup) {
                    sceneView.timeline.splitKeyframe(with: cut.editGroup)
                    movePointNearestGeometry = Cut.NearestGeometry(cellItem: ng.cellItem, geometry: ng.cellItem.cell.geometry, bezierIndex: ng.bezierIndex, t: ng.t, bezierPoint: ng.bezierPoint, oldPoint: ng.oldPoint)
                } else {
                    movePointNearestGeometry = ng
                }
            } else {
                screen?.tempNotAction()
            }
            movePointOldPoint = p
            updateEditView(with: p)
        case .sending:
            if let m = movePointNearestDrawing {
                let np = snapPoint(p - movePointOldPoint, oldPoint: m.oldControl.point, pointIndex: m.pointIndex, line: m.drawing.lines[m.lineIndex], otherLine: nil, isOtherFirst: false)
                var c = m.drawing.lines[m.lineIndex].controls[m.pointIndex]
                c.point = np
                m.drawing.lines[m.lineIndex] = m.drawing.lines[m.lineIndex].withReplaced(c, at: m.pointIndex)
                editPoint = Cut.EditPoint(line: m.drawing.lines[m.lineIndex], pointIndex: m.pointIndex, controlLineIndex: m.controlLineIndex)
            } else if let m = movePointNearestGeometry {
                let dp = p - movePointOldPoint,bezier: Bezier2, oldBezier = m.cellItem.cell.geometry.beziers[m.bezierIndex]
                switch m.bezierPoint {
                case .p0:
                    let minP = snapPoint(newPoint: m.oldPoint + dp, with: m, cut.editGroup.cellItems)
                    bezier = Bezier2(p0: minP, cp: oldBezier.cp, p1: oldBezier.p1)
                case .cp:
                    let minP = snapControlPoint(newPoint: m.oldPoint + dp, with: m, cut.editGroup.cellItems)
                    bezier = Bezier2(p0: oldBezier.p0, cp: minP, p1: oldBezier.p1)
                case .p1:
                    let minP = snapPoint(newPoint: m.oldPoint + dp, with: m, cut.editGroup.cellItems)
                    bezier = Bezier2(p0: oldBezier.p0, cp: oldBezier.cp, p1: minP)
                }
                let geometry = Geometry(beziers: m.geometry.beziers.withReplaced(bezier, at: m.bezierIndex))
                m.cellItem.replaceGeometry(geometry, at: cut.editGroup.editKeyframeIndex)
//                editPoint = Cut.EditPoint(line: lines[m.lineIndex], pointIndex: m.pointIndex, controlLineIndex: m.controlLineIndex)
            } else {
                screen?.tempNotAction()
            }
        case .end:
            if let m = movePointNearestDrawing {
                let np = snapPoint(p - movePointOldPoint, oldPoint: m.oldControl.point, pointIndex: m.pointIndex, line: m.drawing.lines[m.lineIndex], otherLine: nil, isOtherFirst: false)
                var c = m.drawing.lines[m.lineIndex].controls[m.pointIndex]
                c.point = np
                setControl(c, oldControl: m.oldControl, at: m.pointIndex, lineIndex: m.lineIndex, drawing: m.drawing, time: time)
                updateEditPoint(with: p)
                movePointNearestDrawing = nil
            } else if let m = movePointNearestGeometry {
                let dp = p - movePointOldPoint,bezier: Bezier2, oldBezier = m.geometry.beziers[m.bezierIndex]
                switch m.bezierPoint {
                case .p0:
                    let minP = snapPoint(newPoint: m.oldPoint + dp, with: m, cut.editGroup.cellItems)
                    bezier = Bezier2(p0: minP, cp: oldBezier.cp, p1: oldBezier.p1)
                case .cp:
                    let minP = snapControlPoint(newPoint: m.oldPoint + dp, with: m, cut.editGroup.cellItems)
                    bezier = Bezier2(p0: oldBezier.p0, cp: minP, p1: oldBezier.p1)
                case .p1:
                    let minP = snapPoint(newPoint: m.oldPoint + dp, with: m, cut.editGroup.cellItems)
                    bezier = Bezier2(p0: oldBezier.p0, cp: oldBezier.cp, p1: minP)
                }
                let geometry = Geometry(beziers: m.geometry.beziers.withReplaced(bezier, at: m.bezierIndex))
                m.cellItem.replaceGeometry(geometry, at: cut.editGroup.editKeyframeIndex)
                setGeometry(geometry, oldGeometry: m.geometry, at: cut.editGroup.editKeyframeIndex, in: m.cellItem, time: time)
                updateEditPoint(with: p)
                movePointNearestGeometry = nil
            } else {
                screen?.tempNotAction()
            }
            undoManager?.endUndoGrouping()
        }
        updateEditIndicationLines(with: p)
        setNeedsDisplay()
    }
    func snapControlPoint(newPoint np: CGPoint, with n: Cut.NearestGeometry, _ cellItems: [CellItem]) -> CGPoint {
        let snapD = movePointSnapDistance/drawInfo.scale
        let bezier = n.geometry.beziers[n.bezierIndex]
        var minBs = [(d: CGFloat, p0: CGPoint, p1: CGPoint)]()
        for cellItem in cellItems {
            for (i, b) in cellItem.cell.geometry.beziers.enumerated() {
                if !(cellItem == n.cellItem && i == n.bezierIndex) {
                    if b.p0 == bezier.p0 || b.p0 == bezier.p1 {
                        let d = np.distanceWithLine(ap: b.cp, bp: b.p0)
                        if d < snapD {
                            minBs.append((d, b.cp, b.p0))
                        }
                    } else if b.p1 == bezier.p0 || b.p1 == bezier.p1 {
                        let d = np.distanceWithLine(ap: b.p1, bp: b.cp)
                        if d < snapD {
                            minBs.append((d, b.p1, b.cp))
                        }
                    }
                }
            }
        }
        let sortedMinBs = minBs.sorted() { $0.d < $1.d }
        if let firstB = sortedMinBs.first {
            if sortedMinBs.count >= 2 {
                let secondB = sortedMinBs[1]
                return CGPoint.intersectionLine(firstB.p0, firstB.p1, secondB.p0, secondB.p1) ?? firstB.p1.mid(secondB.p0)
            } else {
                return np.nearestWithLine(ap: firstB.p0, bp: firstB.p1)
            }
        }
        return np
    }
    func snapPoint(newPoint np: CGPoint, with n: Cut.NearestGeometry, _ cellItems: [CellItem]) -> CGPoint {
        let snapD = movePointSnapDistance/drawInfo.scale
        var minD = CGFloat.infinity, minP = np
        for aCellItem in cellItems {
            for (i, b) in aCellItem.cell.geometry.beziers.enumerated() {
                if aCellItem == n.cellItem && i == n.bezierIndex {
                    if n.bezierPoint == .p0 {
                        let d1 = np.distance(b.p1)
                        if d1 < snapD && d1 < minD {
                            minD = d1
                            minP = b.p1
                        }
                    } else {
                        let d0 = np.distance(b.p0)
                        if d0 < snapD && d0 < minD {
                            minD = d0
                            minP = b.p0
                        }
                    }
                } else {
                    let d0 = np.distance(b.p0), d1 = np.distance(b.p1)
                    if d0 < snapD && d0 < minD {
                        minD = d0
                        minP = b.p0
                    }
                    if d1 < snapD && d1 < minD {
                        minD = d1
                        minP = b.p1
                    }
                }
            }
        }
        return minP
    }
    func snapPoint(_ dp: CGPoint, oldPoint: CGPoint, pointIndex: Int, line: Line, otherLine: Line?, isOtherFirst: Bool) -> CGPoint {
        let p = dp + oldPoint
        if pointIndex == 0 {
            if let otherLine = otherLine {
                return cut.editGroup.snapPoint(p, snapDistance: movePointSnapDistance/drawInfo.scale, otherLines: [(line, true), (otherLine, isOtherFirst)])
            } else {
                return cut.editGroup.snapPoint(p, snapDistance: movePointSnapDistance/drawInfo.scale, otherLines: [(line, true)])
            }
        }
        else if pointIndex == line.count - 1 {
            if let otherLine = otherLine {
                return cut.editGroup.snapPoint(p, snapDistance: movePointSnapDistance/drawInfo.scale, otherLines: [(line,false), (otherLine, isOtherFirst)])
            } else {
                return cut.editGroup.snapPoint(p, snapDistance: movePointSnapDistance/drawInfo.scale, otherLines: [(line, false)])
            }
        } else {
            return p
        }
    }
    private func setControl(_ control: Line.Control, oldControl: Line.Control, at i: Int, lineIndex li: Int, drawing: Drawing, time: Int) {
        registerUndo { $0.setControl(oldControl, oldControl: control, at: i, lineIndex: li, drawing: drawing, time: $1) }
        self.time = time
        drawing.lines[li] = drawing.lines[li].withReplaced(control, at: i)
        isUpdate = true
    }
    
    private var warpDrawing: Cut.VertexDrawing?, warpGeometry: Cut.VertexGeometry?, warpControlGeometry: Cut.VertexControlGeometry?, warpLineOldPoint = CGPoint()
    override func warpLine(with event: DragEvent) {
        let p = convertToCut(point(from: event))
        switch event.sendType {
        case .begin:
            undoManager?.beginUndoGrouping()
            let e = cut.nearestVertex(p)
            if let w = e.vertexDrawing {
                warpDrawing = w
            } else if let w = e.vertexGeometry {
                if cut.isInterpolatedKeyframe(with: cut.editGroup) {
                    sceneView.timeline.splitKeyframe(with: cut.editGroup)
                    warpGeometry = Cut.VertexGeometry(vertexs: w.vertexs.map { ($0.cellItem, $0.cellItem.cell.geometry, $0.beziers) }, oldPoint: w.oldPoint)
                } else {
                    warpGeometry = w
                }
            } else if let w = e.vertexControlGeometry {
                if cut.isInterpolatedKeyframe(with: cut.editGroup) {
                    sceneView.timeline.splitKeyframe(with: cut.editGroup)
                    warpControlGeometry = Cut.VertexControlGeometry(cellItem: w.cellItem, geometry: w.cellItem.cell.geometry, bezierIndex: w.bezierIndex, controls: w.controls.map { ($0.cellItem, $0.cellItem.cell.geometry, $0.bezierIndex, $0.connectBezierPoint, $0.connectBezierPoint) }, oldPoint: w.oldPoint)
                } else {
                     warpControlGeometry = w
                }
            } else {
                screen?.tempNotAction()
            }
            warpLineOldPoint = p
            updateEditView(with: p)
        case .sending:
            let dp = p - warpLineOldPoint
            if let w = warpDrawing {
                let ddp = snapPoint(dp, oldPoint: w.oldPoint, pointIndex: w.isFirst ? 0 : w.line.count - 1, line: w.drawing.lines[w.index], otherLine: w.otherLine != nil ? w.drawing.lines[w.otherIndex] : nil, isOtherFirst: w.isOtherFirst) - w.oldPoint
                w.drawing.lines[w.index] = w.line.warpedWith(deltaPoint: ddp, isFirst: w.isFirst)
                if let otherLine = w.otherLine {
                    w.drawing.lines[w.otherIndex] = otherLine.warpedWith(deltaPoint: ddp, isFirst: w.isOtherFirst)
                }
                editLine = Cut.EditLine(line: w.drawing.lines[w.index], otherLine: w.otherLine != nil ? w.drawing.lines[w.otherIndex] : nil, isFirst: w.isFirst, isOtherFirst: w.isOtherFirst)
            } else if let w = warpGeometry {
                for v in w.vertexs {
                    v.cellItem.cell.geometry = v.geometry.warped(dp: dp, bezierPointIndexs: v.beziers)
                }
            } else if let w = warpControlGeometry {
                let oldCPBezier = w.cellItem.cell.geometry.beziers[w.bezierIndex]
                var newCPBezier = oldCPBezier
                newCPBezier.cp = dp + w.oldPoint
                for control in w.controls {
                    let preBezier = control.geometry.beziers[control.bezierIndex]
                    if control.connectBezierPoint == .p0 {
                        let t = preBezier.cp.distance(preBezier.p0)/preBezier.cp.distance(oldCPBezier.cp)
                        let newP = CGPoint.linear(preBezier.cp, newCPBezier.cp, t: t)
                        var newBeziers = control.cellItem.cell.geometry.beziers
                        newCPBezier.setPoint(newP, at: control.controlBezierPoint)
                        newBeziers[control.bezierIndex].p0 = newP
                        control.cellItem.cell.geometry = Geometry(beziers: newBeziers)
                    } else {
                        let t = preBezier.cp.distance(preBezier.p1)/oldCPBezier.cp.distance(preBezier.cp)
                        let newP = CGPoint.linear(preBezier.cp, newCPBezier.cp, t: t)
                        var newBeziers = control.cellItem.cell.geometry.beziers
                        newBeziers[control.bezierIndex].p1 = newP
                        newCPBezier.setPoint(newP, at: control.controlBezierPoint)
                        control.cellItem.cell.geometry = Geometry(beziers: newBeziers)
                    }
                }
                w.cellItem.cell.geometry = Geometry(beziers: w.cellItem.cell.geometry.beziers.withReplaced(newCPBezier, at: w.bezierIndex))
            } else {
                screen?.tempNotAction()
            }
        case .end:
            let dp = p - warpLineOldPoint
            if let w = warpDrawing {
                let ddp = w.otherLine != nil ? dp : snapPoint(dp, oldPoint: w.oldPoint, pointIndex: w.isFirst ? 0 : w.line.count - 1, line: w.drawing.lines[w.index], otherLine: w.otherLine != nil ? w.drawing.lines[w.otherIndex] : nil, isOtherFirst: w.isOtherFirst) - w.oldPoint
                replaceLine(w.line.warpedWith(deltaPoint: ddp, isFirst: w.isFirst), oldLine: w.line, at: w.index, in: w.drawing, time: time)
                if let otherLine = w.otherLine {
                    replaceLine(otherLine.warpedWith(deltaPoint: ddp, isFirst: w.isOtherFirst), oldLine: otherLine, at: w.otherIndex, in: w.drawing, time: time)
                }
                updateEditVertex(with: p)
                warpDrawing = nil
            } else if let w = warpGeometry {
                for v in w.vertexs {
                    setGeometry(v.geometry.warped(dp: dp, bezierPointIndexs: v.beziers), oldGeometry: v.geometry, at: cut.editGroup.editKeyframeIndex, in: v.cellItem, time: time)
                }
                updateEditVertex(with: p)
                warpGeometry = nil
            } else if let w = warpControlGeometry {
                let oldCPBezier = w.cellItem.cell.geometry.beziers[w.bezierIndex]
                var newCPBezier = oldCPBezier
                newCPBezier.cp = dp + w.oldPoint
                for control in w.controls {
                    let preBezier = control.geometry.beziers[control.bezierIndex]
                    if control.connectBezierPoint == .p0 {
                        let t = preBezier.cp.distance(preBezier.p0)/preBezier.cp.distance(oldCPBezier.cp)
                        let newP = CGPoint.linear(preBezier.cp, newCPBezier.cp, t: t)
                        var newBeziers = control.cellItem.cell.geometry.beziers
                        newCPBezier.setPoint(newP, at: control.controlBezierPoint)
                        newBeziers[control.bezierIndex].p0 = newP
                        setGeometry(Geometry(beziers: newBeziers), oldGeometry: control.geometry, at: cut.editGroup.editKeyframeIndex, in: control.cellItem, time: time)
                    } else {
                        let t = preBezier.cp.distance(preBezier.p1)/oldCPBezier.cp.distance(preBezier.cp)
                        let newP = CGPoint.linear(preBezier.cp, newCPBezier.cp, t: t)
                        var newBeziers = control.cellItem.cell.geometry.beziers
                        newBeziers[control.bezierIndex].p1 = newP
                        newCPBezier.setPoint(newP, at: control.controlBezierPoint)
                        setGeometry(Geometry(beziers: newBeziers), oldGeometry: control.geometry, at: cut.editGroup.editKeyframeIndex, in: control.cellItem, time: time)
                    }
                }
                setGeometry(Geometry(beziers: w.cellItem.cell.geometry.beziers.withReplaced(newCPBezier, at: w.bezierIndex)), oldGeometry: w.geometry, at: cut.editGroup.editKeyframeIndex, in: w.cellItem, time: time)
                
                updateEditVertex(with: p)
                warpControlGeometry = nil
            } else {
                screen?.tempNotAction()
            }
            undoManager?.endUndoGrouping()
        }
        updateEditIndicationLines(with: p)
        setNeedsDisplay()
    }
    private func replaceLine(_ line: Line, oldLine: Line, at i: Int, in drawing: Drawing, time: Int) {
        registerUndo { $0.replaceLine(oldLine, oldLine: line, at: i, in: drawing, time: $1) }
        self.time = time
        drawing.lines[i] = line
        isUpdate = true
    }
    
    func splitKeyframe(with selectionCellAndLines: [(cell: Cell, geometry: Geometry)]) -> [(group: Group, cellItem: CellItem, geometry: Geometry)] {
        let scl: [(group: Group, cellItem: CellItem, geometry: Geometry)] = selectionCellAndLines.map {
            let gc = cut.groupAndCellItem(with: $0.cell)
            return (group: gc.group, cellItem: gc.cellItem, geometry: $0.geometry)
        }
        let isSplit = scl.reduce(false) {
            if cut.isInterpolatedKeyframe(with: $1.group) {
                sceneView.timeline.splitKeyframe(with: $1.group)
                return true
            } else {
                return $0
            }
        }
        return isSplit ? scl.map { ($0.group, $0.cellItem, $0.cellItem.cell.geometry) } : scl
    }
    
    private var moveDrawingTuple: (drawing: Drawing, lineIndexes: [Int], oldLines: [Line])?, moveCellTuples = [(group: Group, cellItem: CellItem, geometry: Geometry)](), moveOldPoint = CGPoint(), transformFirstWidth = 50.0.cf, moveTranformValueWidth = 60.0.cf, moveTransformValueHeight = 20.0.cf, moveTransformOldPoint = CGPoint(), moveEditing = false, transformType = Cut.TransformType.scaleXY
    override func move(with event: DragEvent) {
        move(with: event, isTransform: false)
    }
    func move(with event: DragEvent, isTransform: Bool) {
        let viewP = point(from: event)
        let p = convertToCut(viewP)
        switch event.sendType {
        case .begin:
            undoManager?.beginUndoGrouping()
            moveCellTuples = splitKeyframe(with: cut.selectionCellAndLines(with: p))
            let drawing = cut.editGroup.drawingItem.drawing
            moveDrawingTuple = !moveCellTuples.isEmpty ? nil : (drawing: drawing, lineIndexes: drawing.editLineIndexes, oldLines: drawing.lines)
            moveOldPoint = p
            moveTransformOldPoint = viewP
            moveEditing = true
        case .sending:
            if !(moveDrawingTuple?.lineIndexes.isEmpty ?? true) || !moveCellTuples.isEmpty {
                let affine = moveAffineTransformWith(viewPoint: viewP, point: p, viewOldPoint: moveTransformOldPoint, oldPoint: moveOldPoint, isTransform: isTransform)
                if let mdp = moveDrawingTuple {
                    var newLines = mdp.oldLines
                    for index in mdp.lineIndexes {
                        newLines.remove(at: index)
                        newLines.insert(mdp.oldLines[index].transformed(with: affine), at: index)
                    }
                    mdp.drawing.lines = newLines
                }
                for mcp in moveCellTuples {
                    mcp.cellItem.replaceGeometry(mcp.geometry.transformed(with: affine), at: mcp.group.editKeyframeIndex)
                }
            } else {
                screen?.tempNotAction()
            }
        case .end:
            if !(moveDrawingTuple?.lineIndexes.isEmpty ?? true) || !moveCellTuples.isEmpty {
                let affine = moveAffineTransformWith(viewPoint: viewP, point: p, viewOldPoint: moveTransformOldPoint, oldPoint: moveOldPoint, isTransform: isTransform)
                if let mdp = moveDrawingTuple {
                    var newLines = mdp.oldLines
                    for index in mdp.lineIndexes {
                        newLines[index] = mdp.oldLines[index].transformed(with: affine)
                    }
                    setLines(newLines, oldLines: mdp.oldLines, drawing: mdp.drawing, time: time)
                }
                for mcp in moveCellTuples {
                    setGeometry(mcp.geometry.transformed(with: affine), oldGeometry: mcp.geometry, at: mcp.group.editKeyframeIndex, in:mcp.cellItem, time: time)
                }
                transformType = .scaleXY
                moveDrawingTuple = nil
                moveCellTuples = []
                moveEditing = false
            } else {
                screen?.tempNotAction()
            }
            undoManager?.endUndoGrouping()
        }
        setNeedsDisplay()
    }
    private func moveAffineTransformWith(viewPoint: CGPoint, point: CGPoint, viewOldPoint: CGPoint, oldPoint: CGPoint, isTransform: Bool) -> CGAffineTransform {
        var affine: CGAffineTransform
        if isTransform {
            let dp = viewPoint - viewOldPoint
            transformType = cut.transformTypeWith(y: dp.y, height: moveTransformValueHeight)
            let value =  dp.x/moveTranformValueWidth
            affine = CGAffineTransform(translationX: oldPoint.x, y: oldPoint.y)
            switch transformType {
            case .scaleXY:
                affine = affine.scaledBy(x: 1 + value, y: 1 + value)
            case .scaleX:
                affine = affine.scaledBy(x: 1 + value, y: 1)
            case .scaleY:
                affine = affine.scaledBy(x: 1, y: 1 + value)
            case .rotate:
                affine = affine.rotated(by: value*(.pi)/2)
            case .skewX:
                affine.c = value
            case .skewY:
                affine.b = value
            }
            affine = affine.translatedBy(x: -oldPoint.x,  y: -oldPoint.y)
        } else {
            affine = CGAffineTransform(translationX: point.x - oldPoint.x, y: point.y - oldPoint.y)
        }
        return affine
    }
    
    private var warpDrawingTuple: (drawing: Drawing, lineIndexes: [Int], oldLines: [Line])?, warpCellTuples = [(group: Group, cellItem: CellItem, geometry: Geometry)](), oldWarpPoint = CGPoint(), minWarpDistance = 0.0.cf, maxWarpDistance = 0.0.cf
    override func warp(with event: DragEvent) {
        let p = convertToCut(point(from: event))
        switch event.sendType {
        case .begin:
            undoManager?.beginUndoGrouping()
            let drawing = cut.editGroup.drawingItem.drawing
            warpCellTuples = splitKeyframe(with: cut.selectionCellAndLines(with: p))
            warpDrawingTuple = !warpCellTuples.isEmpty ? nil : (drawing: drawing, lineIndexes: drawing.editLineIndexes, oldLines: drawing.lines)
            let mm = minMaxPointFrom(p)
            oldWarpPoint = p
            minWarpDistance = mm.minDistance
            maxWarpDistance = mm.maxDistance
        case .sending:
            if !(warpDrawingTuple?.lineIndexes.isEmpty ?? true) || !warpCellTuples.isEmpty {
                let dp = p - oldWarpPoint
                if let wdp = warpDrawingTuple {
                    var newLines = wdp.oldLines
                    for i in wdp.lineIndexes {
                        newLines[i] = wdp.oldLines[i].warpedWith(deltaPoint: dp, editPoint: oldWarpPoint, minDistance: minWarpDistance, maxDistance: maxWarpDistance)
                    }
                    wdp.drawing.lines = newLines
                }
                for wcp in warpCellTuples {
                    wcp.cellItem.replaceGeometry(wcp.geometry.warpedWith(deltaPoint: dp, editPoint: oldWarpPoint, minDistance: minWarpDistance, maxDistance: maxWarpDistance), at: wcp.group.editKeyframeIndex)
                }
            } else {
                screen?.tempNotAction()
            }
        case .end:
            if !(warpDrawingTuple?.lineIndexes.isEmpty ?? true) || !warpCellTuples.isEmpty {
                let dp = p - oldWarpPoint
                if let wdp = warpDrawingTuple {
                    var newLines = wdp.oldLines
                    for i in wdp.lineIndexes {
                        newLines[i] = wdp.oldLines[i].warpedWith(deltaPoint: dp, editPoint: oldWarpPoint, minDistance: minWarpDistance, maxDistance: maxWarpDistance)
                    }
                    setLines(newLines, oldLines: wdp.oldLines, drawing: wdp.drawing, time: time)
                }
                for wcp in warpCellTuples {
                    setGeometry(wcp.geometry.warpedWith(deltaPoint: dp, editPoint: oldWarpPoint, minDistance: minWarpDistance, maxDistance: maxWarpDistance), oldGeometry: wcp.geometry, at: wcp.group.editKeyframeIndex, in: wcp.cellItem, time: time)
                }
                warpDrawingTuple = nil
                warpCellTuples = []
            } else {
                screen?.tempNotAction()
            }
            undoManager?.endUndoGrouping()
        }
        setNeedsDisplay()
    }
    func minMaxPointFrom(_ p: CGPoint) -> (minDistance: CGFloat, maxDistance: CGFloat, minPoint: CGPoint, maxPoint: CGPoint) {
        var minDistance = CGFloat.infinity, maxDistance = 0.0.cf, minPoint = CGPoint(), maxPoint = CGPoint()
        func minMaxPointFrom(_ line: Line) {
            for control in line.controls {
                let d = hypot2(p.x - control.point.x, p.y - control.point.y)
                if d < minDistance {
                    minDistance = d
                    minPoint = control.point
                }
                if d > maxDistance {
                    maxDistance = d
                    maxPoint = control.point
                }
            }
        }
        if let wdp = warpDrawingTuple {
            for lineIndex in wdp.lineIndexes {
                minMaxPointFrom(wdp.drawing.lines[lineIndex])
            }
        }
        for wcp in warpCellTuples {
            for line in wcp.cellItem.cell.geometry.beziers {
                minMaxPointFrom(Line.with(line))
            }
        }
        return (minDistance, maxDistance, minPoint, maxPoint)
    }
    
    override func transform(with event: DragEvent) {
        move(with: event, isTransform: true)
    }
    
    weak var moveZCell: Cell? {
        didSet {
            setNeedsDisplay()
        }
    }
    func updateMoveZ(with point: CGPoint) {
        moveZCell = cut.rootCell.atPoint(point)
    }
    private var moveZOldPoint = CGPoint(), moveZCellTuple: (indexes: [Int], parent: Cell, oldChildren: [Cell])?, moveZMinDeltaIndex = 0, moveZMaxDeltaIndex = 0, moveZHeight = 2.0.cf
    private weak var moveZOldCell: Cell?
    override func moveZ(with event: DragEvent) {
        let p = point(from: event), cp = convertToCut(point(from: event))
        switch event.sendType {
        case .begin:
            let indicationCellsTuple = cut.indicationCellsTuple(with : cp)
            switch indicationCellsTuple.type {
            case .none:
                break
            case .indication:
                let cell = indicationCellsTuple.cells.first!
                cut.rootCell.depthFirstSearch(duplicate: false) { parent, aCell in
                    if cell === aCell, let index = parent.children.index(of: cell) {
                        moveZCellTuple = ([index], parent, parent.children)
                        moveZMinDeltaIndex = -index
                        moveZMaxDeltaIndex = parent.children.count - 1 - index
                    }
                }
            case .selection:
                let firstCell = indicationCellsTuple.cells.first!, cutAllSelectionCells = cut.allEditSelectionCellsWithNotEmptyGeometry
                var firstParent: Cell?
                cut.rootCell.depthFirstSearch(duplicate: false) { parent, cell in
                    if cell === firstCell {
                        firstParent = parent
                    }
                }
                if let firstParent = firstParent {
                    var indexes = [Int]()
                    cut.rootCell.depthFirstSearch(duplicate: false) { parent, cell in
                        if cutAllSelectionCells.contains(cell) && firstParent === parent, let index = parent.children.index(of: cell) {
                            indexes.append(index)
                        }
                    }
                    moveZCellTuple = (indexes, firstParent, firstParent.children)
                    moveZMinDeltaIndex = -(indexes.min() ?? 0)
                    moveZMaxDeltaIndex = firstParent.children.count - 1 - (indexes.max() ?? 0)
                } else {
                    moveZCellTuple = nil
                }
            }
            moveZOldPoint = p
        case .sending:
            if let moveZCellTuple = moveZCellTuple {
                let deltaIndex = Int((p.y - moveZOldPoint.y)/moveZHeight)
                var children = moveZCellTuple.oldChildren
                let indexes = moveZCellTuple.indexes.sorted {
                    deltaIndex < 0 ? $0 < $1 : $0 > $1
                }
                for i in indexes {
                    let cell = children[i]
                    children.remove(at: i)
                    children.insert(cell, at: (i + deltaIndex).clip(min: 0, max: moveZCellTuple.oldChildren.count - 1))
                }
                moveZCellTuple.parent.children = children
            } else {
                screen?.tempNotAction()
            }
        case .end:
            if let moveZCellTuple = moveZCellTuple {
                let deltaIndex = Int((p.y - moveZOldPoint.y)/moveZHeight)
                var children = moveZCellTuple.oldChildren
                let indexes = moveZCellTuple.indexes.sorted {
                    deltaIndex < 0 ? $0 < $1 : $0 > $1
                }
                for i in indexes {
                    let cell = children[i]
                    children.remove(at: i)
                    children.insert(cell, at: (i + deltaIndex).clip(min: 0, max: moveZCellTuple.oldChildren.count - 1))
                }
                setChildren(children, oldChildren: moveZCellTuple.oldChildren, inParent: moveZCellTuple.parent, time: time)
                self.moveZCellTuple = nil
            } else {
                screen?.tempNotAction()
            }
        }
        setNeedsDisplay()
    }
    private func setChildren(_ children: [Cell], oldChildren: [Cell], inParent parent: Cell, time: Int) {
        registerUndo { $0.setChildren(oldChildren, oldChildren: children, inParent: parent, time: $1) }
        self.time = time
        parent.children = children
        isUpdate = true
    }
    
    override func scroll(with event: ScrollEvent) {
        let newScrollPoint = CGPoint(x: viewTransform.position.x + event.scrollDeltaPoint.x, y: viewTransform.position.y - event.scrollDeltaPoint.y)
        if isPlaying && newScrollPoint != viewTransform.position {
            sceneView.timeline.stop()
        }
        viewTransform.position = newScrollPoint
    }
    var minScale = 0.00001.cf, blockScale = 1.0.cf, maxScale = 64.0.cf, correctionScale = 1.28.cf, correctionRotation = 1.0.cf/(4.2*(.pi))
    private var isBlockScale = false, oldScale = 0.0.cf
    override func zoom(with event: PinchEvent) {
        if isPlaying {
            sceneView.timeline.stop()
        }
        let scale = viewTransform.scale
        switch event.sendType {
        case .begin:
            oldScale = scale
            isBlockScale = false
        case .sending:
            if !isBlockScale {
                zoom(at: point(from: event)) {
                    let newScale = (scale*pow(event.magnification*correctionScale + 1, 2)).clip(min: minScale, max: maxScale)
                    if blockScale.isOver(old: scale, new: newScale) {
                        isBlockScale = true
                    }
                    viewTransform.scale = newScale
                }
            }
        case .end:
            if isBlockScale {
                zoom(at: point(from: event)) {
                    viewTransform.scale = blockScale
                }
            }
        }
    }
    var blockRotations: [CGFloat] = [-.pi, 0.0, .pi]
    private var isBlockRotation = false, blockRotation = 0.0.cf, oldRotation = 0.0.cf
    override func rotate(with event: RotateEvent) {
        if isPlaying {
            sceneView.timeline.stop()
        }
        let rotation = viewTransform.rotation
        switch event.sendType {
        case .begin:
            oldRotation = rotation
            isBlockRotation = false
        case .sending:
            if !isBlockRotation {
                zoom(at: point(from: event)) {
                    let oldRotation = rotation, newRotation = rotation + event.rotation*correctionRotation
                    for br in blockRotations {
                        if br.isOver(old: oldRotation, new: newRotation) {
                            isBlockRotation = true
                            blockRotation = br
                            break
                        }
                    }
                    viewTransform.rotation = newRotation.clipRotation
                }
            }
        case .end:
            if isBlockRotation {
                zoom(at: point(from: event)) {
                    viewTransform.rotation = blockRotation
                }
            }
        }
    }
    override func reset() {
        if viewTransform.isIdentity {
            screen?.tempNotAction()
        } else {
            viewTransform = ViewTransform()
        }
    }
    func zoom(at p: CGPoint, handler: () -> ()) {
        let viewPoint = convertToCut(p)
        handler()
        let newViewPoint = convertFromCut(viewPoint)
        viewTransform.position = viewTransform.position - (newViewPoint - p)
    }
}
