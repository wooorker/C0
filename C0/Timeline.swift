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

/*
 # Issue
 ノードトラック、ノード、カットの複数選択
 カット分割
 滑らかなスクロール
*/

import Foundation
import QuartzCore

final class Timeline: LayerRespondable {
    static let name = Localization(english: "Timeline", japanese: "タイムライン")
    static let feature = Localization(
        english: "Select time: Left and right scroll\nSelect animation: Up and down scroll",
        japanese: "時間選択: 左右スクロール\nグループ選択: 上下スクロール"
    )
    var instanceDescription: Localization
    var valueDescription: Localization {
        return Localization(
            english: "Max Time: \(scene.duration)\nCuts Count: \(scene.cutItems.count)",
            japanese: "最大時間: \(scene.duration)\nカットの数: \(scene.cutItems.count)"
        )
    }
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    let layer = CALayer.interface()
    init(frame: CGRect = CGRect(), description: Localization = Localization()) {
        self.instanceDescription = description
        layer.masksToBounds = true
        layer.frame = frame
        cutEditorHeight = bounds.height - timeDivisionHeight - tempoHeight - allKnobsHeight
    }
    
    var frame: CGRect {
        get {
            return layer.frame
        }
        set {
            layer.frame = newValue
            
            cutEditorHeight = bounds.height - timeDivisionHeight - tempoHeight - allKnobsHeight
        }
    }
    
    var scene = Scene() {
        didSet {
            _scrollPoint.x = x(withTime: scene.time)
            _intervalScrollPoint.x = x(withTime: time(withLocalX: _scrollPoint.x))
            cutEditors = self.cutEditors(with: scene)
            children = timeLabels as [Respondable] + [tempoAnimationEditor] as [Respondable]
                + cutEditors as [Respondable]
            updateView(isCut: false, isTransform: false, isKeyframe: true)
            
//            tempoAnimationEditor.
//            scene.tempoTrack.tempoItem.replaceTempo(<#T##tempo: BPM##BPM#>, at: <#T##Int#>)
        }
    }
    var indicationTime = 0
    var setEditCutItemIndexHandler: ((Timeline, Int) -> ())?
    var editCutItemIndex: Int {
        get {
            return scene.editCutItemIndex
        } set {
            scene.editCutItemIndex = newValue
            updateView(isCut: false, isTransform: false, isKeyframe: true)
            setEditCutItemIndexHandler?(self, editCutItemIndex)
        }
    }
    
    static let defautBaseWidth = 6.0.cf, defaultTimeHeight = 24.0.cf
    var baseWidth = defautBaseWidth
    var timeHeight = defaultTimeHeight
    var timeDivisionHeight = 14.0.cf, tempoHeight = defaultTimeHeight, allKnobsHeight = 18.0.cf
    private let knobHalfHeight = 8.0.cf, subKnobHalfHeight = 4.0.cf, maxLineHeight = 3.0.cf
    private(set) var maxScrollX = 0.0.cf
    
    private var _scrollPoint = CGPoint(), _intervalScrollPoint = CGPoint()
    var scrollPoint: CGPoint {
        get {
            return _scrollPoint
        } set {
            let newTime = time(withLocalX: newValue.x)
            if newTime != scene.time {
                updateWith(time: newTime, scrollPoint: newValue)
            } else {
                _scrollPoint = newValue
            }
        }
    }
    var time: Beat {
        get {
            return scene.time
        }
        set {
            if newValue != scene.time {
                updateWith(time: newValue,
                           scrollPoint: CGPoint(x: x(withTime: newValue), y: 0))
            }
        }
    }
    private func updateWith(time: Beat, scrollPoint: CGPoint, alwaysUpdateCutIndex: Bool = false) {
        let oldTime = scene.time
        _scrollPoint = scrollPoint
        _intervalScrollPoint = intervalScrollPoint(with: _scrollPoint)
        if time != oldTime {
            scene.time = time
            sceneDataModel?.isWrite = true
        }
        let cvi = scene.cutItemIndex(withTime: time)
        if alwaysUpdateCutIndex || scene.editCutItemIndex != cvi.index {
            self.editCutItemIndex = cvi.index
            scene.editCutItem.cut.time = cvi.interTime
        } else {
            scene.editCutItem.cut.time = cvi.interTime
        }
        updateView(isCut: true, isTransform: true, isKeyframe: true)
    }
    var updateViewHandler: (((isCut: Bool, isTransform: Bool, isKeyframe: Bool)) -> ())?
    private func updateView(isCut: Bool, isTransform: Bool, isKeyframe: Bool) {
        update()
        if isKeyframe {
            keyframeEditor.keyframe = scene.editCutItem.cut.editNode.editTrack.animation.editKeyframe
        }
        updateViewHandler?((isCut, isTransform, isKeyframe))
    }
    func updateTime(withCutTime cutTime: Beat) {
        _scrollPoint.x = x(withTime: cutTime + scene.cutItems[scene.editCutItemIndex].time)
        let t = time(withLocalX: scrollPoint.x)
        time = t
        _intervalScrollPoint.x = x(withTime: t)
    }
    private func intervalScrollPoint(with scrollPoint: CGPoint) -> CGPoint {
        return CGPoint(x: x(withTime: time(withLocalX: scrollPoint.x)), y: 0)
    }
    
