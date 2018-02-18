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

protocol Animatable {
    func step(_ f0: Int)
    func linear(_ f0: Int, _ f1: Int, t: CGFloat)
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline)
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline)
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline)
}

struct Animation: Codable {
    var keyframes: [Keyframe] {
        willSet {
            var oldTime = Beat(0)
            newValue.forEach {
                guard $0.time >= oldTime else {
                    fatalError()
                }
                oldTime = $0.time
            }
        }
        didSet {
            self.loopFrames = Animation.loopFrames(with: keyframes, duration: duration)
        }
    }
    var duration: Beat {
        didSet {
            self.loopFrames = Animation.loopFrames(with: keyframes, duration: duration)
        }
    }
    
    private(set) var time = Beat(0)
    private(set) var isInterpolated = false
    private(set) var editKeyframeIndex = 0
    private(set) var editLoopframeIndex = 0

    var selectionKeyframeIndexes: [Int]
    
    init(keyframes: [Keyframe] = [Keyframe()], duration: Beat = 1,
         selectionKeyframeIndexes: [Int] = []) {
        
        self.keyframes = keyframes
        self.duration = duration
        self.loopFrames = Animation.loopFrames(with: keyframes, duration: duration)
        self.selectionKeyframeIndexes = selectionKeyframeIndexes
    }
    private init(keyframes: [Keyframe],
                 editKeyframeIndex: Int, selectionKeyframeIndexes: [Int],
                 time: Beat,
                 duration: Beat, isInterpolated: Bool,
                 loopFrames: [LoopFrame]) {
        
        self.keyframes = keyframes
        self.editKeyframeIndex = editKeyframeIndex
        self.selectionKeyframeIndexes = selectionKeyframeIndexes
        self.time = time
        self.duration = duration
        self.isInterpolated = isInterpolated
        self.loopFrames = loopFrames
    }
    
