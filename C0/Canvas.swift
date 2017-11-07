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
//再生中の時間移動
//Playerを別の場所で常に表示

import Foundation
import QuartzCore
import AVFoundation

protocol PlayerDelegate: class {
    func endPlay(_ player: Player)
}
final class Player: LayerRespondable {
    static let name = Localization(english: "Player", japanese: "プレイヤー")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: [])
        }
    }
    
    var undoManager: UndoManager?
    
    weak var delegate: PlayerDelegate?
    
    var layer = CALayer.interfaceLayer(), drawLayer = DrawLayer()
    var playCutItem: CutItem? {
        didSet {
            if let playCutItem = playCutItem {
                self.cut = playCutItem.cut.deepCopy
            }
        }
    }
    var cut = Cut()
    var time: Q {
        get {
            return cut.time
        } set {
            cut.time = newValue
        }
    }
    var scene = Scene()
    func draw(in ctx: CGContext) {
        ctx.concatenate(screenTransform)
        cut.rootNode.draw(
            scene: scene, viewType: .preview,
            scale: scene.scale, rotation: scene.viewTransform.rotation,
            in: ctx
        )
    }
    
    var outsidePadding = 100.0.cf, timeLabelWidth = 40.0.cf
    let timeLabel = Label(string: "00:00", color: .smallFont, backgroundColor: .playBorder, height: 30)
    let cutLabel = Label(string: "C1", color: .smallFont, backgroundColor: .playBorder, height: 30)
    let frameRateLabel = Label(string: "0fps", color: .smallFont, backgroundColor: .playBorder, height: 30)
    
    init() {
        layer.backgroundColor = Color.playBorder.cgColor
        drawLayer.borderWidth = 0
        drawLayer.drawBlock = { [unowned self] ctx in
            self.draw(in: ctx)
        }
        children = [timeLabel, cutLabel, frameRateLabel]
        update(withChildren: children, oldChildren: [])
        layer.addSublayer(drawLayer)
    }
    
    var screenTransform = CGAffineTransform.identity
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            layer.frame = newValue
            screenTransform = CGAffineTransform(translationX: bounds.midX, y: bounds.midY)
            layer.bounds.origin = CGPoint(x: -outsidePadding, y: -outsidePadding)
            drawLayer.frame = CGRect(origin: CGPoint(), size: scene.frame.size)
            let alltw = timeLabelWidth*3
            timeLabel.frame = CGRect(
                x: bounds.midX - floor(alltw/2), y: bounds.origin.y/2 - 15,
                width: timeLabelWidth, height: 30
            )
            cutLabel.frame = CGRect(
                x: bounds.midX - floor(alltw/2) + timeLabelWidth, y: bounds.origin.y/2 - 15,
                width: timeLabelWidth, height: 30
            )
            frameRateLabel.frame = CGRect(
                x: bounds.midX - floor(alltw/2) + timeLabelWidth*2, y: bounds.origin.y/2 - 15,
                width: timeLabelWidth, height: 30
            )
        }
    }
    
    var editCutItem = CutItem()
    var audioPlayer: AVAudioPlayer?
    
    var contentsScale: CGFloat {
        get {
            return layer.contentsScale
        } set {
            layer.contentsScale = newValue
            drawLayer.contentsScale = newValue
            allChildren { ($0 as? LayerRespondable)?.layer.contentsScale = newValue }
        }
    }
    
    private var timer = LockTimer(), oldPlayCutItem: CutItem?, oldPlayTime = Q(0), oldTimestamp = 0.0
    private var playDrawCount = 0, playCutIndex = 0, playSecond = 0, playFrameRate = 0, delayTolerance = 0.5
    var isPlaying = false {
        didSet {
            if isPlaying {
                playCutItem = editCutItem
                oldPlayCutItem = editCutItem
                time = editCutItem.cut.time
                oldPlayTime = editCutItem.cut.time
                oldTimestamp = CFAbsoluteTimeGetCurrent()
                let t = currentPlayTime
                playSecond = t.integralPart
                playCutIndex = scene.editCutItemIndex
                playFrameRate = scene.frameRate
                playDrawCount = 0
                timeLabel.textLine.string = minuteSecondString(withSecond: playSecond, frameRate: scene.frameRate)
                cutLabel.textLine.string = "C\(playCutIndex + 1)"
                frameRateLabel.textLine.string = "\(playFrameRate)fps"
                frameRateLabel.textLine.color = playFrameRate != scene.frameRate ? Color.warning : Color.smallFont
                audioPlayer?.currentTime = t.doubleValue
                audioPlayer?.play()
                timer.begin(1/scene.frameRate.d, tolerance: 0.1/scene.frameRate.d) { [unowned self] in
                    self.updatePlayTime()
                }
                drawLayer.setNeedsDisplay()
            } else {
                timer.stop()
                playCutItem = nil
                audioPlayer?.stop()
                audioPlayer = nil
                drawLayer.contents = nil
            }
        }
    }
    private func updatePlayTime() {
        if let playCutItem = playCutItem {
            var updated = false
            if let audioPlayer = audioPlayer, !scene.soundItem.isHidden {
                let t = Q(Int(audioPlayer.currentTime*Double(scene.frameRate)), scene.frameRate) //Int(audioPlayer.currentTime*Double(scene.frameRate))
                let pt = currentPlayTime + Q(1, scene.frameRate)
                if abs(pt - t) > Q(1, scene.frameRate) {
                    let viewIndex = scene.cutItemIndex(withTime: t)
                    if viewIndex.isOver {
                        self.playCutItem = scene.cutItems[0]
                        time = 0
                        audioPlayer.currentTime = 0
                    } else {
                        let cutItem = scene.cutItems[viewIndex.index]
                        if cutItem != playCutItem {
                            self.playCutItem = cutItem
                        }
                        time = viewIndex.interTime
                    }
                    updated = true
                }
            }
            if !updated {
                let nextTime = time + Q(1, scene.frameRate)
                if nextTime < playCutItem.cut.timeLength {
                    time =  nextTime
                } else if scene.cutItems.count == 1 {
                    time = 0
                } else {
                    let cutIndex = scene.cutItems.index(of: playCutItem) ?? 0
                    let nextCutIndex = cutIndex + 1 <= scene.cutItems.count - 1 ? cutIndex + 1 : 0
                    let nextCutItem = scene.cutItems[nextCutIndex]
                    self.playCutItem = nextCutItem
                    time = 0
                    if nextCutIndex == 0 {
                        audioPlayer?.currentTime = 0
                    }
                }
                drawLayer.setNeedsDisplay()
            }
            
            let t = currentPlayTime
            let s = t.integralPart
            if s != playSecond {
                playSecond = s
                timeLabel.textLine.string = minuteSecondString(withSecond: playSecond, frameRate: scene.frameRate)
            }
            
            if let cutItemIndex = scene.cutItems.index(of: playCutItem), playCutIndex != cutItemIndex {
                playCutIndex = cutItemIndex
                cutLabel.textLine.string = "C\(playCutIndex + 1)"
            }
            
            playDrawCount += 1
            let newTimestamp = CFAbsoluteTimeGetCurrent()
            let deltaTime = newTimestamp - oldTimestamp
            if deltaTime >= 1 {
                let newPlayFrameRate = min(scene.frameRate, Int(round(Double(playDrawCount)/deltaTime)))
                if newPlayFrameRate != playFrameRate {
                    playFrameRate = newPlayFrameRate
                    frameRateLabel.textLine.string = "\(playFrameRate)fps"
                    frameRateLabel.textLine.color = playFrameRate != scene.frameRate ? Color.warning : Color.smallFont
                }
                oldTimestamp = newTimestamp
                playDrawCount = 0
            }
        }
    }
    func minuteSecondString(withSecond s: Int, frameRate: Int) -> String {
        if s >= 60 {
            let minute = s/60
            let second = s - minute*60
            return String(format: "%02d:%02d", minute, second)
        } else {
            return String(format: "00:%02d", s)
        }
    }
    var currentPlayTime: Q {
        var t = Q(0)
        for entity in scene.cutItems {
            if playCutItem != entity {
                t += entity.cut.timeLength
            } else {
                t += time
                break
            }
        }
        return t
    }
    
    func play(with event: KeyInputEvent) {
        if isPlaying {
            isPlaying = false
            isPlaying = true
        } else {
            isPlaying = true
        }
    }
    func cut(with event: KeyInputEvent) -> CopyObject {
        stop()
        return CopyObject()
    }
    
    func zoom(with event: PinchEvent) {
    }
    func rotate(with event: RotateEvent) {
    }
    func stop() {
        if isPlaying {
            isPlaying = false
        }
        delegate?.endPlay(self)
    }
    
    func drag(with event: DragEvent) {
    }
    func scroll(with event: ScrollEvent) {
    }
}

final class Canvas: LayerRespondable, PlayerDelegate, Localizable {
    static let name = Localization(english: "Canvas", japanese: "キャンバス")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    var undoManager: UndoManager?
    var locale = Locale.current {
        didSet {
            materialEditor.locale = locale
        }
    }
    
    weak var sceneEditor: SceneEditor!
    
    let player = Player()
    
    var scene = Scene() {
        didSet {
            cutItem = scene.editCutItem
            player.scene = scene
//            updateViewAffineTransform()
        }
    }
    var cutItem = CutItem() {
        didSet {
//            updateViewAffineTransform()
            setNeedsDisplay()
            player.editCutItem = cutItem
        }
    }
    var cut: Cut {
        return cutItem.cut
    }
    
    var contentsScale: CGFloat {
        get {
            return layer.contentsScale
        } set {
            layer.contentsScale = newValue
            player.contentsScale = newValue
            materialEditor.contentsScale = newValue
            materialEditor.allChildren { ($0 as? LayerRespondable)?.contentsScale = newValue }
        }
    }
    
    var layer: CALayer {
        return drawLayer
    }
    private let drawLayer = DrawLayer()
    
    init() {
        drawLayer.frame.size = cameraFrame.insetBy(dx: -player.outsidePadding, dy: -player.outsidePadding).size
//        drawLayer.bounds = cameraFrame.insetBy(dx: -player.outsidePadding, dy: -player.outsidePadding)
//        drawLayer.frame.origin = drawLayer.bounds.origin
        drawLayer.drawBlock = { [unowned self] ctx in
            self.draw(in: ctx)
        }
        bounds = drawLayer.bounds
        updateScreenTransform()
        player.frame = bounds
        player.delegate = self
    }
    
    var cursor = Cursor.stroke
    
    var isOpenedPlayer = false {
        didSet {
            if isOpenedPlayer != oldValue {
                if isOpenedPlayer {
                    CATransaction.disableAnimation {
                        player.frame = frame
                        if let url = scene.soundItem.url {
                            do {
                                try player.audioPlayer = AVAudioPlayer(contentsOf: url)
                            } catch {
                            }
                        }
                        sceneEditor.children.append(player)
                    }
                } else {
                    player.removeFromParent()
                }
            }
        }
    }
    
