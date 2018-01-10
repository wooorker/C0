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

protocol Track: Animatable {
    var animation: Animation { get }
}
protocol KeyframeValue {
}

final class TempoTrack: NSObject, Track, NSCoding {
    private(set) var animation: Animation
    
    var time: Beat {
        didSet {
            updateInterpolation()
        }
    }
    func updateInterpolation() {
        animation.update(withTime: time, to: self)
    }
    func step(_ f0: Int) {
        tempoItem.step(f0)
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        tempoItem.linear(f0, f1, t: t)
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        tempoItem.firstMonospline(f1, f2, f3, with: msx)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        tempoItem.monospline(f0, f1, f2, f3, with: msx)
    }
    func endMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with msx: MonosplineX) {
        tempoItem.endMonospline(f0, f1, f2, with: msx)
    }
    
    var tempoItem: TempoItem {
        didSet {
            check(keyCount: tempoItem.keyTempos.count)
        }
    }
    
    func replace(_ keyframe: Keyframe, at index: Int) {
        animation.keyframes[index] = keyframe
    }
    func replace(_ keyframes: [Keyframe]) {
        check(keyCount: keyframes.count)
        animation.keyframes = keyframes
    }
    func replace(duration: Beat) {
        animation.duration = duration
    }
    func set(selectionkeyframeIndexes: [Int]) {
        animation.selectionKeyframeIndexes = selectionkeyframeIndexes
    }
    
    private func check(keyCount count: Int) {
        if count != animation.keyframes.count {
            fatalError()
        }
    }
    
    struct KeyframeValues: KeyframeValue {
        var tempo: BPM
    }
    func insert(_ keyframe: Keyframe, _ kv: KeyframeValues, at index: Int) {
        animation.keyframes.insert(keyframe, at: index)
        tempoItem.keyTempos.insert(kv.tempo, at: index)
    }
    func removeKeyframe(at index: Int) {
        animation.keyframes.remove(at: index)
        tempoItem.keyTempos.remove(at: index)
    }
    func set(_ keyTempos: [BPM], isSetTempoInItem: Bool  = true) {
        if keyTempos.count != animation.keyframes.count {
            fatalError()
        }
        if isSetTempoInItem {
            tempoItem.tempo = keyTempos[animation.editKeyframeIndex]
        }
        tempoItem.keyTempos = keyTempos
    }
    
    init(animation: Animation = Animation(),
         time: Beat = 0, duration: Beat = 0,
         tempoItem: TempoItem = TempoItem()) {
        
        self.animation = animation
        self.animation.duration = duration
        self.time = time
        self.tempoItem = tempoItem
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case animation, time, duration, tempoItem
    }
    init?(coder: NSCoder) {
        animation = coder.decodeDecodable(
            Animation.self, forKey: CodingKeys.animation.rawValue) ?? Animation()
        time = coder.decodeDecodable(Beat.self, forKey: CodingKeys.time.rawValue) ?? 0
        tempoItem = coder.decodeDecodable(
            TempoItem.self, forKey: CodingKeys.tempoItem.rawValue) ?? TempoItem()
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeEncodable(animation, forKey: CodingKeys.animation.rawValue)
        coder.encodeEncodable(time, forKey: CodingKeys.time.rawValue)
        coder.encodeEncodable(tempoItem, forKey: CodingKeys.tempoItem.rawValue)
    }
}
extension TempoTrack: Copying {
    func copied(from copier: Copier) -> TempoTrack {
        return TempoTrack(animation: animation, time: time,
                          tempoItem: copier.copied(tempoItem))
    }
}
extension TempoTrack: Referenceable {
    static let name = Localization(english: "Tempo Track", japanese: "テンポトラック")
}

final class NodeTrack: NSObject, Track, NSCoding {
    private(set) var animation: Animation
    
