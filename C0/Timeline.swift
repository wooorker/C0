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
 - ノードトラック、ノード、カットの複数選択
 - カット分割
 - 滑らかなスクロール
 - sceneを取り除く
 - スクロールの可視性の改善
 */
final class Timeline: Layer, Respondable {
    static let name = Localization(english: "Timeline", japanese: "タイムライン")
    static let feature = Localization(
        english: "Select time: Left and right scroll\nSelect animation: Up and down scroll",
        japanese: "時間選択: 左右スクロール\nグループ選択: 上下スクロール"
    )
    
    var scene = Scene() {
        didSet {
            _scrollPoint.x = x(withTime: scene.time)
            _intervalScrollPoint.x = x(withTime: time(withLocalX: _scrollPoint.x))
            cutEditors = self.cutEditors(with: scene)
            baseTimeInterval = scene.baseTimeInterval
            tempoSlider.value = scene.tempoTrack.tempoItem.tempo.cf
            tempoAnimationEditor.animation = scene.tempoTrack.animation
            updateView(isCut: false, isTransform: false, isKeyframe: true)
        }
    }
    var indicatedTime = 0
    var setEditCutItemIndexHandler: ((Timeline, Int) -> ())?
    var editCutItemIndex: Int {
        get {
            return scene.editCutItemIndex
        }
        set {
            scene.editCutItemIndex = newValue
            updateView(isCut: false, isTransform: false, isKeyframe: true)
            setEditCutItemIndexHandler?(self, editCutItemIndex)
        }
    }
    
    static let leftWidth = 80.0.cf
    let timeRuler = Ruler()
    let tempoSlider = NumberSlider(frame: CGRect(x: 0, y: 0,
                                                 width: leftWidth, height: Layout.basicHeight),
                                   min: 1, max: 100000, valueInterval: 1, unit: " bpm",
                                   description: Localization(english: "Tempo", japanese: "テンポ"))
    let tempoAnimationEditor = AnimationEditor()
    let tempoEditor = GroupResponder()
    let nodeTreeEditor = NodeTreeEditor()
    let cutEditorsEditor = GroupResponder()
    let sumKeyTimesEditor = KnobsEditor()
    let timeLayer: Layer = {
        let layer = Layer()
        layer.fillColor = .edit
        layer.lineColor = nil
        return layer
    } ()
    
    let beatsLayer = PathLayer()
    
    let keyframeEditor = KeyframeEditor(), nodeEditor = NodeEditor()
    
    init(frame: CGRect = CGRect(), description: Localization = Localization()) {
        cutEditorHeight = frame.height - timeRulerHeight - tempoHeight - sumKeyTimesHeight
        tempoEditor.replace(children: [tempoAnimationEditor])
        sumKeyTimesEditor.knobSize.width = baseWidth
        tempoEditor.isClipped = true
        cutEditorsEditor.isClipped = true
        sumKeyTimesEditor.isClipped = true
        timeRuler.isClipped = true
        beatsLayer.isClipped = true
        beatsLayer.fillColor = .subContent
        beatsLayer.lineColor = nil
        
        super.init()
        instanceDescription = description
        replace(children: [timeLayer, beatsLayer, sumKeyTimesEditor, timeRuler,
                           tempoEditor, tempoSlider,
                           nodeTreeEditor, cutEditorsEditor])
        if !frame.isEmpty {
            self.frame = frame
        }
        
        tempoSlider.setValueHandler = { [unowned self] in
            let tempo = BPM($0.value)
            self.scene.tempoTrack.tempoItem.replace(tempo: tempo, at:
                self.scene.tempoTrack.animation.editKeyframeIndex)
            self.scene.tempoTrack.tempoItem.tempo = tempo
            self.updateTimeRuler()
        }
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        cutEditorHeight = bounds.height - timeRulerHeight - tempoHeight - sumKeyTimesHeight
        let midX = bounds.midX, padding = Layout.basicPadding, leftWidth = Timeline.leftWidth
        let rightX = leftWidth
        timeRuler.frame = CGRect(x: rightX, y: bounds.height - timeRulerHeight,
                                 width: bounds.width - rightX, height: timeRulerHeight)
        tempoSlider.frame = CGRect(x: padding, y: bounds.height - timeRulerHeight - tempoHeight,
                                   width: leftWidth - padding, height: tempoHeight)
        tempoEditor.frame = CGRect(x: rightX, y: bounds.height - timeRulerHeight - tempoHeight,
                                   width: bounds.width - rightX, height: tempoHeight)
        nodeTreeEditor.frame = CGRect(x: padding, y: sumKeyTimesHeight,
                                      width: leftWidth - padding, height: cutEditorHeight)
        cutEditorsEditor.frame = CGRect(x: rightX, y: sumKeyTimesHeight,
                                        width: bounds.width - rightX, height: cutEditorHeight)
        sumKeyTimesEditor.frame = CGRect(x: rightX, y: 0,
                                         width: bounds.width - rightX, height: bounds.height)
        timeLayer.frame = CGRect(x: midX - baseWidth / 2, y: 0,
                                 width: baseWidth, height: bounds.height)
        beatsLayer.frame = CGRect(x: rightX, y: 0,
                                  width: bounds.width - rightX, height: bounds.height)
    }
    
