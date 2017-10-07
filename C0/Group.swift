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
//グループの線を色分け
//グループ選択による選択結合
//グループの半透明表示を廃止して、完成表示の上から選択グループを半透明着色する（描画の高速化が必要）
//グループの最終キーフレームの時間編集問題
//ループを再設計
//イージングを再設計（セルやカメラに直接設定）

import Foundation

import AppKit.NSSound

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
final class Drawing: NSObject, NSCoding, Copying {
    var lines: [Line], roughLines: [Line], selectionLineIndexes: [Int]
    
    init(lines: [Line] = [], roughLines: [Line] = [], selectionLineIndexes: [Int] = []) {
        self.lines = lines
        self.roughLines = roughLines
        self.selectionLineIndexes = selectionLineIndexes
        super.init()
    }
    
    static let dataType = "C0.Drawing.1", linesKey = "0", roughLinesKey = "1", selectionLineIndexesKey = "2"
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
        return Line.imageBounds(with: lines, lineWidth: lineWidth).unionNotEmpty(Line.imageBounds(with: roughLines, lineWidth: lineWidth))
    }
    var selectionLinesBounds: CGRect {
        if selectionLineIndexes.isEmpty {
            return CGRect()
        } else {
            return selectionLineIndexes.reduce(CGRect()) { $0.unionNotEmpty(lines[$1].imageBounds) }
        }
    }
    var editLinesBounds: CGRect {
        if selectionLineIndexes.isEmpty {
            return lines.reduce(CGRect()) { $0.unionNotEmpty($1.imageBounds) }
        } else {
            return selectionLineIndexes.reduce(CGRect()) { $0.unionNotEmpty(lines[$1].imageBounds) }
        }
    }
    var editLineIndexes: [Int] {
        return selectionLineIndexes.isEmpty ? Array(0 ..< lines.count) : selectionLineIndexes
    }
    var editLines: [Line] {
        return selectionLineIndexes.isEmpty ? lines : selectionLineIndexes.map { lines[$0] }
    }
    var uneditLines: [Line] {
        return selectionLineIndexes.isEmpty ? [] : (0 ..< lines.count)
            .filter { !selectionLineIndexes.contains($0) }
            .map { lines[$0] }
    }
    
    func draw(lineWidth: CGFloat, lineColor: CGColor, in ctx: CGContext) {
        ctx.setFillColor(lineColor)
        for line in lines {
            draw(line, lineWidth: lineWidth, in: ctx)
        }
    }
    func drawRough(lineWidth: CGFloat, lineColor: CGColor, in ctx: CGContext) {
        ctx.setFillColor(lineColor)
        for line in roughLines {
            draw(line, lineWidth: lineWidth, in: ctx)
        }
    }
    func drawSelectionLines(lineWidth: CGFloat, lineColor: CGColor, in ctx: CGContext) {
        ctx.setFillColor(lineColor)
        for lineIndex in selectionLineIndexes {
            draw(lines[lineIndex], lineWidth: lineWidth, in: ctx)
        }
    }
    private func draw(_ line: Line, lineWidth: CGFloat, in ctx: CGContext) {
        line.draw(size: lineWidth, in: ctx)
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
