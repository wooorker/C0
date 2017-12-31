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

import QuartzCore

protocol Animatable {
    func step(_ f0: Int)
    func linear(_ f0: Int, _ f1: Int, t: CGFloat)
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX)
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with msx: MonosplineX)
    func endMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with msx: MonosplineX)
}

final class Animation: Codable {
    var keyframes: [Keyframe] {
        didSet {
            self.loopedKeyframeIndexes = Animation.loopedKeyframeIndexes(with: keyframes,
                                                                         duration: duration)
        }
    }
//    private(set) var time: Beat
    var duration: Beat {
        didSet {
            self.loopedKeyframeIndexes = Animation.loopedKeyframeIndexes(with: keyframes,
                                                                         duration: duration)
        }
    }
    
    var isInterporation: Bool
    var editKeyframeIndex: Int
    var selectionKeyframeIndexes: [Int]
    
    init(keyframes: [Keyframe] = [Keyframe()],
         editKeyframeIndex: Int = 0, selectionKeyframeIndexes: [Int] = [],
//         time: Beat = 0,
         duration: Beat = 1, isInterporation: Bool = false) {
        
        self.keyframes = keyframes
        self.editKeyframeIndex = editKeyframeIndex
        self.selectionKeyframeIndexes = selectionKeyframeIndexes
//        self.time = time
        self.duration = duration
        self.isInterporation = isInterporation
        self.loopedKeyframeIndexes = Animation.loopedKeyframeIndexes(with: keyframes,
                                                                     duration: duration)
    }
    private init(keyframes: [Keyframe],
                 editKeyframeIndex: Int, selectionKeyframeIndexes: [Int],
//                 time: Beat,
                 duration: Beat, isInterporation: Bool,
                 loopedKeyframeIndexes: [LoopIndex]) {
        
        self.keyframes = keyframes
        self.editKeyframeIndex = editKeyframeIndex
        self.selectionKeyframeIndexes = selectionKeyframeIndexes
//        self.time = time
        self.duration = duration
        self.isInterporation = isInterporation
        self.loopedKeyframeIndexes = loopedKeyframeIndexes
    }
    
    struct LoopIndex: Codable {
        var index: Int, time: Beat, loopCount: Int, loopingCount: Int
    }
    