    static let defautBaseWidth = 6.0.cf, defaultTimeHeight = 24.0.cf
    var baseWidth = defautBaseWidth {
        didSet {
           sumKeyTimesEditor.knobSize.width = baseWidth
        }
    }
    private let timeHeight = defaultTimeHeight
    private let timeRulerHeight = 14.0.cf, tempoHeight = defaultTimeHeight
    private let sumKeyTimesHeight = 18.0.cf
    private let knobHalfHeight = 8.0.cf, subKnobHalfHeight = 4.0.cf, maxLineHeight = 3.0.cf
    private(set) var maxScrollX = 0.0.cf
    
    private var _scrollPoint = CGPoint(), _intervalScrollPoint = CGPoint()
    var scrollPoint: CGPoint {
        get {
            return _scrollPoint
        }
        set {
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
                updateWith(time: newValue, scrollPoint: CGPoint(x: x(withTime: newValue), y: 0))
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
    
    var editX: CGFloat {
        return bounds.midX - Timeline.leftWidth
    }
    
    var localDeltaX: CGFloat {
        return editX - _intervalScrollPoint.x
    }
    func convertToLocalX(_ x: CGFloat) -> CGFloat {
        return x - Timeline.leftWidth - localDeltaX
    }
    func convertFromLocalX(_ x: CGFloat) -> CGFloat {
        return x - Timeline.leftWidth + localDeltaX
    }
    func convertToLocal(_ p: CGPoint) -> CGPoint {
        return CGPoint(x: convertToLocalX(p.x), y: p.y)
    }
    func convertFromLocal(_ p: CGPoint) -> CGPoint {
        return CGPoint(x: convertFromLocalX(p.x), y: p.y)
    }
    func nearestKeyframeIndexTuple(at p: CGPoint) -> (cutIndex: Int, keyframeIndex: Int?) {
        let ci = cutIndex(withLocalX: p.x)
        let cut = scene.cutItems[ci].cut, ct = scene.cutItems[ci].time
        guard cut.editNode.editTrack.animation.keyframes.count > 0 else {
            fatalError()
        }
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
    
    func update() {
//        updateBeats()
//        updateTimeRuler()
//        updateSubKeyTimesEditor()
        updateCutEditorPositions()
    }
    
    var baseTimeInterval = Beat(1, 16) {
        didSet {
            tempoAnimationEditor.baseTimeInterval = baseTimeInterval
            cutEditors.forEach {
                $0.animationEditor.baseTimeInterval = baseTimeInterval
                $0.updateChildren()
            }
            updateCutEditorPositions()
        }
    }
    
    var editCutEditor: CutEditor {
        return cutEditors[scene.editCutItemIndex]
    }
    var cutEditors = [CutEditor]() {
        didSet {
            cutEditorsEditor.replace(children: cutEditors)
            updateCutEditorPositions()
        }
    }
    func updateCutEditorPositions() {
        maxScrollX = scene.cutItems.reduce(0.0.cf) { $0 + self.x(withTime: $1.cut.duration) }
        let minX = localDeltaX
        _ = cutEditors.reduce(minX) { x, cutEditor in
            cutEditor.frame.origin = CGPoint(x: x, y: 0)
            return x + cutEditor.frame.width
        }
        tempoAnimationEditor.frame.origin = CGPoint(x: minX, y: 0)
        updateBeats()
        updateTimeRuler()
        updateSubKeyTimesEditor()
    }
    var cutEditorHeight = 0.0.cf
    func cutEditors(with scene: Scene) -> [CutEditor] {
        return scene.cutItems.map { self.cutEditor(with: $0, height: cutEditorHeight) }
    }
    func cutEditor(with cutItem: CutItem, height: CGFloat) -> CutEditor {
        let cutEditor = CutEditor(cutItem, baseWidth: baseWidth, timeHeight: timeHeight,
                                  knobHalfHeight: knobHalfHeight,
                                  subKnobHalfHeight: subKnobHalfHeight,
                                  maxLineWidth: maxLineHeight, height: height)
        cutEditor.animationEditor.baseTimeInterval = baseTimeInterval
        cutEditor.updateDuration()
        cutEditor.animationEditor.setKeyframeHandler = { [unowned self, unowned cutEditor] in
            switch $0.setType {
            case .insert:
                self.insert($0.keyframe, at: $0.index, with: cutEditor)
            case .remove:
                self.removeKeyframe(at: $0.index,
                                    in: cutEditor.cutItem.cut.editNode.editTrack,
                                    in: cutEditor, time: self.time)
            case .replace:
                self.replace($0.keyframe, at: $0.index,
                             in: cutEditor.cutItem.cut.editNode.editTrack,
                             in: cutEditor, time: self.time)
            }
        }
        cutEditor.animationEditor.slideHandler = { [unowned self, unowned cutEditor] in
            self.setAnimation(with: $0, in: cutEditor)
        }
        cutEditor.animationEditor.dragFirstKeyframeHandler = { [unowned self, unowned cutEditor] in
            if let index = self.cutEditors.index(of: cutEditor), index > 0 {
                return self.cutEditors[index - 1].animationEditor.move(with: $1)
            } else {
                return true
            }
        }
        cutEditor.animationEditor.selectHandler = { [unowned self, unowned cutEditor] in
            self.setAnimation(with: $0, in: cutEditor)
        }
        cutEditor.removeTrackHandler = { [unowned self] in
            self.removeTrack(at: $1, in: $2, in: $0)
        }
        cutEditor.pasteHandler = { [unowned self] in
            if let index = self.cutEditors.index(of: $0) {
                for object in $1.objects {
                    if let cut = object as? Cut {
                        self.paste(cut, at: index + 1)
                        return true
                    }
                }
            }
            return false
        }
        cutEditor.deleteHandler = { [unowned self] in
            if let index = self.cutEditors.index(of: $0) {
                self.removeCut(at: index)
            }
            return true
        }
        cutEditor.scrollHandler = { [unowned self, unowned cutEditor] obj in
            if obj.type == .end {
                if obj.nodeAndTrack != obj.oldNodeAndTrack {
                    self.registerUndo(time: self.time) {
                        self.set(obj.oldNodeAndTrack, old: obj.nodeAndTrack, in: cutEditor, time: $1)
                    }
                }
            }
        }
        cutEditor.bindHandler = { [unowned self] in
            self.keyframeEditor.keyframe = $0.animationBindHandlerObject.keyframe
            self.nodeEditor.node = $0.cutEditor.cutItem.cut.editNode
        }
        return cutEditor
    }
    
    func updateTimeRuler() {
        let minTime = time(withLocalX: convertToLocalX(bounds.minX + Timeline.leftWidth))
        let maxTime = time(withLocalX: convertToLocalX(bounds.maxX))
        let minSecond = Int(floor(scene.secondTime(withBeatTime: minTime)))
        let maxSecond = Int(ceil(scene.secondTime(withBeatTime: maxTime)))
        guard minSecond < maxSecond else {
            return
        }
        let minX = localDeltaX
        timeRuler.labels = (minSecond ... maxSecond).map {
            let timeLabel = Timeline.timeLabel(withSecound: $0)
            timeLabel.fillColor = nil
            let secondX = x(withTime: scene.beatTime(withSecondTime: Second($0))) + minX
            timeLabel.frame.origin = CGPoint(x: secondX - timeLabel.frame.width / 2,
                                             y: Layout.smallPadding)
            return timeLabel
        }
    }
    static func timeLabel(withSecound i: Int) -> Label {
        let minute = i / 60
        let second = i - minute * 60
        let string = second < 0 ?
            String(format: "-%d:%02d", minute, -second) :
            String(format: "%d:%02d", minute, second)
        return Label(text: Localization(string), font: .small)
    }
    
    func updateSubKeyTimesEditor() {
        var keyTimes = [Beat]()
        for keyframe in scene.tempoTrack.animation.keyframes {
            if keyframe.time > 0 && !keyTimes.contains(keyframe.time) {
                keyTimes.append(keyframe.time)
            }
        }
        scene.cutItems.forEach { cutItem in
            let cut = cutItem.cut
            for track in cut.editNode.tracks {
                for keyframe in track.animation.keyframes {
                    if keyframe.time > 0 && !keyTimes.contains(keyframe.time) {
                        keyTimes.append(keyframe.time)
                    }
                }
            }
        }
        let minX = localDeltaX
        sumKeyTimesEditor.positions = keyTimes.map {
            let x = self.x(withTime: $0) + minX
            return CGPoint(x: x, y: sumKeyTimesHeight / 2)
        }
    }
    
    let beatsLineWidth = 1.0.cf
    func updateBeats() {
        let minX = localDeltaX
        let minTime = time(withLocalX: convertToLocalX(bounds.minX + Timeline.leftWidth))
        let maxTime = time(withLocalX: convertToLocalX(bounds.maxX))
        let intMinTime = floor(minTime).integralPart, intMaxTime = ceil(maxTime).integralPart
        guard intMinTime < intMaxTime else {
            beatsLayer.path = nil
            return
        }
        let path = CGMutablePath()
        let rects: [CGRect] = (intMinTime ... intMaxTime).map {
            let i0x = x(withDoubleBeatTime: DoubleBeat($0)) + minX
            return CGRect(x: i0x - beatsLineWidth / 2, y: 0,
                          width: beatsLineWidth, height: bounds.height)
        }
        path.addRects(rects)
        beatsLayer.path = path
    }
    
    var sceneDataModel: DataModel?
    var cutsDataModel: DataModel?
    
    private func registerUndo(time: Beat, _ handler: @escaping (Timeline, Beat) -> Void) {
        undoManager?.registerUndo(withTarget: self) { [oldTime = self.time] in
            handler($0, oldTime)
        }
        self.time = time
    }
    
    private func set(time: Beat, oldTime: Beat, alwaysUpdateCutIndex: Bool = false) {
        undoManager?.registerUndo(withTarget: self) {
            $0.set(time: oldTime, oldTime: time, alwaysUpdateCutIndex: alwaysUpdateCutIndex)
        }
        updateWith(time: time,
                   scrollPoint: CGPoint(x: x(withTime: time), y: 0),
                   alwaysUpdateCutIndex: alwaysUpdateCutIndex)
        scene.editCutItem.cutDataModel.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        for object in copiedObject.objects {
            if let cut = object as? Cut {
                let localX = convertToLocalX(point(from: event).x)
                let index = cutIndex(withLocalX: localX)
                paste(cut, at: index + 1)
                return true
            }
        }
        return false
    }
    func paste(_ cut: Cut, at index: Int) {
        let newCutItem = CutItem(cut: cut)
        insert(newCutItem, at: index, time: time)
        set(time: newCutItem.time + newCutItem.cut.time, oldTime: time)
    }
    func new(with event: KeyInputEvent) -> Bool {
        let localX = convertToLocalX(point(from: event).x)
        let cutIndex = self.cutIndex(withLocalX: localX)
        insert(CutItem(), at: cutIndex + 1, time: time)
        let nextCutItem = scene.cutItems[cutIndex + 1]
        set(time: nextCutItem.time + nextCutItem.cut.time, oldTime: time)
        return true
    }
    func insert(_ cutItem: CutItem, at index: Int, time: Beat) {
        registerUndo(time: time) { $0.removeCutItem(at: index, time: $1) }
        insert(cutItem, at: index)
    }
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
        cutEditorsEditor.append(child: cutEditor)
        
        updateCutEditorPositions()
    }
    
    func delete(with event: KeyInputEvent) -> Bool {
        let localX = convertToLocalX(point(from: event).x)
        let cutIndex = self.cutIndex(withLocalX: localX)
        removeCut(at: cutIndex)
        return true
    }
    func removeCut(at i: Int) {
        if i == 0 {
            set(time: time, oldTime: time, alwaysUpdateCutIndex: true)
            removeCutItem(at: 0, time: time)
            if scene.cutItems.count == 0 {
                insert(CutItem(), at: 0, time: time)
            }
            set(time: 0, oldTime: time, alwaysUpdateCutIndex: true)
        } else {
            let previousCut = scene.cutItems[i - 1].cut
            let previousCutTimeLocation = scene.cutItems[i - 1].time
            let isSetTime = i == scene.editCutItemIndex
            set(time: time, oldTime: time, alwaysUpdateCutIndex: true)
            removeCutItem(at: i, time: time)
            if isSetTime {
                let lastKeyframeTime = previousCut.editNode.editTrack.animation.lastKeyframeTime
                set(time: previousCutTimeLocation + lastKeyframeTime,
                    oldTime: time, alwaysUpdateCutIndex: true)
            } else if time >= scene.duration {
                set(time: scene.duration - scene.baseTimeInterval,
                    oldTime: time, alwaysUpdateCutIndex: true)
            }
        }
    }
    func removeCutItem(at index: Int, time: Beat) {
        let cutItem = scene.cutItems[index]
        registerUndo(time: time) { $0.insert(cutItem, at: index, time: $1) }
        removeCutItem(at: index)
    }
    var nextCutKeyIndex: Int {
        if let maxKey = cutsDataModel?.children.max(by: { $0.key < $1.key }) {
            return max(scene.maxCutKeyIndex, Int(maxKey.key) ?? 0) + 1
        } else {
            return scene.maxCutKeyIndex + 1
        }
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
        registerUndo(time: time) { $0.removeNode(at: index, parent: parent, time: $1) }
        parent.children.insert(node, at: index)
        scene.editCutItem.cutDataModel.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    func removeNode(at index: Int, parent: Node, time: Beat) {
        registerUndo(time: time) { [on = parent.children[index]] in
            $0.insert(on, at: index, parent: parent, time: $1)
        }
        parent.children.remove(at: index)
        scene.editCutItem.cutDataModel.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    func set(editNode node: Node, time: Beat) {
        registerUndo(time: time) { [on = scene.editCutItem.cut.editNode] in
            $0.set(editNode: on, time: $1)
        }
        scene.editCutItem.cut.editNode = node
        scene.editCutItem.cutDataModel.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    
    func newNodeTrack() {
        let cutEditor = cutEditors[scene.editCutItemIndex]
        let node = cutEditor.cutItem.cut.editNode
        let track = NodeTrack()
        let trackIndex = node.editTrackIndex + 1
        insert(track, at: trackIndex, in: node, in: cutEditor, time: time)
        set(editTrackIndex: trackIndex, oldEditTrackIndex: node.editTrackIndex,
            in: node, in: cutEditor, time: time)
    }
    func removeTrack(at index: Int, in node: Node, in cutEditor: CutEditor) {
        if node.tracks.count > 1 {
            set(editTrackIndex: max(0, index - 1),
                oldEditTrackIndex: index, in: node, in: cutEditor, time: time)
            removeTrack(at: index, in: node, in: cutEditor, time: time)
        }
    }
    func insert(_ track: NodeTrack, at index: Int, in node: Node,
                in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) { $0.removeTrack(at: index, in: node, in: cutEditor, time: $1) }
        node.tracks.insert(track, at: index)
        cutEditor.cutItem.cutDataModel.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    func removeTrack(at index: Int, in node: Node, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) { [ot = node.tracks[index]] in
            $0.insert(ot, at: index, in: node, in: cutEditor, time: $1)
        }
        node.tracks.remove(at: index)
        cutEditor.cutItem.cutDataModel.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    private func set(editTrackIndex: Int, oldEditTrackIndex: Int,
                     in node: Node, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) {
            $0.set(editTrackIndex: oldEditTrackIndex,
                   oldEditTrackIndex: editTrackIndex, in: node, in: cutEditor, time: $1)
        }
        node.editTrackIndex = editTrackIndex
        cutEditor.cutItem.cutDataModel.isWrite = true
        updateView(isCut: true, isTransform: true, isKeyframe: true)
    }
    
    private func set(_ editNodeAndTrack: CutEditor.NodeAndTrack,
                     old oldEditNodeAndTrack: CutEditor.NodeAndTrack,
                     in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldEditNodeAndTrack, old: editNodeAndTrack, in: cutEditor, time: $1)
        }
        cutEditor.editNodeAndTrack = editNodeAndTrack
    }
    
    private var oldTrack: NodeTrack?
    private func setAnimation(with obj: AnimationEditor.SlideHandlerObject,
                              in cutEditor: CutEditor) {
        switch obj.type {
        case .begin:
            oldTrack = cutEditor.cutItem.cut.editNode.editTrack
        case .sending:
            guard let oldTrack = oldTrack else {
                return
            }
            oldTrack.replace(obj.animation.keyframes, duration: obj.animation.duration)
            updateCutDuration(with: cutEditor)
        case .end:
            guard let oldTrack = oldTrack else {
                return
            }
            if obj.animation != obj.oldAnimation {
                registerUndo(time: time) {
                    $0.set(obj.oldAnimation, old: obj.animation,
                           in: oldTrack, in: cutEditor, time: $1)
                }
            }
            updateCutDuration(with: cutEditor)
            self.oldTrack = nil
        }
    }
    private func setAnimation(with obj: AnimationEditor.SelectHandlerObject,
                              in cutEditor: CutEditor) {
        switch obj.type {
        case .begin:
            oldTrack = cutEditor.cutItem.cut.editNode.editTrack
        case .sending:
            break
        case .end:
            guard let oldTrack = oldTrack else {
                return
            }
            if obj.animation != obj.oldAnimation {
                registerUndo(time: time) {
                    $0.set(obj.oldAnimation, old: obj.animation,
                           in: oldTrack, in: cutEditor, time: $1)
                }
            }
            updateCutDuration(with: cutEditor)
            self.oldTrack = nil
        }
    }
    private func set(_ animation: Animation, old oldAnimation: Animation,
                     in track: NodeTrack, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldAnimation, old: animation, in: track, in: cutEditor, time: $1)
        }
        track.replace(animation.keyframes, duration: animation.duration)
        cutEditor.updateChildren()
        cutEditor.cutItem.cutDataModel.isWrite = true
        updateCutEditorPositions()
    }
    func insert(_ keyframe: Keyframe, at index: Int,
                with cutEditor: CutEditor, isSplitDrawing: Bool = false) {
        let cutItem = cutEditor.cutItem
        var keyframeValue = cutItem.cut.editNode.editTrack.currentItemValues
        keyframeValue.drawing = isSplitDrawing ? keyframeValue.drawing.copied : Drawing()
        insert(keyframe, keyframeValue,
               at: index, in: cutItem.cut.editNode.editTrack, in: cutEditor, time: time)
    }
    private func replace(_ keyframe: Keyframe, at index: Int,
                                 in track: NodeTrack, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) { [ok = track.animation.keyframes[index]] in
            $0.replace(ok, at: index, in: track, in: cutEditor, time: $1)
        }
        track.replace(keyframe, at: index)
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        cutEditor.cutItem.cutDataModel.isWrite = true
        if track == cutEditor.cutItem.cut.editNode.editTrack {
            cutEditor.animationEditor.animation = track.animation
        }
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    private func insert(_ keyframe: Keyframe,
                        _ keyframeValue: NodeTrack.KeyframeValues,
                        at index: Int,
                        in track: NodeTrack, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) { $0.removeKeyframe(at: index, in: track, in: cutEditor, time: $1) }
        track.insert(keyframe, keyframeValue, at: index)
        cutEditor.cutItem.cutDataModel.isWrite = true
        if track == cutEditor.cutItem.cut.editNode.editTrack {
            cutEditor.animationEditor.animation = track.animation
        }
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    private func removeKeyframe(at index: Int,
                                in track: NodeTrack, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) {
            [ok = track.animation.keyframes[index],
            okv = track.keyframeItemValues(at: index)] in
            
            $0.insert(ok, okv, at: index, in: track, in: cutEditor, time: $1)
        }
        track.removeKeyframe(at: index)
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        cutEditor.cutItem.cutDataModel.isWrite = true
        if track == cutEditor.cutItem.cut.editNode.editTrack {
            cutEditor.animationEditor.animation = track.animation
        }
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    
    func updateCutDuration(with cutEditor: CutEditor) {
        cutEditor.updateDuration()
        scene.updateCutTimeAndDuration()
        tempoAnimationEditor.animation.duration = scene.duration
        updateCutEditorPositions()
    }
    