    var contentFrame: CGRect {
        return CGRect(x: _scrollPoint.x, y: 0, width: x(withTime: scene.duration), height: 0)
    }
    
    func time(withLocalX x: CGFloat, isBased: Bool = true) -> Beat {
        return isBased ?
            scene.baseTimeInterval * Beat(Int(round(x / baseWidth))) :
            scene.basedBeatTime(withDoubleBeatTime:
                DoubleBeat(x / baseWidth) * DoubleBeat(scene.baseTimeInterval))
    }
    func x(withTime time: Beat) -> CGFloat {
        return scene.doubleBeatTime(withBeatTime:
            time / scene.baseTimeInterval).cf * baseWidth
    }
    func doubleBeatTime(withLocalX x: CGFloat, isBased: Bool = true) -> DoubleBeat {
        return DoubleBeat(isBased ?
            round(x / baseWidth) :
            x / baseWidth) * DoubleBeat(scene.baseTimeInterval)
    }
    func x(withDoubleBeatTime doubleBeatTime: DoubleBeat) -> CGFloat {
        return CGFloat(doubleBeatTime * DoubleBeat(scene.baseTimeInterval.inversed!))
            * baseWidth
    }
    func doubleBaseTime(withLocalX x: CGFloat) -> DoubleBaseTime {
        return DoubleBaseTime(x / baseWidth)
    }
    func localX(withDoubleBaseTime doubleBaseTime: DoubleBaseTime) -> CGFloat {
        return CGFloat(doubleBaseTime) * baseWidth
    }
    
    func beatTime(withBaseTime baseTime: BaseTime) -> Beat {
        return baseTime * scene.baseTimeInterval
    }
    func baseTime(withBeatTime beatTime: Beat) -> BaseTime {
        return beatTime / scene.baseTimeInterval
    }
    func basedBeatTime(withDoubleBaseTime doubleBaseTime: DoubleBaseTime) -> Beat {
        return Beat(Int(doubleBaseTime)) * scene.baseTimeInterval
    }
    func doubleBaseTime(withBeatTime beatTime: Beat) -> DoubleBaseTime {
        return DoubleBaseTime(beatTime / scene.baseTimeInterval)
    }
    func doubleBaseTime(withX x: CGFloat) -> DoubleBaseTime {
        return DoubleBaseTime(x / baseWidth)
    }
    func basedBeatTime(withDoubleBeatTime doubleBeatTime: DoubleBeat) -> Beat {
        return Beat(Int(doubleBeatTime / DoubleBeat(scene.baseTimeInterval))) * scene.baseTimeInterval
    }
    func clipDeltaTime(withTime time: Beat) -> Beat {
        let ft = baseTime(withBeatTime: time)
        let fft = ft + BaseTime(1, 2)
        return fft - floor(fft) < BaseTime(1, 2) ?
            beatTime(withBaseTime: ceil(ft)) - time :
            beatTime(withBaseTime: floor(ft)) - time
    }
    
