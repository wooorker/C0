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
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX)
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX)
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with msx: MonosplineX)
}

struct Animation: Codable {
    var keyframes: [Keyframe] {
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
//        self.editKeyframeIndex = editKeyframeIndex
//        self.time = time
//        self.isInterpolated = isInterpolated
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
    
    mutating func update(withTime time: Beat, to animatable: Animatable) {
        self.time = time
        let timeResult = loopedKeyframeIndex(withTime: time)
        let i1 = timeResult.loopedIndex, interTime = max(0, timeResult.interTime)
        editLoopframeIndex = i1
        let kis1 = loopFrames[i1]
        self.editKeyframeIndex = kis1.index
        let k1 = keyframes[kis1.index]
        if interTime == 0 || timeResult.duration == 0
            || i1 + 1 >= loopFrames.count || k1.interpolation == .none {
            
            self.isInterpolated = false
            animatable.step(kis1.index)
            return
        }
        self.isInterpolated = true
        let kis2 = loopFrames[i1 + 1]
        guard kis1.time != kis2.time else {
            self.isInterpolated = false
            animatable.step(kis1.index)
            return
        }
        if k1.interpolation == .linear || keyframes.count <= 2 {
            animatable.linear(kis1.index, kis2.index,
                              t: k1.easing.convertT(Double(interTime / timeResult.duration).cf))
        } else {
            let it = Double(interTime / timeResult.duration).cf
            let t = k1.easing.isDefault ?
                Double(time).cf :
                k1.easing.convertT(it) * Double(timeResult.duration).cf + Double(kis1.time).cf
            let isUseIndex0 = i1 - 1 >= 0 && k1.interpolation != .bound
                && loopFrames[i1 - 1].time != kis1.time
            let isUseIndex3 = i1 + 2 < loopFrames.count
                && keyframes[kis2.index].interpolation != .bound
                && loopFrames[i1 + 2].time != kis2.time
            if isUseIndex0 {
                if isUseIndex3 {
                    let kis0 = loopFrames[i1 - 1], kis3 = loopFrames[i1 + 2]
                    let msx = MonosplineX(x0: Double(kis0.time).cf,
                                          x1: Double(kis1.time).cf,
                                          x2: Double(kis2.time).cf,
                                          x3: Double(kis3.time).cf, x: t, t: k1.easing.convertT(it))
                    animatable.monospline(kis0.index, kis1.index, kis2.index, kis3.index, with: msx)
                } else {
                    let kis0 = loopFrames[i1 - 1]
                    let mt = k1.easing.convertT(it)
                    let msx = MonosplineX(x0: Double(kis0.time).cf,
                                          x1: Double(kis1.time).cf,
                                          x2: Double(kis2.time).cf, x: t, t: mt)
                    animatable.lastMonospline(kis0.index, kis1.index, kis2.index, with: msx)
                }
            } else if isUseIndex3 {
                let kis3 = loopFrames[i1 + 2]
                let mt = k1.easing.convertT(it)
                let msx = MonosplineX(x1: Double(kis1.time).cf,
                                      x2: Double(kis2.time).cf,
                                      x3: Double(kis3.time).cf, x: t, t: mt)
                animatable.firstMonospline(kis1.index, kis2.index, kis3.index, with: msx)
            } else {
                animatable.linear(kis1.index, kis2.index, t: k1.easing.convertT(it))
            }
        }
    }
    
    var editKeyframe: Keyframe {
        return keyframes[min(editKeyframeIndex, keyframes.count - 1)]
    }
    func loopedKeyframeIndex(withTime t: Beat
        ) -> (loopedIndex: Int, index: Int, interTime: Beat, duration: Beat) {
        
        var oldT = duration
        for i in (0 ..< loopFrames.count).reversed() {
            let ki = loopFrames[i]
            let kt = ki.time
            if t >= kt {
                return (i, ki.index, t - kt, oldT - kt)
            }
            oldT = kt
        }
        return (0, 0, t - loopFrames.first!.time, oldT - loopFrames.first!.time)
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
         beginBaseTime: Beat = 0, origin: CGPoint = CGPoint()) {
        self.animation = animation
        self.beginBaseTime = beginBaseTime
        super.init()
        frame.origin = origin
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
                             fillColor: Color,
                             baseWidth: CGFloat,
                             knobHalfHeight: CGFloat, subKnobHalfHeight: CGFloat,
                             with label: Keyframe.Label) -> DiscreteKnob {
        let kh = label == .main ? knobHalfHeight : subKnobHalfHeight
        let knob = DiscreteKnob()
        knob.frame = CGRect(x: p.x - baseWidth / 2, y: p.y - kh,
                             width: baseWidth, height: kh * 2)
        knob.fillColor = fillColor
        return knob
    }
    private static func durationLabelTupleWith(duration: Beat,
                                               baseWidth: CGFloat,
                                               at p: CGPoint) -> (pLabel: Label, qLabel: Label) {
        let pLabel = Label(text: Localization("\(duration.p)"), font: .small)
        let timePX = p.x - pLabel.frame.width / 2
        pLabel.frame.origin = CGPoint(x: timePX, y: p.y).integral
        pLabel.fillColor = nil
        
        let qLabel = Label(text: Localization("\(duration.q)"), font: .small)
        let timeQX = p.x - qLabel.frame.width / 2
        qLabel.frame.origin = CGPoint(x: timeQX,
                                          y: p.y - qLabel.frame.height).integral
        qLabel.fillColor = nil
        return (pLabel, qLabel)
    }
    private static func interpolationLineWith(_ keyframe: Keyframe, lineColor: Color,
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
    private static func selectionLayerWith(_ animation: Animation, keyframeIndex: Int,
                                           position: CGPoint, width: CGFloat,
                                           knobHalfHeight: CGFloat) -> Layer? {
        let startIndex = animation.selectionKeyframeIndexes.first ?? animation.keyframes.count - 1
        let endIndex = animation.selectionKeyframeIndexes.last ?? 0
        if animation.selectionKeyframeIndexes.contains(keyframeIndex) {
            let layer = Layer()
            layer.fillColor = .select
            let kh = knobHalfHeight
            layer.frame = CGRect(x: position.x, y: position.y - kh, width: width, height: kh * 2)
            return layer
        } else if keyframeIndex >= startIndex && keyframeIndex < endIndex {
            let layer = Layer()
            layer.fillColor = .select
            let path = CGMutablePath()
            let kh = knobHalfHeight, h = 2.0.cf
            path.addRect(CGRect(x: position.x, y: position.y - kh, width: width, height: h))
            path.addRect(CGRect(x: position.x, y: position.y + kh - h, width: width, height: h))
            return layer
        }
        return nil
    }
    private static func pText(withDuration d: Beat) -> Localization {
        if d.p < d.q || d.isInteger {
            return Localization("\(d.p)")
        } else {
            return Localization("\(d.integralPart), \(d.p - d.integralPart * d.q)")
        }
    }
    
    var lineColorHandler: ((Int) -> (Color)) = { _ in .content }
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
        let midY = timeHeight / 2, lineWidth = 2.0.cf
        var labels = [Label]()
        var keyLines = [Layer](), knobs = [DiscreteKnob](), selections = [Layer]()
        var dx = 0.0.cf, d = Beat(0), dpLabel: Label?, dqLabel: Label?
        for (i, li) in animation.loopFrames.enumerated() {
            let keyframe = animation.keyframes[li.index]
            
            let time = li.time
            let nextTime = i + 1 >= animation.loopFrames.count ?
                animation.duration : animation.loopFrames[i + 1].time
            let duration = nextTime - time
            
            let x = self.x(withTime: time), nextX = self.x(withTime: nextTime)
            let width = nextX - x
            
            if keyframe.label == .sub {
                d += duration
                if let dpLabel = dpLabel, let dqLabel = dqLabel {
                    if d.isInteger {
                        dqLabel.isHidden = true
                    } else {
                        dqLabel.isHidden = false
                    }
                    dpLabel.localization = Localization("\(d.p)")
                    dqLabel.localization = Localization("\(d.q)")
                    let p = CGPoint(x: dx + self.x(withTime: d) / 2, y: midY)
                    let timePX = p.x - dpLabel.frame.width / 2
                    dpLabel.frame.origin = CGPoint(x: timePX, y: p.y).integral
                    let timeQX = p.x - dqLabel.frame.width / 2
                    dqLabel.frame.origin = CGPoint(x: timeQX,
                                                   y: p.y - dqLabel.frame.height).integral
                }
            } else {
                d = duration
                dx = x
                let durationPosition = CGPoint(x: (x + nextX) / 2, y: midY)
                let durationLabelTuple = AnimationEditor.durationLabelTupleWith(duration: duration,
                                                                                baseWidth: baseWidth,
                                                                                at: durationPosition)
                if duration.isInteger {
                    durationLabelTuple.qLabel.isHidden = true
                }
                labels += [durationLabelTuple.pLabel, durationLabelTuple.qLabel]
                dpLabel = durationLabelTuple.pLabel
                dqLabel = durationLabelTuple.qLabel
            }
            
            let position = CGPoint(x: x, y: midY)
            let lineColor = lineColorHandler(li.index)
            let keyLine = AnimationEditor.interpolationLineWith(keyframe,
                                                                lineColor: lineColor,
                                                                baseWidth: baseWidth,
                                                                lineWidth: lineWidth,
                                                                maxLineWidth: maxLineWidth,
                                                                position: position, width: width)
            keyLines.append(keyLine)
            
            let knobLine = AnimationEditor.knobLine(from: position,
                                                    lineColor: lineColor,
                                                    baseWidth: baseWidth,
                                                    lineHeight: timeHeight - 2,
                                                    with: keyframe.interpolation)
            keyLines.append(knobLine)
            if i > 0 {
                let knobColor = li.loopingCount > 0 ? Color.editing : knobColorHandler(li.index)
                let knob = AnimationEditor.knob(from: position,
                                                fillColor: knobColor,
                                                baseWidth: baseWidth,
                                                knobHalfHeight: knobHalfHeight,
                                                subKnobHalfHeight: subKnobHalfHeight,
                                                with: keyframe.label)
                if duration == 0 {
                    knob.lineWidth = 2
                }
                if li.index == editingKeyframeIndex {
                    knob.fillColor = .editing
                }
                if !((li.time + beginBaseTime) / baseTimeInterval).isInteger {
                    knob.lineColor = .warning
                }
                knobs.append(knob)
            }
            
            if li.loopCount > 0 {
                let path = CGMutablePath()
                if i > 0 && animation.loopFrames[i - 1].loopCount < li.loopCount {
                    path.move(to: CGPoint(x: x, y: midY + timeHeight / 2 - 4))
                    path.addLine(to: CGPoint(x: x + 3, y: midY + timeHeight / 2 - 1))
                    path.addLine(to: CGPoint(x: x, y: midY + timeHeight / 2 - 1))
                    path.closeSubpath()
                }
                path.addRect(CGRect(x: x, y: midY + timeHeight / 2 - 2, width: width, height: 1))
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
                layer.fillColor = lineColor
                keyLines.append(layer)
            }
            
            if let sl = AnimationEditor.selectionLayerWith(animation,
                                                           keyframeIndex: li.index,
                                                           position: position,
                                                           width: width,
                                                           knobHalfHeight: knobHalfHeight) {
                selections.append(sl)
            }
        }
        
        let maxX = self.x(withTime: animation.duration)
        let durationKnob = AnimationEditor.knob(from: CGPoint(x: maxX, y: midY),
                                                fillColor: .knob,
                                                baseWidth: baseWidth,
                                                knobHalfHeight: knobHalfHeight,
                                                subKnobHalfHeight: subKnobHalfHeight,
                                                with: .main)
        if !((animation.duration + beginBaseTime) / baseTimeInterval).isInteger {
            durationKnob.lineColor = .warning
        }
        if editingKeyframeIndex == animation.keyframes.count {
            durationKnob.fillColor = .editing
        }
        knobs.append(durationKnob)
        
        self.knobs = knobs
        
        updateEditLoopframeIndex()
        updateIndicatedLayer()
        
        replace(children: [editLayer, indicatedLayer]
            + labels as [Layer] + keyLines + knobs as [Layer] + selections)
        frame.size = CGSize(width: maxX, height: timeHeight)
    }
    private func updateWithBeginTime() {
        for (i, li) in animation.loopFrames.enumerated() {
            if i > 0 {
                if !((li.time + beginBaseTime) / baseTimeInterval).isInteger {
                    knobs[i - 1].lineColor = .warning
                } else {
                    knobs[i - 1].lineColor = .border
                }
            }
        }
        if !((animation.duration + beginBaseTime) / baseTimeInterval).isInteger {
            knobs.last?.lineColor = .warning
        }
    }
    
    private var isUseUpdateChildren = true
    var animation: Animation {
        didSet {
            if isUseUpdateChildren {
                editLoopframeIndex = animation.editLoopframeIndex
                isInterpolated = animation.isInterpolated
                updateChildren()
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
                                          width: baseWidth, height: timeHeight)
        }
    }
    func moveCursor(with event: MoveEvent) -> Bool {
        if let i = nearestKeyframeIndex(at: point(from: event)) {
            indicatedKeyframeIndex = i == 0 && !isSendMoveFirstKeyframe ? nil : i
        } else {
            indicatedKeyframeIndex = animation.keyframes.count
        }
        return true
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
        editLayer.frame = CGRect(x: x - baseWidth / 2, y: 0, width: baseWidth, height: timeHeight)
    }
    var editingKeyframeIndex: Int?
    
    static let defautBaseWidth = 6.0.cf
    var baseWidth = defautBaseWidth {
        didSet {
            updateChildren()
        }
    }
    let timeHeight = 24.0.cf
    let knobHalfHeight = 8.0.cf, subKnobHalfHeight = 3.0.cf, maxLineWidth = 3.0.cf
    var baseTimeInterval = Beat(1, 16) {
        didSet {
            updateChildren()
        }
    }
    var beginBaseTime = Beat(0) {
        didSet {
            updateWithBeginTime()
        }
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
        return isBased ?
            baseTimeInterval * Beat(Int(round(x / baseWidth))) :
            basedBeatTime(withDoubleBeatTime:
                DoubleBeat(x / baseWidth) * DoubleBeat(baseTimeInterval))
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
    
    //animationDragger
    
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
        return removeKeyframe(with: event)
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
        return splitKeyframe(time: time(withX: point(from: event).x))
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
        undoManager?.registerUndo(withTarget: self) { [ok = animation.keyframes[index]] in
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
        undoManager?.registerUndo(withTarget: self) {
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
        undoManager?.registerUndo(withTarget: self) { [ok = animation.keyframes[index]] in
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
    
    var isSendMoveFirstKeyframe = true
    var moveFirstKeyframeHandler: ((AnimationEditor, DragEvent) -> (Bool))?
    
    private var isDrag = false
    private struct DragObject {
        var oldTime = DoubleBaseTime(0)
        var clipDeltaTime = Beat(0), minDeltaTime = Beat(0)
        var oldAnimation = Animation(), oldKeyframeIndex: Int?
    }
    private var dragObject = DragObject()
    func move(with event: DragEvent) -> Bool {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            guard let ki = nearestKeyframeIndex(at: p) else {
                return moveDuration(with: event)
            }
            guard ki > 0 else {
                dragObject.oldKeyframeIndex = 0
                return moveFirstKeyframeHandler?(self, event) ?? false
            }
            editingKeyframeIndex = ki
            isDrag = false
            let preTime = animation.keyframes[ki - 1].time
            let time = animation.keyframes[ki].time
            dragObject.clipDeltaTime = clipDeltaTime(withTime: time + beginBaseTime)
            dragObject.minDeltaTime = preTime - time
            dragObject.oldKeyframeIndex = ki
            dragObject.oldAnimation = animation
            dragObject.oldTime = doubleBaseTime(withX: p.x)
            slideHandler?(SlideBinding(animationEditor: self,
                                             animation: animation,
                                             oldAnimation: dragObject.oldAnimation, type: .begin))
        case .sending:
            guard let oldKeyframeIndex = dragObject.oldKeyframeIndex else {
                return moveDuration(with: event)
            }
            guard oldKeyframeIndex > 0 else {
                return moveFirstKeyframeHandler?(self, event) ?? false
            }
            isDrag = true
            let t = doubleBaseTime(withX: point(from: event).x)
            let fdt = t - dragObject.oldTime + (t - dragObject.oldTime >= 0 ? 0.5 : -0.5)
            let dt = basedBeatTime(withDoubleBaseTime: fdt)
            let deltaTime = max(dragObject.minDeltaTime, dt + dragObject.clipDeltaTime)
            var nks = dragObject.oldAnimation.keyframes
            (oldKeyframeIndex ..< nks.count).forEach {
                nks[$0] = nks[$0].with(time: nks[$0].time + deltaTime)
            }
            isUseUpdateChildren = false
            animation.keyframes = nks
            animation.duration = dragObject.oldAnimation.duration + deltaTime
            slideHandler?(SlideBinding(animationEditor: self,
                                               animation: animation,
                                               oldAnimation: dragObject.oldAnimation, type: .sending))
            isUseUpdateChildren = true
            updateChildren()
        case .end:
            guard let oldKeyframeIndex = dragObject.oldKeyframeIndex else {
                return moveDuration(with: event)
            }
            guard oldKeyframeIndex > 0 else {
                return moveFirstKeyframeHandler?(self, event) ?? false
            }
            editingKeyframeIndex = nil
            guard isDrag else {
                dragObject = DragObject()
                return true
            }
            let t = doubleBaseTime(withX: point(from: event).x)
            let fdt = t - dragObject.oldTime + (t - dragObject.oldTime >= 0 ? 0.5 : -0.5)
            let dt = basedBeatTime(withDoubleBaseTime: fdt)
            let deltaTime = max(dragObject.minDeltaTime, dt + dragObject.clipDeltaTime)
            let newKeyframes: [Keyframe]
            if deltaTime != 0 {
                var nks = dragObject.oldAnimation.keyframes
                (oldKeyframeIndex ..< nks.count).forEach {
                    nks[$0] = nks[$0].with(time: nks[$0].time + deltaTime)
                }
                undoManager?.registerUndo(withTarget: self) { [dragObject] in
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
                                             animation: animation,
                                             oldAnimation: dragObject.oldAnimation, type: .end))
            isUseUpdateChildren = true
            updateChildren()
            
            isDrag = false
            dragObject = DragObject()
        }
        return true
    }
    func moveDuration(with event: DragEvent) -> Bool {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            editingKeyframeIndex = animation.keyframes.count
            isDrag = false
            let preTime = animation.keyframes[animation.keyframes.count - 1].time
            let time = animation.duration
            dragObject.clipDeltaTime = clipDeltaTime(withTime: time + beginBaseTime)
            dragObject.minDeltaTime = preTime - time
            dragObject.oldKeyframeIndex = nil
            dragObject.oldAnimation = animation
            dragObject.oldTime = doubleBaseTime(withX: p.x)
            slideHandler?(SlideBinding(animationEditor: self,
                                             animation: animation,
                                             oldAnimation: dragObject.oldAnimation, type: .begin))
        case .sending:
            isDrag = true
            let t = doubleBaseTime(withX: point(from: event).x)
            let fdt = t - dragObject.oldTime + (t - dragObject.oldTime >= 0 ? 0.5 : -0.5)
            let dt = basedBeatTime(withDoubleBaseTime: fdt)
            let deltaTime = max(dragObject.minDeltaTime, dt + dragObject.clipDeltaTime)
            isUseUpdateChildren = false
            animation.duration = dragObject.oldAnimation.duration + deltaTime
            slideHandler?(SlideBinding(animationEditor: self,
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
            let t = doubleBaseTime(withX: point(from: event).x)
            let fdt = t - dragObject.oldTime + (t - dragObject.oldTime >= 0 ? 0.5 : -0.5)
            let dt = basedBeatTime(withDoubleBaseTime: fdt)
            let deltaTime = max(dragObject.minDeltaTime, dt + dragObject.clipDeltaTime)
            if deltaTime != 0 {
                undoManager?.registerUndo(withTarget: self) { [dragObject] in
                    $0.set(duration: dragObject.oldAnimation.duration,
                           oldDuration: dragObject.oldAnimation.duration + deltaTime)
                }
            }
            isUseUpdateChildren = false
            animation.duration = dragObject.oldAnimation.duration + deltaTime
            slideHandler?(SlideBinding(animationEditor: self,
                                             animation: animation,
                                             oldAnimation: dragObject.oldAnimation, type: .end))
            isUseUpdateChildren = true
            updateChildren()
            
            isDrag = false
            dragObject = DragObject()
        }
        return true
    }
    
    private func set(_ keyframes: [Keyframe], old oldKeyframes: [Keyframe]) {
        undoManager?.registerUndo(withTarget: self) {
            $0.set(oldKeyframes, old: keyframes)
        }
        isUseUpdateChildren = false
        let oldAnimation = animation
        slideHandler?(SlideBinding(animationEditor: self,
                                         animation: animation,
                                         oldAnimation: animation, type: .begin))
        animation.keyframes = keyframes
        slideHandler?(SlideBinding(animationEditor: self,
                                         animation: animation,
                                         oldAnimation: oldAnimation, type: .end))
        isUseUpdateChildren = true
        updateChildren()
    }
    private func set(_ keyframes: [Keyframe], old oldKeyframes: [Keyframe],
                     duration: Beat, oldDuration: Beat) {
        undoManager?.registerUndo(withTarget: self) {
            $0.set(oldKeyframes, old: keyframes, duration: oldDuration, oldDuration: duration)
        }
        isUseUpdateChildren = false
        let oldAnimation = animation
        slideHandler?(SlideBinding(animationEditor: self,
                                         animation: animation,
                                         oldAnimation: animation, type: .begin))
        animation.keyframes = keyframes
        animation.duration = duration
        slideHandler?(SlideBinding(animationEditor: self,
                                         animation: animation,
                                         oldAnimation: oldAnimation, type: .end))
        isUseUpdateChildren = true
        updateChildren()
    }
    private func set(duration: Beat, oldDuration: Beat) {
        undoManager?.registerUndo(withTarget: self) {
            $0.set(duration: oldDuration, oldDuration: duration)
        }
        isUseUpdateChildren = false
        let oldAnimation = animation
        slideHandler?(SlideBinding(animationEditor: self,
                                         animation: animation,
                                         oldAnimation: animation, type: .begin))
        animation.duration = duration
        slideHandler?(SlideBinding(animationEditor: self,
                                         animation: animation,
                                         oldAnimation: oldAnimation, type: .end))
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
                undoManager?.registerUndo(withTarget: self) { [so = selectObject] in
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
        undoManager?.registerUndo(withTarget: self) {
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