    var time: Beat {
        didSet {
            updateInterpolation()
        }
    }
    func updateInterpolation() {
        animation.update(withTime: time, to: self)
    }
    func step(_ f0: Int) {
        drawingItem.step(f0)
        cellItems.forEach { $0.step(f0) }
        materialItems.forEach { $0.step(f0) }
        transformItem?.step(f0)
        wiggleItem?.step(f0)
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        drawingItem.linear(f0, f1, t: t)
        cellItems.forEach { $0.linear(f0, f1, t: t) }
        materialItems.forEach { $0.linear(f0, f1, t: t) }
        transformItem?.linear(f0, f1, t: t)
        wiggleItem?.linear(f0, f1, t: t)
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        drawingItem.firstMonospline(f1, f2, f3, with: msx)
        cellItems.forEach { $0.firstMonospline(f1, f2, f3, with: msx) }
        materialItems.forEach { $0.firstMonospline(f1, f2, f3, with: msx) }
        transformItem?.firstMonospline(f1, f2, f3, with: msx)
        wiggleItem?.firstMonospline(f1, f2, f3, with: msx)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        drawingItem.monospline(f0, f1, f2, f3, with: msx)
        cellItems.forEach { $0.monospline(f0, f1, f2, f3, with: msx) }
        materialItems.forEach { $0.monospline(f0, f1, f2, f3, with: msx) }
        transformItem?.monospline(f0, f1, f2, f3, with: msx)
        wiggleItem?.monospline(f0, f1, f2, f3, with: msx)
    }
    func endMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with msx: MonosplineX) {
        drawingItem.endMonospline(f0, f1, f2, with: msx)
        cellItems.forEach { $0.endMonospline(f0, f1, f2, with: msx) }
        materialItems.forEach { $0.endMonospline(f0, f1, f2, with: msx) }
        transformItem?.endMonospline(f0, f1, f2, with: msx)
        wiggleItem?.endMonospline(f0, f1, f2, with: msx)
    }
    
    var isHidden: Bool {
        didSet {
            cellItems.forEach { $0.cell.isHidden = isHidden }
        }
    }
    
    var drawingItem: DrawingItem {
        didSet {
            check(keyCount: drawingItem.keyDrawings.count)
        }
    }
    
    var selectionCellItems: [CellItem]
    private(set) var cellItems: [CellItem]
    func append(_ cellItem: CellItem) {
        check(keyCount: cellItem.keyGeometries.count)
        cellItems.append(cellItem)
    }
    func remove(_ cellItem: CellItem) {
        if let i = cellItems.index(of: cellItem) {
            cellItems.remove(at: i)
        }
    }
    func replace(_ cellItems: [CellItem]) {
        cellItems.forEach { check(keyCount: $0.keyGeometries.count) }
        self.cellItems = cellItems
    }
    
    private(set) var materialItems: [MaterialItem]
    func append(_ materialItem: MaterialItem) {
        check(keyCount: materialItem.keyMaterials.count)
        materialItems.append(materialItem)
    }
    func remove(_ materialItem: MaterialItem) {
        if let i = materialItems.index(of: materialItem) {
            materialItems.remove(at: i)
        }
    }
    func replace(_ materialItems: [MaterialItem]) {
        materialItems.forEach { check(keyCount: $0.keyMaterials.count) }
        self.materialItems = materialItems
    }
    
    var transformItem: TransformItem? {
        didSet {
            if let transformItem = transformItem {
                check(keyCount: transformItem.keyTransforms.count)
            }
        }
    }
    var wiggleItem: WiggleItem? {
        didSet {
            if let wiggleItem = wiggleItem {
                check(keyCount: wiggleItem.keyWiggles.count)
            }
        }
    }
    
    func replace(_ keyframe: Keyframe, at index: Int) {
        animation.keyframes[index] = keyframe
    }
    func replace(_ keyframes: [Keyframe]) {
        check(keyCount: keyframes.count)
        animation.keyframes = keyframes
    }
    func replace(_ keyframes: [Keyframe], duration: Beat) {
        check(keyCount: keyframes.count)
        animation.keyframes = keyframes
        animation.duration = duration
    }
    func set(duration: Beat) {
        animation.duration = duration
    }
    func set(selectionkeyframeIndexes: [Int]) {
        animation.selectionKeyframeIndexes = selectionkeyframeIndexes
    }
    
    private func check(keyCount count: Int) {
        if count != animation.keyframes.count {
            fatalError()
        }
    }
    
    func insertCell(_ cellItem: CellItem, in parents: [(cell: Cell, index: Int)]) {
        guard cellItem.cell.children.isEmpty else {
            fatalError()
        }
        guard cellItem.keyGeometries.count == animation.keyframes.count else {
            fatalError()
        }
        guard !cellItems.contains(cellItem) else {
            fatalError()
        }
        parents.forEach { $0.cell.children.insert(cellItem.cell, at: $0.index) }
        cellItems.append(cellItem)
    }
    func insertCells(_ insertCellItems: [CellItem], rootCell: Cell, at index: Int, in parent: Cell) {
        rootCell.children.reversed().forEach { parent.children.insert($0, at: index) }
        insertCellItems.forEach {
            if $0.keyGeometries.count != animation.keyframes.count {
                fatalError()
            }
            if cellItems.contains($0) {
                fatalError()
            }
            cellItems.append($0)
        }
    }
    func removeCell(_ cellItem: CellItem, in parents: [(cell: Cell, index: Int)]) {
        if !cellItem.cell.children.isEmpty {
            fatalError()
        }
        parents.forEach { $0.cell.children.remove(at: $0.index) }
        cellItems.remove(at: cellItems.index(of: cellItem)!)
    }
    func removeCells(_ removeCellItems: [CellItem], rootCell: Cell, in parent: Cell) {
        rootCell.children.forEach { parent.children.remove(at: parent.children.index(of: $0)!) }
        removeCellItems.forEach { cellItems.remove(at: cellItems.index(of: $0)!) }
    }
    
    struct KeyframeValues: KeyframeValue {
        var drawing: Drawing, geometries: [Geometry], materials: [Material]
        var transform: Transform?, wiggle: Wiggle?
    }
    func insert(_ keyframe: Keyframe, _ kv: KeyframeValues, at index: Int) {
        guard kv.geometries.count <= cellItems.count
            && kv.materials.count <= materialItems.count else {
                
                fatalError()
        }
        animation.keyframes.insert(keyframe, at: index)
        drawingItem.keyDrawings.insert(kv.drawing, at: index)
        cellItems.enumerated().forEach { $0.element.keyGeometries.insert(kv.geometries[$0.offset],
                                                                         at: index) }
        materialItems.enumerated().forEach { $0.element.keyMaterials.insert(kv.materials[$0.offset],
                                                                            at: index) }
        if let transform = kv.transform {
            transformItem?.keyTransforms.insert(transform, at: index)
        }
        if let wiggle = kv.wiggle {
            wiggleItem?.keyWiggles.insert(wiggle, at: index)
        }
    }
    func removeKeyframe(at index: Int) {
        animation.keyframes.remove(at: index)
        drawingItem.keyDrawings.remove(at: index)
        cellItems.forEach { $0.keyGeometries.remove(at: index) }
        materialItems.forEach { $0.keyMaterials.remove(at: index) }
        transformItem?.keyTransforms.remove(at: index)
        wiggleItem?.keyWiggles.remove(at: index)
    }
    func set(_ keyGeometries: [Geometry], in cellItem: CellItem, isSetGeometryInCell: Bool  = true) {
        if keyGeometries.count != animation.keyframes.count {
            fatalError()
        }
        if isSetGeometryInCell, let i = cellItem.keyGeometries.index(of: cellItem.cell.geometry) {
            cellItem.cell.geometry = keyGeometries[i]
        }
        cellItem.keyGeometries = keyGeometries
    }
    func set(_ keyTransforms: [Transform], isSetTransformInItem: Bool  = true) {
        guard let transformItem = transformItem else {
            return
        }
        if keyTransforms.count != animation.keyframes.count {
            fatalError()
        }
        if isSetTransformInItem,
            let i = transformItem.keyTransforms.index(of: transformItem.transform) {
            
            transformItem.transform = keyTransforms[i]
        }
        transformItem.keyTransforms = keyTransforms
    }
    func set(_ keyWiggles: [Wiggle], isSetWiggleInItem: Bool  = true) {
        guard let wiggleItem = wiggleItem else {
            return
        }
        if keyWiggles.count != animation.keyframes.count {
            fatalError()
        }
        if isSetWiggleInItem, let i = wiggleItem.keyWiggles.index(of: wiggleItem.wiggle) {
            wiggleItem.wiggle = keyWiggles[i]
        }
        wiggleItem.keyWiggles = keyWiggles
    }
    func set(_ keyMaterials: [Material], in materailItem: MaterialItem) {
        guard keyMaterials.count == animation.keyframes.count else {
            fatalError()
        }
        materailItem.keyMaterials = keyMaterials
    }
    var currentItemValues: KeyframeValues {
        let geometries = cellItems.map { $0.cell.geometry }
        let materials = materialItems.map { $0.material }
        return KeyframeValues(drawing: drawingItem.drawing,
                              geometries: geometries, materials: materials,
                              transform: transformItem?.transform, wiggle: wiggleItem?.wiggle)
    }
    func keyframeItemValues(at index: Int) -> KeyframeValues {
        let geometries = cellItems.map { $0.keyGeometries[index] }
        let materials = materialItems.map { $0.keyMaterials[index] }
        return KeyframeValues(drawing: drawingItem.keyDrawings[index],
                              geometries: geometries, materials: materials,
                              transform: transformItem?.keyTransforms[index],
                              wiggle: wiggleItem?.keyWiggles[index])
    }
    
    init(animation: Animation = Animation(),
         time: Beat = 0,
         isHidden: Bool = false, selectionCellItems: [CellItem] = [],
         drawingItem: DrawingItem = DrawingItem(), cellItems: [CellItem] = [],
         materialItems: [MaterialItem] = [], transformItem: TransformItem? = nil) {
        
        self.animation = animation
        self.time = time
        self.isHidden = isHidden
        self.selectionCellItems = selectionCellItems
        self.drawingItem = drawingItem
        self.cellItems = cellItems
        self.materialItems = materialItems
        self.transformItem = transformItem
        super.init()
    }
    private init(animation: Animation, time: Beat, duration: Beat,
                 isHidden: Bool, selectionCellItems: [CellItem],
                 drawingItem: DrawingItem, cellItems: [CellItem], materialItems: [MaterialItem],
                 transformItem: TransformItem?, isInterporation: Bool) {
        
        self.animation = animation
        self.time = time
        self.isHidden = isHidden
        self.selectionCellItems = selectionCellItems
        self.drawingItem = drawingItem
        self.cellItems = cellItems
        self.materialItems = materialItems
        self.transformItem = transformItem
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case
        animation, time, duration, isHidden, selectionCellItems,
        drawingItem, cellItems, materialItems, transformItem, wiggleItem
    }
    init?(coder: NSCoder) {
        animation = coder.decodeDecodable(
            Animation.self, forKey: CodingKeys.animation.rawValue) ?? Animation()
        time = coder.decodeDecodable(Beat.self, forKey: CodingKeys.time.rawValue) ?? 0
        isHidden = coder.decodeBool(forKey: CodingKeys.isHidden.rawValue)
        selectionCellItems = coder.decodeObject(
            forKey: CodingKeys.selectionCellItems.rawValue) as? [CellItem] ?? []
        drawingItem = coder.decodeObject(
            forKey: CodingKeys.drawingItem.rawValue) as? DrawingItem ?? DrawingItem()
        cellItems = coder.decodeObject(forKey: CodingKeys.cellItems.rawValue) as? [CellItem] ?? []
        materialItems = coder.decodeObject(
            forKey: CodingKeys.materialItems.rawValue) as? [MaterialItem] ?? []
        transformItem = coder.decodeDecodable(
            TransformItem.self, forKey: CodingKeys.transformItem.rawValue)
        wiggleItem = coder.decodeDecodable(
            WiggleItem.self, forKey: CodingKeys.wiggleItem.rawValue)
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeEncodable(animation, forKey: CodingKeys.animation.rawValue)
        coder.encodeEncodable(time, forKey: CodingKeys.time.rawValue)
        coder.encode(isHidden, forKey: CodingKeys.isHidden.rawValue)
        coder.encode(selectionCellItems, forKey: CodingKeys.selectionCellItems.rawValue)
        coder.encode(drawingItem, forKey: CodingKeys.drawingItem.rawValue)
        coder.encode(cellItems, forKey: CodingKeys.cellItems.rawValue)
        coder.encode(materialItems, forKey: CodingKeys.materialItems.rawValue)
        coder.encodeEncodable(transformItem, forKey: CodingKeys.transformItem.rawValue)
        coder.encodeEncodable(wiggleItem, forKey: CodingKeys.wiggleItem.rawValue)
    }
    
    func contains(_ cell: Cell) -> Bool {
        for cellItem in cellItems {
            if cellItem.cell == cell {
                return true
            }
        }
        return false
    }
    func contains(_ cellItem: CellItem) -> Bool {
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
    var selectionCellItemsWithNoEmptyGeometry: [CellItem] {
        return selectionCellItems.filter { !$0.cell.geometry.isEmpty }
    }
    func selectionCellItemsWithNoEmptyGeometry(at point: CGPoint) -> [CellItem] {
        for cellItem in selectionCellItems {
            if cellItem.cell.contains(point) {
                return selectionCellItems.filter { !$0.cell.geometry.isEmpty }
            }
        }
        return []
    }
    
    var emptyKeyGeometries: [Geometry] {
        return animation.keyframes.map { _ in Geometry() }
    }
    var isEmptyGeometryWithCells: Bool {
        for cellItem in cellItems {
            if !cellItem.cell.geometry.isEmpty {
                return false
            }
        }
        return true
    }
    func isEmptyGeometryWithCells(at time: Beat) -> Bool {
        let index = animation.loopedKeyframeIndex(withTime: time).index
        for cellItem in cellItems {
            if !cellItem.keyGeometries[index].isEmpty {
                return false
            }
        }
        return true
    }
    func emptyKeyMaterials(with material: Material) -> [Material] {
        return animation.keyframes.map { _ in material }
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
    
    func wigglePhaseWith(time: Beat, lastHz: CGFloat) -> CGFloat {
        if let wiggleItem = wiggleItem, let firstWiggle = wiggleItem.keyWiggles.first {
            var phase = 0.0.cf, oldHz = firstWiggle.frequency, oldTime = Beat(0)
            for i in 1 ..< animation.keyframes.count {
                let newTime = animation.keyframes[i].time
                if time >= newTime {
                    let newHz = wiggleItem.keyWiggles[i].frequency
                    phase += (newHz + oldHz) * Double(newTime - oldTime).cf / 2
                    oldTime = newTime
                    oldHz = newHz
                } else {
                    return phase + (lastHz + oldHz) * Double(time - oldTime).cf / 2
                }
            }
            return phase + lastHz * Double(time - oldTime).cf
        } else {
            return 0
        }
    }
    
    func snapPoint(_ point: CGPoint, with n: Node.Nearest.BezierSortedResult,
                   snapDistance: CGFloat, grid: CGFloat?) -> CGPoint {
        
        let p: CGPoint
        if let grid = grid {
            p = CGPoint(x: point.x.interval(scale: grid), y: point.y.interval(scale: grid))
        } else {
            p = point
        }
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
    
    func snapPoint(_ sp: CGPoint, editLine: Line, editPointIndex: Int,
                   snapDistance: CGFloat) -> CGPoint {
        
        let p: CGPoint, isFirst = editPointIndex == 1 || editPointIndex == editLine.controls.count - 1
        if isFirst {
            p = editLine.firstPoint
        } else if editPointIndex == editLine.controls.count - 2 || editPointIndex == 0 {
            p = editLine.lastPoint
        } else {
            fatalError()
        }
        var snapLines = [(ap: CGPoint, bp: CGPoint)](), lastSnapLines = [(ap: CGPoint, bp: CGPoint)]()
        func snap(with lines: [Line]) {
            for line in lines {
                if editLine.controls.count == 3 {
                    if line != editLine {
                        if line.firstPoint == editLine.firstPoint {
                            snapLines.append((line.controls[1].point, editLine.firstPoint))
                        } else if line.lastPoint == editLine.firstPoint {
                            snapLines.append((line.controls[line.controls.count - 2].point,
                                              editLine.firstPoint))
                        }
                        if line.firstPoint == editLine.lastPoint {
                            lastSnapLines.append((line.controls[1].point, editLine.lastPoint))
                        } else if line.lastPoint == editLine.lastPoint {
                            lastSnapLines.append((line.controls[line.controls.count - 2].point,
                                                  editLine.lastPoint))
                        }
                    }
                } else {
                    if line.firstPoint == p && !(line == editLine && isFirst) {
                        snapLines.append((line.controls[1].point, p))
                    } else if line.lastPoint == p && !(line == editLine && !isFirst) {
                        snapLines.append((line.controls[line.controls.count - 2].point, p))
                    }
                }
            }
        }
        snap(with: drawingItem.drawing.lines)
        for cellItem in cellItems {
            snap(with: cellItem.cell.lines)
        }
        
        var minD = CGFloat.infinity, minIntersectionPoint: CGPoint?, minPoint = sp
        if !snapLines.isEmpty && !lastSnapLines.isEmpty {
            for sl in snapLines {
                for lsl in lastSnapLines {
                    if let ip = CGPoint.intersectionLine(sl.ap, sl.bp, lsl.ap, lsl.bp) {
                        let d = ip.distance(sp)
                        if d < snapDistance && d < minD {
                            minD = d
                            minIntersectionPoint = ip
                        }
                    }
                }
            }
        }
        if let minPoint = minIntersectionPoint {
            return minPoint
        }
        let ss = snapLines + lastSnapLines
        for sl in ss {
            let np = sp.nearestWithLine(ap: sl.ap, bp: sl.bp)
            let d = np.distance(sp)
            if d < snapDistance && d < minD {
                minD = d
                minPoint = np
            }
        }
        return minPoint
    }
    
    var imageBounds: CGRect {
        return cellItems.reduce(CGRect()) { $0.unionNoEmpty($1.cell.imageBounds) }
            .unionNoEmpty(drawingItem.imageBounds)
    }
    
    func drawPreviousNext(isShownPrevious: Bool, isShownNext: Bool,
                          time: Beat, reciprocalScale: CGFloat, in ctx: CGContext) {
        let index = animation.loopedKeyframeIndex(withTime: time).index
        drawingItem.drawPreviousNext(isShownPrevious: isShownPrevious, isShownNext: isShownNext,
                                     index: index, reciprocalScale: reciprocalScale, in: ctx)
        cellItems.forEach {
            $0.drawPreviousNext(lineWidth: drawingItem.lineWidth * reciprocalScale,
                                isShownPrevious: isShownPrevious, isShownNext: isShownNext,
                                index: index, in: ctx)
        }
    }
    func drawSelectionCells(opacity: CGFloat, color: Color, subColor: Color,
                            reciprocalScale: CGFloat, in ctx: CGContext) {
        if !isHidden && !selectionCellItems.isEmpty {
            ctx.setAlpha(opacity)
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            var geometrys = [Geometry]()
            ctx.setFillColor(subColor.with(alpha: 1).cgColor)
            func setPaths(with cellItem: CellItem) {
                let cell = cellItem.cell
                if !cell.geometry.isEmpty {
                    cell.geometry.addPath(in: ctx)
                    ctx.fillPath()
                    geometrys.append(cell.geometry)
                }
            }
            for cellItem in selectionCellItems {
                setPaths(with: cellItem)
            }
            ctx.endTransparencyLayer()
            ctx.setAlpha(1)
            
            ctx.setFillColor(color.with(alpha: 1).cgColor)
            for geometry in geometrys {
                geometry.draw(withLineWidth: 1.5 * reciprocalScale, in: ctx)
            }
        }
    }
    func drawTransparentCellLines(withReciprocalScale reciprocalScale: CGFloat, in ctx: CGContext) {
        cellItems.forEach {
            $0.cell.geometry.drawLines(withColor: Color.border,
                                       reciprocalScale: reciprocalScale, in: ctx)
            $0.cell.geometry.drawPathLine(withReciprocalScale: reciprocalScale, in: ctx)
        }
    }
    func drawSkinCellItem(_ cellItem: CellItem,
                          reciprocalScale: CGFloat, reciprocalAllScale: CGFloat, in ctx: CGContext) {
        cellItem.cell.geometry.drawSkin(
            lineColor: animation.isInterporation ? .warning : .indication,
            subColor: Color.subIndication.multiply(alpha: 0.2),
            skinLineWidth: animation.isInterporation ? 3 : 1,
            reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalAllScale, in: ctx
        )
    }
}
extension NodeTrack: Copying {
    func copied(from copier: Copier) -> NodeTrack {
        return NodeTrack(animation: animation,
                         time: time, isHidden: isHidden,
                         selectionCellItems: selectionCellItems.map { copier.copied($0) },
                         drawingItem: copier.copied(drawingItem),
                         cellItems: cellItems.map { copier.copied($0) },
                         materialItems: materialItems.map { copier.copied($0) },
                         transformItem: transformItem != nil ? copier.copied(transformItem!) : nil)
    }
}
extension NodeTrack: Referenceable {
    static let name = Localization(english: "Node Track", japanese: "ノードトラック")
}

/*
 # Issue
 Itemのstruct化
 */
protocol TrackItem {
    func step(_ f0: Int)
    func linear(_ f0: Int, _ f1: Int, t: CGFloat)
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX)
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX)
    func endMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with msx: MonosplineX)
}

