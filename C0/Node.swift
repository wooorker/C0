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

import CoreGraphics
import QuartzCore

final class Node: NSObject, NSCoding {
    private(set) weak var parent: Node?
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
    
    var time: Beat {
        didSet {
            tracks.forEach { $0.time = time }
            updateTransform()
            children.forEach { $0.time = time }
        }
    }
    var duration: Beat {
        didSet {
            tracks.forEach { $0.duration = duration }
            children.forEach { $0.duration = duration }
        }
    }
    
    func updateTransform() {
        let t = Node.transformWith(time: time, tracks: tracks)
        transform = t.transform
        wigglePhase = t.wigglePhase
    }
    
    var isHidden: Bool
    
    var rootCell: Cell
    var tracks: [NodeTrack]
    var editTrackIndex: Int {
        didSet {
            tracks[oldValue].cellItems.forEach { $0.cell.isLocked = true }
            tracks[editTrackIndex].cellItems.forEach { $0.cell.isLocked = false }
        }
    }
    var editTrack: NodeTrack {
        return tracks[editTrackIndex]
    }
    var selectionTrackIndexes = [Int]()
    
    func insertCell(_ cellItem: CellItem,
                    in parents: [(cell: Cell, index: Int)], _ track: NodeTrack) {
        guard cellItem.cell.children.isEmpty else {
            fatalError()
        }
        guard cellItem.keyGeometries.count == track.animation.keyframes.count else {
            fatalError()
        }
        guard !track.cellItems.contains(cellItem) else {
            fatalError()
        }
        for parent in parents {
            parent.cell.children.insert(cellItem.cell, at: parent.index)
        }
        track.cellItems.append(cellItem)
    }
    func insertCells(_ cellItems: [CellItem], rootCell: Cell,
                     at index: Int, in parent: Cell, _ track: NodeTrack) {
        for cell in rootCell.children.reversed() {
            parent.children.insert(cell, at: index)
        }
        for cellItem in cellItems {
            if cellItem.keyGeometries.count != track.animation.keyframes.count {
                fatalError()
            }
            if track.cellItems.contains(cellItem) {
                fatalError()
            }
            track.cellItems.append(cellItem)
        }
    }
    func removeCell(_ cellItem: CellItem,
                    in parents: [(cell: Cell, index: Int)], _ track: NodeTrack) {
        if !cellItem.cell.children.isEmpty {
            fatalError()
        }
        for parent in parents {
            parent.cell.children.remove(at: parent.index)
        }
        track.cellItems.remove(at: track.cellItems.index(of: cellItem)!)
    }
    func removeCells(_ cellItems: [CellItem], rootCell: Cell, in parent: Cell, _ track: NodeTrack) {
        for cell in rootCell.children {
            parent.children.remove(at: parent.children.index(of: cell)!)
        }
        for cellItem in cellItems {
            track.cellItems.remove(at: track.cellItems.index(of: cellItem)!)
        }
    }
    