    var setSceneDurationHandler: ((Timeline, Beat) -> ())?
    /*
    private var editCutItem: CutItem?
    private var dragMinCutDeltaTime = Beat(0)
    private var isDrag = false, dragOldTime = DoubleBaseTime(0)
    private var dragOldCutDuration = Beat(0), dragClipDeltaTime = Beat(0)
    private var dragMinDeltaTime = Beat(0), dragChangingDurationCutEditor: CutEditor?
    private var dragOldSlideTuples = [(animation: Animation,
                                       keyframeIndex: Int, oldKeyframes: [Keyframe],
                                       track: NodeTrack)]()
    func move(with event: DragEvent) -> Bool {
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
                                       keyframeIndex: Int, oldKeyframes: [Keyframe],
                                       track: NodeTrack)]()
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
                                               track.animation.keyframes, track))
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
            dragChangingDurationCutEditor = cutEditors[ki.cutIndex]
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
                slideAnimation.track.replace(nks)
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
                    slideAnimation.track.replace(nks)
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
    */
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
    private var isScrollTrack = false
    private weak var scrollCutEditor: CutEditor?
    func scroll(with event: ScrollEvent) -> Bool {
        if event.sendType == .begin {
            isScrollTrack = abs(event.scrollDeltaPoint.x) < abs(event.scrollDeltaPoint.y)
        }
        if isScrollTrack {
            if event.sendType == .begin {
                scrollCutEditor = editCutEditor
            }
            scrollCutEditor?.scrollTrack(with: event)
        } else {
            scrollTime(with: event)
        }
        return true
    }
    