final class DrawingItem: NSObject, TrackItem, NSCoding {
    var drawing: Drawing, color: Color, lineWidth: CGFloat
    fileprivate(set) var keyDrawings: [Drawing]
    
    func step(_ f0: Int) {
        drawing = keyDrawings[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        drawing = keyDrawings[f0]
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        drawing = keyDrawings[f1]
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        drawing = keyDrawings[f1]
    }
    func endMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with msx: MonosplineX) {
        drawing = keyDrawings[f1]
    }
    
    static let defaultLineWidth = 1.0.cf
    
    init(drawing: Drawing = Drawing(), keyDrawings: [Drawing] = [],
         color: Color = .strokeLine, lineWidth: CGFloat = defaultLineWidth) {
        
        self.drawing = drawing
        self.keyDrawings = keyDrawings.isEmpty ? [drawing] : keyDrawings
        self.color = color
        self.lineWidth = lineWidth
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case drawing, keyDrawings, lineWidth
    }
    init(coder: NSCoder) {
        drawing = coder.decodeObject(forKey: CodingKeys.drawing.rawValue) as? Drawing ?? Drawing()
        keyDrawings = coder.decodeObject(forKey: CodingKeys.keyDrawings.rawValue) as? [Drawing] ?? []
        lineWidth = coder.decodeDouble(forKey: CodingKeys.lineWidth.rawValue).cf
        color = .strokeLine
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(drawing, forKey: CodingKeys.drawing.rawValue)
        coder.encode(keyDrawings, forKey: CodingKeys.keyDrawings.rawValue)
        coder.encode(lineWidth.d, forKey: CodingKeys.lineWidth.rawValue)
    }
    
