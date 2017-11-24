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

final class Animation: NSObject, NSCoding, Copying {
    static let name = Localization(english: "Animation", japanese: "アニメーション")
    
    private(set) var keyframes: [Keyframe] {
        didSet {
            self.loopedKeyframeIndexes = Animation.loopedKeyframeIndexesWith(keyframes, timeLength: timeLength)
        }
    }
    var editKeyframeIndex: Int
    var selectionKeyframeIndexes: [[Int]]
    
    var time: Beat {
        didSet {
            update(withTime: time)
        }
    }
    var timeLength: Beat {
        didSet {
            self.loopedKeyframeIndexes = Animation.loopedKeyframeIndexesWith(keyframes, timeLength: timeLength)
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
    var drawingItem: DrawingItem, cellItems: [CellItem], materialItems: [MaterialItem], transformItem: TransformItem?, speechItem: SpeechItem?
    var isInterporation: Bool
    
    private(set) var loopedKeyframeIndexes: [(index: Int, time: Beat, loopCount: Int, loopingCount: Int)]
    private static func loopedKeyframeIndexesWith(
        _ keyframes: [Keyframe], timeLength: Beat
    ) -> [(index: Int, time: Beat, loopCount: Int, loopingCount: Int)] {
        var keyframeIndexes = [(index: Int, time: Beat, loopCount: Int, loopingCount: Int)](), previousIndexes = [Int]()
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
    func update(withTime time: Beat) {
        let timeResult = loopedKeyframeIndex(withTime: time)
        let i1 = timeResult.loopedIndex, interTime = max(0, timeResult.interTime)
        let kis1 = loopedKeyframeIndexes[i1]
        self.editKeyframeIndex = kis1.index
        let k1 = keyframes[kis1.index]
        if interTime == 0 || timeResult.sectionTime == 0 || i1 + 1 >= loopedKeyframeIndexes.count || k1.interpolation == .none {
            self.isInterporation = false
            step(kis1.index)
            return
        }
        self.isInterporation = true
        let kis2 = loopedKeyframeIndexes[i1 + 1]
        if k1.interpolation == .linear || keyframes.count <= 2 {
            linear(kis1.index, kis2.index, t: k1.easing.convertT(Double(interTime / timeResult.sectionTime).cf))
        } else {
            let it = Double(interTime / timeResult.sectionTime).cf
            let t = k1.easing.isDefault ?
                Double(time).cf : k1.easing.convertT(it) * Double(timeResult.sectionTime).cf + Double(kis1.time).cf
            let isUseFirstIndex = i1 - 1 >= 0 && k1.interpolation != .bound, isUseEndIndex = i1 + 2 < loopedKeyframeIndexes.count && keyframes[kis2.index].interpolation != .bound
            if isUseFirstIndex {
                if isUseEndIndex {
                    let kis0 = loopedKeyframeIndexes[i1 - 1], kis3 = loopedKeyframeIndexes[i1 + 2]
                    let msx = MonosplineX(x0: Double(kis0.time).cf, x1: Double(kis1.time).cf, x2: Double(kis2.time).cf, x3: Double(kis3.time).cf, x: t, t: k1.easing.convertT(it))
                    monospline(kis0.index, kis1.index, kis2.index, kis3.index, with: msx)
                } else {
                    let kis0 = loopedKeyframeIndexes[i1 - 1]
                    let mt = k1.easing.convertT(it)
                    let msx = MonosplineX(x0: Double(kis0.time).cf, x1: Double(kis1.time).cf, x2: Double(kis2.time).cf, x: t, t: mt)
                    endMonospline(kis0.index, kis1.index, kis2.index, with: msx)
                }
            } else if isUseEndIndex {
                let kis3 = loopedKeyframeIndexes[i1 + 2]
                let mt = k1.easing.convertT(it)
                let msx = MonosplineX(x1: Double(kis1.time).cf, x2: Double(kis2.time).cf, x3: Double(kis3.time).cf, x: t, t: mt)
                firstMonospline(kis1.index, kis2.index, kis3.index, with: msx)
            } else {
                linear(kis1.index, kis2.index, t: k1.easing.convertT(it))
            }
        }
    }
    
    func step(_ f0: Int) {
        drawingItem.update(with: f0)
        cellItems.forEach { $0.step(f0) }
        materialItems.forEach { $0.step(f0) }
        transformItem?.step(f0)
        speechItem?.update(with: f0)
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        drawingItem.update(with: f0)
        cellItems.forEach { $0.linear(f0, f1, t: t) }
        materialItems.forEach { $0.linear(f0, f1, t: t) }
        transformItem?.linear(f0, f1, t: t)
        speechItem?.update(with: f0)
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        drawingItem.update(with: f1)
        cellItems.forEach { $0.firstMonospline(f1, f2, f3, with: msx) }
        materialItems.forEach { $0.firstMonospline(f1, f2, f3, with: msx) }
        transformItem?.firstMonospline(f1, f2, f3, with: msx)
        speechItem?.update(with: f1)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        drawingItem.update(with: f1)
        cellItems.forEach { $0.monospline(f0, f1, f2, f3, with: msx) }
        materialItems.forEach { $0.monospline(f0, f1, f2, f3, with: msx) }
        transformItem?.monospline(f0, f1, f2, f3, with: msx)
        speechItem?.update(with: f1)
    }
    func endMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with msx: MonosplineX) {
        drawingItem.update(with: f1)
        cellItems.forEach { $0.endMonospline(f0, f1, f2, with: msx) }
        materialItems.forEach { $0.endMonospline(f0, f1, f2, with: msx) }
        transformItem?.endMonospline(f0, f1, f2, with: msx)
        speechItem?.update(with: f1)
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
    func insertKeyframe(
        _ keyframe: Keyframe, drawing: Drawing, geometries: [Geometry], materials: [Material], transform: Transform?, speech: Speech?, at index: Int
    ) {
        guard geometries.count <= cellItems.count && materials.count <= materialItems.count else {
            fatalError()
        }
        keyframes.insert(keyframe, at: index)
        drawingItem.keyDrawings.insert(drawing, at: index)
        cellItems.enumerated().forEach { $0.element.keyGeometries.insert(geometries[$0.offset], at: index) }
        materialItems.enumerated().forEach { $0.element.keyMaterials.insert(materials[$0.offset], at: index) }
        if let transform = transform {
            transformItem?.keyTransforms.insert(transform, at: index)
        }
        if let speech = speech {
            speechItem?.keySpeechs.insert(speech, at: index)
        }
    }
    func removeKeyframe(at index: Int) {
        keyframes.remove(at: index)
        drawingItem.keyDrawings.remove(at: index)
        cellItems.forEach { $0.keyGeometries.remove(at: index) }
        materialItems.forEach { $0.keyMaterials.remove(at: index) }
        transformItem?.keyTransforms.remove(at: index)
        speechItem?.keySpeechs.remove(at: index)
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
    func setKeyMaterials(_ keyMaterials: [Material], in materailItem: MaterialItem) {
        guard keyMaterials.count == keyframes.count else {
            fatalError()
        }
        materailItem.keyMaterials = keyMaterials
    }
    var currentItemValues: (drawing: Drawing, geometries: [Geometry], materials: [Material], transform: Transform?, speech: Speech?) {
        let geometries = cellItems.map { $0.cell.geometry }, materials = materialItems.map { $0.material }
        return (drawingItem.drawing, geometries, materials, transformItem?.transform, speechItem?.speech)
    }
    func keyframeItemValues(at index: Int) -> (drawing: Drawing, geometries: [Geometry], materials: [Material], transform: Transform?, speech: Speech?) {
        let geometries = cellItems.map { $0.keyGeometries[index] }, materials = materialItems.map { $0.keyMaterials[index] }
        return (drawingItem.keyDrawings[index], geometries, materials, transformItem?.keyTransforms[index], speechItem?.keySpeechs[index])
    }
    
    init(
        keyframes: [Keyframe] = [Keyframe()], editKeyframeIndex: Int = 0, selectionKeyframeIndexes: [[Int]] = [], time: Beat = 0, timeLength: Beat = 0,
         isHidden: Bool = false, selectionCellItems: [CellItem] = [],
         drawingItem: DrawingItem = DrawingItem(), cellItems: [CellItem] = [], materialItems: [MaterialItem] = [],
         transformItem: TransformItem? = nil, speechItem: SpeechItem? = nil, isInterporation: Bool = false
    ) {
        self.keyframes = keyframes
        self.editKeyframeIndex = editKeyframeIndex
        self.selectionKeyframeIndexes = selectionKeyframeIndexes
        self.time = time
        self.timeLength = timeLength
        self.isHidden = isHidden
        self.selectionCellItems = selectionCellItems
        self.drawingItem = drawingItem
        self.cellItems = cellItems
        self.materialItems = materialItems
        self.transformItem = transformItem
        self.speechItem = speechItem
        self.isInterporation = isInterporation
        self.loopedKeyframeIndexes = Animation.loopedKeyframeIndexesWith(keyframes, timeLength: timeLength)
        super.init()
    }
    private init(
        keyframes: [Keyframe], editKeyframeIndex: Int, selectionKeyframeIndexes: [[Int]], time: Beat, timeLength: Beat,
        isHidden: Bool, selectionCellItems: [CellItem],
        drawingItem: DrawingItem, cellItems: [CellItem], materialItems: [MaterialItem],
        transformItem: TransformItem?, speechItem: SpeechItem?, isInterporation: Bool,
        keyframeIndexes: [(index: Int, time: Beat, loopCount: Int, loopingCount: Int)]
    ) {
        self.keyframes = keyframes
        self.editKeyframeIndex = editKeyframeIndex
        self.selectionKeyframeIndexes = selectionKeyframeIndexes
        self.time = time
        self.timeLength = timeLength
        self.isHidden = isHidden
        self.selectionCellItems = selectionCellItems
        self.drawingItem = drawingItem
        self.cellItems = cellItems
        self.materialItems = materialItems
        self.transformItem = transformItem
        self.speechItem = speechItem
        self.isInterporation = isInterporation
        self.loopedKeyframeIndexes = keyframeIndexes
        super.init()
    }
    
    static let keyframesKey = "0", editKeyframeIndexKey = "1", selectionKeyframeIndexesKey = "2", timeLengthKey = "3", isHiddenKey = "4"
    static let editCellItemKey = "5", selectionCellItemsKey = "6", drawingItemKey = "7", cellItemsKey = "8", materialItemsKey = "12", transformItemKey = "9", speechItemKey = "10", isInterporationKey = "11", timeKey = "13"
    init?(coder: NSCoder) {
        keyframes = coder.decodeStruct(forKey: Animation.keyframesKey) ?? []
        editKeyframeIndex = coder.decodeInteger(forKey: Animation.editKeyframeIndexKey)
        selectionKeyframeIndexes = coder.decodeObject(forKey: Animation.selectionKeyframeIndexesKey) as? [[Int]] ?? []
        time = coder.decodeStruct(forKey: Animation.timeKey) ?? 0
        timeLength = coder.decodeStruct(forKey: Animation.timeLengthKey) ?? 0
        isHidden = coder.decodeBool(forKey: Animation.isHiddenKey)
        selectionCellItems = coder.decodeObject(forKey: Animation.selectionCellItemsKey) as? [CellItem] ?? []
        drawingItem = coder.decodeObject(forKey: Animation.drawingItemKey) as? DrawingItem ?? DrawingItem()
        cellItems = coder.decodeObject(forKey: Animation.cellItemsKey) as? [CellItem] ?? []
        materialItems = coder.decodeObject(forKey: Animation.materialItemsKey) as? [MaterialItem] ?? []
        transformItem = coder.decodeObject(forKey: Animation.transformItemKey) as? TransformItem
        speechItem = coder.decodeObject(forKey: Animation.speechItemKey) as? SpeechItem
        isInterporation = coder.decodeBool(forKey: Animation.isInterporationKey)
        loopedKeyframeIndexes = Animation.loopedKeyframeIndexesWith(keyframes, timeLength: timeLength)
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeStruct(keyframes, forKey: Animation.keyframesKey)
        coder.encode(editKeyframeIndex, forKey: Animation.editKeyframeIndexKey)
        coder.encode(selectionKeyframeIndexes, forKey: Animation.selectionKeyframeIndexesKey)
        coder.encodeStruct(time, forKey: Animation.timeKey)
        coder.encodeStruct(timeLength, forKey: Animation.timeLengthKey)
        coder.encode(isHidden, forKey: Animation.isHiddenKey)
        coder.encode(selectionCellItems, forKey: Animation.selectionCellItemsKey)
        coder.encode(drawingItem, forKey: Animation.drawingItemKey)
        coder.encode(cellItems, forKey: Animation.cellItemsKey)
        coder.encode(materialItems, forKey: Animation.materialItemsKey)
        coder.encode(transformItem, forKey: Animation.transformItemKey)
        coder.encode(speechItem, forKey: Animation.speechItemKey)
        coder.encode(isInterporation, forKey: Animation.isInterporationKey)
    }
    
    var deepCopy: Animation {
        return Animation(
            keyframes: keyframes, editKeyframeIndex: editKeyframeIndex, selectionKeyframeIndexes: selectionKeyframeIndexes,
            time: time, timeLength: timeLength, isHidden: isHidden, selectionCellItems: selectionCellItems.map {$0.deepCopy },
            drawingItem: drawingItem.deepCopy, cellItems: cellItems.map { $0.deepCopy }, materialItems: materialItems.map { $0.deepCopy },
            transformItem: transformItem?.deepCopy, speechItem: speechItem?.deepCopy,
            isInterporation: isInterporation, keyframeIndexes: loopedKeyframeIndexes
        )
    }
    
    var editKeyframe: Keyframe {
        return keyframes[min(editKeyframeIndex, keyframes.count - 1)]
    }
    func loopedKeyframeIndex(withTime t: Beat) -> (loopedIndex: Int, index: Int, interTime: Beat, sectionTime: Beat) {
        var oldT = timeLength
        for i in (0 ..< loopedKeyframeIndexes.count).reversed() {
            let ki = loopedKeyframeIndexes[i]
            let kt = ki.time
            if t >= kt {
                return (i, ki.index, t - kt, oldT - kt)
            }
            oldT = kt
        }
        return (0, 0, t - loopedKeyframeIndexes.first!.time, oldT - loopedKeyframeIndexes.first!.time)
    }
    var minTimeLength: Beat {
        return (keyframes.last?.time ?? 0) + 1
    }
    var lastKeyframeTime: Beat {
        return keyframes.isEmpty ? 0 : keyframes[keyframes.count - 1].time
    }
    var lastLoopedKeyframeTime: Beat {
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
    func selectionCellsWithNoEmptyGeometry(at point: CGPoint) -> [CellItem] {
        for cellItem in selectionCellItems {
            if cellItem.cell.contains(point) {
                return selectionCellItems
            }
        }
        return []
    }
    
    var emptyKeyGeometries: [Geometry] {
        return keyframes.map { _ in Geometry() }
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
        let index = loopedKeyframeIndex(withTime: time).index
        for cellItem in cellItems {
            if !cellItem.keyGeometries[index].isEmpty {
                return false
            }
        }
        return true
    }
    func emptyKeyMaterials(with material: Material) -> [Material] {
        return keyframes.map { _ in material }
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
        if let transformItem = transformItem, let firstTransform = transformItem.keyTransforms.first {
            var phase = 0.0.cf, oldHz = firstTransform.wiggle.frequency, oldTime = Beat(0)
            for i in 1 ..< keyframes.count {
                let newTime = keyframes[i].time
                if time >= newTime {
                    let newHz = transformItem.keyTransforms[i].wiggle.frequency
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
    
    func snapPoint(_ point: CGPoint, with n: Node.Nearest.BezierSortedResult, snapDistance: CGFloat, grid: CGFloat?) -> CGPoint {
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
    
    func snapPoint(_ sp: CGPoint, editLine: Line, editPointIndex: Int, snapDistance: CGFloat) -> CGPoint {
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
                            snapLines.append((line.controls[line.controls.count - 2].point, editLine.firstPoint))
                        }
                        if line.firstPoint == editLine.lastPoint {
                            lastSnapLines.append((line.controls[1].point, editLine.lastPoint))
                        } else if line.lastPoint == editLine.lastPoint {
                            lastSnapLines.append((line.controls[line.controls.count - 2].point, editLine.lastPoint))
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
        return cellItems.reduce(CGRect()) { $0.unionNoEmpty($1.cell.imageBounds) }.unionNoEmpty(drawingItem.imageBounds)
    }
    
    func drawPreviousNext(isShownPrevious: Bool, isShownNext: Bool, time: Beat, reciprocalScale: CGFloat, in ctx: CGContext) {
        let index = loopedKeyframeIndex(withTime: time).index
        drawingItem.drawPreviousNext(isShownPrevious: isShownPrevious, isShownNext: isShownNext, index: index, reciprocalScale: reciprocalScale, in: ctx)
        cellItems.forEach {
            $0.drawPreviousNext(
                lineWidth: drawingItem.lineWidth * reciprocalScale,
                isShownPrevious: isShownPrevious, isShownNext: isShownNext, index: index, in: ctx
            )
        }
    }
    func drawSelectionCells(opacity: CGFloat, color: Color, subColor: Color, reciprocalScale: CGFloat, in ctx: CGContext) {
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
        for cellItem in cellItems {
            cellItem.cell.geometry.drawLines(withColor: Color.border, reciprocalScale: reciprocalScale, in: ctx)
            cellItem.cell.geometry.drawPathLine(withReciprocalScale: reciprocalScale, in: ctx)
        }
    }
    func drawSkinCellItem(_ cellItem: CellItem, reciprocalScale: CGFloat, reciprocalAllScale: CGFloat, in ctx: CGContext) {
        cellItem.cell.geometry.drawSkin(
            lineColor: isInterporation ? .red : .indication,
            subColor: Color.subIndication.multiply(alpha: 0.2),
            skinLineWidth: isInterporation ? 3 : 1,
            reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalAllScale, in: ctx
        )
    }
}
struct Keyframe: ByteCoding, Referenceable, Equatable {
    static let name = Localization(english: "Keyframe", japanese: "キーフレーム")
    
    enum Interpolation: Int8 {
        case spline, bound, linear, none
    }
    enum Label: Int8 {
        case main, sub
    }
    let time: Beat, easing: Easing, interpolation: Interpolation, loop: Loop, label: Label
    
    init(time: Beat = 0, easing: Easing = Easing(), interpolation: Interpolation = .spline, loop: Loop = Loop(), label: Label = .main) {
        self.time = time
        self.easing = easing
        self.interpolation = interpolation
        self.loop = loop
        self.label = label
    }
    
    func with(time: Beat) -> Keyframe {
        return Keyframe(time: time, easing: easing, interpolation: interpolation, loop: loop, label: label)
    }
    func with(_ easing: Easing) -> Keyframe {
        return Keyframe(time: time, easing: easing, interpolation: interpolation, loop: loop, label: label)
    }
    func with(_ interpolation: Interpolation) -> Keyframe {
        return Keyframe(time: time, easing: easing, interpolation: interpolation, loop: loop, label: label)
    }
    func with(_ loop: Loop) -> Keyframe {
        return Keyframe(time: time, easing: easing, interpolation: interpolation, loop: loop, label: label)
    }
    func with(_ label: Label) -> Keyframe {
        return Keyframe(time: time, easing: easing, interpolation: interpolation, loop: loop, label: label)
    }
    static func index(time t: Beat, with keyframes: [Keyframe]) -> (index: Int, interTime: Beat, sectionTime: Beat) {
        var oldT = Beat(0)
        for i in (0 ..< keyframes.count).reversed() {
            let keyframe = keyframes[i]
            if t >= keyframe.time {
                return (i, t - keyframe.time, oldT - keyframe.time)
            }
            oldT = keyframe.time
        }
        return (0, t - keyframes.first!.time, oldT - keyframes.first!.time)
    }
    static func == (lhs: Keyframe, rhs: Keyframe) -> Bool {
        return lhs.time == rhs.time
            && lhs.easing == rhs.easing && lhs.interpolation == rhs.interpolation
            && lhs.loop == rhs.loop && lhs.label == rhs.label
    }
    func equalOption(other: Keyframe) -> Bool {
        return easing == other.easing && interpolation == other.interpolation
            && loop == other.loop && label == other.label
    }
}
struct Loop: Equatable, ByteCoding {
    static let name = Localization(english: "Loop", japanese: "ループ")
    
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
    static let name = Localization(english: "Drawing Item", japanese: "ドローイングアイテム")
    
    var drawing: Drawing, color: Color, lineWidth: CGFloat
    fileprivate(set) var keyDrawings: [Drawing]
    
    func update(with f0: Int) {
        self.drawing = keyDrawings[f0]
    }
    
    static let defaultLineWidth = 1.0.cf
    
    init(drawing: Drawing = Drawing(), keyDrawings: [Drawing] = [], color: Color = .strokeLine, lineWidth: CGFloat = defaultLineWidth) {
        self.drawing = drawing
        self.keyDrawings = keyDrawings.isEmpty ? [drawing] : keyDrawings
        self.color = color
        self.lineWidth = lineWidth
    }
    
    static let drawingKey = "0", keyDrawingsKey = "1", lineWidthKey = "2"
    init(coder: NSCoder) {
        drawing = coder.decodeObject(forKey: DrawingItem.drawingKey) as? Drawing ?? Drawing()
        keyDrawings = coder.decodeObject(forKey: DrawingItem.keyDrawingsKey) as? [Drawing] ?? []
        lineWidth = coder.decodeDouble(forKey: DrawingItem.lineWidthKey).cf
        color = .strokeLine
    }
    func encode(with coder: NSCoder) {
        coder.encode(drawing, forKey: DrawingItem.drawingKey)
        coder.encode(keyDrawings, forKey: DrawingItem.keyDrawingsKey)
        coder.encode(lineWidth.d, forKey: DrawingItem.lineWidthKey)
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
        return drawing.imageBounds(withLineWidth: lineWidth)
    }
    
    func drawEdit(withReciprocalScale reciprocalScale: CGFloat, in ctx: CGContext) {
        drawing.drawEdit(lineWidth: lineWidth * reciprocalScale, lineColor: color, in: ctx)
    }
    func draw(withReciprocalScale reciprocalScale: CGFloat, in ctx: CGContext) {
        drawing.draw(lineWidth: lineWidth * reciprocalScale, lineColor: color, in: ctx)
    }
    func drawPreviousNext(isShownPrevious: Bool, isShownNext: Bool, index: Int, reciprocalScale: CGFloat, in ctx: CGContext) {
        let lineWidth = self.lineWidth * reciprocalScale
        if isShownPrevious && index - 1 >= 0 {
            keyDrawings[index - 1].draw(lineWidth: lineWidth, lineColor: Color.previous, in: ctx)
        }
        if isShownNext && index + 1 <= keyDrawings.count - 1 {
            keyDrawings[index + 1].draw(lineWidth: lineWidth, lineColor: Color.next, in: ctx)
        }
    }
}

final class CellItem: NSObject, NSCoding, Copying {
    static let name = Localization(english: "Cell Item", japanese: "セルアイテム")
    
    let cell: Cell
    fileprivate(set) var keyGeometries: [Geometry]
    func replaceGeometry(_ geometry: Geometry, at i: Int) {
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
        cell.geometry = Geometry.firstMonospline(keyGeometries[f1], keyGeometries[f2], keyGeometries[f3], with: msx)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        cell.geometry = Geometry.monospline(keyGeometries[f0], keyGeometries[f1], keyGeometries[f2], keyGeometries[f3], with: msx)
    }
    func endMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with msx: MonosplineX) {
        cell.geometry = Geometry.endMonospline(keyGeometries[f0], keyGeometries[f1], keyGeometries[f2], with: msx)
    }
    
    init(cell: Cell, keyGeometries: [Geometry] = []) {
        self.cell = cell
        self.keyGeometries = keyGeometries
        super.init()
    }
    
    static let cellKey = "0", keyGeometriesKey = "1"
    init?(coder: NSCoder) {
        cell = coder.decodeObject(forKey: CellItem.cellKey) as? Cell ?? Cell()
        keyGeometries = coder.decodeObject(forKey: CellItem.keyGeometriesKey) as? [Geometry] ?? []
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(cell, forKey: CellItem.cellKey)
        coder.encode(keyGeometries, forKey: CellItem.keyGeometriesKey)
    }
    
    var deepCopy: CellItem {
        return CellItem(cell: cell.noResetDeepCopy, keyGeometries: keyGeometries)
    }
    
    var isEmptyKeyGeometries: Bool {
        for keyGeometry in keyGeometries {
            if !keyGeometry.isEmpty {
                return false
            }
        }
        return true
    }
    
    func drawPreviousNext(lineWidth: CGFloat, isShownPrevious: Bool, isShownNext: Bool, index: Int, in ctx: CGContext) {
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

final class MaterialItem: NSObject, NSCoding, Copying {
    static let name = Localization(english: "Material Item", japanese: "マテリアルアイテム")
    
    var cells: [Cell]
    var material: Material {
        didSet {
            self.cells.forEach { $0.material = material }
        }
    }
    fileprivate(set) var keyMaterials: [Material]
    func replaceMaterial(_ material: Material, at i: Int) {
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
        self.material = Material.firstMonospline(keyMaterials[f1], keyMaterials[f2], keyMaterials[f3], with: msx)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX) {
        self.material = Material.monospline(keyMaterials[f0], keyMaterials[f1], keyMaterials[f2], keyMaterials[f3], with: msx)
    }
    func endMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with msx: MonosplineX) {
        self.material = Material.endMonospline(keyMaterials[f0], keyMaterials[f1], keyMaterials[f2], with: msx)
    }
    
    init(material: Material = Material(), cells: [Cell] = [], keyMaterials: [Material] = []) {
        self.material = material
        self.cells = cells
        self.keyMaterials = keyMaterials
        super.init()
    }
    
    static let materialKey = "0", cellsKey = "1", keyMaterialsKey = "2"
    init?(coder: NSCoder) {
        self.material = coder.decodeObject(forKey: MaterialItem.materialKey) as? Material ?? Material()
        self.cells = coder.decodeObject(forKey: MaterialItem.cellsKey) as? [Cell] ?? []
        self.keyMaterials = coder.decodeObject(forKey: MaterialItem.keyMaterialsKey) as? [Material] ?? []
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(material, forKey: MaterialItem.materialKey)
        coder.encode(cells, forKey: MaterialItem.cellsKey)
        coder.encode(keyMaterials, forKey: MaterialItem.keyMaterialsKey)
    }
    
    var deepCopy: MaterialItem {
        return MaterialItem(material: material, cells: cells.map { $0.noResetDeepCopy }, keyMaterials: keyMaterials)
    }
}

final class TransformItem: NSObject, NSCoding, Copying {
    static let name = Localization(english: "Transform Item", japanese: "トランスフォームアイテム")
    
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
    
    static let transformKey = "0", keyTransformsKey = "1"
    init(coder: NSCoder) {
        transform = coder.decodeStruct(forKey: TransformItem.transformKey) ?? Transform()
        keyTransforms = coder.decodeStruct(forKey: TransformItem.keyTransformsKey) ?? []
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeStruct(transform, forKey: TransformItem.transformKey)
        coder.encodeStruct(keyTransforms, forKey: TransformItem.keyTransformsKey)
    }
    
    static func empty(with animation: Animation) ->  TransformItem {
        let transformItem =  TransformItem()
        let transforms = animation.keyframes.map { _ in Transform() }
        transformItem.keyTransforms = transforms
        transformItem.transform = transforms[animation.editKeyframeIndex]
        return transformItem
    }
    var deepCopy: TransformItem {
        return TransformItem(transform: transform, keyTransforms: keyTransforms)
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

final class SpeechItem: NSObject, NSCoding, Copying {
    static let name = Localization(english: "Speech Item", japanese: "スピーチアイテム")
    
    var speech: Speech
    fileprivate(set) var keySpeechs: [Speech]
    func replaceSpeech(_ speech: Speech, at i: Int) {
        keySpeechs[i] = speech
        self.speech = speech
    }
    
    func update(with f0: Int) {
        self.speech = keySpeechs[f0]
    }
    
    init(speech: Speech = Speech(), keySpeechs: [Speech] = [Speech()]) {
        self.speech = speech
        self.keySpeechs = keySpeechs
        super.init()
    }
    
    static let speechKey = "0", keySpeechsKey = "1"
    init?(coder: NSCoder) {
        speech = coder.decodeObject(forKey: SpeechItem.speechKey) as? Speech ?? Speech()
        keySpeechs = coder.decodeObject(forKey: SpeechItem.keySpeechsKey) as? [Speech] ?? []
    }
    func encode(with coder: NSCoder) {
        coder.encode(speech, forKey: SpeechItem.speechKey)
        coder.encode(keySpeechs, forKey: SpeechItem.keySpeechsKey)
    }
    
    var deepCopy: SpeechItem {
        return SpeechItem(speech: speech, keySpeechs: keySpeechs)
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

final class SoundItem: NSObject, NSCoding, Copying {
    static let name = Localization(english: "Sound Item", japanese: "サウンドアイテム")
    
    var url: URL? {
        didSet {
            if let url = url {
                self.bookmark = try? url.bookmarkData()
            }
        }
    }
    private var bookmark: Data?
    var name = ""
    var isHidden = false
    
    init(url: URL? = nil, name: String = "", isHidden: Bool = false) {
        self.url = url
        if let url = url {
            self.bookmark = try? url.bookmarkData()
        }
        self.name = name.isEmpty ? (url?.lastPathComponent ?? "") : name
        self.isHidden = isHidden
        super.init()
    }
    
    static let bookmarkKey = "0", nameKey = "1", isHiddenKey = "2"
    init?(coder: NSCoder) {
        bookmark = coder.decodeObject(forKey:SoundItem.bookmarkKey) as? Data
        url = URL(bookmark: bookmark)
        name = coder.decodeObject(forKey: SoundItem.nameKey) as? String ?? ""
        isHidden = coder.decodeBool(forKey: SoundItem.isHiddenKey)
    }
    func encode(with coder: NSCoder) {
        coder.encode(bookmark, forKey: SoundItem.bookmarkKey)
        coder.encode(name, forKey: SoundItem.nameKey)
        coder.encode(isHidden, forKey: SoundItem.isHiddenKey)
    }
    
    var deepCopy: SoundItem {
        return SoundItem(url: url, name: name, isHidden: isHidden)
    }
}

final class Drawing: NSObject, ClassCopyData, Drawable {
    static let name = Localization(english: "Drawing", japanese: "線画")
    
    var lines: [Line], roughLines: [Line], selectionLineIndexes: [Int]
    
    init(lines: [Line] = [], roughLines: [Line] = [], selectionLineIndexes: [Int] = []) {
        self.lines = lines
        self.roughLines = roughLines
        self.selectionLineIndexes = selectionLineIndexes
        super.init()
    }
    
    static let linesKey = "0", roughLinesKey = "1", selectionLineIndexesKey = "2"
    init?(coder: NSCoder) {
        lines = coder.decodeObject(forKey: Drawing.linesKey) as? [Line] ?? []
        roughLines = coder.decodeObject(forKey: Drawing.roughLinesKey) as? [Line] ?? []
        selectionLineIndexes = coder.decodeObject(forKey: Drawing.selectionLineIndexesKey) as? [Int] ?? []
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(lines, forKey: Drawing.linesKey)
        coder.encode(roughLines, forKey: Drawing.roughLinesKey)
        coder.encode(selectionLineIndexes, forKey: Drawing.selectionLineIndexesKey)
    }
    
    var deepCopy: Drawing {
        return Drawing(lines: lines, roughLines: roughLines, selectionLineIndexes: selectionLineIndexes)
    }
    
    func imageBounds(withLineWidth lineWidth: CGFloat) -> CGRect {
        return Line.imageBounds(with: lines, lineWidth: lineWidth).unionNoEmpty(Line.imageBounds(with: roughLines, lineWidth: lineWidth))
    }
    
    func nearestLine(at p: CGPoint) -> Line? {
        var minD² = CGFloat.infinity, minLine: Line?
        lines.forEach {
            let d² = $0.minDistance²(at: p)
            if d² < minD² {
                minD² = d²
                minLine = $0
            }
        }
        return minLine
    }
    func isNearestSelectionLineIndexes(at p: CGPoint) -> Bool {
        guard !selectionLineIndexes.isEmpty else {
            return false
        }
        
        var minD² = CGFloat.infinity, minIndex = 0
        lines.enumerated().forEach {
            let d² = $0.element.minDistance²(at: p)
            if d² < minD² {
                minD² = d²
                minIndex = $0.offset
            }
        }
        return selectionLineIndexes.contains(minIndex)
    }
    var editLines: [Line] {
        return selectionLineIndexes.isEmpty ? lines : selectionLineIndexes.map { lines[$0] }
    }
    var uneditLines: [Line] {
        guard  !selectionLineIndexes.isEmpty else {
            return []
        }
        return (0 ..< lines.count)
            .filter { !selectionLineIndexes.contains($0) }
            .map { lines[$0] }
    }
    
    func drawEdit(lineWidth: CGFloat, lineColor: Color, in ctx: CGContext) {
        drawRough(lineWidth: lineWidth, lineColor: Color.rough, in: ctx)
        draw(lineWidth: lineWidth, lineColor: lineColor, in: ctx)
        drawSelectionLines(lineWidth: lineWidth + 1.5, lineColor: Color.selection, in: ctx)
    }
    func drawRough(lineWidth: CGFloat, lineColor: Color, in ctx: CGContext) {
        ctx.setFillColor(lineColor.cgColor)
        for line in roughLines {
            line.draw(size: lineWidth, in: ctx)
        }
    }
    func draw(lineWidth: CGFloat, lineColor: Color, in ctx: CGContext) {
        ctx.setFillColor(lineColor.cgColor)
        for line in lines {
            line.draw(size: lineWidth, in: ctx)
        }
    }
    func drawSelectionLines(lineWidth: CGFloat, lineColor: Color, in ctx: CGContext) {
        ctx.setFillColor(lineColor.cgColor)
        selectionLineIndexes.forEach {
            lines[$0].draw(size: lineWidth, in: ctx)
        }
    }
    
    func draw(with bounds: CGRect, in ctx: CGContext) {
        let imageBounds = self.imageBounds(withLineWidth: 1)
        let c = CGAffineTransform.centering(from: imageBounds, to: bounds.inset(by: 5))
        ctx.concatenate(c.affine)
        draw(lineWidth: 0.5/c.scale, lineColor: Color.strokeLine, in: ctx)
        drawRough(lineWidth: 0.5/c.scale, lineColor: Color.rough, in: ctx)
    }
}

struct Transform: Equatable, ByteCoding, Interpolatable, CopyData {
    static let name = Localization(english: "Transform", japanese: "トランスフォーム")
    
    let translation: CGPoint, scale: CGPoint, rotation: CGFloat, wiggle: Wiggle
    let z: CGFloat, affineTransform: CGAffineTransform
    
    init(translation: CGPoint = CGPoint(), z: CGFloat = 0, rotation: CGFloat = 0, wiggle: Wiggle = Wiggle()) {
        let pow2 = pow(2, z)
        self.translation = translation
        self.scale = CGPoint(x: pow2, y: pow2)
        self.z = z
        self.rotation = rotation
        self.wiggle = wiggle
        self.affineTransform = Transform.affineTransform(translation: translation, scale: scale, rotation: rotation)
    }
    init(translation: CGPoint = CGPoint(), scale: CGPoint, rotation: CGFloat = 0, wiggle: Wiggle = Wiggle()) {
        self.translation = translation
        self.z = log2(scale.x)
        self.scale = scale
        self.rotation = rotation
        self.wiggle = wiggle
        self.affineTransform = Transform.affineTransform(translation: translation, scale: scale, rotation: rotation)
    }
    init(translation: CGPoint, z: CGFloat, scale: CGPoint, rotation: CGFloat, wiggle: Wiggle) {
        self.translation = translation
        self.z = z
        self.scale = scale
        self.rotation = rotation
        self.wiggle = wiggle
        self.affineTransform = Transform.affineTransform(translation: translation, scale: scale, rotation: rotation)
    }
    
    private static func affineTransform(translation: CGPoint, scale: CGPoint, rotation: CGFloat) -> CGAffineTransform {
        var affine = CGAffineTransform(translationX: translation.x, y: translation.y)
        if rotation != 0 {
            affine = affine.rotated(by: rotation)
        }
        if scale != CGPoint() {
            affine = affine.scaledBy(x: scale.x, y: scale.y)
        }
        return affine
    }
    
    func with(translation: CGPoint) -> Transform {
        return Transform(translation: translation, z: z, scale: scale, rotation: rotation, wiggle: wiggle)
    }
    func with(z: CGFloat) -> Transform {
        return Transform(translation: translation, z: z, rotation: rotation, wiggle: wiggle)
    }
    func with(scale: CGFloat) -> Transform {
        return Transform(translation: translation, scale: CGPoint(x: scale, y: scale), rotation: rotation, wiggle: wiggle)
    }
    func with(scale: CGPoint) -> Transform {
        return Transform(translation: translation, scale: scale, rotation: rotation, wiggle: wiggle)
    }
    func with(rotation: CGFloat) -> Transform {
        return Transform(translation: translation, z: z, scale: scale, rotation: rotation, wiggle: wiggle)
    }
    func with(wiggle: Wiggle) -> Transform {
        return Transform(translation: translation, z: z, scale: scale, rotation: rotation, wiggle: wiggle)
    }
    
    static func linear(_ f0: Transform, _ f1: Transform, t: CGFloat) -> Transform {
        let translation = CGPoint.linear(f0.translation, f1.translation, t: t)
        let scaleX = CGFloat.linear(f0.scale.x, f1.scale.x, t: t)
        let scaleY = CGFloat.linear(f0.scale.y, f1.scale.y, t: t)
        let rotation = CGFloat.linear(f0.rotation, f1.rotation, t: t)
        let wiggle = Wiggle.linear(f0.wiggle, f1.wiggle, t: t)
        return Transform(translation: translation, scale: CGPoint(x: scaleX, y: scaleY), rotation: rotation, wiggle: wiggle)
    }
    static func firstMonospline(_ f1: Transform, _ f2: Transform, _ f3: Transform, with msx: MonosplineX) -> Transform {
        let translation = CGPoint.firstMonospline(f1.translation, f2.translation, f3.translation, with: msx)
        let scaleX = CGFloat.firstMonospline(f1.scale.x, f2.scale.x, f3.scale.x, with: msx)
        let scaleY = CGFloat.firstMonospline(f1.scale.y, f2.scale.y, f3.scale.y, with: msx)
        let rotation = CGFloat.firstMonospline(f1.rotation, f2.rotation, f3.rotation, with: msx)
        let wiggle = Wiggle.firstMonospline(f1.wiggle, f2.wiggle, f3.wiggle, with: msx)
        return Transform(translation: translation, scale: CGPoint(x: scaleX, y: scaleY), rotation: rotation, wiggle: wiggle)
    }
    static func monospline(_ f0: Transform, _ f1: Transform, _ f2: Transform, _ f3: Transform, with msx: MonosplineX) -> Transform {
        let translation = CGPoint.monospline(f0.translation, f1.translation, f2.translation, f3.translation, with: msx)
        let scaleX = CGFloat.monospline(f0.scale.x, f1.scale.x, f2.scale.x, f3.scale.x, with: msx)
        let scaleY = CGFloat.monospline(f0.scale.y, f1.scale.y, f2.scale.y, f3.scale.y, with: msx)
        let rotation = CGFloat.monospline(f0.rotation, f1.rotation, f2.rotation, f3.rotation, with: msx)
        let wiggle = Wiggle.monospline(f0.wiggle, f1.wiggle, f2.wiggle, f3.wiggle, with: msx)
        return Transform(translation: translation, scale: CGPoint(x: scaleX, y: scaleY), rotation: rotation, wiggle: wiggle)
    }
    static func endMonospline(_ f0: Transform, _ f1: Transform, _ f2: Transform, with msx: MonosplineX) -> Transform {
        let translation = CGPoint.endMonospline(f0.translation, f1.translation, f2.translation, with: msx)
        let scaleX = CGFloat.endMonospline(f0.scale.x, f1.scale.x, f2.scale.x, with: msx)
        let scaleY = CGFloat.endMonospline(f0.scale.y, f1.scale.y, f2.scale.y, with: msx)
        let rotation = CGFloat.endMonospline(f0.rotation, f1.rotation, f2.rotation, with: msx)
        let wiggle = Wiggle.endMonospline(f0.wiggle, f1.wiggle, f2.wiggle, with: msx)
        return Transform(translation: translation, scale: CGPoint(x: scaleX, y: scaleY), rotation: rotation, wiggle: wiggle)
    }
    
    var isIdentity: Bool {
        return translation == CGPoint() && scale == CGPoint() && rotation == 0 && wiggle.isEmpty
    }
    
    static func == (lhs: Transform, rhs: Transform) -> Bool {
        return lhs.translation == rhs.translation && lhs.scale == rhs.scale && lhs.rotation == rhs.rotation && lhs.wiggle == rhs.wiggle
    }
}

typealias Hz = CGFloat
struct Wiggle: Equatable, Interpolatable, ByteCoding, Referenceable {
    static let name = Localization(english: "Wiggle", japanese: "振動")
    
    let amplitude: CGPoint, frequency: Hz
    
    init(amplitude: CGPoint = CGPoint(), frequency: Hz = 8) {
        self.amplitude = amplitude
        self.frequency = frequency
    }
    
    func with(amplitude: CGPoint) -> Wiggle {
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    func with(frequency: Hz) -> Wiggle {
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    
    static func linear(_ f0: Wiggle, _ f1: Wiggle, t: CGFloat) -> Wiggle {
        let amplitude = CGPoint.linear(f0.amplitude, f1.amplitude, t: t)
        let frequency = CGFloat.linear(f0.frequency, f1.frequency, t: t)
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    static func firstMonospline(_ f1: Wiggle, _ f2: Wiggle, _ f3: Wiggle, with msx: MonosplineX) -> Wiggle {
        let amplitude = CGPoint.firstMonospline(f1.amplitude, f2.amplitude, f3.amplitude, with: msx)
        let frequency = CGFloat.firstMonospline(f1.frequency, f2.frequency, f3.frequency, with: msx)
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    static func monospline(_ f0: Wiggle, _ f1: Wiggle, _ f2: Wiggle, _ f3: Wiggle, with msx: MonosplineX) -> Wiggle {
        let amplitude = CGPoint.monospline(f0.amplitude, f1.amplitude, f2.amplitude, f3.amplitude, with: msx)
        let frequency = CGFloat.monospline(f0.frequency, f1.frequency, f2.frequency, f3.frequency, with: msx)
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    static func endMonospline(_ f0: Wiggle, _ f1: Wiggle, _ f2: Wiggle, with msx: MonosplineX) -> Wiggle {
        let amplitude = CGPoint.endMonospline(f0.amplitude, f1.amplitude, f2.amplitude, with: msx)
        let frequency = CGFloat.endMonospline(f0.frequency, f1.frequency, f2.frequency, with: msx)
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    
    var isEmpty: Bool {
        return amplitude == CGPoint()
    }
    func phasePosition(with position: CGPoint, phase: CGFloat) -> CGPoint {
        let x = sin(2 * (.pi) * phase)
        return CGPoint(x: position.x + amplitude.x * x, y: position.y + amplitude.y * x)
    }
    static func == (lhs: Wiggle, rhs: Wiggle) -> Bool {
        return lhs.amplitude == rhs.amplitude && lhs.frequency == rhs.frequency
    }
}

final class Speech: NSObject, NSCoding {
    let string: String
    
    init(string: String = "") {
        self.string = string
        super.init()
    }
    
    static let stringKey = "0"
    init?(coder: NSCoder) {
        string = coder.decodeObject(forKey: Speech.stringKey) as? String ?? ""
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(string, forKey: Speech.stringKey)
    }
    
    var isEmpty: Bool {
        return string.isEmpty
    }
    let borderColor = Color.speechBorder, fillColor = Color.speechFill
    func draw(bounds: CGRect, in ctx: CGContext) {
        let attString = NSAttributedString(string: string, attributes: [
            String(kCTFontAttributeName): Font.speech.ctFont,
            String(kCTForegroundColorFromContextAttributeName): true
            ])
        let framesetter = CTFramesetterCreateWithAttributedString(attString)
        let range = CFRange(location: 0, length: attString.length), ratio = bounds.size.width/640
        let lineBounds = CGRect(origin: CGPoint(), size: CTFramesetterSuggestFrameSizeWithConstraints(framesetter, range, nil, CGSize(width: CGFloat.infinity, height: CGFloat.infinity), nil))
        let ctFrame = CTFramesetterCreateFrame(framesetter, range, CGPath(rect: lineBounds, transform: nil), nil)
        ctx.saveGState()
        ctx.translateBy(x: round(bounds.midX - lineBounds.midX),  y: round(bounds.minY + 20 * ratio))
        ctx.setTextDrawingMode(.stroke)
        ctx.setLineWidth(ceil(3 * ratio))
        ctx.setStrokeColor(borderColor.cgColor)
        CTFrameDraw(ctFrame, ctx)
        ctx.setTextDrawingMode(.fill)
        ctx.setFillColor(fillColor.cgColor)
        CTFrameDraw(ctFrame, ctx)
        ctx.restoreGState()
    }
}
