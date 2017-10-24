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
//キーフレームの複数選択
//タイムラインにキーフレーム・プロパティを統合
//アニメーション描画（表示が離散的な1フレーム単位または1グループ単位のため）
//カットのサムネイル導入（タイムラインを縮小するとサムネイル表示になるように設計）
//カット分割設計（カットもキーフレームのように分割するように設計。対になる接合アクションが必要）

import Foundation
import QuartzCore

final class TimelineEditor: LayerRespondable, ButtonDelegate {
    static let name = Localization(english: "Timeline Editor", japanese: "タイムラインエディタ")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager?
    
    weak var sceneEditor: SceneEditor! {
        didSet {
            timeline.sceneEditor = sceneEditor
        }
    }
    
    let timeline = Timeline(
        frame: SceneEditor.Layout.timelineEditFrame,
        description: Localization(english: "Interface for scene", japanese: "シーン用インターフェイス")
    )
    let newCutButton = Button(
        frame: SceneEditor.Layout.timelineNewCutFrame,
        name: Localization(english: "New Cut", japanese: "カットを追加")
    )
    let splitKeyframeButton = Button(
        frame: SceneEditor.Layout.timelineNewKeyframeFrame,
        name: Localization(english: "New Keyframe", japanese: "キーフレームを追加")
    )
    let newAnimationButton = Button(
        frame: SceneEditor.Layout.timelineNewAnimationFrame,
        name: Localization(english: "New Animation", japanese: "アニメーションを追加")
    )
    
    let layer = CALayer.interfaceLayer()
    init() {
        layer.frame = SceneEditor.Layout.timelineFrame
        newAnimationButton.drawLayer.fillColor = Color.subBackground3
        newCutButton.drawLayer.fillColor = Color.subBackground3
        splitKeyframeButton.drawLayer.fillColor = Color.subBackground3
        newAnimationButton.sendDelegate = self
        newCutButton.sendDelegate = self
        splitKeyframeButton.sendDelegate = self
        children = [timeline, newAnimationButton, newCutButton, splitKeyframeButton]
        update(withChildren: children)
    }
    func clickButton(_ button: Button) {
        switch button {
        case newAnimationButton:
            timeline.newAnimation()
        case newCutButton:
            timeline.newCut()
        case splitKeyframeButton:
            timeline.newKeyframe()
        default:
            break
        }
    }
    func scroll(with event: ScrollEvent) {
        timeline.scroll(with: event)
    }
    func zoom(with event: PinchEvent) {
        timeline.zoom(with: event)
    }
    func reset(with event: DoubleTapEvent) {
        timeline.reset(with: event)
    }
}

final class Timeline: LayerRespondable {
    static let name = Localization(english: "Timeline", japanese: "タイムライン")
    static let description = Localization(
        english: "Select time: Left and right scroll\nSelect animation: Up and down scroll",
        japanese: "時間選択: 左右スクロール\nグループ選択: 上下スクロール"
    )
    var description: Localization
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager?
    
    weak var sceneEditor: SceneEditor!
    
    var canvas: Canvas {
        return sceneEditor.canvas
    }
    var layer: CALayer {
        return drawLayer
    }
    let drawLayer = DrawLayer(fillColor: Color.subBackground3)
    init(frame: CGRect = CGRect(), description: Localization = Localization()) {
        self.description = description
        drawLayer.frame = frame
        drawLayer.drawBlock = { [unowned self] ctx in
            self.draw(in: ctx)
        }
    }
    
    var cursor: Cursor {
        return moveQuasimode ? .upDown : .arrow
    }
    
    var sceneEntity = SceneEntity() {
        didSet {
            updateCanvassPosition()
            updateMaxTime()
            canvas.player.sceneEntity = sceneEntity
        }
    }
    var scene = Scene() {
        didSet {
            updateWith(time: scene.time, scrollPoint: CGPoint(x: x(withTime: scene.time), y: 0))
            
            canvas.cutEntity = selectionCutEntity
            sceneEditor.keyframeEditor.update()
            sceneEditor.cameraEditor.update()
            sceneEditor.speechEditor.update()
            setNeedsDisplay()
        }
    }
    var selectionCutEntity: CutEntity {
        get {
            return sceneEntity.cutEntities[selectionCutIndex >= sceneEntity.cutEntities.count ? selectionCutIndex - 1 : selectionCutIndex]
        } set {
            if let index = sceneEntity.cutEntities.index(of: newValue) {
                selectionCutIndex = index
            }
        }
    }
    var selectionCutIndex = 0 {
        didSet {
            canvas.cutEntity = selectionCutEntity
            sceneEditor.keyframeEditor.update()
            sceneEditor.cameraEditor.update()
            sceneEditor.speechEditor.update()
            setNeedsDisplay()
        }
    }
    var editAnimation: Animation {
        return selectionCutEntity.cut.editAnimation
    }
    var editKeyframe: Keyframe {
        return editAnimation.editKeyframe
    }
    var fps = 24
    static let defaultFrameRateWidth = 6.0.cf, defaultTimeHeight = 18.0.cf
    var editFrameRateWidth = Timeline.defaultFrameRateWidth, timeHeight = defaultTimeHeight
    private(set) var maxScrollX = 0.0.cf
    func updateCanvassPosition() {
        maxScrollX = sceneEntity.cutEntities.reduce(0.0.cf) { $0 + x(withTime: $1.cut.timeLength) }
        setNeedsDisplay()
    }
    private var _time = 0, _scrollPoint = CGPoint(), _intervalScrollPoint = CGPoint()
    var scrollPoint: CGPoint {
        get {
            return _scrollPoint
        } set {
            let newTime = time(withX: newValue.x)
            if newTime != _time {
                updateWith(time: newTime, scrollPoint: newValue)
            } else {
                _scrollPoint = newValue
            }
        }
    }
    var time: Int {
        get {
            return _time
        } set {
            if newValue != _time {
                updateWith(time: newValue, scrollPoint: CGPoint(x: x(withTime: newValue), y: 0))
            }
        }
    }
    private func updateWith(time: Int, scrollPoint: CGPoint, alwaysUpdateCutIndex: Bool = false) {
        _time = time
        _scrollPoint = scrollPoint
        _intervalScrollPoint = intervalScrollPoint(with: _scrollPoint)
        let oldTime = sceneEntity.preference.scene.time
        if time != oldTime {
            sceneEntity.preference.scene.time = time
            sceneEntity.isUpdatePreference = true
        }
        let cvi = sceneEntity.cutIndex(withTime: time)
        if alwaysUpdateCutIndex || selectionCutIndex != cvi.index {
            selectionCutIndex = cvi.index
            selectionCutEntity.cut.time = cvi.interTime
        } else {
            selectionCutEntity.cut.time = cvi.interTime
        }
        updateView()
    }
    private func updateView() {
        sceneEditor.keyframeEditor.update()
        sceneEditor.cameraEditor.update()
        sceneEditor.speechEditor.update()
        canvas.updateViewAffineTransform()
        setNeedsDisplay()
        canvas.setNeedsDisplay()
    }
    private func intervalScrollPoint(with scrollPoint: CGPoint) -> CGPoint {
        return CGPoint(x: x(withTime: time(withX: scrollPoint.x)), y: 0)
    }
    var cutTime: Int {
        get {
            return selectionCutEntity.cut.time
        } set {
            time = newValue + cutTimeLocation(withCutIndex: selectionCutIndex)
        }
    }
    var maxTime = 0
    func updateTime(withCutTime cutTime: Int) {
        _scrollPoint.x = x(withTime: cutTime + cutTimeLocation(withCutIndex: selectionCutIndex))
        let t = time(withX: scrollPoint.x)
        time = t
        _intervalScrollPoint.x = x(withTime: t)
    }
    func updateMaxTime() {
        maxTime = sceneEntity.cutEntities.reduce(0) { $0 + $1.cut.timeLength }
    }
    