    var imageBounds: CGRect {
        return drawing.imageBounds(withLineWidth: lineWidth)
    }
    
    func drawEdit(withReciprocalScale reciprocalScale: CGFloat, in ctx: CGContext) {
        drawing.drawEdit(lineWidth: lineWidth * reciprocalScale, lineColor: color, in: ctx)
    }
    func draw(withReciprocalScale reciprocalScale: CGFloat, in ctx: CGContext) {
        drawing.draw(lineWidth: lineWidth * reciprocalScale, lineColor: color, in: ctx)
    }
    func drawPreviousNext(isShownPrevious: Bool, isShownNext: Bool,
                          index: Int, reciprocalScale: CGFloat, in ctx: CGContext) {
        let lineWidth = self.lineWidth * reciprocalScale
        if isShownPrevious && index - 1 >= 0 {
            keyDrawings[index - 1].draw(lineWidth: lineWidth, lineColor: Color.previous, in: ctx)
        }
        if isShownNext && index + 1 <= keyDrawings.count - 1 {
            keyDrawings[index + 1].draw(lineWidth: lineWidth, lineColor: Color.next, in: ctx)
        }
    }
}
extension DrawingItem: Copying {
    func copied(from copier: Copier) -> DrawingItem {
        return DrawingItem(drawing: copier.copied(drawing),
                           keyDrawings: keyDrawings.map { copier.copied($0) }, color: color)
    }
}
extension DrawingItem: Referenceable {
    static let name = Localization(english: "Drawing Item", japanese: "ドローイングアイテム")
}