    func cutIndex(withLocalX x: CGFloat) -> Int {
        return scene.cutItemIndex(withTime: time(withLocalX: x)).index
    }
    func convertToLocal(_ p: CGPoint) -> CGPoint {
        return CGPoint(x: p.x - (bounds.width / 2 - _intervalScrollPoint.x), y: p.y)
    }
    func convertFromLocal(_ p: CGPoint) -> CGPoint {
        return CGPoint(x: p.x + (bounds.width / 2 - _intervalScrollPoint.x), y: p.y)
    }
    func nearestKeyframeIndexTuple(at p: CGPoint) -> (cutIndex: Int, keyframeIndex: Int?) {
        let ci = cutIndex(withLocalX: p.x)
        let cut = scene.cutItems[ci].cut, ct = scene.cutItems[ci].time
        if cut.editNode.editTrack.animation.keyframes.count == 0 {
            fatalError()
        } else {
            var minD = CGFloat.infinity, minI = 0
            for (i, k) in cut.editNode.editTrack.animation.keyframes.enumerated() {
                let x = self.x(withTime: ct + k.time)
                let d = abs(p.x - x)
                if d < minD {
                    minI = i
                    minD = d
                }
            }
            let x = self.x(withTime: ct + cut.duration)
            let d = abs(p.x - x)
            if d < minD {
                return (ci, nil)
            } else if minI == 0 && ci > 0 {
                return (ci - 1, nil)
            } else {
                return (ci, minI)
            }
        }
    }
    func trackIndexTuple(at p: CGPoint) -> (cutIndex: Int, trackIndex: Int, keyframeIndex: Int?) {
        let ci = cutIndex(withLocalX: p.x)
        let cut = scene.cutItems[ci].cut, ct = scene.cutItems[ci].time
        var minD = CGFloat.infinity, minKeyframeIndex = 0, minTrackIndex = 0
        for (ii, track) in cut.editNode.tracks.enumerated() {
            for (i, k) in track.animation.keyframes.enumerated() {
                let x = self.x(withTime: ct + k.time)
                let d = abs(p.x - x)
                if d < minD {
                    minTrackIndex = ii
                    minKeyframeIndex = i
                    minD = d
                }
            }
        }
        let x = self.x(withTime: ct + cut.duration)
        let d = abs(p.x - x)
        if d < minD {
            return (ci, minTrackIndex, nil)
        } else if minKeyframeIndex == 0 && ci > 0 {
            return (ci - 1, minTrackIndex, nil)
        } else {
            return (ci,  minTrackIndex, minKeyframeIndex)
        }
    }
    
    func cutKnobBounds(with cut: Cut) -> CGRect {
        return CGRect(x: x(withTime: cut.duration),
                      y: timeHeight + 2,
                      width: baseWidth,
                      height: bounds.height - timeHeight * 2 - 2 * 2)
    }
    
    func update() {
        updateBeatLines()
        updateTimeBarFrame()
        updateTimeLabels()
        
        updateCutEditorPositions()
        
        layer.addSublayer(timeBar)
    }
    
    private var timeLabels = [Label]()
    private func updateTimeLabels() {
        let minTime = time(withLocalX: bounds.minX), maxTime = time(withLocalX: bounds.maxX)
        let minSecond = Int(floor(scene.secondTime(withBeatTime: minTime)))
        let maxSecond = Int(ceil(scene.secondTime(withBeatTime: maxTime)))
        guard minSecond < maxSecond else {
            return
        }
        timeLabels.forEach { $0.removeFromParent() }
        self.timeLabels = (minSecond ... maxSecond).map {
            let midX = bounds.width / 2 - baseWidth / 2 - _intervalScrollPoint.x
            let timeLabel = Timeline.timeLabel(withSecound: $0)
            let secondX = x(withTime: scene.beatTime(withSecondTime: Second($0))) + midX
            timeLabel.frame.origin = CGPoint(x: secondX + (baseWidth - timeLabel.frame.width) / 2,
                                             y: bounds.height - timeLabel.frame.height - 2)
            return timeLabel
        }
        children += timeLabels as [Respondable]
    }
    static func timeLabel(withSecound i: Int) -> Label {
        let minute = i / 60
        let second = i - minute * 60
        let string = second < 0 ?
            String(format: "-%d:%02d", minute, -second) :
            String(format: "%d:%02d", minute, second)
        return Label(text: Localization(string), font: .small)
    }
    
    let timeBar: CALayer = {
        let layer = CALayer.disabledAnimation
        layer.backgroundColor = Color.translucentEdit.cgColor
        return layer
    } ()
    func updateTimeBarFrame() {
        let x = bounds.midX - baseWidth / 2
        timeBar.frame = CGRect(x: x, y: 0, width: baseWidth, height: bounds.height)
        if !(layer.sublayers?.contains(timeBar) ?? false) {
            layer.addSublayer(timeBar)
        }
    }
    
    func updateAnimationKnobs() {
        
    }
    
    static let leftWidth = 80.0.cf
    private let tempoSlider = NumberSlider(frame: CGRect(x: 0,
                                                         y: 0,
                                                         width: leftWidth,
                                                         height: Layout.smallHeight),
                                           min: 1, max: 10000000,
                                           valueInterval: 1, unit: " bpm",
                                           description: Localization(english: "Scene tempo",
                                                                     japanese: "シーンのテンポ"))
    
    private let tempoAnimationEditor = AnimationEditor()
    
    private var editCutItem: CutItem?
    private var dragMinCutDeltaTime = Beat(0)
    func diSetKeyframeTime() {
        
    }
    var setDurationHandler: ((Timeline, Beat, CutItem) -> ())?
    
