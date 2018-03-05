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
import QuartzCore
import AppKit.NSCursor

final class TimelineView: View, ButtonDelegate {
    weak var sceneView: SceneView! {
        didSet {
            timeline.sceneView = sceneView
        }
    }
    
    let timeline = Timeline(frame: SceneLayout.timelineEditFrame)
    let newCutButton = Button(frame: SceneLayout.timelineAddCutFrame, title: "New Cut".localized)
    let splitKeyframeButton = Button(frame: SceneLayout.timelineSplitKeyframeFrame, title: "New Keyframe".localized)
    let newGroupButton = Button(frame: SceneLayout.timelineAddGroupFrame, title: "New Group".localized)
    
    override init(layer: CALayer = CALayer.interfaceLayer()) {
        super.init(layer: layer)
        layer.frame = SceneLayout.timelineFrame
        newGroupButton.drawLayer.fillColor = Defaults.subBackgroundColor3.cgColor
        newCutButton.drawLayer.fillColor = Defaults.subBackgroundColor3.cgColor
        splitKeyframeButton.drawLayer.fillColor = Defaults.subBackgroundColor3.cgColor
        newGroupButton.sendDelegate = self
        newCutButton.sendDelegate = self
        splitKeyframeButton.sendDelegate = self
        children = [
            timeline,
            newGroupButton, newCutButton, splitKeyframeButton
        ]
    }
    func clickButton(_ button: Button) {
        switch button {
        case newGroupButton:
            sceneView.timeline.newGroup()
        case newCutButton:
            sceneView.timeline.newCut()
        case splitKeyframeButton:
            sceneView.timeline.newKeyframe()
        default:
            break
        }
    }
    override func scroll(with event: ScrollEvent) {
        timeline.scroll(with: event)
    }
    override func zoom(with event: PinchEvent) {
        timeline.zoom(with: event)
    }
    override func reset() {
        timeline.reset()
    }
}

final class Timeline: View {
    weak var sceneView: SceneView!
    
    var cutView: CutView {
        return sceneView.cutView
    }
    
    init(frame: CGRect = CGRect()) {
        let drawLayer = DrawLayer(fillColor: Defaults.subBackgroundColor3.cgColor)
        super.init(layer: drawLayer)
        description = "Timeline: Time selection with left and right scroll, group selection with up and down scroll".localized
        drawLayer.frame = frame
        drawLayer.drawBlock = { [unowned self] ctx in
            self.draw(in: ctx)
        }
    }
    deinit {
        timer.stop()
    }
    
    override func cursor(with p: CGPoint) -> NSCursor {
        return moveQuasimode ? Defaults.upDownCursor : NSCursor.arrow
    }
    