final class CellItem: NSObject, TrackItem, NSCoding {
    let cell: Cell
    fileprivate(set) var keyGeometries: [Geometry]
    func replace(_ geometry: Geometry, at i: Int) {
        keyGeometries[i] = geometry
        cell.geometry = geometry
    }
    
    func step(_ f0: Int) {
        cell.geometry = keyGeometries[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        cell.geometry = Geometry.linear(keyGeometries[f0], keyGeometries[f1], t: t)
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        cell.geometry = Geometry.firstMonospline(keyGeometries[f1], keyGeometries[f2],
                                                 keyGeometries[f3], with: msx)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        cell.geometry = Geometry.monospline(keyGeometries[f0], keyGeometries[f1],
                                            keyGeometries[f2], keyGeometries[f3], with: msx)
    }
    func endMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with msx: MonosplineX) {
        cell.geometry = Geometry.endMonospline(keyGeometries[f0], keyGeometries[f1],
                                               keyGeometries[f2], with: msx)
    }
    
    init(cell: Cell, keyGeometries: [Geometry] = []) {
        self.cell = cell
        self.keyGeometries = keyGeometries
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case cell, cells, keyGeometries
    }
    init?(coder: NSCoder) {
        cell = coder.decodeObject(forKey: CodingKeys.cell.rawValue) as? Cell ?? Cell()
        keyGeometries = coder.decodeObject(
            forKey: CodingKeys.keyGeometries.rawValue) as? [Geometry] ?? []
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(cell, forKey: CodingKeys.cell.rawValue)
        coder.encode(keyGeometries, forKey: CodingKeys.keyGeometries.rawValue)
    }
    