    func cutIndexLabel(_ cutItem: CutItem, index: Int) -> Label {
        return Label(frame: CGRect(x: 0, y: 0,
                                   width: Timeline.leftWidth, height: Layout.smallHeight),
                     text: cutLabelString(with: cutItem, at: index),
                     font: .small, color: .locked)
    }
    func cutLabelString(with cutItem: CutItem, at index: Int) -> Localization {
        let node = cutItem.cut.editNode
        let indexPath = node.indexPath
        var string = Localization(english: "Node", japanese: "ノード")
        indexPath.forEach { string += Localization("\($0).") }
        string += Localization(english: "Track", japanese: "トラック")
        string += Localization("\(node.editTrackIndex)")
        return Localization("\(index): ") + string
    }
    
    var cutEditors = [CutEditor]()
    func updateCutEditorPositions() {
        maxScrollX = scene.cutItems.reduce(0.0.cf) { $0 + self.x(withTime: $1.cut.duration) }
        let minX = bounds.width / 2 - _intervalScrollPoint.x
        _ = cutEditors.reduce(minX) { x, cutEditor in
            cutEditor.frame.origin = CGPoint(x: x, y: allKnobsHeight)
            return x + cutEditor.frame.width
        }
        tempoAnimationEditor.frame.origin = CGPoint(x: minX,
                                                    y: bounds.height -
                                                        timeDivisionHeight - tempoHeight)
    }
    var cutEditorHeight = 0.0.cf
    func cutEditors(with scene: Scene) -> [CutEditor] {
        var x = bounds.width / 2 - _intervalScrollPoint.x
        return scene.cutItems.map {
            let cutEditor = self.cutEditor(with: $0, height: cutEditorHeight)
            cutEditor.frame.origin = CGPoint(x: x, y: allKnobsHeight)
            x += cutEditor.frame.width
            return cutEditor
        }
    }
    func cutEditor(with cutItem: CutItem, height: CGFloat) -> CutEditor {
        return CutEditor(cutItem, baseWidth: baseWidth, timeHeight: timeHeight,
                         knobHalfHeight: knobHalfHeight,
                         subKnobHalfHeight: subKnobHalfHeight,
                         maxLineWidth: maxLineHeight, height: height)
    }
    
    var beatLines = [CALayer]()
    func updateBeatLines() {
        let minTime = time(withLocalX: bounds.minX), maxTime = time(withLocalX: bounds.maxX)
        let intMinTime = floor(minTime).integralPart
        let intMaxTime = ceil(maxTime).integralPart
        guard intMinTime < intMaxTime else {
            return
        }
        guard beatLines.count != intMaxTime - intMinTime + 1 else {
            return
        }
        beatLines = (intMinTime ... intMaxTime).map {
            let i0x = x(withDoubleBeatTime: DoubleBeat($0))
            let layer = CALayer.disabledAnimation
            layer.backgroundColor = Color.locked.multiply(alpha: 0.05).cgColor
            layer.frame = CGRect(x: i0x,
                                 y: Layout.basicPadding,
                                 width: baseWidth,
                                 height: bounds.height - timeHeight)
            return layer
        }
    }
    
    private static func animationsKnobs(_ cut: Cut, y: CGFloat, maxY: CGFloat,
                                        baseWidth: CGFloat, timeHeight: CGFloat,
                                        from animationEditor: AnimationEditor) -> [CALayer] {
        guard cut.editNode.tracks.count > 1 else {
            return []
        }
        var lines = [Beat]()
        for track in cut.editNode.tracks {
            for keyframe in track.animation.keyframes {
                if keyframe.time > 0 && !lines.contains(keyframe.time) {
                    lines.append(keyframe.time)
                }
            }
        }
        var lineLayers = [CALayer](), knobLayers = [CALayer]()
        lines.forEach {
            let x = animationEditor.x(withTime: $0) + baseWidth / 2
            
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: timeHeight / 2))
            path.addLine(to: CGPoint(x: x, y: min(y, maxY)))
            let lineLayer = CAShapeLayer()
            lineLayer.path = path
            lineLayer.lineWidth = 1
            lineLayer.strokeColor = Color.edit.cgColor
            lineLayers.append(lineLayer)
            
