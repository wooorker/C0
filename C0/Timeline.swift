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
 タイムラインにキーフレーム・プロパティを統合
 アニメーション描画（表示が離散的な1フレーム単位または1アニメーション単位のため）
 カット分割設計（カットもキーフレームのように分割するように設計）
 最終キーフレームの時間編集問題
 */

import Foundation
import QuartzCore

final class NodeEditor: LayerRespondable, PulldownButtonDelegate {
    static let name = Localization(english: "Node track Editor", japanese: "キーフレームエディタ")
    
    weak var sceneEditor: SceneEditor!
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    let isHiddenButton = PulldownButton(
        names: [
            Localization(english: "Hidden", japanese: "表示なし"),
            Localization(english: "Shown", japanese: "表示あり")
        ]
    )
    let layer = CALayer.interfaceLayer(backgroundColor: .background)
    init() {
        layer.frame = CGRect(
            x: 0, y: 0,
            width: 100 + Layout.basicPadding * 2,
            height: Layout.basicHeight * 3 + Layout.basicPadding * 2
        )
        isHiddenButton.frame = CGRect(
            x: Layout.basicPadding, y: Layout.basicHeight * 2 + Layout.basicPadding,
            width: 100,
            height: Layout.basicHeight
        )
        isHiddenButton.delegate = self
        children = [isHiddenButton]
        update(withChildren: children, oldChildren: [])
    }
    func changeValue(_ pulldownButton: PulldownButton, index: Int, oldIndex: Int, type: Action.SendType) {
        sceneEditor.scene.editCutItem.cut.editNode.isHidden = index == 0
        sceneEditor.canvas.setNeedsDisplay()
        sceneEditor.timeline.setNeedsDisplay()
    }
}

final class KeyframeEditor: LayerRespondable, EasingEditorDelegate, PulldownButtonDelegate {
    static let name = Localization(english: "Keyframe Editor", japanese: "キーフレームエディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    weak var sceneEditor: SceneEditor!
    
    static let easingHeight = 80.0.cf, buttonWidth = 90.0.cf
    let easingEditor = EasingEditor(
        frame: CGRect(
            x: Layout.basicPadding, y: Layout.basicPadding,
            width: buttonWidth * 3, height: easingHeight
        ),
        description: Localization(
            english: "Easing Editor for Keyframe",
            japanese: "キーフレーム用イージングエディタ"
        )
    )
    let interpolationButton = PulldownButton(
        frame: CGRect(
            x: Layout.basicPadding, y: Layout.basicPadding + easingHeight,
            width: buttonWidth, height: Layout.basicHeight
        ),
        names: [
            Localization(english: "Spline", japanese: "スプライン"),
            Localization(english: "Bound", japanese: "バウンド"),
            Localization(english: "Linear", japanese: "リニア"),
            Localization(english: "Step", japanese: "補間なし")
        ],
        description: Localization(
            english: "\"Bound\": Uses \"Spline\" without interpolation on previous, Not previous and next: Use \"Linear\"",
            japanese: "バウンド: 前方側の補間をしないスプライン補間, 前後が足りない場合: リニア補間を使用"
        )
    )
    let loopButton = PulldownButton(
        frame: CGRect(
            x: Layout.basicPadding + buttonWidth, y: Layout.basicPadding + easingHeight,
            width: buttonWidth, height: Layout.basicHeight
        ),
        names: [
            Localization(english: "No Loop", japanese: "ループなし"),
            Localization(english: "Began Loop", japanese: "ループ開始"),
            Localization(english: "Ended Loop", japanese: "ループ終了")
        ],
        description: Localization(
            english: "Loop from  \"Began Loop\" keyframe to \"Ended Loop\" keyframe on \"Ended Loop\" keyframe",
            japanese: "「ループ開始」キーフレームから「ループ終了」キーフレームの間を「ループ終了」キーフレーム上でループ"
        )
    )
    let labelButton = PulldownButton(
        frame: CGRect(
            x: Layout.basicPadding + buttonWidth * 2, y: Layout.basicPadding + easingHeight,
            width: buttonWidth, height: Layout.basicHeight
        ),
        names: [
            Localization(english: "Main Label", japanese: "メインラベル"),
            Localization(english: "Sub Label", japanese: "サブラベル ")
        ]
    )
    let layer = CALayer.interfaceLayer(backgroundColor: .background)
    init() {
        layer.frame = CGRect(
            x: 0, y: 0,
            width: KeyframeEditor.buttonWidth * 3 + Layout.basicPadding * 2,
            height: Layout.basicHeight + KeyframeEditor.easingHeight + Layout.basicPadding * 2
        )
        easingEditor.delegate = self
        interpolationButton.delegate = self
        loopButton.delegate = self
        labelButton.delegate = self
        children = [easingEditor, interpolationButton, loopButton, labelButton]
        update(withChildren: children, oldChildren: [])
    }
    
    var keyframe = Keyframe() {
        didSet {
            if !keyframe.equalOption(other: oldValue) {
                updateChildren()
            }
        }
    }
    func update() {
        keyframe = sceneEditor.scene.editCutItem.cut.editNode.editTrack.animation.editKeyframe
    }
    private func updateChildren() {
        labelButton.selectionIndex = KeyframeEditor.labelIndex(with: keyframe.label)
        loopButton.selectionIndex = KeyframeEditor.loopIndex(with: keyframe.loop)
        interpolationButton.selectionIndex = KeyframeEditor.interpolationIndex(with: keyframe.interpolation)
        easingEditor.easing = keyframe.easing
    }
    
    static func interpolationIndex(with interpolation: Keyframe.Interpolation) -> Int {
        return Int(interpolation.rawValue)
    }
    static func interpolation(at index: Int) -> Keyframe.Interpolation {
        return Keyframe.Interpolation(rawValue: Int8(index)) ?? .spline
    }
    static func loopIndex(with loop: Loop) -> Int {
        if !loop.isStart && !loop.isEnd {
            return 0
        } else if loop.isStart {
            return 1
        } else {
            return 2
        }
    }
    static func loop(at index: Int) -> Loop {
        switch index {
        case 0:
            return Loop(isStart: false, isEnd: false)
        case 1:
            return Loop(isStart: true, isEnd: false)
        default:
            return Loop(isStart: false, isEnd: true)
        }
    }
    static func labelIndex(with label: Keyframe.Label) -> Int {
        return Int(label.rawValue)
    }
    static func label(at index: Int) -> Keyframe.Label {
        return Keyframe.Label(rawValue: Int8(index)) ?? .main
    }
    
    private func registerUndo(_ handler: @escaping (KeyframeEditor, Beat) -> Void) {
        undoManager?.registerUndo(withTarget: self) { [oldTime = sceneEditor.timeline.time] in handler($0, oldTime) }
    }
    
    struct EditKeyframe {
        let keyframe: Keyframe, index: Int, animation: Animation, cutItem: CutItem
    }
    var editKeyframeHandler: ((Void) -> (EditKeyframe))? = nil
    var editKeyframe: EditKeyframe?
    func changeEasing(_ easingEditor: EasingEditor, easing: Easing, oldEasing: Easing, type: Action.SendType) {
        switch type {
        case .begin:
            editKeyframe = editKeyframeHandler?()
        case .sending:
            if let editKeyframe = editKeyframe {
                let keyframe = editKeyframe.keyframe.with(easing)
                setKeyframe(keyframe, at: editKeyframe.index, animation: editKeyframe.animation)
            }
        case .end:
            if let editKeyframe = editKeyframe {
                let keyframe = editKeyframe.keyframe.with(easing)
                setEasing(keyframe, oldKeyframe: editKeyframe.keyframe, at: editKeyframe.index, animation: editKeyframe.animation, cutItem: editKeyframe.cutItem)
                self.editKeyframe = nil
            }
        }
    }
    func changeValue(_ pulldownButton: PulldownButton, index: Int, oldIndex: Int, type: Action.SendType) {
        switch pulldownButton {
        case interpolationButton:
            switch type {
            case .begin:
                editKeyframe = editKeyframeHandler?()
            case .sending:
                if let editKeyframe = editKeyframe {
                    let keyframe = editKeyframe.keyframe.with(KeyframeEditor.interpolation(at: index))
                    setKeyframe(keyframe, at: editKeyframe.index, animation: editKeyframe.animation)
                }
            case .end:
                if let editKeyframe = editKeyframe {
                    let keyframe = editKeyframe.keyframe.with(KeyframeEditor.interpolation(at: index))
                    setInterpolation(keyframe, oldKeyframe: editKeyframe.keyframe, at: editKeyframe.index, animation: editKeyframe.animation, cutItem: editKeyframe.cutItem)
                    self.editKeyframe = nil
                }
            }
        case loopButton:
            switch type {
            case .begin:
                editKeyframe = editKeyframeHandler?()
            case .sending:
                if let editKeyframe = editKeyframe {
                    let keyframe = editKeyframe.keyframe.with(KeyframeEditor.loop(at: index))
                    setKeyframe(keyframe, at: editKeyframe.index, animation: editKeyframe.animation)
                }
            case .end:
                if let editKeyframe = editKeyframe {
                    let keyframe = editKeyframe.keyframe.with(KeyframeEditor.loop(at: index))
                    setLoop(keyframe, oldKeyframe: editKeyframe.keyframe, at: editKeyframe.index, animation: editKeyframe.animation, cutItem: editKeyframe.cutItem)
                    self.editKeyframe = nil
                }
            }
        case labelButton:
            switch type {
            case .begin:
                editKeyframe = editKeyframeHandler?()
            case .sending:
                if let editKeyframe = editKeyframe {
                    let keyframe = editKeyframe.keyframe.with(KeyframeEditor.label(at: index))
                    setKeyframe(keyframe, at: editKeyframe.index, animation: editKeyframe.animation)
                }
            case .end:
                if let editKeyframe = editKeyframe {
                    let keyframe = editKeyframe.keyframe.with(KeyframeEditor.label(at: index))
                    setLabel(keyframe, oldKeyframe: editKeyframe.keyframe, at: editKeyframe.index, animation: editKeyframe.animation, cutItem: editKeyframe.cutItem)
                    self.editKeyframe = nil
                }
            }
        default:
            break
        }
    }
    private func setEasing(_ keyframe: Keyframe, oldKeyframe: Keyframe, at i: Int, animation: Animation, cutItem: CutItem) {
        undoManager?.registerUndo(withTarget: self) {
            $0.setEasing(oldKeyframe, oldKeyframe: keyframe, at: i, animation: animation, cutItem: cutItem)
        }
        setKeyframe(keyframe, at: i, animation: animation)
        easingEditor.easing = keyframe.easing
        cutItem.cutDataModel.isWrite = true
    }
    private func setInterpolation(_ keyframe: Keyframe, oldKeyframe: Keyframe, at i: Int, animation: Animation, cutItem: CutItem) {
        undoManager?.registerUndo(withTarget: self) {
            $0.setInterpolation(oldKeyframe, oldKeyframe: keyframe, at: i, animation: animation, cutItem: cutItem)
        }
        setKeyframe(keyframe, at: i, animation: animation)
        interpolationButton.selectionIndex = KeyframeEditor.interpolationIndex(with: keyframe.interpolation)
        cutItem.cutDataModel.isWrite = true
    }
    private func setLoop(_ keyframe: Keyframe, oldKeyframe: Keyframe, at i: Int, animation: Animation, cutItem: CutItem) {
        undoManager?.registerUndo(withTarget: self) {
            $0.setLoop(oldKeyframe, oldKeyframe: keyframe, at: i, animation: animation, cutItem: cutItem)
        }
        setKeyframe(keyframe, at: i, animation: animation)
        loopButton.selectionIndex = KeyframeEditor.loopIndex(with: keyframe.loop)
        cutItem.cutDataModel.isWrite = true
    }
    private func setLabel(_ keyframe: Keyframe, oldKeyframe: Keyframe, at i: Int, animation: Animation, cutItem: CutItem) {
        undoManager?.registerUndo(withTarget: self) {
            $0.setLabel(oldKeyframe, oldKeyframe: keyframe, at: i, animation: animation, cutItem: cutItem)
        }
        setKeyframe(keyframe, at: i, animation: animation)
        labelButton.selectionIndex = KeyframeEditor.labelIndex(with: keyframe.label)
        cutItem.cutDataModel.isWrite = true
    }
    func setKeyframe(_ keyframe: Keyframe, at i: Int, animation: Animation) {
        animation.replaceKeyframe(keyframe, at: i)
        update()
        sceneEditor.timeline.setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
    }
}

final class Timeline: LayerRespondable, Localizable {
    static let name = Localization(english: "Timeline", japanese: "タイムライン")
    static let feature = Localization(
        english: "Select time: Left and right scroll\nSelect animation: Up and down scroll",
        japanese: "時間選択: 左右スクロール\nグループ選択: 上下スクロール"
    )
    var instanceDescription: Localization
    var valueDescription: Localization {
        return Localization(
            english: "Max Time: \(scene.timeLength)\nCuts Count: \(scene.cutItems.count)",
            japanese: "最大時間: \(scene.timeLength)\nカットの数: \(scene.cutItems.count)"
        )
    }
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var locale = Locale.current {
        didSet {
            panel.allChildren { ($0 as? Localizable)?.locale = locale }
        }
    }
    