    var isEmptyKeyGeometries: Bool {
        for keyGeometry in keyGeometries {
            if !keyGeometry.isEmpty {
                return false
            }
        }
        return true
    }
    
    func drawPreviousNext(lineWidth: CGFloat,
                          isShownPrevious: Bool, isShownNext: Bool, index: Int, in ctx: CGContext) {
        if isShownPrevious && index - 1 >= 0 {
            ctx.setFillColor(Color.previous.cgColor)
            keyGeometries[index - 1].draw(withLineWidth: lineWidth, in: ctx)
        }
        if isShownNext && index + 1 <= keyGeometries.count - 1 {
            ctx.setFillColor(Color.next.cgColor)
            keyGeometries[index + 1].draw(withLineWidth: lineWidth, in: ctx)
        }
    }
}
extension CellItem: Copying {
    func copied(from copier: Copier) -> CellItem {
        return CellItem(cell: copier.copied(cell), keyGeometries: keyGeometries)
    }
}
extension CellItem: Referenceable {
    static let name = Localization(english: "Cell Item", japanese: "セルアイテム")
}

final class MaterialItem: NSObject, TrackItem, NSCoding {
    var cells: [Cell]
    var material: Material {
        didSet {
            self.cells.forEach { $0.material = material }
        }
    }
    fileprivate(set) var keyMaterials: [Material]
    func replace(_ material: Material, at i: Int) {
        self.keyMaterials[i] = material
        self.material = material
    }
    
