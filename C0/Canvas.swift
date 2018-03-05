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
 - Z移動を廃止してセルツリー表示を作成、セルクリップや全てのロック解除などのコマンドを廃止
 - 補間区間上の選択修正
 - スクロール後の元の位置までの距離を表示
 - sceneを取り除く
 */
final class Canvas: DrawLayer, Respondable {
    static let name = Localization(english: "Canvas", japanese: "キャンバス")
    
    let player = Player()
    
    var scene = Scene() {
        didSet {
            player.updateChildren()
            cutItem = scene.editCutItem
            player.scene = scene
            materialEditor.material = scene.editMaterial
            updateScreenTransform()
            updateEditCellBindingLine()
        }
    }
    var sceneDataModel: DataModel?
    var cutItem = CutItem() {
        didSet {
            cutItem.read()
            setNeedsDisplay()
        }
    }
    var cut: Cut {
        return cutItem.cut
    }
    
    var setContentsScaleHandler: ((Canvas, CGFloat) -> ())?
    override var contentsScale: CGFloat {
        didSet {
            player.contentsScale = contentsScale
            setContentsScaleHandler?(self, contentsScale)
        }
    }
    
    override init() {
        super.init()
        drawBlock = { [unowned self] ctx in
            self.draw(in: ctx)
        }
        player.endPlayHandler = { [unowned self] _ in self.isOpenedPlayer = false }
        cellEditor.copyHandler = { [unowned self] _, _ in self.copyCell() }
    }
    
    var cursor = Cursor.stroke
    
    override var bounds: CGRect {
        didSet {
            player.frame = bounds
            updateScreenTransform()
        }
    }
    
    var isOpenedPlayer = false {
        didSet {
            guard isOpenedPlayer != oldValue else {
                return
            }
            if isOpenedPlayer {
                append(child: player)
            } else {
                player.removeFromParent()
            }
        }
    }
    
    enum MaterialViewType {
        case none, selection, preview
    }
    var materialEditorType = MaterialViewType.none {
        didSet {
            updateViewType()
            editCellLineLayer.isHidden = materialEditorType == .preview
        }
    }
    
    override var editQuasimode: EditQuasimode {
        didSet {
            switch editQuasimode {
            case .move, .lassoErase:
                cursor = .stroke
            default:
                cursor = .arrow
            }
            updateViewType()
            updateEditView(with: convertToCurrentLocal(cursorPoint))
        }
    }
    private func updateViewType() {
        if materialEditorType == .selection {
            viewType = .editMaterial
        } else if materialEditorType == .preview {
            viewType = .changingMaterial
        } else {
            switch editQuasimode {
            case .stroke:
                viewType = .edit
            case .movePoint:
                viewType = .editPoint
            case .moveVertex:
                viewType = .editVertex
            case .moveZ:
                viewType = .editMoveZ
            case .move:
                viewType = .edit
            case .warp:
                viewType = .editWarp
            case .transform:
                viewType = .editTransform
            case .select:
                viewType = .editSelection
            case .deselect:
                viewType = .editDeselection
            case .lassoErase:
                viewType = .editDeselection
            }
        }
    }
    var viewType = Cut.ViewType.edit {
        didSet {
            if viewType != oldValue {
                setNeedsDisplay()
            }
        }
    }
    func updateEditView(with p: CGPoint) {
        switch viewType {
        case .edit, .editMaterial, .changingMaterial,
             .preview, .editSelection, .editDeselection:
            editZ = nil
            editPoint = nil
            editTransform = nil
        case .editPoint, .editVertex:
            editZ = nil
            updateEditPoint(with: p)
            editTransform = nil
        case .editMoveZ:
            updateEditZ(with: p)
            editPoint = nil
            editTransform = nil
        case .editWarp:
            editZ = nil
            editPoint = nil
            updateEditTransform(with: p)
        case .editTransform:
            editZ = nil
            editPoint = nil
            updateEditTransform(with: p)
        }
        let cellsTuple = cut.editNode.indicatedCellsTuple(with: p,
                                                           reciprocalScale: scene.reciprocalScale)
        indicatedCellItem = cellsTuple.cellItems.first
        if indicatedCellItem != nil && cut.editNode.editTrack.selectionCellItems.count > 1 {
            indicatedPoint = p
            setNeedsDisplay()
        }
    }
    var screenTransform = CGAffineTransform.identity
    func updateScreenTransform() {
        screenTransform = CGAffineTransform(translationX: bounds.midX, y: bounds.midY)
    }
    
    var editPoint: Node.EditPoint? {
        didSet {
            if editPoint != oldValue {
                setNeedsDisplay()
            }
        }
    }
    func updateEditPoint(with point: CGPoint) {
        if let n = cut.editNode.nearest(at: point, isVertex: viewType == .editVertex) {
            if let e = n.drawingEdit {
                editPoint = Node.EditPoint(
                    nearestLine: e.line, nearestPointIndex: e.pointIndex,
                    lines: [e.line],
                    point: n.point, isSnap: movePointIsSnap
                )
            } else if let e = n.cellItemEdit {
                editPoint = Node.EditPoint(
                    nearestLine: e.geometry.lines[e.lineIndex], nearestPointIndex: e.pointIndex,
                    lines: [e.geometry.lines[e.lineIndex]],
                    point: n.point, isSnap: movePointIsSnap
                )
            } else if n.drawingEditLineCap != nil || !n.cellItemEditLineCaps.isEmpty {
                if let nlc = n.bezierSortedResult(at: point) {
                    if let e = n.drawingEditLineCap {
                        let drawingLines = e.drawingCaps.map { $0.line }
                        let cellItemLines = n.cellItemEditLineCaps.reduce(into: [Line]()) {
                            $0 += $1.caps.map { $0.line }
                        }
                        editPoint = Node.EditPoint(nearestLine: nlc.lineCap.line,
                                                   nearestPointIndex: nlc.lineCap.pointIndex,
                                                   lines: drawingLines + cellItemLines,
                                                   point: n.point,
                                                   isSnap: movePointIsSnap)
                    } else {
                        let cellItemLines = n.cellItemEditLineCaps.reduce(into: [Line]()) {
                            $0 += $1.caps.map { $0.line }
                        }
                        editPoint = Node.EditPoint(nearestLine: nlc.lineCap.line,
                                                   nearestPointIndex: nlc.lineCap.pointIndex,
                                                   lines: cellItemLines,
                                                   point: n.point,
                                                   isSnap: movePointIsSnap)
                    }
                } else {
                    editPoint = nil
                }
            }
        } else {
            editPoint = nil
        }
    }
    
    var editZ: Node.EditZ? {
        didSet {
            if editZ != oldValue {
                setNeedsDisplay()
            }
        }
    }
    func updateEditZ(with point: CGPoint) {
        let ict = cut.editNode.indicatedCellsTuple(with: point,
                                                    reciprocalScale: scene.reciprocalScale)
        if ict.type == .none {
            self.editZ = nil
        } else {
            let cells = ict.cellItems.map { $0.cell }
            let firstY = cut.editNode.editZFirstY(with: cells)
            self.editZ = Node.EditZ(cells: cells,
                                    point: point, firstPoint: point, firstY: firstY)
        }
    }
    
    var editTransform: Node.EditTransform? {
        didSet {
            if editTransform != oldValue {
                setNeedsDisplay()
            }
        }
    }
    func editTransform(at p: CGPoint) -> Node.EditTransform? {
        func editTransform(with lines: [Line]) -> Node.EditTransform {
            var ps = [CGPoint]()
            for line in lines {
                line.allEditPoints { (p, i) in ps.append(p) }
            }
            let rb = RotateRect(convexHullPoints: CGPoint.convexHullPoints(with: ps))
            let w = rb.size.width * Node.EditTransform.centerRatio
            let h = rb.size.height * Node.EditTransform.centerRatio
            let centerBounds = CGRect(x: (rb.size.width - w) / 2,
                                      y: (rb.size.height - h) / 2, width: w, height: h)
            let np = rb.convertToLocal(p: p)
            let isCenter = centerBounds.contains(np)
            let tx = np.x / rb.size.width, ty = np.y / rb.size.height
            if ty < tx {
                if ty < 1 - tx {
                    return Node.EditTransform(
                        rotateRect: rb, anchorPoint: isCenter ? rb.midXMidYPoint : rb.midXMaxYPoint,
                        point: rb.midXMinYPoint, oldPoint: rb.midXMinYPoint, isCenter: isCenter
                    )
                } else {
                    return Node.EditTransform(
                        rotateRect: rb, anchorPoint: isCenter ? rb.midXMidYPoint : rb.minXMidYPoint,
                        point: rb.maxXMidYPoint, oldPoint: rb.maxXMidYPoint, isCenter: isCenter
                    )
                }
            } else {
                if ty < 1 - tx {
                    return Node.EditTransform(
                        rotateRect: rb, anchorPoint: isCenter ? rb.midXMidYPoint : rb.maxXMidYPoint,
                        point: rb.minXMidYPoint, oldPoint: rb.minXMidYPoint, isCenter: isCenter
                    )
                } else {
                    return Node.EditTransform(
                        rotateRect: rb, anchorPoint: isCenter ? rb.midXMidYPoint : rb.midXMinYPoint,
                        point: rb.midXMaxYPoint, oldPoint: rb.midXMaxYPoint, isCenter: isCenter
                    )
                }
            }
        }
        
        let selection = cut.editNode.selection(with: p, reciprocalScale: scene.reciprocalScale)
        if selection.cellTuples.isEmpty {
            if let drawingTuple = selection.drawingTuple {
                if drawingTuple.lineIndexes.isEmpty {
                    return nil
                } else {
                    return editTransform(with:
                        drawingTuple.lineIndexes.map { drawingTuple.drawing.lines[$0] })
                }
            } else {
                return nil
            }
        } else {
            let lines = selection.cellTuples.reduce(into: [Line]()) {
                $0 += $1.cellItem.cell.geometry.lines
            }
            return editTransform(with: lines)
        }
    }
    func updateEditTransform(with p: CGPoint) {
        self.editTransform = editTransform(at: p)
    }
    
    var cameraFrame: CGRect {
        get {
            return scene.frame
        }
        set {
            scene.frame = newValue
            player.updateChildren()
            updateWithScene()
        }
    }
    