    var editQuasimode = EditQuasimode.none
    var materialEditorType = MaterialEditor.ViewType.none {
        didSet {
            updateViewType()
        }
    }
    func setEditQuasimode(_ editQuasimode: EditQuasimode, with event: Event) {
        self.editQuasimode = editQuasimode
        let p = convertToCurrentLocal(point(from: event))
        switch editQuasimode {
        case .none:
            cursor = Cursor.stroke
        case .movePoint:
            cursor = Cursor.arrow
        case .moveVertex:
            cursor = Cursor.arrow
        case .moveZ:
            cursor = Cursor.upDown
        case .move:
            cursor = Cursor.arrow
        case .warp:
            cursor = Cursor.arrow
        case .transform:
            cursor = Cursor.arrow
        case .select:
            cursor = Cursor.arrow
        }
        updateViewType()
        updateEditView(with: p)
    }
    private func updateViewType() {
        if materialEditorType == .selection {
            viewType = .editMaterial
        } else if materialEditorType == .preview {
            viewType = .editingMaterial
        } else {
            switch editQuasimode {
            case .none:
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
                viewType = .edit
            }
        }
    }
    var viewType = Cut.ViewType.edit {
        didSet {
            if viewType != oldValue {
//                updateViewAffineTransform()
                setNeedsDisplay()
            }
        }
    }
    func updateEditView(with p : CGPoint) {
        switch viewType {
        case .edit, .editMaterial, .editingMaterial, .preview, .editSelection:
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
        indicationCellItem = cut.editNode.cellItem(at: p, reciprocalScale: scene.reciprocalScale, with: cut.editNode.editAnimation)
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
        if let n = cut.editNode.nearest(at: point, isWarp: viewType == .editVertex) {
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
                        editPoint = Node.EditPoint(
                            nearestLine: nlc.lineCap.line, nearestPointIndex: nlc.lineCap.pointIndex,
                            lines: e.drawingCaps.map { $0.line } + n.cellItemEditLineCaps.reduce([Line]()) { $0 + $1.caps.map { $0.line } },
                            point: n.point, isSnap: movePointIsSnap
                        )
                    } else {
                        editPoint = Node.EditPoint(
                            nearestLine: nlc.lineCap.line, nearestPointIndex: nlc.lineCap.pointIndex,
                            lines: n.cellItemEditLineCaps.reduce([Line]()) { $0 + $1.caps.map { $0.line } },
                            point: n.point, isSnap: movePointIsSnap
                        )
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
        let indicationCellsTuple = cut.editNode.indicationCellsTuple(with: point, reciprocalScale: scene.reciprocalScale)
        if indicationCellsTuple.type == .none {
            editZ = nil
        } else {
            editZ = Node.EditZ(cells: indicationCellsTuple.cellItems.map { $0.cell }, point: point, firstPoint: point)
        }
    }
    
    var editTransform: Node.EditTransform? {
        didSet {
            if editTransform != oldValue {
                setNeedsDisplay()
            }
        }
    }
    func updateEditTransform(with p: CGPoint) {
        self.editTransform = editTransform(at: p)
    }

    var cameraFrame: CGRect {
        get {
            return scene.frame
        } set {
            scene.frame = newValue
            updateWithScene()
        }
    }
    var time: Q {
        get {
            return scene.time
        } set {
            sceneEditor.timeline.time = newValue
        }
    }
    var isShownPrevious: Bool {
        get {
            return scene.isShownPrevious
        } set {
            scene.isShownPrevious = newValue
            updateWithScene()
        }
    }
    var isShownNext: Bool {
        get {
            return scene.isShownNext
        } set {
            scene.isShownNext = newValue
            updateWithScene()
        }
    }
    var viewTransform: Transform {
        get {
            return scene.viewTransform
        } set {
            scene.viewTransform = newValue
            updateWithScene()
        }
    }
    private func updateWithScene() {
        sceneEditor.sceneDataModel.isWrite = true
        setNeedsDisplay()
    }
    
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
    
    var indication = false {
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
    
    func setNeedsDisplay() {
        drawLayer.setNeedsDisplay()
    }
    func setNeedsDisplay(inCurrentLocalBounds rect: CGRect) {
        drawLayer.setNeedsDisplayIn(convertFromCurrentLocal(rect))
    }
    
    func draw(in ctx: CGContext) {
        ctx.saveGState()
        ctx.concatenate(screenTransform)
        cut.draw(scene: scene, bounds: bounds, viewType: viewType, in: ctx)
        if viewType != .preview {
            let edit = Node.Edit(indicationCellItem: indicationCellItem, editMaterial: viewType == .editMaterial ? nil : materialEditor.material, editZ: editZ, editPoint: editPoint, editTransform: editTransform)
            ctx.concatenate(scene.viewTransform.affineTransform)
            cut.editNode.drawEdit(
                edit, scene: scene, viewType: viewType,
                strokeLine: strokeLine, strokeLineWidth: strokeLineWidth, strokeLineColor: strokeLineColor,
                reciprocalScale: scene.reciprocalScale,
                scale: scene.scale, rotation: scene.viewTransform.rotation,
                in: ctx
            )
            ctx.restoreGState()
            cut.drawCautionBorder(scene: scene, bounds: bounds, in: ctx)
        } else {
            ctx.restoreGState()
        }
    }
    
    private func registerUndo(_ handler: @escaping (Canvas, Q) -> Void) {
        undoManager?.registerUndo(withTarget: self) { [oldTime = time] in handler($0, oldTime) }
    }
    
    func copy(with event: KeyInputEvent) -> CopyObject {
        let p = convertToCurrentLocal(point(from: event))
        let indicationCellsTuple = cut.editNode.indicationCellsTuple(with : p, reciprocalScale: scene.reciprocalScale)
        switch indicationCellsTuple.type {
        case .none:
            let copySelectionLines = cut.editNode.editAnimation.drawingItem.drawing.editLines
            if !copySelectionLines.isEmpty {
                let drawing = Drawing(lines: copySelectionLines)
                return CopyObject(objects: [drawing.deepCopy])
            }
        case .indication, .selection:
            let cell = cut.editNode.rootCell.intersection(indicationCellsTuple.cellItems.map { $0.cell }).deepCopy
            let material = cut.editNode.rootCell.at(p)!.material
//                indicationCellsTuple.cellItems[0].cell.material
            return CopyObject(objects: [cell.deepCopy, material])
        }
        return CopyObject()
    }
    func paste(_ copyObject: CopyObject, with event: KeyInputEvent) {
        for object in copyObject.objects {
            if let color = object as? Color {
                paste(color, with: event)
            } else if let copyDrawing = object as? Drawing {
                let p = convertToCurrentLocal(point(from: event))
                let indicationCellsTuple = cut.editNode.indicationCellsTuple(with : p, reciprocalScale: scene.reciprocalScale)
                if indicationCellsTuple.type != .none, let cell = cut.editNode.rootCell.at(p), let cellItem = cut.editNode.editAnimation.cellItem(with: cell) {
                    let nearestPathLineIndex = cellItem.cell.geometry.nearestPathLineIndex(at: p)
                    let previousLine = cellItem.cell.geometry.lines[nearestPathLineIndex]
                    let nextLine = cellItem.cell.geometry.lines[
                        nearestPathLineIndex + 1 >= cellItem.cell.geometry.lines.count ? 0 : nearestPathLineIndex + 1
                    ]
                    let unionSegmentLine = Line(
                        controls: [
                            Line.Control(point: nextLine.firstPoint, pressure: 1),
                            Line.Control(point: previousLine.lastPoint, pressure: 1)
                        ]
                    )
                    let geometry = Geometry(
                        lines: [unionSegmentLine] + copyDrawing.lines,
                        scale: scene.scale
                    )
                    let lines = geometry.lines.withRemovedFirst()
                    setGeometries(
                        Geometry.geometriesWithInserLines(with: cellItem.keyGeometries, lines: lines, atLinePathIndex: nearestPathLineIndex),
                        oldKeyGeometries: cellItem.keyGeometries,
                        in: cellItem, cut.editNode.editAnimation, time: time
                    )
                } else {
                    let drawing = cut.editNode.editAnimation.drawingItem.drawing, oldCount = drawing.lines.count
                    let lineIndexes = (0 ..< copyDrawing.lines.count).map { $0 + oldCount }
                    setLines(drawing.lines + copyDrawing.lines, oldLines: drawing.lines, drawing: drawing, time: time)
                    setSelectionLineIndexes(drawing.selectionLineIndexes.withAppend(lineIndexes), in: drawing, time: time)
                }
            } else if let copyRootCell = object as? Cell {
                for copyCell in copyRootCell.allCells {
                    for animation in cut.editNode.animations {
                        for ci in animation.cellItems {
                            if ci.cell.id == copyCell.id {
                                setGeometry(copyCell.geometry, oldGeometry: ci.cell.geometry, at: animation.editKeyframeIndex, in: ci, time: time)
                                cut.editNode.editAnimation.update(withTime: cut.time)
                            }
                        }
                    }
                }
            }
        }
    }
    func paste(_ color: Color, with event: KeyInputEvent) {
        let p = convertToCurrentLocal(point(from: event))
        let indicationCellsTuple = cut.editNode.indicationCellsTuple(with:p , reciprocalScale: scene.reciprocalScale)
        if indicationCellsTuple.type != .none, let selectionMaterial = cut.editNode.rootCell.at(p)?.material {
//            let selectionMaterial = indicationCellsTuple.cells[0].material
            if color != selectionMaterial.color {
                materialEditor.paste(color, withSelection: selectionMaterial, useSelection: indicationCellsTuple.type == .selection)
            }
        }
    }
    func paste(_ material: Material, with event: KeyInputEvent) {
        let p = convertToCurrentLocal(point(from: event))
        let indicationCellsTuple = cut.editNode.indicationCellsTuple(with : p, reciprocalScale: scene.reciprocalScale)
        if indicationCellsTuple.type != .none, let selectionMaterial = cut.editNode.rootCell.at(p)?.material {
//            let selectionMaterial = indicationCellsTuple.cells[0].material
            if material != selectionMaterial {
                materialEditor.paste(material, withSelection: selectionMaterial, useSelection: indicationCellsTuple.type == .selection)
            }
        }
    }
    
    
    func delete(with event: KeyInputEvent) {
        if deleteCells(with: event) {
            return
        }
        if deleteSelectionDrawingLines() {
            return
        }
        if deleteDrawingLines() {
            return
        }
    }
    func deleteSelectionDrawingLines() -> Bool {
        let drawingItem = cut.editNode.editAnimation.drawingItem
        if !drawingItem.drawing.selectionLineIndexes.isEmpty {
            let unseletionLines = drawingItem.drawing.uneditLines
            setSelectionLineIndexes([], in: drawingItem.drawing, time: time)
            setLines(unseletionLines, oldLines: drawingItem.drawing.lines, drawing: drawingItem.drawing, time: time)
            return true
        } else {
            return false
        }
    }
    func deleteDrawingLines() -> Bool {
        let drawingItem = cut.editNode.editAnimation.drawingItem
        if !drawingItem.drawing.lines.isEmpty {
            setLines([], oldLines: drawingItem.drawing.lines, drawing: drawingItem.drawing, time: time)
            return true
        } else {
            return false
        }
    }
    func deleteCells(with event: KeyInputEvent) -> Bool {
        let point = convertToCurrentLocal(self.point(from: event))
        let indicationCellsTuple = cut.editNode.indicationCellsTuple(with: point, reciprocalScale: scene.reciprocalScale)
        switch indicationCellsTuple.type {
        case .selection:
            var isChanged = false
            for animation in cut.editNode.animations {
                let removeSelectionCellItems = //animation.editSelectionCellItemsWithNoEmptyGeometry
                    indicationCellsTuple.cellItems.filter {
                    if !$0.cell.geometry.isEmpty {
                        setGeometry(Geometry(), oldGeometry: $0.cell.geometry, at: animation.editKeyframeIndex, in: $0, time: time)
                        cut.editNode.editAnimation.update(withTime: cut.time)
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
            if let cellItem = cut.editNode.cellItem(at: point, reciprocalScale: scene.reciprocalScale, with: cut.editNode.editAnimation) {
                if !cellItem.cell.geometry.isEmpty {
                    setGeometry(Geometry(), oldGeometry: cellItem.cell.geometry, at: cut.editNode.editAnimation.editKeyframeIndex, in: cellItem, time: time)
                    if cellItem.isEmptyKeyGeometries {
                        removeCellItems([cellItem])
                    }
                    cut.editNode.editAnimation.update(withTime: cut.time)
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
            for animationAndCellItems in cellRemoveManager.animationAndCellItems {
                let animation = animationAndCellItems.animation, cellItems = animationAndCellItems.cellItems
                let removeSelectionCellItems = animation.subtractSelectionCellItems(with: cellItems)// Array(Set(animation.selectionCellItems).subtracting(cellItems))
                if removeSelectionCellItems.count != cut.editNode.editAnimation.selectionCellItems.count {
                    setSelectionCellItems(removeSelectionCellItems, in: animation, time: time)
                }
            }
            removeCell(with: cellRemoveManager, time: time)
            cellItems = cellItems.filter { !cellRemoveManager.contains($0) }
        }
    }
    private func insertCell(with cellRemoveManager: Node.CellRemoveManager, time: Q) {
        registerUndo { $0.removeCell(with: cellRemoveManager, time: $1) }
        self.time = time
        cut.editNode.insertCell(with: cellRemoveManager)
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func removeCell(with cellRemoveManager: Node.CellRemoveManager, time: Q) {
        registerUndo { $0.insertCell(with: cellRemoveManager, time: $1) }
        self.time = time
        cut.editNode.removeCell(with: cellRemoveManager)
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    
    private func setGeometries(_ keyGeometries: [Geometry], oldKeyGeometries: [Geometry], in cellItem: CellItem, _ animation: Animation, time: Q) {
        registerUndo { $0.setGeometries(oldKeyGeometries, oldKeyGeometries: keyGeometries, in: cellItem, animation, time: $1) }
        self.time = time
        animation.setKeyGeometries(keyGeometries, in: cellItem)
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func setGeometry(_ geometry: Geometry, oldGeometry: Geometry, at i: Int, in cellItem: CellItem, time: Q) {
        registerUndo { $0.setGeometry(oldGeometry, oldGeometry: geometry, at: i, in: cellItem, time: $1) }
        self.time = time
        cellItem.replaceGeometry(geometry, at: i)
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    
    func operationSets(with event: KeyInputEvent, type: SetType) {
        let p = convertToCurrentLocal(point(from: event))
        let animation = cut.editNode.editAnimation
        let drawing = animation.drawingItem.drawing
        let indicationTuple = cut.editNode.indicationCellsTuple(with: p, reciprocalScale: scene.reciprocalScale)
        if indicationTuple.cellItems.isEmpty && animation.selectionCellItems.isEmpty {
            let selectionLineIndexes: [[Int]]
            if drawing.selectionLineIndexes.isEmpty {
                switch type {
                case .union:
                    selectionLineIndexes = [Array(0 ..< drawing.lines.count)]
                default:
                    return
                }
            } else {
                switch type {
                case .union:
                    selectionLineIndexes = drawing.selectionLineIndexes.withReplaced(Array(Set(drawing.selectionLineIndexes.last!).union(Set(indicationTuple.selectionLineIndexes))), at: drawing.selectionLineIndexes.count - 1)
                case .subtract:
                    selectionLineIndexes = drawing.selectionLineIndexes.withReplaced(Array(Set(drawing.selectionLineIndexes.last!).subtracting(Set(indicationTuple.selectionLineIndexes))), at: drawing.selectionLineIndexes.count - 1)
                case .intersect:
                    selectionLineIndexes = drawing.selectionLineIndexes.withReplaced(Array(Set(drawing.selectionLineIndexes.last!).intersection(Set(indicationTuple.selectionLineIndexes))), at: drawing.selectionLineIndexes.count - 1)
                }
            }
            if !selectionLineIndexes.elementsEqual(drawing.selectionLineIndexes) { $0 == $1 } {
                setSelectionLineIndexes(selectionLineIndexes, in: drawing, time: time)
            }
        } else {
            let selectionCellItems: [[CellItem]]
            if animation.selectionCellItems.isEmpty {
                switch type {
                case .union:
                    selectionCellItems = [indicationTuple.cellItems]
                default:
                    return
                }
            } else {
                switch type {
                case .union:
                    selectionCellItems = animation.selectionCellItems.withReplaced(Array(Set(animation.selectionCellItems.last!).union(Set(indicationTuple.cellItems))), at: animation.selectionCellItems.count - 1)
                case .subtract:
                    selectionCellItems = animation.selectionCellItems.withReplaced(Array(Set(animation.selectionCellItems.last!).subtracting(Set(indicationTuple.cellItems))), at: animation.selectionCellItems.count - 1)
                case .intersect:
                    selectionCellItems = animation.selectionCellItems.withReplaced(Array(Set(animation.selectionCellItems.last!).intersection(Set(indicationTuple.cellItems))), at: animation.selectionCellItems.count - 1)
                }
            }
            if !selectionCellItems.elementsEqual(animation.selectionCellItems) { $0 == $1 } {
                setSelectionCellItems(selectionCellItems, in: animation, time: time)
            }
        }
    }
    func union(with event: KeyInputEvent) {
        operationSets(with: event, type: .union)
    }
    func subtract(with event: KeyInputEvent) {
        operationSets(with: event, type: .subtract)
    }
    func intersect(with event: KeyInputEvent) {
        operationSets(with: event, type: .intersect)
    }
    enum SetType {
        case union, subtract, intersect
    }
    
    var textInput: TextInput?
    func keyInput(with event: KeyInputEvent) {
    }
    
    func play(with event: KeyInputEvent) {
        isOpenedPlayer = true
        player.play(with: event)
    }
    func endPlay(_ player: Player) {
        isOpenedPlayer = false
    }
    
    func addCellWithLines(with event: KeyInputEvent) {
        let drawingItem = cut.editNode.editAnimation.drawingItem, rootCell = cut.editNode.rootCell
        let geometry = Geometry(lines: drawingItem.drawing.editLines, scale: scene.scale)
        if !geometry.isEmpty {
            let isDrawingSelectionLines = !drawingItem.drawing.selectionLineIndexes.isEmpty
            let unselectionLines = drawingItem.drawing.uneditLines
            if isDrawingSelectionLines {
                setSelectionLineIndexes([], in: drawingItem.drawing, time: time)
            }
            setLines(unselectionLines, oldLines: drawingItem.drawing.lines, drawing: drawingItem.drawing, time: time)
            let lki = cut.editNode.editAnimation.loopedKeyframeIndex(withTime: cut.time)
            let keyGeometries = cut.editNode.editAnimation.emptyKeyGeometries.withReplaced(geometry, at: lki.index)
            
            let newCellItem = CellItem(cell: Cell(geometry: geometry, material: Material(color: Color.random(colorSpace: scene.colorSpace))), keyGeometries: keyGeometries)
            insertCell(newCellItem, in: [(rootCell, addCellIndex(with: newCellItem.cell, in: rootCell))], cut.editNode.editAnimation, time: time)
        }
    }
    
//    func addAndClipCellWithLines(with event: KeyInputEvent) {
//        let drawingItem = cut.editNode.editAnimation.drawingItem
//        let geometry = Geometry(lines: drawingItem.drawing.editLines, scale: scene.scale)
//        if !geometry.isEmpty {
//            let isDrawingSelectionLines = !drawingItem.drawing.selectionLineIndexes.isEmpty
//            let unselectionLines = drawingItem.drawing.uneditLines
//            if isDrawingSelectionLines {
//                setSelectionLineIndexes([], in: drawingItem.drawing, time: time)
//            }
//            setLines(unselectionLines, oldLines: drawingItem.drawing.lines, drawing: drawingItem.drawing, time: time)
//            
//            let lki = cut.editNode.editAnimation.loopedKeyframeIndex(withTime: cut.time)
//            let keyGeometries = cut.editNode.editAnimation.emptyKeyGeometries.withReplaced(geometry, at: lki.index)
//            let newCellItem = CellItem(cell: Cell(geometry: geometry, material: Material(color: Color.random())), keyGeometries: keyGeometries)
//            let p = point(from: event)
//            let ict = cut.editNode.indicationCellsTuple(with: convertToCurrentLocal(p), reciprocalScale: scene.reciprocalScale, usingLock: false)
//            if ict.type == .selection {
//                insertCell(newCellItem, in: ict.cells.map { ($0, addCellIndex(with: newCellItem.cell, in: $0)) }, cut.editNode.editAnimation, time: time)
//            } else {
//                let ict = cut.editNode.indicationCellsTuple(with: convertToCurrentLocal(p), reciprocalScale: scene.reciprocalScale, usingLock: true)
//                if ict.type != .none {
//                    insertCell(newCellItem, in: ict.cells.map { ($0, addCellIndex(with: newCellItem.cell, in: $0)) }, cut.editNode.editAnimation, time: time)
//                }
//            }
//        }
//    }
    
    private func addCellIndex(with cell: Cell, in parent: Cell) -> Int {
        let editCells = cut.editNode.editAnimation.cells
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
        return cellIndex(withAnimationIndex: cut.editNode.editAnimationIndex, in: parent)
    }
    
    func cellIndex(withAnimationIndex animationIndex: Int, in parent: Cell) -> Int {
        for i in animationIndex + 1 ..< cut.editNode.animations.count {
            let animation = cut.editNode.animations[i]
            var maxIndex = 0, isMax = false
            for cellItem in animation.cellItems {
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
    
    func moveCell(_ cell: Cell, from fromParents: [(cell: Cell, index: Int)], to toParents: [(cell: Cell, index: Int)], time: Q) {
        registerUndo { $0.moveCell(cell, from: toParents, to: fromParents, time: $1) }
        self.time = time
        for fromParent in fromParents {
            fromParent.cell.children.remove(at: fromParent.index)
        }
        for toParent in toParents {
            toParent.cell.children.insert(cell, at: toParent.index)
        }
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    
    func lassoDelete(with event: KeyInputEvent) {
        let drawing = cut.editNode.editAnimation.drawingItem.drawing, animation = cut.editNode.editAnimation
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
            var removeCellItems = [CellItem]()
            removeCellItems = animation.cellItems.filter { cellItem in
                if cellItem.cell.intersects(lasso) {
                    setGeometry(Geometry(), oldGeometry: cellItem.cell.geometry, at: animation.editKeyframeIndex, in: cellItem, time: time)
                    cut.editNode.editAnimation.update(withTime: cut.time)
                    if cellItem.isEmptyKeyGeometries {
                        return true
                    }
                    isRemoveLineInCell = true
                }
                return false
            }
            if !isRemoveLineInDrawing && !isRemoveLineInCell {
                if let hitCellItem = cut.editNode.cellItem(at: lastLine.firstPoint, reciprocalScale: scene.reciprocalScale, with: animation) {
                    let lines = hitCellItem.cell.geometry.lines
                    setGeometry(Geometry(), oldGeometry: hitCellItem.cell.geometry, at: animation.editKeyframeIndex, in: hitCellItem, time: time)
                    cut.editNode.editAnimation.update(withTime: cut.time)
                    if hitCellItem.isEmptyKeyGeometries {
                        removeCellItems.append(hitCellItem)
                    }
                    setLines(drawing.lines + lines, oldLines: drawing.lines, drawing: drawing, time: time)
                }
            }
            if !removeCellItems.isEmpty {
                self.removeCellItems(removeCellItems)
            }
        }
    }
//    func lassoSelect(with event: KeyInputEvent) {
//        lassoSelect(isDelete: false, with: event)
//    }
//    func lassoDeleteSelect(with event: KeyInputEvent) {
//        lassoSelect(isDelete: true, with: event)
//    }
//    private func lassoSelect(isDelete: Bool, with event: KeyInputEvent) {
//        let animation = cut.editNode.editAnimation
//        let drawing = animation.drawingItem.drawing
//        guard let lassoLine = drawing.lines.last else {
//            return
//        }
//        if let index = drawing.selectionLineIndexes.index(of: drawing.lines.count - 1) {
//            setSelectionLineIndexes(drawing.selectionLineIndexes.withRemoved(at: index), in: drawing, time: time)
//        }
//        removeLastLine(in: drawing, time: time)
//        
//        let lasso = Lasso(lines: [lassoLine])
//        let intersectionCellItems = Set(animation.cellItems.filter { $0.cell.intersects(lasso) })
//        let selectionCellItems = Array(isDelete ?
//            Set(animation.selectionCellItems).subtracting(intersectionCellItems) : Set(animation.selectionCellItems).union(intersectionCellItems))
//        let drawingLineIndexes = Set(drawing.lines.enumerated().flatMap { lasso.intersects($1) ? $0 : nil })
//        let selectionLineIndexes = Array(isDelete ?
//            Set(drawing.selectionLineIndexes).subtracting(drawingLineIndexes) : Set(drawing.selectionLineIndexes).union(drawingLineIndexes))
//        if selectionCellItems != animation.selectionCellItems {
//            setSelectionCellItems(selectionCellItems, in: animation, time: time)
//        }
//        if selectionLineIndexes != drawing.selectionLineIndexes {
//            setSelectionLineIndexes(selectionLineIndexes, in: drawing, time: time)
//        }
//    }
    
//    func clipCellInSelection(with event: KeyInputEvent) {
//        let point = convertToCurrentLocal(self.point(from: event))
//        if let fromCell = cut.editNode.rootCell.at(point, reciprocalScale: scene.reciprocalScale) {
//            let selectionCells = cut.editNode.allEditSelectionCellsWithNoEmptyGeometry
//            if selectionCells.isEmpty {
//                if !cut.editNode.rootCell.children.contains(fromCell) {
//                    let fromParents = cut.editNode.rootCell.parents(with: fromCell)
//                    moveCell(fromCell, from: fromParents, to: [(cut.editNode.rootCell, cut.editNode.rootCell.children.count)], time: time)
//                }
//            } else if !selectionCells.contains(fromCell) {
//                let fromChildrens = fromCell.allCells
//                var newFromParents = cut.editNode.rootCell.parents(with: fromCell)
//                let newToParents: [(cell: Cell, index: Int)] = selectionCells.flatMap { toCell in
//                    for fromChild in fromChildrens {
//                        if fromChild == toCell {
//                            return nil
//                        }
//                    }
//                    for (i, newFromParent) in newFromParents.enumerated() {
//                        if toCell == newFromParent.cell {
//                            newFromParents.remove(at: i)
//                            return nil
//                        }
//                    }
//                    return (toCell, toCell.children.count)
//                }
//                if !(newToParents.isEmpty && newFromParents.isEmpty) {
//                    moveCell(fromCell, from: newFromParents, to: newToParents, time: time)
//                }
//            }
//        }
//    }
    
    private func insertCell(_ cellItem: CellItem, in parents: [(cell: Cell, index: Int)], _ animation: Animation, time: Q) {
        registerUndo { $0.removeCell(cellItem, in: parents, animation, time: $1) }
        self.time = time
        cut.editNode.insertCell(cellItem, in: parents, animation)
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func removeCell(_ cellItem: CellItem, in parents: [(cell: Cell, index: Int)], _ animation: Animation, time: Q) {
        registerUndo { $0.insertCell(cellItem, in: parents, animation, time: $1) }
        self.time = time
        cut.editNode.removeCell(cellItem, in: parents, animation)
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func insertCells(_ cellItems: [CellItem], rootCell: Cell, at index: Int, in parent: Cell, _ animation: Animation, time: Q) {
        registerUndo { $0.removeCells(cellItems, rootCell: rootCell, at: index, in: parent, animation, time: $1) }
        self.time = time
        cut.editNode.insertCells(cellItems, rootCell: rootCell, at: index, in: parent, animation)
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func removeCells(_ cellItems: [CellItem], rootCell: Cell, at index: Int, in parent: Cell, _ animation: Animation, time: Q) {
        registerUndo { $0.insertCells(cellItems, rootCell: rootCell, at: index, in: parent, animation, time: $1) }
        self.time = time
        cut.editNode.removeCells(cellItems, rootCell: rootCell, in: parent, animation)
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    
    func hide(with event: KeyInputEvent) {
        let seletionCells = cut.editNode.indicationCellsTuple(with : convertToCurrentLocal(point(from: event)), reciprocalScale: scene.reciprocalScale)
        for cellItem in seletionCells.cellItems {
            if !cellItem.cell.isEditHidden {
                setIsEditHidden(true, in: cellItem.cell, time: time)
            }
        }
    }
    func show(with event: KeyInputEvent) {
        cut.editNode.rootCell.allCells { cell, stop in
            if cell.isEditHidden {
                setIsEditHidden(false, in: cell, time: time)
            }
        }
    }
    func setIsEditHidden(_ isEditHidden: Bool, in cell: Cell, time: Q) {
        registerUndo { [oldIsEditHidden = cell.isEditHidden] in $0.setIsEditHidden(oldIsEditHidden, in: cell, time: $1) }
        self.time = time
        cell.isEditHidden = isEditHidden
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    
//    func minimize(with event: KeyInputEvent) {
//        let seletionCells = cut.editNode.indicationCellsTuple(with : convertToCurrentLocal(point(from: event)), reciprocalScale: scene.reciprocalScale)
//        if seletionCells.cells.isEmpty {
//            let drawing = cut.editNode.editAnimation.drawingItem.drawing
//            if !drawing.lines.isEmpty {
//                setLines(drawing.lines.map { $0.bezierLine(withScale: scene.scale) }, oldLines: drawing.lines, drawing: drawing, time: time)
//            }
//        } else {
//            for cell in seletionCells.cells {
//                if let cellItem = cut.editNode.editAnimation.cellItem(with: cell) {
//                    setGeometries(
//                        Geometry.bezierLineGeometries(with: cellItem.keyGeometries, scale: scene.scale),
//                        oldKeyGeometries: cellItem.keyGeometries,
//                        in: cellItem, cut.editNode.editAnimation, time: time
//                    )
//                }
//            }
//        }
//    }
    
    func pasteCell(_ copyObject: CopyObject, with event: KeyInputEvent) {
        for object in copyObject.objects {
            if let copyRootCell = object as? Cell {
                let keyframeIndex = cut.editNode.editAnimation.loopedKeyframeIndex(withTime: cut.time)
                var newCellItems = [CellItem]()
                copyRootCell.depthFirstSearch(duplicate: false) { parent, cell in
                    cell.id = UUID()
                    let keyGeometrys = cut.editNode.editAnimation.emptyKeyGeometries.withReplaced(cell.geometry, at: keyframeIndex.index)
                    newCellItems.append(CellItem(cell: cell, keyGeometries: keyGeometrys))
                }
                let index = cellIndex(withAnimationIndex: cut.editNode.editAnimationIndex, in: cut.editNode.rootCell)
                insertCells(newCellItems, rootCell: copyRootCell, at: index, in: cut.editNode.rootCell, cut.editNode.editAnimation, time: time)
                setSelectionCellItems(cut.editNode.editAnimation.selectionCellItems + [newCellItems], in: cut.editNode.editAnimation, time: time)
            }
        }
    }
    func pasteMaterial(_ copyObject: CopyObject, with event: KeyInputEvent) {
        for object in copyObject.objects {
            if let material = object as? Material {
                paste(material, with: event)
                return
            }
        }
    }
    func splitColor(with event: KeyInputEvent) {
        let point = convertToCurrentLocal(self.point(from: event))
        let ict = cut.editNode.indicationCellsTuple(with: point, reciprocalScale: scene.reciprocalScale)
        if !ict.cellItems.isEmpty {
            materialEditor.splitColor(with: ict.cellItems.map { $0.cell })
        }
    }
    func splitOtherThanColor(with event: KeyInputEvent) {
        let point = convertToCurrentLocal(self.point(from: event))
        let ict = cut.editNode.indicationCellsTuple(with: point, reciprocalScale: scene.reciprocalScale)
        if !ict.cellItems.isEmpty {
            materialEditor.splitOtherThanColor(with: ict.cellItems.map { $0.cell })
        }
    }
    
    func changeToRough() {
        let drawing = cut.editNode.editAnimation.drawingItem.drawing
        if !drawing.roughLines.isEmpty || !drawing.lines.isEmpty {
            setRoughLines(drawing.editLines, oldLines: drawing.roughLines, drawing: drawing, time: time)
            setLines(drawing.uneditLines, oldLines: drawing.lines, drawing: drawing, time: time)
            if !drawing.selectionLineIndexes.isEmpty {
                setSelectionLineIndexes([], in: drawing, time: time)
            }
        }
    }
    func removeRough() {
        let drawing = cut.editNode.editAnimation.drawingItem.drawing
        if !drawing.roughLines.isEmpty {
            setRoughLines([], oldLines: drawing.roughLines, drawing: drawing, time: time)
        }
    }
    func swapRough() {
        let drawing = cut.editNode.editAnimation.drawingItem.drawing
        if !drawing.roughLines.isEmpty || !drawing.lines.isEmpty {
            if !drawing.selectionLineIndexes.isEmpty {
                setSelectionLineIndexes([], in: drawing, time: time)
            }
            let newLines = drawing.roughLines, newRoughLines = drawing.lines
            setRoughLines(newRoughLines, oldLines: drawing.roughLines, drawing: drawing, time: time)
            setLines(newLines, oldLines: drawing.lines, drawing: drawing, time: time)
        }
    }
    private func setRoughLines(_ lines: [Line], oldLines: [Line], drawing: Drawing, time: Q) {
        registerUndo { $0.setRoughLines(oldLines, oldLines: lines, drawing: drawing, time: $1) }
        self.time = time
        drawing.roughLines = lines
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.timeline.setNeedsDisplay()
    }
    private func setLines(_ lines: [Line], oldLines: [Line], drawing: Drawing, time: Q) {
        registerUndo { $0.setLines(oldLines, oldLines: lines, drawing: drawing, time: $1) }
        self.time = time
        drawing.lines = lines
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    
    func moveCursor(with event: MoveEvent) {
        updateEditView(with: convertToCurrentLocal(point(from: event)))
    }
    
    let materialEditor = MaterialEditor()
    func showProperty(with event: DragEvent) {
        if let root = rootRespondable as? LayerRespondable {
            CATransaction.disableAnimation {
                let p = event.location.integral
                let material = cut.editNode.indicationCellsTuple(with: p, reciprocalScale: scene.reciprocalScale).cellItems.first?.cell.material ?? cut.editNode.material
                materialEditor.material = material
                materialEditor.frame.origin = CGPoint(x: p.x, y: p.y - materialEditor.frame.height)
                root.children.append(materialEditor)
            }
        }
    }
    
    private struct SelectOption {
        var selectionLineIndexes = [[Int]](), selectionCellItmes = [[CellItem]]()
    }
    private var selectOption = SelectOption()
    func select(with event: DragEvent) {
        let drawing = cut.editNode.editAnimation.drawingItem.drawing, animation = cut.editNode.editAnimation
        func selection() -> (lineIndexes: [Int], cellItems: [CellItem]) {
            guard let line = strokeLine else {
                return ([], [])
            }
            let lasso = Lasso(lines: [line])
            let intersectionCellItems = animation.cellItems.filter { $0.cell.intersects(lasso) }
            let drawingLineIndexes = drawing.lines.enumerated().flatMap { lasso.intersects($1) ? $0 : nil }
            return (drawingLineIndexes, intersectionCellItems)
        }
        drag(
            with: event, lineWidth: strokeLineWidth,
            movePointMaxDistance: strokeDistance, movePointMaxTime: strokeMovePointMaxTime, isAppendLine: true
        )
        let s = selection()
        switch event.sendType {
        case .begin:
            selectOption.selectionLineIndexes = drawing.selectionLineIndexes
            selectOption.selectionCellItmes = animation.selectionCellItems
            drawing.selectionLineIndexes = drawing.selectionLineIndexes + [s.lineIndexes]
            animation.selectionCellItems = animation.selectionCellItems + [s.cellItems]
        case .sending:
            drawing.selectionLineIndexes = drawing.selectionLineIndexes + [s.lineIndexes]
            animation.selectionCellItems = animation.selectionCellItems + [s.cellItems]
        case .end:
            let selectionLineIndexes = drawing.selectionLineIndexes + [s.lineIndexes]
            let selectionCellItems = animation.selectionCellItems + [s.cellItems]
            if !selectionLineIndexes.elementsEqual(drawing.selectionLineIndexes) { $0 == $1 } {
                setSelectionLineIndexes(selectionLineIndexes, in: drawing, time: time)
            }
            if !selectionCellItems.elementsEqual(animation.selectionCellItems) { $0 == $1 } {
                setSelectionCellItems(selectionCellItems, in: animation, time: time)
            }
            self.strokeLine = nil
        }
        setNeedsDisplay()
    }
    
    private var strokeLine: Line?, strokeLineColor = Color.strokeLine, strokeLineWidth = DrawingItem.defaultLineWidth
    private var strokeOldPoint = CGPoint(), strokeOldTime = 0.0, strokeOldLastBounds = CGRect()
    private var strokeIsDrag = false, strokeControls: [Line.Control] = [], strokeBeginTime = 0.0
    private let strokeSplitAngle = 1.5*(.pi)/2.0.cf, strokeLowSplitAngle = 0.9*(.pi)/2.0.cf, strokeDistance = 1.0.cf, strokeMovePointMaxTime = 0.1
    private let strokeSlowDistance = 3.5.cf, strokeSlowTime = 0.25, strokeShortTime = 0.1
    private let strokeShortLinearDistance = 1.0.cf, strokeShortLinearMaxDistance = 1.5.cf
    private struct Stroke {
        var line: Line?, movePointMaxDistance = 1.0.cf, movePointMaxTime = 0.1
    }
    func drag(with event: DragEvent) {
        drag(
            with: event, lineWidth: strokeLineWidth,
            movePointMaxDistance: strokeDistance, movePointMaxTime: strokeMovePointMaxTime
        )
    }
    func slowDrag(with event: DragEvent) {
        drag(
            with: event, lineWidth: strokeLineWidth,
            movePointMaxDistance: strokeSlowDistance, movePointMaxTime: strokeSlowTime, splitAcuteAngle: false
        )
    }
    func drag(
        with event: DragEvent, lineWidth: CGFloat,
        movePointMaxDistance: CGFloat, movePointMaxTime: Double, splitAcuteAngle: Bool = true, isAppendLine: Bool = true
    ) {
        /*
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
//            Thread.sleep(forTimeInterval: 0.1)
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
                    let d = strokeControl.point.distanceWithLineSegment(ap: firstStrokeControl.point, bp: control.point)
                    if d > maxD {
                        maxD = d
                        maxControl = strokeControl
                    }
                }
                let cpMinP = maxControl.point.nearestWithLine(ap: firstStrokeControl.point, bp: control.point)
                let cpControl = Line.Control(point: 2*maxControl.point - cpMinP, pressure: maxControl.pressure)
                let bezier = Bezier2(p0: firstStrokeControl.point, cp: cpControl.point, p1: control.point)
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
                setNeedsDisplay(in: lastBounds.union(strokeOldLastBounds).inset(by: -lineWidth/2))
                self.strokeOldLastBounds = lastBounds
                self.strokeControls = [lastControl]
            }
            
            let midControl = line.controls[line.controls.count - 3].mid(control)
            let newLine = line.withReplaced(midControl, at: line.controls.count - 2).withReplaced(midControl, at: line.controls.count - 1)
            self.strokeLine = newLine
            let lastBounds = newLine.strokeLastBoundingBox
            setNeedsDisplay(in: lastBounds.union(strokeOldLastBounds).inset(by: -lineWidth/2))
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
            addLine(
                removedLine.withReplaced(
                    Line.Control(point: p, pressure: removedLine.controls[removedLine.controls.count - 1].pressure), at: removedLine.controls.count - 1
                ),
                in: cut.editNode.editAnimation.drawingItem.drawing, time: time
            )
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
                return
            }
            strokeIsDrag = true
            let ac = strokeControls.first!, bp = p, lc = strokeControls.last!, scale = scene.scale
            let control = Line.Control(point: p, pressure: event.pressure)
            strokeControls.append(control)
            if splitAcuteAngle && line.controls.count >= 4 {
                let c0 = line.controls[line.controls.count - 4], c1 = line.controls[line.controls.count - 3], c2 = lc
                if c0.point != c1.point && c1.point != c2.point {
                    let dr = abs(CGPoint.differenceAngle(p0: c0.point, p1: c1.point, p2: c2.point))
                    if dr > strokeLowSplitAngle {
                        if dr > strokeSplitAngle {
                            line = line.withInsert(c1, at: line.controls.count - 2)
                            let  lastBounds = line.strokeLastBoundingBox
                            strokeLine = line
                            setNeedsDisplay(inCurrentLocalBounds: lastBounds.union(strokeOldLastBounds).inset(by: -lineWidth/2))
                            strokeOldLastBounds = lastBounds
                        } else {
                            let t = 1 - (dr - strokeLowSplitAngle)/strokeSplitAngle
                            let tp = CGPoint.linear(c1.point, c2.point, t: t)
                            if c1.point != tp {
                                line = line.withInsert(
                                    Line.Control(point: tp, pressure: CGFloat.linear(c1.pressure, c2.pressure, t:  t)), at: line.controls.count - 1
                                )
                                let  lastBounds = line.strokeLastBoundingBox
                                strokeLine = line
                                setNeedsDisplay(inCurrentLocalBounds: lastBounds.union(strokeOldLastBounds).inset(by: -lineWidth/2))
                                strokeOldLastBounds = lastBounds
                            }
                        }
                    }
                }
            }
            if line.controls[line.controls.count - 3].point != lc.point {
                for (i, sp) in strokeControls.enumerated() {
                    if i > 0 {
                        if sp.point.distanceWithLine(ap: ac.point, bp: bp)*scale > strokeDistance || event.time - strokeOldTime > movePointMaxTime {
                            line = line.withInsert(lc, at: line.controls.count - 2)
                            strokeLine = line
                            let lastBounds = line.strokeLastBoundingBox
                            setNeedsDisplay(inCurrentLocalBounds: lastBounds.union(strokeOldLastBounds).inset(by: -lineWidth/2))
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
            setNeedsDisplay(inCurrentLocalBounds: lastBounds.union(strokeOldLastBounds).inset(by: -lineWidth/2))
            strokeOldLastBounds = lastBounds
            strokeOldPoint = p
        case .end:
            if let line = strokeLine {
                if strokeIsDrag {
                    let scale = scene.scale
                    func lastRevisionLine(line: Line) -> Line {
                        if line.controls.count > 3 {
                            let ap = line.controls[line.controls.count - 3].point, bp = p, lp = line.controls[line.controls.count - 2].point
                            if !(lp.distanceWithLine(ap: ap, bp: bp)*scale > strokeDistance || event.time - strokeOldTime > movePointMaxTime) {
                                return line.withRemoveControl(at: line.controls.count - 2)
                            }
                        }
                        return line
                    }
                    var newLine = lastRevisionLine(line: line)
                    if event.time - strokeBeginTime < strokeShortTime && newLine.controls.count > 3 {
                        var maxD = 0.0.cf, maxControl = newLine.controls[0]
                        for control in newLine.controls {
                            let d = control.point.distanceWithLine(ap: newLine.firstPoint, bp: newLine.lastPoint)
                            if d*scale > maxD {
                                maxD = d
                                maxControl = control
                            }
                        }
                        let mcp = maxControl.point.nearestWithLine(ap: newLine.firstPoint, bp: newLine.lastPoint)
                        let cp = 2*maxControl.point - mcp
                        
                        let b = Bezier2(p0: newLine.firstPoint, cp: cp, p1: newLine.lastPoint)
                        var isShort = true
                        newLine.allEditPoints { p, i in
                            let nd = sqrt(b.minDistance²(at: p))
                            if nd*scale > strokeShortLinearMaxDistance {
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
                        addLine(
                            newLine.withReplaced(Line.Control(point: p, pressure: newLine.controls.last!.pressure), at: newLine.controls.count - 1),
                            in: cut.editNode.editAnimation.drawingItem.drawing, time: time
                        )
                    } else {
                        strokeLine = newLine
                    }
                }
                if isAppendLine {
                    strokeLine = nil
                }
            }
        }
    }
    private func addLine(_ line: Line, in drawing: Drawing, time: Q) {
        registerUndo { $0.removeLastLine(in: drawing, time: $1) }
        self.time = time
        drawing.lines.append(line)
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func removeLastLine(in drawing: Drawing, time: Q) {
        registerUndo { [lastLine = drawing.lines.last!] in $0.addLine(lastLine, in: drawing, time: $1) }
        self.time = time
        drawing.lines.removeLast()
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func insertLine(_ line: Line, at i: Int, in drawing: Drawing, time: Q) {
        registerUndo { $0.removeLine(at: i, in: drawing, time: $1) }
        self.time = time
        drawing.lines.insert(line, at: i)
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func removeLine(at i: Int, in drawing: Drawing, time: Q) {
        let oldLine = drawing.lines[i]
        registerUndo { $0.insertLine(oldLine, at: i, in: drawing, time: $1) }
        self.time = time
        drawing.lines.remove(at: i)
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func setSelectionLineIndexes(_ lineIndexes: [[Int]], in drawing: Drawing, time: Q) {
        registerUndo { [os = drawing.selectionLineIndexes] in $0.setSelectionLineIndexes(os, in: drawing, time: $1) }
        self.time = time
        drawing.selectionLineIndexes = lineIndexes
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    
    func click(with event: DragEvent) {
        selectCell(at: point(from: event))
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
    private func setMaterial(_ material: Material, time: Q) {
        registerUndo { [om = materialEditor.material] in $0.setMaterial(om, time: $1) }
        self.time = time
        materialEditor.material = material
    }
    private func setSelectionCellItems(_ cellItems: [[CellItem]], in animation: Animation, time: Q) {
        registerUndo { [os = animation.selectionCellItems] in $0.setSelectionCellItems(os, in: animation, time: $1) }
        self.time = time
        animation.selectionCellItems = cellItems
        setNeedsDisplay()
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    
    func addPoint(with event: KeyInputEvent) {
        let p = convertToCurrentLocal(point(from: event))
        guard let nearest = cut.editNode.nearestLine(at: p) else {
            return
        }
        if let drawing = nearest.drawing {
            replaceLine(nearest.line.splited(at: nearest.pointIndex), oldLine: nearest.line, at: nearest.lineIndex, in: drawing, time: time)
            updateEditView(with: p)
        } else if let cellItem = nearest.cellItem {
            setGeometries(
                Geometry.geometriesWithSplitedControl(with: cellItem.keyGeometries, at: nearest.lineIndex, pointIndex: nearest.pointIndex),
                oldKeyGeometries: cellItem.keyGeometries,
                in: cellItem, cut.editNode.editAnimation, time: time
            )
            updateEditView(with: p)
        }
    }
    func deletePoint(with event: KeyInputEvent) {
        let p = convertToCurrentLocal(point(from: event))
        guard let nearest = cut.editNode.nearestLine(at: p) else {
            return
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
            updateEditView(with: p)
        } else if let cellItem = nearest.cellItem {
            setGeometries(
                Geometry.geometriesWithRemovedControl(
                    with: cellItem.keyGeometries, atLineIndex: nearest.lineIndex, index: nearest.pointIndex
                ),
                oldKeyGeometries: cellItem.keyGeometries,
                in: cellItem, cut.editNode.editAnimation, time: time
            )
            if cellItem.isEmptyKeyGeometries {
                removeCellItems([cellItem])
            }
            updateEditView(with: p)
        }
    }
    private func insert(_ control: Line.Control, at index: Int, in drawing: Drawing, _ lineIndex: Int, time: Q) {
        registerUndo { $0.removeControl(at: index, in: drawing, lineIndex, time: $1) }
        self.time = time
        drawing.lines[lineIndex] = drawing.lines[lineIndex].withInsert(control, at: index)
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func removeControl(at index: Int, in drawing: Drawing, _ lineIndex: Int, time: Q) {
        let line = drawing.lines[lineIndex]
        registerUndo { [oc = line.controls[index]] in $0.insert(oc, at: index, in: drawing, lineIndex, time: $1) }
        self.time = time
        drawing.lines[lineIndex] = line.withRemoveControl(at: index)
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    
    private var movePointNearest: Node.Nearest?, movePointOldPoint = CGPoint(), movePointIsSnap = false
    private let snapPointSnapDistance = 8.0.cf
    private var bezierSortedResult: Node.Nearest.BezierSortedResult?
    func movePoint(with event: DragEvent) {
        movePoint(with: event, isVertex: false)
    }
    func moveVertex(with event: DragEvent) {
        movePoint(with: event, isVertex: true)
    }
    func movePoint(with event: DragEvent, isVertex: Bool) {
        let p = convertToCurrentLocal(point(from: event))
        switch event.sendType {
        case .begin:
            if let nearest = cut.editNode.nearest(at: p, isWarp: isVertex) {
                bezierSortedResult = nearest.bezierSortedResult(at: p)
                movePointNearest = nearest
                movePointIsSnap = false
            }
            updateEditView(with: p)
            movePointOldPoint = p
        case .sending:
            let dp = p - movePointOldPoint
            if let nearest = movePointNearest {
                if nearest.drawingEdit != nil || nearest.cellItemEdit != nil {
                    movePointIsSnap = movePointIsSnap ? true : event.pressure == 1
                    let snapD = snapPointSnapDistance/scene.scale
                    if let e = nearest.drawingEdit {
                        var control = e.line.controls[e.pointIndex]
                        control.point = e.line.editPoint(withEditCenterPoint: nearest.point + dp, at: e.pointIndex)
                        if movePointIsSnap && (e.pointIndex == 1 || e.pointIndex == e.line.controls.count - 2) {
                            control.point = cut.editNode.editAnimation.snapPoint(
                                control.point, editLine: e.drawing.lines[e.lineIndex], editPointIndex: e.pointIndex, snapDistance: snapD
                            )
                        }
                        e.drawing.lines[e.lineIndex] = e.line.withReplaced(control, at: e.pointIndex)
                        let np = e.drawing.lines[e.lineIndex].editCenterPoint(at: e.pointIndex)
                        editPoint = Node.EditPoint(
                            nearestLine: e.drawing.lines[e.lineIndex], nearestPointIndex: e.pointIndex,
                            lines: [e.drawing.lines[e.lineIndex]],
                            point: np, isSnap: movePointIsSnap
                        )
                    } else if let e = nearest.cellItemEdit {
                        var control = e.geometry.lines[e.lineIndex].controls[e.pointIndex]
                        control.point = e.geometry.lines[e.lineIndex].editPoint(withEditCenterPoint: nearest.point + dp, at: e.pointIndex)
                        if movePointIsSnap && (e.pointIndex == 1 || e.pointIndex == e.geometry.lines[e.lineIndex].controls.count - 2) {
                            control.point = cut.editNode.editAnimation.snapPoint(
                                control.point, editLine: e.cellItem.cell.geometry.lines[e.lineIndex], editPointIndex: e.pointIndex, snapDistance: snapD
                            )
                        }
                        e.cellItem.cell.geometry = Geometry(
                            lines: e.geometry.lines.withReplaced(
                                e.geometry.lines[e.lineIndex].withReplaced(control, at: e.pointIndex).autoPressure(), at: e.lineIndex
                            )
                        )
                        let np = e.cellItem.cell.geometry.lines[e.lineIndex].editCenterPoint(at: e.pointIndex)
                        editPoint = Node.EditPoint(
                            nearestLine: e.cellItem.cell.geometry.lines[e.lineIndex], nearestPointIndex: e.pointIndex,
                            lines: [e.cellItem.cell.geometry.lines[e.lineIndex]],
                            point: np, isSnap: movePointIsSnap
                        )
                    }
                } else {
                    var np: CGPoint
                    if movePointIsSnap || event.pressure == 1, let b = bezierSortedResult {
                        movePointIsSnap = true
                        let snapD = snapPointSnapDistance/scene.scale
                        np = cut.editNode.editAnimation.snapPoint(nearest.point + dp, with: b, snapDistance: snapD)
                        if let e = nearest.drawingEditLineCap, let drawing = b.drawing {
                            var newLines = e.lines
                            if b.lineCap.line.controls.count == 2 {
                                let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                                var control = b.lineCap.line.controls[pointIndex]
                                control.point = cut.editNode.editAnimation.snapPoint(
                                    np, editLine: drawing.lines[b.lineCap.lineIndex], editPointIndex: pointIndex, snapDistance: snapD
                                )
                                newLines[b.lineCap.lineIndex] = b.lineCap.line.withReplaced(control, at: pointIndex)
                                np = control.point
                            } else if isVertex {
                                newLines[b.lineCap.lineIndex] = b.lineCap.line.warpedWith(deltaPoint: np - nearest.point, isFirst: b.lineCap.isFirst)
                            } else {
                                let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                                var control = b.lineCap.line.controls[pointIndex]
                                control.point = np
                                newLines[b.lineCap.lineIndex] = newLines[b.lineCap.lineIndex].withReplaced(
                                    control, at: b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                                )
                            }
                            drawing.lines = newLines
                            editPoint = Node.EditPoint(
                                nearestLine: drawing.lines[b.lineCap.lineIndex], nearestPointIndex: b.lineCap.pointIndex,
                                lines: drawing.lines,
                                point: np, isSnap: movePointIsSnap
                            )
                        } else if let cellItem = b.cellItem, let geometry = b.geometry {
                            for editLineCap in nearest.cellItemEditLineCaps {
                                if editLineCap.cellItem == cellItem {
                                    if b.lineCap.line.controls.count == 2 {
                                        let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                                        var control = b.lineCap.line.controls[pointIndex]
                                        control.point = cut.editNode.editAnimation.snapPoint(
                                            np, editLine: cellItem.cell.geometry.lines[b.lineCap.lineIndex], editPointIndex: pointIndex, snapDistance: snapD
                                        )
                                        cellItem.cell.geometry = Geometry(
                                            lines: geometry.lines.withReplaced(
                                                b.lineCap.line.withReplaced(control, at: pointIndex).autoPressure(), at: b.lineCap.lineIndex
                                            )
                                        )
                                        np = control.point
                                    } else if isVertex {
                                        let newLine = b.lineCap.line.warpedWith(deltaPoint: np - nearest.point, isFirst: b.lineCap.isFirst).autoPressure()
                                        cellItem.cell.geometry = Geometry(
                                            lines: geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)
                                        )
                                    } else {
                                        let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                                        var control = geometry.lines[b.lineCap.lineIndex].controls[pointIndex]
                                        control.point = np
                                        let newLine = b.lineCap.line.withReplaced(control, at: pointIndex).autoPressure()
                                        cellItem.cell.geometry = Geometry(
                                            lines: geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)
                                        )
                                    }
                                    editPoint = Node.EditPoint(
                                        nearestLine: cellItem.cell.geometry.lines[b.lineCap.lineIndex], nearestPointIndex: b.lineCap.pointIndex,
                                        lines: cellItem.cell.geometry.lines,
                                        point: np, isSnap: movePointIsSnap
                                    )
                                } else {
                                    editLineCap.cellItem.cell.geometry = editLineCap.geometry
                                }
                            }
                        }
                    } else {
                        np = nearest.point + dp
                        var editPointLines = [Line]()
                        if let e = nearest.drawingEditLineCap {
                            var newLines = e.drawing.lines
                            if isVertex {
                                for cap in e.drawingCaps {
                                    newLines[cap.lineIndex] = cap.line.warpedWith(deltaPoint: dp, isFirst: cap.isFirst)
                                }
                            } else {
                                for cap in e.drawingCaps {
                                    var control = cap.isFirst ? cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
                                    control.point = np
                                    newLines[cap.lineIndex] = newLines[cap.lineIndex].withReplaced(control, at: cap.isFirst ? 0 : cap.line.controls.count - 1)
                                }
                            }
                            e.drawing.lines = newLines
                            editPointLines = e.drawingCaps.map { newLines[$0.lineIndex] }
                        }
                        
                        for editLineCap in nearest.cellItemEditLineCaps {
                            var newLines = editLineCap.geometry.lines
                            if isVertex {
                                for cap in editLineCap.caps {
                                    newLines[cap.lineIndex] = cap.line.warpedWith(deltaPoint: dp, isFirst: cap.isFirst).autoPressure()
                                }
                            } else {
                                for cap in editLineCap.caps {
                                    var control = cap.isFirst ? cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
                                    control.point = np
                                    newLines[cap.lineIndex] = newLines[cap.lineIndex].withReplaced(control, at: cap.isFirst ? 0 : cap.line.controls.count - 1).autoPressure()
                                }
                            }
                            editLineCap.cellItem.cell.geometry = Geometry(lines: newLines)
                            editPointLines += editLineCap.caps.map { newLines[$0.lineIndex] }
                        }
                        if let b = bezierSortedResult {
                            if let cellItem = b.cellItem {
                                editPoint = Node.EditPoint(
                                    nearestLine: cellItem.cell.geometry.lines[b.lineCap.lineIndex], nearestPointIndex: b.lineCap.pointIndex,
                                    lines: Array(Set(editPointLines)),
                                    point: np, isSnap: movePointIsSnap
                                )
                            } else if let drawing = b.drawing {
                                editPoint = Node.EditPoint(
                                    nearestLine: drawing.lines[b.lineCap.lineIndex], nearestPointIndex: b.lineCap.pointIndex,
                                    lines: Array(Set(editPointLines)),
                                    point: np, isSnap: movePointIsSnap
                                )
                            }
                        }
                    }
                }
            }
        case .end:
            let dp = p - movePointOldPoint
            if let nearest = movePointNearest {
                if nearest.drawingEdit != nil || nearest.cellItemEdit != nil {
                    let snapD = snapPointSnapDistance/scene.scale
                    if let e = nearest.drawingEdit {
                        var control = e.line.controls[e.pointIndex]
                        control.point = e.line.editPoint(withEditCenterPoint: nearest.point + dp, at: e.pointIndex)
                        if movePointIsSnap && (e.pointIndex == 1 || e.pointIndex == e.line.controls.count - 2) {
                            control.point = cut.editNode.editAnimation.snapPoint(
                                control.point, editLine: e.drawing.lines[e.lineIndex], editPointIndex: e.pointIndex, snapDistance: snapD
                            )
                        }
                        replaceLine(e.line.withReplaced(control, at: e.pointIndex), oldLine: e.line, at: e.lineIndex, in: e.drawing, time: time)
                    } else if let e = nearest.cellItemEdit {
                        var control = e.geometry.lines[e.lineIndex].controls[e.pointIndex]
                        control.point = e.geometry.lines[e.lineIndex].editPoint(withEditCenterPoint: nearest.point + dp, at: e.pointIndex)
                        if movePointIsSnap && (e.pointIndex == 1 || e.pointIndex == e.geometry.lines[e.lineIndex].controls.count - 2) {
                            control.point = cut.editNode.editAnimation.snapPoint(
                                control.point, editLine: e.cellItem.cell.geometry.lines[e.lineIndex], editPointIndex: e.pointIndex, snapDistance: snapD
                            )
                        }
                        let newLine = e.geometry.lines[e.lineIndex].withReplaced(control, at: e.pointIndex).autoPressure()
                        setGeometry(
                            Geometry(lines: e.geometry.lines.withReplaced(newLine, at: e.lineIndex)),
                            oldGeometry: e.geometry,
                            at: cut.editNode.editAnimation.editKeyframeIndex, in: e.cellItem, time: time
                        )
                    }
                } else {
                    if movePointIsSnap, let b = bezierSortedResult {
                        let snapD = snapPointSnapDistance/scene.scale
                        let np = cut.editNode.editAnimation.snapPoint(nearest.point + dp, with: b, snapDistance: snapD)
                        if let e = nearest.drawingEditLineCap, let drawing = b.drawing {
                            var newLines = e.lines
                            if b.lineCap.line.controls.count == 2 {
                                let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                                var control = b.lineCap.line.controls[pointIndex]
                                control.point = cut.editNode.editAnimation.snapPoint(
                                    np, editLine: drawing.lines[b.lineCap.lineIndex], editPointIndex: pointIndex, snapDistance: snapD
                                )
                                newLines[b.lineCap.lineIndex] = b.lineCap.line.withReplaced(control, at: pointIndex)
                            } else if isVertex {
                                newLines[b.lineCap.lineIndex] = b.lineCap.line.warpedWith(deltaPoint: np - nearest.point, isFirst: b.lineCap.isFirst)
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
                                if editLineCap.cellItem == cellItem {
                                    if b.lineCap.line.controls.count == 2 {
                                        let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                                        var control = b.lineCap.line.controls[pointIndex]
                                        control.point = cut.editNode.editAnimation.snapPoint(
                                            np, editLine: cellItem.cell.geometry.lines[b.lineCap.lineIndex], editPointIndex: pointIndex, snapDistance: snapD
                                        )
                                        let newLine = b.lineCap.line.withReplaced(control, at: pointIndex).autoPressure()
                                        setGeometry(
                                            Geometry(lines: geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)),
                                            oldGeometry: geometry,
                                            at: cut.editNode.editAnimation.editKeyframeIndex, in: cellItem, time: time
                                        )
                                    } else if isVertex {
                                        let newLine = b.lineCap.line.warpedWith(deltaPoint: np - nearest.point, isFirst: b.lineCap.isFirst).autoPressure()
                                        setGeometry(
                                            Geometry(lines: geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)),
                                            oldGeometry: geometry,
                                            at: cut.editNode.editAnimation.editKeyframeIndex, in: cellItem, time: time
                                        )
                                    } else {
                                        let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                                        var control = geometry.lines[b.lineCap.lineIndex].controls[pointIndex]
                                        control.point = np
                                        let newLine = b.lineCap.line.withReplaced(control, at: pointIndex).autoPressure()
                                        setGeometry(
                                            Geometry(lines: geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)),
                                            oldGeometry: geometry,
                                            at: cut.editNode.editAnimation.editKeyframeIndex, in: cellItem, time: time
                                        )
                                    }
                                } else {
                                    editLineCap.cellItem.cell.geometry = editLineCap.geometry
                                }
                            }
                        }
                        bezierSortedResult = nil
                    } else {
                        let np = nearest.point + dp
                        if let e = nearest.drawingEditLineCap {
                            var newLines = e.drawing.lines
                            if isVertex {
                                for cap in e.drawingCaps {
                                    newLines[cap.lineIndex] = cap.line.warpedWith(deltaPoint: dp, isFirst: cap.isFirst)
                                }
                            } else {
                                for cap in e.drawingCaps {
                                    var control = cap.isFirst ? cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
                                    control.point = np
                                    newLines[cap.lineIndex] = newLines[cap.lineIndex].withReplaced(control, at: cap.isFirst ? 0 : cap.line.controls.count - 1)
                                }
                            }
                            setLines(newLines, oldLines: e.lines, drawing: e.drawing, time: time)
                        }
                        for editLineCap in nearest.cellItemEditLineCaps {
                            var newLines = editLineCap.geometry.lines
                            if isVertex {
                                for cap in editLineCap.caps {
                                    newLines[cap.lineIndex] = cap.line.warpedWith(deltaPoint: dp, isFirst: cap.isFirst).autoPressure()
                                }
                            } else {
                                for cap in editLineCap.caps {
                                    var control = cap.isFirst ? cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
                                    control.point = np
                                    newLines[cap.lineIndex] = newLines[cap.lineIndex].withReplaced(control, at: cap.isFirst ? 0 : cap.line.controls.count - 1).autoPressure()
                                }
                            }
                            setGeometry(Geometry(lines: newLines), oldGeometry: editLineCap.geometry, at: cut.editNode.editAnimation.editKeyframeIndex, in: editLineCap.cellItem, time: time)
                        }
                    }
                }
                movePointIsSnap = false
                movePointNearest = nil
                bezierSortedResult = nil
                updateEditView(with: p)
            }
        }
        setNeedsDisplay()
    }
    private func replaceLine(_ line: Line, oldLine: Line, at i: Int, in drawing: Drawing, time: Q) {
        registerUndo { $0.replaceLine(oldLine, oldLine: line, at: i, in: drawing, time: $1) }
        self.time = time
        drawing.lines[i] = line
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    
    private var moveZOldPoint = CGPoint(), moveZCellTuple: (indexes: [Int], parent: Cell, oldChildren: [Cell])?
    private var moveZMinDeltaIndex = 0, moveZMaxDeltaIndex = 0, moveZHeight = 2.0.cf
    private weak var moveZOldCell: Cell?
    func moveZ(with event: DragEvent) {
        let p = point(from: event), cp = convertToCurrentLocal(point(from: event))
        switch event.sendType {
        case .begin:
            let indicationCellsTuple = cut.editNode.indicationCellsTuple(with : cp, reciprocalScale: scene.reciprocalScale)
            switch indicationCellsTuple.type {
            case .none:
                break
            case .indication:
                let cell = indicationCellsTuple.cellItems.first!.cell
                cut.editNode.rootCell.depthFirstSearch(duplicate: false) { parent, aCell in
                    if cell === aCell, let index = parent.children.index(of: cell) {
                        moveZCellTuple = ([index], parent, parent.children)
                        moveZMinDeltaIndex = -index
                        moveZMaxDeltaIndex = parent.children.count - 1 - index
                    }
                }
            case .selection:
                let firstCell = indicationCellsTuple.cellItems[0].cell, cutAllSelectionCells = indicationCellsTuple.cellItems.map { $0.cell }//cutAllSelectionCells = cut.editNode.allEditSelectionCellsWithNoEmptyGeometry
                var firstParent: Cell?
                cut.editNode.rootCell.depthFirstSearch(duplicate: false) { parent, cell in
                    if cell === firstCell {
                        firstParent = parent
                    }
                }
                
                //x < XX x > YY -> parent
                
                if let firstParent = firstParent {
                    var indexes = [Int]()
                    cut.editNode.rootCell.depthFirstSearch(duplicate: false) { parent, cell in
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
            }
        }
        setNeedsDisplay()
    }
    private func setChildren(_ children: [Cell], oldChildren: [Cell], inParent parent: Cell, time: Q) {
        registerUndo { $0.setChildren(oldChildren, oldChildren: children, inParent: parent, time: $1) }
        self.time = time
        parent.children = children
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    
    private var moveSelection = Node.Selection()
    private var transformBounds = CGRect(), moveOldPoint = CGPoint(), moveTransformOldPoint = CGPoint()
    enum TransformEditType {
        case move, warp, transform
    }
    func move(with event: DragEvent) {
        move(with: event, type: .move)
    }
    func warp(with event: DragEvent) {
        move(with: event, type: .warp)
    }
    func transform(with event: DragEvent) {
        move(with: event, type: .transform)
    }
    let moveTransformAngleTime = 0.1
    var moveTransformAngleOldTime = 0.0, moveTransformAnglePoint = CGPoint(), moveTransformAngleOldPoint = CGPoint()
    var isMoveTransformAngle = false, moveWarpIsSnap = false
    func move(with event: DragEvent,type: TransformEditType) {
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
                    self.moveWarpIsSnap = false
                }
            }
            moveOldPoint = p
        case .sending:
            if type != .move {
                if type == .warp {
                    moveWarpIsSnap = moveWarpIsSnap ? true : event.pressure == 1
                    if moveWarpIsSnap {
                        editTransform = nil
                        distanceWarp(with: event)
                        return
                    }
                }
                
                if var editTransform = editTransform {
                    
                    func aeditTransform(with lines: [Line]) -> Node.EditTransform {
                        var ps = [CGPoint]()
                        for line in lines {
                            line.allEditPoints { ps.append($0.0) }
                        }
                        let rb = RotateRect(convexHullPoints: CGPoint.convexHullPoints(with: ps))
                        let np = rb.convertToLocal(p: p)
                        let tx = np.x/rb.size.width, ty = np.y/rb.size.height
                        if ty < tx {
                            if ty < 1 - tx {
                                return Node.EditTransform(rotateRect: rb, anchorPoint: rb.midXMaxYPoint, point: rb.midXMinYPoint, oldPoint: rb.midXMinYPoint)
                            } else {
                                return Node.EditTransform(rotateRect: rb, anchorPoint: rb.minXMidYPoint, point: rb.maxXMidYPoint, oldPoint: rb.maxXMidYPoint)
                            }
                        } else {
                            if ty < 1 - tx {
                                return Node.EditTransform(rotateRect: rb, anchorPoint: rb.maxXMidYPoint, point: rb.minXMidYPoint, oldPoint: rb.minXMidYPoint)
                            } else {
                                return Node.EditTransform(rotateRect: rb, anchorPoint: rb.midXMinYPoint, point: rb.midXMaxYPoint, oldPoint: rb.midXMaxYPoint)
                            }
                        }
                    }
                    if moveSelection.cellTuples.isEmpty {
                        if moveSelection.drawingTuple?.lineIndexes.isEmpty ?? true {
                        } else if let moveDrawingTuple = moveSelection.drawingTuple {
                            editTransform = Node.EditTransform(
                                rotateRect: aeditTransform(with: moveDrawingTuple.lineIndexes.map { moveDrawingTuple.drawing.lines[$0] }).rotateRect,
                                anchorPoint: editTransform.anchorPoint, point: editTransform.point, oldPoint: editTransform.oldPoint
                            )
                        }
                    } else {
                        var lines = [Line]()
                        for mct in moveSelection.cellTuples {
                            lines += mct.cellItem.cell.geometry.lines
                        }
                        editTransform = Node.EditTransform(
                            rotateRect: aeditTransform(with: lines).rotateRect,
                            anchorPoint: editTransform.anchorPoint, point: editTransform.point, oldPoint: editTransform.oldPoint
                        )
                    }
                    
                    self.editTransform = editTransform.withPoint(p - moveTransformOldPoint + editTransform.oldPoint)
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
                    mcp.cellItem.replaceGeometry(mcp.geometry.applying(affine), at: mcp.animation.editKeyframeIndex)
                }
            }
        case .end:
            if type == .warp {
                if moveWarpIsSnap {
                    editTransform = nil
                    distanceWarp(with: event)
                    return
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
                    setGeometry(
                        mcp.geometry.applying(affine),
                        oldGeometry: mcp.geometry,
                        at: mcp.animation.editKeyframeIndex, in:mcp.cellItem, time: time
                    )
                }
                moveSelection = Node.Selection()
            }
            editTransform = nil
        }
        setNeedsDisplay()
    }
    
    func editTransform(at p: CGPoint) -> Node.EditTransform? {
        func editTransform(with lines: [Line]) -> Node.EditTransform {
            var ps = [CGPoint]()
            for line in lines {
                line.allEditPoints { ps.append($0.0) }
            }
            let rb = RotateRect(convexHullPoints: CGPoint.convexHullPoints(with: ps))
            let np = rb.convertToLocal(p: p)
            let tx = np.x/rb.size.width, ty = np.y/rb.size.height
            if ty < tx {
                if ty < 1 - tx {
                    return Node.EditTransform(rotateRect: rb, anchorPoint: rb.midXMaxYPoint, point: rb.midXMinYPoint, oldPoint: rb.midXMinYPoint)
                } else {
                    return Node.EditTransform(rotateRect: rb, anchorPoint: rb.minXMidYPoint, point: rb.maxXMidYPoint, oldPoint: rb.maxXMidYPoint)
                }
            } else {
                if ty < 1 - tx {
                    return Node.EditTransform(rotateRect: rb, anchorPoint: rb.maxXMidYPoint, point: rb.minXMidYPoint, oldPoint: rb.minXMidYPoint)
                } else {
                    return Node.EditTransform(rotateRect: rb, anchorPoint: rb.midXMinYPoint, point: rb.midXMaxYPoint, oldPoint: rb.midXMaxYPoint)
                }
            }
        }
        
        let selection = cut.editNode.selection(with: p, reciprocalScale: scene.reciprocalScale)
        if moveSelection.cellTuples.isEmpty {
            if let drawingTuple = moveSelection.drawingTuple {
                if drawingTuple.lineIndexes.isEmpty {
                    return nil
                } else {
                    return editTransform(with: drawingTuple.lineIndexes.map { drawingTuple.drawing.lines[$0] })
                }
            } else {
                return nil
            }
        } else {
            var lines = [Line]()
            for mct in selection.cellTuples {
                lines += mct.cellItem.cell.geometry.lines
            }
            return editTransform(with: lines)
        }
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
                        newLines[i] = wdp.oldLines[i].warpedWith(
                            deltaPoint: dp, editPoint: moveOldPoint, minDistance: minWarpDistance, maxDistance: maxWarpDistance
                        )
                    }
                    wdp.drawing.lines = newLines
                }
                for wcp in moveSelection.cellTuples {
                    wcp.cellItem.replaceGeometry(
                        wcp.geometry.warpedWith(
                            deltaPoint: dp, editPoint: moveOldPoint, minDistance: minWarpDistance, maxDistance: maxWarpDistance
                        ),
                        at: wcp.animation.editKeyframeIndex
                    )
                }
            }
        case .end:
            if !moveSelection.isEmpty {
                let dp = p - moveOldPoint
                if let wdp = moveSelection.drawingTuple {
                    var newLines = wdp.oldLines
                    for i in wdp.lineIndexes {
                        newLines[i] = wdp.oldLines[i].warpedWith(
                            deltaPoint: dp, editPoint: moveOldPoint, minDistance: minWarpDistance, maxDistance: maxWarpDistance
                        )
                    }
                    setLines(newLines, oldLines: wdp.oldLines, drawing: wdp.drawing, time: time)
                }
                for wcp in moveSelection.cellTuples {
                    setGeometry(
                        wcp.geometry.warpedWith(
                            deltaPoint: dp, editPoint: moveOldPoint, minDistance: minWarpDistance, maxDistance: maxWarpDistance
                        ),
                        oldGeometry: wcp.geometry,
                        at: wcp.animation.editKeyframeIndex, in: wcp.cellItem, time: time
                    )
                }
                moveSelection = Node.Selection()
            }
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
    
    func scroll(with event: ScrollEvent) {
        self.viewTransform = viewTransform.with(translation: viewTransform.translation + event.scrollDeltaPoint)
        updateEditView(with: convertToCurrentLocal(point(from: event)))
    }
    var minScale = 0.00001.cf, blockScale = 1.0.cf, maxScale = 64.0.cf
    var correctionScale = 1.28.cf, correctionRotation = 1.0.cf/(4.2*(.pi))
    private var isBlockScale = false, oldScale = 0.0.cf
    func zoom(with event: PinchEvent) {
        let scale = viewTransform.scale.x
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
    }
    var blockRotations: [CGFloat] = [-.pi, 0.0, .pi]
    private var isBlockRotation = false, blockRotation = 0.0.cf, oldRotation = 0.0.cf
    func rotate(with event: RotateEvent) {
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
    }
    func reset(with event: DoubleTapEvent) {
        if !viewTransform.isIdentity {
            self.viewTransform = Transform()
        }
    }
    func zoom(at p: CGPoint, handler: () -> ()) {
        let point = convertToCurrentLocal(p)
        handler()
        let newPoint = convertFromCurrentLocal(point)
        self.viewTransform = viewTransform.with(translation: viewTransform.translation - (newPoint - p))
    }
    
    func lookUp(with event: TapEvent) -> Referenceable {
        let indicationCellsTuple = cut.editNode.indicationCellsTuple(with:
            convertToCurrentLocal(point(from: event)), reciprocalScale: scene.reciprocalScale
        )
        if let cellItem = indicationCellsTuple.cellItems.first {
            return cellItem.cell
        } else {
            return self
        }
    }
}