    func step(_ f0: Int) {
        self.material = keyMaterials[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        self.material = Material.linear(keyMaterials[f0], keyMaterials[f1], t: t)
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        self.material = Material.firstMonospline(keyMaterials[f1], keyMaterials[f2],
                                                 keyMaterials[f3], with: msx)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        self.material = Material.monospline(keyMaterials[f0], keyMaterials[f1],
                                            keyMaterials[f2], keyMaterials[f3], with: msx)
    }
    func endMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with msx: MonosplineX) {
        self.material = Material.endMonospline(keyMaterials[f0], keyMaterials[f1],
                                               keyMaterials[f2], with: msx)
    }
    
    init(material: Material = Material(), cells: [Cell] = [], keyMaterials: [Material] = []) {
        self.material = material
        self.cells = cells
        self.keyMaterials = keyMaterials
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case material, cells, keyMaterials
    }
    init?(coder: NSCoder) {
        material = coder.decodeObject(
            forKey: CodingKeys.material.rawValue) as? Material ?? Material()
        cells = coder.decodeObject(forKey: CodingKeys.cells.rawValue) as? [Cell] ?? []
        keyMaterials = coder.decodeObject(
            forKey: CodingKeys.keyMaterials.rawValue) as? [Material] ?? []
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(material, forKey: CodingKeys.material.rawValue)
        coder.encode(cells, forKey: CodingKeys.cells.rawValue)
        coder.encode(keyMaterials, forKey: CodingKeys.keyMaterials.rawValue)
    }
}
extension MaterialItem: Copying {
    func copied(from copier: Copier) -> MaterialItem {
        return MaterialItem(material: material,
                            cells: cells.map { copier.copied($0) }, keyMaterials: keyMaterials)
    }
}
extension MaterialItem: Referenceable {
    static let name = Localization(english: "Material Item", japanese: "マテリアルアイテム")
}

final class TransformItem: TrackItem, Codable {
    var transform: Transform
    fileprivate(set) var keyTransforms: [Transform]
    func replace(_ transform: Transform, at i: Int) {
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
        transform = Transform.firstMonospline(keyTransforms[f1], keyTransforms[f2],
                                              keyTransforms[f3], with: msx)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        transform = Transform.monospline(keyTransforms[f0], keyTransforms[f1],
                                         keyTransforms[f2], keyTransforms[f3], with: msx)
    }
    func endMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with msx: MonosplineX) {
        transform = Transform.endMonospline(keyTransforms[f0], keyTransforms[f1],
                                            keyTransforms[f2], with: msx)
    }
    
    init(transform: Transform = Transform(), keyTransforms: [Transform] = [Transform()]) {
        self.transform = transform
        self.keyTransforms = keyTransforms
    }
    
    static func empty(with animation: Animation) -> TransformItem {
        let transformItem =  TransformItem()
        let transforms = animation.keyframes.map { _ in Transform() }
        transformItem.keyTransforms = transforms
        transformItem.transform = transforms[animation.editKeyframeIndex]
        return transformItem
    }
    var isEmpty: Bool {
        for t in keyTransforms {
            if !t.isIdentity {
                return false
            }
        }
        return true
    }
}
extension TransformItem: Copying {
    func copied(from copier: Copier) -> TransformItem {
        return TransformItem(transform: transform, keyTransforms: keyTransforms)
    }
}
extension TransformItem: Referenceable {
    static let name = Localization(english: "Transform Item", japanese: "トランスフォームアイテム")
}

final class WiggleItem: TrackItem, Codable {
    var wiggle: Wiggle
    fileprivate(set) var keyWiggles: [Wiggle]
    func replace(_ wiggle: Wiggle, at i: Int) {
        keyWiggles[i] = wiggle
        self.wiggle = wiggle
    }
    
    func step(_ f0: Int) {
        wiggle = keyWiggles[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        wiggle = Wiggle.linear(keyWiggles[f0], keyWiggles[f1], t: t)
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        wiggle = Wiggle.firstMonospline(keyWiggles[f1], keyWiggles[f2],
                                        keyWiggles[f3], with: msx)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        wiggle = Wiggle.monospline(keyWiggles[f0], keyWiggles[f1],
                                   keyWiggles[f2], keyWiggles[f3], with: msx)
    }
    func endMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with msx: MonosplineX) {
        wiggle = Wiggle.endMonospline(keyWiggles[f0], keyWiggles[f1],
                                      keyWiggles[f2], with: msx)
    }
    