    struct LoopFrame: Codable {
        var index: Int, time: Beat, loopCount: Int, loopingCount: Int
    }
    private(set) var loopFrames: [LoopFrame]
    private static func loopFrames(with keyframes: [Keyframe], duration: Beat) -> [LoopFrame] {
        var loopFrames = [LoopFrame](), previousIndexes = [Int]()
        for (i, keyframe) in keyframes.enumerated() {
            if keyframe.loop == .ended, let preIndex = previousIndexes.last {
                let loopCount = previousIndexes.count
                previousIndexes.removeLast()
                let time = keyframe.time
                let nextTime = i + 1 >= keyframes.count ? duration : keyframes[i + 1].time
                var t = time, isEndT = false
                while t <= nextTime {
                    for j in preIndex ..< i {
                        let nk = loopFrames[j]
                        loopFrames.append(LoopFrame(index: nk.index, time: t,
                                                    loopCount: loopCount,
                                                    loopingCount: loopCount))
                        t += loopFrames[j + 1].time - nk.time
                        if t > nextTime {
                            if i == keyframes.count - 1 {
                                loopFrames.append(LoopFrame(index: loopFrames[j + 1].index,
                                                            time: t, loopCount: loopCount,
                                                            loopingCount: loopCount))
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
                let loopCount = keyframe.loop == .began ?
                    previousIndexes.count + 1 : previousIndexes.count
                loopFrames.append(LoopFrame(index: i, time: keyframe.time,
                                            loopCount: loopCount,
                                            loopingCount: max(0, loopCount - 1)))
            }
            if keyframe.loop == .began {
                previousIndexes.append(loopFrames.count - 1)
            }
        }
        return loopFrames
    }
    
    mutating func update(withTime time: Beat) {
        self.time = time
        let timeResult = loopedKeyframeIndex(withTime: time)
        let li1 = timeResult.loopFrameIndex, interTime = max(0, timeResult.interTime)
        editLoopframeIndex = li1
        let lf1 = loopFrames[li1]
        editKeyframeIndex = lf1.index
        let k1 = keyframes[lf1.index]
        if interTime == 0 || timeResult.duration == 0
            || li1 + 1 >= loopFrames.count || k1.interpolation == .none {
            
            isInterpolated = false
            return
        }
        let lf2 = loopFrames[li1 + 1]
        isInterpolated = lf1.time != lf2.time
    }
    
    mutating func update(withTime time: Beat, to animatable: Animatable) {
        self.time = time
        let timeResult = loopedKeyframeIndex(withTime: time)
        let li1 = timeResult.loopFrameIndex, interTime = max(0, timeResult.interTime)
        editLoopframeIndex = li1
        let lf1 = loopFrames[li1]
        editKeyframeIndex = lf1.index
        let k1 = keyframes[lf1.index]
        guard interTime > 0 && timeResult.duration > 0
            && li1 + 1 < loopFrames.count && k1.interpolation != .none else {
            
            isInterpolated = false
            animatable.step(lf1.index)
            return
        }
        let lf2 = loopFrames[li1 + 1]
        guard lf1.time != lf2.time else {
            isInterpolated = false
            animatable.step(lf1.index)
            return
        }
        isInterpolated = true
        let t = k1.easing.convertT(Double(interTime / timeResult.duration).cf)
        if k1.interpolation == .linear || keyframes.count <= 2 {
            animatable.linear(lf1.index, lf2.index, t: t)
        } else {
            let isUseIndex0 = li1 - 1 >= 0 && k1.interpolation != .bound
                && loopFrames[li1 - 1].time != lf1.time
            let isUseIndex3 = li1 + 2 < loopFrames.count
                && keyframes[lf2.index].interpolation != .bound
                && loopFrames[li1 + 2].time != lf2.time
            if isUseIndex0 {
                if isUseIndex3 {
                    let lf0 = loopFrames[li1 - 1], lf3 = loopFrames[li1 + 2]
                    let ms = Monospline(x0: Double(lf0.time).cf,
                                        x1: Double(lf1.time).cf,
                                        x2: Double(lf2.time).cf,
                                        x3: Double(lf3.time).cf,
                                        t: t)
                    animatable.monospline(lf0.index, lf1.index, lf2.index, lf3.index, with: ms)
                } else {
                    let lf0 = loopFrames[li1 - 1]
                    let ms = Monospline(x0: Double(lf0.time).cf,
                                        x1: Double(lf1.time).cf,
                                        x2: Double(lf2.time).cf,
                                        t: t)
                    animatable.lastMonospline(lf0.index, lf1.index, lf2.index, with: ms)
                }
            } else if isUseIndex3 {
                let lf3 = loopFrames[li1 + 2]
                let ms = Monospline(x1: Double(lf1.time).cf,
                                    x2: Double(lf2.time).cf,
                                    x3: Double(lf3.time).cf,
                                    t: t)
                animatable.firstMonospline(lf1.index, lf2.index, lf3.index, with: ms)
            } else {
                animatable.linear(lf1.index, lf2.index, t: t)
            }
        }
    }
    
    func interpolation(at li: Int,
                       step: ((LoopFrame) -> ()),
                       linear: ((LoopFrame, LoopFrame) -> ()),
                       monospline: ((LoopFrame, LoopFrame, LoopFrame, LoopFrame) -> ()),
                       firstMonospline: ((LoopFrame, LoopFrame, LoopFrame) -> ()),
                       endMonospline: ((LoopFrame, LoopFrame, LoopFrame) -> ())) {
        let lf1 = loopFrames[li], lf2 = loopFrames[li + 1]
        let k1 = keyframes[lf1.index], k2 = keyframes[lf2.index]
        if k1.interpolation == .none || lf2.time - lf1.time == 0 {
            step(lf1)
        } else if k1.interpolation == .linear {
            linear(lf1, lf2)
        } else {
            let isUseIndex0 = li - 1 >= 0 && k2.interpolation != .bound
                && loopFrames[li - 1].time != lf1.time
            let isUseIndex3 = li + 2 < loopFrames.count
                && k2.interpolation != .bound
                && loopFrames[li + 2].time != lf2.time
            if isUseIndex0 {
                if isUseIndex3 {
                    let lf0 = loopFrames[li - 1], lf3 = loopFrames[li + 2]
                    monospline(lf0, lf1, lf2, lf3)
                } else {
                    let lf0 = loopFrames[li - 1]
                    endMonospline(lf0, lf1, lf2)
                }
            } else if isUseIndex3 {
                let lf3 = loopFrames[li + 2]
                firstMonospline(lf1, lf2, lf3)
            } else {
                linear(lf1, lf2)
            }
        }
    }
    
    var editKeyframe: Keyframe {
        return keyframes[min(editKeyframeIndex, keyframes.count - 1)]
    }
    func loopedKeyframeIndex(withTime t: Beat
        ) -> (loopFrameIndex: Int, keyframeIndex: Int, interTime: Beat, duration: Beat) {
        
        var oldT = duration
        for i in (0 ..< loopFrames.count).reversed() {
            let li = loopFrames[i]
            let kt = li.time
            if t >= kt {
                return (i, li.index, t - kt, oldT - kt)
            }
            oldT = kt
        }
        return (0, 0, t - loopFrames.first!.time, oldT - loopFrames.first!.time)
    }
    func interpolatedKeyframeIndex(withTime t: Beat) -> Int? {
        guard t < duration else {
            return nil
        }
        for i in (0 ..< keyframes.count).reversed() {
            if t >= keyframes[i].time {
                return i
            }
        }
        return 0
    }
    func movingKeyframeIndex(withTime t: Beat) -> (index: Int?, isSolution: Bool) {
        if t > duration {
            return (nil, false)
        } else if t == duration {
            return (nil, true)
        } else {
            for i in (0 ..< keyframes.count).reversed() {
                let time = keyframes[i].time
                if t == time {
                    return (i, true)
                } else if t > time {
                    return (i + 1, true)
                }
            }
            return (nil, false)
        }
    }
    var minDuration: Beat {
        return (keyframes.last?.time ?? 0) + 1
    }
    var lastKeyframeTime: Beat {
        return keyframes.isEmpty ? 0 : keyframes[keyframes.count - 1].time
    }
    var lastLoopedKeyframeTime: Beat {
        if loopFrames.isEmpty {
            return 0
        }
        let t = loopFrames[loopFrames.count - 1].time
        if t >= duration {
            return loopFrames.count >= 2 ? loopFrames[loopFrames.count - 2].time : 0
        } else {
            return t
        }
    }
}
extension Animation: Equatable {
    static func ==(lhs: Animation, rhs: Animation) -> Bool {
        return lhs.keyframes == rhs.keyframes
            && lhs.duration == rhs.duration
            && lhs.selectionKeyframeIndexes == rhs.selectionKeyframeIndexes
    }
}
extension Animation: Referenceable {
    static let name = Localization(english: "Animation", japanese: "アニメーション")
}

/**
 # Issue
 - 0秒キーフレーム
 */
final class AnimationEditor: Layer, Respondable {
    static let name = Localization(english: "Animation Editor", japanese: "アニメーションエディタ")
    
    init(_ animation: Animation = Animation(),
         beginBaseTime: Beat = 0, baseTimeInterval: Beat = Beat(1, 16),
         origin: CGPoint = CGPoint(),
         height: CGFloat = 24.0, smallHeight: CGFloat = 8.0, isSmall: Bool = true) {
        
        self.animation = animation
        self.beginBaseTime = beginBaseTime
        self.baseTimeInterval = baseTimeInterval
        self.height = height
        self.smallHeight = smallHeight
        self.isSmall = isSmall
        super.init()
        frame = CGRect(x: origin.x, y: origin.y, width: 0, height: isSmall ? smallHeight : height)
        updateChildren()
    }
    
    private static func knobLine(from p: CGPoint, lineColor: Color,
                                 baseWidth: CGFloat, lineHeight: CGFloat,
                                 lineWidth: CGFloat = 4, linearLineWidth: CGFloat = 2,
                                 with interpolation: Keyframe.Interpolation) -> Layer {
        let path = CGMutablePath()
        switch interpolation {
        case .spline:
            break
        case .bound:
            path.addRect(CGRect(x: p.x - linearLineWidth / 2, y: p.y - lineHeight / 2,
                                width: linearLineWidth, height: lineHeight / 2))
        case .linear:
            path.addRect(CGRect(x: p.x - linearLineWidth / 2, y: p.y - lineHeight / 2,
                                width: linearLineWidth, height: lineHeight))
        case .none:
            path.addRect(CGRect(x: p.x - lineWidth / 2, y: p.y - lineHeight / 2,
                                width: lineWidth, height: lineHeight))
        }
        let layer = PathLayer()
        layer.path = path
        layer.fillColor = lineColor
        return layer
    }
    private static func knob(from p: CGPoint,
                             fillColor: Color, lineColor: Color,
                             baseWidth: CGFloat,
                             knobHalfHeight: CGFloat, subKnobHalfHeight: CGFloat,
                             with label: Keyframe.Label) -> DiscreteKnob {
        let kh = label == .main ? knobHalfHeight : subKnobHalfHeight
        let knob = DiscreteKnob()
        knob.frame = CGRect(x: p.x - baseWidth / 2, y: p.y - kh,
                             width: baseWidth, height: kh * 2)
        knob.fillColor = fillColor
        knob.lineColor = lineColor
        return knob
    }
    private static func keyLineWith(_ keyframe: Keyframe, lineColor: Color,
                                    baseWidth: CGFloat,
                                    lineWidth: CGFloat, maxLineWidth: CGFloat,
                                    position: CGPoint, width: CGFloat) -> Layer {
        let path = CGMutablePath()
        if keyframe.easing.isLinear {
            path.addRect(CGRect(x: position.x, y: position.y - lineWidth / 2,
                                width: width, height: lineWidth))
        } else {
            let b = keyframe.easing.bezier, bw = width
            let bx = position.x, count = Int(width / 5.0)
            let d = 1 / count.cf
            let points: [CGPoint] = (0 ... count).map { i in
                let dx = d * i.cf
                let dp = b.difference(withT: dx)
                let dy = max(0.5, min(maxLineWidth, (dp.x == dp.y ?
                    .pi / 2 : 1.8 * atan2(dp.y, dp.x)) / (.pi / 2)))
                return CGPoint(x: dx * bw + bx, y: dy)
            }
            let ps0 = points.map { CGPoint(x: $0.x, y: position.y + $0.y) }
            let ps1 = points.reversed().map { CGPoint(x: $0.x, y: position.y - $0.y) }
            path.addLines(between: ps0 + ps1)
        }
        let layer = PathLayer()
        layer.path = path
        layer.fillColor = lineColor
        return layer
    }
    
    var lineColorHandler: ((Int) -> (Color)) = { _ in .content }
    var smallLineColorHandler: (() -> (Color)) = { .content }
    var knobColorHandler: ((Int) -> (Color)) = { _ in .knob }
    private var knobs = [DiscreteKnob]()
    let editLayer: Layer = {
        let layer = Layer()
        layer.fillColor = .selection
        layer.lineColor = nil
        layer.isHidden = true
        return layer
    } ()
    let indicatedLayer: Layer = {
        let layer = Layer()
        layer.fillColor = .subIndicated
        layer.lineColor = nil
        layer.isHidden = true
        return layer
    } ()
    func updateChildren() {
        let height = frame.height
        let midY = height / 2, lineWidth = 2.0.cf
        let khh = isSmall ? smallKnobHalfHeight : self.knobHalfHeight
        let skhh = isSmall ? smallSubKnobHalfHeight : self.subKnobHalfHeight
        let selectionStartIndex = animation.selectionKeyframeIndexes.first
            ?? animation.keyframes.count - 1
        let selectionEndIndex = animation.selectionKeyframeIndexes.last ?? 0
        
        var keyLines = [Layer](), knobs = [DiscreteKnob](), selections = [Layer]()
        for (i, li) in animation.loopFrames.enumerated() {
            let keyframe = animation.keyframes[li.index]
            let time = li.time
            let nextTime = i + 1 >= animation.loopFrames.count ?
                animation.duration : animation.loopFrames[i + 1].time
            let x = self.x(withTime: time), nextX = self.x(withTime: nextTime)
            let width = nextX - x
            let position = CGPoint(x: x, y: midY)
            
            if !isSmall {
                let keyLineColor = lineColorHandler(li.index)
                let keyLine = AnimationEditor.keyLineWith(keyframe,
                                                          lineColor: keyLineColor,
                                                          baseWidth: baseWidth,
                                                          lineWidth: lineWidth,
                                                          maxLineWidth: maxLineWidth,
                                                          position: position, width: width)
                keyLines.append(keyLine)
                
                let knobLine = AnimationEditor.knobLine(from: position,
                                                        lineColor: keyLineColor,
                                                        baseWidth: baseWidth,
                                                        lineHeight: height - 2,
                                                        with: keyframe.interpolation)
                keyLines.append(knobLine)
                
                if li.loopCount > 0 {
                    let path = CGMutablePath()
                    if i > 0 && animation.loopFrames[i - 1].loopCount < li.loopCount {
                        path.move(to: CGPoint(x: x, y: midY + height / 2 - 4))
                        path.addLine(to: CGPoint(x: x + 3, y: midY + height / 2 - 1))
                        path.addLine(to: CGPoint(x: x, y: midY + height / 2 - 1))
                        path.closeSubpath()
                    }
                    path.addRect(CGRect(x: x, y: midY + height / 2 - 2, width: width, height: 1))
                    if li.loopingCount > 0 {
                        if i > 0 && animation.loopFrames[i - 1].loopingCount < li.loopingCount {
                            path.move(to: CGPoint(x: x, y: 1))
                            path.addLine(to: CGPoint(x: x + 3, y: 1))
                            path.addLine(to: CGPoint(x: x, y: 4))
                            path.closeSubpath()
                        }
                        path.addRect(CGRect(x: x, y: 1, width: width, height: 1))
                    }
                    
                    let layer = PathLayer()
                    layer.path = path
                    layer.fillColor = keyLineColor
                    keyLines.append(layer)
                }
            }
            
            if i > 0 {
                let fillColor = li.loopingCount > 0 || li.index == editingKeyframeIndex ?
                    Color.editing : knobColorHandler(li.index)
                let lineColor = ((li.time + beginBaseTime) / baseTimeInterval).isInteger ?
                    Color.border : Color.warning
                let knob = AnimationEditor.knob(from: position,
                                                fillColor: fillColor,
                                                lineColor: lineColor,
                                                baseWidth: baseWidth,
                                                knobHalfHeight: khh,
                                                subKnobHalfHeight: skhh,
                                                with: keyframe.label)
                knobs.append(knob)
            }
            
            if animation.selectionKeyframeIndexes.contains(li.index) {
                let layer = Layer.selection
                layer.frame = CGRect(x: position.x, y: 0, width: width, height: height)
                selections.append(layer)
            } else if li.index >= selectionStartIndex && li.index < selectionEndIndex {
                let layer = PathLayer()
                layer.fillColor = .select
                layer.lineColor = .selectBorder
                let path = CGMutablePath(), h = 2.0.cf
                path.addRect(CGRect(x: position.x, y: 0, width: width, height: h))
                path.addRect(CGRect(x: position.x, y: height - h, width: width, height: h))
                selections.append(layer)
            }
        }
        
        let maxX = self.x(withTime: animation.duration)
        
        if isSmall {
            let keyLine = Layer()
            keyLine.frame = CGRect(x: 0, y: midY - 0.5, width: maxX, height: 1)
            keyLine.fillColor = smallLineColorHandler()
            keyLine.lineColor = nil
            keyLines.append(keyLine)
        }
        
        let durationFillColor = editingKeyframeIndex == animation.keyframes.count ?
            Color.editing : Color.knob
        let durationLineColor = ((animation.duration + beginBaseTime) / baseTimeInterval).isInteger ?
            Color.border : Color.warning
        let durationKnob = AnimationEditor.knob(from: CGPoint(x: maxX, y: midY),
                                                fillColor: durationFillColor,
                                                lineColor: durationLineColor,
                                                baseWidth: baseWidth,
                                                knobHalfHeight: khh,
                                                subKnobHalfHeight: skhh,
                                                with: .main)
        knobs.append(durationKnob)
        
        self.knobs = knobs
        
        if let selectionLayer = selectionLayer {
            selections.append(selectionLayer)
        }
        
        updateEditLoopframeIndex()
        updateIndicatedLayer()
        replace(children: [editLayer, indicatedLayer] + keyLines + knobs as [Layer] + selections)
    }
    private func updateWithBeginTime() {
        for (i, li) in animation.loopFrames.enumerated() {
            if i > 0 {
                knobs[i - 1].lineColor = ((li.time + beginBaseTime) / baseTimeInterval).isInteger ?
                    Color.border : Color.warning
            }
        }
        knobs.last?.lineColor = ((animation.duration + beginBaseTime) / baseTimeInterval).isInteger ?
            Color.border : Color.warning
    }
    
    var height: CGFloat {
        didSet {
            updateWithHeight()
        }
    }
    var smallHeight: CGFloat {
        didSet {
            updateWithHeight()
        }
    }
    var isSmall = true {
        didSet {
            updateWithHeight()
        }
    }
    private func updateWithHeight() {
        frame.size.height = isSmall ? smallHeight : height
        updateChildren()
    }
    private var isUseUpdateChildren = true
    var animation: Animation {
        didSet {
            if isUseUpdateChildren {
                editLoopframeIndex = animation.editLoopframeIndex
                isInterpolated = animation.isInterpolated
                updateChildren()
                updateIndicatedKeyframeIndex(at: cursorPoint)
            }
        }
    }
    
    override var isIndicated: Bool {
        didSet {
            indicatedLayer.isHidden = !isIndicated
        }
    }
    var indicatedKeyframeIndex: Int? {
        didSet {
            updateIndicatedLayer()
        }
    }
    func updateIndicatedLayer() {
        if let indicatedKeyframeIndex = indicatedKeyframeIndex {
            let time: Beat
            if indicatedKeyframeIndex >= animation.keyframes.count {
                time = animation.duration
            } else {
                time = animation.keyframes[indicatedKeyframeIndex].time
            }
            let x = self.x(withTime: time)
            indicatedLayer.frame = CGRect(x: x - baseWidth / 2, y: 0,
                                          width: baseWidth, height: frame.height)
        }
    }
    func moveCursor(with event: MoveEvent) -> Bool {
        updateIndicatedKeyframeIndex(at: point(from: event))
        return true
    }
    func updateIndicatedKeyframeIndex(at p: CGPoint) {
        if let i = nearestKeyframeIndex(at: p) {
            indicatedKeyframeIndex = i == 0 ? nil : i
        } else {
            indicatedKeyframeIndex = animation.keyframes.count
        }
    }
    
    func updateKeyframeIndex(with animation: Animation) {
        isInterpolated = animation.isInterpolated
        editLoopframeIndex = animation.editLoopframeIndex
    }
    
    var isInterpolated = false {
        didSet {
            if isInterpolated != oldValue {
                updateEditLoopframeIndex()
            }
        }
    }
    var isEdit = false {
        didSet {
            editLayer.isHidden = !isEdit
        }
    }
    var editLoopframeIndex = 0 {
        didSet {
            if editLoopframeIndex != oldValue {
                updateEditLoopframeIndex()
            }
        }
    }
    func updateEditLoopframeIndex() {
        let time: Beat
        if editLoopframeIndex >= animation.loopFrames.count {
            time = animation.duration
        } else {
            time = animation.loopFrames[editLoopframeIndex].time
        }
        let x = self.x(withTime: time)
        editLayer.fillColor = isInterpolated ? .subSelection : .selection
        editLayer.frame = CGRect(x: x - baseWidth / 2, y: 0, width: baseWidth, height: frame.height)
    }
    var editingKeyframeIndex: Int?
    
    static let defautBaseWidth = 6.0.cf
    var baseWidth = defautBaseWidth {
        didSet {
            updateChildren()
        }
    }
    let smallKnobHalfHeight = 3.0.cf, smallSubKnobHalfHeight = 2.0.cf
    let knobHalfHeight = 6.0.cf, subKnobHalfHeight = 3.0.cf, maxLineWidth = 3.0.cf
    var baseTimeInterval: Beat {
        didSet {
            updateChildren()
        }
    }
    var beginBaseTime = Beat(0) {
        didSet {
            updateWithBeginTime()
        }
    }
    
    func movingKeyframeIndex(atTime time: Beat) -> (index: Int?, isSolution: Bool) {
        return animation.movingKeyframeIndex(withTime: time)
    }
    func beatTime(withBaseTime baseTime: BaseTime) -> Beat {
        return baseTime * baseTimeInterval
    }
    func baseTime(withBeatTime beatTime: Beat) -> BaseTime {
        return beatTime / baseTimeInterval
    }
    func basedBeatTime(withDoubleBaseTime doubleBaseTime: DoubleBaseTime) -> Beat {
        return Beat(Int(doubleBaseTime)) * baseTimeInterval
    }
    func doubleBaseTime(withBeatTime beatTime: Beat) -> DoubleBaseTime {
        return DoubleBaseTime(beatTime / baseTimeInterval)
    }
    func doubleBaseTime(withX x: CGFloat) -> DoubleBaseTime {
        return DoubleBaseTime(x / baseWidth)
    }
    func basedBeatTime(withDoubleBeatTime doubleBeatTime: DoubleBeat) -> Beat {
        return Beat(Int(doubleBeatTime / DoubleBeat(baseTimeInterval))) * baseTimeInterval
    }
    func time(withX x: CGFloat, isBased: Bool = true) -> Beat {
        let dt = beginBaseTime - floor(beginBaseTime / baseTimeInterval) * baseTimeInterval
        let basedX = x + self.x(withTime: dt)
        let t =  isBased ?
            baseTimeInterval * Beat(Int(round(basedX / baseWidth))) :
            basedBeatTime(withDoubleBeatTime:
                DoubleBeat(basedX / baseWidth) * DoubleBeat(baseTimeInterval))
        return t - (beginBaseTime - floor(beginBaseTime / baseTimeInterval) * baseTimeInterval)
    }
    func x(withTime time: Beat) -> CGFloat {
        return DoubleBeat(time / baseTimeInterval).cf * baseWidth
    }
    func clipDeltaTime(withTime time: Beat) -> Beat {
        let ft = baseTime(withBeatTime: time)
        let fft = ft + BaseTime(1, 2)
        return fft - floor(fft) < BaseTime(1, 2) ?
            beatTime(withBaseTime: ceil(ft)) - time :
            beatTime(withBaseTime: floor(ft)) - time
    }
    func nearestKeyframeIndex(at p: CGPoint) -> Int? {
        guard !animation.keyframes.isEmpty else {
            return nil
        }
        var minD = CGFloat.infinity, minIndex: Int?
        func updateMin(index: Int?, time: Beat) {
            let x = self.x(withTime: time)
            let d = abs(p.x - x)
            if d < minD {
                minIndex = index
                minD = d
            }
        }
        for (i, keyframe) in animation.keyframes.enumerated().reversed() {
            updateMin(index: i, time: keyframe.time)
        }
        updateMin(index: nil, time: animation.duration)
        return minIndex
    }
    
    var disabledRegisterUndo = true

    enum SetKeyframeType {
        case insert, remove, replace
    }
    struct SetKeyframeBinding {
        let animationEditor: AnimationEditor
        let keyframe: Keyframe, index: Int, setType: SetKeyframeType
        let animation: Animation, oldAnimation: Animation, type: Action.SendType
    }
    var setKeyframeHandler: ((SetKeyframeBinding) -> ())?
    
    struct SlideBinding {
        let animationEditor: AnimationEditor
        let keyframeIndex: Int?, deltaTime: Beat, oldTime: Beat
        let animation: Animation, oldAnimation: Animation, type: Action.SendType
    }
    var slideHandler: ((SlideBinding) -> ())?
    
    struct SelectBinding {
        let animationEditor: AnimationEditor
        let selectionIndexes: [Int], oldSelectionIndexes: [Int]
        let animation: Animation, oldAnimation: Animation, type: Action.SendType
    }
    var selectHandler: ((SelectBinding) -> ())?
    
    func copy(with event: KeyInputEvent) -> CopiedObject? {
        return CopiedObject(objects: [animation.editKeyframe])
    }
    
    func delete(with event: KeyInputEvent) -> Bool {
        _ = removeKeyframe(with: event)
        return true
    }
    var noRemovedHandler: ((AnimationEditor) -> (Bool))?
    func removeKeyframe(with event: KeyInputEvent) -> Bool {
        guard let ki = nearestKeyframeIndex(at: point(from: event)) else {
            return false
        }
        let containsIndexes = animation.selectionKeyframeIndexes.contains(ki)
        let indexes = containsIndexes ? animation.selectionKeyframeIndexes : [ki]
        var isChanged = false
        if containsIndexes {
            set(selectionIndexes: [],
                oldSelectionIndexes: animation.selectionKeyframeIndexes)
        }
        indexes.sorted().reversed().forEach {
            if animation.keyframes.count > 1 {
                if $0 == 0 {
                    removeFirstKeyframe()
                } else {
                    removeKeyframe(at: $0)
                }
                isChanged = true
            } else {
                isChanged = noRemovedHandler?(self) ?? false
            }
        }
        return isChanged
    }
    private func removeFirstKeyframe() {
        let deltaTime = animation.keyframes[1].time
        removeKeyframe(at: 0)
        let keyframes = animation.keyframes.map { $0.with(time: $0.time - deltaTime) }
        set(keyframes, old: animation.keyframes)
    }
    
    func new(with event: KeyInputEvent) -> Bool {
        _ = splitKeyframe(time: time(withX: point(from: event).x))
        return true
    }
    var splitKeyframeLabelHandler: ((Keyframe, Int) -> (Keyframe.Label))?
    func splitKeyframe(time: Beat) -> Bool {
        let ki = Keyframe.index(time: time, with: animation.keyframes)
        guard ki.interTime > 0 else {
            return false
        }
        let k = animation.keyframes[ki.index]
        let newEaing = ki.duration != 0 ?
            k.easing.split(with: Double(ki.interTime / ki.duration).cf) :
            (b0: k.easing, b1: Easing())
        let splitKeyframe0 = Keyframe(time: k.time, easing: newEaing.b0,
                                      interpolation: k.interpolation, loop: k.loop, label: k.label)
        let splitKeyframe1 = Keyframe(time: time, easing: newEaing.b1,
                                      interpolation: k.interpolation, loop: k.loop,
                                      label: splitKeyframeLabelHandler?(k, ki.index) ?? .main)
        replace(splitKeyframe0, at: ki.index)
        insert(splitKeyframe1, at: ki.index + 1)
        let indexes = animation.selectionKeyframeIndexes
        for (i, index) in indexes.enumerated() {
            if index >= ki.index {
                let movedIndexes = indexes.map { $0 > ki.index ? $0 + 1 : $0 }
                let intertedIndexes = index == ki.index ?
                    movedIndexes.withInserted(index + 1, at: i + 1) : movedIndexes
                set(selectionIndexes: intertedIndexes, oldSelectionIndexes: indexes)
                break
            }
        }
        return true
    }
    
    private func replace(_ keyframe: Keyframe, at index: Int) {
        registeringUndoManager?.registerUndo(withTarget: self) { [ok = animation.keyframes[index]] in
            $0.replace(ok, at: index)
        }
        isUseUpdateChildren = false
        let oldAnimation = animation
        setKeyframeHandler?(SetKeyframeBinding(animationEditor: self,
                                                     keyframe: keyframe, index: index,
                                                     setType: .replace,
                                                     animation: oldAnimation,
                                                     oldAnimation: oldAnimation, type: .begin))
        animation.keyframes[index] = keyframe
        setKeyframeHandler?(SetKeyframeBinding(animationEditor: self,
                                                     keyframe: keyframe, index: index,
                                                     setType: .replace,
                                                     animation: animation,
                                                     oldAnimation: oldAnimation, type: .end))
        isUseUpdateChildren = true
        updateChildren()
    }
    private func insert(_ keyframe: Keyframe, at index: Int) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.removeKeyframe(at: index)
        }
        isUseUpdateChildren = false
        let oldAnimation = animation
        setKeyframeHandler?(SetKeyframeBinding(animationEditor: self,
                                                     keyframe: keyframe, index: index,
                                                     setType: .insert,
                                                     animation: oldAnimation,
                                                     oldAnimation: oldAnimation, type: .begin))
        animation.keyframes.insert(keyframe, at: index)
        setKeyframeHandler?(SetKeyframeBinding(animationEditor: self,
                                                     keyframe: keyframe, index: index,
                                                     setType: .insert,
                                                     animation: animation,
                                                     oldAnimation: oldAnimation, type: .end))
        isUseUpdateChildren = true
        updateChildren()
    }
    private func removeKeyframe(at index: Int) {
        registeringUndoManager?.registerUndo(withTarget: self) { [ok = animation.keyframes[index]] in
            $0.insert(ok, at: index)
        }
        isUseUpdateChildren = false
        let oldAnimation = animation
        setKeyframeHandler?(SetKeyframeBinding(animationEditor: self,
                                                     keyframe: oldAnimation.keyframes[index],
                                                     index: index,
                                                     setType: .remove,
                                                     animation: oldAnimation,
                                                     oldAnimation: oldAnimation, type: .begin))
        animation.keyframes.remove(at: index)
        setKeyframeHandler?(SetKeyframeBinding(animationEditor: self,
                                                     keyframe: oldAnimation.keyframes[index],
                                                     index: index,
                                                     setType: .remove,
                                                     animation: animation,
                                                     oldAnimation: oldAnimation, type: .end))
        isUseUpdateChildren = true
        updateChildren()
    }
    
    private var isDrag = false, oldTime = DoubleBaseTime(0), oldKeyframeIndex: Int?
    private struct DragObject {
        var clipDeltaTime = Beat(0), minDeltaTime = Beat(0), oldTime = Beat(0)
        var oldAnimation = Animation()
    }
    
    private var dragObject = DragObject()
    func move(with event: DragEvent) -> Bool {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            oldTime = doubleBaseTime(withX: p.x)
            if let ki = nearestKeyframeIndex(at: p), animation.keyframes.count > 1 {
                let keyframeIndex = ki > 0 ? ki : 1
                oldKeyframeIndex = keyframeIndex
                return moveKeyframe(withDeltaTime: 0,
                                    keyframeIndex: keyframeIndex, sendType: event.sendType)
            } else {
                oldKeyframeIndex = nil
                return moveDuration(withDeltaTime: 0, sendType: event.sendType)
            }
        case .sending, .end:
            let t = doubleBaseTime(withX: point(from: event).x)
            let fdt = t - oldTime + (t - oldTime >= 0 ? 0.5 : -0.5)
            let dt = basedBeatTime(withDoubleBaseTime: fdt)
            let deltaTime = max(dragObject.minDeltaTime, dt + dragObject.clipDeltaTime)
            if let keyframeIndex = oldKeyframeIndex, keyframeIndex < animation.keyframes.count {
                return moveKeyframe(withDeltaTime: deltaTime,
                                    keyframeIndex: keyframeIndex, sendType: event.sendType)
            } else {
                return moveDuration(withDeltaTime: deltaTime, sendType: event.sendType)
            }
        }
    }
    func move(withDeltaTime deltaTime: Beat, keyframeIndex: Int?, sendType: Action.SendType) -> Bool {
        if let keyframeIndex = keyframeIndex, keyframeIndex < animation.keyframes.count {
            return moveKeyframe(withDeltaTime: deltaTime,
                                keyframeIndex: keyframeIndex, sendType: sendType)
        } else {
            return moveDuration(withDeltaTime: deltaTime, sendType: sendType)
        }
    }
    func moveKeyframe(withDeltaTime deltaTime: Beat,
                      keyframeIndex: Int, sendType: Action.SendType) -> Bool {
        switch sendType {
        case .begin:
            editingKeyframeIndex = keyframeIndex
            isDrag = false
            let preTime = animation.keyframes[keyframeIndex - 1].time
            let time = animation.keyframes[keyframeIndex].time
            dragObject.clipDeltaTime = clipDeltaTime(withTime: time + beginBaseTime)
            dragObject.minDeltaTime = preTime - time
            dragObject.oldAnimation = animation
            dragObject.oldTime = time
            slideHandler?(SlideBinding(animationEditor: self,
                                       keyframeIndex: keyframeIndex,
                                       deltaTime: deltaTime,
                                       oldTime: dragObject.oldTime,
                                       animation: animation,
                                       oldAnimation: dragObject.oldAnimation, type: .begin))
        case .sending:
            isDrag = true
            var nks = dragObject.oldAnimation.keyframes
            (keyframeIndex ..< nks.count).forEach {
                nks[$0] = nks[$0].with(time: nks[$0].time + deltaTime)
            }
            isUseUpdateChildren = false
            animation.keyframes = nks
            animation.duration = dragObject.oldAnimation.duration + deltaTime
            slideHandler?(SlideBinding(animationEditor: self,
                                       keyframeIndex: keyframeIndex,
                                       deltaTime: deltaTime,
                                       oldTime: dragObject.oldTime,
                                       animation: animation, oldAnimation: dragObject.oldAnimation,
                                       type: .sending))
            isUseUpdateChildren = true
            updateChildren()
        case .end:
            editingKeyframeIndex = nil
            guard isDrag else {
                dragObject = DragObject()
                return true
            }
            let newKeyframes: [Keyframe]
            if deltaTime != 0 {
                var nks = dragObject.oldAnimation.keyframes
                (keyframeIndex ..< nks.count).forEach {
                    nks[$0] = nks[$0].with(time: nks[$0].time + deltaTime)
                }
                registeringUndoManager?.registerUndo(withTarget: self) { [dragObject] in
                    $0.set(dragObject.oldAnimation.keyframes, old: nks,
                           duration: dragObject.oldAnimation.duration,
                           oldDuration: dragObject.oldAnimation.duration + deltaTime)
                }
                newKeyframes = nks
            } else {
                newKeyframes = dragObject.oldAnimation.keyframes
            }
            isUseUpdateChildren = false
            animation.keyframes = newKeyframes
            animation.duration = dragObject.oldAnimation.duration + deltaTime
            slideHandler?(SlideBinding(animationEditor: self,
                                       keyframeIndex: keyframeIndex,
                                       deltaTime: deltaTime,
                                       oldTime: dragObject.oldTime,
                                       animation: animation,
                                       oldAnimation: dragObject.oldAnimation, type: .end))
            isUseUpdateChildren = true
            updateChildren()
            
            isDrag = false
            dragObject = DragObject()
        }
        return true
    }
    func moveDuration(withDeltaTime deltaTime: Beat, sendType: Action.SendType) -> Bool {
        switch sendType {
        case .begin:
            editingKeyframeIndex = animation.keyframes.count
            isDrag = false
            let preTime = animation.keyframes[animation.keyframes.count - 1].time
            let time = animation.duration
            dragObject.clipDeltaTime = clipDeltaTime(withTime: time + beginBaseTime)
            dragObject.minDeltaTime = preTime - time
            dragObject.oldAnimation = animation
            dragObject.oldTime = time
            slideHandler?(SlideBinding(animationEditor: self,
                                       keyframeIndex: nil,
                                       deltaTime: deltaTime,
                                       oldTime: dragObject.oldTime,
                                       animation: animation,
                                       oldAnimation: dragObject.oldAnimation, type: .begin))
        case .sending:
            isDrag = true
            isUseUpdateChildren = false
            animation.duration = dragObject.oldAnimation.duration + deltaTime
            slideHandler?(SlideBinding(animationEditor: self,
                                       keyframeIndex: nil,
                                       deltaTime: deltaTime,
                                       oldTime: dragObject.oldTime,
                                       animation: animation,
                                       oldAnimation: dragObject.oldAnimation, type: .sending))
            isUseUpdateChildren = true
            updateChildren()
        case .end:
            editingKeyframeIndex = nil
            guard isDrag else {
                dragObject = DragObject()
                return true
            }
            if deltaTime != 0 {
                registeringUndoManager?.registerUndo(withTarget: self) { [dragObject] in
                    $0.set(duration: dragObject.oldAnimation.duration,
                           oldDuration: dragObject.oldAnimation.duration + deltaTime)
                }
            }
            isUseUpdateChildren = false
            animation.duration = dragObject.oldAnimation.duration + deltaTime
            slideHandler?(SlideBinding(animationEditor: self,
                                       keyframeIndex: nil,
                                       deltaTime: deltaTime,
                                       oldTime: dragObject.oldTime,
                                       animation: animation,
                                       oldAnimation: dragObject.oldAnimation, type: .end))
            isUseUpdateChildren = true
            updateChildren()
            
            isDrag = false
            dragObject = DragObject()
        }
        return true
    }
    
    struct Binding {
        let animationEditor: AnimationEditor
        let animation: Animation, oldAnimation: Animation, type: Action.SendType
    }
    var binding: ((Binding) -> ())?
    private func set(_ keyframes: [Keyframe], old oldKeyframes: [Keyframe]) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.set(oldKeyframes, old: keyframes)
        }
        isUseUpdateChildren = false
        let oldAnimation = animation
        binding?(Binding(animationEditor: self,
                         animation: animation, oldAnimation: animation, type: .begin))
        animation.keyframes = keyframes
        binding?(Binding(animationEditor: self,
                         animation: animation, oldAnimation: oldAnimation, type: .end))
        isUseUpdateChildren = true
        updateChildren()
    }
    private func set(_ keyframes: [Keyframe], old oldKeyframes: [Keyframe],
                     duration: Beat, oldDuration: Beat) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.set(oldKeyframes, old: keyframes, duration: oldDuration, oldDuration: duration)
        }
        isUseUpdateChildren = false
        let oldAnimation = animation
        binding?(Binding(animationEditor: self,
                         animation: animation, oldAnimation: animation, type: .begin))
        animation.keyframes = keyframes
        animation.duration = duration
        binding?(Binding(animationEditor: self,
                         animation: animation, oldAnimation: oldAnimation, type: .end))
        isUseUpdateChildren = true
        updateChildren()
    }
    private func set(duration: Beat, oldDuration: Beat) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.set(duration: oldDuration, oldDuration: duration)
        }
        isUseUpdateChildren = false
        let oldAnimation = animation
        binding?(Binding(animationEditor: self,
                         animation: animation, oldAnimation: animation, type: .begin))
        animation.duration = duration
        binding?(Binding(animationEditor: self,
                         animation: animation, oldAnimation: oldAnimation, type: .end))
        isUseUpdateChildren = true
        updateChildren()
    }
    
    func selectAll(with event: KeyInputEvent) -> Bool {
        return selectAll(with: event, isDeselect: false)
    }
    func deselectAll(with event: KeyInputEvent) -> Bool {
        return selectAll(with: event, isDeselect: true)
    }
    func selectAll(with event: KeyInputEvent, isDeselect: Bool) -> Bool {
        let indexes = isDeselect ? [] : Array(0 ..< animation.keyframes.count)
        if indexes != animation.selectionKeyframeIndexes {
            set(selectionIndexes: indexes,
                oldSelectionIndexes: animation.selectionKeyframeIndexes)
        }
        return true
    }
    var selectionLayer: Layer? {
        didSet {
            if let selectionLayer = selectionLayer {
                append(child: selectionLayer)
            } else {
                oldValue?.removeFromParent()
            }
        }
    }
    func select(with event: DragEvent) -> Bool {
        return select(with: event, isDeselect: false)
    }
    func deselect(with event: DragEvent) -> Bool {
        return select(with: event, isDeselect: true)
    }
    private struct SelectObject {
        var startPoint = CGPoint()
        var oldAnimation = Animation()
    }
    private var selectObject = SelectObject()
    func select(with event: DragEvent, isDeselect: Bool) -> Bool {
        let p = point(from: event).integral
        switch event.sendType {
        case .begin:
            selectionLayer = isDeselect ? Layer.deselection : Layer.selection
            selectObject.startPoint = p
            selectObject.oldAnimation = animation
            selectionLayer?.frame = CGRect(origin: p, size: CGSize())
            selectHandler?(SelectBinding(animationEditor: self,
                                         selectionIndexes: animation.selectionKeyframeIndexes,
                                         oldSelectionIndexes: animation.selectionKeyframeIndexes,
                                         animation: animation, oldAnimation: animation,
                                         type: .begin))
        case .sending:
            selectionLayer?.frame = CGRect(origin: selectObject.startPoint,
                                           size: CGSize(width: p.x - selectObject.startPoint.x,
                                                        height: p.y - selectObject.startPoint.y))
            
            isUseUpdateChildren = false
            animation.selectionKeyframeIndexes = selectionIndex(at: p,
                                                                with: selectObject,
                                                                isDeselect: isDeselect)
            selectHandler?(SelectBinding(animationEditor: self,
                                         selectionIndexes: animation.selectionKeyframeIndexes,
                                         oldSelectionIndexes: selectObject.oldAnimation.selectionKeyframeIndexes,
                                         animation: animation,
                                         oldAnimation: selectObject.oldAnimation,
                                         type: .sending))
            isUseUpdateChildren = true
            updateChildren()
        case .end:
            let newIndexes = selectionIndex(at: p,
                                            with: selectObject, isDeselect: isDeselect)
            if selectObject.oldAnimation.selectionKeyframeIndexes != newIndexes {
                registeringUndoManager?.registerUndo(withTarget: self) { [so = selectObject] in
                    $0.set(selectionIndexes: so.oldAnimation.selectionKeyframeIndexes,
                           oldSelectionIndexes: newIndexes)
                }
            }
            isUseUpdateChildren = false
            animation.selectionKeyframeIndexes = newIndexes
            selectHandler?(SelectBinding(animationEditor: self,
                                         selectionIndexes: animation.selectionKeyframeIndexes,
                                         oldSelectionIndexes: selectObject.oldAnimation.selectionKeyframeIndexes,
                                         animation: animation,
                                         oldAnimation: selectObject.oldAnimation,
                                         type: .end))
            isUseUpdateChildren = true
            updateChildren()
            
            selectionLayer = nil
            selectObject = SelectObject()
        }
        return true
    }
    private func indexes(at point: CGPoint, with selectObject: SelectObject) -> [Int] {
        let startTime = time(withX: selectObject.startPoint.x, isBased: false) + baseTimeInterval / 2
        let startIndexTuple = Keyframe.index(time: startTime,
                                             with: selectObject.oldAnimation.keyframes)
        let startIndex = startIndexTuple.index
        let selectEndPoint = point
        let endTime = time(withX: selectEndPoint.x, isBased: false) + baseTimeInterval / 2
        let endIndexTuple = Keyframe.index(time: endTime,
                                           with: selectObject.oldAnimation.keyframes)
        let endIndex = endIndexTuple.index
        return startIndex == endIndex ?
            [startIndex] :
            Array(startIndex < endIndex ? (startIndex ... endIndex) : (endIndex ... startIndex))
    }
    private func selectionIndex(at point: CGPoint,
                                with selectObject: SelectObject, isDeselect: Bool) -> [Int] {
        let selectionIndexes = indexes(at: point, with: selectObject)
        let oldIndexes = selectObject.oldAnimation.selectionKeyframeIndexes
        return isDeselect ?
            Array(Set(oldIndexes).subtracting(Set(selectionIndexes))).sorted() :
            Array(Set(oldIndexes).union(Set(selectionIndexes))).sorted()
    }
    
    func set(selectionIndexes: [Int], oldSelectionIndexes: [Int]) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.set(selectionIndexes: oldSelectionIndexes,
                   oldSelectionIndexes: selectionIndexes)
        }
        isUseUpdateChildren = false
        let oldAnimation = animation
        selectHandler?(SelectBinding(animationEditor: self,
                                           selectionIndexes: oldSelectionIndexes,
                                           oldSelectionIndexes: oldSelectionIndexes,
                                           animation: animation, oldAnimation: animation,
                                           type: .begin))
        animation.selectionKeyframeIndexes = selectionIndexes
        selectHandler?(SelectBinding(animationEditor: self,
                                           selectionIndexes: animation.selectionKeyframeIndexes,
                                           oldSelectionIndexes: oldSelectionIndexes,
                                           animation: animation,
                                           oldAnimation: oldAnimation,
                                           type: .end))
        isUseUpdateChildren = true
        updateChildren()
    }
}