    weak var sceneEditor: SceneEditor!
    
    var layer: CALayer {
        return drawLayer
    }
    let drawLayer: DrawLayer
    init(frame: CGRect = CGRect(), backgroundColor: Color = .background, description: Localization = Localization()) {
        self.drawLayer = DrawLayer(backgroundColor: backgroundColor)
        self.instanceDescription = description
        drawLayer.frame = frame
        drawLayer.drawBlock = { [unowned self] ctx in
            self.draw(in: ctx)
        }
    }
    
    var cursor: Cursor {
        return moveQuasimode ? .upDown : .arrow
    }
    
    var contentsScale: CGFloat {
        get {
            return layer.contentsScale
        }
        set {
            layer.contentsScale = newValue
            panel.allChildren { $0.contentsScale = newValue }
        }
    }
    
    var scene = Scene() {
        didSet {
            _scrollPoint.x = x(withTime: scene.time)
            _intervalScrollPoint.x = x(withTime: time(withLocalX: _scrollPoint.x))
            setNeedsDisplay()
        }
    }
    var indicationTime = 0
    var editCutItemIndex: Int {
        get {
            return scene.editCutItemIndex
        } set {
            scene.editCutItemIndex = newValue
            sceneEditor.canvas.cutItem = scene.editCutItem
            keyframeEditor.update()
            sceneEditor.transformEditor.update()
            setNeedsDisplay()
        }
    }
    static let defaultFrameRateWidth = 6.0.cf, defaultTimeHeight = 18.0.cf
    var editFrameRateWidth = Timeline.defaultFrameRateWidth
    var timeHeight = defaultTimeHeight
    var timeDivisionHeight = 10.0.cf
    var tempoHeight = 18.0.cf
    private(set) var maxScrollX = 0.0.cf
    func updateCanvassPosition() {
        maxScrollX = scene.cutItems.reduce(0.0.cf) { $0 + x(withTime: $1.cut.timeLength) }
        setNeedsDisplay()
    }
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
        } set {
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
            sceneEditor.sceneDataModel.isWrite = true
        }
        let cvi = scene.cutItemIndex(withTime: time)
        if alwaysUpdateCutIndex || scene.editCutItemIndex != cvi.index {
            self.editCutItemIndex = cvi.index
            scene.editCutItem.cut.time = cvi.interTime
        } else {
            scene.editCutItem.cut.time = cvi.interTime
        }
        updateView()
    }
    private func updateView() {
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
        keyframeEditor.update()
        sceneEditor.transformEditor.update()
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
        return CGRect(x: _scrollPoint.x, y: 0, width: x(withTime: scene.timeLength), height: 0)
    }
    
    func time(withLocalX x: CGFloat, isBased: Bool = true) -> Beat {
        return isBased ?
            scene.baseTimeInterval * Beat(Int(round(x / editFrameRateWidth))) :
            scene.basedBeatTime(withDoubleBeatTime: DoubleBeat(x / editFrameRateWidth) * DoubleBeat(scene.baseTimeInterval))
    }
    func x(withTime time: Beat) -> CGFloat {
        return scene.doubleBeatTime(withBeatTime: time / scene.baseTimeInterval).cf * editFrameRateWidth
    }
    func doubleBeatTime(withLocalX x: CGFloat, isBased: Bool = true) -> DoubleBeat {
        return DoubleBeat(isBased ? round(x / editFrameRateWidth) : x / editFrameRateWidth) * DoubleBeat(scene.baseTimeInterval)
    }
    func x(withDoubleBeatTime doubleBeatTime: DoubleBeat) -> CGFloat {
        return CGFloat(doubleBeatTime * DoubleBeat(scene.baseTimeInterval.inversed!)) * editFrameRateWidth
    }
    func doubleBaseTime(withLocalX x: CGFloat) -> DoubleBaseTime {
        return DoubleBaseTime(x / editFrameRateWidth)
    }
    func localX(withDoubleBaseTime doubleBaseTime: DoubleBaseTime) -> CGFloat {
        return CGFloat(doubleBaseTime) * editFrameRateWidth
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
            let x = self.x(withTime: ct + cut.timeLength)
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
    func animationIndexTuple(at p: CGPoint) -> (cutIndex: Int, animationIndex: Int, keyframeIndex: Int?) {
        let ci = cutIndex(withLocalX: p.x)
        let cut = scene.cutItems[ci].cut, ct = scene.cutItems[ci].time
        var minD = CGFloat.infinity, minKeyframeIndex = 0, minAnimationIndex = 0
        for (ii, track) in cut.editNode.tracks.enumerated() {
            for (i, k) in track.animation.keyframes.enumerated() {
                let x = self.x(withTime: ct + k.time)
                let d = abs(p.x - x)
                if d < minD {
                    minAnimationIndex = ii
                    minKeyframeIndex = i
                    minD = d
                }
            }
        }
        let x = self.x(withTime: ct + cut.timeLength)
        let d = abs(p.x - x)
        if d < minD {
            return (ci, minAnimationIndex, nil)
        } else if minKeyframeIndex == 0 && ci > 0 {
            return (ci - 1, minAnimationIndex, nil)
        } else {
            return (ci,  minAnimationIndex, minKeyframeIndex)
        }
    }
    
    func setNeedsDisplay() {
        layer.setNeedsDisplay()
    }
    func draw(in ctx: CGContext) {
        ctx.translateBy(x: bounds.width / 2 - editFrameRateWidth / 2 - _intervalScrollPoint.x, y: 0)
        drawTime(in: ctx)
        drawCuts(in: ctx)
        drawTimeBar(in: ctx)
    }
    func drawCuts(in ctx: CGContext) {
        ctx.saveGState()
        let b = ctx.boundingBoxOfClipPath
        let ch = bounds.height - timeDivisionHeight - tempoHeight - Layout.basicPadding
        let midY = round(ch / 2) + Layout.basicPadding
        var x = 0.0.cf
        for (i, cutItem) in scene.cutItems.enumerated() {
            let w = self.x(withTime: cutItem.cut.timeLength)
            if b.minX <= x + w && b.maxX >= x {
                let index = cutItem.cut.editNode.editTrackIndex, h = 1.0.cf
                let cutBounds = CGRect(x: editFrameRateWidth / 2, y: Layout.basicPadding, width: w, height: bounds.height - timeDivisionHeight - tempoHeight - Layout.basicPadding)
                let clipBounds = CGRect(x: cutBounds.minX + 1, y: timeHeight + Layout.basicPadding, width: cutBounds.width - 2, height: cutBounds.height - timeHeight * 2)
                if index == 0 {
                    drawAllAnimationKnob(cutItem.cut, y: midY, maxY: clipBounds.maxY, in: ctx)
                } else {
                    var y = ch / 2 + knobHalfHeight
                    for _ in (0 ... index).reversed() {
                        y += 1 + h
                        if y >= clipBounds.maxY {
                            y = clipBounds.maxY
                            break
                        }
                    }
                    drawAllAnimationKnob(cutItem.cut, y: y, maxY: clipBounds.maxY, in: ctx)
                }
                
                ctx.setFillColor(Color.translucentEdit.cgColor)
                ctx.fill(CGRect(x: clipBounds.minX, y: midY - 4, width: clipBounds.width, height: 8))
                
                ctx.setLineWidth(0.5)
                ctx.setStrokeColor(Color.border.cgColor)
                ctx.stroke(cutBounds.inset(by: 0.25))
                ctx.stroke(clipBounds.inset(by: 0.25))
                var y = midY + knobHalfHeight + 2
                for i in (0 ..< index).reversed() {
                    drawNoSelected(with: cutItem.cut.editNode.tracks[i], width: w, y: y, h: h, in: ctx)
                    y += 2 + h
                    if y >= clipBounds.maxY {
                        break
                    }
                }
                y = midY - knobHalfHeight - 2
                if index + 1 < cutItem.cut.editNode.tracks.count {
                    for i in index + 1 ..< cutItem.cut.editNode.tracks.count {
                        drawNoSelected(with: cutItem.cut.editNode.tracks[i], width: w, y: y - h, h:h, in: ctx)
                        y -= 2 + h
                        if y <= clipBounds.minY {
                            break
                        }
                    }
                }
                draw(with: cutItem.cut.editNode.editTrack, with: cutItem.cut.editNode, cut: cutItem.cut, y: midY, isOther: false, in: ctx)
                drawCutIndex(cutItem, index: i, in: ctx)
            }
            ctx.translateBy(x: w, y: 0)
            x += w
        }
        ctx.restoreGState()
        
        drawKnob(
            from: CGPoint(x: x, y: midY),
            fillColor: Color.knob, lineColor: Color.border, interpolation: .spline, label: .main, in: ctx
        )
    }
    func cutKnobBounds(with cut: Cut) -> CGRect {
        return CGRect(
            x: x(withTime: cut.timeLength), y: timeHeight + 2,
            width: editFrameRateWidth, height: bounds.height - timeHeight * 2 - 2 * 2
        )
    }
    
    func cutLabelString(with cutItem: CutItem, at index: Int) -> String {
        let node = cutItem.cut.editNode
        let indexPath = node.indexPath
        var string = Localization(english: "Node", japanese: "ノード").currentString
        indexPath.forEach { string += "\($0)." }
        string += Localization(english: "Track", japanese: "トラック").currentString + "\(node.editTrackIndex)"
        return "\(index): \(string)"
    }
    func drawCutIndex(_ cutItem: CutItem, index: Int, in ctx: CGContext) {
        let textFrame = TextFrame(
            string: cutLabelString(with: cutItem, at: index), font: .division, color: .locked
        )
        let sb = textFrame.typographicBounds, inBounds = ctx.boundingBoxOfClipPath.insetBy(dx: Layout.basicPadding, dy: 0)
        let w = x(withTime: cutItem.cut.timeLength)
        var textBounds = CGRect(
            x: Layout.basicPadding + sb.origin.x + editFrameRateWidth / 2,
            y: bounds.height - timeDivisionHeight - tempoHeight - timeHeight + (timeHeight - sb.height) / 2 + sb.origin.y,
            width: sb.width, height: sb.height
        )
        if textBounds.minX < inBounds.minX {
            if inBounds.minX + textBounds.width > w {
                textBounds.origin.x = w - textBounds.width
            } else {
                textBounds.origin.x = inBounds.minX
            }
        }
        if textBounds.maxX > inBounds.maxX {
            let d = Layout.basicPadding + editFrameRateWidth / 2
            if inBounds.maxX - textBounds.width - d < 0 {
                textBounds.origin.x = d
            } else {
                textBounds.origin.x = d + inBounds.maxX - textBounds.width
            }
        }
        textFrame.draw(in: textBounds.integral, in: ctx)
    }
    private let knobHalfHeight = 8.0.cf, subKnobHalfHeight = 4.0.cf, easingHeight = 3.0.cf
    func draw(with track: NodeTrack, with node: Node, cut: Cut, y: CGFloat, isOther: Bool, in ctx: CGContext) {
        let lineColor = track.transformItem != nil ? Color.camera : Color.content
        let knobFillColor = Color.knob
        let knobLineColor = track.transformItem != nil ?
            Color.camera.multiply(white: 0.5) : Color.border
        let animation = track.animation
        
        let startIndex = animation.selectionKeyframeIndexes.first ?? animation.keyframes.count - 1
        let endIndex = animation.selectionKeyframeIndexes.last ?? 0
        for (i, lki) in animation.loopedKeyframeIndexes.enumerated() {
            let keyframe = animation.keyframes[lki.index]
            let time = lki.time
            let nextTime = i + 1 >= animation.loopedKeyframeIndexes.count ?
                cut.timeLength : animation.loopedKeyframeIndexes[i + 1].time
            let x = self.x(withTime: time)
            let nextX = self.x(withTime: nextTime)
            let timeLength = nextTime - time, width = nextX - x
            if time >= animation.timeLength {
                continue
            }
            let isClipDrawKeyframe = nextTime > animation.timeLength
            if isClipDrawKeyframe {
                ctx.saveGState()
                let nx = min(nextX,  self.x(withTime: cut.timeLength) - editFrameRateWidth / 2)
                ctx.clip(to: CGRect(x: x, y: y - timeHeight / 2, width: nx - x, height: timeHeight))
            }
            let lw = isOther ? 1.0.cf : 2.0.cf
            
            let pLine = TextFrame(
                string: "\(timeLength.p)", font: .division, color: .locked
            )
            let psb = pLine.typographicBounds
            let pBounds = CGRect(
                x: (x + nextX) / 2 + (editFrameRateWidth - psb.width) / 2 + psb.origin.x,
                y: y,
                width: psb.width, height: psb.height
            )
            pLine.draw(in: pBounds.integral, in: ctx)
            
            let qLine = TextFrame(
                string: "\(timeLength.q)", font: .division, color: .locked
            )
            let qsb = qLine.typographicBounds
            let qBounds = CGRect(
                x: (x + nextX) / 2 + (editFrameRateWidth - qsb.width) / 2 + qsb.origin.x,
                y: y - qsb.height,
                width: qsb.width, height: qsb.height
            )
            qLine.draw(in: qBounds.integral, in: ctx)
            
            
            if timeLength > scene.baseTimeInterval {
                if !keyframe.easing.isLinear && !isOther {
                    let b = keyframe.easing.bezier, bw = width, bx = x + editFrameRateWidth / 2, count = Int(width / 5.0)
                    let d = 1 / count.cf
                    let points: [CGPoint] = (0 ... count).map { i in
                        let dx = d * i.cf
                        let dp = b.difference(withT: dx)
                        let dy = max(0.5, min(easingHeight, (dp.x == dp.y ? .pi / 2 : 2 * atan2(dp.y, dp.x)) / (.pi / 2)))
                        return CGPoint(x: dx * bw + bx, y: dy)
                    }
                    if lki.loopCount > 0 {
                        for i in 0 ..< lki.loopCount {
                            let dt = i.cf * 2
                            let ps = points.map { CGPoint(x: $0.x, y: y + $0.y + dt) } + points.reversed().map { CGPoint(x: $0.x, y: y - $0.y - dt) }
                            ctx.addLines(between: ps)
                        }
                        ctx.setLineWidth(1.0)
                        ctx.setStrokeColor(lineColor.cgColor)
                        ctx.strokePath()
                    } else {
                        let ps = points.map { CGPoint(x: $0.x, y: y + $0.y) } + points.reversed().map { CGPoint(x: $0.x, y: y - $0.y) }
                        ctx.addLines(between: ps)
                        ctx.setFillColor(lineColor.cgColor)
                        ctx.fillPath()
                    }
                } else {
                    if lki.loopCount > 0 {
                        for i in 0 ..< lki.loopCount {
                            let dt = (i + 1).cf * 2 - 0.5
                            ctx.move(to: CGPoint(x: x + editFrameRateWidth / 2, y: y - dt))
                            ctx.addLine(to: CGPoint(x: nextX + editFrameRateWidth / 2, y: y - dt))
                            ctx.move(to: CGPoint(x: x + editFrameRateWidth / 2, y: y + dt))
                            ctx.addLine(to: CGPoint(x: nextX + editFrameRateWidth / 2.0, y: y + dt))
                        }
                        ctx.setLineWidth(lw / 2)
                    } else {
                        ctx.move(to: CGPoint(x: x + editFrameRateWidth / 2, y: y))
                        ctx.addLine(to: CGPoint(x: nextX + editFrameRateWidth / 2, y: y))
                        ctx.setLineWidth(lw)
                    }
                    ctx.setStrokeColor(lineColor.cgColor)
                    ctx.strokePath()
                }
            }
            
            let knobColor = lki.loopingCount > 0 ?
                Color.edit :
                (track.drawingItem.keyDrawings[i].roughLines.isEmpty ? knobFillColor : Color.timelineRough)
            
            drawKnob(
                from: CGPoint(x: x, y: y),
                fillColor: knobColor, lineColor: knobLineColor, interpolation: keyframe.interpolation, label: keyframe.label, in: ctx
            )
            drawSelection: do {
                if animation.selectionKeyframeIndexes.contains(i) {
                    ctx.setFillColor(Color.select.cgColor)
                    let kh = knobHalfHeight
                    ctx.fill(CGRect(x: x, y: y - kh, width: width, height: kh * 2))
                } else if i >= startIndex && i < endIndex {
                    ctx.setFillColor(Color.select.cgColor)
                    let kh = knobHalfHeight, h = 2.0.cf
                    ctx.fill(CGRect(x: x, y: y - kh, width: width, height: h))
                    ctx.fill(CGRect(x: x, y: y + kh - h, width: width, height: h))
                }
            }
            
            if isClipDrawKeyframe {
                ctx.restoreGState()
            }
        }
    }
    func drawNoSelected(with track: NodeTrack, width: CGFloat, y: CGFloat, h: CGFloat, in ctx: CGContext) {
        let lineColor = track.isHidden ?
            (track.transformItem != nil ? Color.camera.multiply(white: 0.75) : Color.background) :
            (track.transformItem != nil ? Color.camera.multiply(white: 0.5) : Color.content)
//        let keyColor = track.isHidden ?
//            (track.transformItem != nil ? Color.camera.multiply(white: 0.5) : Color.edit) :
//            (track.transformItem != nil ? Color.camera : Color.content)
        let animation = track.animation
        
        ctx.setFillColor(lineColor.cgColor)
        ctx.fill(CGRect(x: editFrameRateWidth / 2 + 1, y: y, width: width - 2, height: h))
//        ctx.setFillColor(keyColor.cgColor)
        for (i, keyframe) in animation.keyframes.enumerated() {
            if i > 0 {
                ctx.fill(CGRect(x: x(withTime: keyframe.time), y: y - 1, width: editFrameRateWidth, height: h + 2))
            }
        }
    }
    func drawAllAnimationKnob(_ cut: Cut, y: CGFloat, maxY: CGFloat, in ctx: CGContext) {
        if cut.editNode.tracks.count > 1 {
            for track in cut.editNode.tracks {
                for (i, keyframe) in track.animation.keyframes.enumerated() {
                    if i > 0 {
                        let x = self.x(withTime: keyframe.time) + editFrameRateWidth / 2
                        
                        ctx.setLineWidth(1)
                        ctx.setStrokeColor(Color.edit.cgColor)
                        ctx.move(to: CGPoint(x: x, y: timeHeight / 2))
                        ctx.addLine(to: CGPoint(x: x, y: min(y, maxY)))
                        ctx.strokePath()
                        
                        ctx.setLineWidth(1)
                        ctx.setFillColor(Color.knob.cgColor)
                        ctx.setStrokeColor(Color.border.cgColor)
                        ctx.addRect(
                            CGRect(
                                x: x - editFrameRateWidth / 2, y: Layout.basicPadding + timeHeight / 2 - 3,
                                width: editFrameRateWidth, height: 6
                                ).inset(by: 0.5)
                        )
                        ctx.drawPath(using: .fillStroke)
                    }
                }
            }
        }
    }
    
    var timeTexts = [Text]()
    func updateTimeTexts() {
        
    }
    
    var viewPadding = 4.0.cf
    func drawTime(in ctx: CGContext) {
        let bounds = ctx.boundingBoxOfClipPath
        let minTime = time(withLocalX: bounds.minX), maxTime = time(withLocalX: bounds.maxX)
        let minSecond = Int(floor(scene.secondTime(withBeatTime: minTime)))
        let maxSecond = Int(ceil(scene.secondTime(withBeatTime: maxTime)))
        guard minSecond < maxSecond else {
            return
        }
        for i in minSecond ... maxSecond {
            let minute = i / 60
            let second = i - minute * 60
            let string = second < 0 ?
                String(format: "-%d:%02d", minute, -second) : String(format: "%d:%02d", minute, second)
            
            let textLine = TextFrame(
                string: string, font: .division, color: .locked
            )
            let sb = textLine.pathBounds
            let textBounds = CGRect(
                x: x(withTime: scene.beatTime(withSecondTime: Second(i))) + (editFrameRateWidth - sb.width) / 2 + sb.origin.x,
                y: bounds.height - sb.height - 2 + sb.origin.y,
                width: sb.width, height: sb.height
            )
            textLine.draw(in: textBounds.integral, in: ctx)
        }
        
        let textLine = TextFrame(string: "\(scene.tempo) bpm", font: .division, color: .locked)
        let sb = textLine.pathBounds
        let textBounds = CGRect(
            x: self.x(withTime: time) + (editFrameRateWidth - sb.width) / 2 + sb.origin.x,
            y: bounds.height - sb.height * 2 - 2 + sb.origin.y,
            width: sb.width, height: sb.height
        )
        textLine.draw(in: textBounds.integral, in: ctx)
        
        let intMinTime = floor(minTime).integralPart
        let intMaxTime = ceil(maxTime).integralPart
        guard intMinTime < intMaxTime else {
            return
        }
        (intMinTime ... intMaxTime).forEach {
            let i0x = x(withDoubleBeatTime: DoubleBeat($0))
            ctx.setFillColor(Color.locked.multiply(alpha: 0.05).cgColor)
            ctx.fill(CGRect(x: i0x,
                            y: Layout.basicPadding,
                            width: editFrameRateWidth,
                            height: bounds.height - timeHeight))
        }
    }
    func drawTimeBar(in ctx: CGContext) {
        let x = self.x(withTime: time)
        ctx.setFillColor(Color.translucentEdit.cgColor)
        ctx.fill(CGRect(x: x, y: 0, width: editFrameRateWidth, height: bounds.height))
        
        let secondTime = scene.secondTime
        if secondTime.frame != 0 {
        }
    }
    func drawKnob(from p: CGPoint, fillColor: Color, lineColor: Color, interpolation: Keyframe.Interpolation, label: Keyframe.Label, in ctx: CGContext) {
        let kh = label == .main ? knobHalfHeight : subKnobHalfHeight
        ctx.setLineWidth(1)
        ctx.setFillColor(fillColor.cgColor)
        ctx.setStrokeColor(lineColor.cgColor)
        let rect = CGRect(x: p.x, y: p.y - kh, width: editFrameRateWidth, height: kh * 2).inset(by: 0.5)
        switch interpolation {
        case .spline:
            ctx.move(to: CGPoint(x: rect.minX, y: (rect.midY + rect.minY) / 2))
            ctx.addLine(to: CGPoint(x: rect.minX, y: (rect.midY + rect.maxY) / 2))
            ctx.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            ctx.addLine(to: CGPoint(x: rect.maxX, y: (rect.midY + rect.maxY) / 2))
            ctx.addLine(to: CGPoint(x: rect.maxX, y: (rect.midY + rect.minY) / 2))
            ctx.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            ctx.closePath()
        case .bound:
            ctx.move(to: CGPoint(x: rect.minX, y: (rect.midY + rect.minY) / 2))
            ctx.addLine(to: CGPoint(x: rect.minX, y: (rect.midY + rect.maxY) / 2))
            ctx.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            ctx.addLine(to: CGPoint(x: rect.maxX, y: (rect.midY + rect.maxY) / 2))
            ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            ctx.closePath()
        case .linear:
            ctx.move(to: CGPoint(x: rect.minX, y: (rect.midY + rect.minY) / 2))
            ctx.addLine(to: CGPoint(x: rect.minX, y: (rect.midY + rect.maxY) / 2))
            ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            ctx.closePath()
        case .none:
            ctx.addRect(rect)
        }
        ctx.drawPath(using: .fillStroke)
    }
    
    private func registerUndo(_ handler: @escaping (Timeline, Beat) -> Void) {
        undoManager?.registerUndo(withTarget: self) { [oldTime = time] in handler($0, oldTime) }
    }
    
    func copy(with event: KeyInputEvent) -> CopiedObject {
        let index = cutIndex(withLocalX: convertToLocal(point(from: event)).x)
        let cut = scene.cutItems[index].cut
        return CopiedObject(objects: [cut.deepCopy])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        for object in copiedObject.objects {
            if let cut = object as? Cut {
                let index = cutIndex(withLocalX: convertToLocal(point(from: event)).x)
                insertCutItem(CutItem(cut: cut), at: index + 1, time: time)
                let nextCutItem = scene.cutItems[index + 1]
                setTime(nextCutItem.time + nextCutItem.cut.time, oldTime: time)
                return
            }
        }
    }
    
    func delete(with event: KeyInputEvent) {
        let inP = convertToLocal(point(from: event))
        let cutIndex = self.cutIndex(withLocalX: inP.x)
        if inP.y < bounds.height - timeDivisionHeight - tempoHeight - timeHeight {
            removeKeyframe(with: event)
        } else {
            removeCut(at: cutIndex)
        }
    }
    
    func moveToPrevious(with event: KeyInputEvent) {
        let cut = scene.editCutItem.cut
        let track = cut.editNode.editTrack
        let loopedIndex = track.animation.loopedKeyframeIndex(withTime: cut.time).loopedIndex
        let keyframeIndex = track.animation.loopedKeyframeIndexes[loopedIndex]
        if cut.time - keyframeIndex.time > 0 {
            updateTime(withCutTime: keyframeIndex.time)
        } else if loopedIndex - 1 >= 0 {
            updateTime(withCutTime: track.animation.loopedKeyframeIndexes[loopedIndex - 1].time)
        } else if scene.editCutItemIndex - 1 >= 0 {
            self.editCutItemIndex -= 1
            updateTime(withCutTime: track.animation.lastLoopedKeyframeTime)
        }
        sceneEditor.canvas.updateEditView(with: event.location)
    }
    func moveToNext(with event: KeyInputEvent) {
        let cut = scene.editCutItem.cut
        let track = cut.editNode.editTrack
        let loopedIndex = track.animation.loopedKeyframeIndex(withTime: cut.time).loopedIndex
        if loopedIndex + 1 <= track.animation.loopedKeyframeIndexes.count - 1 {
            let t = track.animation.loopedKeyframeIndexes[loopedIndex + 1].time
            if t < track.animation.timeLength {
                updateTime(withCutTime: t)
                return
            }
        }
        if scene.editCutItemIndex + 1 <= scene.cutItems.count - 1 {
            self.editCutItemIndex += 1
            updateTime(withCutTime: 0)
        }
        sceneEditor.canvas.updateEditView(with: event.location)
    }
    func play(with event: KeyInputEvent) {
        sceneEditor.canvas.play(with: event)
    }
    
//    func hide(with event: KeyInputEvent) {
//        let animation = scene.editCutItem.cut.editNode.editTrack
//        if !animation.isHidden {
//            setIsHidden(true, in: animation, time: time)
//        }
//    }
//    func show(with event: KeyInputEvent) {
//        let animation = scene.editCutItem.cut.editNode.editTrack
//        if animation.isHidden {
//            setIsHidden(false, in: animation, time: time)
//        }
//    }
//    func setIsHidden(_ isHidden: Bool, in animation: Animation, time: Beat) {
//        registerUndo { [oldHidden = animation.isHidden] in $0.setIsHidden(oldHidden, in: animation, time: $1) }
//        self.time = time
//        animation.isHidden = isHidden
//        scene.editCutItem.cutDataModel.isWrite = true
//        setNeedsDisplay()
//        sceneEditor.canvas.setNeedsDisplay()
//    }
    
    func new(with event: KeyInputEvent) {
        let inP = convertToLocal(point(from: event))
        let cutIndex = self.cutIndex(withLocalX: inP.x)
        if inP.y < bounds.height - timeDivisionHeight - tempoHeight - timeHeight {
            let cutItem = scene.cutItems[cutIndex]
            splitKeyframe(with: cutItem.cut.editNode.editTrack, in: cutItem, cutTime: time(withLocalX: inP.x) - cutItem.time)
        } else {
            insertCutItem(CutItem(), at: cutIndex + 1, time: time)
//            let nextCutItem = scene.cutItems[cutIndex + 1]
//            setTime(nextCutItem.time + nextCutItem.cut.time, oldTime: time)
        }
    }
    func insertCutItem(_ cutItem: CutItem, at index: Int, time: Beat) {
        registerUndo { $0.removeCutItem(at: index, time: $1) }
        self.time = time
        sceneEditor.insert(cutItem, at: index)
        updateCanvassPosition()
    }
    func removeCutItem(at index: Int, time: Beat) {
        let cutItem = scene.cutItems[index]
        registerUndo { $0.insertCutItem(cutItem, at: index, time: $1) }
        self.time = time
        sceneEditor.removeCutItem(at: index)
        updateCanvassPosition()
    }
    
    func newNode() {
        guard
            let parent = scene.editCutItem.cut.editNode.parent,
            let index = parent.children.index(of: scene.editCutItem.cut.editNode) else {
                return
        }
        let newNode = Node()
        insert(newNode, at: index, parent: parent, time: time)
        select(newNode, time: time)
    }
    func insert(_ node: Node, at index: Int, parent: Node, time: Beat) {
        registerUndo { $0.removeNode(at: index, parent: parent, time: $1) }
        self.time = time
        parent.children.insert(node, at: index)
        scene.editCutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
    }
    func removeNode(at index: Int, parent: Node, time: Beat) {
        registerUndo { [on = parent.children[index]] in $0.insert(on, at: index, parent: parent, time: $1) }
        self.time = time
        parent.children.remove(at: index)
        scene.editCutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
    }
    func select(_ node: Node, time: Beat) {
        registerUndo { [on = scene.editCutItem.cut.editNode] in $0.select(on, time: $1) }
        scene.editCutItem.cut.editNode = node
        scene.editCutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
    }
    
    func newNodeTrack() {
        let cutItem = scene.editCutItem
        let node = cutItem.cut.editNode
        let track = NodeTrack(timeLength: cutItem.cut.timeLength)
        let trackIndex = node.editTrackIndex + 1
        insert(track, at: trackIndex, in: node, in: cutItem, time: time)
        set(editTrackIndex: trackIndex, oldEditTrackIndex: node.editTrackIndex,
            in: node, in: cutItem, time: time)
    }
    func removeTrack(at index: Int, in node: Node, in cutItem: CutItem) {
        if node.tracks.count > 1 {
            set(editTrackIndex: max(0, index - 1), oldEditTrackIndex: index, in: node, in: cutItem, time: time)
            removeTrack(at: index, in: node, in: cutItem, time: time)
        }
    }
    func insert(_ track: NodeTrack, at index: Int, in node: Node, in cutItem: CutItem, time: Beat) {
        registerUndo { $0.removeTrack(at: index, in: node, in: cutItem, time: $1) }
        self.time = time
        node.tracks.insert(track, at: index)
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
    }
    func removeTrack(at index: Int, in node: Node, in cutItem: CutItem, time: Beat) {
        registerUndo { [ot = node.tracks[index]] in $0.insert(ot, at: index, in: node, in: cutItem, time: $1) }
        self.time = time
        node.tracks.remove(at: index)
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
    }
    private func set(editTrackIndex: Int, oldEditTrackIndex: Int, in node: Node, in cutItem: CutItem, time: Beat) {
        registerUndo { $0.set(editTrackIndex: oldEditTrackIndex, oldEditTrackIndex: editTrackIndex, in: node, in: cutItem, time: $1) }
        self.time = time
        node.editTrackIndex = editTrackIndex
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
        keyframeEditor.update()
        sceneEditor.transformEditor.update()
    }
    
    func newKeyframe() {
        let cutItem = scene.editCutItem
        let track = cutItem.cut.editNode.editTrack
        splitKeyframe(with: track, in: cutItem, cutTime: track.animation.time)
    }
    func splitKeyframe(with track: NodeTrack, in cutItem: CutItem, cutTime: Beat, isSplitDrawing: Bool = false) {
        let ki = Keyframe.index(time: cutTime, with: track.animation.keyframes)
        if ki.interTime > 0 {
            let k = track.animation.keyframes[ki.index]
            let newEaing = ki.sectionTime != 0 ? k.easing.split(with: Double(ki.interTime / ki.sectionTime).cf) : (b0: k.easing, b1: Easing())
            let splitKeyframe0 = Keyframe(time: k.time, easing: newEaing.b0, interpolation: k.interpolation, loop: k.loop, label: k.label)
            let splitKeyframe1 = Keyframe(
                time: cutTime, easing: newEaing.b1, interpolation: k.interpolation,
                label: track.isEmptyGeometryWithCells ? .main : .sub)
            let values = track.currentItemValues
            replaceKeyframe(splitKeyframe0, at: ki.index, in: track.animation, in: cutItem, time: time)
            insertKeyframe(
                keyframe: splitKeyframe1,
                drawing: isSplitDrawing ? values.drawing.deepCopy : Drawing(), geometries: values.geometries, materials: values.materials,
                transform: values.transform,
                at: ki.index + 1, in: track, in: cutItem, time: time
            )
            
            let indexes = track.animation.selectionKeyframeIndexes
            for (i, index) in indexes.enumerated() {
                if index >= ki.index {
                    let movedIndexes = indexes.map { $0 > ki.index ? $0 + 1 : $0 }
                    let intertedIndexes = index == ki.index ?
                        movedIndexes.withInserted(index + 1, at: i + 1) : movedIndexes
                    set(selectionIndexes: intertedIndexes, oldSelectionIndexes: indexes,
                        in: track.animation, in: cutItem, time: time)
                    break
                }
            }
        }
    }
    func removeKeyframe(with event: KeyInputEvent) {
        let ki = nearestKeyframeIndexTuple(at: convertToLocal(point(from: event)))
        let (index, cutIndex): (Int, Int) = {
            if let i = ki.keyframeIndex {
                return (i, ki.cutIndex)
            } else {
                let track = scene.cutItems[ki.cutIndex].cut.editNode.editTrack
                if track.animation.keyframes.count == 0 {
                    return (0, ki.cutIndex)
                } else {
                    return ki.cutIndex + 1 < scene.cutItems.count ?
                        (0, ki.cutIndex + 1) :
                        (track.animation.keyframes.count - 1, ki.cutIndex)
                }
            }
        } ()
        let cutItem = scene.cutItems[cutIndex]
        let node = cutItem.cut.editNode
        let track = node.editTrack
        let containsIndexes = track.animation.selectionKeyframeIndexes.contains(index)
        let indexes = containsIndexes ? track.animation.selectionKeyframeIndexes : [index]
        indexes.sorted().reversed().forEach {
            if track.animation.keyframes.count > 1 {
                if $0 == 0 {
                    removeFirstKeyframe(atCutIndex: cutIndex)
                } else {
                    removeKeyframe(at: $0, in: track, in: cutItem, time: time)
                }
            } else if node.tracks.count > 1 {
                removeTrack(at: node.editTrackIndex, in: node, in: cutItem)
            } else {
                removeCut(at: cutIndex)
            }
        }
        if containsIndexes {
            set(selectionIndexes: [], oldSelectionIndexes: track.animation.selectionKeyframeIndexes, in: track.animation, in: cutItem, time: time)
        }
    }
    private func removeFirstKeyframe(atCutIndex cutIndex: Int) {
        let cutItem = scene.cutItems[cutIndex]
        let track = cutItem.cut.editNode.editTrack
        let deltaTime = track.animation.keyframes[1].time
        removeKeyframe(at: 0, in: track, in: cutItem, time: time)
        let keyframes = track.animation.keyframes.map { $0.with(time: $0.time - deltaTime) }
        setKeyframes(keyframes, oldKeyframes: track.animation.keyframes, in: track.animation, cutItem, time: time)
    }
    func removeCut(at i: Int) {
        if i == 0 {
            setTime(time, oldTime: time, alwaysUpdateCutIndex: true)
            removeCutItem(at: 0, time: time)
            if scene.cutItems.count == 0 {
                insertCutItem(CutItem(), at: 0, time: time)
            }
            setTime(0, oldTime: time, alwaysUpdateCutIndex: true)
        } else {
            let previousCut = scene.cutItems[i - 1].cut
            let previousCutTimeLocation = scene.cutItems[i - 1].time
            let isSetTime = i == scene.editCutItemIndex
            setTime(time, oldTime: time, alwaysUpdateCutIndex: true)
            removeCutItem(at: i, time: time)
            if isSetTime {
                setTime(previousCutTimeLocation + previousCut.editNode.editTrack.animation.lastKeyframeTime, oldTime: time, alwaysUpdateCutIndex: true)
            } else if time >= scene.timeLength {
                setTime(scene.timeLength - scene.baseTimeInterval, oldTime: time, alwaysUpdateCutIndex: true)
            }
        }
    }
    private func setKeyframes(_ keyframes: [Keyframe], oldKeyframes: [Keyframe], in animation: Animation, _ cutItem: CutItem, time: Beat) {
        registerUndo { $0.setKeyframes(oldKeyframes, oldKeyframes: keyframes, in: animation, cutItem, time: $1) }
        self.time = time
        animation.replaceKeyframes(keyframes)
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
    }
    private func setTime(_ t: Beat, oldTime: Beat, alwaysUpdateCutIndex: Bool = false) {
        registerUndo { $0.0.setTime(oldTime, oldTime: t, alwaysUpdateCutIndex: alwaysUpdateCutIndex) }
        updateWith(time: t, scrollPoint: CGPoint(x: x(withTime: t), y: 0), alwaysUpdateCutIndex: alwaysUpdateCutIndex)
        scene.editCutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
    }
    private func replaceKeyframe(_ keyframe: Keyframe, at index: Int, in animation: Animation, in cutItem: CutItem, time: Beat) {
        registerUndo { [ok = animation.keyframes[index]] in $0.replaceKeyframe(ok, at: index, in: animation, in: cutItem, time: $1) }
        self.time = time
        animation.replaceKeyframe(keyframe, at: index)
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
    }
    private func insertKeyframe(
        keyframe: Keyframe,
        drawing: Drawing, geometries: [Geometry], materials: [Material],
        transform: Transform?,
        at index: Int, in track: NodeTrack, in cutItem: CutItem, time: Beat
        ) {
        registerUndo { $0.removeKeyframe(at: index, in: track, in: cutItem, time: $1) }
        self.time = time
        track.insertKeyframe(
            keyframe,
            drawing: drawing, geometries: geometries, materials: materials, transform: transform,
            at: index
        )
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
    }
    private func removeKeyframe(at index: Int, in track: NodeTrack, in cutItem: CutItem, time: Beat) {
        registerUndo { [ok = track.animation.keyframes[index], okv = track.keyframeItemValues(at: index)] in
            $0.insertKeyframe(
                keyframe: ok,
                drawing: okv.drawing, geometries: okv.geometries, materials: okv.materials,
                transform: okv.transform,
                at: index, in: track, in: cutItem, time: $1
            )
        }
        self.time = time
        track.removeKeyframe(at: index)
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
    }
    
    let (panel, keyframeEditor, nodeEditor): (Panel, KeyframeEditor, NodeEditor) = {
        let keyframeEditor = KeyframeEditor(), nodeEditor = NodeEditor()
        return (Panel(contents: [keyframeEditor, nodeEditor], isUseHedding: true),
                keyframeEditor, nodeEditor)
    } ()
    func showProperty(with event: DragEvent) {
        let root = rootRespondable
        if root !== self {
            CATransaction.disableAnimation {
                let point = self.point(from: event)
                let inPoint = convertToLocal(point)
                let cutItem = scene.cutItems[cutIndex(withLocalX: inPoint.x)]
                let track = cutItem.cut.editNode.editTrack
                let ki = Keyframe.index(time: time(withLocalX: inPoint.x) - cutItem.time, with: track.animation.keyframes)
                let keyframe = track.animation.keyframes[ki.index]
                keyframeEditor.keyframe = keyframe
                keyframeEditor.editKeyframeHandler = {
                    return KeyframeEditor.EditKeyframe(keyframe: keyframe, index: ki.index,
                                                       animation: track.animation, cutItem: cutItem)
                }
                nodeEditor.isHiddenButton.selectionIndex = cutItem.cut.editNode.isHidden ? 0 : 1
                
                panel.openPoint = event.location.integral
                panel.openViewPoint = point
                panel.indicationParent = self
                if !root.children.contains(where: { $0 === panel }) {
                    root.children.append(panel)
                }
            }
        }
    }
    
    private var isDrag = false, dragOldTime = DoubleBaseTime(0), editCutItem: CutItem?
    private var dragOldCutTimeLength = Beat(0), dragClipDeltaTime = Beat(0), dragMinDeltaTime = Beat(0), dragMinCutDeltaTime = Beat(0)
    private var dragOldSlideTuples = [(animation: Animation, keyframeIndex: Int, oldKeyframes: [Keyframe])]()
    func drag(with event: DragEvent) {
        let p = convertToLocal(point(from: event))
        func clipDeltaTime(withTime time: Beat) -> Beat {
            let ft = scene.baseTime(withBeatTime: time)
            let fft = ft + BaseTime(1, 2)
            return fft - floor(fft) < BaseTime(1, 2) ?
                scene.beatTime(withBaseTime: ceil(ft)) - time : scene.beatTime(withBaseTime: floor(ft)) - time
        }
       
        switch event.sendType {
        case .begin:
            if p.y >= timeHeight + Layout.basicPadding && p.y <= bounds.height - timeDivisionHeight - tempoHeight - timeHeight {
                let result = nearestKeyframeIndexTuple(at: p)
                let editCutItem = scene.cutItems[result.cutIndex]
                let track = editCutItem.cut.editNode.editTrack
                if let ki = result.keyframeIndex {
                    if ki > 0 {
                        let preTime = track.animation.keyframes[ki - 1].time, time = track.animation.keyframes[ki].time
                        dragClipDeltaTime = clipDeltaTime(withTime: time + editCutItem.time)
                        dragMinDeltaTime = preTime - time + scene.baseTimeInterval
                        dragOldSlideTuples = [(track.animation, ki, track.animation.keyframes)]
                    } else {
                        dragClipDeltaTime = 0
                    }
                } else {
                    let preTime = track.animation.keyframes[track.animation.keyframes.count - 1].time, time = editCutItem.cut.timeLength
                    dragClipDeltaTime = clipDeltaTime(withTime: time + editCutItem.time)
                    dragMinDeltaTime = preTime - time + scene.baseTimeInterval
                    dragOldSlideTuples = []
                }
                dragMinCutDeltaTime = max(
                    editCutItem.cut.editNode.maxTimeWithOtherAnimation(track.animation) - editCutItem.cut.timeLength + scene.baseTimeInterval,
                    dragMinDeltaTime
                )
                self.editCutItem = result.cutIndex == 0 && result.keyframeIndex == 0 ? nil : editCutItem
                dragOldCutTimeLength = editCutItem.cut.timeLength
            } else {
                let result = animationIndexTuple(at: p)
                let editCutItem = scene.cutItems[result.cutIndex]
                let minTrack = editCutItem.cut.editNode.tracks[result.animationIndex]
                if let ki = result.keyframeIndex {
                    if ki > 0 {
                        let kt = minTrack.animation.keyframes[ki].time
                        var dragOldSlideTuples = [(animation: Animation, keyframeIndex: Int, oldKeyframes: [Keyframe])](), pkt = Beat(0)
                        for track in editCutItem.cut.editNode.tracks {
                            let result = Keyframe.index(time: kt, with: track.animation.keyframes)
                            let index: Int? = result.interTime > 0 ? (result.index + 1 <= track.animation.keyframes.count - 1 ? result.index + 1 : nil) : result.index
                            if let i = index {
                                dragOldSlideTuples.append((track.animation, i, track.animation.keyframes))
                            }
                            let preIndex: Int? = result.interTime > 0 ?  result.index : (result.index > 0 ? result.index - 1 : nil)
                            if let pi = preIndex {
                                let preTime = track.animation.keyframes[pi].time
                                if pkt < preTime {
                                    pkt = preTime
                                }
                            }
                        }
                        dragClipDeltaTime = clipDeltaTime(withTime: kt + editCutItem.time)
                        dragMinDeltaTime = pkt - kt + scene.baseTimeInterval
                        self.dragOldSlideTuples = dragOldSlideTuples
                    }
                } else {
                    let preTime = minTrack.animation.keyframes[minTrack.animation.keyframes.count - 1].time, time = editCutItem.cut.timeLength
                    dragClipDeltaTime = clipDeltaTime(withTime: time + editCutItem.time)
                    dragMinDeltaTime = preTime - time + scene.baseTimeInterval
                    dragOldSlideTuples = []
                }
                self.dragMinCutDeltaTime = dragMinDeltaTime
                self.editCutItem = result.cutIndex == 0 && result.keyframeIndex == 0 ? nil : editCutItem
                self.dragOldCutTimeLength = editCutItem.cut.timeLength
            }
            dragOldTime = doubleBaseTime(withLocalX: p.x)
            isDrag = false
        case .sending:
            isDrag = true
            if let editCutItem = editCutItem {
                let t = doubleBaseTime(withLocalX: convertToLocal(point(from: event)).x)
                let fdt = t - dragOldTime + (t - dragOldTime >= 0 ? 0.5 : -0.5)
                let dt = scene.basedBeatTime(withDoubleBaseTime: fdt)
                let deltaTime = max(dragMinDeltaTime, dt + dragClipDeltaTime)
                for slideAnimation in dragOldSlideTuples {
                    var nks = slideAnimation.oldKeyframes
                    for i in slideAnimation.keyframeIndex ..< nks.count {
                        nks[i] = nks[i].with(time: nks[i].time + deltaTime)
                    }
                    slideAnimation.animation.replaceKeyframes(nks)
                }
                let animationTimeLength = dragOldCutTimeLength + max(dragMinCutDeltaTime, dt + dragClipDeltaTime)
                if animationTimeLength != editCutItem.cut.timeLength {
                    editCutItem.cut.timeLength = animationTimeLength
                    scene.updateCutTimeAndTimeLength()
                }
                updateView()
                setNeedsDisplay()
            }
        case .end:
            if isDrag, let editCutItem = editCutItem {
                setTime(time, oldTime: time)
                let t = doubleBaseTime(withLocalX: convertToLocal(point(from: event)).x)
                let fdt = t - dragOldTime + (t - dragOldTime >= 0 ? 0.5 : -0.5)
                let dt = scene.basedBeatTime(withDoubleBaseTime: fdt)
                let deltaTime = max(dragMinDeltaTime, dt + dragClipDeltaTime)
                for slideAnimation in dragOldSlideTuples {
                    var nks = slideAnimation.oldKeyframes
                    if deltaTime != 0 {
                        for i in slideAnimation.keyframeIndex ..< nks.count {
                            nks[i] = nks[i].with(time: nks[i].time + deltaTime)
                        }
                        setKeyframes(nks, oldKeyframes: slideAnimation.oldKeyframes, in: slideAnimation.animation, editCutItem, time: time)
                    } else {
                        slideAnimation.animation.replaceKeyframes(nks)
                    }
                }
                let timeLength = dragOldCutTimeLength + max(dragMinCutDeltaTime, dt + dragClipDeltaTime)
                if timeLength != dragOldCutTimeLength {
                    setTimeLength(timeLength, oldTimeLength: dragOldCutTimeLength, in: editCutItem, time: time)
                }
                setTime(time, oldTime: time)
                dragOldSlideTuples = []
                self.editCutItem = nil
            }
        }
    }
    private func setTimeLength(_ timeLength: Beat, oldTimeLength: Beat, in cutItem: CutItem, time: Beat) {
        registerUndo { $0.setTimeLength(oldTimeLength, oldTimeLength: timeLength, in: cutItem, time: $1) }
        self.time = time
        cutItem.cut.timeLength = timeLength
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
        scene.updateCutTimeAndTimeLength()
        sceneEditor.playerEditor.maxTime = scene.secondTime(withBeatTime: scene.timeLength)
    }
    
    let itemHeight = 8.0.cf
    private var oldIndex = 0, oldP = CGPoint()
    var moveQuasimode = false
    private weak var moveCutItem: CutItem?
    var oldTracks = [NodeTrack]()
    func move(with event: DragEvent) {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            oldTracks = scene.editCutItem.cut.editNode.tracks
            oldIndex = scene.editCutItem.cut.editNode.editTrackIndex
            oldP = p
            moveCutItem = scene.editCutItem
        case .sending:
            if let cutItem = moveCutItem {
                let d = p.y - oldP.y
                let i = (oldIndex + Int(d / itemHeight)).clip(min: 0, max: cutItem.cut.editNode.tracks.count), oi = cutItem.cut.editNode.editTrackIndex
                let animation = cutItem.cut.editNode.editTrack
                cutItem.cut.editNode.tracks.remove(at: oi)
                cutItem.cut.editNode.tracks.insert(animation, at: oi < i ? i - 1 : i)
                setNeedsDisplay()
                sceneEditor.canvas.setNeedsDisplay()
                keyframeEditor.update()
                sceneEditor.transformEditor.update()
            }
        case .end:
            if let cutItem = moveCutItem {
                let d = p.y - oldP.y
                let i = (oldIndex + Int(d / itemHeight)).clip(min: 0, max: cutItem.cut.editNode.tracks.count), oi = cutItem.cut.editNode.editTrackIndex
                if oldIndex != i {
                    var tracks = cutItem.cut.editNode.tracks
                    tracks.remove(at: oi)
                    tracks.insert(cutItem.cut.editNode.editTrack, at: oi < i ? i - 1 : i)
                    set(tracks: tracks, oldTracks: oldTracks, in: cutItem, time: time)
                } else if oi != i {
                    cutItem.cut.editNode.tracks.remove(at: oi)
                    cutItem.cut.editNode.tracks.insert(cutItem.cut.editNode.editTrack, at: oi < i ? i - 1 : i)
                    setNeedsDisplay()
                    sceneEditor.canvas.setNeedsDisplay()
                    keyframeEditor.update()
                    sceneEditor.transformEditor.update()
                }
                oldTracks = []
                editCutItem = nil
            }
        }
    }
    private func set(tracks: [NodeTrack], oldTracks: [NodeTrack], in cutItem: CutItem, time: Beat) {
        registerUndo { $0.set(tracks: oldTracks, oldTracks: tracks, in: cutItem, time: $1) }
        self.time = time
        cutItem.cut.editNode.tracks = tracks
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
        keyframeEditor.update()
        sceneEditor.transformEditor.update()
    }
    
    func selectAll(with event: KeyInputEvent) {
        selectAll(with: event, isDeselect: false)
    }
    func deselectAll(with event: KeyInputEvent) {
        selectAll(with: event, isDeselect: true)
    }
    func selectAll(with event: KeyInputEvent, isDeselect: Bool) {
        let cutItem = scene.cutItems[cutIndex(withLocalX: convertToLocal(point(from: event)).x)]
        let track = cutItem.cut.editNode.editTrack
        let indexes = isDeselect ? [] : Array(0 ..< track.animation.keyframes.count)
        if indexes != track.animation.selectionKeyframeIndexes {
            set(selectionIndexes: indexes, oldSelectionIndexes: track.animation.selectionKeyframeIndexes, in: track.animation, in: cutItem, time: time)
        }
    }
    var selectionLayer: CALayer? {
        didSet {
            CATransaction.disableAnimation {
                if let selectionLayer = selectionLayer {
                    layer.addSublayer(selectionLayer)
                } else {
                    oldValue?.removeFromSuperlayer()
                }
            }
        }
    }
    private struct SelectOption {
        let indexes: [Int], animation: Animation, cutItem: CutItem
    }
    private var selectOption: SelectOption?
    func select(with event: DragEvent) {
        select(with: event, isDeselect: false)
    }
    func deselect(with event: DragEvent) {
        select(with: event, isDeselect: true)
    }
    func select(with event: DragEvent, isDeselect: Bool) {
        CATransaction.disableAnimation {
            let point = self.point(from: event).integral
            func indexes(with selectOption: SelectOption) -> [Int] {
                let startIndexInPoint = convertToLocal(oldP)
                let startIndexTuple = Keyframe.index(time: time(withLocalX: startIndexInPoint.x, isBased: false) + scene.baseTimeInterval / 2 - selectOption.cutItem.time, with: selectOption.animation.keyframes)
                let startIndex = startIndexTuple.index
                let endIndexPoint = self.point(from: event)
                let endIndexInPoint = convertToLocal(endIndexPoint)
                let endIndexTuple = Keyframe.index(time: time(withLocalX: endIndexInPoint.x, isBased: false) + scene.baseTimeInterval / 2 - selectOption.cutItem.time, with: selectOption.animation.keyframes)
                let endIndex = endIndexTuple.index
                return startIndex == endIndex ? [startIndex] :
                    (startIndex < endIndex ? Array(startIndex ... endIndex) : Array(endIndex ... startIndex))
            }
            func selectionIndex(with selectOption: SelectOption) -> [Int] {
                let selectionIndexes = indexes(with: selectOption)
                return isDeselect ?
                    Array(Set(selectOption.indexes).subtracting(Set(selectionIndexes))).sorted() :
                    Array(Set(selectOption.indexes).union(Set(selectionIndexes))).sorted()
            }
            switch event.sendType {
            case .begin:
                selectionLayer = isDeselect ? CALayer.deselectionLayer() : CALayer.selectionLayer()
                oldP = point
                let cutItem = scene.cutItems[cutIndex(withLocalX: convertToLocal(point).x)]
                let track = cutItem.cut.editNode.editTrack
                selectOption = SelectOption(indexes: track.animation.selectionKeyframeIndexes, animation: track.animation, cutItem: cutItem)
                selectionLayer?.frame = CGRect(origin: point, size: CGSize())
            case .sending:
                if let selectOption = selectOption {
                    selectionLayer?.frame = CGRect(origin: oldP, size: CGSize(width: point.x - oldP.x, height: point.y - oldP.y))
                    selectOption.animation.selectionKeyframeIndexes = selectionIndex(with: selectOption)
                    setNeedsDisplay()
                }
            case .end:
                if let selectOption = selectOption {
                    self.selectOption = nil
                    let newIndexes = selectionIndex(with: selectOption)
                    if selectOption.indexes != newIndexes {
                        set(selectionIndexes: newIndexes, oldSelectionIndexes: selectOption.indexes, in: selectOption.animation, in: selectOption.cutItem, time: time)
                    } else {
                        selectOption.animation.selectionKeyframeIndexes = selectOption.indexes
                    }
                    setNeedsDisplay()
                }
                selectionLayer = nil
            }
        }
    }
    func set(selectionIndexes: [Int], oldSelectionIndexes: [Int], in animation: Animation, in cutItem: CutItem, time: Beat) {
        registerUndo { $0.set(selectionIndexes: oldSelectionIndexes,
                              oldSelectionIndexes: selectionIndexes,
                              in: animation, in: cutItem, time: $1) }
        self.time = time
        animation.selectionKeyframeIndexes = selectionIndexes
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
    }
    
    private var istrackscroll = false, deltaScrollY = 0.0.cf, scrollCutItem: CutItem?
    func scroll(with event: ScrollEvent) {
        scroll(with: event, isUseMomentum: true)
    }
    func scroll(with event: ScrollEvent, isUseMomentum: Bool) {
        if event.sendType  == .begin {
            let point = self.point(from: event)
            let cutItem = scene.cutItems[cutIndex(withLocalX: convertToLocal(point).x)]
            istrackscroll = cutItem.cut.editNode.tracks.count == 1 ? false : abs(event.scrollDeltaPoint.x) < abs(event.scrollDeltaPoint.y)
        }
        if istrackscroll {
            if event.scrollMomentumType == nil {
                let point = self.point(from: event)
                switch event.sendType {
                case .begin:
                    let cutItem = scene.cutItems[cutIndex(withLocalX: convertToLocal(point).x)]
                    oldIndex = cutItem.cut.editNode.editTrackIndex
                    oldP = point
                    deltaScrollY = 0
                    scrollCutItem = cutItem
                case .sending:
                    if let scrollCutItem = scrollCutItem {
                        deltaScrollY += event.scrollDeltaPoint.y
                        let i = (oldIndex + Int(deltaScrollY / 10)).clip(min: 0, max: scrollCutItem.cut.editNode.tracks.count - 1)
                        if scrollCutItem.cut.editNode.editTrackIndex != i {
                            scrollCutItem.cut.editNode.editTrackIndex = i
                            updateView()
                        }
                    }
                case .end:
                    if let scrollCutItem = scrollCutItem {
                        let node = scrollCutItem.cut.editNode
                        let i = (oldIndex + Int(deltaScrollY / 10)).clip(min: 0, max: node.tracks.count - 1)
                        if oldIndex != i {
                            set(editTrackIndex: i, oldEditTrackIndex: oldIndex, in: node, in: scrollCutItem, time: time)
                        } else if node.editTrackIndex != i {
                            node.editTrackIndex = i
                            updateView()
                        }
                        self.scrollCutItem = nil
                    }
                }
            }
        } else /*if event.scrollMomentumType == nil*/ {
            if event.sendType == .begin && sceneEditor.canvas.player.isPlaying {
                sceneEditor.canvas.player.layer.opacity = 0.2
            } else if event.sendType == .end && sceneEditor.canvas.player.layer.opacity != 1 {
                sceneEditor.canvas.player.layer.opacity = 1
            }
            let x = (scrollPoint.x - event.scrollDeltaPoint.x).clip(min: 0, max: self.x(withTime: scene.timeLength - scene.baseTimeInterval))
            scrollPoint = CGPoint(x: event.sendType == .begin ? self.x(withTime: time(withLocalX: x)) : x, y: 0)
        }
    }
    func zoom(with event: PinchEvent) {
        zoom(at: point(from: event)) {
            editFrameRateWidth = (editFrameRateWidth * (event.magnification * 2.5 + 1)).clip(min: 1, max: Timeline.defaultFrameRateWidth)
        }
    }
    func reset(with event: DoubleTapEvent) {
        zoom(at: point(from: event)) {
            editFrameRateWidth = Timeline.defaultFrameRateWidth
        }
    }
    func zoom(at p: CGPoint, handler: () -> ()) {
        handler()
        _scrollPoint.x = x(withTime: time)
        _intervalScrollPoint.x = scrollPoint.x
        setNeedsDisplay()
    }
}