    init(wiggle: Wiggle = Wiggle(), keyWiggles: [Wiggle] = [Wiggle()]) {
        self.wiggle = wiggle
        self.keyWiggles = keyWiggles
    }
    
    static func empty(with animation: Animation) -> WiggleItem {
        let wiggleItem =  WiggleItem()
        let wiggles = animation.keyframes.map { _ in Wiggle() }
        wiggleItem.keyWiggles = wiggles
        wiggleItem.wiggle = wiggles[animation.editKeyframeIndex]
        return wiggleItem
    }
    var isEmpty: Bool {
        for t in keyWiggles {
            if !t.isEmpty {
                return false
            }
        }
        return true
    }
}
extension WiggleItem: Copying {
    func copied(from copier: Copier) -> WiggleItem {
        return WiggleItem(wiggle: wiggle, keyWiggles: keyWiggles)
    }
}
extension WiggleItem: Referenceable {
    static let name = Localization(english: "Wiggle Item", japanese: "振動アイテム")
}

final class SpeechItem: TrackItem, Codable {
    var speech: Speech
    fileprivate(set) var keySpeechs: [Speech]
    func replaceSpeech(_ speech: Speech, at i: Int) {
        keySpeechs[i] = speech
        self.speech = speech
    }
    
    func step(_ f0: Int) {
        self.speech = keySpeechs[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        self.speech = keySpeechs[f0]
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        self.speech = keySpeechs[f1]
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        self.speech = keySpeechs[f1]
    }
    func endMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with msx: MonosplineX) {
        self.speech = keySpeechs[f1]
    }
    
    func update(with f0: Int) {
        self.speech = keySpeechs[f0]
    }
    
    init(speech: Speech = Speech(), keySpeechs: [Speech] = [Speech()]) {
        self.speech = speech
        self.keySpeechs = keySpeechs
    }
    
    var isEmpty: Bool {
        for t in keySpeechs {
            if !t.isEmpty {
                return false
            }
        }
        return true
    }
}
extension SpeechItem: Copying {
    func copied(from copier: Copier) -> SpeechItem {
        return SpeechItem(speech: speech, keySpeechs: keySpeechs)
    }
}
extension SpeechItem: Referenceable {
    static let name = Localization(english: "Speech Item", japanese: "スピーチアイテム")
}

final class TempoItem: TrackItem, Codable {
    var tempo: BPM
    fileprivate(set) var keyTempos: [BPM]
    func replace(tempo: BPM, at i: Int) {
        keyTempos[i] = tempo
        self.tempo = tempo
    }

    func step(_ f0: Int) {
        tempo = keyTempos[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        tempo = BPM.linear(keyTempos[f0], keyTempos[f1], t: t)
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        tempo = BPM.firstMonospline(keyTempos[f1], keyTempos[f2], keyTempos[f3], with: msx)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        tempo = BPM.monospline(keyTempos[f0], keyTempos[f1], keyTempos[f2], keyTempos[f3], with: msx)
    }
    func endMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with msx: MonosplineX) {
        tempo = BPM.endMonospline(keyTempos[f0], keyTempos[f1], keyTempos[f2], with: msx)
    }

    static let defaultTempo = 60
    init(tempo: BPM = defaultTempo, keyTempos: [BPM] = [defaultTempo]) {
        self.tempo = tempo
        self.keyTempos = keyTempos
    }

    static func empty(with animation: Animation) -> TempoItem {
        let tempoItem =  TempoItem()
        let tempos = animation.keyframes.map { _ in defaultTempo }
        tempoItem.keyTempos = tempos
        tempoItem.tempo = tempos[animation.editKeyframeIndex]
        return tempoItem
    }
}
extension TempoItem: Copying {
    func copied(from copier: Copier) -> TempoItem {
        return TempoItem(tempo: tempo, keyTempos: keyTempos)
    }
}
extension TempoItem: Referenceable {
    static let name = Localization(english: "Tempo Item", japanese: "テンポアイテム")
}

final class SoundItem: TrackItem, Codable {
    var sound: Sound
    fileprivate(set) var keySounds: [Sound]
    func replace(_ sound: Sound, at i: Int) {
        keySounds[i] = sound
        self.sound = sound
    }
    
    func step(_ f0: Int) {
        sound = keySounds[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        sound = keySounds[f0]
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        sound = keySounds[f1]
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        sound = keySounds[f1]
    }
    func endMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with msx: MonosplineX) {
        sound = keySounds[f1]
    }
    
    static let defaultSound = Sound()
    init(sound: Sound = defaultSound, keySounds: [Sound] = [defaultSound]) {
        self.sound = sound
        self.keySounds = keySounds
    }
}
extension SoundItem: Copying {
    func copied(from copier: Copier) -> SoundItem {
        return SoundItem(sound: sound, keySounds: keySounds)
    }
}
extension SoundItem: Referenceable {
    static let name = Localization(english: "Sound Item", japanese: "サウンドアイテム")
}