    var contentFrame: CGRect {
        return CGRect(x: _scrollPoint.x, y: 0, width: x(withTime: maxTime - 1), height: 0)
    }
    func time(withX x: CGFloat) -> Int {
        return Int(x/editFrameRateWidth)
    }
    func x(withTime time: Int) -> CGFloat {
        return time.cf*editFrameRateWidth
    }
    func cutTimeLocation(withCutIndex index: Int) -> Int {
        return (0 ..< index).reduce(0) { $0 + sceneEntity.cutEntities[$1].cut.timeLength }
    }
    func cutIndex(withX x: CGFloat) -> Int {
        return sceneEntity.cutIndex(withTime: time(withX: x)).index
    }
    func cutLabelIndex(at p: CGPoint) -> Int? {
        let time = self.time(withX: p.x)
        var t = 0
        for cutEntity in sceneEntity.cutEntities {
            let nt = t + cutEntity.cut.timeLength
            if time < nt {
                func cutIndex(with x: CGFloat) -> Bool {
                    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "C\(cutEntity.index + 1)", attributes: [String(kCTFontAttributeName): Font.small.ctFont, String(kCTForegroundColorAttributeName): Color.smallFont.cgColor]))
                    let sb = line.typographicBounds
                    let nsb = CGRect(
                        x: x + editFrameRateWidth/2 - sb.width/2 + sb.origin.x, y: timeHeight/2 - sb.height/2 + sb.origin.y,
                        width: sb.width, height: sb.height
                    )
                    return nsb.contains(p)
                }
                if cutIndex(with: x(withTime: t)) {
                    return cutEntity.index
                } else if cutIndex(with: x(withTime: nt)) {
                    return cutEntity.index + 1
                }
            }
            t = nt
        }
        return nil
    }
    func convertToInternal(_ p: CGPoint) -> CGPoint {
        return CGPoint(x: p.x - (bounds.width/2 - _intervalScrollPoint.x), y: p.y)
    }
    func convertFromInternal(_ p: CGPoint) -> CGPoint {
        return CGPoint(x: p.x + (bounds.width/2 - _intervalScrollPoint.x), y: p.y)
    }
    func nearestKeyframeIndexTuple(at p: CGPoint) -> (cutIndex: Int, keyframeIndex: Int?) {
        let ci = cutIndex(withX: p.x)
        let cut = sceneEntity.cutEntities[ci].cut, kt = cutTimeLocation(withCutIndex: ci)
        if cut.editAnimation.keyframes.count == 0 {
            return (ci, nil)
        } else {
            var minD = CGFloat.infinity, minI = 0
            for (i, k) in cut.editAnimation.keyframes.enumerated() {
                let x = (kt + k.time).cf*editFrameRateWidth
                let d = abs(p.x - x)
                if d < minD {
                    minI = i
                    minD = d
                }
            }
            let x = (kt + cut.timeLength).cf*editFrameRateWidth
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
        let ci = cutIndex(withX: p.x)
        let cut = sceneEntity.cutEntities[ci].cut, kt = cutTimeLocation(withCutIndex: ci)
        var minD = CGFloat.infinity, minKeyframeIndex = 0, minAnimationIndex = 0
        for (ii, animation) in cut.animations.enumerated() {
            for (i, k) in animation.keyframes.enumerated() {
                let x = (kt + k.time).cf*editFrameRateWidth
                let d = abs(p.x - x)
                if d < minD {
                    minAnimationIndex = ii
                    minKeyframeIndex = i
                    minD = d
                }
            }
        }
        let x = (kt + cut.timeLength).cf*editFrameRateWidth
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
        ctx.translateBy(x: bounds.width/2 - editFrameRateWidth/2 - _intervalScrollPoint.x, y: 0)
        drawTime(in: ctx)
        drawCuts(in: ctx)
        drawTimeBar(in: ctx)
    }
    func drawCuts(in ctx: CGContext) {
        ctx.saveGState()
        let b = ctx.boundingBoxOfClipPath
        var x = 0.0.cf
        for cutEntity in sceneEntity.cutEntities {
            let w = cutEntity.cut.timeLength.cf*editFrameRateWidth
            if b.minX <= x + w && b.maxX >= x {
                let index = cutEntity.cut.editAnimationIndex, h = 2.0.cf
                let cutKnobBounds = self.cutKnobBounds(with: cutEntity.cut).insetBy(dx: 0, dy: 1)
                if index == 0 {
                    drawAllAnimationKnob(cutEntity.cut, y: bounds.height/2, in: ctx)
                } else {
                    var y = bounds.height/2 + knobHalfHeight
                    for _ in (0 ..< index).reversed() {
                        y += 1 + h
                        if y >= cutKnobBounds.maxY {
                            y = cutKnobBounds.maxY
                            break
                        }
                    }
                    drawAllAnimationKnob(cutEntity.cut, y: y, in: ctx)
                }
                
                var y = bounds.height/2 + knobHalfHeight + 1
                for i in (0 ..< index).reversed() {
                    drawNotSelectedAnimationWith(animation: cutEntity.cut.animations[i], width: w, y: y, h: h, in: ctx)
                    y += 1 + h
                    if y >= cutKnobBounds.maxY {
                        break
                    }
                }
                y = bounds.height/2 - knobHalfHeight - 1
                if index + 1 < cutEntity.cut.animations.count {
                    for i in index + 1 ..< cutEntity.cut.animations.count {
                        drawNotSelectedAnimationWith(animation: cutEntity.cut.animations[i], width: w, y: y - h, h:h, in: ctx)
                        y -= 1 + h
                        if y <= cutKnobBounds.minY {
                            break
                        }
                    }
                }
                drawAnimation(cutEntity.cut.editAnimation, cut: cutEntity.cut, y: bounds.height/2, isOther: false, in: ctx)
                drawCutEntity(cutEntity, in: ctx)
            }
            ctx.translateBy(x: w, y: 0)
            x += w
        }
        ctx.restoreGState()
        
        drawKnob(from: CGPoint(x: x, y: bounds.height/2), fillColor: Color.content, lineColor: Color.edit, in: ctx)
    }
    func cutKnobBounds(with cut: Cut) -> CGRect {
        return CGRect(
            x: cut.timeLength.cf*editFrameRateWidth, y: timeHeight + 2,
            width: editFrameRateWidth, height: bounds.height - timeHeight*2 - 2*2
        )
    }
    func drawCutEntity(_ cutEntity: CutEntity, in ctx: CGContext) {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: "C\(cutEntity.index + 1)", attributes: [String(kCTFontAttributeName): Font.small.ctFont, String(kCTForegroundColorAttributeName): Color.smallFont.cgColor]))
        let sb = line.typographicBounds
        ctx.textPosition = CGPoint(x: editFrameRateWidth/2 - sb.width/2 + sb.origin.x, y: timeHeight/2 - sb.height/2 + sb.origin.y)
        CTLineDraw(line, ctx)
    }
    private let knobHalfHeight = 6.0.cf, easingHeight = 3.0.cf
    func drawAnimation(_ animation: Animation, cut: Cut, y: CGFloat, isOther: Bool, in ctx: CGContext) {
        let lineColor = animation.isHidden ?
            (animation.transformItem != nil ? Color.camera.multiply(white: 0.5) : Color.contentEdit.multiply(white: 0.5)) :
            (animation.transformItem != nil ? Color.camera : Color.contentEdit)
        let knobFillColor = animation.isHidden ? Color.subBackground3.multiply(white: 0.5) : Color.content
        let knobLineColor = animation.isHidden ?
            (animation.transformItem != nil ? Color.camera.multiply(white: 0.5) : Color.subBackground) :
            (animation.transformItem != nil ? Color.camera.multiply(white: 0.5) : Color.edit)
        
        ctx.setLineWidth(2)
        ctx.setStrokeColor(Color.contentEdit.cgColor)
        ctx.move(to: CGPoint(x: editFrameRateWidth/2, y: timeHeight))
        ctx.addLine(to: CGPoint(x: editFrameRateWidth/2, y: bounds.height - timeHeight))
        ctx.strokePath()
        
        for (i, lki) in animation.loopedKeyframeIndexes.enumerated() {
            let keyframe = animation.keyframes[lki.index]
            let time = lki.time
            let nextTime = i + 1 >= animation.loopedKeyframeIndexes.count ?
                cut.timeLength : animation.loopedKeyframeIndexes[i + 1].time
            let x = time.cf*editFrameRateWidth
            let nextX = i + 1 >= animation.loopedKeyframeIndexes.count ?
                (nextTime.cf - 0.5)*editFrameRateWidth : nextTime.cf*editFrameRateWidth
            let timeLength = nextTime - time, width = nextX - x
            
            if time >= animation.timeLength {
                continue
            }
            let isClipDrawKeyframe = nextTime > animation.timeLength
            if isClipDrawKeyframe {
                ctx.saveGState()
                let nx = min(nextX, (cut.timeLength.cf - 0.5)*editFrameRateWidth)
                ctx.clip(to: CGRect(x: x, y: y - timeHeight/2, width: nx - x, height: timeHeight))
            }
            if timeLength > 1 {
                if !keyframe.easing.isLinear && !isOther {
                    let b = keyframe.easing.bezier, bw = width, bx = x + editFrameRateWidth/2, count = Int(width/5.0)
                    let d = 1/count.cf
                    let points: [CGPoint] = (0 ... count).map { i in
                        let dx = d*i.cf
                        let dp = b.difference(withT: dx)
                        let dy = max(0.5, min(easingHeight, (dp.x == dp.y ? .pi/2 : 2*atan2(dp.y, dp.x))/(.pi/2)))
                        return CGPoint(x: dx*bw + bx, y: dy)
                    }
                    if lki.loopCount > 0 {
                        for i in 0 ..< lki.loopCount {
                            let dt = i.cf*2
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
                    let lw = isOther ? 1.0.cf : 2.0.cf
                    if lki.loopCount > 0 {
                        for i in 0 ..< lki.loopCount {
                            let dt = (i + 1).cf*2 - 0.5
                            ctx.move(to: CGPoint(x: x + editFrameRateWidth/2, y: y - dt))
                            ctx.addLine(to: CGPoint(x: nextX + editFrameRateWidth/2, y: y - dt))
                            ctx.move(to: CGPoint(x: x + editFrameRateWidth/2, y: y + dt))
                            ctx.addLine(to: CGPoint(x: nextX + editFrameRateWidth/2.0, y: y + dt))
                        }
                        ctx.setLineWidth(lw/2)
                    } else {
                        ctx.move(to: CGPoint(x: x + editFrameRateWidth/2, y: y))
                        ctx.addLine(to: CGPoint(x: nextX + editFrameRateWidth/2, y: y))
                        ctx.setLineWidth(lw)
                    }
                    ctx.setStrokeColor(lineColor.cgColor)
                    ctx.strokePath()
                }
            }
            let knobColor = lki.loopingCount > 0 ?
                Color.subBackground3 :
                (animation.drawingItem.keyDrawings[i].roughLines.isEmpty ? knobFillColor : Color.timelineRough)
            drawKnob(from: CGPoint(x: x, y:y), fillColor: knobColor, lineColor: knobLineColor, in: ctx)

            if isClipDrawKeyframe {
                ctx.restoreGState()
            }
        }
    }
    func drawNotSelectedAnimationWith(animation: Animation, width: CGFloat, y: CGFloat, h: CGFloat, in ctx: CGContext) {
        let lineColor = animation.isHidden ?
            (animation.transformItem != nil ? Color.camera.multiply(white: 0.75) : Color.subBackground) :
            (animation.transformItem != nil ? Color.camera.multiply(white: 0.5) : Color.edit)
        let keyColor = animation.isHidden ?
            (animation.transformItem != nil ? Color.camera.multiply(white: 0.5) : Color.subEdit) :
            (animation.transformItem != nil ? Color.camera : Color.contentEdit)
        
        ctx.setFillColor(lineColor.cgColor)
        ctx.fill(CGRect(x: editFrameRateWidth/2 + 1, y: y, width: width - 2, height: h))
        ctx.setFillColor(keyColor.cgColor)
        for (i, keyframe) in animation.keyframes.enumerated() {
            if i > 0 {
                ctx.fill(CGRect(x: keyframe.time.cf*editFrameRateWidth + 1, y: y, width: editFrameRateWidth - 2, height: h))
            }
        }
    }
    func drawAllAnimationKnob(_ cut: Cut, y: CGFloat, in ctx: CGContext) {
        if cut.animations.count > 1 {
            for animation in cut.animations {
                for (i, keyframe) in animation.keyframes.enumerated() {
                    if i > 0 {
                        let x = keyframe.time.cf*editFrameRateWidth + editFrameRateWidth/2
                        ctx.setLineWidth(1)
                        
                        ctx.setLineWidth(1)
                        ctx.setStrokeColor(Color.subEdit.cgColor)
                        ctx.move(to: CGPoint(x: x, y: timeHeight))
                        ctx.addLine(to: CGPoint(x: x, y: y))
                        ctx.strokePath()
                        
                        ctx.setFillColor(Color.content.cgColor)
                        ctx.setStrokeColor(Color.edit.cgColor)
                        ctx.addRect(
                            CGRect(
                                x: x - editFrameRateWidth/2, y: timeHeight - 3 - 2,
                                width: editFrameRateWidth, height: 6
                            ).inset(by: 0.5)
                        )
                        ctx.drawPath(using: .fillStroke)
                    }
                }
            }
        }
    }
    var viewPadding = 4.0.cf
    func drawTime(in ctx: CGContext) {
        let b = ctx.boundingBoxOfClipPath
        let frameMinT = max(time(withX: b.minX), 0), frameMaxT = min(time(withX: b.maxX), maxTime)
        let minT = frameMinT/fps, maxT = frameMaxT/fps
        for i in minT ... maxT {
            let string: String
            if i >= 60 {
                let minute = i / 60
                let second = i - minute*60
                string = String(format: "%d:%02d", minute, second)
            } else {
                string = String(i)
            }
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: [String(kCTFontAttributeName): Font.small.ctFont, String(kCTForegroundColorAttributeName): Color.smallFont.cgColor]))
            let sb = line.typographicBounds
            let tx = x(withTime: i*fps) + editFrameRateWidth/2, ty = bounds.height - timeHeight/2
            let ni1 = i*fps + fps/4, ni2 = i*fps + fps/2, ni3 = i*fps + fps*3/4
            ctx.textPosition = CGPoint(x: tx - sb.width/2 + sb.origin.x, y: ty - sb.height/2 + sb.origin.y)
            CTLineDraw(line, ctx)
            
            ctx.setFillColor(Color.smallFont.multiply(alpha: 0.1).cgColor)
            ctx.fill(CGRect(x: x(withTime: i*fps), y: timeHeight, width: editFrameRateWidth, height: bounds.height - timeHeight*2))
            if ni2 < maxTime {
                ctx.fill(CGRect(x: x(withTime: ni2), y: timeHeight, width: editFrameRateWidth, height: bounds.height - timeHeight*2))
            }
            ctx.setFillColor(Color.smallFont.multiply(alpha: 0.05).cgColor)
            if ni1 < maxTime {
                ctx.fill(CGRect(x: x(withTime: ni1), y: timeHeight, width: editFrameRateWidth, height: bounds.height - timeHeight*2))
            }
            if ni3 < maxTime {
                ctx.fill(CGRect(x: x(withTime: ni3), y: timeHeight, width: editFrameRateWidth, height: bounds.height - timeHeight*2))
            }
        }
    }
    func drawTimeBar(in ctx: CGContext) {
        let x = self.x(withTime: time)
        ctx.setFillColor(Color.translucentBackground.cgColor)
        ctx.fill(CGRect(x: x, y: timeHeight - 2, width: editFrameRateWidth, height: bounds.height - timeHeight*2 + 2*2))
        
        let secondTime = scene.secondTime
        if secondTime.frame != 0 {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: String(secondTime.frame), attributes: [String(kCTFontAttributeName): Font.small.ctFont, String(kCTForegroundColorAttributeName): Color.smallFont.multiply(alpha: 0.2).cgColor]))
            let sb = line.typographicBounds, tx = x + editFrameRateWidth/2, ty = bounds.height - timeHeight/2
            ctx.textPosition = CGPoint(x: tx - sb.width/2 + sb.origin.x, y: ty - sb.height/2 + sb.origin.y)
            CTLineDraw(line, ctx)
        }
    }
    func drawKnob(from p: CGPoint, fillColor: Color, lineColor: Color, in ctx: CGContext) {
        let kh = knobHalfHeight
        ctx.setLineWidth(1)
        ctx.setFillColor(fillColor.cgColor)
        ctx.setStrokeColor(lineColor.cgColor)
        ctx.addRect(CGRect(x: p.x, y: p.y - kh, width: editFrameRateWidth, height: kh*2).inset(by: 0.5))
        ctx.drawPath(using: .fillStroke)
    }
    
    private func registerUndo(_ handler: @escaping (Timeline, Int) -> Void) {
        undoManager?.registerUndo(withTarget: self) { [oldTime = time] in handler($0, oldTime) }
    }
    func setUpdate(_ update: Bool, in cutEntity: CutEntity) {
        cutEntity.isUpdate = update
        setNeedsDisplay()
        canvas.setNeedsDisplay()
    }
    var isUpdate: Bool {
        get {
            return selectionCutEntity.isUpdate
        } set {
            selectionCutEntity.isUpdate = newValue
            setNeedsDisplay()
            canvas.setNeedsDisplay()
        }
    }
    
    func copy(with event: KeyInputEvent) -> CopyObject {
        if let i = cutLabelIndex(at: convertToInternal(point(from: event))) {
            let cut = sceneEntity.cutEntities[i].cut
            return CopyObject(objects: [cut.deepCopy])
        } else {
            return CopyObject()
        }
    }
    func paste(_ copyObject: CopyObject, with event: KeyInputEvent) {
        for object in copyObject.objects {
            if let cut = object as? Cut {
                let index = cutIndex(withX: convertToInternal(point(from: event)).x)
                insertCutEntity(CutEntity(cut: cut), at: index + 1, time: time)
                setTime(cutTimeLocation(withCutIndex: index + 1), oldTime: time)
                return
            }
        }
    }
    
    func delete(with event: KeyInputEvent) {
        if let i = cutLabelIndex(at: convertToInternal(point(from: event))) {
            removeCut(at: i)
        } else {
            removeKeyframe(with: event)
        }
    }
    
    func moveToPrevious(with event: KeyInputEvent) {
        let cut = selectionCutEntity.cut
        let animation = cut.editAnimation
        let loopedIndex = animation.loopedKeyframeIndex(withTime: cut.time).loopedIndex
        let keyframeIndex = animation.loopedKeyframeIndexes[loopedIndex]
        if cut.time - keyframeIndex.time > 0 {
            updateTime(withCutTime: keyframeIndex.time)
        } else if loopedIndex - 1 >= 0 {
            updateTime(withCutTime: animation.loopedKeyframeIndexes[loopedIndex - 1].time)
        } else if selectionCutIndex - 1 >= 0 {
            selectionCutIndex -= 1
            updateTime(withCutTime: selectionCutEntity.cut.editAnimation.lastLoopedKeyframeTime)
        }
        canvas.updateEditView(with: event.location)
    }
    func moveToNext(with event: KeyInputEvent) {
        let cut = selectionCutEntity.cut
        let animation = cut.editAnimation
        let loopedIndex = animation.loopedKeyframeIndex(withTime: cut.time).loopedIndex
        if loopedIndex + 1 <= animation.loopedKeyframeIndexes.count - 1 {
            let t = animation.loopedKeyframeIndexes[loopedIndex + 1].time
            if t < animation.timeLength {
                updateTime(withCutTime: t)
                return
            }
        }
        if selectionCutIndex + 1 <= sceneEntity.cutEntities.count - 1 {
            selectionCutIndex += 1
            updateTime(withCutTime: 0)
        }
        canvas.updateEditView(with: event.location)
    }
    func moveToPreviousFrame() {
        let cut = selectionCutEntity.cut
        if cut.time - 1 >= 0 {
            updateTime(withCutTime: cut.time - 1)
        } else if selectionCutIndex - 1 >= 0 {
            selectionCutIndex -= 1
            updateTime(withCutTime: selectionCutEntity.cut.timeLength - 1)
        }
    }
    func moveToNextFrame() {
        let cut = selectionCutEntity.cut
        if cut.time + 1 < cut.timeLength {
            updateTime(withCutTime: cut.time + 1)
        } else if selectionCutIndex + 1 <= sceneEntity.cutEntities.count - 1 {
            selectionCutIndex += 1
            updateTime(withCutTime: 0)
        }
    }
    func play(with event: KeyInputEvent) {
        canvas.play(with: event)
    }
    
    func hide(with event: KeyInputEvent) {
        let animation = selectionCutEntity.cut.editAnimation
        if !animation.isHidden {
            setIsHidden(true, in: animation, time: time)
        }
    }
    func show(with event: KeyInputEvent) {
        let animation = selectionCutEntity.cut.editAnimation
        if animation.isHidden {
            setIsHidden(false, in: animation, time: time)
        }
    }
    func setIsHidden(_ isHidden: Bool, in animation: Animation, time: Int) {
        registerUndo { [oldHidden = animation.isHidden] in $0.setIsHidden(oldHidden, in: animation, time: $1) }
        self.time = time
        animation.isHidden = isHidden
        isUpdate = true
        layer.setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
        sceneEditor.timeline.setNeedsDisplay()
    }
    
    func newCut() {
        insertCutEntity(CutEntity(), at: selectionCutIndex + 1, time: time)
        setTime(cutTimeLocation(withCutIndex: selectionCutIndex + 1), oldTime: time)
    }
    func insertCutEntity(_ cutEntity: CutEntity, at index: Int, time: Int) {
        registerUndo { $0.removeCutEntity(at: index, time: $1) }
        self.time = time
        sceneEntity.insert(cutEntity, at: index)
        updateCanvassPosition()
        updateMaxTime()
    }
    func removeCutEntity(at index: Int, time: Int) {
        let cutEntity = sceneEntity.cutEntities[index]
        registerUndo { $0.insertCutEntity(cutEntity, at: index, time: $1) }
        self.time = time
        sceneEntity.removeCutEntity(at: index)
        updateCanvassPosition()
        updateMaxTime()
    }
    
    func newAnimation() {
        let animation = Animation(timeLength: selectionCutEntity.cut.timeLength)
        insertAnimation(animation, at: selectionCutEntity.cut.editAnimationIndex + 1, time: time)
        setEditAnimation(animation, oldEditAnimation: selectionCutEntity.cut.editAnimation, time: time)
    }
    func removeAnimation(at index: Int, in cutEntity: CutEntity) {
        if cutEntity.cut.animations.count > 1 {
            let oldAnimation = cutEntity.cut.animations[index]
            removeAnimationAtIndex(index, time: time)
            setEditAnimation(cutEntity.cut.animations[max(0, index - 1)], oldEditAnimation: oldAnimation, time: time)
        }
    }
    func insertAnimation(_ animation: Animation, at index: Int, time: Int) {
        registerUndo { $0.removeAnimationAtIndex(index, time: $1) }
        self.time = time
        selectionCutEntity.cut.animations.insert(animation, at: index)
        isUpdate = true
    }
    func removeAnimationAtIndex(_ index: Int, time: Int) {
        registerUndo { [og = selectionCutEntity.cut.animations[index]] in $0.insertAnimation(og, at: index, time: $1) }
        self.time = time
        selectionCutEntity.cut.animations.remove(at: index)
        isUpdate = true
    }
    private func setEditAnimation(_ editAnimation: Animation, oldEditAnimation: Animation, time: Int) {
        registerUndo { $0.setEditAnimation(oldEditAnimation, oldEditAnimation: editAnimation, time: $1) }
        self.time = time
        selectionCutEntity.cut.editAnimation = editAnimation
        isUpdate = true
        sceneEditor.keyframeEditor.update()
        sceneEditor.cameraEditor.update()
        sceneEditor.speechEditor.update()
    }
    
    func newKeyframe() {
        splitKeyframe(with: editAnimation)
    }
    func splitKeyframe(with animation: Animation, isSplitDrawing: Bool = false) {
        let cutTime = self.cutTime
        let ki = Keyframe.index(time: cutTime, with: animation.keyframes)
        if ki.interValue > 0 {
            let k = animation.keyframes[ki.index]
            let newEaing = ki.sectionValue != 0 ? k.easing.split(with: ki.interValue.cf/ki.sectionValue.cf) : (b0: k.easing, b1: Easing())
            let splitKeyframe0 = Keyframe(time: k.time, easing: newEaing.b0, interpolation: k.interpolation, loop: k.loop)
            let splitKeyframe1 = Keyframe(time: cutTime, easing: newEaing.b1, interpolation: k.interpolation)
            let values = animation.currentItemValues
            replaceKeyframe(splitKeyframe0, at: ki.index, in: animation, time: time)
            insertKeyframe(
                keyframe: splitKeyframe1,
                drawing: isSplitDrawing ? values.drawing.deepCopy : Drawing(), geometries: values.geometries, materials: values.materials,
                transform: values.transform, text: values.text,
                at: ki.index + 1, in: animation, time: time
            )
        }
    }
    func removeKeyframe(with event: KeyInputEvent) {
        let ki = nearestKeyframeIndexTuple(at: convertToInternal(point(from: event)))
        let cutEntity =  sceneEntity.cutEntities[ki.cutIndex]
        let animation = cutEntity.cut.editAnimation
        if ki.cutIndex == 0 && ki.keyframeIndex == 0 && animation.keyframes.count >= 2 {
            removeFirstKeyframe(atCutIndex: ki.cutIndex)
        } else if
            ki.cutIndex + 1 < sceneEntity.cutEntities.count && ki.keyframeIndex == nil &&
                sceneEntity.cutEntities[ki.cutIndex + 1].cut.editAnimation.keyframes.count >= 2 {
            removeFirstKeyframe(atCutIndex: ki.cutIndex + 1)
        } else if animation.keyframes.count <= 1 || ki.keyframeIndex == nil {
            if selectionCutEntity.cut.animations.count <= 1 {
                removeCut(at: ki.keyframeIndex == nil ? ki.cutIndex + 1 : ki.cutIndex)
            } else {
                removeAnimation(at: cutEntity.cut.editAnimationIndex, in: cutEntity)
            }
        } else if let ki = ki.keyframeIndex {
            removeKeyframe(at: ki, in: animation, time: time)
        }
    }
    private func removeFirstKeyframe(atCutIndex cutIndex: Int) {
        let cutEntity = sceneEntity.cutEntities[cutIndex]
        let animation = cutEntity.cut.editAnimation
        let deltaTime = animation.keyframes[1].time
        removeKeyframe(at: 0, in: animation, time: time)
        let keyframes = animation.keyframes.map { $0.withTime($0.time - deltaTime) }
        setKeyframes(keyframes, oldKeyframes: animation.keyframes, in: animation, cutEntity, time: time)
    }
    func removeCut(at i: Int) {
        if i == 0 {
            setTime(time, oldTime: time, alwaysUpdateCutIndex: true)
            removeCutEntity(at: 0, time: time)
            if sceneEntity.cutEntities.count == 0 {
                insertCutEntity(CutEntity(), at: 0, time: time)
            }
            setTime(0, oldTime: time, alwaysUpdateCutIndex: true)
        } else {
            let previousCut = sceneEntity.cutEntities[i - 1].cut
            let previousCutTimeLocation = cutTimeLocation(withCutIndex: i - 1)
            let isSetTime = i == selectionCutIndex
            setTime(time, oldTime: time, alwaysUpdateCutIndex: true)
            removeCutEntity(at: i, time: time)
            if isSetTime {
                setTime(previousCutTimeLocation + previousCut.editAnimation.lastKeyframeTime, oldTime: time, alwaysUpdateCutIndex: true)
            } else if time >= maxTime {
                setTime(maxTime - 1, oldTime: time, alwaysUpdateCutIndex: true)
            }
        }
    }
    private func setKeyframes(_ keyframes: [Keyframe], oldKeyframes: [Keyframe], in animation: Animation, _ cutEntity: CutEntity, time: Int) {
        registerUndo { $0.setKeyframes(oldKeyframes, oldKeyframes: keyframes, in: animation, cutEntity, time: $1) }
        self.time = time
        animation.replaceKeyframes(keyframes)
        setUpdate(true, in: cutEntity)
    }
    private func setTime(_ t: Int, oldTime: Int, alwaysUpdateCutIndex: Bool = false) {
        registerUndo { $0.0.setTime(oldTime, oldTime: t, alwaysUpdateCutIndex: alwaysUpdateCutIndex) }
        updateWith(time: t, scrollPoint: CGPoint(x: x(withTime: t), y: 0), alwaysUpdateCutIndex: alwaysUpdateCutIndex)
        setUpdate(true, in: selectionCutEntity)
    }
    private func replaceKeyframe(_ keyframe: Keyframe, at index: Int, in animation: Animation, time: Int) {
        registerUndo { [ok = animation.keyframes[index]] in $0.replaceKeyframe(ok, at: index, in: animation, time: $1) }
        self.time = time
        animation.replaceKeyframe(keyframe, at: index)
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        isUpdate = true
    }
    private func insertKeyframe(
        keyframe: Keyframe,
        drawing: Drawing, geometries: [Geometry], materials: [Material],
        transform: Transform?, text: Text?,
        at index: Int, in animation: Animation, time: Int
    ) {
        registerUndo { $0.removeKeyframe(at: index, in: animation, time: $1) }
        self.time = time
        animation.insertKeyframe(
            keyframe,
            drawing: drawing, geometries: geometries, materials: materials, transform: transform, text: text,
            at: index
        )
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        isUpdate = true
    }
    private func removeKeyframe(at index: Int, in animation: Animation, time: Int) {
        registerUndo { [ok = animation.keyframes[index], okv = animation.keyframeItemValues(at: index)] in
            $0.insertKeyframe(
                keyframe: ok,
                drawing: okv.drawing, geometries: okv.geometries, materials: okv.materials,
                transform: okv.transform, text: okv.text,
                at: index, in: animation, time: $1
            )
        }
        self.time = time
        animation.removeKeyframe(at: index)
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        isUpdate = true
    }
    private var previousTime: Int? {
        let cut = selectionCutEntity.cut
        let animation = cut.editAnimation
        let keyframeIndex = animation.loopedKeyframeIndex(withTime: cut.time)
        let t = animation.loopedKeyframeIndexes[keyframeIndex.loopedIndex].time
        if cutTime - t > 0 {
            return cutTimeLocation(withCutIndex: selectionCutIndex) + t
        } else if keyframeIndex.loopedIndex - 1 >= 0 {
            return cutTimeLocation(withCutIndex: selectionCutIndex) + animation.loopedKeyframeIndexes[keyframeIndex.loopedIndex - 1].time
        } else if selectionCutIndex - 1 >= 0 {
            return cutTimeLocation(withCutIndex: selectionCutIndex - 1) + sceneEntity.cutEntities[selectionCutIndex - 1].cut.editAnimation.lastLoopedKeyframeTime
        } else {
            return nil
        }
    }
    
    private var isDrag = false, dragOldTime = 0.0.cf, editCutEntity: CutEntity?
    private var dragOldCutTimeLength = 0, dragMinDeltaTime = 0, dragMinCutDeltaTime = 0
    private var dragOldSlideAnimations = [(animation: Animation, keyframeIndex: Int, oldKeyframes: [Keyframe])]()
    func drag(with event: DragEvent) {
        let p = convertToInternal(point(from: event))
        switch event.sendType {
        case .begin:
            let cutEntity = sceneEntity.cutEntities[cutIndex(withX: p.x)]
            if p.y > bounds.height/2 - (bounds.height/4 - timeHeight/2 - 1) || cutEntity.cut.animations.count == 1 {
                let result = nearestKeyframeIndexTuple(at: p)
                let editCutEntity = sceneEntity.cutEntities[result.cutIndex]
                let animation = editCutEntity.cut.editAnimation
                if let ki = result.keyframeIndex {
                    if ki > 0 {
                        let preTime = animation.keyframes[ki - 1].time, time = animation.keyframes[ki].time
                        dragMinDeltaTime = preTime - time + 1
                        dragOldSlideAnimations = [(animation, ki, animation.keyframes)]
                    }
                } else {
                    let preTime = animation.keyframes[animation.keyframes.count - 1].time, time = editCutEntity.cut.timeLength
                    dragMinDeltaTime = preTime - time + 1
                    dragOldSlideAnimations = []
                }
                dragMinCutDeltaTime = max(editCutEntity.cut.maxTimeWithOtherAnimation(animation) - editCutEntity.cut.timeLength + 1, dragMinDeltaTime)
                self.editCutEntity = result.cutIndex == 0 && result.keyframeIndex == 0 ? nil : editCutEntity
                dragOldCutTimeLength = editCutEntity.cut.timeLength
            } else {
                let result = animationIndexTuple(at: p)
                let editCutEntity = sceneEntity.cutEntities[result.cutIndex]
                let minAnimation = editCutEntity.cut.animations[result.animationIndex]
                if let ki = result.keyframeIndex {
                    if ki > 0 {
                        let kt = minAnimation.keyframes[ki].time
                        var oldSlideAnimations = [(animation: Animation, keyframeIndex: Int, oldKeyframes: [Keyframe])](), pkt = 0
                        for animation in editCutEntity.cut.animations {
                            let result = Keyframe.index(time: kt, with: animation.keyframes)
                            let index: Int? = result.interValue > 0 ? (result.index + 1 <= animation.keyframes.count - 1 ? result.index + 1 : nil) : result.index
                            if let i = index {
                                oldSlideAnimations.append((animation, i, animation.keyframes))
                            }
                            let preIndex: Int? = result.interValue > 0 ?  result.index : (result.index > 0 ? result.index - 1 : nil)
                            if let pi = preIndex {
                                let preTime = animation.keyframes[pi].time
                                if pkt < preTime {
                                    pkt = preTime
                                }
                            }
                        }
                        dragMinDeltaTime = pkt - kt + 1
                        dragOldSlideAnimations = oldSlideAnimations
                    }
                } else {
                    let preTime = minAnimation.keyframes[minAnimation.keyframes.count - 1].time, time = editCutEntity.cut.timeLength
                    dragMinDeltaTime = preTime - time + 1
                    dragOldSlideAnimations = []
                }
                dragMinCutDeltaTime = dragMinDeltaTime
                self.editCutEntity = result.cutIndex == 0 && result.keyframeIndex == 0 ? nil : editCutEntity
                dragOldCutTimeLength = editCutEntity.cut.timeLength
            }
            dragOldTime = p.x/editFrameRateWidth
            isDrag = false
        case .sending:
            isDrag = true
            if let editCutEntity = editCutEntity {
                let t = convertToInternal(point(from: event)).x/editFrameRateWidth
                let dt = Int(t - dragOldTime + (t - dragOldTime >= 0 ? 0.5 : -0.5))
                let deltaTime = max(dragMinDeltaTime, dt)
                for slideAnimation in dragOldSlideAnimations {
                    var nks = slideAnimation.oldKeyframes
                    for i in slideAnimation.keyframeIndex ..< nks.count {
                        nks[i] = nks[i].withTime(nks[i].time + deltaTime)
                    }
                    slideAnimation.animation.replaceKeyframes(nks)
                }
                let animationTimeLength = dragOldCutTimeLength + max(dragMinCutDeltaTime, dt)
                if animationTimeLength != editCutEntity.cut.timeLength {
                    editCutEntity.cut.timeLength = animationTimeLength
                    updateMaxTime()
                }
                updateView()
                setNeedsDisplay()
            }
        case .end:
            if isDrag, let editCutEntity = editCutEntity {
                setTime(time, oldTime: time)
                let t = convertToInternal(point(from: event)).x/editFrameRateWidth
                let dt = Int(t - dragOldTime + (t - dragOldTime >= 0 ? 0.5 : -0.5))
                let deltaTime = max(dragMinDeltaTime, dt)
                for slideAnimation in dragOldSlideAnimations {
                    var nks = slideAnimation.oldKeyframes
                    if deltaTime != 0 {
                        for i in slideAnimation.keyframeIndex ..< nks.count {
                            nks[i] = nks[i].withTime(nks[i].time + deltaTime)
                        }
                        setKeyframes(nks, oldKeyframes: slideAnimation.oldKeyframes, in: slideAnimation.animation, editCutEntity, time: time)
                    } else {
                        slideAnimation.animation.replaceKeyframes(nks)
                    }
                }
                let timeLength = dragOldCutTimeLength + max(dragMinCutDeltaTime, dt)
                if timeLength != dragOldCutTimeLength {
                    setTimeLength(timeLength, oldTimeLength: dragOldCutTimeLength, in: editCutEntity, time: time)
                }
                setTime(time, oldTime: time)
                dragOldSlideAnimations = []
                self.editCutEntity = nil
            }
        }
    }
    private func setTimeLength(_ timeLength: Int, oldTimeLength: Int, in cutEntity: CutEntity, time: Int) {
        registerUndo { $0.setTimeLength(oldTimeLength, oldTimeLength: timeLength, in: cutEntity, time: $1) }
        self.time = time
        cutEntity.cut.timeLength = timeLength
        setUpdate(true, in: cutEntity)
        updateMaxTime()
    }
    
    let itemHeight = 8.0.cf
    private var oldIndex = 0, oldP = CGPoint()
    var moveQuasimode = false
    var oldAnimations = [Animation]()
    func move(with event: DragEvent) {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            oldAnimations = selectionCutEntity.cut.animations
            oldIndex = selectionCutEntity.cut.editAnimationIndex
            oldP = p
            editCutEntity = selectionCutEntity
        case .sending:
            if let cutEntity = editCutEntity {
                let d = p.y - oldP.y
                let i = (oldIndex + Int(d/itemHeight)).clip(min: 0, max: cutEntity.cut.animations.count), oi = cutEntity.cut.editAnimationIndex
                cutEntity.cut.animations.remove(at: oi)
                cutEntity.cut.animations.insert(cutEntity.cut.editAnimation, at: oi < i ? i - 1 : i)
                layer.setNeedsDisplay()
                sceneEditor.canvas.setNeedsDisplay()
                sceneEditor.timeline.setNeedsDisplay()
                sceneEditor.keyframeEditor.update()
                sceneEditor.cameraEditor.update()
            }
        case .end:
            if let cutEntity = editCutEntity {
                let d = p.y - oldP.y
                let i = (oldIndex + Int(d/itemHeight)).clip(min: 0, max: cutEntity.cut.animations.count), oi = cutEntity.cut.editAnimationIndex
                if oldIndex != i {
                    var animations = cutEntity.cut.animations
                    animations.remove(at: oi)
                    animations.insert(cutEntity.cut.editAnimation, at: oi < i ? i - 1 : i)
                    setAnimations(animations, oldAnimations: oldAnimations, in: cutEntity, time: time)
                } else if oi != i {
                    cutEntity.cut.animations.remove(at: oi)
                    cutEntity.cut.animations.insert(cutEntity.cut.editAnimation, at: oi < i ? i - 1 : i)
                    layer.setNeedsDisplay()
                    sceneEditor.canvas.setNeedsDisplay()
                    sceneEditor.timeline.setNeedsDisplay()
                    sceneEditor.keyframeEditor.update()
                    sceneEditor.cameraEditor.update()
                }
                oldAnimations = []
                editCutEntity = nil
            }
        }
    }
    private func setEditAnimation(_ animation: Animation, oldAnimation: Animation, in cutEntity: CutEntity, time: Int) {
        registerUndo { $0.setEditAnimation(oldAnimation, oldAnimation: animation, in: cutEntity, time: $1) }
        self.time = time
        cutEntity.cut.editAnimation = animation
        setUpdate(true, in: cutEntity)
        layer.setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
        sceneEditor.timeline.setNeedsDisplay()
        sceneEditor.keyframeEditor.update()
        sceneEditor.cameraEditor.update()
    }
    private func setAnimations(_ animations: [Animation], oldAnimations: [Animation], in cutEntity: CutEntity, time: Int) {
        registerUndo { $0.setAnimations(oldAnimations, oldAnimations: animations, in: cutEntity, time: $1) }
        self.time = time
        cutEntity.cut.animations = animations
        setUpdate(true, in: cutEntity)
        layer.setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
        sceneEditor.timeline.setNeedsDisplay()
        sceneEditor.keyframeEditor.update()
        sceneEditor.cameraEditor.update()
    }
    
    func select(_ event: DragEvent, type: Action.SendType) {
    }
    
    private var isAnimationScroll = false, deltaScrollY = 0.0.cf, scrollCutEntity: CutEntity?
    func scroll(with event: ScrollEvent) {
        scroll(with: event, isUseMomentum: true)
    }
    func scroll(with event: ScrollEvent, isUseMomentum: Bool) {
        if event.sendType  == .begin {
            isAnimationScroll = selectionCutEntity.cut.animations.count == 1 ? false : abs(event.scrollDeltaPoint.x) < abs(event.scrollDeltaPoint.y)
        }
        if isAnimationScroll {
            if event.scrollMomentumType == nil {
                let p = point(from: event)
                switch event.sendType {
                case .begin:
                    oldIndex = selectionCutEntity.cut.editAnimationIndex
                    oldP = p
                    deltaScrollY = 0
                    scrollCutEntity = selectionCutEntity
                case .sending:
                    if let scrollCutEntity = scrollCutEntity {
                        deltaScrollY += event.scrollDeltaPoint.y
                        let i = (oldIndex + Int(deltaScrollY/10)).clip(min: 0, max: scrollCutEntity.cut.animations.count - 1)
                        if scrollCutEntity.cut.editAnimationIndex != i {
                            scrollCutEntity.cut.editAnimation = scrollCutEntity.cut.animations[i]
                            updateView()
                        }
                    }
                case .end:
                    if let scrollCutEntity = scrollCutEntity {
                        let i = (oldIndex + Int(deltaScrollY/10)).clip(min: 0, max: scrollCutEntity.cut.animations.count - 1)
                        if oldIndex != i {
                            setEditAnimation(scrollCutEntity.cut.animations[i], oldAnimation: scrollCutEntity.cut.animations[oldIndex], in: scrollCutEntity, time: time)
                        } else if scrollCutEntity.cut.editAnimationIndex != i {
                            scrollCutEntity.cut.editAnimation = scrollCutEntity.cut.animations[i]
                            updateView()
                        }
                        self.scrollCutEntity = nil
                    }
                }
            }
        } else {
            if event.sendType == .begin && canvas.player.isPlaying {
                canvas.player.layer.opacity = 0.2
            } else if event.sendType == .end && canvas.player.layer.opacity != 1 {
                canvas.player.layer.opacity = 1
            }
            let x = (scrollPoint.x - event.scrollDeltaPoint.x).clip(min: 0, max: self.x(withTime: maxTime - 1))
            scrollPoint = CGPoint(x: event.sendType == .begin ? self.x(withTime: time(withX: x)) : x, y: 0)
        }
    }
    func zoom(with event: PinchEvent) {
        zoom(at: point(from: event)) {
            editFrameRateWidth = (editFrameRateWidth*(event.magnification*2.5 + 1)).clip(min: 1, max: Timeline.defaultFrameRateWidth)
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