    weak var sceneEntity: SceneEntity! {
        didSet {
            updateCutViewsPosition()
            updateMaxTime()
        }
    }
    var scene = Scene() {
        didSet {
            updateWith(time: scene.time, scrollPoint: CGPoint(x: x(withTime: scene.time), y: 0))
        }
    }
    var selectionCutEntity: CutEntity {
        get {
            return sceneEntity.cutEntities[selectionCutIndex >= sceneEntity.cutEntities.count ? selectionCutIndex - 1 : selectionCutIndex]
        }
        set {
            if let index = sceneEntity.cutEntities.index(of: newValue) {
                selectionCutIndex = index
            }
        }
    }
    var selectionCutIndex = -1 {
        didSet {
            cutView.cutEntity = selectionCutEntity
            sceneView.keyframeView.update()
            sceneView.transformView.update()
            sceneView.speechView.update()
            setNeedsDisplay()
        }
    }
    var editGroup: Group {
        return selectionCutEntity.cut.editGroup
    }
    var editKeyframe: Keyframe {
        return editGroup.editKeyframe
    }
    var fps = 24
    static let defaultFrameRateWidth = 6.0.cf, defaultTimeHeight = 18.0.cf
    var editFrameRateWidth = Timeline.defaultFrameRateWidth, timeHeight = defaultTimeHeight
    private(set) var maxScrollX = 0.0.cf
    func updateCutViewsPosition() {
        maxScrollX = sceneEntity.cutEntities.reduce(0.0.cf) { $0 + x(withTime: $1.cut.timeLength) }
        setNeedsDisplay()
    }
    private var _time = 0, _scrollPoint = CGPoint(), _intervalScrollPoint = CGPoint()
    var scrollPoint: CGPoint {
        get {
            return _scrollPoint
        }
        set {
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
        }
        set {
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
        let cvi = cutViewIndex(withTime: time)
        if alwaysUpdateCutIndex || selectionCutIndex != cvi.index {
            selectionCutIndex = cvi.index
            selectionCutEntity.cut.time = cvi.interTime
        } else {
            selectionCutEntity.cut.time = cvi.interTime
        }
        updateViews()
    }
    private func updateViews() {
        sceneView.keyframeView.update()
        sceneView.transformView.update()
        sceneView.speechView.update()
        cutView.updateViewAffineTransform()
        setNeedsDisplay()
        cutView.setNeedsDisplay()
    }
    private func intervalScrollPoint(with scrollPoint: CGPoint) -> CGPoint {
        return CGPoint(x: x(withTime: time(withX: scrollPoint.x)), y: 0)
    }
    var cutTime: Int {
        get {
            return selectionCutEntity.cut.time
        }
        set {
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
    
    private var timer = LockTimer(), oldPlayCutEntity: CutEntity?, oldPlayTime = 0, oldTimestamp = 0.0, playDrawCount = 0, playCutIndex = 0, playSecond = 0, playFPS = 0, playCutEntity: CutEntity?, delayTolerance = 0.5
    var isPlaying = false {
        didSet {
            if isPlaying {
                playCutEntity = selectionCutEntity
                oldPlayCutEntity = selectionCutEntity
                oldPlayTime = selectionCutEntity.cut.time
                oldTimestamp = CFAbsoluteTimeGetCurrent()
                let t = Double(currentPlayTime)/Double(scene.frameRate)
                playSecond = Int(t)
                playCutIndex = selectionCutEntity.index
                playFPS = scene.frameRate
                playDrawCount = 0
                cutView.timeLabel.textLine.string = minuteSecondString(withSecond: playSecond, frameRate: scene.frameRate)
                cutView.cutLabel.textLine.string = "C\(playCutIndex + 1)"
                cutView.fpsLabel.textLine.string = "\(playFPS)fps"
                cutView.fpsLabel.textLine.color = playFPS != scene.frameRate ? NSColor.red.cgColor : Defaults.smallFontColor.cgColor
                cutView.isPlaying = true
                scene.soundItem.sound?.currentTime = t
                scene.soundItem.sound?.play()
                timer.begin(1/TimeInterval(fps), tolerance: 0.1/TimeInterval(fps)) { [unowned self] in
                    self.updatePlayTime()
                }
            } else {
                timer.stop()
                cutView.isPlaying = false
                if let oldPlayCutEntity = oldPlayCutEntity, cutView.cutEntity !== oldPlayCutEntity {
                    cutView.cutEntity = oldPlayCutEntity
                }
                selectionCutEntity.cut.time = oldPlayTime
                sceneView.keyframeView.update()
                sceneView.transformView.update()
                sceneView.speechView.update()
                cutView.updateViewAffineTransform()
                setNeedsDisplay()
                cutView.setNeedsDisplay()
                playCutEntity = nil
                scene.soundItem.sound?.stop()
            }
        }
    }
    private func updatePlayTime() {
        if let playCutEntity = playCutEntity {
            var updated = false
            if let sound = scene.soundItem.sound, !scene.soundItem.isHidden {
                let t = Int(sound.currentTime*Double(scene.frameRate))
                let pt = currentPlayTime + 1
                if abs(pt - t) > 1 {
                    let viewIndex = cutViewIndex(withTime: t)
                    if viewIndex.isOver {
                        sceneEntity.cutEntities[0].cut.time = 0
                        scene.soundItem.sound?.currentTime = 0
                    } else {
                        let cutEntity = sceneEntity.cutEntities[viewIndex.index]
                        if cutEntity != playCutEntity {
                            self.playCutEntity = cutEntity
                            cutView.cutEntity = cutEntity
                        }
                        playCutEntity.cut.time =  viewIndex.interTime
                    }
                    updated = true
                }
            }
            if !updated {
                let nextTime = playCutEntity.cut.time + 1
                if nextTime < playCutEntity.cut.timeLength {
                    playCutEntity.cut.time =  nextTime
                } else if sceneEntity.cutEntities.count == 1 {
                    playCutEntity.cut.time = 0
                } else {
                    let cutIndex = sceneEntity.cutEntities.index(of: playCutEntity) ?? 0
                    let nextCutIndex = cutIndex + 1 <= sceneEntity.cutEntities.count - 1 ? cutIndex + 1 : 0
                    let nextCutEntity = sceneEntity.cutEntities[nextCutIndex]
                    playCutEntity.cut.time = oldPlayTime
                    self.playCutEntity = nextCutEntity
                    cutView.cutEntity = nextCutEntity
                    nextCutEntity.cut.time = 0
                    if nextCutIndex == 0 {
                        scene.soundItem.sound?.currentTime = 0
                    }
                }
                cutView.updateViewAffineTransform()
                cutView.setNeedsDisplay()
            }
            
            let t = currentPlayTime
            let s = t/scene.frameRate
            if s != playSecond {
                playSecond = s
                cutView.timeLabel.textLine.string = minuteSecondString(withSecond: playSecond, frameRate: scene.frameRate)
            }
            
            if playCutIndex != playCutEntity.index {
                playCutIndex = playCutEntity.index
                cutView.cutLabel.textLine.string = "C\(playCutIndex + 1)"
            }
            
            playDrawCount += 1
            let newTimestamp = CFAbsoluteTimeGetCurrent()
            let deltaTime = newTimestamp - oldTimestamp
            if deltaTime >= 1 {
                let newPlayFPS = min(scene.frameRate, Int(round(Double(playDrawCount)/deltaTime)))
                if newPlayFPS != playFPS {
                    playFPS = newPlayFPS
                    cutView.fpsLabel.textLine.string = "\(playFPS)fps"
                    cutView.fpsLabel.textLine.color = playFPS != scene.frameRate ? NSColor.red.cgColor : Defaults.smallFontColor.cgColor
                }
                oldTimestamp = newTimestamp
                playDrawCount = 0
            }
        }
    }
    func minuteSecondString(withSecond s: Int, frameRate: Int) -> String {
        if s >= 60 {
            let minute = s/60
            let second = s - minute*60
            return String(format: "%02d:%02d", minute, second)
        } else {
            return String(format: "00:%02d", s)
        }
    }
    
    var currentPlayTime: Int {
        var t = 0
        for entity in sceneEntity.cutEntities {
            if playCutEntity != entity {
                t += entity.cut.timeLength
            } else {
                t += entity.cut.time
                break
            }
        }
        return t
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
        return cutViewIndex(withTime: time(withX: x)).index
    }
    func cutViewIndex(withTime time: Int) -> (index: Int, interTime: Int, isOver: Bool) {
        var t = 0
        for (i, cutEntity) in sceneEntity.cutEntities.enumerated() {
            let nt = t + cutEntity.cut.timeLength
            if time < nt {
                return (i, time - t, false)
            }
            t = nt
        }
        return (sceneEntity.cutEntities.count - 1, time - t, true)
    }
    func cutLabelIndex(at p: CGPoint) -> Int? {
        let time = self.time(withX: p.x)
        var t = 0
        for cutEntity in sceneEntity.cutEntities {
            let nt = t + cutEntity.cut.timeLength
            if time < nt {
                func cutIndex(with x: CGFloat) -> Bool {
                    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "C\(cutEntity.index + 1)", attributes: [NSAttributedStringKey(rawValue: String(kCTFontAttributeName)): Defaults.smallFont, NSAttributedStringKey(rawValue: String(kCTForegroundColorAttributeName)): Defaults.smallFontColor.cgColor]))
                    let sb = line.typographicBounds
                    let nsb = CGRect(x: x + editFrameRateWidth/2 - sb.width/2 + sb.origin.x, y: timeHeight/2 - sb.height/2 + sb.origin.y, width: sb.width, height: sb.height)
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
        if cut.editGroup.keyframes.count == 0 {
            return (ci, nil)
        } else {
            var minD = CGFloat.infinity, minI = 0
            for (i, k) in cut.editGroup.keyframes.enumerated() {
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
    func groupIndexTuple(at p: CGPoint) -> (cutIndex: Int, groupIndex: Int, keyframeIndex: Int?) {
        let ci = cutIndex(withX: p.x)
        let cut = sceneEntity.cutEntities[ci].cut, kt = cutTimeLocation(withCutIndex: ci)
        var minD = CGFloat.infinity, minKeyframeIndex = 0, minGroupIndex = 0
        for (ii, group) in cut.groups.enumerated() {
            for (i, k) in group.keyframes.enumerated() {
                let x = (kt + k.time).cf*editFrameRateWidth
                let d = abs(p.x - x)
                if d < minD {
                    minGroupIndex = ii
                    minKeyframeIndex = i
                    minD = d
                }
            }
        }
        let x = (kt + cut.timeLength).cf*editFrameRateWidth
        let d = abs(p.x - x)
        if d < minD {
            return (ci, minGroupIndex, nil)
        } else if minKeyframeIndex == 0 && ci > 0 {
            return (ci - 1, minGroupIndex, nil)
        } else {
            return (ci,  minGroupIndex, minKeyframeIndex)
        }
    }
    
    func setNeedsDisplay() {
        layer.setNeedsDisplay()
    }
    func draw(in ctx: CGContext) {
        ctx.translateBy(x: bounds.width/2 - editFrameRateWidth/2 - _intervalScrollPoint.x, y: 0)
        drawTime(in: ctx)
        drawFirstCutLine(in: ctx)
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
                let index = cutEntity.cut.editGroupIndex, cutKnobBounds = self.cutKnobBounds(with: cutEntity.cut).insetBy(dx: 0, dy: 1), h = 2.0.cf
                if index == 0 {
                    drawAllGroupKnob(cutEntity.cut, y: bounds.height/2, in: ctx)
                } else {
                    var y = bounds.height/2 + knobHalfHeight
                    for _ in (0 ..< index).reversed() {
                        y += 1 + h
                        if y >= cutKnobBounds.maxY {
                            y = cutKnobBounds.maxY
                            break
                        }
                    }
                    drawAllGroupKnob(cutEntity.cut, y: y, in: ctx)
                }
                
                var y = bounds.height/2 + knobHalfHeight + 1
                for i in (0 ..< index).reversed() {
                    drawNotSelectedGroupWith(group: cutEntity.cut.groups[i], width: w, y: y, h: h, in: ctx)
                    y += 1 + h
                    if y >= cutKnobBounds.maxY {
                        break
                    }
                }
                y = bounds.height/2 - knobHalfHeight - 1
                if index + 1 < cutEntity.cut.groups.count {
                    for i in index + 1 ..< cutEntity.cut.groups.count {
                        drawNotSelectedGroupWith(group: cutEntity.cut.groups[i], width: w, y: y - h, h:h, in: ctx)
                        y -= 1 + h
                        if y <= cutKnobBounds.minY {
                            break
                        }
                    }
                }
                drawGroup(cutEntity.cut.editGroup, cut: cutEntity.cut, y: bounds.height/2, isOther: false, in: ctx)
                drawCutEntity(cutEntity, in: ctx)
            }
            ctx.translateBy(x: w, y: 0)
            x += w
        }
        ctx.restoreGState()
        ctx.saveGState()
        x = 0
        for cutEntity in sceneEntity.cutEntities {
            let w = cutEntity.cut.timeLength.cf*editFrameRateWidth
            if b.minX <= x + w && b.maxX >= x {
                drawCutKnob(cutEntity.cut, in: ctx)
            }
            ctx.translateBy(x: w, y: 0)
            x += w
        }
        ctx.restoreGState()
    }
    func drawFirstCutLine(in ctx: CGContext) {
        ctx.setLineWidth(2)
        ctx.setStrokeColor(Defaults.contentEditColor.cgColor)
        ctx.move(to: CGPoint(x: editFrameRateWidth/2, y: timeHeight + 3))
        ctx.addLine(to: CGPoint(x: editFrameRateWidth/2, y: bounds.height - timeHeight - 3))
        ctx.strokePath()
    }
    func cutKnobBounds(with cut: Cut) -> CGRect {
        return CGRect(x: cut.timeLength.cf*editFrameRateWidth, y: timeHeight + 2, width: editFrameRateWidth, height: bounds.height - timeHeight*2 - 2*2)
    }
    func drawCutKnob(_ cut: Cut, in ctx: CGContext) {
        ctx.setLineWidth(1)
        ctx.setFillColor(Defaults.contentColor.cgColor)
        ctx.setStrokeColor(Defaults.editColor.cgColor)
        ctx.addRect(cutKnobBounds(with: cut).inset(by: 0.5))
        ctx.drawPath(using: .fillStroke)
    }
    func drawCutEntity(_ cutEntity: CutEntity, in ctx: CGContext) {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: "C\(cutEntity.index + 1)", attributes: [NSAttributedStringKey(rawValue: String(kCTFontAttributeName)): Defaults.smallFont, NSAttributedStringKey(rawValue: String(kCTForegroundColorAttributeName)): Defaults.smallFontColor.cgColor]))
        let sb = line.typographicBounds
        ctx.textPosition = CGPoint(x: editFrameRateWidth/2 - sb.width/2 + sb.origin.x, y: timeHeight/2 - sb.height/2 + sb.origin.y)
        CTLineDraw(line, ctx)
    }
    private let knobHalfHeight = 6.0.cf, easingHeight = 3.0.cf
    func drawGroup(_ group: Group, cut: Cut, y: CGFloat, isOther: Bool, in ctx: CGContext) {
        let lineColor = group.isHidden ?
            (group.transformItem != nil ? SceneDefaults.cameraColor.multiplyWhite(0.5) : Defaults.contentEditColor.cgColor.multiplyWhite(0.5)) :
            (group.transformItem != nil ? SceneDefaults.cameraColor : Defaults.contentEditColor.cgColor)
        let knobFillColor = group.isHidden ? Defaults.subBackgroundColor3.cgColor.multiplyWhite(0.5) : Defaults.contentColor.cgColor
        let knobLineColor = group.isHidden ?
            (group.transformItem != nil ? SceneDefaults.cameraColor.multiplyWhite(0.5) : Defaults.subBackgroundColor.cgColor) :
            (group.transformItem != nil ? SceneDefaults.cameraColor.multiplyWhite(0.5) : Defaults.editColor.cgColor)
        
        for (i, lki) in group.loopedKeyframeIndexes.enumerated() {
            let keyframe = group.keyframes[lki.index]
            let time = lki.time
            let nextTime = i + 1 >= group.loopedKeyframeIndexes.count ? cut.timeLength : group.loopedKeyframeIndexes[i + 1].time
            let x = time.cf*editFrameRateWidth
            let nextX = i + 1 >= group.loopedKeyframeIndexes.count ? (nextTime.cf - 0.5)*editFrameRateWidth : nextTime.cf*editFrameRateWidth
            let timeLength = nextTime - time, width = nextX - x
            
            if time >= group.timeLength {
                continue
            }
            let isClipDrawKeyframe = nextTime > group.timeLength
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
                        ctx.setStrokeColor(lineColor)
                        ctx.strokePath()
                    } else {
                        let ps = points.map { CGPoint(x: $0.x, y: y + $0.y) } + points.reversed().map { CGPoint(x: $0.x, y: y - $0.y) }
                        ctx.addLines(between: ps)
                        ctx.setFillColor(lineColor)
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
                    ctx.setStrokeColor(lineColor)
                    ctx.strokePath()
                }
            }
            
            if i > 0 {
                let kh = knobHalfHeight
                ctx.setLineWidth(1)
                ctx.setFillColor(lki.loopingCount > 0 ? Defaults.subBackgroundColor3.cgColor : knobFillColor)
                ctx.setStrokeColor(knobLineColor)
                ctx.addRect(CGRect(x: x, y: y - kh, width: editFrameRateWidth, height: kh*2).inset(by: 0.5))
                ctx.drawPath(using: .fillStroke)
            }
            if isClipDrawKeyframe {
                ctx.restoreGState()
            }
        }
    }
    func drawNotSelectedGroupWith(group: Group, width: CGFloat, y: CGFloat, h: CGFloat, in ctx: CGContext) {
        let lineColor = group.isHidden ? (group.transformItem != nil ? SceneDefaults.cameraColor.multiplyWhite(0.75) : Defaults.subBackgroundColor.cgColor) : (group.transformItem != nil ? SceneDefaults.cameraColor.multiplyWhite(0.5) : Defaults.editColor.cgColor)
        let keyColor = group.isHidden ? (group.transformItem != nil ? SceneDefaults.cameraColor.multiplyWhite(0.5) : Defaults.subEditColor.cgColor) : (group.transformItem != nil ? SceneDefaults.cameraColor : Defaults.contentEditColor.cgColor)
        ctx.setFillColor(lineColor)
        ctx.fill(CGRect(x: editFrameRateWidth/2 + 1, y: y, width: width - 2, height: h))
        ctx.setFillColor(keyColor)
        for (i, keyframe) in group.keyframes.enumerated() {
            if i > 0 {
                ctx.fill(CGRect(x: keyframe.time.cf*editFrameRateWidth + 1, y: y, width: editFrameRateWidth - 2, height: h))
            }
        }
    }
    func drawAllGroupKnob(_ cut: Cut, y: CGFloat, in ctx: CGContext) {
        if cut.groups.count > 1 {
            for group in cut.groups {
                for (i, keyframe) in group.keyframes.enumerated() {
                    if i > 0 {
                        let x = keyframe.time.cf*editFrameRateWidth + editFrameRateWidth/2
                        ctx.setLineWidth(1)
                        
                        ctx.setLineWidth(1)
                        ctx.setStrokeColor(Defaults.subEditColor.cgColor)
                        ctx.move(to: CGPoint(x: x, y: timeHeight))
                        ctx.addLine(to: CGPoint(x: x, y: y))
                        ctx.strokePath()
                        
                        ctx.setFillColor(Defaults.contentColor.cgColor)
                        ctx.setStrokeColor(Defaults.editColor.cgColor)
                        ctx.addRect(CGRect(x: x - editFrameRateWidth/2, y: timeHeight - 3 - 2, width: editFrameRateWidth, height: 6).insetBy(dx: 0.5, dy: 0.5))
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
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: [NSAttributedStringKey(rawValue: String(kCTFontAttributeName)): Defaults.smallFont, NSAttributedStringKey(rawValue: String(kCTForegroundColorAttributeName)): Defaults.smallFontColor.cgColor]))
            let sb = line.typographicBounds, tx = x(withTime: i*fps) + editFrameRateWidth/2, ty = bounds.height - timeHeight/2, ni1 = i*fps + fps/4, ni2 = i*fps + fps/2, ni3 = i*fps + fps*3/4
            ctx.textPosition = CGPoint(x: tx - sb.width/2 + sb.origin.x, y: ty - sb.height/2 + sb.origin.y)
            CTLineDraw(line, ctx)
            
            ctx.setFillColor(Defaults.smallFontColor.cgColor.multiplyAlpha(0.1))
            ctx.fill(CGRect(x: x(withTime: i*fps), y: timeHeight, width: editFrameRateWidth, height: bounds.height - timeHeight*2))
            if ni2 < maxTime {
                ctx.fill(CGRect(x: x(withTime: ni2), y: timeHeight, width: editFrameRateWidth, height: bounds.height - timeHeight*2))
            }
            ctx.setFillColor(Defaults.smallFontColor.cgColor.multiplyAlpha(0.05))
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
        ctx.setFillColor(Defaults.translucentBackgroundColor.cgColor)
        ctx.fill(CGRect(x: x, y: timeHeight - 2, width: editFrameRateWidth, height: bounds.height - timeHeight*2 + 2*2))
        
        let secondTime = scene.secondTime
        if secondTime.frame != 0 {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: String(secondTime.frame), attributes: [NSAttributedStringKey(rawValue: String(kCTFontAttributeName)): Defaults.smallFont, NSAttributedStringKey(rawValue: String(kCTForegroundColorAttributeName)): Defaults.smallFontColor.cgColor.multiplyAlpha(0.2)]))
            let sb = line.typographicBounds, tx = x + editFrameRateWidth/2, ty = bounds.height - timeHeight/2
            ctx.textPosition = CGPoint(x: tx - sb.width/2 + sb.origin.x, y: ty - sb.height/2 + sb.origin.y)
            CTLineDraw(line, ctx)
        }
    }
    
    private func registerUndo(_ handler: @escaping (Timeline, Int) -> Void) {
        undoManager?.registerUndo(withTarget: self) { [oldTime = time] in handler($0, oldTime) }
    }
    func setUpdate(_ update: Bool, in cutEntity: CutEntity) {
        cutEntity.isUpdate = update
        setNeedsDisplay()
        cutView.setNeedsDisplay()
    }
    var isUpdate: Bool {
        get {
            return selectionCutEntity.isUpdate
        }
        set {
            selectionCutEntity.isUpdate = newValue
            setNeedsDisplay()
            cutView.setNeedsDisplay()
        }
    }
    
    override func copy() {
        if let i = cutLabelIndex(at: convertToInternal(currentPoint)) {
            let cut = sceneEntity.cutEntities[i].cut
            screen?.copy(cut.data, forType: Cut.dataType, from: self)
        } else {
            screen?.tempNotAction()
        }
    }
    override func paste() {
        if isPlaying {
            screen?.tempNotAction()
            return
        }
        if let data = screen?.copyData(forType: Cut.dataType), let cut = Cut.with(data) {
            let index = cutIndex(withX: convertToInternal(currentPoint).x)
            insertCutEntity(CutEntity(cut: cut), at: index + 1, time: time)
            setTime(cutTimeLocation(withCutIndex: index + 1), oldTime: time)
        }
    }
    
    override func delete() {
        if isPlaying {
            screen?.tempNotAction()
            return
        }
        if let i = cutLabelIndex(at: convertToInternal(currentPoint)) {
            removeCut(at: i)
        } else {
            removeKeyframe()
        }
    }
    
    override func moveToPrevious() {
        if isPlaying {
            stop()
        }
        let cut = selectionCutEntity.cut
        let group = cut.editGroup
        let loopedIndex = group.loopedKeyframeIndex(withTime: cut.time).loopedIndex
        let keyframeIndex = group.loopedKeyframeIndexes[loopedIndex]
        if cut.time - keyframeIndex.time > 0 {
            updateTime(withCutTime: keyframeIndex.time)
        } else if loopedIndex - 1 >= 0 {
            updateTime(withCutTime: group.loopedKeyframeIndexes[loopedIndex - 1].time)
        } else if selectionCutIndex - 1 >= 0 {
            selectionCutIndex -= 1
            updateTime(withCutTime: selectionCutEntity.cut.editGroup.lastLoopedKeyframeTime)
        } else {
            screen?.tempNotAction()
        }
    }
    override func moveToNext() {
        if isPlaying {
            stop()
        }
        let cut = selectionCutEntity.cut
        let group = cut.editGroup
        let loopedIndex = group.loopedKeyframeIndex(withTime: cut.time).loopedIndex
        if loopedIndex + 1 <= group.loopedKeyframeIndexes.count - 1 {
            let t = group.loopedKeyframeIndexes[loopedIndex + 1].time
            if t < group.timeLength {
                updateTime(withCutTime: t)
                return
            }
        }
        if selectionCutIndex + 1 <= sceneEntity.cutEntities.count - 1 {
            selectionCutIndex += 1
            updateTime(withCutTime: 0)
        } else {
            screen?.tempNotAction()
        }
    }
    func moveToPreviousFrame() {
        if isPlaying {
            stop()
        }
        let cut = selectionCutEntity.cut
        if cut.time - 1 >= 0 {
            updateTime(withCutTime: cut.time - 1)
        } else if selectionCutIndex - 1 >= 0 {
            selectionCutIndex -= 1
            updateTime(withCutTime: selectionCutEntity.cut.timeLength - 1)
        }
    }
    func moveToNextFrame() {
        if isPlaying {
            stop()
        }
        let cut = selectionCutEntity.cut
        if cut.time + 1 < cut.timeLength {
            updateTime(withCutTime: cut.time + 1)
        } else if selectionCutIndex + 1 <= sceneEntity.cutEntities.count - 1 {
            selectionCutIndex += 1
            updateTime(withCutTime: 0)
        }
    }
    override func play() {
        if isPlaying {
            if let oldPlayCutEntity = oldPlayCutEntity {
                if cutView.cutEntity !== oldPlayCutEntity {
                    cutView.cutEntity = oldPlayCutEntity
                    playCutEntity = oldPlayCutEntity
                }
            }
            playCutEntity?.cut.time = oldPlayTime
            scene.soundItem.sound?.currentTime = Double(currentPlayTime)/Double(scene.frameRate)
        } else {
            isPlaying = true
        }
    }
    func stop() {
        if isPlaying {
            isPlaying = false
        }
    }
    
    override func hideCell() {
        if isPlaying {
            screen?.tempNotAction()
            return
        }
        let group = sceneView.cutView.cut.editGroup
        if !group.isHidden {
            setIsHidden(true, in: group, time: time)
        } else {
            screen?.tempNotAction()
        }
    }
    override func showCell() {
        if isPlaying {
            screen?.tempNotAction()
            return
        }
        let group = sceneView.cutView.cut.editGroup
        if group.isHidden {
            setIsHidden(false, in: group, time: time)
        } else {
            screen?.tempNotAction()
        }
    }
    func setIsHidden(_ isHidden: Bool, in group: Group, time: Int) {
        registerUndo { [oldHidden = group.isHidden] in $0.setIsHidden(oldHidden, in: group, time: $1) }
        self.time = time
        group.isHidden = isHidden
        isUpdate = true
        layer.setNeedsDisplay()
        sceneView.cutView.setNeedsDisplay()
        sceneView.timeline.setNeedsDisplay()
    }
    
    func newCut() {
        if isPlaying {
            screen?.tempNotAction()
            return
        }
        insertCutEntity(CutEntity(), at: selectionCutIndex + 1, time: time)
        setTime(cutTimeLocation(withCutIndex: selectionCutIndex + 1), oldTime: time)
    }
    func insertCutEntity(_ cutEntity: CutEntity, at index: Int, time: Int) {
        registerUndo { $0.removeCutEntity(at: index, time: $1) }
        self.time = time
        sceneEntity.insert(cutEntity, at: index)
        updateCutViewsPosition()
        updateMaxTime()
    }
    func removeCutEntity(at index: Int, time: Int) {
        let cutEntity = sceneEntity.cutEntities[index]
        registerUndo { $0.insertCutEntity(cutEntity, at: index, time: $1) }
        self.time = time
        sceneEntity.removeCutEntity(at: index)
        updateCutViewsPosition()
        updateMaxTime()
    }
    
    func newGroup() {
        if isPlaying {
            screen?.tempNotAction()
            return
        }
        let group = Group(timeLength: selectionCutEntity.cut.timeLength)
        insertGroup(group, at: selectionCutEntity.cut.editGroupIndex + 1, time: time)
        setEditGroup(group, oldEditGroup: selectionCutEntity.cut.editGroup, time: time)
    }
    func removeGroup(at index: Int, in cutEntity: CutEntity) {
        if cutEntity.cut.groups.count > 1 {
            let oldGroup = cutEntity.cut.groups[index]
            removeGroupAtIndex(index, time: time)
            setEditGroup(cutEntity.cut.groups[max(0, index - 1)], oldEditGroup: oldGroup, time: time)
        }
    }
    func insertGroup(_ group: Group, at index: Int, time: Int) {
        registerUndo { $0.removeGroupAtIndex(index, time: $1) }
        self.time = time
        selectionCutEntity.cut.groups.insert(group, at: index)
        isUpdate = true
    }
    func removeGroupAtIndex(_ index: Int, time: Int) {
        registerUndo { [og = selectionCutEntity.cut.groups[index]] in $0.insertGroup(og, at: index, time: $1) }
        self.time = time
        selectionCutEntity.cut.groups.remove(at: index)
        isUpdate = true
    }
    private func setEditGroup(_ editGroup: Group, oldEditGroup: Group, time: Int) {
        registerUndo { $0.setEditGroup(oldEditGroup, oldEditGroup: editGroup, time: $1) }
        self.time = time
        selectionCutEntity.cut.editGroup = editGroup
        isUpdate = true
        sceneView.keyframeView.update()
        sceneView.transformView.update()
        sceneView.speechView.update()
    }
    
    func isInterpolatedKeyframe(with group: Group) -> Bool {
        return selectionCutEntity.cut.isInterpolatedKeyframe(with:group)
    }
    func newKeyframe() {
        splitKeyframe(with: editGroup, implicitSplited: false)
    }
    func splitKeyframe(with group: Group, implicitSplited: Bool = true, isSplitDrawing: Bool = false) {
        if isPlaying {
            screen?.tempNotAction()
            return
        }
        let cutTime = self.cutTime
        let ki = Keyframe.index(time: cutTime, with: group.keyframes)
        if ki.interValue > 0 {
            let k = group.keyframes[ki.index]
            let newEaing = ki.sectionValue != 0 ? k.easing.split(with: ki.interValue.cf/ki.sectionValue.cf) : (b0: k.easing, b1: Easing())
            let splitKeyframe0 = Keyframe(time: k.time, easing: newEaing.b0, interpolation: k.interpolation, loop: k.loop, implicitSplited: k.implicitSplited)
            let splitKeyframe1 = Keyframe(time: cutTime, easing: newEaing.b1, interpolation: k.interpolation, implicitSplited: implicitSplited)
            let values = group.currentItemValues
            replaceKeyframe(splitKeyframe0, at: ki.index, in: group, time: time)
            insertKeyframe(keyframe: splitKeyframe1, drawing: isSplitDrawing ? values.drawing.deepCopy : Drawing(), geometries: values.geometries, materials: values.materials, transform: values.transform, text: values.text, at: ki.index + 1, in: group, time: time)
            if implicitSplited {
                sceneView.cutView.highlight()
            }
        } else {
            screen?.tempNotAction()
        }
    }
    func removeKeyframe() {
        let ki = nearestKeyframeIndexTuple(at: convertToInternal(currentPoint))
        let cutEntity =  sceneEntity.cutEntities[ki.cutIndex]
        let group = cutEntity.cut.editGroup
        if ki.cutIndex == 0 && ki.keyframeIndex == 0 && group.keyframes.count >= 2 {
            removeFirstKeyframe(atCutIndex: ki.cutIndex)
        } else if ki.cutIndex + 1 < sceneEntity.cutEntities.count && ki.keyframeIndex == nil && sceneEntity.cutEntities[ki.cutIndex + 1].cut.editGroup.keyframes.count >= 2 {
            removeFirstKeyframe(atCutIndex: ki.cutIndex + 1)
        } else if group.keyframes.count <= 1 || ki.keyframeIndex == nil {
            if selectionCutEntity.cut.groups.count <= 1 {
                removeCut(at: ki.keyframeIndex == nil ? ki.cutIndex + 1 : ki.cutIndex)
            } else {
                removeGroup(at: cutEntity.cut.editGroupIndex, in: cutEntity)
            }
        } else if let ki = ki.keyframeIndex {
            removeKeyframe(at: ki, in: group, time: time)
        } else {
            screen?.tempNotAction()
        }
    }
    private func removeFirstKeyframe(atCutIndex cutIndex: Int) {
        let cutEntity = sceneEntity.cutEntities[cutIndex]
        let group = cutEntity.cut.editGroup
        let deltaTime = group.keyframes[1].time
        removeKeyframe(at: 0, in: group, time: time)
        let keyframes = group.keyframes.map { $0.withTime($0.time - deltaTime) }
        setKeyframes(keyframes, oldKeyframes: group.keyframes, in: group, cutEntity, time: time)
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
                setTime(previousCutTimeLocation + previousCut.editGroup.lastKeyframeTime, oldTime: time, alwaysUpdateCutIndex: true)
            } else if time >= maxTime {
                setTime(maxTime - 1, oldTime: time, alwaysUpdateCutIndex: true)
            }
        }
    }
    private func setKeyframes(_ keyframes: [Keyframe], oldKeyframes: [Keyframe], in group: Group, _ cutEntity: CutEntity, time: Int) {
        registerUndo { $0.setKeyframes(oldKeyframes, oldKeyframes: keyframes, in: group, cutEntity, time: $1) }
        self.time = time
        group.replaceKeyframes(keyframes)
        setUpdate(true, in: cutEntity)
    }
    private func setTime(_ t: Int, oldTime: Int, alwaysUpdateCutIndex: Bool = false) {
        registerUndo {(TimeLine,Int) in TimeLine.setTime(oldTime, oldTime: t, alwaysUpdateCutIndex: alwaysUpdateCutIndex) }
        updateWith(time: t, scrollPoint: CGPoint(x: x(withTime: t), y: 0), alwaysUpdateCutIndex: alwaysUpdateCutIndex)
        setUpdate(true, in: selectionCutEntity)
    }
    private func replaceKeyframe(_ keyframe: Keyframe, at index: Int, in group: Group, time: Int) {
        registerUndo { [ok = group.keyframes[index]] in $0.replaceKeyframe(ok, at: index, in: group, time: $1) }
        self.time = time
        group.replaceKeyframe(keyframe, at: index)
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        isUpdate = true
    }
    private func insertKeyframe(keyframe: Keyframe, drawing: Drawing, geometries: [Geometry], materials: [Material?], transform: Transform?, text: Text?, at index: Int, in group: Group, time: Int) {
        registerUndo { $0.removeKeyframe(at: index, in: group, time: $1) }
        self.time = time
        group.insertKeyframe(keyframe, drawing: drawing, geometries: geometries, materials: materials, transform: transform, text: text, at: index)
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        isUpdate = true
    }
    private func removeKeyframe(at index: Int, in group: Group, time: Int) {
        registerUndo { [ok = group.keyframes[index], okv = group.keyframeItemValues(at: index)] in $0.insertKeyframe(keyframe: ok, drawing: okv.drawing, geometries: okv.geometries, materials: okv.materials, transform: okv.transform, text: okv.text, at: index, in: group, time: $1) }
        self.time = time
        group.removeKeyframe(at: index)
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        isUpdate = true
    }
    private var previousTime: Int? {
        let cut = selectionCutEntity.cut
        let group = cut.editGroup
        let keyframeIndex = group.loopedKeyframeIndex(withTime: cut.time)
        let t = group.loopedKeyframeIndexes[keyframeIndex.loopedIndex].time
        if cutTime - t > 0 {
            return cutTimeLocation(withCutIndex: selectionCutIndex) + t
        } else if keyframeIndex.loopedIndex - 1 >= 0 {
            return cutTimeLocation(withCutIndex: selectionCutIndex) + group.loopedKeyframeIndexes[keyframeIndex.loopedIndex - 1].time
        } else if selectionCutIndex - 1 >= 0 {
            return cutTimeLocation(withCutIndex: selectionCutIndex - 1) + sceneEntity.cutEntities[selectionCutIndex - 1].cut.editGroup.lastLoopedKeyframeTime
        } else {
            return nil
        }
    }
    
    override func willDrag(with event: DragEvent) -> Bool {
        if isPlaying {
            stop()
            return false
        } else {
            return true
        }
    }
    
    private var isDrag = false, dragOldTime = 0.0.cf, editCutEntity: CutEntity?, dragOldCutTimeLength = 0, dragMinDeltaTime = 0, dragMinCutDeltaTime = 0
    private var dragOldSlideGroups = [(group: Group, keyframeIndex: Int, oldKeyframes: [Keyframe])]()
    override func drag(with event: DragEvent) {
        if isPlaying {
            stop()
        }
        let p = convertToInternal(point(from: event))
        switch event.sendType {
        case .begin:
            let cutEntity = sceneEntity.cutEntities[cutIndex(withX: p.x)]
            if p.y > bounds.height/2 - (bounds.height/4 - timeHeight/2 - 1) || cutEntity.cut.groups.count == 1 {
                let result = nearestKeyframeIndexTuple(at: p)
                let editCutEntity = sceneEntity.cutEntities[result.cutIndex]
                let group = editCutEntity.cut.editGroup
                if let ki = result.keyframeIndex {
                    if ki > 0 {
                        let preTime = group.keyframes[ki - 1].time, time = group.keyframes[ki].time
                        dragMinDeltaTime = preTime - time + 1
                        dragOldSlideGroups = [(group, ki, group.keyframes)]
                    }
                } else {
                    let preTime = group.keyframes[group.keyframes.count - 1].time, time = editCutEntity.cut.timeLength
                    dragMinDeltaTime = preTime - time + 1
                    dragOldSlideGroups = []
                }
                dragMinCutDeltaTime = max(editCutEntity.cut.maxTimeWithOtherGroup(group) - editCutEntity.cut.timeLength + 1, dragMinDeltaTime)
                self.editCutEntity = result.cutIndex == 0 && result.keyframeIndex == 0 ? nil : editCutEntity
                dragOldCutTimeLength = editCutEntity.cut.timeLength
            } else {
                let result = groupIndexTuple(at: p)
                let editCutEntity = sceneEntity.cutEntities[result.cutIndex]
                let minGroup = editCutEntity.cut.groups[result.groupIndex]
                if let ki = result.keyframeIndex {
                    if ki > 0 {
                        let kt = minGroup.keyframes[ki].time
                        var oldSlideGroups = [(group: Group, keyframeIndex: Int, oldKeyframes: [Keyframe])](), pkt = 0
                        for group in editCutEntity.cut.groups {
                            let result = Keyframe.index(time: kt, with: group.keyframes)
                            let index: Int? = result.interValue > 0 ? (result.index + 1 <= group.keyframes.count - 1 ? result.index + 1 : nil) : result.index
                            if let i = index {
                                oldSlideGroups.append((group, i, group.keyframes))
                            }
                            let preIndex: Int? = result.interValue > 0 ?  result.index : (result.index > 0 ? result.index - 1 : nil)
                            if let pi = preIndex {
                                let preTime = group.keyframes[pi].time
                                if pkt < preTime {
                                    pkt = preTime
                                }
                            }
                        }
                        dragMinDeltaTime = pkt - kt + 1
                        dragOldSlideGroups = oldSlideGroups
                    }
                } else {
                    let preTime = minGroup.keyframes[minGroup.keyframes.count - 1].time, time = editCutEntity.cut.timeLength
                    dragMinDeltaTime = preTime - time + 1
                    dragOldSlideGroups = []
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
                for slideGroup in dragOldSlideGroups {
                    var nks = slideGroup.oldKeyframes
                    for i in slideGroup.keyframeIndex ..< nks.count {
                        nks[i] = nks[i].withTime(nks[i].time + deltaTime)
                    }
                    slideGroup.group.replaceKeyframes(nks)
                }
                let groupTimeLength = dragOldCutTimeLength + max(dragMinCutDeltaTime, dt)
                if groupTimeLength != editCutEntity.cut.timeLength {
                    editCutEntity.cut.timeLength = groupTimeLength
                    updateMaxTime()
                }
                updateViews()
                setNeedsDisplay()
            }
        case .end:
            if isDrag, let editCutEntity = editCutEntity {
                setTime(time, oldTime: time)
                let t = convertToInternal(point(from: event)).x/editFrameRateWidth
                let dt = Int(t - dragOldTime + (t - dragOldTime >= 0 ? 0.5 : -0.5))
                let deltaTime = max(dragMinDeltaTime, dt)
                for slideGroup in dragOldSlideGroups {
                    var nks = slideGroup.oldKeyframes
                    if deltaTime != 0 {
                        for i in slideGroup.keyframeIndex ..< nks.count { nks[i] = nks[i].withTime(nks[i].time + deltaTime) }
                        setKeyframes(nks, oldKeyframes: slideGroup.oldKeyframes, in: slideGroup.group, editCutEntity, time: time)
                    } else {
                        slideGroup.group.replaceKeyframes(nks)
                    }
                }
                let timeLength = dragOldCutTimeLength + max(dragMinCutDeltaTime, dt)
                if timeLength != dragOldCutTimeLength {
                    setTimeLength(timeLength, oldTimeLength: dragOldCutTimeLength, in: editCutEntity, time: time)
                }
                setTime(time, oldTime: time)
                dragOldSlideGroups = []
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
    var moveQuasimode = false {
        didSet {
            screen?.updateCursor(with: currentPoint)
        }
    }
    var oldGroups = [Group]()
    override func move(with event: DragEvent) {
        if isPlaying {
            stop()
        }
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            oldGroups = selectionCutEntity.cut.groups
            oldIndex = selectionCutEntity.cut.editGroupIndex
            oldP = p
            editCutEntity = selectionCutEntity
        case .sending:
            if let cutEntity = editCutEntity {
                let d = p.y - oldP.y
                let i = (oldIndex + Int(d/itemHeight)).clip(min: 0, max: cutEntity.cut.groups.count), oi = cutEntity.cut.editGroupIndex
                cutEntity.cut.groups.remove(at: oi)
                cutEntity.cut.groups.insert(cutEntity.cut.editGroup, at: oi < i ? i - 1 : i)
                layer.setNeedsDisplay()
                sceneView.cutView.setNeedsDisplay()
                sceneView.timeline.setNeedsDisplay()
                sceneView.keyframeView.update()
                sceneView.transformView.update()
            }
        case .end:
            if let cutEntity = editCutEntity {
                let d = p.y - oldP.y
                let i = (oldIndex + Int(d/itemHeight)).clip(min: 0, max: cutEntity.cut.groups.count), oi = cutEntity.cut.editGroupIndex
                if oldIndex != i {
                    var groups = cutEntity.cut.groups
                    groups.remove(at: oi)
                    groups.insert(cutEntity.cut.editGroup, at: oi < i ? i - 1 : i)
                    setGroups(groups, oldGroups: oldGroups, in: cutEntity, time: time)
                } else if oi != i {
                    cutEntity.cut.groups.remove(at: oi)
                    cutEntity.cut.groups.insert(cutEntity.cut.editGroup, at: oi < i ? i - 1 : i)
                    layer.setNeedsDisplay()
                    sceneView.cutView.setNeedsDisplay()
                    sceneView.timeline.setNeedsDisplay()
                    sceneView.keyframeView.update()
                    sceneView.transformView.update()
                }
                oldGroups = []
                editCutEntity = nil
            }
        }
    }
    private func setEditGroup(_ group: Group, oldGroup: Group, in cutEntity: CutEntity, time: Int) {
        registerUndo { $0.setEditGroup(oldGroup, oldGroup: group, in: cutEntity, time: $1) }
        self.time = time
        cutEntity.cut.editGroup = group
        setUpdate(true, in: cutEntity)
        layer.setNeedsDisplay()
        sceneView.cutView.setNeedsDisplay()
        sceneView.timeline.setNeedsDisplay()
        sceneView.keyframeView.update()
        sceneView.transformView.update()
    }
    private func setGroups(_ groups: [Group], oldGroups: [Group], in cutEntity: CutEntity, time: Int) {
        registerUndo { $0.setGroups(oldGroups, oldGroups: groups, in: cutEntity, time: $1) }
        self.time = time
        cutEntity.cut.groups = groups
        setUpdate(true, in: cutEntity)
        layer.setNeedsDisplay()
        sceneView.cutView.setNeedsDisplay()
        sceneView.timeline.setNeedsDisplay()
        sceneView.keyframeView.update()
        sceneView.transformView.update()
    }
    
    func select(_ event: DragEvent, type: DragEvent.SendType) {
        if isPlaying {
            stop()
        }
    }
    
    private var isGroupScroll = false, deltaScrollY = 0.0.cf, scrollCutEntity: CutEntity?
    override func scroll(with event: ScrollEvent) {
        if isPlaying {
            stop()
        }
        if event.sendType  == .begin {
            isGroupScroll = selectionCutEntity.cut.groups.count == 1 ? false : abs(event.scrollDeltaPoint.x) < abs(event.scrollDeltaPoint.y)
        }
        if isGroupScroll {
            if !event.scrollMomentum.contains(NSEvent.Phase.began) && !event.scrollMomentum.contains(NSEvent.Phase.changed) && !event.scrollMomentum.contains(NSEvent.Phase.ended) {
                let p = point(from: event)
                switch event.sendType {
                case .begin:
                    oldIndex = selectionCutEntity.cut.editGroupIndex
                    oldP = p
                    deltaScrollY = 0
                    scrollCutEntity = selectionCutEntity
                case .sending:
                    if let scrollCutEntity = scrollCutEntity {
                        deltaScrollY += event.scrollDeltaPoint.y
                        let i = (oldIndex - Int(deltaScrollY/10)).clip(min: 0, max: scrollCutEntity.cut.groups.count - 1)
                        if scrollCutEntity.cut.editGroupIndex != i {
                            scrollCutEntity.cut.editGroup = scrollCutEntity.cut.groups[i]
                            updateViews()
                        }
                    }
                case .end:
                    if let scrollCutEntity = scrollCutEntity {
                        let i = (oldIndex - Int(deltaScrollY/10)).clip(min: 0, max: scrollCutEntity.cut.groups.count - 1)
                        if oldIndex != i {
                            setEditGroup(scrollCutEntity.cut.groups[i], oldGroup: scrollCutEntity.cut.groups[oldIndex], in: scrollCutEntity, time: time)
                        } else if scrollCutEntity.cut.editGroupIndex != i {
                            scrollCutEntity.cut.editGroup = scrollCutEntity.cut.groups[i]
                            updateViews()
                        }
                        self.scrollCutEntity = nil
                    }
                }
            }
        } else {
            let x = (scrollPoint.x - event.scrollDeltaPoint.x).clip(min: 0, max: self.x(withTime: maxTime - 1))
            scrollPoint = CGPoint(x: event.sendType == .begin ? self.x(withTime: time(withX: x)) : x, y: 0)
        }
    }
    override func zoom(with event: PinchEvent) {
        zoom(at: point(from: event)) {
            editFrameRateWidth = (editFrameRateWidth*(event.magnification*2.5 + 1)).clip(min: 1, max: Timeline.defaultFrameRateWidth)
        }
    }
    override func reset() {
        zoom(at: currentPoint) {
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
