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
        description: Localization(english: "Timeline for scene", japanese: "シーン用タイムライン")
    )
    let newCutButton = Button(
        frame: SceneEditor.Layout.timelineNewCutFrame,
        name: Localization(english: "New Cut", japanese: "新規カット")
    )
    let splitKeyframeButton = Button(
        frame: SceneEditor.Layout.timelineNewKeyframeFrame,
        name: Localization(english: "New Keyframe", japanese: "新規キーフレーム")
    )
    let newAnimationButton = Button(
        frame: SceneEditor.Layout.timelineNewAnimationFrame,
        name: Localization(english: "New Animation", japanese: "新規アニメーション")
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
    
    var scene = Scene() {
        didSet {
            updateWith(time: scene.time, scrollPoint: CGPoint(x: x(withTime: scene.time), y: 0))
        }
    }
    var editCutItemIndex: Int {
        get {
            return scene.editCutItemIndex
        } set {
            scene.editCutItemIndex = newValue
            sceneEditor.canvas.cutItem = scene.editCutItem
            sceneEditor.keyframeEditor.update()
            sceneEditor.cameraEditor.update()
            sceneEditor.speechEditor.update()
            setNeedsDisplay()
        }
    }
    static let defaultFrameRateWidth = 6.0.cf, defaultTimeHeight = 18.0.cf
    var editFrameRateWidth = Timeline.defaultFrameRateWidth, timeHeight = defaultTimeHeight
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
            let newTime = time(withX: newValue.x)
            if newTime != scene.time {
                updateWith(time: newTime, scrollPoint: newValue)
            } else {
                _scrollPoint = newValue
            }
        }
    }
    var time: Int {
        get {
            return scene.time
        } set {
            if newValue != scene.time {
                updateWith(time: newValue, scrollPoint: CGPoint(x: x(withTime: newValue), y: 0))
            }
        }
    }
    private func updateWith(time: Int, scrollPoint: CGPoint, alwaysUpdateCutIndex: Bool = false) {
        let oldTime = sceneEditor.scene.time
        scene.time = time
        _scrollPoint = scrollPoint
        _intervalScrollPoint = intervalScrollPoint(with: _scrollPoint)
        if time != oldTime {
            sceneEditor.scene.time = time
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
        sceneEditor.canvas.updateViewAffineTransform()//sceneEditor.canvas.setNeedsDisplay()
        sceneEditor.keyframeEditor.update()
        sceneEditor.cameraEditor.update()
        sceneEditor.speechEditor.update()
    }
    func updateTime(withCutTime cutTime: Int) {
        _scrollPoint.x = x(withTime: cutTime + scene.cutItems[scene.editCutItemIndex].time)
        let t = time(withX: scrollPoint.x)
        time = t
        _intervalScrollPoint.x = x(withTime: t)
    }
    private func intervalScrollPoint(with scrollPoint: CGPoint) -> CGPoint {
        return CGPoint(x: x(withTime: time(withX: scrollPoint.x)), y: 0)
    }
    
    var contentFrame: CGRect {
        return CGRect(x: _scrollPoint.x, y: 0, width: x(withTime: scene.timeLength), height: 0)
    }
    func time(withX x: CGFloat) -> Int {
        return Int(x/editFrameRateWidth)
    }
    func x(withTime time: Int) -> CGFloat {
        return time.cf*editFrameRateWidth
    }
    func cutIndex(withX x: CGFloat) -> Int {
        return scene.cutItemIndex(withTime: time(withX: x)).index
    }
    func cutLabelIndex(at p: CGPoint) -> Int? {
        let time = self.time(withX: p.x)
        var t = 0
        for (i, cutItem) in scene.cutItems.enumerated() {
            let nt = t + cutItem.cut.timeLength
            if time < nt {
                func cutIndex(with x: CGFloat) -> Bool {
                    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "C\(i + 1)", attributes: [String(kCTFontAttributeName): Font.small.ctFont, String(kCTForegroundColorAttributeName): Color.smallFont.cgColor]))
                    let sb = line.typographicBounds
                    let nsb = CGRect(
                        x: x + editFrameRateWidth/2 - sb.width/2 + sb.origin.x, y: timeHeight/2 - sb.height/2 + sb.origin.y,
                        width: sb.width, height: sb.height
                    )
                    return nsb.contains(p)
                }
                if cutIndex(with: x(withTime: t)) {
                    return i
                } else if cutIndex(with: x(withTime: nt)) {
                    return i + 1
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
        let cut = scene.cutItems[ci].cut, ct = scene.cutItems[ci].time
        if cut.editAnimation.keyframes.count == 0 {
            return (ci, nil)
        } else {
            var minD = CGFloat.infinity, minI = 0
            for (i, k) in cut.editAnimation.keyframes.enumerated() {
                let x = (ct + k.time).cf*editFrameRateWidth
                let d = abs(p.x - x)
                if d < minD {
                    minI = i
                    minD = d
                }
            }
            let x = (ct + cut.timeLength).cf*editFrameRateWidth
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
        let cut = scene.cutItems[ci].cut, ct = scene.cutItems[ci].time
        var minD = CGFloat.infinity, minKeyframeIndex = 0, minAnimationIndex = 0
        for (ii, animation) in cut.animations.enumerated() {
            for (i, k) in animation.keyframes.enumerated() {
                let x = (ct + k.time).cf*editFrameRateWidth
                let d = abs(p.x - x)
                if d < minD {
                    minAnimationIndex = ii
                    minKeyframeIndex = i
                    minD = d
                }
            }
        }
        let x = (ct + cut.timeLength).cf*editFrameRateWidth
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
        for (i, cutItem) in scene.cutItems.enumerated() {
            let w = cutItem.cut.timeLength.cf*editFrameRateWidth
            if b.minX <= x + w && b.maxX >= x {
                let index = cutItem.cut.editAnimationIndex, h = 2.0.cf
                let cutKnobBounds = self.cutKnobBounds(with: cutItem.cut).insetBy(dx: 0, dy: 1)
                if index == 0 {
                    drawAllAnimationKnob(cutItem.cut, y: bounds.height/2, in: ctx)
                } else {
                    var y = bounds.height/2 + knobHalfHeight
                    for _ in (0 ..< index).reversed() {
                        y += 1 + h
                        if y >= cutKnobBounds.maxY {
                            y = cutKnobBounds.maxY
                            break
                        }
                    }
                    drawAllAnimationKnob(cutItem.cut, y: y, in: ctx)
                }
                
                var y = bounds.height/2 + knobHalfHeight + 1
                for i in (0 ..< index).reversed() {
                    drawNotSelectedAnimationWith(animation: cutItem.cut.animations[i], width: w, y: y, h: h, in: ctx)
                    y += 1 + h
                    if y >= cutKnobBounds.maxY {
                        break
                    }
                }
                y = bounds.height/2 - knobHalfHeight - 1
                if index + 1 < cutItem.cut.animations.count {
                    for i in index + 1 ..< cutItem.cut.animations.count {
                        drawNotSelectedAnimationWith(animation: cutItem.cut.animations[i], width: w, y: y - h, h:h, in: ctx)
                        y -= 1 + h
                        if y <= cutKnobBounds.minY {
                            break
                        }
                    }
                }
                drawAnimation(cutItem.cut.editAnimation, cut: cutItem.cut, y: bounds.height/2, isOther: false, in: ctx)
                drawCutItem(cutItem, index: i, in: ctx)
            }
            ctx.translateBy(x: w, y: 0)
            x += w
        }
        ctx.restoreGState()
        
        ctx.setLineWidth(2)
        ctx.setStrokeColor(Color.contentEdit.cgColor)
        ctx.move(to: CGPoint(x: x + editFrameRateWidth/2, y: timeHeight))
        ctx.addLine(to: CGPoint(x: x + editFrameRateWidth/2, y: bounds.height - timeHeight))
        ctx.strokePath()
        drawKnob(from: CGPoint(x: x, y: bounds.height/2), fillColor: Color.content, lineColor: Color.edit, in: ctx)
    }
    func cutKnobBounds(with cut: Cut) -> CGRect {
        return CGRect(
            x: cut.timeLength.cf*editFrameRateWidth, y: timeHeight + 2,
            width: editFrameRateWidth, height: bounds.height - timeHeight*2 - 2*2
        )
    }
    
    func drawCutItem(_ cutItem: CutItem, index: Int, in ctx: CGContext) {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: "C\(index + 1)", attributes: [String(kCTFontAttributeName): Font.small.ctFont, String(kCTForegroundColorAttributeName): Color.smallFont.cgColor]))
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
        let bounds = ctx.boundingBoxOfClipPath
        let frameMinT = time(withX: bounds.minX), frameMaxT = time(withX: bounds.maxX)
        let minT = frameMinT/scene.frameRate - 1, maxT = frameMaxT/scene.frameRate
        guard minT < maxT else {
            return
        }
        for i in minT ... maxT {
            let string: String
            if i >= 60 {
                let minute = i / 60
                let second = i - minute*60
                string = String(format: "%d:%02d", minute, second)
            } else {
                string = String(i)
            }
            
            let textLine = TextLine(
                string: string, font: Font.small, color: Color.smallFont,
                isHorizontalCenter: true, isVerticalCenter: true
            )
            let sb = textLine.stringBounds
            let textBounds = CGRect(
                x: x(withTime: i*scene.frameRate) + editFrameRateWidth/2 - sb.width/2 + sb.origin.x,
                y: bounds.height - timeHeight/2 - sb.height/2 + sb.origin.y,
                width: sb.width, height: sb.height
            )
            textLine.draw(in: textBounds, in: ctx)
            
            ctx.setFillColor(Color.smallFont.multiply(alpha: 0.1).cgColor)
            ctx.fill(CGRect(x: x(withTime: i*scene.frameRate), y: timeHeight, width: editFrameRateWidth, height: bounds.height - timeHeight*2))
            let ni1 = i*scene.frameRate + scene.frameRate/4
            let ni2 = i*scene.frameRate + scene.frameRate/2
            let ni3 = i*scene.frameRate + scene.frameRate*3/4
            ctx.fill(CGRect(x: x(withTime: ni2), y: timeHeight, width: editFrameRateWidth, height: bounds.height - timeHeight*2))
            ctx.setFillColor(Color.smallFont.multiply(alpha: 0.05).cgColor)
            ctx.fill(CGRect(x: x(withTime: ni1), y: timeHeight, width: editFrameRateWidth, height: bounds.height - timeHeight*2))
            ctx.fill(CGRect(x: x(withTime: ni3), y: timeHeight, width: editFrameRateWidth, height: bounds.height - timeHeight*2))
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
    
    func copy(with event: KeyInputEvent) -> CopyObject {
        if let i = cutLabelIndex(at: convertToInternal(point(from: event))) {
            let cut = scene.cutItems[i].cut
            return CopyObject(objects: [cut.deepCopy])
        } else {
            return CopyObject()
        }
    }
    func paste(_ copyObject: CopyObject, with event: KeyInputEvent) {
        for object in copyObject.objects {
            if let cut = object as? Cut {
                let index = cutIndex(withX: convertToInternal(point(from: event)).x)
                insertCutItem(CutItem(cut: cut), at: index + 1, time: time)
                let nextCutItem = scene.cutItems[index + 1]
                setTime(nextCutItem.time + nextCutItem.cut.time, oldTime: time)
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
        let cut = scene.editCutItem.cut
        let animation = cut.editAnimation
        let loopedIndex = animation.loopedKeyframeIndex(withTime: cut.time).loopedIndex
        let keyframeIndex = animation.loopedKeyframeIndexes[loopedIndex]
        if cut.time - keyframeIndex.time > 0 {
            updateTime(withCutTime: keyframeIndex.time)
        } else if loopedIndex - 1 >= 0 {
            updateTime(withCutTime: animation.loopedKeyframeIndexes[loopedIndex - 1].time)
        } else if scene.editCutItemIndex - 1 >= 0 {
            self.editCutItemIndex -= 1
            updateTime(withCutTime: scene.editCutItem.cut.editAnimation.lastLoopedKeyframeTime)
        }
        sceneEditor.canvas.updateEditView(with: event.location)
    }
    func moveToNext(with event: KeyInputEvent) {
        let cut = scene.editCutItem.cut
        let animation = cut.editAnimation
        let loopedIndex = animation.loopedKeyframeIndex(withTime: cut.time).loopedIndex
        if loopedIndex + 1 <= animation.loopedKeyframeIndexes.count - 1 {
            let t = animation.loopedKeyframeIndexes[loopedIndex + 1].time
            if t < animation.timeLength {
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
    
    func hide(with event: KeyInputEvent) {
        let animation = scene.editCutItem.cut.editAnimation
        if !animation.isHidden {
            setIsHidden(true, in: animation, time: time)
        }
    }
    func show(with event: KeyInputEvent) {
        let animation = scene.editCutItem.cut.editAnimation
        if animation.isHidden {
            setIsHidden(false, in: animation, time: time)
        }
    }
    func setIsHidden(_ isHidden: Bool, in animation: Animation, time: Int) {
        registerUndo { [oldHidden = animation.isHidden] in $0.setIsHidden(oldHidden, in: animation, time: $1) }
        self.time = time
        animation.isHidden = isHidden
        scene.editCutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
    }
    
    func newCut() {
        insertCutItem(CutItem(), at: scene.editCutItemIndex + 1, time: time)
        let nextCutItem = scene.cutItems[scene.editCutItemIndex + 1]
        setTime(nextCutItem.time + nextCutItem.cut.time, oldTime: time)
    }
    func insertCutItem(_ cutItem: CutItem, at index: Int, time: Int) {
        registerUndo { $0.removeCutItem(at: index, time: $1) }
        self.time = time
        sceneEditor.insert(cutItem, at: index)
        updateCanvassPosition()
    }
    func removeCutItem(at index: Int, time: Int) {
        let cutItem = scene.cutItems[index]
        registerUndo { $0.insertCutItem(cutItem, at: index, time: $1) }
        self.time = time
        sceneEditor.removeCutItem(at: index)
        updateCanvassPosition()
    }
    
    func newAnimation() {
        let animation = Animation(timeLength: scene.editCutItem.cut.timeLength)
        insertAnimation(animation, at: scene.editCutItem.cut.editAnimationIndex + 1, time: time)
        setEditAnimation(animation, oldEditAnimation: scene.editCutItem.cut.editAnimation, time: time)
    }
    func removeAnimation(at index: Int, in cutItem: CutItem) {
        if cutItem.cut.animations.count > 1 {
            let oldAnimation = cutItem.cut.animations[index]
            removeAnimationAtIndex(index, time: time)
            setEditAnimation(cutItem.cut.animations[max(0, index - 1)], oldEditAnimation: oldAnimation, time: time)
        }
    }
    func insertAnimation(_ animation: Animation, at index: Int, time: Int) {
        registerUndo { $0.removeAnimationAtIndex(index, time: $1) }
        self.time = time
        scene.editCutItem.cut.animations.insert(animation, at: index)
        scene.editCutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
    }
    func removeAnimationAtIndex(_ index: Int, time: Int) {
        registerUndo { [og = scene.editCutItem.cut.animations[index]] in $0.insertAnimation(og, at: index, time: $1) }
        self.time = time
        scene.editCutItem.cut.animations.remove(at: index)
        scene.editCutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
    }
    private func setEditAnimation(_ editAnimation: Animation, oldEditAnimation: Animation, time: Int) {
        registerUndo { $0.setEditAnimation(oldEditAnimation, oldEditAnimation: editAnimation, time: $1) }
        self.time = time
        scene.editCutItem.cut.editAnimation = editAnimation
        scene.editCutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
        sceneEditor.keyframeEditor.update()
        sceneEditor.cameraEditor.update()
        sceneEditor.speechEditor.update()
    }
    
    func newKeyframe() {
        splitKeyframe(with: scene.editCutItem.cut.editAnimation)
    }
    func splitKeyframe(with animation: Animation, isSplitDrawing: Bool = false) {
        let cutTime = scene.editCutItem.cut.time
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
        let cutItem =  scene.cutItems[ki.cutIndex]
        let animation = cutItem.cut.editAnimation
        if ki.cutIndex == 0 && ki.keyframeIndex == 0 && animation.keyframes.count >= 2 {
            removeFirstKeyframe(atCutIndex: ki.cutIndex)
        } else if
            ki.cutIndex + 1 < scene.cutItems.count && ki.keyframeIndex == nil &&
                scene.cutItems[ki.cutIndex + 1].cut.editAnimation.keyframes.count >= 2 {
            removeFirstKeyframe(atCutIndex: ki.cutIndex + 1)
        } else if animation.keyframes.count <= 1 || ki.keyframeIndex == nil {
            if scene.editCutItem.cut.animations.count <= 1 {
                removeCut(at: ki.keyframeIndex == nil ? ki.cutIndex + 1 : ki.cutIndex)
            } else {
                removeAnimation(at: cutItem.cut.editAnimationIndex, in: cutItem)
            }
        } else if let ki = ki.keyframeIndex {
            removeKeyframe(at: ki, in: animation, time: time)
        }
    }
    private func removeFirstKeyframe(atCutIndex cutIndex: Int) {
        let cutItem = scene.cutItems[cutIndex]
        let animation = cutItem.cut.editAnimation
        let deltaTime = animation.keyframes[1].time
        removeKeyframe(at: 0, in: animation, time: time)
        let keyframes = animation.keyframes.map { $0.withTime($0.time - deltaTime) }
        setKeyframes(keyframes, oldKeyframes: animation.keyframes, in: animation, cutItem, time: time)
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
                setTime(previousCutTimeLocation + previousCut.editAnimation.lastKeyframeTime, oldTime: time, alwaysUpdateCutIndex: true)
            } else if time >= scene.timeLength {
                setTime(scene.timeLength - 1, oldTime: time, alwaysUpdateCutIndex: true)
            }
        }
    }
    private func setKeyframes(_ keyframes: [Keyframe], oldKeyframes: [Keyframe], in animation: Animation, _ cutItem: CutItem, time: Int) {
        registerUndo { $0.setKeyframes(oldKeyframes, oldKeyframes: keyframes, in: animation, cutItem, time: $1) }
        self.time = time
        animation.replaceKeyframes(keyframes)
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
    }
    private func setTime(_ t: Int, oldTime: Int, alwaysUpdateCutIndex: Bool = false) {
        registerUndo { $0.0.setTime(oldTime, oldTime: t, alwaysUpdateCutIndex: alwaysUpdateCutIndex) }
        updateWith(time: t, scrollPoint: CGPoint(x: x(withTime: t), y: 0), alwaysUpdateCutIndex: alwaysUpdateCutIndex)
        scene.editCutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
    }
    private func replaceKeyframe(_ keyframe: Keyframe, at index: Int, in animation: Animation, time: Int) {
        registerUndo { [ok = animation.keyframes[index]] in $0.replaceKeyframe(ok, at: index, in: animation, time: $1) }
        self.time = time
        animation.replaceKeyframe(keyframe, at: index)
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        scene.editCutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
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
        scene.editCutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
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
        scene.editCutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
    }
//    private var previousTime: Int? {
//        let cut = scene.editCutItem.cut
//        let animation = cut.editAnimation
//        let keyframeIndex = animation.loopedKeyframeIndex(withTime: cut.time)
//        let t = animation.loopedKeyframeIndexes[keyframeIndex.loopedIndex].time
//        if cutTime - t > 0 {
//            return cutTimeLocation(withCutIndex: scene.editCutItemIndex) + t
//        } else if keyframeIndex.loopedIndex - 1 >= 0 {
//            return cutTimeLocation(withCutIndex: scene.editCutItemIndex) + animation.loopedKeyframeIndexes[keyframeIndex.loopedIndex - 1].time
//        } else if scene.editCutItemIndex - 1 >= 0 {
//            return cutTimeLocation(withCutIndex: scene.editCutItemIndex - 1) + scene.cutItems[scene.editCutItemIndex - 1].cut.editAnimation.lastLoopedKeyframeTime
//        } else {
//            return nil
//        }
//    }
    
    private var isDrag = false, dragOldTime = 0.0.cf, editCutItem: CutItem?
    private var dragOldCutTimeLength = 0, dragMinDeltaTime = 0, dragMinCutDeltaTime = 0
    private var dragOldSlideAnimations = [(animation: Animation, keyframeIndex: Int, oldKeyframes: [Keyframe])]()
    func drag(with event: DragEvent) {
        let p = convertToInternal(point(from: event))
        switch event.sendType {
        case .begin:
            let cutItem = scene.cutItems[cutIndex(withX: p.x)]
            if p.y > bounds.height/2 - (bounds.height/4 - timeHeight/2 - 1) || cutItem.cut.animations.count == 1 {
                let result = nearestKeyframeIndexTuple(at: p)
                let editCutItem = scene.cutItems[result.cutIndex]
                let animation = editCutItem.cut.editAnimation
                if let ki = result.keyframeIndex {
                    if ki > 0 {
                        let preTime = animation.keyframes[ki - 1].time, time = animation.keyframes[ki].time
                        dragMinDeltaTime = preTime - time + 1
                        dragOldSlideAnimations = [(animation, ki, animation.keyframes)]
                    }
                } else {
                    let preTime = animation.keyframes[animation.keyframes.count - 1].time, time = editCutItem.cut.timeLength
                    dragMinDeltaTime = preTime - time + 1
                    dragOldSlideAnimations = []
                }
                dragMinCutDeltaTime = max(editCutItem.cut.maxTimeWithOtherAnimation(animation) - editCutItem.cut.timeLength + 1, dragMinDeltaTime)
                self.editCutItem = result.cutIndex == 0 && result.keyframeIndex == 0 ? nil : editCutItem
                dragOldCutTimeLength = editCutItem.cut.timeLength
            } else {
                let result = animationIndexTuple(at: p)
                let editCutItem = scene.cutItems[result.cutIndex]
                let minAnimation = editCutItem.cut.animations[result.animationIndex]
                if let ki = result.keyframeIndex {
                    if ki > 0 {
                        let kt = minAnimation.keyframes[ki].time
                        var oldSlideAnimations = [(animation: Animation, keyframeIndex: Int, oldKeyframes: [Keyframe])](), pkt = 0
                        for animation in editCutItem.cut.animations {
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
                    let preTime = minAnimation.keyframes[minAnimation.keyframes.count - 1].time, time = editCutItem.cut.timeLength
                    dragMinDeltaTime = preTime - time + 1
                    dragOldSlideAnimations = []
                }
                dragMinCutDeltaTime = dragMinDeltaTime
                self.editCutItem = result.cutIndex == 0 && result.keyframeIndex == 0 ? nil : editCutItem
                dragOldCutTimeLength = editCutItem.cut.timeLength
            }
            dragOldTime = p.x/editFrameRateWidth
            isDrag = false
        case .sending:
            isDrag = true
            if let editCutItem = editCutItem {
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
                let t = convertToInternal(point(from: event)).x/editFrameRateWidth
                let dt = Int(t - dragOldTime + (t - dragOldTime >= 0 ? 0.5 : -0.5))
                let deltaTime = max(dragMinDeltaTime, dt)
                for slideAnimation in dragOldSlideAnimations {
                    var nks = slideAnimation.oldKeyframes
                    if deltaTime != 0 {
                        for i in slideAnimation.keyframeIndex ..< nks.count {
                            nks[i] = nks[i].withTime(nks[i].time + deltaTime)
                        }
                        setKeyframes(nks, oldKeyframes: slideAnimation.oldKeyframes, in: slideAnimation.animation, editCutItem, time: time)
                    } else {
                        slideAnimation.animation.replaceKeyframes(nks)
                    }
                }
                let timeLength = dragOldCutTimeLength + max(dragMinCutDeltaTime, dt)
                if timeLength != dragOldCutTimeLength {
                    setTimeLength(timeLength, oldTimeLength: dragOldCutTimeLength, in: editCutItem, time: time)
                }
                setTime(time, oldTime: time)
                dragOldSlideAnimations = []
                self.editCutItem = nil
            }
        }
    }
    private func setTimeLength(_ timeLength: Int, oldTimeLength: Int, in cutItem: CutItem, time: Int) {
        registerUndo { $0.setTimeLength(oldTimeLength, oldTimeLength: timeLength, in: cutItem, time: $1) }
        self.time = time
        cutItem.cut.timeLength = timeLength
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
        scene.updateCutTimeAndTimeLength()
    }
    
    let itemHeight = 8.0.cf
    private var oldIndex = 0, oldP = CGPoint()
    var moveQuasimode = false
    private weak var moveCutItem: CutItem?
    var oldAnimations = [Animation]()
    func move(with event: DragEvent) {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            oldAnimations = scene.editCutItem.cut.animations
            oldIndex = scene.editCutItem.cut.editAnimationIndex
            oldP = p
            moveCutItem = scene.editCutItem
        case .sending:
            if let cutItem = moveCutItem {
                let d = p.y - oldP.y
                let i = (oldIndex + Int(d/itemHeight)).clip(min: 0, max: cutItem.cut.animations.count), oi = cutItem.cut.editAnimationIndex
                cutItem.cut.animations.remove(at: oi)
                cutItem.cut.animations.insert(cutItem.cut.editAnimation, at: oi < i ? i - 1 : i)
                setNeedsDisplay()
                sceneEditor.canvas.setNeedsDisplay()
                sceneEditor.keyframeEditor.update()
                sceneEditor.cameraEditor.update()
            }
        case .end:
            if let cutItem = moveCutItem {
                let d = p.y - oldP.y
                let i = (oldIndex + Int(d/itemHeight)).clip(min: 0, max: cutItem.cut.animations.count), oi = cutItem.cut.editAnimationIndex
                if oldIndex != i {
                    var animations = cutItem.cut.animations
                    animations.remove(at: oi)
                    animations.insert(cutItem.cut.editAnimation, at: oi < i ? i - 1 : i)
                    setAnimations(animations, oldAnimations: oldAnimations, in: cutItem, time: time)
                } else if oi != i {
                    cutItem.cut.animations.remove(at: oi)
                    cutItem.cut.animations.insert(cutItem.cut.editAnimation, at: oi < i ? i - 1 : i)
                    setNeedsDisplay()
                    sceneEditor.canvas.setNeedsDisplay()
                    sceneEditor.keyframeEditor.update()
                    sceneEditor.cameraEditor.update()
                }
                oldAnimations = []
                editCutItem = nil
            }
        }
    }
    private func setEditAnimation(_ animation: Animation, oldAnimation: Animation, in cutItem: CutItem, time: Int) {
        registerUndo { $0.setEditAnimation(oldAnimation, oldAnimation: animation, in: cutItem, time: $1) }
        self.time = time
        cutItem.cut.editAnimation = animation
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
        sceneEditor.keyframeEditor.update()
        sceneEditor.cameraEditor.update()
    }
    private func setAnimations(_ animations: [Animation], oldAnimations: [Animation], in cutItem: CutItem, time: Int) {
        registerUndo { $0.setAnimations(oldAnimations, oldAnimations: animations, in: cutItem, time: $1) }
        self.time = time
        cutItem.cut.animations = animations
        cutItem.cutDataModel.isWrite = true
        setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
        sceneEditor.keyframeEditor.update()
        sceneEditor.cameraEditor.update()
    }
    
    func select(_ event: DragEvent, type: Action.SendType) {
    }
    
    private var isAnimationScroll = false, deltaScrollY = 0.0.cf, scrollCutItem: CutItem?
    func scroll(with event: ScrollEvent) {
        scroll(with: event, isUseMomentum: true)
    }
    func scroll(with event: ScrollEvent, isUseMomentum: Bool) {
        if event.sendType  == .begin {
            isAnimationScroll = scene.editCutItem.cut.animations.count == 1 ? false : abs(event.scrollDeltaPoint.x) < abs(event.scrollDeltaPoint.y)
        }
        if isAnimationScroll {
            if event.scrollMomentumType == nil {
                let p = point(from: event)
                switch event.sendType {
                case .begin:
                    oldIndex = scene.editCutItem.cut.editAnimationIndex
                    oldP = p
                    deltaScrollY = 0
                    scrollCutItem = scene.editCutItem
                case .sending:
                    if let scrollCutItem = scrollCutItem {
                        deltaScrollY += event.scrollDeltaPoint.y
                        let i = (oldIndex + Int(deltaScrollY/10)).clip(min: 0, max: scrollCutItem.cut.animations.count - 1)
                        if scrollCutItem.cut.editAnimationIndex != i {
                            scrollCutItem.cut.editAnimation = scrollCutItem.cut.animations[i]
                            updateView()
                        }
                    }
                case .end:
                    if let scrollCutItem = scrollCutItem {
                        let i = (oldIndex + Int(deltaScrollY/10)).clip(min: 0, max: scrollCutItem.cut.animations.count - 1)
                        if oldIndex != i {
                            setEditAnimation(scrollCutItem.cut.animations[i], oldAnimation: scrollCutItem.cut.animations[oldIndex], in: scrollCutItem, time: time)
                        } else if scrollCutItem.cut.editAnimationIndex != i {
                            scrollCutItem.cut.editAnimation = scrollCutItem.cut.animations[i]
                            updateView()
                        }
                        self.scrollCutItem = nil
                    }
                }
            }
        } else {
            if event.sendType == .begin && sceneEditor.canvas.player.isPlaying {
                sceneEditor.canvas.player.layer.opacity = 0.2
            } else if event.sendType == .end && sceneEditor.canvas.player.layer.opacity != 1 {
                sceneEditor.canvas.player.layer.opacity = 1
            }
            let x = (scrollPoint.x - event.scrollDeltaPoint.x).clip(min: 0, max: self.x(withTime: scene.timeLength - 1))
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
