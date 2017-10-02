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
//Player（再生中のとき、isPlayingでの分岐を廃止してCanvasの上にPlayerを配置）
//Playerの分離（同時作業を可能にする）
//再生中のタイムライン表示更新
//再生中の時間移動

import Foundation
import QuartzCore
import AppKit.NSCursor
import AppKit.NSPasteboard
import AppKit.NSPasteboardItem

final class Player: View {
    
}

struct DrawInfo {
    let scale: CGFloat, cameraScale: CGFloat, reciprocalScale: CGFloat, reciprocalCameraScale: CGFloat, rotation: CGFloat
    init(scale: CGFloat = 1, cameraScale: CGFloat = 1, rotation: CGFloat = 0) {
        if scale == 0 || cameraScale == 0 {
            fatalError()
        }
        self.scale = scale
        self.cameraScale = cameraScale
        self.reciprocalScale = 1/scale
        self.reciprocalCameraScale = 1/cameraScale
        self.rotation = rotation
    }
}

final class Canvas: View {
    enum Quasimode {
        case none, movePoint, snapPoint, moveZ, move, warp, transform, rotate
    }
    
    weak var sceneEditor: SceneEditor!
    
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
            sceneEditor.timeline.setNeedsDisplay()
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
    var cursor = Canvas.strokeCurosr {
        didSet {
            screen?.updateCursor(with: currentPoint)
        }
    }
    override func cursor(with p: CGPoint) -> NSCursor {
        return cursor
    }
    
