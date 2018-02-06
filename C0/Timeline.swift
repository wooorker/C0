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
 - Bar設定
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
            editCutEditor.isEdit = true
            baseTimeInterval = scene.baseTimeInterval
            tempoSlider.value = scene.tempoTrack.tempoItem.tempo.cf
            tempoAnimationEditor.animation = scene.tempoTrack.animation
            updateWith(time: scene.time, scrollPoint: _scrollPoint)
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
    
    var editedKeyframeTime = Beat(0) {
        didSet {
            if editedKeyframeTime != oldValue {
                timeLabel.localization = Localization(Timeline.timeString(atTime: editedKeyframeTime))
            }
        }
    }
    private static func timeString(atTime time: Beat) -> String {
        let i = time.integralPart
        return i == 0 ? "\(time) b" : (time.isInteger ? "\(i) b" : "\(i) + \(time - Beat(i)) b")
    }
    
    static let defautBaseWidth = 6.0.cf, defaultTimeHeight = 24.0.cf
    static let defaultSumKeyTimesHeight = 18.0.cf
    var baseWidth = defautBaseWidth {
        didSet {
            sumKeyTimesEditor.baseWidth = baseWidth
            tempoAnimationEditor.baseWidth = baseWidth
            cutEditors.forEach { $0.baseWidth = baseWidth }
        }
    }
    private let timeHeight = defaultTimeHeight
    private let timeRulerHeight = 14.0.cf, tempoHeight = defaultTimeHeight
    private let sumKeyTimesHeight = defaultSumKeyTimesHeight
    private let knobHalfHeight = 8.0.cf, subKnobHalfHeight = 4.0.cf, maxLineHeight = 3.0.cf
    private(set) var maxScrollX = 0.0.cf
    
    static let leftWidth = 80.0.cf
    let timeRuler = Ruler()
    let timeLabel = Label(text: Localization("0 b"), font: .small)
    let tempoSlider = NumberSlider(frame: CGRect(x: 0, y: 0,
                                                 width: leftWidth, height: Layout.basicHeight),
                                   defaultValue: 120, min: 1, max: 10000, unit: " bpm",
                                   description: Localization(english: "Tempo", japanese: "テンポ"))
    let tempoAnimationEditor = AnimationEditor()
    let tempoEditor = GroupResponder()
    let nodeTreeEditor = NodeTreeEditor()
    let cutEditorsEditor = GroupResponder()
    let sumKeyTimesEditor = AnimationEditor(height: defaultSumKeyTimesHeight)
    let sumKeyTimesCliper = GroupResponder()
    let timeLayer: Layer = {
        let layer = Layer()
        layer.fillColor = .editing
        layer.lineColor = nil
        return layer
    } ()
    let timeBindingLineLayer: PathLayer = {
        let layer = PathLayer()
        layer.lineWidth = 5
        layer.lineColor = .border
        return layer
    } ()
    let nodeBindingLineLayer: PathLayer = {
        let layer = PathLayer()
        layer.lineWidth = 5
        layer.lineColor = .border
        return layer
    } ()
    enum BindingKeyframeType {
        case tempo, cut
    }
    var bindingKeyframeType = BindingKeyframeType.cut
    
    let beatsLayer = PathLayer()
    
    let keyframeEditor = KeyframeEditor(), nodeEditor = NodeEditor()
    
    init(frame: CGRect = CGRect(), description: Localization = Localization()) {
        cutEditorHeight = frame.height - timeRulerHeight - tempoHeight - sumKeyTimesHeight
        tempoEditor.replace(children: [tempoAnimationEditor])
        tempoEditor.isClipped = true
        tempoAnimationEditor.smallHeight = tempoHeight
        cutEditorsEditor.isClipped = true
        sumKeyTimesCliper.isClipped = true
        sumKeyTimesEditor.isEdit = true
        sumKeyTimesEditor.smallHeight = sumKeyTimesHeight
        sumKeyTimesCliper.append(child: sumKeyTimesEditor)
        timeRuler.isClipped = true
        beatsLayer.isClipped = true
        beatsLayer.fillColor = .subContent
        beatsLayer.lineColor = nil
        
        super.init()
        instanceDescription = description
        replace(children: [timeLayer, timeLabel, beatsLayer, sumKeyTimesCliper, timeRuler,
                           tempoEditor, tempoSlider,
                           nodeTreeEditor, cutEditorsEditor])
        if !frame.isEmpty {
            self.frame = frame
        }
        
        tempoEditor.moveHandler = { [unowned self] in
            if ($1.sendType == .begin &&
                self.tempoAnimationEditor.frame.maxX <= $0.point(from: $1).x) ||
                $1.sendType != .begin {
                
                return self.tempoAnimationEditor.move(with: $1)
            } else {
                return false
            }
        }
//        cutEditorsEditor.moveHandler = { [unowned self] in
//            if let lastEditor = self.cutEditors.last {
//                if ($1.sendType == .begin && lastEditor.frame.maxX <= $0.point(from: $1).x) ||
//                    $1.sendType != .begin {
//
//                    return lastEditor.animationEditor.move(with: $1)
//                }
//            }
//            return false
//        }
        
        tempoEditor.bindHandler = { [unowned self] _, _ in
            return self.bindKeyframe(bindingKeyframeType: .tempo)
        }
        cutEditorsEditor.bindHandler = { [unowned self] _, _ in
            return self.bindKeyframe(bindingKeyframeType: .cut)
        }
        
        sumKeyTimesEditor.slideHandler = { [unowned self] in
            self.setAnimations(with: $0)
        }
        
        nodeTreeEditor.setNodesHandler = { [unowned self] in
            self.setNodes(with: $0)
        }
        nodeTreeEditor.nodesEditor.deleteHandler = { [unowned self] _, _ in
            self.remove(self.editCutEditor.cutItem.cut.editNode, in: self.editCutEditor)
            return true
        }
        nodeTreeEditor.nodesEditor.pasteHandler = { [unowned self] in
            return self.pasteFromNodesEditor($1, with: $2)
        }
        
        nodeTreeEditor.setTracksHandler = { [unowned self] in
            self.setNodeTracks(with: $0)
        }
        nodeTreeEditor.tracksEditor.deleteHandler = { [unowned self] _, _ in
            let node = self.editCutEditor.cutItem.cut.editNode
            self.remove(trackIndex: node.editTrackIndex, in: node, in: self.editCutEditor)
            return true
        }
        nodeTreeEditor.tracksEditor.pasteHandler = { [unowned self] in
            return self.pasteFromTracksEditor($1, with: $2)
        }
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let sp = Layout.smallPadding
        cutEditorHeight = bounds.height - timeRulerHeight - tempoHeight - sumKeyTimesHeight - sp * 6
        let midX = bounds.midX, leftWidth = Timeline.leftWidth
        let rightX = leftWidth
        timeRuler.frame = CGRect(x: rightX, y: bounds.height - timeRulerHeight - sp,
                                 width: bounds.width - rightX - sp, height: timeRulerHeight)
        timeLabel.frame.origin = CGPoint(x: sp * 2, y: bounds.height - timeRulerHeight)
        tempoSlider.frame = CGRect(x: sp,
                                   y: bounds.height - timeRulerHeight - tempoHeight - sp * 3,
                                   width: leftWidth - sp, height: tempoHeight + sp * 2)
        tempoEditor.frame = CGRect(x: rightX,
                                   y: bounds.height - timeRulerHeight - tempoHeight - sp * 3,
                                   width: bounds.width - rightX - sp, height: tempoHeight + sp * 2)
        nodeTreeEditor.frame = CGRect(x: sp, y: sumKeyTimesHeight + sp,
                                      width: leftWidth - sp, height: cutEditorHeight + sp * 2)
        cutEditorsEditor.frame = CGRect(x: rightX, y: sumKeyTimesHeight + sp,
                                        width: bounds.width - rightX - sp,
                                        height: cutEditorHeight + sp * 2)
        sumKeyTimesCliper.frame = CGRect(x: rightX, y: sp,
                                          width: bounds.width - rightX - sp, height: sumKeyTimesHeight)
        timeLayer.frame = CGRect(x: midX - baseWidth / 2, y: 0,
                                 width: baseWidth, height: bounds.height)
        beatsLayer.frame = CGRect(x: rightX, y: 0,
                                  width: bounds.width - rightX, height: bounds.height)
    }
    
    private var _scrollPoint = CGPoint(), _intervalScrollPoint = CGPoint()
    var scrollPoint: CGPoint {
        get {
            return _scrollPoint
        }
        set {
            let newTime = time(withLocalX: newValue.x)
            if newTime != time {
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
            editCutEditor.isEdit = false
            self.editCutItemIndex = cvi.index
            editCutEditor.isEdit = true
        }
        editCutEditor.update(withTime: cvi.interTime)
        updateWithScrollPosition()
        updateView(isCut: true, isTransform: true, isKeyframe: true)
    }
    var updateViewHandler: (((isCut: Bool, isTransform: Bool, isKeyframe: Bool)) -> ())?
    private func updateView(isCut: Bool, isTransform: Bool, isKeyframe: Bool) {
        if isKeyframe {
            updateKeyframeEditor()
            let cutItem = scene.editCutItem
            let animation = cutItem.cut.editNode.editTrack.animation
            let t = cutItem.cut.time >= animation.duration ?
                animation.duration : animation.editKeyframe.time
            editedKeyframeTime = cutItem.time + t
            tempoSlider.value = scene.tempoTrack.tempoItem.tempo.cf
        }
        if isCut {
            nodeTreeEditor.cut = scene.editCutItem.cut
            nodeEditor.node = scene.editCutItem.cut.editNode
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
    
    func updateBindingLine() {
        let y: CGFloat
        switch bindingKeyframeType {
        case .tempo:
            y = tempoEditor.frame.midY + frame.minY
            timeBindingLineLayer.lineColor = .warning
        case .cut:
            y = cutEditorsEditor.frame.midY + frame.minY
            timeBindingLineLayer.lineColor = .border
        }
        let timeBindingPath = CGMutablePath()
        timeBindingPath.move(to: CGPoint(x: frame.maxX, y: y))
        timeBindingPath.addLine(to: CGPoint(x: keyframeEditor.frame.minX, y: y))
        timeBindingLineLayer.path = timeBindingPath
    }
    
    var editCutEditor: CutEditor {
        return cutEditors[scene.editCutItemIndex]
    }
    var cutEditors = [CutEditor]() {
        didSet {
            cutEditorsEditor.replace(children: cutEditors.reversed())
            updateCutEditorPositions()
        }
    }
    private func updateWithScrollPosition() {
        let minX = localDeltaX
        _ = cutEditors.reduce(minX) { x, cutEditor in
            cutEditor.frame.origin = CGPoint(x: x, y: Layout.smallPadding)
            return x + cutEditor.frame.width
        }
        tempoAnimationEditor.frame.origin = CGPoint(x: minX, y: Layout.smallPadding)
        sumKeyTimesEditor.frame.origin.x = minX
        updateBeats()
        updateTimeRuler()
    }
    func updateCutEditorPositions() {
        maxScrollX = scene.cutItems.reduce(0.0.cf) { $0 + self.x(withTime: $1.cut.duration) }
        let minX = localDeltaX
        _ = cutEditors.reduce(minX) { x, cutEditor in
            cutEditor.frame.origin = CGPoint(x: x, y: Layout.smallPadding)
            return x + cutEditor.frame.width
        }
        tempoAnimationEditor.frame.origin = CGPoint(x: minX, y: Layout.smallPadding)
        updateBeats()
        updateTimeRuler()
        updateSubKeyTimesEditor()
    }
    var cutEditorHeight = 0.0.cf
    func cutEditors(with scene: Scene) -> [CutEditor] {
        return scene.cutItems.map { self.cutEditor(with: $0, height: cutEditorHeight) }
    }
    func cutEditor(with cutItem: CutItem, height: CGFloat) -> CutEditor {
        let cutEditor = CutEditor(cutItem,
                                  baseWidth: baseWidth, baseTimeInterval: baseTimeInterval,
                                  knobHalfHeight: knobHalfHeight,
                                  subKnobHalfHeight: subKnobHalfHeight,
                                  maxLineWidth: maxLineHeight, height: height)
        
        cutEditor.animationEditors.enumerated().forEach { (i, animationEditor) in
            let nodeAndTrack = cutEditor.nodeAndTrack(atNodeAndTrackIndex: i)
            
            animationEditor.setKeyframeHandler = { [unowned self, unowned cutEditor] in
                guard $0.type == .end else {
                    return
                }
                switch $0.setType {
                case .insert:
                    self.insert($0.keyframe, at: $0.index, in: nodeAndTrack.track,
                                in: $0.animationEditor, in: cutEditor)
                case .remove:
                    self.removeKeyframe(at: $0.index,
                                        in: nodeAndTrack.track,
                                        in: $0.animationEditor, in: cutEditor, time: self.time)
                case .replace:
                    self.replace($0.keyframe, at: $0.index,
                                 in: nodeAndTrack.track,
                                 in: $0.animationEditor, in: cutEditor, time: self.time)
                }
            }
            animationEditor.slideHandler = { [unowned self, unowned cutEditor] in
                self.setAnimation(with: $0, in: nodeAndTrack.track, in: cutEditor)
            }
            animationEditor.selectHandler = { [unowned self, unowned cutEditor] in
                self.setAnimation(with: $0, in: nodeAndTrack.track, in: cutEditor)
            }
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
            if cutEditor.cutItem.cut == self.nodeTreeEditor.cut {
                self.nodeTreeEditor.updateWithNodes()
                self.setTrackAndNodeBinding?(self, cutEditor, obj.nodeAndTrack)
            }
        }
        return cutEditor
    }
    var setTrackAndNodeBinding: ((Timeline, CutEditor, CutEditor.NodeAndTrack) -> ())?
    
    func updateTimeRuler() {
//        let minTime = time(withLocalX: convertToLocalX(bounds.minX + Timeline.leftWidth))
//        let maxTime = time(withLocalX: convertToLocalX(bounds.maxX))
//        let minSecond = Int(floor(scene.secondTime(withBeatTime: minTime)))
//        let maxSecond = Int(ceil(scene.secondTime(withBeatTime: maxTime)))
//        guard minSecond < maxSecond else {
//            return
//        }
//        timeRuler.scrollPosition.x = localDeltaX
//        timeRuler.labels = (minSecond ... maxSecond).map {
//            let timeLabel = Timeline.timeLabel(withSecound: $0)
//            timeLabel.fillColor = nil
//            let secondX = x(withTime: scene.beatTime(withSecondTime: Second($0)))
//            timeLabel.frame.origin = CGPoint(x: secondX - timeLabel.frame.width / 2,
//                                             y: Layout.smallPadding)
//            return timeLabel
//        }
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
        var keyframeDics = [Beat: Keyframe]()
        func updateKeyframesWith(time: Beat, _ label: Keyframe.Label) {
            if keyframeDics[time] != nil {
                if label == .main {
                    keyframeDics[time]?.label = .main
                }
            } else {
                var newKeyframe = Keyframe()
                newKeyframe.time = time
                newKeyframe.label = label
                keyframeDics[time] = newKeyframe
            }
        }
        scene.tempoTrack.animation.keyframes.forEach { updateKeyframesWith(time: $0.time, $0.label) }
        scene.cutItems.forEach { cutItem in
            let cut = cutItem.cut
            cut.rootNode.allChildren({ node in
                for track in node.tracks {
                    track.animation.keyframes.forEach {
                        updateKeyframesWith(time: $0.time + cutItem.time, $0.label)
                    }
                    let maxTime = track.animation.duration + cutItem.time
                    updateKeyframesWith(time: maxTime, Keyframe.Label.main)
                }
            })
        }
        var keyframes = keyframeDics.values.sorted(by: { $0.time < $1.time })
        guard let lastTime = keyframes.last?.time else {
            sumKeyTimesEditor.animation = Animation()
            return
        }
        keyframes.removeLast()
        
        var animation = sumKeyTimesEditor.animation
        animation.keyframes = keyframes
        animation.duration = lastTime
        sumKeyTimesEditor.animation = animation
        
        
//        var keyTimes = [Beat](), keyframes = [Keyframe]()
//        func updateKeyframesWith(time: Beat, _ label: Keyframe.Label) {
//            if let i = keyTimes.index(of: time) {
//                if label == .main {
//                    keyframes[i].label = .main
//                }
//            } else {
//                keyTimes.append(time)
//                var newKeyframe = Keyframe()
//                newKeyframe.time = time
//                newKeyframe.label = label
//                keyframes.append(newKeyframe)
//            }
//        }
//        scene.tempoTrack.animation.keyframes.forEach { updateKeyframesWith(time: $0.time, $0.label) }
//        scene.cutItems.forEach { cutItem in
//            let cut = cutItem.cut
//            cut.rootNode.allChildren({ node in
//                for track in node.tracks {
//                    track.animation.keyframes.forEach {
//                        updateKeyframesWith(time: $0.time + cutItem.time, $0.label)
//                    }
//                    let maxTime = track.animation.duration + cutItem.time
//                    updateKeyframesWith(time: maxTime, Keyframe.Label.main)
//                }
//            })
//        }
//        guard let lastTime = keyTimes.last else {
//            sumKeyTimesEditor.animation = Animation()
//            return
//        }
//        keyTimes.removeLast()
//
//        var animation = sumKeyTimesEditor.animation
//        animation.keyframes = keyframes.sorted(by: { $0.time < $1.time })
//        animation.duration = lastTime
//        sumKeyTimesEditor.animation = animation
    }
    
    let beatsLineWidth = 1.0.cf, barLineWidth = 3.0.cf, beatsPerBar = 0
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
            let w = beatsPerBar != 0 && $0 % beatsPerBar == 0 ? barLineWidth : beatsLineWidth
            return CGRect(x: i0x - w / 2, y: 0, width: w, height: bounds.height)
        }
        path.addRects(rects)
        beatsLayer.path = path
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
    func cutIndex(withTime time: Beat) -> Int {
        return scene.cutItemIndex(withTime: time).index
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
    
    var baseTimeInterval = Beat(1, 16) {
        didSet {
            sumKeyTimesEditor.baseTimeInterval = baseTimeInterval
            tempoAnimationEditor.baseTimeInterval = baseTimeInterval
            cutEditors.forEach { $0.baseTimeInterval = baseTimeInterval }
            updateCutEditorPositions()
        }
    }
    
    var sceneDataModel: DataModel?
    var cutsDataModel: DataModel?
    
    private func registerUndo(time: Beat, _ handler: @escaping (Timeline, Beat) -> Void) {
        undoManager?.registerUndo(withTarget: self) { [oldTime = self.time] in
            handler($0, oldTime)
        }
        self.time = time
    }
    
    func bindKeyframe(bindingKeyframeType: BindingKeyframeType) -> Bool {
        if bindingKeyframeType != self.bindingKeyframeType {
            set(bindingKeyframeType, time: time)
        }
        return true
    }
    private func set(_ bindingKeyframeType: BindingKeyframeType, time: Beat) {
        registerUndo(time: time) { [ob = self.bindingKeyframeType] in $0.set(ob, time: $1) }
        self.bindingKeyframeType = bindingKeyframeType
        updateKeyframeEditor()
        updateBindingLine()
    }
    private func updateKeyframeEditor() {
        switch bindingKeyframeType {
        case .tempo:
            keyframeEditor.keyframe = tempoAnimationEditor.animation.editKeyframe
        case .cut:
            keyframeEditor.keyframe = scene.editCutItem.cut.editNode.editTrack.animation.editKeyframe
        }
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
        if scene.editCutItemIndex == cutEditors.count - 1 {
            scene.editCutItemIndex = cutEditors.count - 2
        }
        cutEditors.remove(at: index)
        
        updateCutEditorPositions()
    }
    
    var newNodeName: String {
        var minIndex: Int?
        scene.editCutItem.cut.rootNode.allChildren { node in
            if let i = node.name.suffixNumber {
                if let minI = minIndex {
                    if i > minI {
                        minIndex = i
                    }
                } else {
                    minIndex = 0
                }
            }
        }
        let index = minIndex != nil ? minIndex! + 1 : 0
        return Localization(english: "Node \(index)", japanese: "ノード\(index)")
            .currentString
    }
    func newNode() -> Bool {
        let node = Node(name: newNodeName)
        node.editTrack.name = Localization(english: "Track 0", japanese: "トラック0").currentString
        return append(node, in: editCutEditor)
    }
    func pasteFromNodesEditor(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        for object in copiedObject.objects {
            if let node = object as? Node {
                return append(node, in: editCutEditor)
            }
        }
        return false
    }
    func append(_ node: Node, in cutEditor: CutEditor) -> Bool {
        guard let parent = cutEditor.cutItem.cut.editNode.parent,
            let index = parent.children.index(of: cutEditor.cutItem.cut.editNode) else {
                return false
        }
        insert(node, at: index + 1, parent: parent, in: cutEditor, time: time)
        set(editNode: node, in: cutEditor, time: time)
        return true
    }
    func remove(_ node: Node, in cutEditor: CutEditor) {
        guard let parent = node.parent else {
            return
        }
        let index = parent.children.index(of: node)!
        removeNode(at: index, parent: parent, in: cutEditor, time: time)
        if parent.children.count == 0 {
            let newNode = Node(name: newNodeName)
            insert(newNode, at: 0, parent: parent, in: cutEditor, time: time)
            set(editNode: newNode, in: cutEditor, time: time)
        } else {
            set(editNode: parent.children[index > 0 ? index - 1 : index], in: cutEditor, time: time)
        }
    }
    func insert(_ node: Node, at index: Int, parent: Node, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) { $0.removeNode(at: index, parent: parent, in: cutEditor, time: $1) }
        parent.children.insert(node, at: index)
        cutEditor.cutItem.cutDataModel.isWrite = true
        cutEditor.updateChildren()
        updateView(isCut: true, isTransform: false, isKeyframe: false)
        if cutEditor.cutItem.cut == nodeTreeEditor.cut {
            nodeTreeEditor.updateWithNodes()
        }
    }
    func removeNode(at index: Int, parent: Node, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) { [on = parent.children[index]] in
            $0.insert(on, at: index, parent: parent, in: cutEditor, time: $1)
        }
        parent.children.remove(at: index)
        cutEditor.cutItem.cutDataModel.isWrite = true
        cutEditor.updateChildren()
        updateView(isCut: true, isTransform: false, isKeyframe: false)
        if cutEditor.cutItem.cut == nodeTreeEditor.cut {
            nodeTreeEditor.updateWithNodes()
        }
    }
    func set(editNode node: Node, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) { [on = cutEditor.cutItem.cut.editNode] in
            $0.set(editNode: on, in: cutEditor, time: $1)
        }
        cutEditor.cutItem.cut.editNode = node
        cutEditor.cutItem.cutDataModel.isWrite = true
        cutEditor.updateChildren()
        updateView(isCut: true, isTransform: false, isKeyframe: false)
        if cutEditor.cutItem.cut == nodeTreeEditor.cut {
            nodeTreeEditor.updateWithNodes()
        }
    }
    
    func newNodeTrackName(with node: Node) -> String {
        var minIndex: Int?
        node.tracks.forEach { track in
            if let i = track.name.suffixNumber {
                if let minI = minIndex {
                    if i > minI {
                        minIndex = i
                    }
                } else {
                    minIndex = 0
                }
            }
        }
        let index = minIndex != nil ? minIndex! + 1 : 0
        return Localization(english: "Track \(index)", japanese: "トラック\(index)")
            .currentString
    }
    func newNodeTrack() {
        let cutEditor = cutEditors[scene.editCutItemIndex]
        let node = cutEditor.cutItem.cut.editNode
        let track = NodeTrack(name: newNodeTrackName(with: node))
        let trackIndex = node.editTrackIndex + 1
        insert(track, at: trackIndex, in: node, in: cutEditor, time: time)
        set(editTrackIndex: trackIndex, oldEditTrackIndex: node.editTrackIndex,
            in: node, in: cutEditor, time: time)
    }
    func pasteFromTracksEditor(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        for object in copiedObject.objects {
            if let track = object as? NodeTrack {
                return append(track, in: editCutEditor)
            }
        }
        return false
    }
    func append(_ track: NodeTrack, in cutEditor: CutEditor) -> Bool {
        let node = cutEditor.cutItem.cut.editNode
        let index = node.editTrackIndex
        insert(track, at: index + 1, in: node, in: cutEditor, time: time)
        set(editTrackIndex: index + 1, oldEditTrackIndex: node.editTrackIndex,
            in: node, in: cutEditor, time: time)
        return true
    }
    func remove(trackIndex: Int, in node: Node, in cutEditor: CutEditor) {
        removeTrack(at: trackIndex, in: node, in: cutEditor, time: time)
        if node.tracks.count == 0 {
            let newTrack = NodeTrack(name: newNodeTrackName(with: node))
            insert(newTrack, at: 0, in: node, in: cutEditor, time: time)
            set(editTrackIndex: 0, oldEditTrackIndex: node.editTrackIndex,
                in: node, in: cutEditor, time: time)
        } else {
            let newIndex = trackIndex > 0 ? trackIndex - 1 : trackIndex
            set(editTrackIndex: newIndex, oldEditTrackIndex: node.editTrackIndex,
                in: node, in: cutEditor, time: time)
        }
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
        cutEditor.updateChildren()
        updateView(isCut: true, isTransform: false, isKeyframe: false)
        if cutEditor.cutItem.cut == nodeTreeEditor.cut {
            nodeTreeEditor.updateWithTracks()
        }
    }
    func removeTrack(at index: Int, in node: Node, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) { [ot = node.tracks[index]] in
            $0.insert(ot, at: index, in: node, in: cutEditor, time: $1)
        }
        node.tracks.remove(at: index)
        cutEditor.cutItem.cutDataModel.isWrite = true
        cutEditor.updateChildren()
        updateView(isCut: true, isTransform: false, isKeyframe: false)
        if cutEditor.cutItem.cut == nodeTreeEditor.cut {
            nodeTreeEditor.updateWithTracks()
        }
    }
    private func set(editTrackIndex: Int, oldEditTrackIndex: Int,
                     in node: Node, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) {
            $0.set(editTrackIndex: oldEditTrackIndex,
                   oldEditTrackIndex: editTrackIndex, in: node, in: cutEditor, time: $1)
        }
        node.editTrackIndex = editTrackIndex
        cutEditor.cutItem.cutDataModel.isWrite = true
        cutEditor.updateChildren()
        updateView(isCut: true, isTransform: true, isKeyframe: true)
        if cutEditor.cutItem.cut == nodeTreeEditor.cut {
            nodeTreeEditor.updateWithTracks()
        }
    }
    
    private func set(_ editNodeAndTrack: CutEditor.NodeAndTrack,
                     old oldEditNodeAndTrack: CutEditor.NodeAndTrack,
                     in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldEditNodeAndTrack, old: editNodeAndTrack, in: cutEditor, time: $1)
        }
        cutEditor.editNodeAndTrack = editNodeAndTrack
        cutEditor.cutItem.cutDataModel.isWrite = true
        if cutEditor.cutItem.cut == nodeTreeEditor.cut {
            nodeTreeEditor.updateWithNodes()
            setTrackAndNodeBinding?(self, cutEditor, editNodeAndTrack)
        }
    }
    
    private var moveAnimationEditors = [(animationEditor: AnimationEditor, keyframeIndex: Int?)]()
    private func setAnimations(with obj: AnimationEditor.SlideBinding) {
        switch obj.type {
        case .begin:
            let cutEditor = self.cutEditors[cutIndex(withTime: obj.oldTime)]
            
            let time = obj.oldTime - cutEditor.cutItem.time
            moveAnimationEditors = []
            cutEditor.animationEditors.forEach {
                moveAnimationEditors.append(($0, $0.index(atTime: time)))
            }
            moveAnimationEditors.append((tempoAnimationEditor,
                                         tempoAnimationEditor.index(atTime: obj.oldTime)))
            
            moveAnimationEditors.forEach {
                _ = $0.animationEditor.move(withDeltaTime: obj.deltaTime,
                                            keyframeIndex: $0.keyframeIndex, sendType: obj.type)
            }
        case .sending:
            moveAnimationEditors.forEach {
                _ = $0.animationEditor.move(withDeltaTime: obj.deltaTime,
                                            keyframeIndex: $0.keyframeIndex, sendType: obj.type)
            }
        case .end:
            moveAnimationEditors.forEach {
                _ = $0.animationEditor.move(withDeltaTime: obj.deltaTime,
                                            keyframeIndex: $0.keyframeIndex, sendType: obj.type)
            }
            moveAnimationEditors = []
        }
    }
    
    private var oldTempoTrack: TempoTrack?
    private func setAnimationInTempoTrack(with obj: AnimationEditor.SlideBinding) {
        switch obj.type {
        case .begin:
            oldTempoTrack = scene.tempoTrack
        case .sending:
            guard let oldTrack = oldTempoTrack else {
                return
            }
            oldTrack.replace(obj.animation.keyframes)
        case .end:
            guard let oldTrack = oldTempoTrack else {
                return
            }
            if obj.animation != obj.oldAnimation {
                registerUndo(time: time) { [sceneDataModel] in
                    $0.set(obj.oldAnimation, old: obj.animation,
                           in: oldTrack, in: sceneDataModel, time: $1)
                }
            }
            self.oldTempoTrack = nil
        }
        updateView(isCut: false, isTransform: false, isKeyframe: true)
    }
    private func setAnimationInTempoTrack(with obj: AnimationEditor.SelectBinding) {
        switch obj.type {
        case .begin:
            oldTempoTrack = scene.tempoTrack
        case .sending:
            break
        case .end:
            guard let oldTrack = oldTempoTrack else {
                return
            }
            if obj.animation != obj.oldAnimation {
                registerUndo(time: time) { [sceneDataModel] in
                    $0.set(obj.oldAnimation, old: obj.animation,
                           in: oldTrack, in: sceneDataModel, time: $1)
                }
            }
            self.oldTempoTrack = nil
        }
    }
    private func set(_ animation: Animation, old oldAnimation: Animation,
                     in track: TempoTrack, in sceneDataModel: DataModel?, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldAnimation, old: animation, in: track, in: sceneDataModel, time: $1)
        }
        track.replace(animation.keyframes, duration: animation.duration)
        sceneDataModel?.isWrite = true
        updateTimeRuler()
    }
    func insert(_ keyframe: Keyframe, at index: Int,
                in track: TempoTrack) {
        let keyframeValue = track.currentItemValues
        insert(keyframe, keyframeValue,
               at: index, in: track, in: sceneDataModel, time: time)
    }
    private func replace(_ keyframe: Keyframe, at index: Int,
                         in track: TempoTrack, in sceneDataModel: DataModel?, time: Beat) {
        registerUndo(time: time) { [ok = track.animation.keyframes[index]] in
            $0.replace(ok, at: index, in: track, in: sceneDataModel, time: $1)
        }
        track.replace(keyframe, at: index)
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        sceneDataModel?.isWrite = true
        updateView(isCut: false, isTransform: false, isKeyframe: true)
    }
    private func insert(_ keyframe: Keyframe,
                        _ keyframeValue: TempoTrack.KeyframeValues,
                        at index: Int,
                        in track: TempoTrack, in sceneDataModel: DataModel?, time: Beat) {
        registerUndo(time: time) {
            $0.removeKeyframe(at: index, in: track, in: sceneDataModel, time: $1)
        }
        track.insert(keyframe, keyframeValue, at: index)
        sceneDataModel?.isWrite = true
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        updateView(isCut: false, isTransform: false, isKeyframe: true)
    }
    private func removeKeyframe(at index: Int,
                                in track: TempoTrack, in sceneDataModel: DataModel?, time: Beat) {
        registerUndo(time: time) {
            [ok = track.animation.keyframes[index],
            okv = track.keyframeItemValues(at: index)] in
            
            $0.insert(ok, okv, at: index, in: track, in: sceneDataModel, time: $1)
        }
        track.removeKeyframe(at: index)
        sceneDataModel?.isWrite = true
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    
    private func setAnimation(with obj: AnimationEditor.SlideBinding,
                              in track: NodeTrack, in cutEditor: CutEditor) {
        switch obj.type {
        case .begin:
            break
        case .sending:
            track.replace(obj.animation.keyframes, duration: obj.animation.duration)
            updateCutDuration(with: cutEditor)
        case .end:
            if obj.animation != obj.oldAnimation {
                registerUndo(time: time) {
                    $0.set(obj.oldAnimation, old: obj.animation,
                           in: track, in: obj.animationEditor, in: cutEditor, time: $1)
                }
            }
            updateCutDuration(with: cutEditor)
        }
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    private func setAnimation(with obj: AnimationEditor.SelectBinding,
                              in track: NodeTrack, in cutEditor: CutEditor) {
        switch obj.type {
        case .begin:
            break
        case .sending:
            break
        case .end:
            if obj.animation != obj.oldAnimation {
                registerUndo(time: time) {
                    $0.set(obj.oldAnimation, old: obj.animation,
                           in: track, in: obj.animationEditor, in: cutEditor, time: $1)
                }
            }
        }
    }
    private func set(_ animation: Animation, old oldAnimation: Animation,
                     in track: NodeTrack,
                     in animationEditor: AnimationEditor, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldAnimation, old: animation, in: track,
                   in: animationEditor, in: cutEditor, time: $1)
        }
        track.replace(animation.keyframes, duration: animation.duration)
        cutEditor.cutItem.cutDataModel.isWrite = true
        animationEditor.animation = track.animation
    }
    func insert(_ keyframe: Keyframe, at index: Int,
                in track: NodeTrack,
                in animationEditor: AnimationEditor, in cutEditor: CutEditor, isSplitDrawing: Bool = false) {
        var keyframeValue = track.currentItemValues
        keyframeValue.drawing = isSplitDrawing ? keyframeValue.drawing.copied : Drawing()
        insert(keyframe, keyframeValue, at: index, in: track,
               in: animationEditor, in: cutEditor, time: time)
    }
    private func replace(_ keyframe: Keyframe, at index: Int,
                         in track: NodeTrack,
                         in animationEditor: AnimationEditor, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) { [ok = track.animation.keyframes[index]] in
            $0.replace(ok, at: index, in: track, in: animationEditor, in: cutEditor, time: $1)
        }
        track.replace(keyframe, at: index)
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        cutEditor.cutItem.cutDataModel.isWrite = true
        animationEditor.animation = track.animation
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    private func insert(_ keyframe: Keyframe,
                        _ keyframeValue: NodeTrack.KeyframeValues,
                        at index: Int,
                        in track: NodeTrack,
                        in animationEditor: AnimationEditor, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) { $0.removeKeyframe(at: index, in: track,
                                                     in: animationEditor, in: cutEditor, time: $1) }
        track.insert(keyframe, keyframeValue, at: index)
        cutEditor.cutItem.cutDataModel.isWrite = true
        animationEditor.animation = track.animation
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    private func removeKeyframe(at index: Int,
                                in track: NodeTrack,
                                in animationEditor: AnimationEditor, in cutEditor: CutEditor,
                                time: Beat) {
        registerUndo(time: time) {
            [ok = track.animation.keyframes[index],
            okv = track.keyframeItemValues(at: index)] in
            
            $0.insert(ok, okv, at: index, in: track, in: animationEditor, in: cutEditor, time: $1)
        }
        track.removeKeyframe(at: index)
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        cutEditor.cutItem.cutDataModel.isWrite = true
        animationEditor.animation = track.animation
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    
    func updateCutDuration(with cutEditor: CutEditor) {
        cutEditor.cutItem.cut.duration = cutEditor.cutItem.cut.maxDuration
        cutEditor.updateWithDuration()
        cutEditor.cutItem.cutDataModel.isWrite = true
        scene.updateCutTimeAndDuration()
        tempoAnimationEditor.animation.duration = scene.duration
        cutEditors.forEach { $0.updateWithCutTime() }
        updateCutEditorPositions()
        setSceneDurationHandler?(self, scene.duration)
    }
    
    private var oldCutEditor: CutEditor?
    
    private func setNodes(with obj: NodeTreeEditor.NodesBinding) {
        switch obj.type {
        case .begin:
            oldCutEditor = editCutEditor
        case .sending:
            guard let cutEditor = oldCutEditor else {
                return
            }
            obj.inNode.children = obj.nodes
            if cutEditor.cutItem.cut == obj.nodeTreeEditor.cut {
                obj.nodeTreeEditor.updateWithMovedNodes()
            }
            cutEditor.updateChildren()
        case .end:
            guard let cutEditor = oldCutEditor else {
                return
            }
            if obj.nodes != obj.oldNodes {
                set(obj.nodes, old: obj.oldNodes,
                    in: obj.inNode, in: cutEditor, time: time)
            } else {
                obj.inNode.children = obj.oldNodes
                if cutEditor.cutItem.cut == obj.nodeTreeEditor.cut {
                    obj.nodeTreeEditor.updateWithMovedNodes()
                }
                cutEditor.updateChildren()
            }
            self.oldCutEditor = nil
        }
    }
    private func set(_ nodes: [Node], old oldNodes: [Node],
                     in node: Node, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) { $0.set(oldNodes, old: nodes, in: node, in: cutEditor, time: $1) }
        node.children = nodes
        cutEditor.cutItem.cutDataModel.isWrite = true
        if cutEditor.cutItem.cut == nodeTreeEditor.cut {
            nodeTreeEditor.updateWithNodes()
        }
        cutEditor.updateChildren()
    }
    
    private func setNodeTracks(with obj: NodeTreeEditor.NodeTracksBinding) {
        switch obj.type {
        case .begin:
            oldCutEditor = editCutEditor
        case .sending:
            guard let cutEditor = oldCutEditor else {
                return
            }
            obj.inNode.tracks = obj.tracks
            obj.inNode.editTrackIndex = obj.index
            if cutEditor.cutItem.cut == obj.nodeTreeEditor.cut {
                obj.nodeTreeEditor.updateWithMovedTracks()
            }
            cutEditor.updateChildren()
        case .end:
            guard let cutEditor = oldCutEditor else {
                return
            }
            if obj.tracks != obj.oldTracks {
                set(obj.tracks, old: obj.oldTracks,
                    in: obj.inNode, in: cutEditor, time: time)
                set(editTrackIndex: obj.index, oldEditTrackIndex: obj.oldIndex,
                    in: obj.inNode, in: cutEditor, time: time)
            } else {
                obj.inNode.tracks = obj.oldTracks
                obj.inNode.editTrackIndex = obj.oldIndex
                if cutEditor.cutItem.cut == obj.nodeTreeEditor.cut {
                    obj.nodeTreeEditor.updateWithMovedTracks()
                }
                cutEditor.updateChildren()
            }
            self.oldCutEditor = nil
        }
    }
    private func set(_ tracks: [NodeTrack], old oldTracks: [NodeTrack],
                     in node: Node, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) { $0.set(oldTracks, old: tracks, in: node, in: cutEditor, time: $1) }
        node.tracks = tracks
        cutEditor.cutItem.cutDataModel.isWrite = true
        if cutEditor.cutItem.cut == nodeTreeEditor.cut {
            nodeTreeEditor.updateWithTracks()
        }
        cutEditor.updateChildren()
    }
    
    var setSceneDurationHandler: ((Timeline, Beat) -> ())?
    
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
            // snapScroll
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
    
    private let scroller: Layer = {
        let layer = Layer()
        layer.lineColor = nil
        return layer
    } ()
    
    override init() {
        super.init()
        append(child: scroller)
    }
    
    var scrollPosition: CGPoint {
        get  {
            return scroller.frame.origin
        }
        set {
            scroller.frame.origin = newValue
        }
    }
//    var scrollFrame: CGRect {
//
//    }
    
    var labels = [Label]() {
        didSet {
            scroller.replace(children: labels)
        }
    }
}