            let knobHeight = 6.0.cf
            let knobLayer = CALayer.discreteKnob(width: baseWidth,
                                                 height: knobHeight, lineWidth: 1)
            knobLayer.frame.origin = CGPoint(x: x - baseWidth / 2,
                                             y: Layout.basicPadding
                                                + timeHeight / 2 - knobHeight / 2)
            knobLayers.append(knobLayer)
        }
        return lineLayers + knobLayers
    }
    
    private func registerUndo(_ handler: @escaping (Timeline, Beat) -> Void) {
        undoManager?.registerUndo(withTarget: self) { [oldTime = time] in handler($0, oldTime) }
    }
    
    func insert(_ keyframe: Keyframe, at index: Int,
                with cutEditor: CutEditor, isSplitDrawing: Bool = false) {
        let cutItem = cutEditor.cutItem
        var keyframeValue = cutItem.cut.editNode.editTrack.currentItemValues
        keyframeValue.drawing = isSplitDrawing ? keyframeValue.drawing.copied : Drawing()
        insert(keyframe, keyframeValue,
               at: index, in: cutItem.cut.editNode.editTrack, in: cutItem, time: time)
    }
    func removeTrackOrCut(with cutEditor: CutEditor) {
        let cutItem = cutEditor.cutItem
        let node = cutItem.cut.editNode
        if node.tracks.count > 1 {
            removeTrack(at: node.editTrackIndex, in: node, in: cutItem)
        } else if let cutIndex = cutEditors.index(of: cutEditor) {
            removeCut(at: cutIndex)
        }
    }
    
    func copy(with event: KeyInputEvent) -> CopiedObject {
        let index = cutIndex(withLocalX: convertToLocal(point(from: event)).x)
        let cut = scene.cutItems[index].cut
        return CopiedObject(objects: [cut.copied])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        for object in copiedObject.objects {
            if let cut = object as? Cut {
                let index = cutIndex(withLocalX: convertToLocal(point(from: event)).x)
                insert(CutItem(cut: cut), at: index + 1, time: time)
                let nextCutItem = scene.cutItems[index + 1]
                setTime(nextCutItem.time + nextCutItem.cut.time, oldTime: time)
                return
            }
        }
    }
    
    func delete(with event: KeyInputEvent) {
        let inP = convertToLocal(point(from: event))
        let cutIndex = self.cutIndex(withLocalX: inP.x)
        removeCut(at: cutIndex)
    }
    
    func new(with event: KeyInputEvent) {
        let inP = convertToLocal(point(from: event))
        let cutIndex = self.cutIndex(withLocalX: inP.x)
        insert(CutItem(), at: cutIndex + 1, time: time)
        let nextCutItem = scene.cutItems[cutIndex + 1]
        setTime(nextCutItem.time + nextCutItem.cut.time, oldTime: time)
    }
    
    func insert(_ cutItem: CutItem, at index: Int, time: Beat) {
        registerUndo { $0.removeCutItem(at: index, time: $1) }
        self.time = time
        insert(cutItem, at: index)
    }
    func removeCutItem(at index: Int, time: Beat) {
        let cutItem = scene.cutItems[index]
        registerUndo { $0.insert(cutItem, at: index, time: $1) }
        self.time = time
        removeCutItem(at: index)
    }
    var nextCutKeyIndex: Int {
        if let maxKey = cutsDataModel?.children.max(by: { $0.key < $1.key }) {
            return max(scene.maxCutKeyIndex, Int(maxKey.key) ?? 0) + 1
        } else {
            return scene.maxCutKeyIndex + 1
        }
    }
    var sceneDataModel: DataModel?
    var cutsDataModel: DataModel?
    func insert(_ cutItem: CutItem, at index: Int) {
        let nextIndex = nextCutKeyIndex
        let key = "\(nextIndex)"
        cutItem.key = key
        cutItem.cutDataModel = DataModel(key: key)
        scene.cutItems.insert(cutItem, at: index)
        cutsDataModel?.insert(cutItem.cutDataModel)
        scene.maxCutKeyIndex = nextIndex
        sceneDataModel?.isWrite = true
        
        let cutEditor = self.cutEditor(with: cutItem, height: cutEditorHeight)
        cutEditors.insert(cutEditor, at: index)
        children.append(cutEditor)
        
        updateCutEditorPositions()
    }
    func removeCutItem(at index: Int) {
        let cutDataModel = scene.cutItems[index].cutDataModel
        scene.cutItems.remove(at: index)
        cutsDataModel?.remove(cutDataModel)
        sceneDataModel?.isWrite = true
        
        cutEditors[index].removeFromParent()
        cutEditors.remove(at: index)
        
        updateCutEditorPositions()
    }
    
    func newNode() {
        guard let parent = scene.editCutItem.cut.editNode.parent,
            let index = parent.children.index(of: scene.editCutItem.cut.editNode) else {
                return
        }
        let newNode = Node()
        insert(newNode, at: index, parent: parent, time: time)
        set(editNode: newNode, time: time)
    }
    func insert(_ node: Node, at index: Int, parent: Node, time: Beat) {
        registerUndo { $0.removeNode(at: index, parent: parent, time: $1) }
        self.time = time
        parent.children.insert(node, at: index)
        scene.editCutItem.cutDataModel.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    func removeNode(at index: Int, parent: Node, time: Beat) {
        registerUndo { [on = parent.children[index]] in
            $0.insert(on, at: index, parent: parent, time: $1)
        }
        self.time = time
        parent.children.remove(at: index)
        scene.editCutItem.cutDataModel.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    func set(editNode node: Node, time: Beat) {
        registerUndo { [on = scene.editCutItem.cut.editNode] in $0.set(editNode: on, time: $1) }
        scene.editCutItem.cut.editNode = node
        scene.editCutItem.cutDataModel.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    
    func newNodeTrack() {
        let cutItem = scene.editCutItem
        let node = cutItem.cut.editNode
        let track = NodeTrack(duration: cutItem.cut.duration)
        let trackIndex = node.editTrackIndex + 1
        insert(track, at: trackIndex, in: node, in: cutItem, time: time)
        set(editTrackIndex: trackIndex, oldEditTrackIndex: node.editTrackIndex,
            in: node, in: cutItem, time: time)
    }
    func removeTrack(at index: Int, in node: Node, in cutItem: CutItem) {
        if node.tracks.count > 1 {
            set(editTrackIndex: max(0, index - 1),
                oldEditTrackIndex: index, in: node, in: cutItem, time: time)
            removeTrack(at: index, in: node, in: cutItem, time: time)
        }
    }
    func insert(_ track: NodeTrack, at index: Int, in node: Node, in cutItem: CutItem, time: Beat) {
        registerUndo { $0.removeTrack(at: index, in: node, in: cutItem, time: $1) }
        self.time = time
        node.tracks.insert(track, at: index)
        cutItem.cutDataModel.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    func removeTrack(at index: Int, in node: Node, in cutItem: CutItem, time: Beat) {
        registerUndo { [ot = node.tracks[index]] in
            $0.insert(ot, at: index, in: node, in: cutItem, time: $1)
        }
        self.time = time
        node.tracks.remove(at: index)
        cutItem.cutDataModel.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    private func set(editTrackIndex: Int, oldEditTrackIndex: Int,
                     in node: Node, in cutItem: CutItem, time: Beat) {
        
        registerUndo { $0.set(editTrackIndex: oldEditTrackIndex,
                              oldEditTrackIndex: editTrackIndex, in: node, in: cutItem, time: $1) }
        self.time = time
        node.editTrackIndex = editTrackIndex
        cutItem.cutDataModel.isWrite = true
        updateView(isCut: true, isTransform: true, isKeyframe: true)
    }
    
    func removeCut(at i: Int) {
        if i == 0 {
            setTime(time, oldTime: time, alwaysUpdateCutIndex: true)
            removeCutItem(at: 0, time: time)
            if scene.cutItems.count == 0 {
                insert(CutItem(), at: 0, time: time)
            }
            setTime(0, oldTime: time, alwaysUpdateCutIndex: true)
        } else {
            let previousCut = scene.cutItems[i - 1].cut
            let previousCutTimeLocation = scene.cutItems[i - 1].time
            let isSetTime = i == scene.editCutItemIndex
            setTime(time, oldTime: time, alwaysUpdateCutIndex: true)
            removeCutItem(at: i, time: time)
            if isSetTime {
                let lastKeyframeTime = previousCut.editNode.editTrack.animation.lastKeyframeTime
                setTime(previousCutTimeLocation + lastKeyframeTime,
                        oldTime: time, alwaysUpdateCutIndex: true)
            } else if time >= scene.duration {
                setTime(scene.duration - scene.baseTimeInterval,
                        oldTime: time, alwaysUpdateCutIndex: true)
            }
        }
    }
    private func setTime(_ t: Beat, oldTime: Beat, alwaysUpdateCutIndex: Bool = false) {
        undoManager?.registerUndo(withTarget: self) {
            $0.setTime(oldTime, oldTime: t, alwaysUpdateCutIndex: alwaysUpdateCutIndex)
        }
        updateWith(time: t,
                   scrollPoint: CGPoint(x: x(withTime: t), y: 0),
                   alwaysUpdateCutIndex: alwaysUpdateCutIndex)
        scene.editCutItem.cutDataModel.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    
    private func replace(_ keyframe: Keyframe, at index: Int,
                                 in animation: Animation, in cutItem: CutItem, time: Beat) {
        
        registerUndo { [ok = animation.keyframes[index]] in
            $0.replace(ok, at: index, in: animation, in: cutItem, time: $1)
        }
        self.time = time
        animation.replaceKeyframe(keyframe, at: index)
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        cutItem.cutDataModel.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    private func insert(_ keyframe: Keyframe,
                        _ keyframeValue: NodeTrack.KeyframeValue,
                        at index: Int,
                        in track: NodeTrack, in cutItem: CutItem, time: Beat) {
        
        registerUndo { $0.removeKeyframe(at: index, in: track, in: cutItem, time: $1) }
        self.time = time
        track.insert(keyframe, keyframeValue, at: index)
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        cutItem.cutDataModel.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    private func removeKeyframe(at index: Int,
                                in track: NodeTrack, in cutItem: CutItem, time: Beat) {
        registerUndo {
            [ok = track.animation.keyframes[index],
            okv = track.keyframeItemValues(at: index)] in
            
            $0.insert(ok, okv, at: index, in: track, in: cutItem, time: $1)
        }
        self.time = time
        track.removeKeyframe(at: index)
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        cutItem.cutDataModel.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    
    func changeAnimation(animation: Animation) {
        let otherMaxTime = scene.editCutItem.cut.editNode.maxTimeWithOtherAnimation(animation)
        let otherDeltaTime = otherMaxTime - scene.editCutItem.cut.duration + scene.baseTimeInterval
        dragMinCutDeltaTime = max(otherDeltaTime, dragMinDeltaTime)
//        self.editCutItem = result.cutIndex == 0 && result.keyframeIndex == 0 ?
//            nil : editCutItem
        dragOldCutDuration = scene.editCutItem.cut.duration
        
    }
    func updateAnimationDuration() {
        
        scene.updateCutTimeAndDuration()
    }
    
    let keyframeEditor = KeyframeEditor(), nodeEditor = NodeEditor()
    func showProperty(with event: DragEvent) {
        let root = rootRespondable
        guard root !== self else {
            return
        }
        let point = self.point(from: event)
        let inPoint = convertToLocal(point)
        let cutItem = scene.cutItems[cutIndex(withLocalX: inPoint.x)]
        let track = cutItem.cut.editNode.editTrack
        let ki = Keyframe.index(time: time(withLocalX: inPoint.x) - cutItem.time,
                                with: track.animation.keyframes)
        let keyframe = track.animation.keyframes[ki.index]
        keyframeEditor.keyframe = keyframe
        nodeEditor.node = cutItem.cut.editNode
    }
    
    private var isDrag = false, dragOldTime = DoubleBaseTime(0)
    private var dragOldCutDuration = Beat(0), dragClipDeltaTime = Beat(0)
    private var dragMinDeltaTime = Beat(0), dragChangingDurationCutEditor: CutEditor?
    private var dragOldSlideTuples = [(animation: Animation,
                                       keyframeIndex: Int, oldKeyframes: [Keyframe])]()
    
    func drag(with event: DragEvent) {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            isDrag = false
            let ki = nearestKeyframeIndexTuple(at: p)
            let cutItem = scene.cutItems[ki.cutIndex]
            let kt: Beat
            if let keyframeIndex = ki.keyframeIndex {
                kt = cutItem.cut.editNode.editTrack.animation.keyframes[keyframeIndex].time
            } else {
                kt = cutItem.cut.editNode.editTrack.animation.duration
            }
            var dragOldSlideTuples = [(animation: Animation,
                                       keyframeIndex: Int, oldKeyframes: [Keyframe])]()
            var pkt = Beat(0)
//                    scene.tempo
            for track in scene.editCutItem.cut.editNode.tracks {
                let result = Keyframe.index(time: kt, with: track.animation.keyframes)
                let index: Int? = result.interTime > 0 ?
                    (result.index + 1 <= track.animation.keyframes.count - 1 ?
                        result.index + 1 : nil) :
                    result.index
                if let i = index {
                    dragOldSlideTuples.append((track.animation, i,
                                               track.animation.keyframes))
                }
                let preIndex: Int? = result.interTime > 0 ?
                    result.index : (result.index > 0 ? result.index - 1 : nil)
                if let pi = preIndex {
                    let preTime = track.animation.keyframes[pi].time
                    if pkt < preTime {
                        pkt = preTime
                    }
                }
            }
            dragClipDeltaTime = clipDeltaTime(withTime: kt)
            dragMinDeltaTime = pkt - kt + scene.baseTimeInterval
            self.dragOldSlideTuples = dragOldSlideTuples
            
            //dragChangingDurationCutEditor =
            self.dragMinCutDeltaTime = dragMinDeltaTime
//            self.editCutItem = result.cutIndex == 0 && result.keyframeIndex == 0 ?
//                nil : scene.editCutItem
            self.dragOldCutDuration = scene.editCutItem.cut.duration
            dragOldTime = doubleBaseTime(withX: p.x)
        case .sending:
            isDrag = true
            let t = doubleBaseTime(withX: point(from: event).x)
            let fdt = t - dragOldTime + (t - dragOldTime >= 0 ? 0.5 : -0.5)
            let dt = basedBeatTime(withDoubleBaseTime: fdt)
            let deltaTime = max(dragMinDeltaTime, dt + dragClipDeltaTime)
            for slideAnimation in dragOldSlideTuples {
                var nks = slideAnimation.oldKeyframes
                for i in slideAnimation.keyframeIndex ..< nks.count {
                    nks[i] = nks[i].with(time: nks[i].time + deltaTime)
                }
                slideAnimation.animation.replaceKeyframes(nks)
            }
            
            let animationDuration = dragOldCutDuration + max(dragMinCutDeltaTime,
                                                             dt + dragClipDeltaTime)
//            updateHnadler
            if animationDuration != scene.editCutItem.cut.duration {
                scene.editCutItem.cut.duration = animationDuration
                scene.updateCutTimeAndDuration()
            }
            
            updateCutEditorPositions()
        case .end:
            guard isDrag else {
                return
            }
            let t = doubleBaseTime(withX: point(from: event).x)
            let fdt = t - dragOldTime + (t - dragOldTime >= 0 ? 0.5 : -0.5)
            let dt = basedBeatTime(withDoubleBaseTime: fdt)
            let deltaTime = max(dragMinDeltaTime, dt + dragClipDeltaTime)
            for slideAnimation in dragOldSlideTuples {
                var nks = slideAnimation.oldKeyframes
                if deltaTime != 0 {
                    for i in slideAnimation.keyframeIndex ..< nks.count {
                        nks[i] = nks[i].with(time: nks[i].time + deltaTime)
                    }
                    //animationEditor setKeyframes
//                    set(nks, oldKeyframes: slideAnimation.oldKeyframes,
//                        in: slideAnimation.animation)
                } else {
                    slideAnimation.animation.replaceKeyframes(nks)
                }
            }
            
            if let cutEditor = dragChangingDurationCutEditor {
                let duration = dragOldCutDuration + max(dragMinCutDeltaTime, dt + dragClipDeltaTime)
                if duration != dragOldCutDuration {
                    set(duration: duration, oldDuration: dragOldCutDuration,
                        in: cutEditor)
                }
            }

            dragOldSlideTuples = []
        }
    }
    
    private func set(duration: Beat, oldDuration: Beat, in cutEditor: CutEditor) {
        
        updateCutEditorPositions()
    }
    
    func moveToPrevious(with event: KeyInputEvent) {
        let cut = scene.editCutItem.cut
        let track = cut.editNode.editTrack
        let loopedIndex = track.animation.loopedKeyframeIndex(withTime: cut.time).loopedIndex
        let keyframeIndex = track.animation.loopFrames[loopedIndex]
        if cut.time - keyframeIndex.time > 0 {
            updateTime(withCutTime: keyframeIndex.time)
        } else if loopedIndex - 1 >= 0 {
            updateTime(withCutTime: track.animation.loopFrames[loopedIndex - 1].time)
        } else if scene.editCutItemIndex - 1 >= 0 {
            self.editCutItemIndex -= 1
            updateTime(withCutTime: track.animation.lastLoopedKeyframeTime)
        }
    }
    func moveToNext(with event: KeyInputEvent) {
        let cut = scene.editCutItem.cut
        let track = cut.editNode.editTrack
        let loopedIndex = track.animation.loopedKeyframeIndex(withTime: cut.time).loopedIndex
        if loopedIndex + 1 <= track.animation.loopFrames.count - 1 {
            let t = track.animation.loopFrames[loopedIndex + 1].time
            if t < track.animation.duration {
                updateTime(withCutTime: t)
                return
            }
        }
        if scene.editCutItemIndex + 1 <= scene.cutItems.count - 1 {
            self.editCutItemIndex += 1
            updateTime(withCutTime: 0)
        }
    }
    
    var scrollHandler: ((Timeline, CGPoint, ScrollEvent) -> ())?
    private var istrackscroll = false, deltaScrollY = 0.0.cf, scrollCutItem: CutItem?
    func scroll(with event: ScrollEvent) {
        scroll(with: event, isUseMomentum: true)
    }
    func scroll(with event: ScrollEvent, isUseMomentum: Bool) {
        if event.scrollMomentumType == nil {
            //snapScroll
        }
        let maxX = self.x(withTime: scene.duration - scene.baseTimeInterval)
        let x = (scrollPoint.x - event.scrollDeltaPoint.x).clip(min: 0, max: maxX)
        scrollPoint = CGPoint(x: event.sendType == .begin ?
            self.x(withTime: time(withLocalX: x)) : x, y: 0)
        scrollHandler?(self, scrollPoint, event)
    }
    func zoom(with event: PinchEvent) {
        zoom(at: point(from: event)) {
            baseWidth = (baseWidth * (event.magnification * 2.5 + 1))
                .clip(min: 1, max: Timeline.defautBaseWidth)
        }
    }
    func reset(with event: DoubleTapEvent) {
        zoom(at: point(from: event)) {
            baseWidth = Timeline.defautBaseWidth
        }
    }
    func zoom(at p: CGPoint, handler: () -> ()) {
        handler()
        _scrollPoint.x = x(withTime: time)
        _intervalScrollPoint.x = scrollPoint.x
        updateView(isCut: false, isTransform: false, isKeyframe: false)
    }
}