    override var cutQuasimode: Canvas.Quasimode {
        didSet {
            updateViewType()
        }
    }
    var materialEditorType = MaterialEditor.ViewType.none {
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
        } else if materialEditorType == .selection {
            viewType = .editMaterial
            cursor = Canvas.strokeCurosr
        } else if materialEditorType == .preview {
            viewType = .editingMaterial
            cursor = Canvas.strokeCurosr
        } else {
            switch cutQuasimode {
            case .none:
                viewType = .edit
                cursor = Canvas.strokeCurosr
                moveZCell = nil
                editPoint = nil
            case .movePoint:
                viewType = .editPoint
                cursor = NSCursor.arrow()
            case .snapPoint:
                viewType = .editSnap
                cursor = NSCursor.arrow()
            case .warp:
                viewType = .editWarp
                cursor = NSCursor.arrow()
            case .moveZ:
                viewType = .editMoveZ
                cursor = Defaults.upDownCursor
                moveZCell = cut.rootCell.atPoint(convertToCut(currentPoint))
            case .move:
                cursor = NSCursor.arrow()
            case .transform:
                viewType = .editTransform
                cursor = NSCursor.arrow()
            case .rotate:
                viewType = .editRotation
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
            sceneEditor.timeline.time = newValue
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
        sceneEditor.sceneEntity.isUpdatePreference = true
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
    
    override var indication: Bool {
        didSet {
            if !indication {
                indicationCellItem = nil
            }
        }
    }
    var indicationCellItem: CellItem? {
        didSet {
            if indicationCellItem != oldValue {
                setNeedsDisplay()
            }
        }
    }
    
    func updateEditView(with p : CGPoint) {
        switch viewType {
        case .edit, .editMaterial, .editingMaterial, .preview:
            break
        case .editPoint, .editSnap, .editWarp:
            updateEditPoint(with: p)
        case .editMoveZ:
            updateMoveZ(with: p)
            editPoint = nil
        case .editTransform:
            updateTransform(with: p)
            editPoint = nil
        case .editRotation:
            setNeedsDisplay()
            editPoint = nil
        }
        indicationCellItem = indication ? cut.cellItem(at: p, with: cut.editGroup) : nil
    }
    var editPoint: Cut.EditPoint? {
        didSet {
            setNeedsDisplay()
        }
    }
    func updateEditPoint(with point: CGPoint) {
        if let n = cut.nearest(at: point) {
            if let e = n.drawingEdit {
                editPoint = Cut.EditPoint(nearestLine: e.line, lines: [e.line], point: n.point)
            } else if let e = n.cellItemEdit {
                editPoint = Cut.EditPoint(nearestLine: e.geometry.lines[e.lineIndex], lines: [e.geometry.lines[e.lineIndex]], point: n.point)
            } else if n.drawingEditLineCap != nil || !n.cellItemEditLineCaps.isEmpty {
                if let nlc = n.bezierSortedResult(at: point) {
                    if let e = n.drawingEditLineCap {
                        editPoint = Cut.EditPoint(nearestLine: nlc.lineCap.line, lines: e.drawingCaps.map { $0.line } + n.cellItemEditLineCaps.reduce([Line]()) { $0 + $1.caps.map { $0.line } }, point: n.point)
                    } else {
                        editPoint = Cut.EditPoint(nearestLine: nlc.lineCap.line, lines: n.cellItemEditLineCaps.reduce([Line]()) { $0 + $1.caps.map { $0.line } }, point: n.point)
                    }
                } else {
                    editPoint = nil
                }
            }
        } else {
            editPoint = nil
        }
    }
    var transformEditorType = Cut.TransformEditorType.none, transformRotationBounds = CGRect()
    func updateTransform(with point: CGPoint) {
        setNeedsDisplay()
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
        func drawStroke(in ctx: CGContext) {
            if let strokeLine = strokeLine {
                cut.drawStrokeLine(strokeLine, lineColor: strokeLineColor, lineWidth: strokeLineWidth*drawInfo.reciprocalCameraScale, in: ctx)
            }
        }
        if viewType == .preview {
            if viewTransform.isFlippedHorizontal {
                ctx.flipHorizontal(by: cameraFrame.width)
            }
            cut.draw(sceneEditor.scene, with: drawInfo, in: ctx)
            drawStroke(in: ctx)
        } else {
            if let affine = scene.affineTransform {
                ctx.saveGState()
                ctx.concatenate(affine)
                cut.draw(sceneEditor.scene, viewType: viewType, editMaterial: viewType == .editMaterial ? nil : sceneEditor.materialEditor.material,
                         indicationCellItem: indicationCellItem, moveZCell: moveZCell, editPoint: editPoint, isShownPrevious: isShownPrevious, isShownNext: isShownNext, with: drawInfo, in: ctx)
                drawStroke(in: ctx)
                ctx.restoreGState()
            } else {
                cut.draw(sceneEditor.scene, viewType: viewType, editMaterial: viewType == .editMaterial ? nil : sceneEditor.materialEditor.material,
                         indicationCellItem: indicationCellItem, moveZCell: moveZCell, editPoint: editPoint, isShownPrevious: isShownPrevious, isShownNext: isShownNext, with: drawInfo, in: ctx)
                drawStroke(in: ctx)
            }
            drawEditInterfaces(in: ctx)
            drawCautionBorder(in: ctx)
        }
    }
    private func drawEditInterfaces(in ctx: CGContext) {
        switch viewType {
        case .editPoint, .editSnap: break
        case .editTransform: break
        default:
            break
        }
    }
    private func drawCautionBorder(in ctx: CGContext) {
        func drawBorderWith(bounds: CGRect, width: CGFloat, color: CGColor, in ctx: CGContext) {
            ctx.setFillColor(color)
            ctx.fill([
                CGRect(x: bounds.minX, y: bounds.minY, width: width, height: bounds.height),
                CGRect(x: bounds.minX + width, y: bounds.minY, width: bounds.width - width*2, height: width),
                CGRect(x: bounds.minX + width, y: bounds.maxY - width, width: bounds.width - width*2, height: width),
                CGRect(x: bounds.maxX - width, y: bounds.minY, width: width, height: bounds.height)
                ])
        }
        let borderWidth = 2.0.cf, bounds = self.bounds
        if viewTransform.rotation > .pi/2 || viewTransform.rotation < -.pi/2 {
            drawBorderWith(bounds: bounds, width: borderWidth*2, color: SceneDefaults.rotateCautionColor, in: ctx)
        }
    }
    
    private func registerUndo(_ handler: @escaping (Canvas, Int) -> Void) {
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
            let indicationCellsTuple = cut.indicationCellsTuple(with : convertToCut(currentPoint))
            if indicationCellsTuple.type != .none, let cellItem = cut.editGroup.cellItem(with: indicationCellsTuple.cells[0]) {
                setGeometry(Geometry(lines: copyDrawing.lines), oldGeometry: cellItem.cell.geometry, at: cut.editGroup.editKeyframeIndex, in: cellItem, time: time)
            } else {
                let drawing = cut.editGroup.drawingItem.drawing, oldCount = drawing.lines.count
                let lineIndexes = Set((0 ..< copyDrawing.lines.count).map { $0 + oldCount })
                setLines(drawing.lines + copyDrawing.lines, oldLines: drawing.lines, drawing: drawing, time: time)
                setSelectionLineIndexes(Array(Set(drawing.selectionLineIndexes).union(lineIndexes)), in: drawing, time: time)
            }
        } else if let data = pasteboard.data(forType: Cell.dataType), let copyRootCell = Cell.with(data) {
            var isChanged = false
            for copyCell in copyRootCell.allCells {
                for group in cut.groups {
                    for ci in group.cellItems {
                        if ci.cell.id == copyCell.id {
                            if sceneEditor.timeline.isInterpolatedKeyframe(with: group) {
                                sceneEditor.timeline.splitKeyframe(with: group)
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
                sceneEditor.materialEditor.paste(color, withSelection: selectionMaterial, useSelection: indicationCellsTuple.type == .selection)
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
                sceneEditor.materialEditor.paste(material, withSelection: selectionMaterial, useSelection: indicationCellsTuple.type == .selection)
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
            if sceneEditor.timeline.isInterpolatedKeyframe(with: cut.editGroup) {
                sceneEditor.timeline.splitKeyframe(with: cut.editGroup)
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
            
            if sceneEditor.timeline.isInterpolatedKeyframe(with: cut.editGroup) {
                sceneEditor.timeline.splitKeyframe(with: cut.editGroup)
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
                    if sceneEditor.timeline.isInterpolatedKeyframe(with: group) {
                        sceneEditor.timeline.splitKeyframe(with: group)
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
                    if sceneEditor.timeline.isInterpolatedKeyframe(with: group) {
                        sceneEditor.timeline.splitKeyframe(with: group)
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
    
    override func hide() {
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
    override func show() {
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
    override func splitColor() {
        let point = convertToCut(currentPoint)
        let ict = cut.indicationCellsTuple(with: point)
        if !ict.cells.isEmpty {
            sceneEditor.materialEditor.splitColor(with: ict.cells)
            highlight()
        } else {
            screen?.tempNotAction()
        }
    }
    override func splitOtherThanColor() {
        let point = convertToCut(currentPoint)
        let ict = cut.indicationCellsTuple(with: point)
        if !ict.cells.isEmpty {
            sceneEditor.materialEditor.splitOtherThanColor(with: ict.cells)
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
    
    override func moveCursor(with event: MoveEvent) {
        updateEditView(with: convertToCut(point(from: event)))
    }
    
    override func willDrag(with event: DragEvent) -> Bool {
        if isPlaying {
            sceneEditor.timeline.stop()
            return false
        } else {
            return true
        }
    }
    private var strokeLine: Line?, strokeLineColor = SceneDefaults.strokeLineColor, strokeLineWidth = SceneDefaults.strokeLineWidth
    private var strokeOldPoint = CGPoint(), strokeOldTime = TimeInterval(0), strokeOldLastBounds = CGRect(), strokeIsDrag = false, strokeControls: [Line.Control] = []
    private let strokeSplitAngle = 1.5*(.pi)/2.0.cf, strokeLowSplitAngle = 0.9*(.pi)/2.0.cf, strokeDistance = 1.2.cf, strokeTime = TimeInterval(0.1), strokeSlowDistance = 3.5.cf, strokeSlowTime = TimeInterval(0.25)
    override func drag(with event: DragEvent) {
        drag(with: event, lineWidth: strokeLineWidth, strokeDistance: strokeDistance, strokeTime: strokeTime)
    }
    override func slowDrag(with event: DragEvent) {
        drag(with: event, lineWidth: strokeLineWidth, strokeDistance: strokeSlowDistance, strokeTime: strokeSlowTime, splitAcuteAngle: false)
    }
    func drag(with event: DragEvent, lineWidth: CGFloat, strokeDistance: CGFloat, strokeTime: TimeInterval, splitAcuteAngle: Bool = true) {
        let p = convertToCut(point(from: event))
        switch event.sendType {
        case .begin:
            let firstControl = Line.Control(point: p, pressure: event.pressure)
            let line = Line(controls: [firstControl, firstControl])
            strokeLine = line
            strokeOldPoint = p
            strokeOldTime = event.time
            strokeOldLastBounds = line.strokeLastBoundingBox
            strokeIsDrag = false
            strokeControls = [firstControl]
        case .sending:
            if var line = strokeLine, p != strokeOldPoint {
                strokeIsDrag = true
                let ac = strokeControls.first!, bp = p, lc = strokeControls.last!, scale = drawInfo.scale
                let control = Line.Control(point: p, pressure: event.pressure)
                strokeControls.append(control)
                if splitAcuteAngle && line.controls.count >= 3 {
                    let c0 = line.controls[line.controls.count - 3], c1 = line.controls[line.controls.count - 2], c2 = lc
                    if c0.point != c1.point && c1.point != c2.point {
                        let dr = abs(CGPoint.differenceAngle(p0: c0.point, p1: c1.point, p2: c2.point))
                        if dr > strokeLowSplitAngle {
                            if dr > strokeSplitAngle {
                                line = line.withInsert(c1, at: line.controls.count - 1)
                                let  lastBounds = line.strokeLastBoundingBox
                                strokeLine = line
                                setNeedsDisplay(in: lastBounds.union(strokeOldLastBounds).inset(by: -lineWidth/2))
                                strokeOldLastBounds = lastBounds
                            } else {
                                let t = 1 - (dr - strokeLowSplitAngle)/strokeSplitAngle
                                let tp = CGPoint.linear(c1.point, c2.point, t: t)
                                if c1.point != tp {
                                    line = line.withInsert(Line.Control(point: tp, pressure: CGFloat.linear(c1.pressure, c2.pressure, t:  t)), at: line.controls.count - 1)
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
                                line = line.withInsert(lc, at: line.controls.count - 1)
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
                line = line.withReplaced(control, at: line.controls.count - 1)
                strokeLine = line
                let lastBounds = line.strokeLastBoundingBox
                setNeedsDisplay(in: lastBounds.union(strokeOldLastBounds).inset(by: -lineWidth/2))
                strokeOldLastBounds = lastBounds
                strokeOldPoint = p
            }
        case .end:
            if let line = strokeLine {
                strokeLine = nil
                if strokeIsDrag {
                    func lastRevisionLine(line: Line) -> Line {
                        if line.controls.count > 3 {
                            let ap = line.controls[line.controls.count - 3].point, bp = p, lp = line.controls[line.controls.count - 2].point, scale = drawInfo.scale
                            if !(lp.distanceWithLine(ap: ap, bp: bp)*scale > strokeDistance || event.time - strokeOldTime > strokeTime) {
                                return line.withRemoveControl(at: line.controls.count - 2)
                            }
                        }
                        return line
                    }
                    let newLine = lastRevisionLine(line: line)
                    addLine(newLine.withReplaced(Line.Control(point: p, pressure: newLine.controls.last!.pressure), at: newLine.controls.count - 1), in: cut.editGroup.drawingItem.drawing, time: time)
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
            if selectionCell.material.id != sceneEditor.materialEditor.material.id {
                setMaterial(selectionCell.material, time: time)
                isChanged = true
            }
        } else {
            if MaterialEditor.emptyMaterial != sceneEditor.materialEditor.material {
                setMaterial(MaterialEditor.emptyMaterial, time: time)
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
        registerUndo { [om = sceneEditor.materialEditor.material] in $0.setMaterial(om, time: $1) }
        self.time = time
        sceneEditor.materialEditor.material = material
    }
    private func setSelectionCellItems(_ cellItems: [CellItem], in group: Group, time: Int) {
        registerUndo { [os = group.selectionCellItems] in $0.setSelectionCellItems(os, in: group, time: $1) }
        self.time = time
        group.selectionCellItems = cellItems
        setNeedsDisplay()
        sceneEditor.timeline.setNeedsDisplay()
        isUpdate = true
    }
    
    override func addPoint() {
        let p = convertToCut(currentPoint)
        if let nearest = cut.nearestLine(at: p) {
            if let drawing = nearest.drawing {
                replaceLine(nearest.line.splited(at: nearest.pointIndex), oldLine: nearest.line, at: nearest.lineIndex, in: drawing, time: time)
                updateEditView(with: p)
            } else if let cellItem = nearest.cellItem {
                if sceneEditor.timeline.isInterpolatedKeyframe(with: cut.editGroup) {
                    sceneEditor.timeline.splitKeyframe(with: cut.editGroup)
                }
                setGeometries(Geometry.splitedGeometries(with: cellItem.keyGeometries, at: nearest.lineIndex, pointIndex: nearest.pointIndex), oldKeyGeometries: cellItem.keyGeometries, in: cellItem, cut.editGroup, time: time)
                updateEditView(with: p)
            }
        } else {
            screen?.tempNotAction()
        }
    }
    override func deletePoint() {
        let p = convertToCut(currentPoint)
        if let nearest = cut.nearestLine(at: p) {
            if let drawing = nearest.drawing {
                if nearest.line.controls.count > 2 {
                    replaceLine(nearest.line.removedControl(at: nearest.pointIndex), oldLine: nearest.line, at: nearest.lineIndex, in: drawing, time: time)
                } else {
                    removeLine(at: nearest.lineIndex, in: drawing, time: time)
                }
                updateEditView(with: p)
            } else if let cellItem = nearest.cellItem {
                if sceneEditor.timeline.isInterpolatedKeyframe(with: cut.editGroup) {
                    sceneEditor.timeline.splitKeyframe(with: cut.editGroup)
                }
                setGeometries(Geometry.geometriesWithRemoveControl(with: cellItem.keyGeometries, atLineIndex: nearest.lineIndex, index: nearest.pointIndex), oldKeyGeometries: cellItem.keyGeometries, in: cellItem, cut.editGroup, time: time)
                if cellItem.isEmptyKeyGeometries {
                    removeCellItems([cellItem])
                }
                updateEditView(with: p)
            }
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
    
    private var movePointNearest: Cut.Nearest?, movePointOldPoint = CGPoint()
    override func movePoint(with event: DragEvent) {
        let p = convertToCut(point(from: event))
        switch event.sendType {
        case .begin:
            undoManager?.beginUndoGrouping()
            if var nearest = cut.nearest(at: p) {
                if nearest.cellItemEdit != nil || !nearest.cellItemEditLineCaps.isEmpty {
                    if cut.isInterpolatedKeyframe(with: cut.editGroup) {
                        sceneEditor.timeline.splitKeyframe(with: cut.editGroup)
                        if let e = nearest.cellItemEdit {
                            nearest.cellItemEdit?.geometry = e.cellItem.cell.geometry
                        } else {
                            nearest.cellItemEditLineCaps = nearest.cellItemEditLineCaps.map { ($0.cellItem, $0.cellItem.cell.geometry, $0.caps) }
                        }
                    }
                }
                bezierSortedResult = nearest.bezierSortedResult(at: p)
                movePointNearest = nearest
            } else {
                screen?.tempNotAction()
            }
            movePointOldPoint = p
            updateEditView(with: p)
        case .sending:
            let dp = p - movePointOldPoint
            if let nearest = movePointNearest {
                if nearest.drawingEdit != nil || nearest.cellItemEdit != nil {
                    if let e = nearest.drawingEdit {
                        var control = e.line.controls[e.pointIndex]
                        control.point = e.line.editPoint(withEditCenterPoint: nearest.point + dp, at: e.pointIndex)
                        e.drawing.lines[e.lineIndex] = e.line.withReplaced(control, at: e.pointIndex)
                        editPoint = Cut.EditPoint(nearestLine: e.drawing.lines[e.lineIndex], lines: [e.drawing.lines[e.lineIndex]], point: nearest.point + dp)
                    } else if let e = nearest.cellItemEdit {
                        var control = e.geometry.lines[e.lineIndex].controls[e.pointIndex]
                        control.point = e.geometry.lines[e.lineIndex].editPoint(withEditCenterPoint: nearest.point + dp, at: e.pointIndex)
                        e.cellItem.cell.geometry = Geometry(lines: e.geometry.lines.withReplaced(e.geometry.lines[e.lineIndex].withReplaced(control, at: e.pointIndex).autoPressure(), at: e.lineIndex))
                        editPoint = Cut.EditPoint(nearestLine: e.cellItem.cell.geometry.lines[e.lineIndex], lines: [e.cellItem.cell.geometry.lines[e.lineIndex]], point: nearest.point + dp)
                    }
                } else {
                    var editPointLines = [Line]()
                    if let e = nearest.drawingEditLineCap {
                        var newLines = e.drawing.lines
                        for cap in e.drawingCaps {
                            var control = cap.isFirst ? cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
                            control.point = control.point + dp
                            newLines[cap.lineIndex] = newLines[cap.lineIndex].withReplaced(control, at: cap.isFirst ? 0 : cap.line.controls.count - 1)
                        }
                        e.drawing.lines = newLines
                        editPointLines = e.drawingCaps.map { newLines[$0.lineIndex] }
                    }
                    for editLineCap in nearest.cellItemEditLineCaps {
                        var newLines = editLineCap.geometry.lines
                        for cap in editLineCap.caps {
                            var control = cap.isFirst ? cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
                            control.point = control.point + dp
                            newLines[cap.lineIndex] = newLines[cap.lineIndex].withReplaced(control, at: cap.isFirst ? 0 : cap.line.controls.count - 1).autoPressure()
                        }
                        editLineCap.cellItem.cell.geometry = Geometry(lines: newLines)
                        editPointLines += editLineCap.caps.map { newLines[$0.lineIndex] }
                    }
                    if let b = bezierSortedResult {
                        if let cellItem = b.cellItem {
                            editPoint = Cut.EditPoint(nearestLine: cellItem.cell.geometry.lines[b.lineCap.lineIndex], lines: Array(Set(editPointLines)), point: nearest.point + dp)
                        } else if let drawing = b.drawing {
                            editPoint = Cut.EditPoint(nearestLine: drawing.lines[b.lineCap.lineIndex], lines: Array(Set(editPointLines)), point: nearest.point + dp)
                        }
                    }
                }
            } else {
                screen?.tempNotAction()
            }
        case .end:
            let dp = p - movePointOldPoint
            if let nearest = movePointNearest {
                if nearest.drawingEdit != nil || nearest.cellItemEdit != nil {
                    if let e = nearest.drawingEdit {
                        var control = e.line.controls[e.pointIndex]
                        control.point = e.line.editPoint(withEditCenterPoint: nearest.point + dp, at: e.pointIndex)
                        replaceLine(e.line.withReplaced(control, at: e.pointIndex), oldLine: e.line, at: e.lineIndex, in: e.drawing, time: time)
                    } else if let e = nearest.cellItemEdit {
                        var control = e.geometry.lines[e.lineIndex].controls[e.pointIndex]
                        control.point = e.geometry.lines[e.lineIndex].editPoint(withEditCenterPoint: nearest.point + dp, at: e.pointIndex)
                        setGeometry(Geometry(lines: e.geometry.lines.withReplaced(e.geometry.lines[e.lineIndex].withReplaced(control, at: e.pointIndex).autoPressure(), at: e.lineIndex)), oldGeometry: e.geometry, at: cut.editGroup.editKeyframeIndex, in: e.cellItem, time: time)
                    }
                } else {
                    if let e = nearest.drawingEditLineCap {
                        var newLines = e.drawing.lines
                        for cap in e.drawingCaps {
                            var control = cap.isFirst ? cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
                            control.point = control.point + dp
                            newLines[cap.lineIndex] = newLines[cap.lineIndex].withReplaced(control, at: cap.isFirst ? 0 : cap.line.controls.count - 1)
                        }
                        setLines(newLines, oldLines: e.lines, drawing: e.drawing, time: time)
                    }
                    for editLineCap in nearest.cellItemEditLineCaps {
                        var newLines = editLineCap.geometry.lines
                        for cap in editLineCap.caps {
                            var control = cap.isFirst ? cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
                            control.point = control.point + dp
                            newLines[cap.lineIndex] = newLines[cap.lineIndex].withReplaced(control, at: cap.isFirst ? 0 : cap.line.controls.count - 1).autoPressure()
                        }
                        setGeometry(Geometry(lines: newLines), oldGeometry: editLineCap.geometry, at: cut.editGroup.editKeyframeIndex, in: editLineCap.cellItem, time: time)
                    }
                }
                updateEditView(with: p)
                movePointNearest = nil
                bezierSortedResult = nil
            } else {
                screen?.tempNotAction()
            }
            undoManager?.endUndoGrouping()
        }
        setNeedsDisplay()
    }
    private func replaceLine(_ line: Line, oldLine: Line, at i: Int, in drawing: Drawing, time: Int) {
        registerUndo { $0.replaceLine(oldLine, oldLine: line, at: i, in: drawing, time: $1) }
        self.time = time
        drawing.lines[i] = line
        isUpdate = true
    }
    
    private let snapPointSnapDistance = 8.0.cf
    private var bezierSortedResult: Cut.Nearest.BezierSortedResult?
    override func snapPoint(with event: DragEvent) {
        let snapD = snapPointSnapDistance/drawInfo.scale
        let p = convertToCut(point(from: event))
        switch event.sendType {
        case .begin:
            undoManager?.beginUndoGrouping()
            if var nearest = cut.nearest(at: p)?.bezierSortedResult(at: p) {
                if let cellItem = nearest.cellItem {
                    if cut.isInterpolatedKeyframe(with: cut.editGroup) {
                        sceneEditor.timeline.splitKeyframe(with: cut.editGroup)
                        nearest = Cut.Nearest.BezierSortedResult(drawing: nil, cellItem: cellItem, geometry: cellItem.cell.geometry, lineCap: nearest.lineCap, point: nearest.point)
                    }
                }
                bezierSortedResult = nearest
            } else {
                screen?.tempNotAction()
            }
            movePointOldPoint = p
            updateEditView(with: p)
        case .sending:
            let dp = p - movePointOldPoint
            if let nearest = bezierSortedResult {
                if let drawing = nearest.drawing {
                    let pointIndex = nearest.lineCap.isFirst ? 0 : nearest.lineCap.line.controls.count - 1
                    var control = nearest.lineCap.line.controls[pointIndex]
                    control.point = cut.editGroup.snapPoint(nearest.point + dp, with: nearest, snapDistance: snapD)
                    drawing.lines[nearest.lineCap.lineIndex] = nearest.lineCap.line.withReplaced(control, at: pointIndex)
                    editPoint = Cut.EditPoint(nearestLine: drawing.lines[nearest.lineCap.lineIndex], lines: drawing.lines, point: control.point)
                } else if let cellItem = nearest.cellItem, let geometry = nearest.geometry {
                    let pointIndex = nearest.lineCap.isFirst ? 0 : nearest.lineCap.line.controls.count - 1
                    var control = geometry.lines[nearest.lineCap.lineIndex].controls[pointIndex]
                    control.point = cut.editGroup.snapPoint(nearest.point + dp, with: nearest, snapDistance: snapD)
                    cellItem.cell.geometry = Geometry(lines: geometry.lines.withReplaced(nearest.lineCap.line.withReplaced(control, at: pointIndex), at: nearest.lineCap.lineIndex))
                    editPoint = Cut.EditPoint(nearestLine: cellItem.cell.geometry.lines[nearest.lineCap.lineIndex], lines: cellItem.cell.geometry.lines, point: control.point)
                }
            } else {
                screen?.tempNotAction()
            }
        case .end:
            let dp = p - movePointOldPoint
            if let nearest = bezierSortedResult {
                if let drawing = nearest.drawing {
                    let pointIndex = nearest.lineCap.isFirst ? 0 : nearest.lineCap.line.controls.count - 1
                    var control = nearest.lineCap.line.controls[pointIndex]
                    control.point = cut.editGroup.snapPoint(nearest.point + dp, with: nearest, snapDistance: snapD)
                    replaceLine(nearest.lineCap.line.withReplaced(control, at: pointIndex), oldLine: nearest.lineCap.line, at: nearest.lineCap.lineIndex, in: drawing, time: time)
                } else if let cellItem = nearest.cellItem, let geometry = nearest.geometry {
                    let pointIndex = nearest.lineCap.isFirst ? 0 : nearest.lineCap.line.controls.count - 1
                    var control = geometry.lines[nearest.lineCap.lineIndex].controls[pointIndex]
                    control.point = cut.editGroup.snapPoint(nearest.point + dp, with: nearest, snapDistance: snapD)
                    setGeometry(Geometry(lines: geometry.lines.withReplaced(nearest.lineCap.line.withReplaced(control, at: pointIndex), at: nearest.lineCap.lineIndex)), oldGeometry: geometry, at: cut.editGroup.editKeyframeIndex, in: cellItem, time: time)
                }
                bezierSortedResult = nil
            } else {
                screen?.tempNotAction()
            }
            undoManager?.endUndoGrouping()
        }
        setNeedsDisplay()
    }
    private func setControl(_ control: Line.Control, oldControl: Line.Control, at i: Int, lineIndex li: Int, drawing: Drawing, time: Int) {
        registerUndo { $0.setControl(oldControl, oldControl: control, at: i, lineIndex: li, drawing: drawing, time: $1) }
        self.time = time
        drawing.lines[li] = drawing.lines[li].withReplaced(control, at: i)
        isUpdate = true
    }
    
    private var warpPointNearest: Cut.Nearest?, warpPointOldPoint = CGPoint(), isWarpCell = false
    override func warpLine(with event: DragEvent) {
        let p = convertToCut(point(from: event))
        switch event.sendType {
        case .begin:
            undoManager?.beginUndoGrouping()
            if var nearest = cut.nearest(at: p) {
                if nearest.cellItemEdit != nil || !nearest.cellItemEditLineCaps.isEmpty {
                    if cut.isInterpolatedKeyframe(with: cut.editGroup) {
                        sceneEditor.timeline.splitKeyframe(with: cut.editGroup)
                        if let e = nearest.cellItemEdit {
                            nearest.cellItemEdit?.geometry = e.cellItem.cell.geometry
                        } else {
                            nearest.cellItemEditLineCaps = nearest.cellItemEditLineCaps.map { ($0.cellItem, $0.cellItem.cell.geometry, $0.caps) }
                        }
                    }
                }
                warpPointNearest = nearest
                bezierSortedResult = nearest.bezierSortedResult(at: p)
                
                if nearest.cellItemEdit != nil || !nearest.cellItemEditLineCaps.isEmpty {
                    if let cellItem = nearest.cellItemEdit?.cellItem {
                        if cut.editGroup.containsSelection(cellItem.cell) {
                            warp(with: event, nearest: nearest)
                            isWarpCell = true
                            return
                        }
                    } else {
                        for cap in nearest.cellItemEditLineCaps {
                            if cut.editGroup.containsSelection(cap.cellItem.cell) {
                                warp(with: event, nearest: nearest)
                                isWarpCell = true
                                return
                            }
                        }
                    }
                } else if let e = nearest.drawingEdit {
                    if cut.editGroup.drawingItem.drawing.selectionLineIndexes.contains(e.lineIndex) {
                        warp(with: event, nearest: nearest)
                        isWarpCell = true
                        return
                    }
                } else if let e = nearest.drawingEditLineCap {
                    for cap in e.drawingCaps {
                        if cut.editGroup.drawingItem.drawing.selectionLineIndexes.contains(cap.lineIndex) {
                            warp(with: event, nearest: nearest)
                            isWarpCell = true
                            return
                        }
                    }
                }
                isWarpCell = false
            } else {
                screen?.tempNotAction()
            }
            warpPointOldPoint = p
            updateEditView(with: p)
        case .sending:
            let dp = p - warpPointOldPoint
            if let nearest = warpPointNearest {
                if isWarpCell {
                    warp(with: event, nearest: nearest)
                    return
                }
                if nearest.drawingEdit != nil || nearest.cellItemEdit != nil {
                    if let e = nearest.drawingEdit {
                        let control = e.line.controls[e.pointIndex]
                        let ndp = e.drawing.lines[e.lineIndex].editPoint(withEditCenterPoint: nearest.point + dp, at: e.pointIndex) - control.point
                        e.drawing.lines[e.lineIndex] = e.line.warpedWith(deltaPoint: ndp, at: e.pointIndex)
                        editPoint = Cut.EditPoint(nearestLine: e.drawing.lines[e.lineIndex], lines: [e.drawing.lines[e.lineIndex]], point: nearest.point + dp)
                    } else if let e = nearest.cellItemEdit {
                        let control = e.geometry.lines[e.lineIndex].controls[e.pointIndex]
                        let ndp = e.cellItem.cell.geometry.lines[e.lineIndex].editPoint(withEditCenterPoint: nearest.point + dp, at: e.pointIndex) - control.point
                        e.cellItem.cell.geometry = Geometry(lines: e.geometry.lines.withReplaced(e.geometry.lines[e.lineIndex].warpedWith(deltaPoint: ndp, at: e.pointIndex).autoPressure(), at: e.lineIndex))
                        editPoint = Cut.EditPoint(nearestLine: e.cellItem.cell.geometry.lines[e.lineIndex], lines: [e.cellItem.cell.geometry.lines[e.lineIndex]], point: nearest.point + dp)
                    }
                } else {
                    var editPointLines = [Line]()
                    if let e = nearest.drawingEditLineCap {
                        var newLines = e.drawing.lines
                        for cap in e.drawingCaps {
                            newLines[cap.lineIndex] = cap.line.warpedWith(deltaPoint: dp, isFirst: cap.isFirst).autoPressure()
                        }
                        e.drawing.lines = newLines
                        editPointLines = e.drawingCaps.map { newLines[$0.lineIndex] }
                    }
                    for editLineCap in nearest.cellItemEditLineCaps {
                        var newLines = editLineCap.geometry.lines
                        for cap in editLineCap.caps {
                            newLines[cap.lineIndex] = cap.line.warpedWith(deltaPoint: dp, isFirst: cap.isFirst).autoPressure()
                        }
                        editLineCap.cellItem.cell.geometry = Geometry(lines: newLines)
                        editPointLines += editLineCap.caps.map { newLines[$0.lineIndex] }
                    }
                    if let b = bezierSortedResult {
                        if let cellItem = b.cellItem {
                            editPoint = Cut.EditPoint(nearestLine: cellItem.cell.geometry.lines[b.lineCap.lineIndex], lines: Array(Set(editPointLines)), point: nearest.point + dp)
                        } else if let drawing = b.drawing {
                            editPoint = Cut.EditPoint(nearestLine: drawing.lines[b.lineCap.lineIndex], lines: Array(Set(editPointLines)), point: nearest.point + dp)
                        }
                    }
                }
            } else {
                screen?.tempNotAction()
            }
        case .end:
            let dp = p - warpPointOldPoint
            if let nearest = warpPointNearest {
                if isWarpCell {
                    warp(with: event, nearest: nearest)
                    return
                }
                if nearest.drawingEdit != nil || nearest.cellItemEdit != nil {
                    if let e = nearest.drawingEdit {
                        let control = e.line.controls[e.pointIndex]
                        let ndp = e.drawing.lines[e.lineIndex].editPoint(withEditCenterPoint: nearest.point + dp, at: e.pointIndex) - control.point
                        replaceLine(e.line.warpedWith(deltaPoint: ndp, at: e.pointIndex), oldLine: e.line, at: e.lineIndex, in: e.drawing, time: time)
                    } else if let e = nearest.cellItemEdit {
                        let control = e.geometry.lines[e.lineIndex].controls[e.pointIndex]
                        let ndp = e.cellItem.cell.geometry.lines[e.lineIndex].editPoint(withEditCenterPoint: nearest.point + dp, at: e.pointIndex) - control.point
                        setGeometry(Geometry(lines: e.geometry.lines.withReplaced(e.geometry.lines[e.lineIndex].warpedWith(deltaPoint: ndp, at: e.pointIndex).autoPressure(), at: e.lineIndex)), oldGeometry: e.geometry, at: cut.editGroup.editKeyframeIndex, in: e.cellItem, time: time)
                    }
                } else {
                    if let e = nearest.drawingEditLineCap {
                        var newLines = e.drawing.lines
                        for cap in e.drawingCaps {
                            newLines[cap.lineIndex] = cap.line.warpedWith(deltaPoint: dp, isFirst: cap.isFirst).autoPressure()
                        }
                        setLines(newLines, oldLines: e.lines, drawing: e.drawing, time: time)
                    }
                    for editLineCap in nearest.cellItemEditLineCaps {
                        var newLines = editLineCap.geometry.lines
                        for cap in editLineCap.caps {
                            newLines[cap.lineIndex] = cap.line.warpedWith(deltaPoint: dp, isFirst: cap.isFirst).autoPressure()
                        }
                        setGeometry(Geometry(lines: newLines), oldGeometry: editLineCap.geometry, at: cut.editGroup.editKeyframeIndex, in: editLineCap.cellItem, time: time)
                    }
                }
                updateEditView(with: p)
                warpPointNearest = nil
                bezierSortedResult = nil
            } else {
                screen?.tempNotAction()
            }
            undoManager?.endUndoGrouping()
        }
        setNeedsDisplay()
    }
    private var warpDrawingTuple: (drawing: Drawing, lineIndexes: [Int], oldLines: [Line])?, warpCellTuples = [(group: Group, cellItem: CellItem, geometry: Geometry)](), oldWarpPoint = CGPoint(), minWarpDistance = 0.0.cf, maxWarpDistance = 0.0.cf
    func warp(with event: DragEvent, nearest: Cut.Nearest) {
        let p = convertToCut(point(from: event))
        switch event.sendType {
        case .begin:
            let drawing = cut.editGroup.drawingItem.drawing
            warpCellTuples = splitKeyframe(with: cut.editGroup.selectionCellItems.map { ($0.cell, $0.cell.geometry) })
            warpDrawingTuple = !warpCellTuples.isEmpty ? nil : (drawing: drawing, lineIndexes: drawing.editLineIndexes, oldLines: drawing.lines)
            let mm = minMaxPointFrom(nearest.point)
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
                
                if nearest.drawingEdit != nil || nearest.cellItemEdit != nil {
                    if let e = nearest.drawingEdit {
                        editPoint = Cut.EditPoint(nearestLine: e.drawing.lines[e.lineIndex], lines: [e.drawing.lines[e.lineIndex]], point: nearest.point + dp)
                    } else if let e = nearest.cellItemEdit {
                        editPoint = Cut.EditPoint(nearestLine: e.cellItem.cell.geometry.lines[e.lineIndex], lines: [e.cellItem.cell.geometry.lines[e.lineIndex]], point: nearest.point + dp)
                    }
                } else {
                    var editPointLines = [Line]()
                    if let e = nearest.drawingEditLineCap {
                        editPointLines = e.drawingCaps.map { e.drawing.lines[$0.lineIndex] }
                    }
                    for editLineCap in nearest.cellItemEditLineCaps {
                        editPointLines += editLineCap.caps.map { editLineCap.cellItem.cell.geometry.lines[$0.lineIndex] }
                    }
                    if let b = bezierSortedResult {
                        if let cellItem = b.cellItem {
                            editPoint = Cut.EditPoint(nearestLine: cellItem.cell.geometry.lines[b.lineCap.lineIndex], lines: Array(Set(editPointLines)), point: nearest.point + dp)
                        } else if let drawing = b.drawing {
                            editPoint = Cut.EditPoint(nearestLine: drawing.lines[b.lineCap.lineIndex], lines: Array(Set(editPointLines)), point: nearest.point + dp)
                        }
                    }
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
                let d = hypot²(p.x - control.point.x, p.y - control.point.y)
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
            for line in wcp.cellItem.cell.geometry.lines {
                minMaxPointFrom(line)
            }
        }
        return (minDistance, maxDistance, minPoint, maxPoint)
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
    
    func splitKeyframe(with selectionCellAndLines: [(cell: Cell, geometry: Geometry)]) -> [(group: Group, cellItem: CellItem, geometry: Geometry)] {
        let scl: [(group: Group, cellItem: CellItem, geometry: Geometry)] = selectionCellAndLines.map {
            let gc = cut.groupAndCellItem(with: $0.cell)
            return (group: gc.group, cellItem: gc.cellItem, geometry: $0.geometry)
        }
        let isSplit = scl.reduce(false) {
            if cut.isInterpolatedKeyframe(with: $1.group) {
                sceneEditor.timeline.splitKeyframe(with: $1.group)
                return true
            } else {
                return $0
            }
        }
        return isSplit ? scl.map { ($0.group, $0.cellItem, $0.cellItem.cell.geometry) } : scl
    }
    
    private var moveDrawingTuple: (drawing: Drawing, lineIndexes: [Int], oldLines: [Line])?, moveCellTuples = [(group: Group, cellItem: CellItem, geometry: Geometry)]()
    private var transformBounds = CGRect(), transformType = Cut.TransformType.minXMinY
    private var moveOldPoint = CGPoint(), moveTransformOldPoint = CGPoint()
    enum TransformEditType {
        case move, transform, rotate
    }
    override func move(with event: DragEvent) {
        move(with: event, type: .move)
    }
    func move(with event: DragEvent,type: TransformEditType) {
        let viewP = point(from: event)
        let p = convertToCut(viewP)
        func affineTransform() -> CGAffineTransform {
            if type != .move {
                return cut.affineTransform(with: transformType, bounds: transformBounds, p: viewP, oldP: moveTransformOldPoint, viewAffineTransform: viewAffineTransform)
            } else {
                return CGAffineTransform(translationX: p.x - moveOldPoint.x, y: p.y - moveOldPoint.y)
            }
        }
        switch event.sendType {
        case .begin:
            undoManager?.beginUndoGrouping()
            if type != .move {
                if let nearest = cut.nearestTransformType(at: viewP, viewAffineTransform: viewAffineTransform, isRotation: type == .rotate) {
                    transformType = nearest.type
                    transformBounds = nearest.bounds
                    if let drawingTuple = nearest.edit.drawingTuple {
                        moveDrawingTuple = drawingTuple
                    } else {
                        moveCellTuples = splitKeyframe(with: nearest.edit.cellTuples.map { ($0.cellItem.cell, $0.geometry) })
                    }
                }
            } else {
                moveCellTuples = splitKeyframe(with: cut.selectionCellAndLines(with: p))
                let drawing = cut.editGroup.drawingItem.drawing
                moveDrawingTuple = !moveCellTuples.isEmpty ? nil : (drawing: drawing, lineIndexes: drawing.editLineIndexes, oldLines: drawing.lines)
            }
            moveOldPoint = p
            moveTransformOldPoint = viewP
        case .sending:
            if !(moveDrawingTuple?.lineIndexes.isEmpty ?? true) || !moveCellTuples.isEmpty {
                let affine = affineTransform()
                if let mdp = moveDrawingTuple {
                    var newLines = mdp.oldLines
                    for index in mdp.lineIndexes {
                        newLines.remove(at: index)
                        newLines.insert(mdp.oldLines[index].applying(affine), at: index)
                    }
                    mdp.drawing.lines = newLines
                }
                for mcp in moveCellTuples {
                    mcp.cellItem.replaceGeometry(mcp.geometry.applying(affine), at: mcp.group.editKeyframeIndex)
                }
            } else {
                screen?.tempNotAction()
            }
        case .end:
            if !(moveDrawingTuple?.lineIndexes.isEmpty ?? true) || !moveCellTuples.isEmpty {
                let affine = affineTransform()
                if let mdp = moveDrawingTuple {
                    var newLines = mdp.oldLines
                    for index in mdp.lineIndexes {
                        newLines[index] = mdp.oldLines[index].applying(affine)
                    }
                    setLines(newLines, oldLines: mdp.oldLines, drawing: mdp.drawing, time: time)
                }
                for mcp in moveCellTuples {
                    setGeometry(mcp.geometry.applying(affine), oldGeometry: mcp.geometry, at: mcp.group.editKeyframeIndex, in:mcp.cellItem, time: time)
                }
                moveDrawingTuple = nil
                moveCellTuples = []
            } else {
                screen?.tempNotAction()
            }
            undoManager?.endUndoGrouping()
        }
        setNeedsDisplay()
    }
    override func transform(with event: DragEvent) {
        move(with: event, type: .transform)
    }
    override func rotateTransform(with event: DragEvent) {
        move(with: event, type: .rotate)
    }
    
    override func scroll(with event: ScrollEvent) {
        let newScrollPoint = CGPoint(x: viewTransform.position.x + event.scrollDeltaPoint.x, y: viewTransform.position.y - event.scrollDeltaPoint.y)
        if isPlaying && newScrollPoint != viewTransform.position {
            sceneEditor.timeline.stop()
        }
        viewTransform.position = newScrollPoint
    }
    var minScale = 0.00001.cf, blockScale = 1.0.cf, maxScale = 64.0.cf, correctionScale = 1.28.cf, correctionRotation = 1.0.cf/(4.2*(.pi))
    private var isBlockScale = false, oldScale = 0.0.cf
    override func zoom(with event: PinchEvent) {
        if isPlaying {
            sceneEditor.timeline.stop()
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
            sceneEditor.timeline.stop()
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
