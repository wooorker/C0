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

import CoreGraphics

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
    private(set) var time: Beat
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
         time: Beat = 0, duration: Beat = 0, isInterporation: Bool = false) {
        
        self.keyframes = keyframes
        self.editKeyframeIndex = editKeyframeIndex
        self.selectionKeyframeIndexes = selectionKeyframeIndexes
        self.time = time
        self.duration = duration
        self.isInterporation = isInterporation
        self.loopedKeyframeIndexes = Animation.loopedKeyframeIndexes(with: keyframes,
                                                                     duration: duration)
    }
    private init(keyframes: [Keyframe],
                 editKeyframeIndex: Int, selectionKeyframeIndexes: [Int],
                 time: Beat, duration: Beat, isInterporation: Bool,
                 loopedKeyframeIndexes: [LoopIndex]) {
        
        self.keyframes = keyframes
        self.editKeyframeIndex = editKeyframeIndex
        self.selectionKeyframeIndexes = selectionKeyframeIndexes
        self.time = time
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
                let loopCount = keyframe.loop.isStart
                    ? previousIndexes.count + 1 : previousIndexes.count
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
        self.time = time
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
        return (0, 0, t - loopedKeyframeIndexes.first!.time, oldT - loopedKeyframeIndexes.first!.time)
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
                         time: time, duration: duration, isInterporation: isInterporation,
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