    var setTimeHandler: ((Canvas, Beat) -> ())?
    var time: Beat {
        get {
            return scene.time
        }
        set {
            setTimeHandler?(self, newValue)
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
    var viewTransform: Transform {
        get {
            return scene.viewTransform
        }
        set {
            scene.viewTransform = newValue
            updateWithScene()
            updateEditCellBindingLine()
        }
    }
    private func updateWithScene() {
        updateSceneHandler?(self)
        setNeedsDisplay()
    }
    var updateSceneHandler: ((Canvas) -> ())?
    
    var currentTransform: CGAffineTransform {
        var affine = CGAffineTransform.identity
        affine = affine.concatenating(cut.editNode.worldAffineTransform)
        affine = affine.concatenating(scene.viewTransform.affineTransform)
        affine = affine.concatenating(screenTransform)
        return affine
    }
    func convertToCurrentLocal(_ r: CGRect) -> CGRect {
        let transform = currentTransform
        return transform.isIdentity ? r : r.applying(transform.inverted())
    }
    func convertFromCurrentLocal(_ r: CGRect) -> CGRect {
        let transform = currentTransform
        return transform.isIdentity ? r : r.applying(transform)
    }
    func convertToCurrentLocal(_ p: CGPoint) -> CGPoint {
        let transform = currentTransform
        return transform.isIdentity ? p : p.applying(transform.inverted())
    }
    func convertFromCurrentLocal(_ p: CGPoint) -> CGPoint {
        let transform = currentTransform
        return transform.isIdentity ? p : p.applying(transform)
    }
    
    override var isIndicated: Bool {
        didSet {
            if !isIndicated {
                indicatedCellItem = nil
            }
        }
    }
    var indicatedPoint: CGPoint?
    var indicatedCellItem: CellItem? {
        didSet {
            if indicatedCellItem != oldValue {
                oldValue?.cell.isIndicated = false
                indicatedCellItem?.cell.isIndicated = true
                setNeedsDisplay()
            }
        }
    }
    
    func setNeedsDisplay() {
        draw()
    }
    func setNeedsDisplay(inCurrentLocalBounds rect: CGRect) {
        draw(convertFromCurrentLocal(rect))
    }
    
    func draw(in ctx: CGContext) {
        ctx.saveGState()
        ctx.concatenate(screenTransform)
        cut.draw(scene: scene, viewType: viewType, in: ctx)
        if viewType != .preview {
            let edit = Node.Edit(indicatedCellItem: indicatedCellItem,
                                 editMaterial: materialEditor.material,
                                 editZ: editZ, editPoint: editPoint,
                                 editTransform: editTransform, point: indicatedPoint)
            ctx.concatenate(scene.viewTransform.affineTransform)
            cut.editNode.drawEdit(edit, scene: scene, viewType: viewType,
                                  strokeLine: strokeLine,
                                  strokeLineWidth: strokeLineWidth, strokeLineColor: strokeLineColor,
                                  reciprocalViewScale: scene.reciprocalViewScale,
                                  scale: scene.scale, rotation: scene.viewTransform.rotation,
                                  in: ctx)
            ctx.restoreGState()
            if let editZ = editZ {
                let p = convertFromCurrentLocal(editZ.firstPoint)
                cut.editNode.drawEditZKnob(editZ, at: p, in: ctx)
            }
            cut.drawCautionBorder(scene: scene, bounds: bounds, in: ctx)
        } else {
            ctx.restoreGState()
        }
    }
    
    private func registerUndo(_ handler: @escaping (Canvas, Beat) -> Void) {
        undoManager?.registerUndo(withTarget: self) { [oldTime = time] in handler($0, oldTime) }
    }
    
    func copy(with event: KeyInputEvent) -> CopiedObject? {
        let p = convertToCurrentLocal(point(from: event))
        let ict = cut.editNode.indicatedCellsTuple(with: p, reciprocalScale: scene.reciprocalScale)
        switch ict.type {
        case .none:
            let copySelectionLines = cut.editNode.editTrack.drawingItem.drawing.editLines
            if !copySelectionLines.isEmpty {
                let drawing = Drawing(lines: copySelectionLines)
                return CopiedObject(objects: [drawing.copied])
            }
        case .indicated, .selected:
            if !ict.selectionLineIndexes.isEmpty {
                let copySelectionLines = cut.editNode.editTrack.drawingItem.drawing.editLines
                let drawing = Drawing(lines: copySelectionLines)
                return CopiedObject(objects: [drawing.copied])
            } else {
                let cell = cut.editNode.rootCell.intersection(ict.cellItems.map { $0.cell },
                                                              isNewID: false)
                let material = ict.cellItems[0].cell.material
                return CopiedObject(objects: [JoiningCell(cell), material])
            }
        }
        return CopiedObject()
    }
    func copyCell() -> CopiedObject? {
        guard let editCell = editCell else {
            return nil
        }
        let cells = cut.editNode.selectionCells(with: editCell)
        let cell = cut.editNode.rootCell.intersection(cells, isNewID: true)
        return CopiedObject(objects: [cell.copied])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        for object in copiedObject.objects {
            if let color = object as? Color {
                return paste(color, with: event)
            } else if let material = object as? Material {
                return paste(material, with: event)
            } else if let drawing = object as? Drawing {
                return paste(drawing, with: event)
            } else if !cut.editNode.editTrack.animation.isInterpolated {
                if let joiningCell = object as? JoiningCell {
                    return paste(joiningCell, with: event)
                } else if let rootCell = object as? Cell {
                    return paste(rootCell, with: event)
                }
            }
        }
        return false
    }
    var pasteColorBinding: ((Canvas, Color, [Cell]) -> ())?
    func paste(_ color: Color, with event: KeyInputEvent) -> Bool {
        let p = convertToCurrentLocal(point(from: event))
        let ict = cut.editNode.indicatedCellsTuple(with: p, reciprocalScale: scene.reciprocalScale)
        guard !ict.cellItems.isEmpty else {
            return false
        }
        var isPaste = false
        for cellItem in ict.cellItems {
            if color != cellItem.cell.material.color {
                isPaste = true
                break
            }
        }
        if isPaste {
            pasteColorBinding?(self, color, ict.cellItems.map { $0.cell })
        }
        return true
    }
    var pasteMaterialBinding: ((Canvas, Material, [Cell]) -> ())?
    func paste(_ material: Material, with event: KeyInputEvent) -> Bool {
        let p = convertToCurrentLocal(point(from: event))
        let ict = cut.editNode.indicatedCellsTuple(with: p, reciprocalScale: scene.reciprocalScale)
        guard !ict.cellItems.isEmpty else {
            return false
        }
        var isPaste = false
        for cellItem in ict.cellItems {
            if material.id != cellItem.cell.material.id {
                isPaste = true
                break
            }
        }
        if isPaste {
            pasteMaterialBinding?(self, material, ict.cellItems.map { $0.cell })
        }
        return true
    }
    func paste(_ copyJoiningCell: JoiningCell, with event: KeyInputEvent) -> Bool {
        var isChanged = false
        let copyRootCell = copyJoiningCell.cell
        for copyCell in copyRootCell.allCells {
            for track in cut.editNode.tracks {
                for ci in track.cellItems {
                    if ci.cell.id == copyCell.id {
                        set(copyCell.geometry, old: ci.cell.geometry,
                            at: track.animation.editKeyframeIndex, in: ci, time: time)
                        cut.editNode.editTrack.updateInterpolation()
                        isChanged = true
                    }
                }
            }
        }
        return isChanged
    }
    func paste(_ copyRootCell: Cell, with event: KeyInputEvent) -> Bool {
        let lki = cut.editNode.editTrack.animation.loopedKeyframeIndex(withTime: cut.time)
        var newCellItems = [CellItem]()
        copyRootCell.depthFirstSearch(duplicate: false) { parent, cell in
            cell.id = UUID()
            let emptyKeyGeometries = cut.editNode.editTrack.emptyKeyGeometries
            let keyGeometrys = emptyKeyGeometries.withReplaced(cell.geometry,
                                                               at: lki.keyframeIndex)
            newCellItems.append(CellItem(cell: cell, keyGeometries: keyGeometrys))
        }
        let index = cellIndex(withTrackIndex: cut.editNode.editTrackIndex, in: cut.editNode.rootCell)
        insertCells(newCellItems, rootCell: copyRootCell,
                    at: index, in: cut.editNode.rootCell, cut.editNode.editTrack, time: time)
        setSelectionCellItems(cut.editNode.editTrack.selectionCellItems + newCellItems,
                              oldCellItems: cut.editNode.editTrack.selectionCellItems,
                              in: cut.editNode.editTrack, time: time)
        return true
    }
    func paste(_ copyDrawing: Drawing, with event: KeyInputEvent) -> Bool {
        let p = convertToCurrentLocal(point(from: event))
        let ict = cut.editNode.indicatedCellsTuple(with : p,
                                                   reciprocalScale: scene.reciprocalScale)
        if !cut.editNode.editTrack.animation.isInterpolated && ict.type != .none,
            let cell = cut.editNode.rootCell.at(p),
            let cellItem = cut.editNode.editTrack.cellItem(with: cell) {
            
            let nearestPathLineIndex = cellItem.cell.geometry.nearestPathLineIndex(at: p)
            let previousLine = cellItem.cell.geometry.lines[nearestPathLineIndex]
            let nextLineIndex = nearestPathLineIndex + 1 >=
                cellItem.cell.geometry.lines.count ? 0 : nearestPathLineIndex + 1
            let nextLine = cellItem.cell.geometry.lines[nextLineIndex]
            let unionSegmentLine = Line(
                controls: [Line.Control(point: nextLine.firstPoint, pressure: 1),
                           Line.Control(point: previousLine.lastPoint, pressure: 1)]
            )
            let geometry = Geometry(lines: [unionSegmentLine] + copyDrawing.lines,
                                    scale: scene.scale)
            let lines = geometry.lines.withRemovedFirst()
            let geometris = Geometry.geometriesWithInserLines(with: cellItem.keyGeometries,
                                                              lines: lines,
                                                              atLinePathIndex: nearestPathLineIndex)
            setGeometries(geometris,
                          oldKeyGeometries: cellItem.keyGeometries,
                          in: cellItem, cut.editNode.editTrack, time: time)
        } else {
            let drawing = cut.editNode.editTrack.drawingItem.drawing
            let oldCount = drawing.lines.count
            let lineIndexes = (0 ..< copyDrawing.lines.count).map { $0 + oldCount }
            setLines(drawing.lines + copyDrawing.lines,
                     oldLines: drawing.lines, drawing: drawing, time: time)
            setSelectionLineIndexes(drawing.selectionLineIndexes + lineIndexes,
                                    oldLineIndexes: drawing.selectionLineIndexes,
                                    in: drawing, time: time)
        }
        return true
    }
    
    func delete(with event: KeyInputEvent) -> Bool {
        let point = convertToCurrentLocal(self.point(from: event))
        if deleteCells(for: point) {
            return true
        }
        if deleteSelectionDrawingLines(for: point) {
            return true
        }
        if deleteDrawingLines(for: point) {
            return true
        }
        return false
    }
    func deleteSelectionDrawingLines(for p: CGPoint) -> Bool {
        let drawingItem = cut.editNode.editTrack.drawingItem
        guard drawingItem.drawing.isNearestSelectionLineIndexes(at: p) else {
            return false
        }
        let unseletionLines = drawingItem.drawing.uneditLines
        setSelectionLineIndexes([], oldLineIndexes: drawingItem.drawing.selectionLineIndexes,
                                in: drawingItem.drawing, time: time)
        setLines(unseletionLines, oldLines: drawingItem.drawing.lines,
                 drawing: drawingItem.drawing, time: time)
        return true
    }
    func deleteDrawingLines(for p: CGPoint) -> Bool {
        let drawingItem = cut.editNode.editTrack.drawingItem
        guard !drawingItem.drawing.lines.isEmpty else {
            return false
        }
        setSelectionLineIndexes([], oldLineIndexes: drawingItem.drawing.selectionLineIndexes,
                                in: drawingItem.drawing, time: time)
        setLines([], oldLines: drawingItem.drawing.lines,
                 drawing: drawingItem.drawing, time: time)
        return true
    }
    func deleteCells(for point: CGPoint) -> Bool {
        let ict = cut.editNode.indicatedCellsTuple(with: point,
                                                    reciprocalScale: scene.reciprocalScale)
        switch ict.type {
        case .selected:
            var isChanged = false
            for track in cut.editNode.tracks {
                let removeSelectionCellItems = ict.cellItems.filter {
                    if !$0.cell.geometry.isEmpty {
                        set(Geometry(), old: $0.cell.geometry,
                            at: track.animation.editKeyframeIndex, in: $0, time: time)
                        cut.editNode.editTrack.updateInterpolation()
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
        case .indicated:
            if let cellItem = cut.editNode.cellItem(at: point,
                                                    reciprocalScale: scene.reciprocalScale,
                                                    with: cut.editNode.editTrack) {
                if !cellItem.cell.geometry.isEmpty {
                    set(Geometry(), old: cellItem.cell.geometry,
                        at: cut.editNode.editTrack.animation.editKeyframeIndex,
                        in: cellItem, time: time)
                    if cellItem.isEmptyKeyGeometries {
                        removeCellItems([cellItem])
                    }
                    cut.editNode.editTrack.updateInterpolation()
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
            let cellRemoveManager = cut.editNode.cellRemoveManager(with: cellItems[0])
            for trackAndCellItems in cellRemoveManager.trackAndCellItems {
                let track = trackAndCellItems.track, cellItems = trackAndCellItems.cellItems
                let removeSelectionCellItems
                    = Array(Set(track.selectionCellItems).subtracting(cellItems))
                if removeSelectionCellItems.count != track.selectionCellItems.count {
                    setSelectionCellItems(removeSelectionCellItems,
                                          oldCellItems: track.selectionCellItems,
                                          in: track, time: time)
                }
            }
            removeCell(with: cellRemoveManager, time: time)
            cellItems = cellItems.filter { !cellRemoveManager.contains($0) }
        }
    }
    private func insertCell(with cellRemoveManager: Node.CellRemoveManager, time: Beat) {
        registerUndo { $0.removeCell(with: cellRemoveManager, time: $1) }
        self.time = time
        cut.editNode.insertCell(with: cellRemoveManager)
        cutItem.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        setNeedsDisplay()
    }
    private func removeCell(with cellRemoveManager: Node.CellRemoveManager, time: Beat) {
        registerUndo { $0.insertCell(with: cellRemoveManager, time: $1) }
        self.time = time
        cut.editNode.removeCell(with: cellRemoveManager)
        cutItem.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        setNeedsDisplay()
    }
    
    private func setGeometries(_ keyGeometries: [Geometry], oldKeyGeometries: [Geometry],
                               in cellItem: CellItem, _ track: NodeTrack, time: Beat) {
        registerUndo { $0.setGeometries(oldKeyGeometries, oldKeyGeometries: keyGeometries,
                                        in: cellItem, track, time: $1) }
        self.time = time
        track.set(keyGeometries, in: cellItem)
        cutItem.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func set(_ geometry: Geometry, old oldGeometry: Geometry,
                     at i: Int, in cellItem: CellItem, time: Beat) {
        registerUndo { $0.set(oldGeometry, old: geometry,
                              at: i, in: cellItem, time: $1) }
        self.time = time
        cellItem.replace(geometry, at: i)
        cutItem.cut.editNode.editTrack.updateInterpolation()
        cutItem.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    
    func selectAll(with event: KeyInputEvent) -> Bool {
        let track = cut.editNode.editTrack
        let drawing = track.drawingItem.drawing
        let lineIndexes = Array(0 ..< drawing.lines.count)
        if Set(drawing.selectionLineIndexes) != Set(lineIndexes) {
            setSelectionLineIndexes(lineIndexes, oldLineIndexes: drawing.selectionLineIndexes,
                                    in: drawing, time: time)
        }
        if Set(track.selectionCellItems) != Set(track.cellItems) {
            setSelectionCellItems(track.cellItems, oldCellItems: track.selectionCellItems,
                                  in: track, time: time)
        }
        return true
    }
    func deselectAll(with event: KeyInputEvent) -> Bool {
        let track = cut.editNode.editTrack
        let drawing = track.drawingItem.drawing
        if !drawing.selectionLineIndexes.isEmpty {
            setSelectionLineIndexes([], oldLineIndexes: drawing.selectionLineIndexes,
                                    in: drawing, time: time)
        }
        if !track.selectionCellItems.isEmpty {
            setSelectionCellItems([], oldCellItems: track.selectionCellItems,
                                  in: track, time: time)
        }
        return true
    }
    
    func play(with event: KeyInputEvent) {
        play()
    }
    func play() {
        isOpenedPlayer = true
        player.play()
    }
    
    func new(with event: KeyInputEvent) -> Bool {
        let track = cut.editNode.editTrack
        let drawingItem = track.drawingItem, rootCell = cut.editNode.rootCell
        let geometry = Geometry(lines: drawingItem.drawing.editLines, scale: scene.scale)
        guard !geometry.isEmpty else {
            return false
        }
        let isDrawingSelectionLines = !drawingItem.drawing.selectionLineIndexes.isEmpty
        let unselectionLines = drawingItem.drawing.uneditLines
        if isDrawingSelectionLines {
            setSelectionLineIndexes([], oldLineIndexes: drawingItem.drawing.selectionLineIndexes,
                                    in: drawingItem.drawing, time: time)
        }
        setLines(unselectionLines, oldLines: drawingItem.drawing.lines,
                 drawing: drawingItem.drawing, time: time)
        let lki = track.animation.loopedKeyframeIndex(withTime: cut.time)
        let keyGeometries = track.emptyKeyGeometries.withReplaced(geometry, at: lki.keyframeIndex)
        
        let newMaterial = Material(color: Color.random(colorSpace: scene.colorSpace))
        let newCellItem = CellItem(cell: Cell(geometry: geometry, material: newMaterial),
                                   keyGeometries: keyGeometries)
        
        let p = point(from: event)
        let ict = cut.editNode.indicatedCellsTuple(with: convertToCurrentLocal(p),
                                                   reciprocalScale: scene.reciprocalScale)
        if ict.type == .selected {
            let newCellItems = ict.cellItems.map {
                ($0.cell, addCellIndex(with: newCellItem.cell, in: $0.cell))
            }
            insertCell(newCellItem, in: newCellItems, cut.editNode.editTrack, time: time)
        } else {
            let newCellItems = [(rootCell, addCellIndex(with: newCellItem.cell, in: rootCell))]
            insertCell(newCellItem, in: newCellItems, cut.editNode.editTrack, time: time)
        }
        return true
    }
    
    private func addCellIndex(with cell: Cell, in parent: Cell) -> Int {
        let editCells = cut.editNode.editTrack.cells
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
        return cellIndex(withTrackIndex: cut.editNode.editTrackIndex, in: parent)
    }
    
    func cellIndex(withTrackIndex trackIndex: Int, in parent: Cell) -> Int {
        for i in trackIndex + 1 ..< cut.editNode.tracks.count {
            let track = cut.editNode.tracks[i]
            var maxIndex = 0, isMax = false
            for cellItem in track.cellItems {
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
    
    func moveCell(_ cell: Cell, from fromParents: [(cell: Cell, index: Int)],
                  to toParents: [(cell: Cell, index: Int)], time: Beat) {
        registerUndo { $0.moveCell(cell, from: toParents, to: fromParents, time: $1) }
        self.time = time
        for fromParent in fromParents {
            fromParent.cell.children.remove(at: fromParent.index)
        }
        for toParent in toParents {
            toParent.cell.children.insert(cell, at: toParent.index)
        }
        cutItem.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        setNeedsDisplay()
    }
    
    func lassoErase(with event: DragEvent) -> Bool {
        _ = stroke(with: event, lineWidth: strokeLineWidth,
                   movePointMaxDistance: strokeDistance,
                   movePointMaxTime: strokeMovePointMaxTime, isAppendLine: false)
        switch event.sendType {
        case .begin:
            break
        case .sending:
            if let line = strokeLine {
                setNeedsDisplay(inCurrentLocalBounds: line.imageBounds.inset(by: -strokeLineWidth))
            }
        case .end:
            if let line = strokeLine {
                lassoErase(with: line)
                strokeLine = nil
            }
        }
        return true
    }
    func lassoErase(with line: Line) {
        let drawing = cut.editNode.editTrack.drawingItem.drawing, track = cut.editNode.editTrack
        if let index = drawing.lines.index(of: line) {
            removeLine(at: index, in: drawing, time: time)
        }
        if !drawing.selectionLineIndexes.isEmpty {
            setSelectionLineIndexes([], oldLineIndexes: drawing.selectionLineIndexes,
                                    in: drawing, time: time)
        }
        var isRemoveLineInDrawing = false, isRemoveLineInCell = false
        let lasso = LineLasso(lines: [line])
        let newDrawingLines = drawing.lines.reduce(into: [Line]()) {
            if let splitLines = lasso.split($1) {
                isRemoveLineInDrawing = true
                $0 += splitLines
            } else {
                $0.append($1)
            }
        }
        if isRemoveLineInDrawing {
            setLines(newDrawingLines, oldLines: drawing.lines, drawing: drawing, time: time)
        }
        var removeCellItems = [CellItem]()
        removeCellItems = track.cellItems.filter { cellItem in
            if cellItem.cell.intersects(lasso) {
                set(Geometry(), old: cellItem.cell.geometry,
                    at: track.animation.editKeyframeIndex, in: cellItem, time: time)
                cut.editNode.editTrack.updateInterpolation()
                if cellItem.isEmptyKeyGeometries {
                    return true
                }
                isRemoveLineInCell = true
            }
            return false
        }
        if !isRemoveLineInDrawing && !isRemoveLineInCell {
            if let hitCellItem = cut.editNode.cellItem(at: line.firstPoint,
                                                       reciprocalScale: scene.reciprocalScale,
                                                       with: track) {
                let lines = hitCellItem.cell.geometry.lines
                set(Geometry(), old: hitCellItem.cell.geometry,
                    at: track.animation.editKeyframeIndex,
                    in: hitCellItem, time: time)
                cut.editNode.editTrack.updateInterpolation()
                if hitCellItem.isEmptyKeyGeometries {
                    removeCellItems.append(hitCellItem)
                }
                setLines(drawing.lines + lines, oldLines: drawing.lines,
                         drawing: drawing, time: time)
            }
        }
        if !removeCellItems.isEmpty {
            self.removeCellItems(removeCellItems)
        }
    }
    
    private func insertCell(_ cellItem: CellItem,
                            in parents: [(cell: Cell, index: Int)],
                            _ track: NodeTrack, time: Beat) {
        registerUndo { $0.removeCell(cellItem, in: parents, track, time: $1) }
        self.time = time
        track.insertCell(cellItem, in: parents)
        cutItem.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        setNeedsDisplay()
    }
    private func removeCell(_ cellItem: CellItem,
                            in parents: [(cell: Cell, index: Int)],
                            _ track: NodeTrack, time: Beat) {
        registerUndo { $0.insertCell(cellItem, in: parents, track, time: $1) }
        self.time = time
        track.removeCell(cellItem, in: parents)
        cutItem.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        setNeedsDisplay()
    }
    private func insertCells(_ cellItems: [CellItem], rootCell: Cell,
                             at index: Int, in parent: Cell,
                             _ track: NodeTrack, time: Beat) {
        registerUndo {
            $0.removeCells(cellItems, rootCell: rootCell, at: index, in: parent, track, time: $1)
        }
        self.time = time
        track.insertCells(cellItems, rootCell: rootCell, at: index, in: parent)
        cutItem.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        setNeedsDisplay()
    }
    private func removeCells(_ cellItems: [CellItem], rootCell: Cell,
                             at index: Int, in parent: Cell,
                             _ track: NodeTrack, time: Beat) {
        registerUndo {
            $0.insertCells(cellItems, rootCell: rootCell, at: index, in: parent, track, time: $1)
        }
        self.time = time
        track.removeCells(cellItems, rootCell: rootCell, in: parent)
        cutItem.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        setNeedsDisplay()
    }
    
    func translucentLockCell(at point: CGPoint) {
        let seletionCells = cut.editNode.indicatedCellsTuple(with: convertToCurrentLocal(point),
                                                             reciprocalScale: scene.reciprocalScale)
        for cellItem in seletionCells.cellItems {
            if !cellItem.cell.isTranslucentLock {
                setIsTranslucentLock(true, in: cellItem.cell, time: time)
            }
        }
    }
    func unlockAllCells() {
        cut.editNode.rootCell.allCells { cell, stop in
            if cell.isTranslucentLock {
                setIsTranslucentLock(false, in: cell, time: time)
            }
        }
    }
    func setIsTranslucentLock(_ isTranslucentLock: Bool, in cell: Cell, time: Beat) {
        registerUndo { [oldIsTranslucentLock = cell.isTranslucentLock] in
            $0.setIsTranslucentLock(oldIsTranslucentLock, in: cell, time: $1)
        }
        self.time = time
        cell.isTranslucentLock = isTranslucentLock
        sceneDataModel?.isWrite = true
        setNeedsDisplay()
        if cell == cellEditor.cell {
            cellEditor.updateWithCell()
        }
    }
    
    func changeToRough() {
        let indexes = cut.editNode.editTrack.animation.selectionKeyframeIndexes.sorted()
        let i = cut.editNode.editTrack.animation.editKeyframeIndex
        (indexes.contains(i) ? indexes : [i]).forEach {
            let drawing = cut.editNode.editTrack.drawingItem.keyDrawings[$0]
            if !drawing.roughLines.isEmpty || !drawing.lines.isEmpty {
                setRoughLines(drawing.editLines, oldLines: drawing.roughLines,
                              drawing: drawing, time: time)
                setLines(drawing.uneditLines, oldLines: drawing.lines, drawing: drawing, time: time)
                if !drawing.selectionLineIndexes.isEmpty {
                    setSelectionLineIndexes([], oldLineIndexes: drawing.selectionLineIndexes,
                                            in: drawing, time: time)
                }
            }
        }
    }
    func removeRough() {
        let indexes = cut.editNode.editTrack.animation.selectionKeyframeIndexes.sorted()
        let i = cut.editNode.editTrack.animation.editKeyframeIndex
        (indexes.contains(i) ? indexes : [i]).forEach {
            let drawing = cut.editNode.editTrack.drawingItem.keyDrawings[$0]
            if !drawing.roughLines.isEmpty {
                setRoughLines([], oldLines: drawing.roughLines, drawing: drawing, time: time)
            }
        }
    }
    func swapRough() {
        let indexes = cut.editNode.editTrack.animation.selectionKeyframeIndexes.sorted()
        let i = cut.editNode.editTrack.animation.editKeyframeIndex
        (indexes.contains(i) ? indexes : [i]).forEach {
            let drawing = cut.editNode.editTrack.drawingItem.keyDrawings[$0]
            if !drawing.roughLines.isEmpty || !drawing.lines.isEmpty {
                if !drawing.selectionLineIndexes.isEmpty {
                    setSelectionLineIndexes([], oldLineIndexes: drawing.selectionLineIndexes,
                                            in: drawing, time: time)
                }
                let newLines = drawing.roughLines, newRoughLines = drawing.lines
                setRoughLines(newRoughLines, oldLines: drawing.roughLines,
                              drawing: drawing, time: time)
                setLines(newLines, oldLines: drawing.lines, drawing: drawing, time: time)
            }
        }
    }
    var setRoughLinesHandler: ((Canvas, Drawing) -> ())? = nil
    private func setRoughLines(_ lines: [Line], oldLines: [Line], drawing: Drawing, time: Beat) {
        registerUndo { $0.setRoughLines(oldLines, oldLines: lines, drawing: drawing, time: $1) }
        self.time = time
        drawing.roughLines = lines
        cutItem.differentialDataModel.isWrite = true
        setNeedsDisplay()
        setRoughLinesHandler?(self, drawing)
    }
    private func setLines(_ lines: [Line], oldLines: [Line], drawing: Drawing, time: Beat) {
        registerUndo { $0.setLines(oldLines, oldLines: lines, drawing: drawing, time: $1) }
        self.time = time
        drawing.lines = lines
        cutItem.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    
    private let polygonRadius = 50.0.cf
    func appendTriangleLines() {
        let lines = regularPolygonLinesWith(centerPosition: CGPoint(x: bounds.midX, y: bounds.midY),
                                            radius: polygonRadius, count: 3)
        append(lines, duplicatedTranslation: CGPoint(x: polygonRadius * 2 + Layout.basicPadding, y: 0))
    }
    func appendSquareLines() {
        let r = polygonRadius
        let cp = CGPoint(x: bounds.midX, y: bounds.midY)
        let p0 = CGPoint(x: cp.x - r, y: cp.y - r), p1 = CGPoint(x: cp.x + r, y: cp.y - r)
        let p2 = CGPoint(x: cp.x - r, y: cp.y + r), p3 = CGPoint(x: cp.x + r, y: cp.y + r)
        let l0 = Line(controls: [Line.Control(point: p0, pressure: 1),
                                 Line.Control(point: p1, pressure: 1)])
        let l1 = Line(controls: [Line.Control(point: p1, pressure: 1),
                                 Line.Control(point: p3, pressure: 1)])
        let l2 = Line(controls: [Line.Control(point: p3, pressure: 1),
                                 Line.Control(point: p2, pressure: 1)])
        let l3 = Line(controls: [Line.Control(point: p2, pressure: 1),
                                 Line.Control(point: p0, pressure: 1)])
        append([l0, l1, l2, l3], duplicatedTranslation: CGPoint(x: r * 2 + Layout.basicPadding, y: 0))
    }
    func appendPentagonLines() {
        let lines = regularPolygonLinesWith(centerPosition: CGPoint(x: bounds.midX, y: bounds.midY),
                                            radius: polygonRadius, count: 5)
        append(lines, duplicatedTranslation: CGPoint(x: polygonRadius * 2 + Layout.basicPadding, y: 0))
    }
    func appendHexagonLines() {
        let lines = regularPolygonLinesWith(centerPosition: CGPoint(x: bounds.midX, y: bounds.midY),
                                            radius: polygonRadius, count: 6)
        append(lines, duplicatedTranslation: CGPoint(x: polygonRadius * 2 + Layout.basicPadding, y: 0))
    }
    func appendCircleLines() {
        let count = 8, r = polygonRadius
        let theta = .pi / count.cf
        let cp = CGPoint(x: bounds.midX, y: bounds.midY)
        let fp = CGPoint(x: cp.x, y: cp.y + polygonRadius)
        let points = circlePointsWith(centerPosition: cp,
                                      radius: r / cos(theta),
                                      firstAngle: .pi / 2 + theta,
                                      count: count)
        let newPoints = [fp] + points + [fp]
        let line = Line(controls: newPoints.map { Line.Control(point: $0, pressure: 1) })
        append([line],
               duplicatedTranslation: CGPoint(x: polygonRadius * 2 + Layout.basicPadding, y: 0))
    }
    func regularPolygonLinesWith(centerPosition cp: CGPoint, radius r: CGFloat,
                                 firstAngle: CGFloat = .pi / 2, count: Int) -> [Line] {
        let points = circlePointsWith(centerPosition: cp, radius: r,
                                      firstAngle: firstAngle, count: count)
        return points.enumerated().map {
            let p0 = $0.element, i = $0.offset
            let p1 = i + 1 < points.count ? points[i + 1] : points[0]
            return Line(controls: [Line.Control(point: p0, pressure: 1),
                                   Line.Control(point: p1, pressure: 1)])
        }
    }
    func circlePointsWith(centerPosition cp: CGPoint, radius r: CGFloat,
                          firstAngle: CGFloat = .pi / 2, count: Int) -> [CGPoint] {
        var angle = firstAngle, theta = (2 * .pi) / count.cf
        return (0 ..< count).map { _ in
            let p = CGPoint(x: cp.x + r * cos(angle), y: cp.y + r * sin(angle))
            angle += theta
            return p
        }
    }
    func append(_ lines: [Line], duplicatedTranslation dtp: CGPoint) {
        let affineTransform = currentTransform.inverted()
        let transformedLines = affineTransform.isIdentity ?
            lines : lines.map { $0.applying(affineTransform) }
        let drawing = cut.editNode.editTrack.drawingItem.drawing
        let newLines: [Line] = {
            if drawing.intersects(transformedLines) {
                var p = dtp, moveLines = lines
                repeat {
                    let moveAffine = CGAffineTransform(translationX: p.x, y: p.y)
                    moveLines = lines.map { $0.applying(moveAffine).applying(affineTransform) }
                    p += dtp
                } while drawing.intersects(moveLines)
                return drawing.lines + moveLines
            } else {
                return drawing.lines + transformedLines
            }
        } ()
        setLines(newLines, oldLines: drawing.lines, drawing: drawing, time: time)
    }
    
    func moveCursor(with event: MoveEvent) -> Bool {
        updateEditView(with: convertToCurrentLocal(point(from: event)))
        return true
    }
    
    var editCell: Cell?
    var (editCellLineLayer, subEditCellLineLayer): (PathLayer, PathLayer) = {
        let layer = PathLayer()
        layer.lineColor = .subSelection
        layer.lineWidth = 3
        let sublayer = PathLayer()
        sublayer.lineColor = .selection
        sublayer.lineWidth = 1
        layer.append(child: sublayer)
        return (layer, sublayer)
    } ()
    private let bindingLineHeight = 5.0.cf
    let editCellBindingLineLayer: PathLayer = {
        let layer = PathLayer()
        layer.fillColor = .border
        return layer
    } ()
    
    func isVisible(_ cell: Cell) -> Bool {
        return cell.intersects(bounds.applying(currentTransform.inverted()))
    }
    
    let materialEditor = MaterialEditor(), cellEditor = CellEditor()
    func bind(with event: RightClickEvent) -> Bool {
        let p = convertToCurrentLocal(point(from: event))
        let ict = cut.editNode.indicatedCellsTuple(with: p, reciprocalScale: scene.reciprocalScale)
        let material = ict.cellItems.first?.cell.material ?? cut.editNode.material
        let cell = ict.cellItems.first?.cell
        bind(material, cell, time: time)
        return true
    }
    func bind(_ material: Material, _ editCell: Cell?, time: Beat) {
        registerUndo { [oec = editCell] in $0.bind($0.materialEditor.material, oec, time: $1) }
        self.time = time
        materialEditor.material = material
        cellEditor.cell = editCell ?? Cell()
        self.editCell = editCell
        updateEditCellBindingLine()
    }
    
    func updateEditCellBindingLine() {
        let maxX = cellEditor.frame.minX
        let width = maxX - frame.maxX, midY = frame.midY
        if let editCell = editCell, !editCell.isEmpty && isVisible(editCell) {
            let path = CGPath(rect: CGRect(x: frame.maxX, y: midY - bindingLineHeight / 2,
                                           width: width,
                                           height: bindingLineHeight), transform: nil)
            editCellBindingLineLayer.fillColor = .border
            editCellBindingLineLayer.path = path
            
            let fp = CGPoint(x: bounds.maxX, y: bounds.midY)
            if let n = editCell.geometry.nearestBezier(with: fp) {
                let np = editCell.geometry.lines[n.lineIndex]
                    .bezier(at: n.bezierIndex).position(withT: n.t)
                let p = np.applying(currentTransform)
                if bounds.contains(p) {
                    if editCellLineLayer.parent == nil {
                        append(child: editCellLineLayer)
                    }
                    let path = CGMutablePath()
                    path.move(to: fp)
                    path.addLine(to: CGPoint(x: p.x, y: bounds.midY))
                    path.addLine(to: p)
                    editCellLineLayer.path = path
                    subEditCellLineLayer.path = path
                } else {
                    editCellLineLayer.removeFromParent()
                }
            }
        } else {
            editCellBindingLineLayer.fillColor = .warning
            let path = CGMutablePath()
            path.move(to: CGPoint(x: frame.maxX, y: midY))
            path.addLine(to: CGPoint(x: maxX, y: midY - bindingLineHeight / 2))
            path.addLine(to: CGPoint(x: maxX, y: midY + bindingLineHeight / 2))
            path.closeSubpath()
            editCellBindingLineLayer.path = path
            
            editCellLineLayer.removeFromParent()
        }
    }
    
    private struct SelectOption {
        var selectionLineIndexes = [Int](), selectionCellItems = [CellItem]()
    }
    private var selectOption = SelectOption()
    func select(with event: DragEvent) -> Bool {
        return select(with: event, isDeselect: false)
    }
    func deselect(with event: DragEvent) -> Bool {
        return select(with: event, isDeselect: true)
    }
    func select(with event: DragEvent, isDeselect: Bool) -> Bool {
        _ = stroke(with: event, lineWidth: strokeLineWidth,
                   movePointMaxDistance: strokeDistance,
                   movePointMaxTime: strokeMovePointMaxTime, isAppendLine: false)
        let drawing = cut.editNode.editTrack.drawingItem.drawing, track = cut.editNode.editTrack
        
        func unionWithStrokeLine() -> (lineIndexes: [Int], cellItems: [CellItem]) {
            func selection() -> (lineIndexes: [Int], cellItems: [CellItem]) {
                guard let line = strokeLine else {
                    return ([], [])
                }
                let lasso = LineLasso(lines: [line])
                return (drawing.lines.enumerated().flatMap { lasso.intersects($1) ? $0 : nil },
                        track.cellItems.filter { $0.cell.intersects(lasso) })
            }
            let s = selection()
            if isDeselect {
                return (Array(Set(selectOption.selectionLineIndexes).subtracting(Set(s.lineIndexes))),
                        Array(Set(selectOption.selectionCellItems).subtracting(Set(s.cellItems))))
            } else {
                return (Array(Set(selectOption.selectionLineIndexes).union(Set(s.lineIndexes))),
                        Array(Set(selectOption.selectionCellItems).union(Set(s.cellItems))))
            }
        }
        
        switch event.sendType {
        case .begin:
            selectOption.selectionLineIndexes = drawing.selectionLineIndexes
            selectOption.selectionCellItems = track.selectionCellItems
        case .sending:
            (drawing.selectionLineIndexes, track.selectionCellItems) = unionWithStrokeLine()
        case .end:
            let (selectionLineIndexes, selectionCellItems) = unionWithStrokeLine()
            if selectionLineIndexes != selectOption.selectionLineIndexes {
                setSelectionLineIndexes(selectionLineIndexes,
                                        oldLineIndexes: selectOption.selectionLineIndexes,
                                        in: drawing, time: time)
            }
            if selectionCellItems != selectOption.selectionCellItems {
                setSelectionCellItems(selectionCellItems,
                                      oldCellItems: selectOption.selectionCellItems,
                                      in: track, time: time)
            }
            self.selectOption = SelectOption()
            self.strokeLine = nil
        }
        setNeedsDisplay()
        return true
    }
    
    private var strokeLine: Line?
    private let strokeLineColor = Color.strokeLine, strokeLineWidth = DrawingItem.defaultLineWidth
    private var strokeOldPoint = CGPoint(), strokeOldTime = 0.0, strokeOldLastBounds = CGRect()
    private var strokeIsDrag = false, strokeControls: [Line.Control] = [], strokeBeginTime = 0.0
    private let strokeSplitAngle = 1.5 * (.pi) / 2.0.cf, strokeLowSplitAngle = 0.9 * (.pi) / 2.0.cf
    private let strokeDistance = 1.0.cf, strokeMovePointMaxTime = 0.1
    private let strokeSlowDistance = 3.5.cf, strokeSlowTime = 0.25, strokeShortTime = 0.1
    private let strokeShortLinearDistance = 1.0.cf, strokeShortLinearMaxDistance = 1.5.cf
    private struct Stroke {
        var line: Line?, movePointMaxDistance = 1.0.cf, movePointMaxTime = 0.1
    }
    func move(with event: DragEvent) -> Bool {
        return stroke(with: event)
    }
    func stroke(with event: DragEvent) -> Bool {
        return stroke(with: event, lineWidth: strokeLineWidth,
                      movePointMaxDistance: strokeDistance, movePointMaxTime: strokeMovePointMaxTime)
    }
    func slowStroke(with event: DragEvent) -> Bool {
        return stroke(with: event, lineWidth: strokeLineWidth,
                      movePointMaxDistance: strokeSlowDistance,
                      movePointMaxTime: strokeSlowTime, splitAcuteAngle: false)
    }
    func stroke(with event: DragEvent, lineWidth: CGFloat,
                movePointMaxDistance: CGFloat, movePointMaxTime: Double,
                splitAcuteAngle: Bool = true, isAppendLine: Bool = true) -> Bool {

        /* #
        let p = convertToCurrentLocal(point(from: event))
        let control = Line.Control(point: p, pressure: event.pressure)
        switch event.sendType {
        case .begin:
            let line = Line(controls: [control, control, control, control])
            self.strokeLine = line
            self.strokeOldLastBounds = line.strokeLastBoundingBox
            self.strokeControls = [control]
            self.strokeIsDrag = false
        case .sending:
            guard var line = strokeLine, p != strokeOldPoint else {
                return
            }
            self.strokeIsDrag = true
            var isSplit = false
            let lastControl = line.controls[line.controls.count - 3]
            if event.time - strokeOldTime > movePointMaxTime {
                isSplit = true
            } else if line.controls.count == 4 {
                let firstStrokeControl = strokeControls[0]
                var maxD = 0.0.cf, maxControl = firstStrokeControl
                for strokeControl in strokeControls {
                    let d = strokeControl.point.distanceWithLineSegment(ap: firstStrokeControl.point,
                                                                        bp: control.point)
                    if d > maxD {
                        maxD = d
                        maxControl = strokeControl
                    }
                }
                let cpMinP = maxControl.point.nearestWithLine(ap: firstStrokeControl.point,
                                                              bp: control.point)
                let cpControl = Line.Control(point: 2 * maxControl.point - cpMinP,
                                             pressure: maxControl.pressure)
                let bezier = Bezier2(p0: firstStrokeControl.point,
                                     cp: cpControl.point, p1: control.point)
                for strokeControl in strokeControls {
                    let d = bezier.minDistance²(at: strokeControl.point)
                    if d > movePointMaxDistance {
                        isSplit = true
                        break
                    }
                }
                if !isSplit {
                    line = line.withReplaced(cpControl, at: 1)
                }
            } else {
                
            }
            if isSplit {
                line = line.withInsert(lastControl, at: line.controls.count - 2)
                self.strokeLine = line
                let lastBounds = line.strokeLastBoundingBox
                setNeedsDisplay(inCurrentLocalBounds: lastBounds.union(strokeOldLastBounds)
                    .inset(by: -lineWidth / 2))
                self.strokeOldLastBounds = lastBounds
                self.strokeControls = [lastControl]
            }
            
            let midControl = line.controls[line.controls.count - 3].mid(control)
            let newLine = line.withReplaced(midControl, at: line.controls.count - 2)
                .withReplaced(midControl, at: line.controls.count - 1)
            self.strokeLine = newLine
            let lastBounds = newLine.strokeLastBoundingBox
            setNeedsDisplay(inCurrentLocalBounds: lastBounds.union(strokeOldLastBounds)
                .inset(by: -lineWidth / 2))
            self.strokeOldLastBounds = lastBounds
        case .end:
            guard let line = strokeLine else {
                return
            }
            self.strokeLine = nil
            guard strokeIsDrag else {
                return
            }
            let removedLine = line.withRemoveControl(at: line.controls.count - 2)
            let pressure = removedLine.controls[removedLine.controls.count - 1].pressure
            let newLine = removedLine.withReplaced(Line.Control(point: p, pressure: pressure),
                                                   at: removedLine.controls.count - 1)
            addLine(newLine, in: cut.editNode.editTrack.drawingItem.drawing, time: time)
        }
        self.strokeOldPoint = p
        self.strokeOldTime = event.time
*/
        let p = convertToCurrentLocal(point(from: event))
        switch event.sendType {
        case .begin:
            let firstControl = Line.Control(point: p, pressure: event.pressure)
            let line = Line(controls: [firstControl, firstControl, firstControl])
            strokeLine = line
            strokeOldPoint = p
            strokeOldTime = event.time
            strokeBeginTime = event.time
            strokeOldLastBounds = line.strokeLastBoundingBox
            strokeIsDrag = false
            strokeControls = [firstControl]
        case .sending:
            guard var line = strokeLine, p != strokeOldPoint else {
                return true
            }
            strokeIsDrag = true
            let ac = strokeControls.first!, bp = p, lc = strokeControls.last!, scale = scene.scale
            let control = Line.Control(point: p, pressure: event.pressure)
            strokeControls.append(control)
            if splitAcuteAngle && line.controls.count >= 4 {
                let c0 = line.controls[line.controls.count - 4]
                let c1 = line.controls[line.controls.count - 3], c2 = lc
                if c0.point != c1.point && c1.point != c2.point {
                    let dr = abs(CGPoint.differenceAngle(p0: c0.point, p1: c1.point, p2: c2.point))
                    if dr > strokeLowSplitAngle {
                        if dr > strokeSplitAngle {
                            line = line.withInsert(c1, at: line.controls.count - 2)
                            let  lastBounds = line.strokeLastBoundingBox
                            strokeLine = line
                            setNeedsDisplay(inCurrentLocalBounds: lastBounds.union(strokeOldLastBounds)
                                .inset(by: -lineWidth / 2))
                            strokeOldLastBounds = lastBounds
                        } else {
                            let t = 1 - (dr - strokeLowSplitAngle) / strokeSplitAngle
                            let tp = CGPoint.linear(c1.point, c2.point, t: t)
                            if c1.point != tp {
                                let newPressure = CGFloat.linear(c1.pressure, c2.pressure, t:  t)
                                line = line.withInsert(Line.Control(point: tp, pressure: newPressure),
                                                       at: line.controls.count - 1)
                                let  lastBounds = line.strokeLastBoundingBox
                                strokeLine = line
                                setNeedsDisplay(inCurrentLocalBounds: lastBounds
                                    .union(strokeOldLastBounds)
                                    .inset(by: -lineWidth / 2))
                                strokeOldLastBounds = lastBounds
                            }
                        }
                    }
                }
            }
            if line.controls[line.controls.count - 3].point != lc.point {
                for (i, sp) in strokeControls.enumerated() {
                    if i > 0 {
                        if sp.point.distanceWithLine(ap: ac.point, bp: bp) * scale > strokeDistance
                            || event.time - strokeOldTime > movePointMaxTime {
                            
                            line = line.withInsert(lc, at: line.controls.count - 2)
                            strokeLine = line
                            let lastBounds = line.strokeLastBoundingBox
                            setNeedsDisplay(inCurrentLocalBounds: lastBounds
                                .union(strokeOldLastBounds)
                                .inset(by: -lineWidth / 2))
                            strokeOldLastBounds = lastBounds
                            strokeControls = [lc]
                            strokeOldTime = event.time
                            break
                        }
                    }
                }
            }
            line = line.withReplaced(control, at: line.controls.count - 2)
            line = line.withReplaced(control, at: line.controls.count - 1)
            strokeLine = line
            let lastBounds = line.strokeLastBoundingBox
            setNeedsDisplay(inCurrentLocalBounds: lastBounds
                .union(strokeOldLastBounds)
                .inset(by: -lineWidth / 2))
            strokeOldLastBounds = lastBounds
            strokeOldPoint = p
        case .end:
            if let line = strokeLine {
                if strokeIsDrag {
                    let scale = scene.scale
                    func lastRevisionLine(line: Line) -> Line {
                        if line.controls.count > 3 {
                            let ap = line.controls[line.controls.count - 3].point, bp = p
                            let lp = line.controls[line.controls.count - 2].point
                            if !(lp.distanceWithLine(ap: ap, bp: bp) * scale > strokeDistance
                                || event.time - strokeOldTime > movePointMaxTime) {
                                
                                return line.withRemoveControl(at: line.controls.count - 2)
                            }
                        }
                        return line
                    }
                    var newLine = lastRevisionLine(line: line)
                    if event.time - strokeBeginTime < strokeShortTime && newLine.controls.count > 3 {
                        var maxD = 0.0.cf, maxControl = newLine.controls[0]
                        for control in newLine.controls {
                            let d = control.point.distanceWithLine(ap: newLine.firstPoint,
                                                                   bp: newLine.lastPoint)
                            if d * scale > maxD {
                                maxD = d
                                maxControl = control
                            }
                        }
                        let mcp = maxControl.point.nearestWithLine(ap: newLine.firstPoint,
                                                                   bp: newLine.lastPoint)
                        let cp = 2 * maxControl.point - mcp
                        
                        let b = Bezier2(p0: newLine.firstPoint, cp: cp, p1: newLine.lastPoint)
                        var isShort = true
                        newLine.allEditPoints { p, i in
                            let nd = sqrt(b.minDistance²(at: p))
                            if nd * scale > strokeShortLinearMaxDistance {
                                isShort = false
                            }
                        }
                        if isShort {
                            newLine = Line(
                                controls: [
                                    newLine.controls[0],
                                    Line.Control(point: cp, pressure: maxControl.pressure),
                                    newLine.controls[newLine.controls.count - 1]
                                ]
                            )
                        }
                    }
                    if isAppendLine {
                        let lastPressure = newLine.controls.last!.pressure
                        addLine(newLine.withReplaced(Line.Control(point: p, pressure: lastPressure),
                                                     at: newLine.controls.count - 1),
                                in: cut.editNode.editTrack.drawingItem.drawing, time: time)
                    } else {
                        strokeLine = newLine
                    }
                }
                if isAppendLine {
                    strokeLine = nil
                }
            }
        }
        return true
    }
    private func addLine(_ line: Line, in drawing: Drawing, time: Beat) {
        registerUndo { $0.removeLastLine(in: drawing, time: $1) }
        self.time = time
        drawing.lines.append(line)
        cutItem.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func removeLastLine(in drawing: Drawing, time: Beat) {
        registerUndo { [lastLine = drawing.lines.last!] in
            $0.addLine(lastLine, in: drawing, time: $1)
        }
        self.time = time
        drawing.lines.removeLast()
        cutItem.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func insertLine(_ line: Line, at i: Int, in drawing: Drawing, time: Beat) {
        registerUndo { $0.removeLine(at: i, in: drawing, time: $1) }
        self.time = time
        drawing.lines.insert(line, at: i)
        cutItem.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func removeLine(at i: Int, in drawing: Drawing, time: Beat) {
        let oldLine = drawing.lines[i]
        registerUndo { $0.insertLine(oldLine, at: i, in: drawing, time: $1) }
        self.time = time
        drawing.lines.remove(at: i)
        cutItem.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func setSelectionLineIndexes(_ lineIndexes: [Int], oldLineIndexes: [Int],
                                         in drawing: Drawing, time: Beat) {
        registerUndo { $0.setSelectionLineIndexes(oldLineIndexes, oldLineIndexes: lineIndexes,
                                                  in: drawing, time: $1) }
        self.time = time
        drawing.selectionLineIndexes = lineIndexes
        cutItem.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    
    func selectCell(at point: CGPoint) {
        let p = convertToCurrentLocal(point)
        let selectionCell = cut.editNode.rootCell.at(p, reciprocalScale: scene.reciprocalScale)
        if let selectionCell = selectionCell {
            if selectionCell.material.id != materialEditor.material.id {
                setMaterial(selectionCell.material, time: time)
            }
        } else {
            if cut.editNode.material != materialEditor.material {
                setMaterial(cut.editNode.material, time: time)
            }
        }
    }
    private func setMaterial(_ material: Material, time: Beat) {
        registerUndo { [om = materialEditor.material] in $0.setMaterial(om, time: $1) }
        self.time = time
        materialEditor.material = material
    }
    private func setSelectionCellItems(_ cellItems: [CellItem], oldCellItems: [CellItem],
                                       in track: NodeTrack, time: Beat) {
        registerUndo {
            $0.setSelectionCellItems(oldCellItems, oldCellItems: cellItems, in: track, time: $1)
        }
        self.time = time
        track.selectionCellItems = cellItems
        setNeedsDisplay()
        sceneDataModel?.isWrite = true
        setNeedsDisplay()
    }
    
    func insertPoint(with event: KeyInputEvent) -> Bool {
        let p = convertToCurrentLocal(point(from: event))
        guard let nearest = cut.editNode.nearestLine(at: p) else {
            return true
        }
        if let drawing = nearest.drawing {
            replaceLine(nearest.line.splited(at: nearest.pointIndex), oldLine: nearest.line,
                        at: nearest.lineIndex, in: drawing, time: time)
            cut.updateWithTime()
            updateEditView(with: p)
        } else if let cellItem = nearest.cellItem {
            let newGeometries = Geometry.geometriesWithSplitedControl(with: cellItem.keyGeometries,
                                                                      at: nearest.lineIndex,
                                                                      pointIndex: nearest.pointIndex)
            setGeometries(newGeometries, oldKeyGeometries: cellItem.keyGeometries,
                          in: cellItem, cut.editNode.editTrack, time: time)
            cut.updateWithTime()
            updateEditView(with: p)
        }
        return true
    }
    func removePoint(with event: KeyInputEvent) -> Bool {
        let p = convertToCurrentLocal(point(from: event))
        guard let nearest = cut.editNode.nearestLine(at: p) else {
            return true
        }
        if let drawing = nearest.drawing {
            if nearest.line.controls.count > 2 {
                replaceLine(
                    nearest.line.removedControl(at: nearest.pointIndex), oldLine: nearest.line,
                    at: nearest.lineIndex, in: drawing, time: time
                )
            } else {
                removeLine(at: nearest.lineIndex, in: drawing, time: time)
            }
            cut.updateWithTime()
            updateEditView(with: p)
        } else if let cellItem = nearest.cellItem {
            setGeometries(Geometry.geometriesWithRemovedControl(with: cellItem.keyGeometries,
                                                                atLineIndex: nearest.lineIndex,
                                                                index: nearest.pointIndex),
                          oldKeyGeometries: cellItem.keyGeometries,
                          in: cellItem, cut.editNode.editTrack, time: time)
            if cellItem.isEmptyKeyGeometries {
                removeCellItems([cellItem])
            }
            cut.updateWithTime()
            updateEditView(with: p)
        }
        return true
    }
    private func insert(_ control: Line.Control, at index: Int,
                        in drawing: Drawing, _ lineIndex: Int, time: Beat) {
        registerUndo { $0.removeControl(at: index, in: drawing, lineIndex, time: $1) }
        self.time = time
        drawing.lines[lineIndex] = drawing.lines[lineIndex].withInsert(control, at: index)
        cutItem.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func removeControl(at index: Int, in drawing: Drawing, _ lineIndex: Int, time: Beat) {
        let line = drawing.lines[lineIndex]
        registerUndo { [oc = line.controls[index]] in
            $0.insert(oc, at: index,
                                                                in: drawing, lineIndex, time: $1) }
        self.time = time
        drawing.lines[lineIndex] = line.withRemoveControl(at: index)
        cutItem.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    
    private var movePointNearest: Node.Nearest?, movePointOldPoint = CGPoint(), movePointIsSnap = false
    private let snapPointSnapDistance = 8.0.cf
    private var bezierSortedResult: Node.Nearest.BezierSortedResult?
    func movePoint(with event: DragEvent) -> Bool {
        return movePoint(with: event, isVertex: false)
    }
    func moveVertex(with event: DragEvent) -> Bool {
        return movePoint(with: event, isVertex: true)
    }
    func movePoint(with event: DragEvent, isVertex: Bool) -> Bool {
        let p = convertToCurrentLocal(point(from: event))
        switch event.sendType {
        case .begin:
            if let nearest = cut.editNode.nearest(at: p, isVertex: isVertex) {
                bezierSortedResult = nearest.bezierSortedResult(at: p)
                movePointNearest = nearest
                movePointIsSnap = false
            }
            updateEditView(with: p)
            movePointOldPoint = p
        case .sending:
            let dp = p - movePointOldPoint
            movePointIsSnap = movePointIsSnap ? true : event.pressure == 1
            
            if let nearest = movePointNearest {
                if nearest.drawingEdit != nil || nearest.cellItemEdit != nil {
                    movingPoint(with: nearest, dp: dp, in: cut.editNode.editTrack)
                } else {
                    if movePointIsSnap, let b = bezierSortedResult {
                        movingPoint(with: nearest, bezierSortedResult: b, dp: dp,
                                    isVertex: isVertex, in: cut.editNode.editTrack)
                    } else {
                        movingLineCap(with: nearest, dp: dp,
                                      isVertex: isVertex, in: cut.editNode.editTrack)
                    }
                }
            }
        case .end:
            let dp = p - movePointOldPoint
            if let nearest = movePointNearest {
                if nearest.drawingEdit != nil || nearest.cellItemEdit != nil {
                    movedPoint(with: nearest, dp: dp, in: cut.editNode.editTrack)
                } else {
                    if movePointIsSnap, let b = bezierSortedResult {
                        movedPoint(with: nearest, bezierSortedResult: b, dp: dp,
                                   isVertex: isVertex, in: cut.editNode.editTrack)
                    } else {
                        movedLineCap(with: nearest, dp: dp,
                                     isVertex: isVertex, in: cut.editNode.editTrack)
                    }
                }
                movePointIsSnap = false
                movePointNearest = nil
                bezierSortedResult = nil
                updateEditView(with: p)
            }
        }
        setNeedsDisplay()
        return true
    }
    private func movingPoint(with nearest: Node.Nearest, dp: CGPoint, in track: NodeTrack) {
        let snapD = snapPointSnapDistance / scene.scale
        if let e = nearest.drawingEdit {
            var control = e.line.controls[e.pointIndex]
            control.point = e.line.editPoint(withEditCenterPoint: nearest.point + dp,
                                             at: e.pointIndex)
            if movePointIsSnap && (e.pointIndex == 1 || e.pointIndex == e.line.controls.count - 2) {
                control.point = track.snapPoint(control.point,
                                                editLine: e.drawing.lines[e.lineIndex],
                                                editPointIndex: e.pointIndex,
                                                snapDistance: snapD)
            }
            e.drawing.lines[e.lineIndex] = e.line.withReplaced(control, at: e.pointIndex)
            let np = e.drawing.lines[e.lineIndex].editCenterPoint(at: e.pointIndex)
            editPoint = Node.EditPoint(nearestLine: e.drawing.lines[e.lineIndex],
                                       nearestPointIndex: e.pointIndex,
                                       lines: [e.drawing.lines[e.lineIndex]],
                                       point: np,
                                       isSnap: movePointIsSnap)
        } else if let e = nearest.cellItemEdit {
            let line = e.geometry.lines[e.lineIndex]
            var control = line.controls[e.pointIndex]
            control.point = line.editPoint(withEditCenterPoint: nearest.point + dp, at: e.pointIndex)
            if movePointIsSnap && (e.pointIndex == 1 || e.pointIndex == line.controls.count - 2) {
                control.point = track.snapPoint(control.point,
                                                editLine: e.cellItem.cell.geometry.lines[e.lineIndex],
                                                editPointIndex: e.pointIndex,
                                                snapDistance: snapD)
            }
            let newLine = line.withReplaced(control, at: e.pointIndex).autoPressure()
            
            let i = cut.editNode.editTrack.animation.editKeyframeIndex
            e.cellItem.replace(Geometry(lines: e.geometry.lines.withReplaced(newLine,
                                                                             at: e.lineIndex)), at: i)
            track.updateInterpolation()
            
            let np = e.cellItem.cell.geometry.lines[e.lineIndex].editCenterPoint(at: e.pointIndex)
            editPoint = Node.EditPoint(nearestLine: e.cellItem.cell.geometry.lines[e.lineIndex],
                                       nearestPointIndex: e.pointIndex,
                                       lines: [e.cellItem.cell.geometry.lines[e.lineIndex]],
                                       point: np, isSnap: movePointIsSnap)
            
        }
    }
    private func movedPoint(with nearest: Node.Nearest, dp: CGPoint, in track: NodeTrack) {
        let snapD = snapPointSnapDistance / scene.scale
        if let e = nearest.drawingEdit {
            var control = e.line.controls[e.pointIndex]
            control.point = e.line.editPoint(withEditCenterPoint: nearest.point + dp,
                                             at: e.pointIndex)
            if movePointIsSnap && (e.pointIndex == 1 || e.pointIndex == e.line.controls.count - 2) {
                control.point = track.snapPoint(control.point,
                                                editLine: e.drawing.lines[e.lineIndex],
                                                editPointIndex: e.pointIndex,
                                                snapDistance: snapD)
            }
            replaceLine(e.line.withReplaced(control, at: e.pointIndex), oldLine: e.line,
                        at: e.lineIndex, in: e.drawing, time: time)
        } else if let e = nearest.cellItemEdit {
            let line = e.geometry.lines[e.lineIndex]
            var control = line.controls[e.pointIndex]
            control.point = line.editPoint(withEditCenterPoint: nearest.point + dp,
                                           at: e.pointIndex)
            if movePointIsSnap && (e.pointIndex == 1 || e.pointIndex == line.controls.count - 2) {
                control.point = track.snapPoint(control.point,
                                                editLine: e.cellItem.cell.geometry.lines[e.lineIndex],
                                                editPointIndex: e.pointIndex,
                                                snapDistance: snapD)
            }
            let newLine = line.withReplaced(control, at: e.pointIndex).autoPressure()
            set(Geometry(lines: e.geometry.lines.withReplaced(newLine, at: e.lineIndex)),
                old: e.geometry,
                at: cut.editNode.editTrack.animation.editKeyframeIndex,
                in: e.cellItem,
                time: time)
        }
    }
    
    private func movingPoint(with nearest: Node.Nearest,
                             bezierSortedResult b: Node.Nearest.BezierSortedResult,
                             dp: CGPoint, isVertex: Bool, in track: NodeTrack) {
        let snapD = snapPointSnapDistance * scene.reciprocalScale
        let grid = 5 * scene.reciprocalScale
        var np = track.snapPoint(nearest.point + dp, with: b, snapDistance: snapD, grid: grid)
        if let e = nearest.drawingEditLineCap, let drawing = b.drawing {
            var newLines = e.lines
            if b.lineCap.line.controls.count == 2 {
                let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                var control = b.lineCap.line.controls[pointIndex]
                control.point = track.snapPoint(
                    np, editLine: drawing.lines[b.lineCap.lineIndex],
                    editPointIndex: pointIndex, snapDistance: snapD
                )
                newLines[b.lineCap.lineIndex] = b.lineCap.line.withReplaced(control, at: pointIndex)
                np = control.point
            } else if isVertex {
                newLines[b.lineCap.lineIndex] = b.lineCap.line.warpedWith(
                    deltaPoint: np - nearest.point, isFirst: b.lineCap.isFirst)
            } else {
                let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                var control = b.lineCap.line.controls[pointIndex]
                control.point = np
                newLines[b.lineCap.lineIndex] = newLines[b.lineCap.lineIndex].withReplaced(
                    control, at: b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1)
            }
            drawing.lines = newLines
            editPoint = Node.EditPoint(nearestLine: drawing.lines[b.lineCap.lineIndex],
                                       nearestPointIndex: b.lineCap.pointIndex,
                                       lines: e.drawingCaps.map { drawing.lines[$0.lineIndex] },
                                       point: np,
                                       isSnap: movePointIsSnap)
        } else if let cellItem = b.cellItem, let geometry = b.geometry {
            for editLineCap in nearest.cellItemEditLineCaps {
                if editLineCap.cellItem == cellItem {
                    if b.lineCap.line.controls.count == 2 {
                        let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                        var control = b.lineCap.line.controls[pointIndex]
                        let line = cellItem.cell.geometry.lines[b.lineCap.lineIndex]
                        control.point = track.snapPoint(np,
                                                        editLine: line,
                                                        editPointIndex: pointIndex,
                                                        snapDistance: snapD)
                        let newBLine = b.lineCap.line.withReplaced(control,
                                                                   at: pointIndex).autoPressure()
                        let newLines = geometry.lines.withReplaced(newBLine,
                                                                   at: b.lineCap.lineIndex)
                        cellItem.cell.geometry = Geometry(lines: newLines)
                        np = control.point
                    } else if isVertex {
                        let newLine = b.lineCap.line.warpedWith(deltaPoint: np - nearest.point,
                                                                isFirst: b.lineCap.isFirst)
                            .autoPressure()
                        cellItem.cell.geometry = Geometry(
                            lines: geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)
                        )
                    } else {
                        let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                        var control = geometry.lines[b.lineCap.lineIndex].controls[pointIndex]
                        control.point = np
                        let newLine = b.lineCap.line.withReplaced(control,
                                                                  at: pointIndex).autoPressure()
                        let newLines = geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)
                        
                        let i = cut.editNode.editTrack.animation.editKeyframeIndex
                        cellItem.replace(Geometry(lines: newLines), at: i)
                    }
                } else {
                    editLineCap.cellItem.cell.geometry = editLineCap.geometry
                }
            }
            track.updateInterpolation()
            
            let newLines = nearest.cellItemEditLineCaps.reduce(into: [Line]()) {
                $0 += $1.caps.map { cellItem.cell.geometry.lines[$0.lineIndex] }
            }
            editPoint = Node.EditPoint(nearestLine: cellItem.cell.geometry.lines[b.lineCap.lineIndex],
                                       nearestPointIndex: b.lineCap.pointIndex,
                                       lines: newLines,
                                       point: np,
                                       isSnap: movePointIsSnap)
        }
    }
    private func movedPoint(with nearest: Node.Nearest,
                            bezierSortedResult b: Node.Nearest.BezierSortedResult,
                            dp: CGPoint, isVertex: Bool, in track: NodeTrack) {
        let snapD = snapPointSnapDistance * scene.reciprocalScale
        let grid = 5 * scene.reciprocalScale
        let np = track.snapPoint(nearest.point + dp, with: b, snapDistance: snapD, grid: grid)
        if let e = nearest.drawingEditLineCap, let drawing = b.drawing {
            var newLines = e.lines
            if b.lineCap.line.controls.count == 2 {
                let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                var control = b.lineCap.line.controls[pointIndex]
                control.point = track.snapPoint(np,
                                                editLine: drawing.lines[b.lineCap.lineIndex],
                                                editPointIndex: pointIndex,
                                                snapDistance: snapD)
                newLines[b.lineCap.lineIndex] = b.lineCap.line.withReplaced(control, at: pointIndex)
            } else if isVertex {
                newLines[b.lineCap.lineIndex] = b.lineCap.line.warpedWith(
                    deltaPoint: np - nearest.point, isFirst: b.lineCap.isFirst)
            } else {
                let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                var control = b.lineCap.line.controls[pointIndex]
                control.point = np
                newLines[b.lineCap.lineIndex] = newLines[b.lineCap.lineIndex].withReplaced(
                    control, at: b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                )
            }
            setLines(newLines, oldLines: e.lines, drawing: drawing, time: time)
        } else if let cellItem = b.cellItem, let geometry = b.geometry {
            for editLineCap in nearest.cellItemEditLineCaps {
                guard editLineCap.cellItem == cellItem else {
                    editLineCap.cellItem.cell.geometry = editLineCap.geometry
                    continue
                }
                if b.lineCap.line.controls.count == 2 {
                    let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                    var control = b.lineCap.line.controls[pointIndex]
                    let editLine = cellItem.cell.geometry.lines[b.lineCap.lineIndex]
                    control.point = track.snapPoint(np,
                                                    editLine: editLine,
                                                    editPointIndex: pointIndex,
                                                    snapDistance: snapD)
                    let newLine = b.lineCap.line.withReplaced(control,
                                                              at: pointIndex).autoPressure()
                    let newLines = geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)
                    set(Geometry(lines: newLines),
                        old: geometry,
                        at: track.animation.editKeyframeIndex,
                        in: cellItem, time: time)
                } else if isVertex {
                    let newLine = b.lineCap.line.warpedWith(deltaPoint: np - nearest.point,
                                                            isFirst: b.lineCap.isFirst).autoPressure()
                    let bLines = geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)
                    set(Geometry(lines: bLines),
                        old: geometry,
                        at: track.animation.editKeyframeIndex,
                        in: cellItem, time: time)
                } else {
                    let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                    var control = geometry.lines[b.lineCap.lineIndex].controls[pointIndex]
                    control.point = np
                    let newLine = b.lineCap.line.withReplaced(control, at: pointIndex).autoPressure()
                    let newLines = geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)
                    set(Geometry(lines: newLines),
                        old: geometry,
                        at: track.animation.editKeyframeIndex,
                        in: cellItem, time: time)
                }
            }
        }
        bezierSortedResult = nil
    }
    
    func movingLineCap(with nearest: Node.Nearest, dp: CGPoint,
                       isVertex: Bool, in track: NodeTrack) {
        let np = nearest.point + dp
        var editPointLines = [Line]()
        if let e = nearest.drawingEditLineCap {
            var newLines = e.drawing.lines
            if isVertex {
                e.drawingCaps.forEach {
                    newLines[$0.lineIndex] = $0.line.warpedWith(deltaPoint: dp,
                                                                isFirst: $0.isFirst)
                }
            } else {
                for cap in e.drawingCaps {
                    var control = cap.isFirst ?
                        cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
                    control.point = np
                    newLines[cap.lineIndex] = newLines[cap.lineIndex]
                        .withReplaced(control, at: cap.isFirst ? 0 : cap.line.controls.count - 1)
                }
            }
            e.drawing.lines = newLines
            editPointLines = e.drawingCaps.map { newLines[$0.lineIndex] }
        }
        
        for editLineCap in nearest.cellItemEditLineCaps {
            var newLines = editLineCap.geometry.lines
            if isVertex {
                for cap in editLineCap.caps {
                    newLines[cap.lineIndex] = cap.line.warpedWith(deltaPoint: dp,
                                                                  isFirst: cap.isFirst).autoPressure()
                }
            } else {
                for cap in editLineCap.caps {
                    var control = cap.isFirst ? 
                        cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
                    control.point = np
                    newLines[cap.lineIndex] = newLines[cap.lineIndex]
                        .withReplaced(control, at: cap.isFirst ?
                            0 : cap.line.controls.count - 1).autoPressure()
                }
            }
            
            let i = cut.editNode.editTrack.animation.editKeyframeIndex
            editLineCap.cellItem.replace(Geometry(lines: newLines), at: i)
            
            editPointLines += editLineCap.caps.map { newLines[$0.lineIndex] }
        }
        
        track.updateInterpolation()
        
        if let b = bezierSortedResult {
            if let cellItem = b.cellItem {
                let newLine = cellItem.cell.geometry.lines[b.lineCap.lineIndex]
                editPoint = Node.EditPoint(nearestLine: newLine,
                                           nearestPointIndex: b.lineCap.pointIndex,
                                           lines: Array(Set(editPointLines)),
                                           point: np, isSnap: movePointIsSnap)
            } else if let drawing = b.drawing {
                let newLine = drawing.lines[b.lineCap.lineIndex]
                editPoint = Node.EditPoint(nearestLine: newLine,
                                           nearestPointIndex: b.lineCap.pointIndex,
                                           lines: Array(Set(editPointLines)),
                                           point: np, isSnap: movePointIsSnap)
            }
        }
    }
    func movedLineCap(with nearest: Node.Nearest, dp: CGPoint, isVertex: Bool, in track: NodeTrack) {
        let np = nearest.point + dp
        if let e = nearest.drawingEditLineCap {
            var newLines = e.drawing.lines
            if isVertex {
                for cap in e.drawingCaps {
                    newLines[cap.lineIndex] = cap.line.warpedWith(deltaPoint: dp,
                                                                  isFirst: cap.isFirst)
                }
            } else {
                for cap in e.drawingCaps {
                    var control = cap.isFirst ?
                        cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
                    control.point = np
                    newLines[cap.lineIndex] = newLines[cap.lineIndex]
                        .withReplaced(control, at: cap.isFirst ? 0 : cap.line.controls.count - 1)
                }
            }
            setLines(newLines, oldLines: e.lines, drawing: e.drawing, time: time)
        }
        for editLineCap in nearest.cellItemEditLineCaps {
            var newLines = editLineCap.geometry.lines
            if isVertex {
                for cap in editLineCap.caps {
                    newLines[cap.lineIndex] = cap.line.warpedWith(deltaPoint: dp,
                                                                  isFirst: cap.isFirst).autoPressure()
                }
            } else {
                for cap in editLineCap.caps {
                    var control = cap.isFirst ?
                        cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
                    control.point = np
                    newLines[cap.lineIndex] = newLines[cap.lineIndex]
                        .withReplaced(control, at: cap.isFirst ?
                            0 : cap.line.controls.count - 1).autoPressure()
                }
            }
            set(Geometry(lines: newLines),
                old: editLineCap.geometry,
                at: track.animation.editKeyframeIndex,
                in: editLineCap.cellItem, time: time)
        }
    }
    
    private func replaceLine(_ line: Line, oldLine: Line, at i: Int, in drawing: Drawing, time: Beat) {
        registerUndo { $0.replaceLine(oldLine, oldLine: line, at: i, in: drawing, time: $1) }
        self.time = time
        drawing.lines[i] = line
        cutItem.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    
    func clipCellInSelection(with event: KeyInputEvent) {
        clipCellInSelection()
    }
    func clipCellInSelection() {
        guard let fromCell = editCell else {
            return
        }
        let selectionCells = cut.editNode.allSelectionCellItemsWithNoEmptyGeometry.map { $0.cell }
        if selectionCells.isEmpty {
            if !cut.editNode.rootCell.children.contains(fromCell) {
                let fromParents = cut.editNode.rootCell.parents(with: fromCell)
                moveCell(fromCell,
                         from: fromParents,
                         to: [(cut.editNode.rootCell, cut.editNode.rootCell.children.count)],
                         time: time)
            }
        } else if !selectionCells.contains(fromCell) {
            let fromChildrens = fromCell.allCells
            var newFromParents = cut.editNode.rootCell.parents(with: fromCell)
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
            }
        }
    }
    
    private var moveZOldPoint = CGPoint()
    private var moveZCellTuple: (indexes: [Int], parent: Cell, oldChildren: [Cell])?
    private var moveZMinDeltaIndex = 0, moveZMaxDeltaIndex = 0
    private weak var moveZOldCell: Cell?
    func moveZ(with event: DragEvent) -> Bool {
        let p = point(from: event), cp = convertToCurrentLocal(point(from: event))
        switch event.sendType {
        case .begin:
            let ict = cut.editNode.indicatedCellsTuple(with : cp,
                                                       reciprocalScale: scene.reciprocalScale)
            guard !ict.cellItems.isEmpty else {
                return true
            }
            switch ict.type {
            case .none:
                break
            case .indicated:
                let cell = ict.cellItems.first!.cell
                cut.editNode.rootCell.depthFirstSearch(duplicate: false) { parent, aCell in
                    if cell === aCell, let index = parent.children.index(of: cell) {
                        moveZCellTuple = ([index], parent, parent.children)
                        moveZMinDeltaIndex = -index
                        moveZMaxDeltaIndex = parent.children.count - 1 - index
                    }
                }
            case .selected:
                let firstCell = ict.cellItems[0].cell
                let cutAllSelectionCells
                    = cut.editNode.allSelectionCellItemsWithNoEmptyGeometry.map { $0.cell }
                var firstParent: Cell?
                cut.editNode.rootCell.depthFirstSearch(duplicate: false) { parent, cell in
                    if cell === firstCell {
                        firstParent = parent
                    }
                }
                
                if let firstParent = firstParent {
                    var indexes = [Int]()
                    cut.editNode.rootCell.depthFirstSearch(duplicate: false) { parent, cell in
                        if cutAllSelectionCells.contains(cell) && firstParent === parent,
                            let index = parent.children.index(of: cell) {
                            
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
            self.editZ?.point = cp
            if let moveZCellTuple = moveZCellTuple {
                let deltaIndex = Int((p.y - moveZOldPoint.y) / cut.editNode.editZHeight)
                var children = moveZCellTuple.oldChildren
                let indexes = moveZCellTuple.indexes.sorted {
                    deltaIndex < 0 ? $0 < $1 : $0 > $1
                }
                for i in indexes {
                    let cell = children[i]
                    children.remove(at: i)
                    children.insert(cell, at: (i + deltaIndex)
                        .clip(min: 0, max: moveZCellTuple.oldChildren.count - 1))
                }
                moveZCellTuple.parent.children = children
            }
        case .end:
            if let moveZCellTuple = moveZCellTuple {
                let deltaIndex = Int((p.y - moveZOldPoint.y) / cut.editNode.editZHeight)
                var children = moveZCellTuple.oldChildren
                let indexes = moveZCellTuple.indexes.sorted {
                    deltaIndex < 0 ? $0 < $1 : $0 > $1
                }
                for i in indexes {
                    let cell = children[i]
                    children.remove(at: i)
                    children.insert(cell, at: (i + deltaIndex)
                        .clip(min: 0, max: moveZCellTuple.oldChildren.count - 1))
                }
                setChildren(children, oldChildren: moveZCellTuple.oldChildren,
                            inParent: moveZCellTuple.parent, time: time)
                self.moveZCellTuple = nil
            }
        }
        setNeedsDisplay()
        return true
    }
    private func setChildren(_ children: [Cell], oldChildren: [Cell],
                             inParent parent: Cell, time: Beat) {
        registerUndo { $0.setChildren(oldChildren, oldChildren: children, inParent: parent, time: $1) }
        self.time = time
        parent.children = children
        cutItem.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        setNeedsDisplay()
    }
    
    private var moveSelection = Node.Selection()
    private var transformBounds = CGRect(), moveOldPoint = CGPoint(), moveTransformOldPoint = CGPoint()
    enum TransformEditType {
        case move, warp, transform
    }
    func moveInStrokable(with event: DragEvent) -> Bool {
        return move(with: event, type: .move)
    }
    func transform(with event: DragEvent) -> Bool {
        return move(with: event, type: .transform)
    }
    func warp(with event: DragEvent) -> Bool {
        return move(with: event, type: .warp)
    }
    let moveTransformAngleTime = 0.1
    var moveTransformAngleOldTime = 0.0
    var moveTransformAnglePoint = CGPoint(), moveTransformAngleOldPoint = CGPoint()
    var isMoveTransformAngle = false
    func move(with event: DragEvent, type: TransformEditType) -> Bool {
        let viewP = point(from: event)
        let p = convertToCurrentLocal(viewP)
        func affineTransform() -> CGAffineTransform {
            switch type {
            case .move:
                return CGAffineTransform(translationX: p.x - moveOldPoint.x, y: p.y - moveOldPoint.y)
            case .warp:
                if let editTransform = editTransform {
                    return cut.editNode.warpAffineTransform(with: editTransform)
                } else {
                    return CGAffineTransform.identity
                }
            case .transform:
                if let editTransform = editTransform {
                    return cut.editNode.transformAffineTransform(with: editTransform)
                } else {
                    return CGAffineTransform.identity
                }
            }
        }
        switch event.sendType {
        case .begin:
            moveSelection = cut.editNode.selection(with: p, reciprocalScale: scene.reciprocalScale)
            if type != .move {
                self.editTransform = editTransform(at: p)
                self.moveTransformAngleOldTime = event.time
                self.moveTransformAngleOldPoint = p
                self.isMoveTransformAngle = false
                self.moveTransformOldPoint = p
                
                if type == .warp {
                    let mm = minMaxPointFrom(p)
                    self.minWarpDistance = mm.minDistance
                    self.maxWarpDistance = mm.maxDistance
                }
            }
            moveOldPoint = p
        case .sending:
            if type != .move {
                if var editTransform = editTransform {
                    
                    func newEditTransform(with lines: [Line]) -> Node.EditTransform {
                        var ps = [CGPoint]()
                        for line in lines {
                            line.allEditPoints({ (p, _) in
                                ps.append(p)
                            })
                            line.allEditPoints { (p, i) in ps.append(p) }
                        }
                        let rb = RotateRect(convexHullPoints: CGPoint.convexHullPoints(with: ps))
                        let np = rb.convertToLocal(p: p)
                        let tx = np.x / rb.size.width, ty = np.y / rb.size.height
                        if ty < tx {
                            if ty < 1 - tx {
                                let ap = editTransform.isCenter ? rb.midXMidYPoint : rb.midXMaxYPoint
                                return Node.EditTransform(rotateRect: rb,
                                                          anchorPoint: ap,
                                                          point: rb.midXMinYPoint,
                                                          oldPoint: rb.midXMinYPoint,
                                                          isCenter: editTransform.isCenter)
                            } else {
                                let ap = editTransform.isCenter ? rb.midXMidYPoint : rb.minXMidYPoint
                                return Node.EditTransform(rotateRect: rb,
                                                          anchorPoint: ap,
                                                          point: rb.maxXMidYPoint,
                                                          oldPoint: rb.maxXMidYPoint,
                                                          isCenter: editTransform.isCenter)
                            }
                        } else {
                            if ty < 1 - tx {
                                let ap = editTransform.isCenter ? rb.midXMidYPoint : rb.maxXMidYPoint
                                return Node.EditTransform(rotateRect: rb,
                                                          anchorPoint: ap,
                                                          point: rb.minXMidYPoint,
                                                          oldPoint: rb.minXMidYPoint,
                                                          isCenter: editTransform.isCenter)
                            } else {
                                let ap = editTransform.isCenter ? rb.midXMidYPoint : rb.midXMinYPoint
                                return Node.EditTransform(rotateRect: rb,
                                                          anchorPoint: ap,
                                                          point: rb.midXMaxYPoint,
                                                          oldPoint: rb.midXMaxYPoint,
                                                          isCenter: editTransform.isCenter)
                            }
                        }
                    }
                    if moveSelection.cellTuples.isEmpty {
                        if moveSelection.drawingTuple?.lineIndexes.isEmpty ?? true {
                        } else if let moveDrawingTuple = moveSelection.drawingTuple {
                            let net = newEditTransform(with: moveDrawingTuple.lineIndexes.map {
                                moveDrawingTuple.drawing.lines[$0]
                            })
                            let ap = editTransform.isCenter ?
                                net.anchorPoint : editTransform.anchorPoint
                            editTransform = Node.EditTransform(rotateRect: net.rotateRect,
                                                               anchorPoint: ap,
                                                               point: editTransform.point,
                                                               oldPoint: editTransform.oldPoint,
                                                               isCenter: editTransform.isCenter)
                        }
                    } else {
                        let lines = moveSelection.cellTuples.reduce(into: [Line]()) {
                            $0 += $1.cellItem.cell.geometry.lines
                        }
                        let net = newEditTransform(with: lines)
                        let ap = editTransform.isCenter ? net.anchorPoint : editTransform.anchorPoint
                        editTransform = Node.EditTransform(rotateRect: net.rotateRect,
                                                           anchorPoint: ap,
                                                           point: editTransform.point,
                                                           oldPoint: editTransform.oldPoint,
                                                           isCenter: editTransform.isCenter)
                    }
                    
                    let ep = p - moveTransformOldPoint + editTransform.oldPoint
                    self.editTransform = editTransform.with(ep)
                }
            }
            if type == .warp {
                if let editTransform = editTransform, editTransform.isCenter {
                    distanceWarp(with: event)
                    return true
                }
            }
            if !moveSelection.isEmpty {
                let affine = affineTransform()
                if let mdp = moveSelection.drawingTuple {
                    var newLines = mdp.oldLines
                    for index in mdp.lineIndexes {
                        newLines.remove(at: index)
                        newLines.insert(mdp.oldLines[index].applying(affine), at: index)
                    }
                    mdp.drawing.lines = newLines
                }
                for mcp in moveSelection.cellTuples {
                    mcp.cellItem.replace(mcp.geometry.applying(affine),
                                         at: mcp.track.animation.editKeyframeIndex)
                }
                cut.updateWithTime()
            }
        case .end:
            if type == .warp {
                if editTransform?.isCenter ?? false {
                    distanceWarp(with: event)
                    editTransform = nil
                    return true
                }
            }
            if !moveSelection.isEmpty {
                let affine = affineTransform()
                if let mdp = moveSelection.drawingTuple {
                    var newLines = mdp.oldLines
                    for index in mdp.lineIndexes {
                        newLines[index] = mdp.oldLines[index].applying(affine)
                    }
                    setLines(newLines, oldLines: mdp.oldLines, drawing: mdp.drawing, time: time)
                }
                for mcp in moveSelection.cellTuples {
                    set(mcp.geometry.applying(affine),
                        old: mcp.geometry,
                        at: mcp.track.animation.editKeyframeIndex, in:mcp.cellItem, time: time)
                }
                cut.updateWithTime()
                moveSelection = Node.Selection()
            }
            self.editTransform = nil
        }
        setNeedsDisplay()
        return true
    }
    
    private var minWarpDistance = 0.0.cf, maxWarpDistance = 0.0.cf
    func distanceWarp(with event: DragEvent) {
        let p = convertToCurrentLocal(point(from: event))
        switch event.sendType {
        case .begin:
            moveSelection = cut.editNode.selection(with: p, reciprocalScale: scene.reciprocalScale)
            let mm = minMaxPointFrom(p)
            moveOldPoint = p
            minWarpDistance = mm.minDistance
            maxWarpDistance = mm.maxDistance
        case .sending:
            if !moveSelection.isEmpty {
                let dp = p - moveOldPoint
                if let wdp = moveSelection.drawingTuple {
                    var newLines = wdp.oldLines
                    for i in wdp.lineIndexes {
                        newLines[i] = wdp.oldLines[i].warpedWith(deltaPoint: dp,
                                                                 editPoint: moveOldPoint,
                                                                 minDistance: minWarpDistance,
                                                                 maxDistance: maxWarpDistance)
                    }
                    wdp.drawing.lines = newLines
                }
                for wcp in moveSelection.cellTuples {
                    wcp.cellItem.replace(wcp.geometry.warpedWith(deltaPoint: dp,
                                                                 editPoint: moveOldPoint,
                                                                 minDistance: minWarpDistance,
                                                                 maxDistance: maxWarpDistance),
                                         at: wcp.track.animation.editKeyframeIndex)
                }
            }
        case .end:
            if !moveSelection.isEmpty {
                let dp = p - moveOldPoint
                if let wdp = moveSelection.drawingTuple {
                    var newLines = wdp.oldLines
                    for i in wdp.lineIndexes {
                        newLines[i] = wdp.oldLines[i].warpedWith(deltaPoint: dp,
                                                                 editPoint: moveOldPoint,
                                                                 minDistance: minWarpDistance,
                                                                 maxDistance: maxWarpDistance)
                    }
                    setLines(newLines, oldLines: wdp.oldLines, drawing: wdp.drawing, time: time)
                }
                for wcp in moveSelection.cellTuples {
                    set(wcp.geometry.warpedWith(deltaPoint: dp, editPoint: moveOldPoint,
                                                minDistance: minWarpDistance,
                                                maxDistance: maxWarpDistance),
                        old: wcp.geometry,
                        at: wcp.track.animation.editKeyframeIndex, in: wcp.cellItem, time: time)
                }
                moveSelection = Node.Selection()
            }
        }
        setNeedsDisplay()
    }
    func minMaxPointFrom(_ p: CGPoint
        ) -> (minDistance: CGFloat, maxDistance: CGFloat, minPoint: CGPoint, maxPoint: CGPoint) {
        
        var minDistance = CGFloat.infinity, maxDistance = 0.0.cf
        var minPoint = CGPoint(), maxPoint = CGPoint()
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
        if let wdp = moveSelection.drawingTuple {
            for lineIndex in wdp.lineIndexes {
                minMaxPointFrom(wdp.drawing.lines[lineIndex])
            }
        }
        for wcp in moveSelection.cellTuples {
            for line in wcp.cellItem.cell.geometry.lines {
                minMaxPointFrom(line)
            }
        }
        return (sqrt(minDistance), sqrt(maxDistance), minPoint, maxPoint)
    }
    
    var isUseScrollView = false
    func scroll(with event: ScrollEvent) -> Bool {
        guard isUseScrollView else {
            return false
        }
        let translation = viewTransform.translation + event.scrollDeltaPoint
        self.viewTransform = viewTransform.with(translation: translation)
        updateEditView(with: convertToCurrentLocal(point(from: event)))
        return true
    }
    
    var minScale = 0.00001.cf, blockScale = 1.0.cf, maxScale = 64.0.cf
    var correctionScale = 1.28.cf, correctionRotation = 1.0.cf / (4.2 * (.pi))
    private var isBlockScale = false, oldScale = 0.0.cf
    func zoom(with event: PinchEvent) -> Bool {
        let scale = viewTransform.scale.x
        switch event.sendType {
        case .begin:
            oldScale = scale
            isBlockScale = false
        case .sending:
            if !isBlockScale {
                zoom(at: point(from: event)) {
                    let newScale = (scale * pow(event.magnification * correctionScale + 1, 2))
                        .clip(min: minScale, max: maxScale)
                    if blockScale.isOver(old: scale, new: newScale) {
                        isBlockScale = true
                    }
                    self.viewTransform = viewTransform.with(scale: newScale)
                }
            }
        case .end:
            if isBlockScale {
                zoom(at: point(from: event)) {
                    self.viewTransform = viewTransform.with(scale: blockScale)
                }
            }
        }
        return true
    }
    var blockRotations: [CGFloat] = [-.pi, 0.0, .pi]
    private var isBlockRotation = false, blockRotation = 0.0.cf, oldRotation = 0.0.cf
    func rotate(with event: RotateEvent) -> Bool {
        let rotation = viewTransform.rotation
        switch event.sendType {
        case .begin:
            oldRotation = rotation
            isBlockRotation = false
        case .sending:
            if !isBlockRotation {
                zoom(at: point(from: event)) {
                    let oldRotation = rotation
                    let newRotation = rotation + event.rotation * correctionRotation
                    for br in blockRotations {
                        if br.isOver(old: oldRotation, new: newRotation) {
                            isBlockRotation = true
                            blockRotation = br
                            break
                        }
                    }
                    self.viewTransform = viewTransform.with(rotation: newRotation.clipRotation)
                }
            }
        case .end:
            if isBlockRotation {
                zoom(at: point(from: event)) {
                    self.viewTransform = viewTransform.with(rotation: blockRotation)
                }
            }
        }
        return true
    }
    func resetView(with event: DoubleTapEvent) -> Bool {
        guard !viewTransform.isIdentity else {
            return false
        }
        viewTransform = Transform()
        updateEditView(with: convertToCurrentLocal(point(from: event)))
        return true
    }
    func zoom(at p: CGPoint, handler: () -> ()) {
        let point = convertToCurrentLocal(p)
        handler()
        let newPoint = convertFromCurrentLocal(point)
        let translation = viewTransform.translation - (newPoint - p)
        self.viewTransform = viewTransform.with(translation: translation)
    }
    
    func lookUp(with event: TapEvent) -> Referenceable? {
        let indicatedCellsTuple = cut.editNode.indicatedCellsTuple(with:
            convertToCurrentLocal(point(from: event)), reciprocalScale: scene.reciprocalScale
        )
        if let cellItem = indicatedCellsTuple.cellItems.first {
            return cellItem.cell
        } else {
            return self
        }
    }
}