    func scrollTime(with event: ScrollEvent) {
        if event.scrollMomentumType == nil {
            //snapScroll
        }
        let maxX = self.x(withTime: scene.duration)
        let x = (scrollPoint.x - event.scrollDeltaPoint.x).clip(min: 0, max: maxX)
        scrollPoint = CGPoint(x: event.sendType == .begin ?
            self.x(withTime: time(withLocalX: x)) : x, y: 0)
        scrollHandler?(self, scrollPoint, event)
    }
    
    func zoom(with event: PinchEvent) -> Bool {
        zoom(at: point(from: event)) {
            baseWidth = (baseWidth * (event.magnification * 2.5 + 1))
                .clip(min: 1, max: Timeline.defautBaseWidth)
        }
        return true
    }
    func resetView(with event: DoubleTapEvent) -> Bool {
        guard baseWidth != Timeline.defautBaseWidth else {
            return false
        }
        zoom(at: point(from: event)) {
            baseWidth = Timeline.defautBaseWidth
        }
        return true
    }
    func zoom(at p: CGPoint, handler: () -> ()) {
        handler()
        _scrollPoint.x = x(withTime: time)
        _intervalScrollPoint.x = scrollPoint.x
        updateView(isCut: false, isTransform: false, isKeyframe: false)
    }
}