    private(set) var loopedKeyframeIndexes: [LoopIndex]
    private static func loopedKeyframeIndexes(with keyframes: [Keyframe],
                                              duration: Beat) -> [LoopIndex] {
        var keyframeIndexes = [LoopIndex](), previousIndexes = [Int]()
        for (i, keyframe) in keyframes.enumerated() {
            if keyframe.loop.isEnd, let preIndex = previousIndexes.last {
                let loopCount = previousIndexes.count
                previousIndexes.removeLast()
                let time = keyframe.time
                let nextTime = i + 1 >= keyframes.count ? duration : keyframes[i + 1].time
                var t = time, isEndT = false
                while t <= nextTime {
                    for j in preIndex ..< i {
                        let nk = keyframeIndexes[j]
                        keyframeIndexes.append(LoopIndex(index: nk.index, time: t,
                                                         loopCount: loopCount,
                                                         loopingCount: loopCount))
                        t += keyframeIndexes[j + 1].time - nk.time
                        if t > nextTime {
                            if i == keyframes.count - 1 {
                                keyframeIndexes.append(LoopIndex(index: keyframeIndexes[j + 1].index,
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
                let loopCount = keyframe.loop.isStart ?
                    previousIndexes.count + 1 : previousIndexes.count
                keyframeIndexes.append(LoopIndex(index: i, time: keyframe.time,
                                                 loopCount: loopCount,
                                                 loopingCount: max(0, loopCount - 1)))
            }
            if keyframe.loop.isStart {
                previousIndexes.append(keyframeIndexes.count - 1)
            }
        }
        return keyframeIndexes
    }
    
    
    func update(withTime time: Beat, to animatable: Animatable) {
//        self.time = time
        let timeResult = loopedKeyframeIndex(withTime: time)
        let i1 = timeResult.loopedIndex, interTime = max(0, timeResult.interTime)
        let kis1 = loopedKeyframeIndexes[i1]
        self.editKeyframeIndex = kis1.index
        let k1 = keyframes[kis1.index]
        if interTime == 0 || timeResult.sectionTime == 0
            || i1 + 1 >= loopedKeyframeIndexes.count || k1.interpolation == .none {
            
            self.isInterporation = false
            animatable.step(kis1.index)
            return
        }
        self.isInterporation = true
        let kis2 = loopedKeyframeIndexes[i1 + 1]
        if k1.interpolation == .linear || keyframes.count <= 2 {
            animatable.linear(kis1.index, kis2.index,
                              t: k1.easing.convertT(Double(interTime / timeResult.sectionTime).cf))
        } else {
            let it = Double(interTime / timeResult.sectionTime).cf
            let t = k1.easing.isDefault ?
                Double(time).cf :
                k1.easing.convertT(it) * Double(timeResult.sectionTime).cf + Double(kis1.time).cf
            let isUseFirstIndex = i1 - 1 >= 0 && k1.interpolation != .bound
            let isUseEndIndex = i1 + 2 < loopedKeyframeIndexes.count
                && keyframes[kis2.index].interpolation != .bound
            if isUseFirstIndex {
                if isUseEndIndex {
                    let kis0 = loopedKeyframeIndexes[i1 - 1], kis3 = loopedKeyframeIndexes[i1 + 2]
                    let msx = MonosplineX(x0: Double(kis0.time).cf,
                                          x1: Double(kis1.time).cf,
                                          x2: Double(kis2.time).cf,
                                          x3: Double(kis3.time).cf, x: t, t: k1.easing.convertT(it))
                    animatable.monospline(kis0.index, kis1.index, kis2.index, kis3.index, with: msx)
                } else {
                    let kis0 = loopedKeyframeIndexes[i1 - 1]
                    let mt = k1.easing.convertT(it)
                    let msx = MonosplineX(x0: Double(kis0.time).cf,
                                          x1: Double(kis1.time).cf,
                                          x2: Double(kis2.time).cf, x: t, t: mt)
                    animatable.endMonospline(kis0.index, kis1.index, kis2.index, with: msx)
                }
            } else if isUseEndIndex {
                let kis3 = loopedKeyframeIndexes[i1 + 2]
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
    
    func replaceKeyframe(_ keyframe: Keyframe, at index: Int) {
        keyframes[index] = keyframe
    }
    func replaceKeyframes(_ keyframes: [Keyframe]) {
        if keyframes.count != self.keyframes.count {
            fatalError()
        }
        self.keyframes = keyframes
    }
    
    var editKeyframe: Keyframe {
        return keyframes[min(editKeyframeIndex, keyframes.count - 1)]
    }
    func loopedKeyframeIndex(withTime t: Beat
        ) -> (loopedIndex: Int, index: Int, interTime: Beat, sectionTime: Beat) {
        
        var oldT = duration
        for i in (0 ..< loopedKeyframeIndexes.count).reversed() {
            let ki = loopedKeyframeIndexes[i]
            let kt = ki.time
            if t >= kt {
                return (i, ki.index, t - kt, oldT - kt)
            }
            oldT = kt
        }
        return (0, 0,
                t - loopedKeyframeIndexes.first!.time, oldT - loopedKeyframeIndexes.first!.time)
    }
    var minDuration: Beat {
        return (keyframes.last?.time ?? 0) + 1
    }
    var lastKeyframeTime: Beat {
        return keyframes.isEmpty ? 0 : keyframes[keyframes.count - 1].time
    }
    var lastLoopedKeyframeTime: Beat {
        if loopedKeyframeIndexes.isEmpty {
            return 0
        }
        let t = loopedKeyframeIndexes[loopedKeyframeIndexes.count - 1].time
        if t >= duration {
            return loopedKeyframeIndexes.count >= 2 ?
                loopedKeyframeIndexes[loopedKeyframeIndexes.count - 2].time : 0
        } else {
            return t
        }
    }
}
extension Animation: Equatable {
    static func ==(lhs: Animation, rhs: Animation) -> Bool {
        return lhs === rhs
    }
}
extension Animation: Copying {
    func copied(from copier: Copier) -> Animation {
        return Animation(keyframes: keyframes, editKeyframeIndex: editKeyframeIndex,
                         selectionKeyframeIndexes: selectionKeyframeIndexes,
//                         time: time,
                         duration: duration, isInterporation: isInterporation,
                         loopedKeyframeIndexes: loopedKeyframeIndexes)
    }
}
extension Animation: Referenceable {
    static let name = Localization(english: "Animation", japanese: "アニメーション")
}

struct Keyframe: Codable {
    enum Interpolation: Int8, Codable {
        case spline, bound, linear, none
    }
    enum Label: Int8, Codable {
        case main, sub
    }
    var time = Beat(0), easing = Easing(), interpolation = Interpolation.spline
    var loop = Loop(), label = Label.main
    
    func with(time: Beat) -> Keyframe {
        return Keyframe(time: time, easing: easing,
                        interpolation: interpolation, loop: loop, label: label)
    }
    func with(_ easing: Easing) -> Keyframe {
        return Keyframe(time: time, easing: easing,
                        interpolation: interpolation, loop: loop, label: label)
    }
    func with(_ interpolation: Interpolation) -> Keyframe {
        return Keyframe(time: time, easing: easing,
                        interpolation: interpolation, loop: loop, label: label)
    }
    func with(_ loop: Loop) -> Keyframe {
        return Keyframe(time: time, easing: easing,
                        interpolation: interpolation, loop: loop, label: label)
    }
    func with(_ label: Label) -> Keyframe {
        return Keyframe(time: time, easing: easing,
                        interpolation: interpolation, loop: loop, label: label)
    }
    
    static func index(time t: Beat,
                      with keyframes: [Keyframe]) -> (index: Int, interTime: Beat, sectionTime: Beat) {
        
        var oldT = Beat(0)
        for i in (0 ..< keyframes.count).reversed() {
            let keyframe = keyframes[i]
            if t >= keyframe.time {
                return (i, t - keyframe.time, oldT - keyframe.time)
            }
            oldT = keyframe.time
        }
        return (0, t - keyframes.first!.time, oldT - keyframes.first!.time)
    }
    func equalOption(other: Keyframe) -> Bool {
        return easing == other.easing && interpolation == other.interpolation
            && loop == other.loop && label == other.label
    }
}
extension Keyframe: Equatable {
    static func ==(lhs: Keyframe, rhs: Keyframe) -> Bool {
        return lhs.time == rhs.time
            && lhs.easing == rhs.easing && lhs.interpolation == rhs.interpolation
            && lhs.loop == rhs.loop && lhs.label == rhs.label
    }
}
extension Keyframe: Referenceable {
    static let name = Localization(english: "Keyframe", japanese: "キーフレーム")
}

struct Loop: Codable {
    var isStart = false, isEnd = false
    
    func with(isStart: Bool) -> Loop {
        return Loop(isStart: isStart, isEnd: isEnd)
    }
    func with(isEnd: Bool) -> Loop {
        return Loop(isStart: isStart, isEnd: isEnd)
    }
}
extension Loop: Equatable {
    static func ==(lhs: Loop, rhs: Loop) -> Bool {
        return lhs.isStart == rhs.isStart && lhs.isEnd == rhs.isEnd
    }
}
extension Loop: Referenceable {
    static let name = Localization(english: "Loop", japanese: "ループ")
}

final class AnimationEditor: LayerRespondable {
    static let name = Localization(english: "Animation Editor", japanese: "アニメーションエディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    let layer = CALayer.interface()
    
    let animation: Animation
    init(_ animation: Animation,
         lineColor: Color = .content,
         y: CGFloat,
         knobColorHandler: (Int) -> (Color) = { _ in .knob }) {
        
        self.animation = animation
        
        layer.frame.origin.y = y
        updateChildren()
    }
    
    static func keyframeLine(from p: CGPoint,
                             baseWidth: CGFloat, lineHeight: CGFloat,
                             lineWidth: CGFloat = 4, linearLineWidth: CGFloat = 2,
                             _ interpolation: Keyframe.Interpolation, _ label: Keyframe.Label) -> CALayer {
        
        let layer = CAShapeLayer()
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
        layer.backgroundColor = Color.content.cgColor
        return layer
    }
    static func knob(from p: CGPoint,
                     fillColor: Color,
                     baseWidth: CGFloat, knobHalfHeight: CGFloat, subKnobHalfHeight: CGFloat,
                     _ label: Keyframe.Label) -> CALayer {
        
        let kh = label == .main ? knobHalfHeight : subKnobHalfHeight
        let layer = CALayer.discreteKnob()
        layer.frame = CGRect(x: p.x - baseWidth / 2, y: p.y - kh,
                             width: baseWidth, height: kh * 2)
        layer.backgroundColor = fillColor.cgColor
        return layer
    }
    
    var lineColorHandler: ((Int) -> (Color))?
    var knobColorHandler: ((Int) -> (Color))?
    func updateChildren() {
        let midY = timeHeight / 2
        var labels = [Label]()
        var keyLines = [CALayer](), knobs = [CALayer](), selections = [CALayer]()
        let startIndex = animation.selectionKeyframeIndexes.first ?? animation.keyframes.count - 1
        let endIndex = animation.selectionKeyframeIndexes.last ?? 0
        for (i, lki) in animation.loopedKeyframeIndexes.enumerated() {
            let time = lki.time
            guard time < animation.duration else {
                continue
            }
            let keyframe = animation.keyframes[lki.index]
            let nextTime = i + 1 >= animation.loopedKeyframeIndexes.count ?
                animation.duration : animation.loopedKeyframeIndexes[i + 1].time
            let x = self.x(withTime: time)
            let nextX = self.x(withTime: nextTime)
            let duration = nextTime - time, width = nextX - x
            let lw = 2.0.cf
            
            //            let isClipDrawKeyframe = nextTime > animation.duration
            //            if isClipDrawKeyframe {
            //                let nx = min(nextX,
            //                             AnimationEditor.x(withTime: animation.duration,
            //                                               baseWidth: baseWidth, from: scene) - baseWidth / 2)
            //                let kb = CGRect(x: x, y: y - timeHeight / 2, width: nx - x, height: timeHeight)
            //            }
            
            let timePLabel = Label(text: Localization("\(duration.p)"), font: .small)
            let timePX = (x + nextX) / 2 + (baseWidth - timePLabel.frame.width) / 2
            timePLabel.frame.origin = CGPoint(x: timePX, y: midY).integral
            timePLabel.layer.backgroundColor = nil
            
            let timeQLabel = Label(text: Localization("\(duration.q)"), font: .small)
            let timeQX = (x + nextX) / 2 + (baseWidth - timeQLabel.frame.width) / 2
            timeQLabel.frame.origin = CGPoint(x: timeQX,
                                              y: midY - timeQLabel.frame.height).integral
            timeQLabel.layer.backgroundColor = nil
            
            labels += [timePLabel, timeQLabel]
            
            if duration > baseTimeInterval {
                if !keyframe.easing.isLinear {
                    let b = keyframe.easing.bezier, bw = width
                    let bx = x + baseWidth / 2, count = Int(width / 5.0)
                    let d = 1 / count.cf
                    let points: [CGPoint] = (0 ... count).map { i in
                        let dx = d * i.cf
                        let dp = b.difference(withT: dx)
                        let dy = max(0.5, min(maxLineHeight, (dp.x == dp.y ?
                            .pi / 2 : 2 * atan2(dp.y, dp.x)) / (.pi / 2)))
                        return CGPoint(x: dx * bw + bx, y: dy)
                    }
                    
                    if lki.loopCount > 0 {
                    }
                    let ps0 = points.map { CGPoint(x: $0.x, y: midY + $0.y) }
                    let ps1 = points.reversed().map { CGPoint(x: $0.x, y: midY - $0.y) }
                    let ps = ps0 + ps1
                    let path = CGMutablePath()
                    path.addLines(between: ps)
                    let layer = CAShapeLayer()
                    layer.path = path
                    layer.fillColor = lineColorHandler?(i).cgColor
                    keyLines.append(layer)
                } else {
                    if lki.loopCount > 0 {
                    }
                    let path = CGMutablePath()
                    path.addRect(CGRect(x: x + baseWidth / 2, y: midY - lw / 2,
                                        width: width, height: lw))
                    let layer = CAShapeLayer()
                    layer.path = path
                    layer.fillColor = lineColorHandler?(i).cgColor
                    keyLines.append(layer)
                }
            }
            
            let knobColor = lki.loopingCount > 0 ? Color.edit : (knobColorHandler?(i) ?? Color.edit)
            let knob = AnimationEditor.knob(from: CGPoint(x: x, y: midY),
                                            fillColor: knobColor,
                                            baseWidth: baseWidth,
                                            knobHalfHeight: knobHalfHeight,
                                            subKnobHalfHeight: subKnobHalfHeight,
                                            keyframe.label)
            knobs.append(knob)
            
            appendSelection: do {
                if animation.selectionKeyframeIndexes.contains(i) {
                    let layer = CALayer.disabledAnimation
                    layer.backgroundColor = Color.select.cgColor
                    let kh = knobHalfHeight
                    layer.frame = CGRect(x: x, y: midY - kh, width: width, height: kh * 2)
                    selections.append(layer)
                } else if i >= startIndex && i < endIndex {
                    let layer = CAShapeLayer()
                    layer.fillColor = Color.select.cgColor
                    let path = CGMutablePath()
                    let kh = knobHalfHeight, h = 2.0.cf
                    path.addRect(CGRect(x: x, y: midY - kh, width: width, height: h))
                    path.addRect(CGRect(x: x, y: midY + kh - h, width: width, height: h))
                    selections.append(layer)
                }
            }
        }
        let x = self.x(withTime: animation.duration)
        let knob = AnimationEditor.knob(from: CGPoint(x: x, y: midY),
                                        fillColor: .knob,
                                        baseWidth: baseWidth,
                                        knobHalfHeight: knobHalfHeight,
                                        subKnobHalfHeight: subKnobHalfHeight,
                                        .main)
        knobs.append(knob)
        children = labels
        update(withChildren: children, oldChildren: [])
        layer.sublayers = labels.map { $0.layer } + keyLines + knobs + selections
        layer.frame.size = CGSize(width: x, height: timeHeight)
    }
    var keyframeLayers = [CALayer]()
    
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
    
    func nearestKeyframeIndex(at p: CGPoint) -> Int? {
        guard !animation.keyframes.isEmpty else {
            return nil
        }
        var minD = CGFloat.infinity, minIndex = 0
        for (i, keyframe) in animation.keyframes.enumerated() {
            let x = self.x(withTime: keyframe.time)
            let d = abs(p.x - x)
            if d < minD {
                minIndex = i
                minD = d
            }
        }
        return minIndex
    }
    
    func delete(with event: KeyInputEvent) {
        removeKeyframe(with: event)
    }
    
    var splitKeyframeLabelHandler: ((Keyframe) -> (Keyframe.Label))?
    var splitKeyframeHandler: ((Keyframe) -> ())?
    func splitKeyframe(time: Beat) {
//        let ki = Keyframe.index(time: time, with: animation.keyframes)
//        guard ki.interTime > 0 else {
//            return
//        }
//        let k = animation.keyframes[ki.index]
//        let newEaing = ki.sectionTime != 0 ?
//            k.easing.split(with: Double(ki.interTime / ki.sectionTime).cf) :
//            (b0: k.easing, b1: Easing())
//        let splitKeyframe0 = Keyframe(time: k.time, easing: newEaing.b0,
//                                      interpolation: k.interpolation, loop: k.loop, label: k.label)
//        let splitKeyframe1 = Keyframe(time: time, easing: newEaing.b1,
//                                      interpolation: k.interpolation, loop: k.loop,
//                                      label: splitKeyframeLabelHandler?(k) ?? .main)
        //insert
        
        //handler
//        let values = track.currentItemValues
//        replaceKeyframe(splitKeyframe0, at: ki.index, in: track.animation, in: cutItem, time: time)
//        insertKeyframe(keyframe: splitKeyframe1,
//                       drawing: isSplitDrawing ? values.drawing.copied : Drawing(),
//                       geometries: values.geometries,
//                       materials: values.materials,
//                       transform: values.transform,
//                       at: ki.index + 1,
//                       in: track, in: cutItem, time: time)
        
//        let indexes = animation.selectionKeyframeIndexes
//        for (i, index) in indexes.enumerated() {
//            if index >= ki.index {
//                let movedIndexes = indexes.map { $0 > ki.index ? $0 + 1 : $0 }
//                let intertedIndexes = index == ki.index ?
//                    movedIndexes.withInserted(index + 1, at: i + 1) : movedIndexes
//                set(selectionIndexes: intertedIndexes, oldSelectionIndexes: indexes,
//                    in: animation)
//                break
//            }
//        }
    }
    func removeKeyframe(with event: KeyInputEvent) {
        guard let ki = nearestKeyframeIndex(at: point(from: event)) else {
            return
        }
//        let (index, cutIndex): (Int, Int) = {
//            if let i = ki.keyframeIndex {
//                return (i, ki.cutIndex)
//            } else {
//                if animation.keyframes.count == 0 {
//                    return (0, ki.cutIndex)
//                } else {
//                    return ki.cutIndex + 1 < scene.cutItems.count ?
//                        (0, ki.cutIndex + 1) :
//                        (animation.keyframes.count - 1, ki.cutIndex)
//                }
//            }
//        } ()
        let containsIndexes = animation.selectionKeyframeIndexes.contains(ki)
        let indexes = containsIndexes ? animation.selectionKeyframeIndexes : [ki]
        indexes.sorted().reversed().forEach {
            if animation.keyframes.count > 1 {
                if $0 == 0 {
                    removeFirstKeyframe()
                } else {
                    removeKeyframe(at: $0)
                }
            }
            //handler
//            else if node.tracks.count > 1 {
//                removeTrack(at: node.editTrackIndex, in: node, in: cutItem)
//            } else {
//                removeCut(at: cutIndex)
//            }
        }
        if containsIndexes {
            set(selectionIndexes: [],
                oldSelectionIndexes: animation.selectionKeyframeIndexes,
                in: animation)
        }
    }
//    private func replaceKeyframe(_ keyframe: Keyframe, at index: Int,
//                                 in animation: Animation, in cutItem: CutItem, time: Beat) {
//
//        registerUndo { [ok = animation.keyframes[index]] in
//            $0.replaceKeyframe(ok, at: index, in: animation, in: cutItem, time: $1)
//        }
//        self.time = time
//        animation.replaceKeyframe(keyframe, at: index)
//        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
//        cutItem.cutDataModel.isWrite = true
//        updateView(isCut: true, isTransform: false, isKeyframe: false)
//    }
//    private func insertKeyframe(keyframe: Keyframe,
//                                drawing: Drawing,
//                                geometries: [Geometry], materials: [Material],
//                                transform: Transform?,
//                                at index: Int) {
//
//        registerUndo { $0.removeKeyframe(at: index, in: track, in: cutItem, time: $1) }
//        self.time = time
//        track.insertKeyframe(keyframe,
//                             drawing: drawing,
//                             geometries: geometries, materials: materials,
//                             transform: transform,
//                             at: index)
//        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
//        cutItem.cutDataModel.isWrite = true
//        updateView(isCut: true, isTransform: false, isKeyframe: false)
//    }
    private func removeKeyframe(at index: Int) {
//        registerUndo {
//            [ok = track.animation.keyframes[index],
//            okv = track.keyframeItemValues(at: index)] in
//
//            $0.insertKeyframe(keyframe: ok,
//                              drawing: okv.drawing, geometries: okv.geometries,
//                              materials: okv.materials,
//                              transform: okv.transform,
//                              at: index, in: track, in: cutItem, time: $1)
//        }
//        self.time = time
//        track.removeKeyframe(at: index)
//        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
//        cutItem.cutDataModel.isWrite = true
//        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    private func removeFirstKeyframe() {
        let deltaTime = animation.keyframes[1].time
        removeKeyframe(at: 0)
        let keyframes = animation.keyframes.map { $0.with(time: $0.time - deltaTime) }
        set(keyframes, oldKeyframes: animation.keyframes, in: animation)
    }
    
    func new(with event: KeyInputEvent) {
//        let inP = convertToLocal(point(from: event))
//        let cutIndex = self.cutIndex(withLocalX: inP.x)
//        let cutItem = scene.cutItems[cutIndex]
        splitKeyframe(time: time(withX: point(from: event).x))
    }
    
    static let defautBaseWidth = 6.0.cf, defaultTimeHeight = 18.0.cf
    var baseWidth = Timeline.defautBaseWidth
    var timeHeight = defaultTimeHeight
    var timeDivisionHeight = 10.0.cf, tempoHeight = 18.0.cf
    private let knobHalfHeight = 8.0.cf, subKnobHalfHeight = 4.0.cf, maxLineHeight = 3.0.cf
    
    var baseTimeInterval = Beat(1, 16)
    var beginBaseTime = Beat(0)
    
    private var isDrag = false, dragOldTime = DoubleBaseTime(0)
    private var dragOldCutDuration = Beat(0), dragClipDeltaTime = Beat(0)
    private var dragMinDeltaTime = Beat(0)
    private var dragOldSlideTuples = [(animation: Animation,
                                       keyframeIndex: Int, oldKeyframes: [Keyframe])]()
    
    func drag(with event: DragEvent) {
        let p = point(from: event)
        func clipDeltaTime(withTime time: Beat) -> Beat {
            let ft = baseTime(withBeatTime: time)
            let fft = ft + BaseTime(1, 2)
            return fft - floor(fft) < BaseTime(1, 2) ?
                beatTime(withBaseTime: ceil(ft)) - time :
                beatTime(withBaseTime: floor(ft)) - time
        }
        
        switch event.sendType {
        case .begin:
            if p.y >= timeHeight + Layout.basicPadding
                && p.y <= bounds.height - timeDivisionHeight - tempoHeight - timeHeight {
                
                if let ki = nearestKeyframeIndex(at: p) {
                    
                
//                if let ki = result.keyframeIndex {
                    if ki > 0 {
                        let preTime = animation.keyframes[ki - 1].time
                        let time = animation.keyframes[ki].time
                        dragClipDeltaTime = clipDeltaTime(withTime: time)
                        dragMinDeltaTime = preTime - time + baseTimeInterval
                        dragOldSlideTuples = [(animation, ki, animation.keyframes)]
                    } else {
                        dragClipDeltaTime = 0
                    }
                } else {
//                    let preTime = animation.keyframes[animation.keyframes.count - 1].time
//                    let time = editCutItem.cut.duration
//                    dragClipDeltaTime = clipDeltaTime(withTime: time + editCutItem.time)
//                    dragMinDeltaTime = preTime - time + baseTimeInterval
//                    dragOldSlideTuples = []
                }
//                let otherMaxTime = editCutItem.cut.editNode.maxTimeWithOtherAnimation(track.animation)
//                let otherDeltaTime = otherMaxTime - editCutItem.cut.duration + baseTimeInterval
//                dragMinCutDeltaTime = max(otherDeltaTime, dragMinDeltaTime)
//                self.editCutItem = result.cutIndex == 0 && result.keyframeIndex == 0 ?
//                    nil : editCutItem
//                dragOldCutDuration = editCutItem.cut.duration
            } else {
                if let ki = nearestKeyframeIndex(at: p) {
                    if ki > 0 {
//                        let kt = animation.keyframes[ki].time
//                        var dragOldSlideTuples = [(animation: Animation,
//                                                   keyframeIndex: Int, oldKeyframes: [Keyframe])]()
//                        var pkt = Beat(0)
//                        for track in editCutItem.cut.editNode.tracks {
//                            let result = Keyframe.index(time: kt, with: track.animation.keyframes)
//                            let index: Int? = result.interTime > 0 ?
//                                (result.index + 1 <= track.animation.keyframes.count - 1 ?
//                                    result.index + 1 : nil) :
//                                result.index
//                            if let i = index {
//                                dragOldSlideTuples.append((track.animation, i,
//                                                           track.animation.keyframes))
//                            }
//                            let preIndex: Int? = result.interTime > 0 ?
//                                result.index : (result.index > 0 ? result.index - 1 : nil)
//                            if let pi = preIndex {
//                                let preTime = track.animation.keyframes[pi].time
//                                if pkt < preTime {
//                                    pkt = preTime
//                                }
//                            }
//                        }
//                        dragClipDeltaTime = clipDeltaTime(withTime: kt)
//                        dragMinDeltaTime = pkt - kt + baseTimeInterval
//                        self.dragOldSlideTuples = dragOldSlideTuples
                    }
                } else {
//                    let preTime = minTrack.animation.keyframes.last!.time
//                    let time = editCutItem.cut.duration
//                    dragClipDeltaTime = clipDeltaTime(withTime: time + editCutItem.time)
//                    dragMinDeltaTime = preTime - time + baseTimeInterval
//                    dragOldSlideTuples = []
                }
//                self.dragMinCutDeltaTime = dragMinDeltaTime
//                self.editCutItem = result.cutIndex == 0 && result.keyframeIndex == 0 ?
//                    nil : editCutItem
//                self.dragOldCutDuration = editCutItem.cut.duration
            }
            dragOldTime = doubleBaseTime(withX: p.x)
            isDrag = false
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
            
//            let animationDuration = dragOldCutDuration + max(dragMinCutDeltaTime,
//                                                             dt + dragClipDeltaTime)
            //updateHnadler
//            if animationDuration != editCutItem.cut.duration {
//                editCutItem.cut.duration = animationDuration
//                scene.updateCutTimeAndDuration()
//            }
            updateChildren()
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
                    set(nks, oldKeyframes: slideAnimation.oldKeyframes,
                        in: slideAnimation.animation)
                } else {
                    slideAnimation.animation.replaceKeyframes(nks)
                }
            }
            
//            let duration = dragOldCutDuration + max(dragMinCutDeltaTime, dt + dragClipDeltaTime)
//            if duration != dragOldCutDuration {
//                set(duration: duration, oldDuration: dragOldCutDuration, in: editCutItem, time: time)
//            }
            
            dragOldSlideTuples = []
        }
    }
    var setDurationHandler: ((AnimationEditor, Beat) -> ())?
    private func set(duration: Beat, oldDuration: Beat, in animation: Animation) {
        undoManager?.registerUndo(withTarget: self) {
            $0.set(duration: oldDuration, oldDuration: duration, in: animation)
        }
        animation.duration = duration
        updateChildren()
        setDurationHandler?(self, duration)
    }
    
    private func set(_ keyframes: [Keyframe], oldKeyframes: [Keyframe], in animation: Animation) {
        undoManager?.registerUndo(withTarget: self) {
            $0.set(oldKeyframes, oldKeyframes: keyframes, in: animation)
        }
        animation.replaceKeyframes(keyframes)
        updateChildren()
    }
    
    func selectAll(with event: KeyInputEvent) {
        selectAll(with: event, isDeselect: false)
    }
    func deselectAll(with event: KeyInputEvent) {
        selectAll(with: event, isDeselect: true)
    }
    func selectAll(with event: KeyInputEvent, isDeselect: Bool) {
        let indexes = isDeselect ? [] : Array(0 ..< animation.keyframes.count)
        if indexes != animation.selectionKeyframeIndexes {
            set(selectionIndexes: indexes,
                oldSelectionIndexes: animation.selectionKeyframeIndexes, in: animation)
        }
    }
    var selectionLayer: CALayer? {
        didSet {
            if let selectionLayer = selectionLayer {
                layer.addSublayer(selectionLayer)
            } else {
                oldValue?.removeFromSuperlayer()
            }
        }
    }
    private struct SelectOption {
        let indexes: [Int], animation: Animation
    }
    private var selectOption: SelectOption?
    func select(with event: DragEvent) {
        select(with: event, isDeselect: false)
    }
    func deselect(with event: DragEvent) {
        select(with: event, isDeselect: true)
    }
    var selectStartPoint = CGPoint()
    func select(with event: DragEvent, isDeselect: Bool) {
        let point = self.point(from: event).integral
        func indexes(with selectOption: SelectOption) -> [Int] {
            let startTime = time(withX: selectStartPoint.x, isBased: false) + baseTimeInterval / 2
            let startIndexTuple = Keyframe.index(time: startTime,
                                                 with: selectOption.animation.keyframes)
            let startIndex = startIndexTuple.index
            let selectEndPoint = point
            let endTime = time(withX: selectEndPoint.x, isBased: false) + baseTimeInterval / 2
            let endIndexTuple = Keyframe.index(time: endTime,
                                               with: selectOption.animation.keyframes)
            let endIndex = endIndexTuple.index
            return startIndex == endIndex ?
                [startIndex] :
                (startIndex < endIndex ?
                    Array(startIndex ... endIndex) : Array(endIndex ... startIndex))
        }
        func selectionIndex(with selectOption: SelectOption) -> [Int] {
            let selectionIndexes = indexes(with: selectOption)
            return isDeselect ?
                Array(Set(selectOption.indexes).subtracting(Set(selectionIndexes))).sorted() :
                Array(Set(selectOption.indexes).union(Set(selectionIndexes))).sorted()
        }
        switch event.sendType {
        case .begin:
            selectionLayer = isDeselect ? CALayer.deselection : CALayer.selection
            selectStartPoint = point
            selectOption = SelectOption(indexes: animation.selectionKeyframeIndexes,
                                        animation: animation)
            selectionLayer?.frame = CGRect(origin: point, size: CGSize())
        case .sending:
            guard let selectOption = selectOption else {
                return
            }
            selectionLayer?.frame = CGRect(origin: selectStartPoint,
                                           size: CGSize(width: point.x - selectStartPoint.x,
                                                        height: point.y - selectStartPoint.y))
            
            selectOption.animation.selectionKeyframeIndexes
                = selectionIndex(with: selectOption)
            updateChildren()
        case .end:
            guard let selectOption = selectOption else {
                selectionLayer = nil
                return
            }
            self.selectOption = nil
            let newIndexes = selectionIndex(with: selectOption)
            if selectOption.indexes != newIndexes {
                set(selectionIndexes: newIndexes,
                    oldSelectionIndexes: selectOption.indexes,
                    in: selectOption.animation)
            } else {
                selectOption.animation.selectionKeyframeIndexes = selectOption.indexes
            }
            updateChildren()
            selectionLayer = nil
        }
    }
    func set(selectionIndexes: [Int], oldSelectionIndexes: [Int], in animation: Animation) {
        undoManager?.registerUndo(withTarget: self) {
            $0.set(selectionIndexes: oldSelectionIndexes,
                   oldSelectionIndexes: selectionIndexes,
                   in: animation)
        }
        animation.selectionKeyframeIndexes = selectionIndexes
        updateChildren()
    }
}

final class KeyframeEditor: LayerRespondable {
    static let name = Localization(english: "Keyframe Editor", japanese: "キーフレームエディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    let nameLabel = Label(text: Keyframe.name, font: .bold)
    let easingEditor = EasingEditor()
    let interpolationButton = PulldownButton(
        names: [Localization(english: "Spline", japanese: "スプライン"),
                Localization(english: "Bound", japanese: "バウンド"),
                Localization(english: "Linear", japanese: "リニア"),
                Localization(english: "Step", japanese: "補間なし")],
        description: Localization(
            english: "\"Bound\": Uses \"Spline\" without interpolation on previous, Not previous and next: Use \"Linear\"",
            japanese: "バウンド: 前方側の補間をしないスプライン補間, 前後が足りない場合: リニア補間を使用"
        )
    )
    let loopButton = PulldownButton(
        names: [Localization(english: "No Loop", japanese: "ループなし"),
                Localization(english: "Began Loop", japanese: "ループ開始"),
                Localization(english: "Ended Loop", japanese: "ループ終了")],
        description: Localization(
            english: "Loop from \"Began Loop\" keyframe to \"Ended Loop\" keyframe on \"Ended Loop\" keyframe",
            japanese: "「ループ開始」キーフレームから「ループ終了」キーフレームの間を「ループ終了」キーフレーム上でループ"
        )
    )
    let labelButton = PulldownButton(
        names: [Localization(english: "Main Label", japanese: "メインラベル"),
                Localization(english: "Sub Label", japanese: "サブラベル")]
    )
    let layer = CALayer.interface()
    init() {
        interpolationButton.setIndexHandler = { [unowned self] in self.setKeyframe(with: $0) }
        loopButton.setIndexHandler = { [unowned self] in self.setKeyframe(with: $0) }
        labelButton.setIndexHandler = { [unowned self] in self.setKeyframe(with: $0) }
        easingEditor.setEasingHandler = { [unowned self] in self.setKeyframe(with: $0) }
        children = [nameLabel, easingEditor, interpolationButton, loopButton, labelButton]
        update(withChildren: children, oldChildren: [])
    }
    private var oldKeyframe = Keyframe()
    private func setKeyframe(with obj: PulldownButton.HandlerObject) {
        if obj.type == .begin {
            oldKeyframe = keyframe
            setKeyframeHandler?(HandlerObject(keyframeEditor: self,
                                              keyframe: oldKeyframe, oldKeyframe: oldKeyframe,
                                              type: .begin))
        } else {
            switch obj.pulldownButton {
            case interpolationButton:
                keyframe = keyframe.with(KeyframeEditor.interpolation(at: obj.index))
            case loopButton:
                keyframe = keyframe.with(KeyframeEditor.loop(at: obj.index))
            case labelButton:
                keyframe = keyframe.with(KeyframeEditor.label(at: obj.index))
            default:
                fatalError()
            }
            setKeyframeHandler?(HandlerObject(keyframeEditor: self,
                                              keyframe: keyframe, oldKeyframe: oldKeyframe,
                                              type: obj.type))
        }
    }
    private func setKeyframe(with obj: EasingEditor.HandlerObject) {
        if obj.type == .begin {
            oldKeyframe = keyframe
            setKeyframeHandler?(HandlerObject(keyframeEditor: self,
                                              keyframe: oldKeyframe, oldKeyframe: oldKeyframe,
                                              type: .begin))
        } else {
            keyframe = keyframe.with(obj.easing)
            setKeyframeHandler?(HandlerObject(keyframeEditor: self,
                                              keyframe: keyframe, oldKeyframe: oldKeyframe,
                                              type: obj.type))
        }
    }
    
    var frame: CGRect {
        get {
            return layer.frame
        }
        set {
            layer.frame = newValue
            updateChildren(with: bounds)
        }
    }
    func updateChildren(with bounds: CGRect) {
        let padding = Layout.basicPadding
        let w = bounds.width - padding * 2, h = Layout.basicHeight
        var y = bounds.height - nameLabel.frame.height - padding
        nameLabel.frame.origin = CGPoint(x: padding, y: y)
        y -= h + padding
        interpolationButton.frame = CGRect(x: padding, y: y, width: w, height: h)
        y -= h
        loopButton.frame = CGRect(x: padding, y: y, width: w, height: h)
        y -= h
        labelButton.frame = CGRect(x: padding, y: y, width: w, height: h)
        easingEditor.frame = CGRect(x: padding, y: padding,
                                    width: w, height: y - padding)
    }
    
    struct HandlerObject {
        let keyframeEditor: KeyframeEditor
        let keyframe: Keyframe, oldKeyframe: Keyframe, type: Action.SendType
    }
    var setKeyframeHandler: ((HandlerObject) -> ())?
    
    var keyframe = Keyframe() {
        didSet {
            if !keyframe.equalOption(other: oldValue) {
                updateChildren()
            }
        }
    }
    private func updateChildren() {
        labelButton.selectionIndex = KeyframeEditor.labelIndex(with: keyframe.label)
        loopButton.selectionIndex = KeyframeEditor.loopIndex(with: keyframe.loop)
        interpolationButton.selectionIndex =
            KeyframeEditor.interpolationIndex(with: keyframe.interpolation)
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
}