    struct CellRemoveManager {
        let trackAndCellItems: [(track: NodeTrack, cellItems: [CellItem])]
        let rootCell: Cell
        let parents: [(cell: Cell, index: Int)]
        func contains(_ cellItem: CellItem) -> Bool {
            for tac in trackAndCellItems {
                if tac.cellItems.contains(cellItem) {
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
        var trackAndCellItems = [(track: NodeTrack, cellItems: [CellItem])]()
        for track in tracks {
            var cellItems = [CellItem]()
            cells = cells.filter {
                if let removeCellItem = track.cellItem(with: $0) {
                    cellItems.append(removeCellItem)
                    return false
                }
                return true
            }
            if !cellItems.isEmpty {
                trackAndCellItems.append((track, cellItems))
            }
        }
        if trackAndCellItems.isEmpty {
            fatalError()
        }
        return CellRemoveManager(trackAndCellItems: trackAndCellItems,
                                 rootCell: cellItem.cell,
                                 parents: rootCell.parents(with: cellItem.cell))
    }
    func insertCell(with crm: CellRemoveManager) {
        for parent in crm.parents {
            parent.cell.children.insert(crm.rootCell, at: parent.index)
        }
        for tac in crm.trackAndCellItems {
            for cellItem in tac.cellItems {
                if cellItem.keyGeometries.count != tac.track.animation.keyframes.count {
                    fatalError()
                }
                if tac.track.cellItems.contains(cellItem) {
                    fatalError()
                }
                tac.track.cellItems.append(cellItem)
            }
        }
    }
    func removeCell(with crm: CellRemoveManager) {
        for parent in crm.parents {
            parent.cell.children.remove(at: parent.index)
        }
        for tac in crm.trackAndCellItems {
            for cellItem in tac.cellItems {
                tac.track.cellItems.remove(at: tac.track.cellItems.index(of: cellItem)!)
            }
        }
    }
    
    var transform: Transform, material: Material
    static func transformWith(time: Beat,
                              tracks: [NodeTrack]) -> (transform: Transform, wigglePhase: CGFloat) {
        var translation = CGPoint(), scale = CGPoint(), rotation = 0.0.cf
        var wiggleSize = CGPoint(), hz = 0.0.cf, phase = 0.0.cf, transformCount = 0.0
        for track in tracks {
            if let t = track.transformItem?.transform {
                translation.x += t.translation.x
                translation.y += t.translation.y
                scale.x += t.scale.x
                scale.y += t.scale.y
                rotation += t.rotation
                wiggleSize.x += t.wiggle.amplitude.x
                wiggleSize.y += t.wiggle.amplitude.y
                hz += t.wiggle.frequency
                phase += track.wigglePhaseWith(time: time, lastHz: t.wiggle.frequency)
                transformCount += 1
            }
        }
        if transformCount > 0 {
            let reciprocalTransformCount = 1 / transformCount.cf
            let wiggle = Wiggle(amplitude: wiggleSize, frequency: hz * reciprocalTransformCount)
            return (Transform(translation: translation, scale: scale, rotation: rotation,
                              wiggle: wiggle),
                    phase * reciprocalTransformCount)
        } else {
            return (Transform(), 0)
        }
    }
    var wigglePhase: CGFloat = 0
    
    init(parent: Node? = nil, children: [Node] = [Node](),
         isHidden: Bool = false,
         rootCell: Cell = Cell(material: Material(color: .background)),
         transform: Transform = Transform(), material: Material = Material(),
         tracks: [NodeTrack] = [NodeTrack()], editTrackIndex: Int = 0,
         time: Beat = 0, duration: Beat = 1) {
        
        guard !tracks.isEmpty else {
            fatalError()
        }
        self.parent = parent
        self.children = children
        self.isHidden = isHidden
        self.rootCell = rootCell
        self.transform = transform
        self.material = material
        self.tracks = tracks
        self.editTrackIndex = editTrackIndex
        self.time = time
        self.duration = duration
        super.init()
        tracks.forEach { $0.duration = duration }
        children.forEach { $0.parent = self }
    }
    
    private enum CodingKeys: String, CodingKey {
        case
        children, isHidden, rootCell, transform, wigglePhase,
        material, tracks, editTrackIndex, selectionTrackIndexes, time, duration
    }
    init?(coder: NSCoder) {
        parent = nil
        children = coder.decodeObject(forKey: CodingKeys.children.rawValue) as? [Node] ?? []
        isHidden = coder.decodeBool(forKey: CodingKeys.isHidden.rawValue)
        rootCell = coder.decodeObject(forKey: CodingKeys.rootCell.rawValue) as? Cell ?? Cell()
        transform = coder.decodeDecodable(
            Transform.self, forKey: CodingKeys.transform.rawValue) ?? Transform()
        wigglePhase = coder.decodeDouble(forKey: CodingKeys.wigglePhase.rawValue).cf
        material = coder.decodeObject(forKey: CodingKeys.material.rawValue) as? Material ?? Material()
        tracks = coder.decodeObject(forKey: CodingKeys.tracks.rawValue) as? [NodeTrack] ?? []
        editTrackIndex = coder.decodeInteger(forKey: CodingKeys.editTrackIndex.rawValue)
        selectionTrackIndexes = coder.decodeObject(forKey: CodingKeys.selectionTrackIndexes.rawValue)
            as? [Int] ?? []
        time = coder.decodeDecodable(Beat.self, forKey: CodingKeys.time.rawValue) ?? 0
        duration = coder.decodeDecodable(Beat.self, forKey: CodingKeys.duration.rawValue) ?? 0
        super.init()
        children.forEach { $0.parent = self }
    }
    func encode(with coder: NSCoder) {
        coder.encode(children, forKey: CodingKeys.children.rawValue)
        coder.encode(isHidden, forKey: CodingKeys.isHidden.rawValue)
        coder.encode(rootCell, forKey: CodingKeys.rootCell.rawValue)
        coder.encodeEncodable(transform, forKey: CodingKeys.transform.rawValue)
        coder.encode(wigglePhase.d, forKey: CodingKeys.wigglePhase.rawValue)
        coder.encode(material, forKey: CodingKeys.material.rawValue)
        coder.encode(tracks, forKey: CodingKeys.tracks.rawValue)
        coder.encode(editTrackIndex, forKey: CodingKeys.editTrackIndex.rawValue)
        coder.encode(selectionTrackIndexes, forKey: CodingKeys.selectionTrackIndexes.rawValue)
        coder.encodeEncodable(time, forKey: CodingKeys.time.rawValue)
        coder.encodeEncodable(duration, forKey: CodingKeys.duration.rawValue)
    }
    
    var imageBounds: CGRect {
        return tracks.reduce(rootCell.allImageBounds) { $0.unionNoEmpty($1.imageBounds) }
    }
    
    enum IndicationCellType {
        case none, indication, selection
    }
    func indicationCellsTuple(with  point: CGPoint, reciprocalScale: CGFloat
        ) -> (cellItems: [CellItem], selectionLineIndexes: [Int], type: IndicationCellType) {
        
        let allEditSelectionCells = editTrack.selectionCellItemsWithNoEmptyGeometry(at: point)
        if !allEditSelectionCells.isEmpty {
            return (allEditSelectionCells, [], .selection)
        } else if
            let cell = rootCell.at(point, reciprocalScale: reciprocalScale),
            let cellItem = editTrack.cellItem(with: cell) {
            
            return ([cellItem], [], .indication)
        } else {
            let drawing = editTrack.drawingItem.drawing
            let lineIndexes = drawing.isNearestSelectionLineIndexes(at: point) ?
                drawing.selectionLineIndexes : []
            if lineIndexes.isEmpty {
                return ([], [], .none)
//                return drawing.lines.count == 0 ?
//                    ([], [], .none) : ([], Array(0 ..< drawing.lines.count), .indication)
            } else {
                return ([], lineIndexes, .selection)
            }
        }
    }
    var allSelectionCellItemsWithNoEmptyGeometry: [CellItem] {
        var selectionCellItems = [CellItem]()
        tracks.forEach { selectionCellItems += $0.selectionCellItemsWithNoEmptyGeometry }
        return selectionCellItems
    }
    func allSelectionCellItemsWithNoEmptyGeometry(at p: CGPoint) -> [CellItem] {
        for track in tracks {
            let cellItems = track.selectionCellItemsWithNoEmptyGeometry(at: p)
            if !cellItems.isEmpty {
                var selectionCellItems = [CellItem]()
                tracks.forEach { selectionCellItems += $0.selectionCellItemsWithNoEmptyGeometry }
                return selectionCellItems
            }
        }
        return []
    }
    struct Selection {
        var cellTuples: [(track: NodeTrack, cellItem: CellItem, geometry: Geometry)] = []
        var drawingTuple: (drawing: Drawing, lineIndexes: [Int], oldLines: [Line])? = nil
        var isEmpty: Bool {
            return (drawingTuple?.lineIndexes.isEmpty ?? true) && cellTuples.isEmpty
        }
    }
    func selection(with point: CGPoint, reciprocalScale: CGFloat) -> Selection {
        let ict = self.indicationCellsTuple(with: point, reciprocalScale: reciprocalScale)
        if !ict.cellItems.isEmpty {
            return Selection(cellTuples: ict.cellItems.map { (track(with: $0), $0, $0.cell.geometry) },
                             drawingTuple: nil)
        } else if !ict.selectionLineIndexes.isEmpty {
            let drawing = editTrack.drawingItem.drawing
            return Selection(cellTuples: [],
                             drawingTuple: (drawing, ict.selectionLineIndexes, drawing.lines))
        } else {
            return Selection()
        }
    }
    
    func track(with cell: Cell) -> NodeTrack {
        for track in tracks {
            if track.contains(cell) {
                return track
            }
        }
        fatalError()
    }
    func trackAndCellItem(with cell: Cell) -> (track: NodeTrack, cellItem: CellItem) {
        for track in tracks {
            if let cellItem = track.cellItem(with: cell) {
                return (track, cellItem)
            }
        }
        fatalError()
    }
    func track(with cellItem: CellItem) -> NodeTrack {
        for track in tracks {
            if track.contains(cellItem) {
                return track
            }
        }
        fatalError()
    }
    func isInterpolatedKeyframe(with animation: Animation) -> Bool {
        let keyIndex = animation.loopedKeyframeIndex(withTime: time)
        return animation.editKeyframe.interpolation != .none && keyIndex.interTime != 0
            && keyIndex.index != animation.keyframes.count - 1
    }
    func isContainsKeyframe(with animation: Animation) -> Bool {
        let keyIndex = animation.loopedKeyframeIndex(withTime: time)
        return keyIndex.interTime == 0
    }
    var maxTime: Beat {
        return tracks.reduce(Beat(0)) { max($0, $1.animation.keyframes.last?.time ?? 0) }
    }
    func maxTimeWithOtherAnimation(_ animation: Animation) -> Beat {
        return tracks.reduce(Beat(0)) { $1 !== animation ?
            max($0, $1.animation.keyframes.last?.time ?? 0) : $0 }
    }
    func cellItem(at point: CGPoint, reciprocalScale: CGFloat, with track: NodeTrack) -> CellItem? {
        if let cell = rootCell.at(point, reciprocalScale: reciprocalScale) {
            let gc = trackAndCellItem(with: cell)
            return gc.track == track ? gc.cellItem : nil
        } else {
            return nil
        }
    }
    
    var indexPath: IndexPath {
        guard let parent = parent else {
            return IndexPath()
        }
        return parent.indexPath.appending(parent.children.index(of: self)!)
    }
    
    var worldAffineTransform: CGAffineTransform {
        if let parentAffine = parent?.worldAffineTransform {
            return transform.affineTransform.concatenating(parentAffine)
        } else {
            return transform.affineTransform
        }
    }
    var worldScale: CGFloat {
        if let parentScale = parent?.worldScale {
            return transform.scale.x * parentScale
        } else {
            return transform.scale.x
        }
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
            let drawing: Drawing?, cellItem: CellItem?, geometry: Geometry?
            let lineCap: LineCap, point: CGPoint
        }
        func bezierSortedResult(at p: CGPoint) -> BezierSortedResult? {
            var minDrawing: Drawing?, minCellItem: CellItem?
            var minLineCap: LineCap?, minD² = CGFloat.infinity
            func minNearest(with caps: [LineCap]) -> Bool {
                var isMin = false
                for cap in caps {
                    let d² = (cap.isFirst ?
                        cap.line.bezier(at: 0) :
                        cap.line.bezier(at: cap.line.controls.count - 3)).minDistance²(at: p)
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
                return BezierSortedResult(drawing: drawing, cellItem: nil, geometry: nil,
                                          lineCap: lineCap, point: point)
            } else if let cellItem = minCellItem, let lineCap = minLineCap {
                return BezierSortedResult(drawing: nil, cellItem: cellItem,
                                          geometry: cellItem.cell.geometry,
                                          lineCap: lineCap, point: point)
            }
            return nil
        }
    }
    func nearest(at point: CGPoint, isVertex: Bool) -> Nearest? {
        var minD = CGFloat.infinity, minDrawing: Drawing?, minCellItem: CellItem?
        var minLine: Line?, minLineIndex = 0, minPointIndex = 0, minPoint = CGPoint()
        func nearestEditPoint(from lines: [Line]) -> Bool {
            var isNearest = false
            for (j, line) in lines.enumerated() {
                line.allEditPoints() { p, i in
                    if !(isVertex && i != 0 && i != line.controls.count - 1) {
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
        
        if nearestEditPoint(from: editTrack.drawingItem.drawing.lines) {
            minDrawing = editTrack.drawingItem.drawing
        }
        for cellItem in editTrack.cellItems {
            if nearestEditPoint(from: cellItem.cell.lines) {
                minDrawing = nil
                minCellItem = cellItem
            }
        }
        
        if let minLine = minLine {
            if minPointIndex == 0 || minPointIndex == minLine.controls.count - 1 {
                func caps(with point: CGPoint, _ lines: [Line]) -> [LineCap] {
                    return lines.enumerated().flatMap {
                        if point == $0.element.firstPoint {
                            return LineCap(line: $0.element, lineIndex: $0.offset, isFirst: true)
                        }
                        if point == $0.element.lastPoint {
                            return LineCap(line: $0.element, lineIndex: $0.offset, isFirst: false)
                        }
                        return nil
                    }
                }
                let drawingCaps = caps(with: minPoint, editTrack.drawingItem.drawing.lines)
                let drawingResult: (drawing: Drawing, lines: [Line], drawingCaps: [LineCap])? =
                    drawingCaps.isEmpty ? nil : (editTrack.drawingItem.drawing,
                                                 editTrack.drawingItem.drawing.lines, drawingCaps)
                let cellResults: [(cellItem: CellItem, geometry: Geometry, caps: [LineCap])]
                cellResults = editTrack.cellItems.flatMap {
                    let aCaps = caps(with: minPoint, $0.cell.geometry.lines)
                    return aCaps.isEmpty ? nil : ($0, $0.cell.geometry, aCaps)
                }
                return Nearest(drawingEdit: nil, cellItemEdit: nil,
                               drawingEditLineCap: drawingResult,
                               cellItemEditLineCaps: cellResults, point: minPoint)
            } else {
                if let drawing = minDrawing {
                    return Nearest(drawingEdit: (drawing, minLine, minLineIndex, minPointIndex),
                                   cellItemEdit: nil,
                                   drawingEditLineCap: nil, cellItemEditLineCaps: [],
                                   point: minPoint)
                } else if let cellItem = minCellItem {
                    return Nearest(drawingEdit: nil,
                                   cellItemEdit: (cellItem, cellItem.cell.geometry,
                                                  minLineIndex, minPointIndex),
                                   drawingEditLineCap: nil, cellItemEditLineCaps: [],
                                   point: minPoint)
                }
            }
        }
        return nil
    }
    func nearestLine(at point: CGPoint
        ) -> (drawing: Drawing?, cellItem: CellItem?, line: Line, lineIndex: Int, pointIndex: Int)? {
        
        guard let nearest = self.nearest(at: point, isVertex: false) else {
            return nil
        }
        if let e = nearest.drawingEdit {
            return (e.drawing, nil, e.line, e.lineIndex, e.pointIndex)
        } else if let e = nearest.cellItemEdit {
            return (nil, e.cellItem, e.geometry.lines[e.lineIndex], e.lineIndex, e.pointIndex)
        } else if nearest.drawingEditLineCap != nil || !nearest.cellItemEditLineCaps.isEmpty {
            if let b = nearest.bezierSortedResult(at: point) {
                return (b.drawing, b.cellItem, b.lineCap.line, b.lineCap.lineIndex,
                        b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1)
            }
        }
        return nil
    }
    
    func draw(scene: Scene, viewType: Cut.ViewType,
              scale: CGFloat, rotation: CGFloat,
              viewScale: CGFloat, viewRotation: CGFloat,
              in ctx: CGContext) {
        
        let inScale = scale * transform.scale.x, inRotation = rotation + transform.rotation
        let inViewScale = viewScale * transform.scale.x
        let inViewRotation = viewRotation + transform.rotation
        let reciprocalScale = 1 / inScale, reciprocalAllScale = 1 / inViewScale
        
        ctx.concatenate(transform.affineTransform)
        
        if material.opacity != 1 || !(material.type == .normal || material.type == .lineless) {
            ctx.saveGState()
            ctx.setAlpha(material.opacity)
            ctx.setBlendMode(material.type.blendMode)
            if material.type == .blur || material.type == .luster
                || material.type == .add || material.type == .subtract {
                
                if let bctx = CGContext.bitmap(with: ctx.boundingBoxOfClipPath.size) {
                    _draw(scene: scene, viewType: viewType,
                          reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalAllScale,
                          scale: inViewScale, rotation: inViewRotation, in: bctx)
                    children.forEach { $0.draw(scene: scene, viewType: viewType,
                                               scale: inScale, rotation: inRotation,
                                               viewScale: inViewScale, viewRotation: inViewRotation,
                                               in: bctx) }
                    if let image = bctx.makeImage() {
                        let ciImage = CIImage(cgImage: image)
                        let cictx = CIContext(cgContext: ctx, options: nil)
                        let filter = CIFilter(name: "CIGaussianBlur")
                        filter?.setValue(ciImage, forKey: kCIInputImageKey)
                        filter?.setValue(Float(material.lineWidth), forKey: kCIInputRadiusKey)
                        if let outputImage = filter?.outputImage {
                            cictx.draw(outputImage,
                                       in: ctx.boundingBoxOfClipPath, from: outputImage.extent)
                        }
                    }
                }
            } else {
                ctx.beginTransparencyLayer(auxiliaryInfo: nil)
                _draw(scene: scene, viewType: viewType,
                      reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalAllScale,
                      scale: inViewScale, rotation: inViewRotation, in: ctx)
                children.forEach { $0.draw(scene: scene, viewType: viewType,
                                           scale: inScale, rotation: inRotation,
                                           viewScale: inViewScale, viewRotation: inViewRotation,
                                           in: ctx) }
                ctx.endTransparencyLayer()
            }
            ctx.restoreGState()
        } else {
            _draw(scene: scene, viewType: viewType,
                  reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalAllScale,
                  scale: inViewScale, rotation: inViewRotation, in: ctx)
            children.forEach { $0.draw(scene: scene, viewType: viewType,
                                       scale: inScale, rotation: inRotation,
                                       viewScale: inViewScale, viewRotation: inViewRotation,
                                       in: ctx) }
        }
    }
    
    private func _draw(
        scene: Scene, viewType: Cut.ViewType, reciprocalScale: CGFloat, reciprocalAllScale: CGFloat,
        scale: CGFloat, rotation: CGFloat,
        in ctx: CGContext
        ) {
        let isEdit = viewType != .preview && viewType != .editMaterial && viewType != .editingMaterial
        moveWithWiggle: if viewType == .preview && !transform.wiggle.isEmpty {
            let p = transform.wiggle.phasePosition(with: CGPoint(),
                                                   phase: wigglePhase / scene.frameRate.cf)
            ctx.translateBy(x: p.x, y: p.y)
        }
        guard !isHidden else {
            return
        }
        rootCell.children.forEach {
            $0.draw(
                isEdit: isEdit,
                reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalAllScale,
                scale: scale, rotation: rotation,
                in: ctx
            )
        }
        drawAnimation: do {
            if isEdit {
                tracks.forEach {
                    if !$0.isHidden {
                        if $0 === editTrack {
                            $0.drawingItem.drawEdit(withReciprocalScale: reciprocalScale, in: ctx)
                        } else {
                            ctx.setAlpha(0.08)
                            $0.drawingItem.drawEdit(withReciprocalScale: reciprocalScale, in: ctx)
                            ctx.setAlpha(1)
                        }
                    }
                }
            } else {
                var alpha = 1.0.cf
                tracks.forEach {
                    if !$0.isHidden {
                        ctx.setAlpha(alpha)
                        $0.drawingItem.draw(withReciprocalScale: reciprocalScale, in: ctx)
                    }
                    alpha = max(alpha * 0.4, 0.25)
                }
                ctx.setAlpha(1)
            }
        }
    }
    
    struct Edit {
        var indicationCellItem: CellItem? = nil, editMaterial: Material? = nil, editZ: EditZ? = nil
        var editPoint: EditPoint? = nil, editTransform: EditTransform? = nil, point: CGPoint?
    }
    func drawEdit(_ edit: Edit,
                  scene: Scene, viewType: Cut.ViewType,
                  strokeLine: Line?, strokeLineWidth: CGFloat, strokeLineColor: Color,
                  reciprocalViewScale: CGFloat, scale: CGFloat, rotation: CGFloat,
                  in ctx: CGContext) {

        let worldScale = self.worldScale
        let rScale = 1 / worldScale
        let rAllScale = reciprocalViewScale / worldScale
        let wat = worldAffineTransform
        ctx.saveGState()
        ctx.concatenate(wat)
        
        if !wat.isIdentity {
            ctx.setStrokeColor(Color.locked.cgColor)
            ctx.move(to: CGPoint(x: -10, y: 0))
            ctx.addLine(to: CGPoint(x: 10, y: 0))
            ctx.move(to: CGPoint(x: 0, y: -10))
            ctx.addLine(to: CGPoint(x: 0, y: 10))
            ctx.strokePath()
        }
        
        drawStroke: do {
            if let strokeLine = strokeLine {
                if viewType == .editSelection || viewType == .editDeselection {
                    let geometry = Geometry(lines: [strokeLine])
                    if viewType == .editSelection {
                        geometry.drawSkin(lineColor: .selectBorder, subColor: .select,
                                          reciprocalScale: rScale, reciprocalAllScale: rAllScale,
                                          in: ctx)
                    } else {
                        geometry.drawSkin(lineColor: .deselectBorder, subColor: .deselect,
                                          reciprocalScale: rScale, reciprocalAllScale: rAllScale,
                                          in: ctx)
                    }
                } else {
                    ctx.setFillColor(strokeLineColor.cgColor)
                    strokeLine.draw(size: strokeLineWidth * rScale, in: ctx)
                }
            }
        }
        
        let isEdit = viewType != .preview && viewType != .editingMaterial
        if isEdit {
            if !editTrack.isHidden {
                if viewType == .editPoint || viewType == .editVertex {
                    editTrack.drawTransparentCellLines(withReciprocalScale: rScale, in: ctx)
                }
                editTrack.drawPreviousNext(
                    isShownPrevious: scene.isShownPrevious, isShownNext: scene.isShownNext,
                    time: time, reciprocalScale: rScale, in: ctx
                )
            }
            
            for track in tracks {
                if !track.isHidden {
                    track.drawSelectionCells(
                        opacity: 0.75 * (track != editTrack ? 0.5 : 1),
                        color: .selection,
                        subColor: .subSelection,
                        reciprocalScale: rScale,  in: ctx
                    )
                    
                    let drawing = track.drawingItem.drawing
                    let selectionLineIndexes = drawing.selectionLineIndexes
                    if !selectionLineIndexes.isEmpty {
                        let imageBounds = selectionLineIndexes.reduce(CGRect()) {
                            $0.unionNoEmpty(drawing.lines[$1].imageBounds)
                        }
                        ctx.setStrokeColor(Color.selection.with(alpha: 0.8).cgColor)
                        ctx.setLineWidth(rScale)
                        ctx.stroke(imageBounds)
                    }
                }
            }
            if !editTrack.isHidden {
                let isMovePoint = viewType == .editPoint || viewType == .editVertex
                
                if viewType == .editMaterial {
                    if let material = edit.editMaterial {
                        drawMaterial: do {
                            rootCell.allCells { cell, stop in
                                if cell.material.id == material.id {
                                    ctx.addPath(cell.geometry.path)
                                }
                            }
                            ctx.setLineWidth(3 * rAllScale)
                            ctx.setLineJoin(.round)
                            ctx.setStrokeColor(Color.editMaterial.cgColor)
                            ctx.strokePath()
                            rootCell.allCells { cell, stop in
                                if cell.material.color == material.color
                                    && cell.material.id != material.id {
                                    
                                    ctx.addPath(cell.geometry.path)
                                }
                            }
                            ctx.setLineWidth(3 * rAllScale)
                            ctx.setLineJoin(.round)
                            ctx.setStrokeColor(Color.editMaterialColorOnly.cgColor)
                            ctx.strokePath()
                        }
                    }
                }
                
                if !isMovePoint,
                    let indicationCellItem = edit.indicationCellItem,
                    editTrack.cellItems.contains(indicationCellItem) {
                    
                    editTrack.drawSkinCellItem(indicationCellItem,
                                               reciprocalScale: rScale, reciprocalAllScale: rAllScale,
                                               in: ctx)
                    
                    if editTrack.selectionCellItems.contains(indicationCellItem), let p = edit.point {
                        editTrack.selectionCellItems.forEach {
                            drawNearestCellLine(for: p, cell: $0.cell, lineColor: .selection,
                                                reciprocalAllScale: rAllScale, in: ctx)
                        }
                    }
                }
                if let editZ = edit.editZ {
                    drawEditZ(editZ, reciprocalAllScale: rAllScale, in: ctx)
                }
                if isMovePoint {
                    drawEditPoints(with: edit.editPoint, isEditVertex: viewType == .editVertex,
                                   reciprocalAllScale: rAllScale, in: ctx)
                }
                if let editTransform = edit.editTransform {
                    if viewType == .editWarp {
                        drawWarp(with: editTransform, reciprocalAllScale: rAllScale, in: ctx)
                    } else if viewType == .editTransform {
                        drawTransform(with: editTransform, reciprocalAllScale: rAllScale, in: ctx)
                    }
                }
            }
        }
        ctx.restoreGState()
        if viewType != .preview {
            drawTransform(scene.frame, in: ctx)
        }
    }
    
    func drawTransform(_ cameraFrame: CGRect, in ctx: CGContext) {
        func drawCameraBorder(bounds: CGRect, inColor: Color, outColor: Color) {
            ctx.setStrokeColor(inColor.cgColor)
            ctx.stroke(bounds.insetBy(dx: -0.5, dy: -0.5))
            ctx.setStrokeColor(outColor.cgColor)
            ctx.stroke(bounds.insetBy(dx: -1.5, dy: -1.5))
        }
        ctx.setLineWidth(1)
        if !transform.wiggle.isEmpty {
            let amplitude = transform.wiggle.amplitude
            drawCameraBorder(
                bounds: cameraFrame.insetBy(dx: -amplitude.x, dy: -amplitude.y),
                inColor: Color.cameraBorder, outColor: Color.cutSubBorder
            )
        }
        let track = editTrack
        func drawPreviousNextCamera(t: Transform, color: Color) {
            let affine = transform.affineTransform.inverted().concatenating(t.affineTransform)
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
        let keyframeIndex = track.animation.loopedKeyframeIndex(withTime: time)
        if keyframeIndex.interTime == 0 && keyframeIndex.index > 0 {
            if let t = track.transformItem?.keyTransforms[keyframeIndex.index - 1], transform != t {
                drawPreviousNextCamera(t: t, color: Color.red)
            }
        }
        if let t = track.transformItem?.keyTransforms[keyframeIndex.index], transform != t {
            drawPreviousNextCamera(t: t, color: Color.red)
        }
        if keyframeIndex.index < track.animation.keyframes.count - 1 {
            if let t = track.transformItem?.keyTransforms[keyframeIndex.index + 1], transform != t {
                drawPreviousNextCamera(t: t, color: Color.green)
            }
        }
        drawCameraBorder(bounds: cameraFrame, inColor: Color.locked, outColor: Color.cutSubBorder)
    }
    
    struct EditPoint: Equatable {
        let nearestLine: Line, nearestPointIndex: Int, lines: [Line], point: CGPoint, isSnap: Bool
        func draw(withReciprocalAllScale reciprocalAllScale: CGFloat, in ctx: CGContext) {
            for line in lines {
                ctx.setFillColor((line === nearestLine ? Color.selection : Color.subSelection).cgColor)
                line.draw(size: 2 * reciprocalAllScale, in: ctx)
            }
            point.draw(
                radius: 3 * reciprocalAllScale, lineWidth: reciprocalAllScale,
                inColor: isSnap ? Color.snap : Color.selection, outColor: Color.controlPointIn, in: ctx
            )
        }
        static func ==(lhs: EditPoint, rhs: EditPoint) -> Bool {
            return lhs.nearestLine == rhs.nearestLine && lhs.nearestPointIndex == rhs.nearestPointIndex
                && lhs.lines == rhs.lines && lhs.point == rhs.point && lhs.isSnap == lhs.isSnap
        }
    }
    private let editPointRadius = 0.5.cf, lineEditPointRadius = 1.5.cf, pointEditPointRadius = 3.0.cf
    func drawEditPoints(with editPoint: EditPoint?, isEditVertex: Bool,
                        reciprocalAllScale: CGFloat, in ctx: CGContext) {
        if let ep = editPoint, ep.isSnap {
            let p: CGPoint?, np: CGPoint?
            if ep.nearestPointIndex == 1 {
                p = ep.nearestLine.firstPoint
                np = ep.nearestLine.controls.count == 2 ?
                    nil : ep.nearestLine.controls[2].point
            } else if ep.nearestPointIndex == ep.nearestLine.controls.count - 2 {
                p = ep.nearestLine.lastPoint
                np = ep.nearestLine.controls.count == 2 ?
                    nil :
                    ep.nearestLine.controls[ep.nearestLine.controls.count - 3].point
            } else {
                p = nil
                np = nil
            }
            if let p = p {
                func drawSnap(with point: CGPoint, capPoint: CGPoint) {
                    if let ps = CGPoint.boundsPointWithLine(ap: point, bp: capPoint,
                                                            bounds: ctx.boundingBoxOfClipPath) {
                        ctx.move(to: ps.p0)
                        ctx.addLine(to: ps.p1)
                        ctx.setLineWidth(1 * reciprocalAllScale)
                        ctx.setStrokeColor(Color.selection.cgColor)
                        ctx.strokePath()
                    }
                    if let np = np, ep.nearestLine.controls.count > 2 {
                        let p1 = ep.nearestPointIndex == 1 ?
                            ep.nearestLine.controls[1].point :
                            ep.nearestLine.controls[ep.nearestLine.controls.count - 2].point
                        ctx.move(to: p1.mid(np))
                        ctx.addLine(to: p1)
                        ctx.addLine(to: capPoint)
                        ctx.setLineWidth(0.5 * reciprocalAllScale)
                        ctx.setStrokeColor(Color.selection.cgColor)
                        ctx.strokePath()
                        p1.draw(radius: 2 * reciprocalAllScale, lineWidth: reciprocalAllScale,
                                inColor: Color.selection, outColor: Color.controlPointIn, in: ctx)
                    }
                }
                func drawSnap(with lines: [Line]) {
                    for line in lines {
                        if line != ep.nearestLine {
                            if ep.nearestLine.controls.count == 3 {
                                if line.firstPoint == ep.nearestLine.firstPoint {
                                    drawSnap(with: line.controls[1].point,
                                             capPoint: ep.nearestLine.firstPoint)
                                } else if line.lastPoint == ep.nearestLine.firstPoint {
                                    drawSnap(with: line.controls[line.controls.count - 2].point,
                                             capPoint: ep.nearestLine.firstPoint)
                                }
                                if line.firstPoint == ep.nearestLine.lastPoint {
                                    drawSnap(with: line.controls[1].point,
                                             capPoint: ep.nearestLine.lastPoint)
                                } else if line.lastPoint == ep.nearestLine.lastPoint {
                                    drawSnap(with: line.controls[line.controls.count - 2].point,
                                             capPoint: ep.nearestLine.lastPoint)
                                }
                            } else {
                                if line.firstPoint == p {
                                    drawSnap(with: line.controls[1].point, capPoint: p)
                                } else if line.lastPoint == p {
                                    drawSnap(with: line.controls[line.controls.count - 2].point,
                                             capPoint: p)
                                }
                            }
                        } else if line.firstPoint == line.lastPoint {
                            if ep.nearestPointIndex == line.controls.count - 2 {
                                drawSnap(with: line.controls[1].point, capPoint: p)
                            } else if ep.nearestPointIndex == 1 && p == line.firstPoint {
                                drawSnap(with: line.controls[line.controls.count - 2].point,
                                         capPoint: p)
                            }
                        }
                    }
                }
                drawSnap(with: editTrack.drawingItem.drawing.lines)
                for cellItem in editTrack.cellItems {
                    drawSnap(with: cellItem.cell.lines)
                }
            }
        }
        editPoint?.draw(withReciprocalAllScale: reciprocalAllScale, in: ctx)
        
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
        if !editTrack.cellItems.isEmpty {
            for cellItem in editTrack.cellItems {
                if !cellItem.cell.isEditHidden {
                    if !isEditVertex {
                        Line.drawEditPointsWith(lines: cellItem.cell.lines,
                                                reciprocalScale: reciprocalAllScale, in: ctx)
                    }
                    updateCapPointDic(with: cellItem.cell.lines)
                }
            }
        }
        if !isEditVertex {
            Line.drawEditPointsWith(lines: editTrack.drawingItem.drawing.lines,
                                    reciprocalScale: reciprocalAllScale, in: ctx)
        }
        updateCapPointDic(with: editTrack.drawingItem.drawing.lines)
        
        let r = lineEditPointRadius * reciprocalAllScale, lw = 0.5 * reciprocalAllScale
        for v in capPointDic {
            v.key.draw(
                radius: r, lineWidth: lw,
                inColor: v.value ? .controlPointJointIn : .controlPointCapIn,
                outColor: .controlPointOut, in: ctx
            )
        }
    }
    
    struct EditZ: Equatable {
        let cells: [Cell], point: CGPoint, firstPoint: CGPoint
        static func ==(lhs: EditZ, rhs: EditZ) -> Bool {
            return lhs.cells == rhs.cells && lhs.point == rhs.point
                && lhs.firstPoint == rhs.firstPoint
        }
    }
    let editZHeight = 5.0.cf
    func drawEditZ(_ editZ: EditZ, reciprocalAllScale: CGFloat, in ctx: CGContext) {
        rootCell.depthFirstSearch(duplicate: true) { parent, cell in
            if editZ.cells.contains(cell), let index = parent.children.index(of: cell) {
                if !parent.isEmptyGeometry {
                    parent.geometry.clip(in: ctx) {
                        Cell.drawCellPaths(cells: Array(parent.children[(index + 1)...]),
                                           color: Color.moveZ, in: ctx)
                    }
                } else {
                    Cell.drawCellPaths(cells: Array(parent.children[(index + 1)...]),
                                       color: Color.moveZ, in: ctx)
                }
            }
        }
        guard let firstCell = editZ.cells.first else {
            return
        }
        let editZHeight = self.editZHeight * reciprocalAllScale
        var y = 0.0.cf
        rootCell.allCells { (cell, stop) in
            if cell == firstCell {
                stop = true
            }
            y += editZHeight
        }
        ctx.saveGState()
        ctx.setLineWidth(reciprocalAllScale)
        var p = CGPoint(x: editZ.firstPoint.x, y: editZ.firstPoint.y - y)
        rootCell.allCells { (cell, stop) in
            drawNearestCellLine(for: p, cell: cell, lineColor: .border,
                                reciprocalAllScale: reciprocalAllScale, in: ctx)
            p.y += editZHeight
        }
        p = CGPoint(x: editZ.firstPoint.x, y: editZ.firstPoint.y - y)
        rootCell.allCells { (cell, stop) in
            ctx.setFillColor(cell.material.color.cgColor)
            ctx.setStrokeColor(Color.border.cgColor)
            ctx.addRect(CGRect(x: p.x, y: p.y - editZHeight / 2,
                               width: editZHeight, height: editZHeight))
            ctx.drawPath(using: .fillStroke)
            p.y += editZHeight
        }
        ctx.restoreGState()
    }
    func drawNearestCellLine(for p: CGPoint, cell: Cell, lineColor: Color,
                             reciprocalAllScale: CGFloat, in ctx: CGContext) {
        if let n = cell.geometry.nearestBezier(with: p) {
            let np = cell.geometry.lines[n.lineIndex].bezier(at: n.bezierIndex).position(withT: n.t)
            ctx.setStrokeColor(Color.background.multiply(alpha: 0.75).cgColor)
            ctx.setLineWidth(3 * reciprocalAllScale)
            ctx.move(to: CGPoint(x: p.x, y: p.y))
            ctx.addLine(to: CGPoint(x: np.x, y: p.y))
            ctx.addLine(to: CGPoint(x: np.x, y: np.y))
            ctx.strokePath()
            ctx.setStrokeColor(lineColor.cgColor)
            ctx.setLineWidth(reciprocalAllScale)
            ctx.move(to: CGPoint(x: p.x, y: p.y))
            ctx.addLine(to: CGPoint(x: np.x, y: p.y))
            ctx.addLine(to: CGPoint(x: np.x, y: np.y))
            ctx.strokePath()
        }
    }
    
    struct EditTransform: Equatable {
        static let centerRatio = 0.25.cf
        let rotateRect: RotateRect, anchorPoint: CGPoint
        let point: CGPoint, oldPoint: CGPoint, isCenter: Bool
        func with(_ point: CGPoint) -> EditTransform {
            return EditTransform(rotateRect: rotateRect, anchorPoint: anchorPoint,
                                 point: point, oldPoint: oldPoint, isCenter: isCenter)
        }
        static func ==(lhs: EditTransform, rhs: EditTransform) -> Bool {
            return
                lhs.rotateRect == rhs.rotateRect && lhs.anchorPoint == rhs.anchorPoint
                    && lhs.point == rhs.point && lhs.oldPoint == lhs.oldPoint
                    && lhs.isCenter == rhs.isCenter
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
        let scaleX = newP.x / newOldP.x, skewY = (newP.y - newOldP.y) / newOldP.x
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
        let angle = et.anchorPoint.tangential(et.point)
        let oldAngle = et.anchorPoint.tangential(et.oldPoint)
        let scale = r / oldR
        var affine = CGAffineTransform(translationX: et.anchorPoint.x, y: et.anchorPoint.y)
        affine = affine.rotated(by: angle.differenceRotation(oldAngle))
        affine = affine.scaledBy(x: scale, y: scale)
        affine = affine.translatedBy(x: -et.anchorPoint.x, y: -et.anchorPoint.y)
        return affine
    }
    func drawWarp(with et: EditTransform, reciprocalAllScale: CGFloat, in ctx: CGContext) {
        if et.isCenter {
            drawLine(firstPoint: et.rotateRect.midXMinYPoint, lastPoint: et.rotateRect.midXMaxYPoint,
                     reciprocalAllScale: reciprocalAllScale, in: ctx)
            drawLine(firstPoint: et.rotateRect.minXMidYPoint, lastPoint: et.rotateRect.maxXMidYPoint,
                     reciprocalAllScale: reciprocalAllScale, in: ctx)
        } else {
            drawLine(firstPoint: et.anchorPoint, lastPoint: et.point,
                     reciprocalAllScale: reciprocalAllScale, in: ctx)
        }
        
        drawRotateRect(with: et, reciprocalAllScale: reciprocalAllScale, in: ctx)
        et.anchorPoint.draw(radius: lineEditPointRadius * reciprocalAllScale,
                            lineWidth: reciprocalAllScale, in: ctx)
    }
    func drawTransform(with et: EditTransform, reciprocalAllScale: CGFloat, in ctx: CGContext) {
        ctx.setAlpha(0.5)
        drawLine(firstPoint: et.anchorPoint, lastPoint: et.oldPoint,
                 reciprocalAllScale: reciprocalAllScale, in: ctx)
        drawCircleWith(radius: et.oldPoint.distance(et.anchorPoint), anchorPoint: et.anchorPoint,
                       reciprocalAllScale: reciprocalAllScale, in: ctx)
        ctx.setAlpha(1)
        drawLine(firstPoint: et.anchorPoint, lastPoint: et.point,
                 reciprocalAllScale: reciprocalAllScale, in: ctx)
        drawCircleWith(radius: et.point.distance(et.anchorPoint), anchorPoint: et.anchorPoint,
                       reciprocalAllScale: reciprocalAllScale, in: ctx)
        
        drawRotateRect(with: et, reciprocalAllScale: reciprocalAllScale, in: ctx)
        et.anchorPoint.draw(radius: lineEditPointRadius * reciprocalAllScale,
                            lineWidth: reciprocalAllScale, in: ctx)
    }
    func drawRotateRect(with et: EditTransform, reciprocalAllScale: CGFloat, in ctx: CGContext) {
        ctx.setLineWidth(reciprocalAllScale)
        ctx.setStrokeColor(Color.camera.cgColor)
        ctx.saveGState()
        ctx.concatenate(et.rotateRect.affineTransform)
        let w = et.rotateRect.size.width * EditTransform.centerRatio
        let h = et.rotateRect.size.height * EditTransform.centerRatio
        ctx.stroke(CGRect(x: (et.rotateRect.size.width - w) / 2,
                          y: (et.rotateRect.size.height - h) / 2, width: w, height: h))
        ctx.stroke(CGRect(x: 0, y: 0,
                          width: et.rotateRect.size.width, height: et.rotateRect.size.height))
        ctx.restoreGState()
    }
    
    func drawCircleWith(radius r: CGFloat, anchorPoint: CGPoint,
                        reciprocalAllScale: CGFloat, in ctx: CGContext) {
        let cb = CGRect(x: anchorPoint.x - r, y: anchorPoint.y - r, width: r * 2, height: r * 2)
        let outLineWidth = 3 * reciprocalAllScale, inLineWidth = 1.5 * reciprocalAllScale
        ctx.setLineWidth(outLineWidth)
        ctx.setStrokeColor(Color.controlPointOut.cgColor)
        ctx.strokeEllipse(in: cb)
        ctx.setLineWidth(inLineWidth)
        ctx.setStrokeColor(Color.controlPointIn.cgColor)
        ctx.strokeEllipse(in: cb)
    }
    func drawLine(firstPoint: CGPoint, lastPoint: CGPoint,
                  reciprocalAllScale: CGFloat, in ctx: CGContext) {
        let outLineWidth = 3 * reciprocalAllScale, inLineWidth = 1.5 * reciprocalAllScale
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
extension Node: Copying {
    func copied(from copier: Copier) -> Node {
        let node = Node(parent: nil,
                        children: children.map { copier.copied($0) },
                        rootCell: copier.copied(rootCell),
                        transform: transform, material: material,
                        tracks: tracks.map { copier.copied($0) },
                        editTrackIndex: editTrackIndex,
                        time: time, duration: duration)
        node.children.forEach { $0.parent = node }
        return node
    }
}
extension Node: Referenceable {
    static let name = Localization(english: "Node", japanese: "ノード")
}