final class Ruler: Layer, Respondable {
    static let name = Localization(english: "Ruler", japanese: "目盛り")
    var labels = [Label]() {
        didSet {
            replace(children: labels)
        }
    }
}

final class KnobsEditor: Layer, Respondable {
    static let name = Localization(english: "Knobs Editor", japanese: "ノブエディタ")
    
    override init() {
        linesLayer.lineWidth = 1
        linesLayer.lineColor = .content
        super.init()
    }
    
    private var konbs = [DiscreteKnob]()
    private var linesLayer = PathLayer()
    var knobSize = CGSize(width: 5, height: 6)
    var positions = [CGPoint]() {
        didSet {
            var knobs = [DiscreteKnob](), path = CGMutablePath()
            positions.forEach {
//                path.move(to: CGPoint(x: $0.x, y: bounds.minY))
//                path.addLine(to: CGPoint(x: $0.x, y: bounds.maxY))
                let knob = DiscreteKnob(CGSize(width: knobSize.width,
                                               height: knobSize.height), lineWidth: 1)
                knob.frame.origin = CGPoint(x: $0.x - knobSize.width / 2,
                                            y: $0.y - knobSize.height / 2)
                knobs.append(knob)
            }
            self.konbs = knobs
            linesLayer.path = path
            replace(children: [linesLayer] + knobs)
        }
    }
}
