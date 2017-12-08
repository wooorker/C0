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
    func endMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with msx: MonosplineX)
}

final class Animation: NSObject, NSCoding, Copying {
    static let name = Localization(english: "Animation", japanese: "アニメーション")
    
    var keyframes: [Keyframe] {
        didSet {
            self.loopedKeyframeIndexes = Animation.loopedKeyframeIndexesWith(keyframes, timeLength: timeLength)
        }
    }
    private(set) var time: Beat
    var timeLength: Beat {
        didSet {
            self.loopedKeyframeIndexes = Animation.loopedKeyframeIndexesWith(keyframes, timeLength: timeLength)
        }
    }
    
    var isInterporation: Bool
    var editKeyframeIndex: Int
    var selectionKeyframeIndexes: [Int]
    
    init(keyframes: [Keyframe] = [Keyframe()], editKeyframeIndex: Int = 0, selectionKeyframeIndexes: [Int] = [], time: Beat = 0, timeLength: Beat = 0, isInterporation: Bool = false) {
        
        self.keyframes = keyframes
        self.editKeyframeIndex = editKeyframeIndex
        self.selectionKeyframeIndexes = selectionKeyframeIndexes
        self.time = time
        self.timeLength = timeLength
        self.isInterporation = isInterporation
        self.loopedKeyframeIndexes = Animation.loopedKeyframeIndexesWith(keyframes, timeLength: timeLength)
        super.init()
    }
    private init(keyframes: [Keyframe], editKeyframeIndex: Int, selectionKeyframeIndexes: [Int], time: Beat, timeLength: Beat, isInterporation: Bool, loopedKeyframeIndexes: [(index: Int, time: Beat, loopCount: Int, loopingCount: Int)]) {
        
        self.keyframes = keyframes
        self.editKeyframeIndex = editKeyframeIndex
        self.selectionKeyframeIndexes = selectionKeyframeIndexes
        self.time = time
        self.timeLength = timeLength
        self.isInterporation = isInterporation
        self.loopedKeyframeIndexes = loopedKeyframeIndexes
        super.init()
    }
    
    static let keyframesKey = "0", editKeyframeIndexKey = "1", selectionKeyframeIndexesKey = "2", timeLengthKey = "3", isHiddenKey = "4"
    static let editCellItemKey = "5", selectionCellItemsKey = "6", drawingItemKey = "7", cellItemsKey = "8", materialItemsKey = "12", transformItemKey = "9", speechItemKey = "10", isInterporationKey = "11", timeKey = "13"
    init?(coder: NSCoder) {
        keyframes = coder.decodeStruct(forKey: Animation.keyframesKey) ?? []
        editKeyframeIndex = coder.decodeInteger(forKey: Animation.editKeyframeIndexKey)
        selectionKeyframeIndexes = coder.decodeObject(forKey: Animation.selectionKeyframeIndexesKey) as? [Int] ?? []
        time = coder.decodeStruct(forKey: Animation.timeKey) ?? 0
        timeLength = coder.decodeStruct(forKey: Animation.timeLengthKey) ?? 0
        isInterporation = coder.decodeBool(forKey: Animation.isInterporationKey)
        loopedKeyframeIndexes = Animation.loopedKeyframeIndexesWith(keyframes, timeLength: timeLength)
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeStruct(keyframes, forKey: Animation.keyframesKey)
        coder.encode(editKeyframeIndex, forKey: Animation.editKeyframeIndexKey)
        coder.encode(selectionKeyframeIndexes, forKey: Animation.selectionKeyframeIndexesKey)
        coder.encodeStruct(time, forKey: Animation.timeKey)
        coder.encodeStruct(timeLength, forKey: Animation.timeLengthKey)
        coder.encode(isInterporation, forKey: Animation.isInterporationKey)
    }
    
    var deepCopy: Animation {
        return Animation(keyframes: keyframes, editKeyframeIndex: editKeyframeIndex, selectionKeyframeIndexes: selectionKeyframeIndexes, time: time, timeLength: timeLength, isInterporation: isInterporation, loopedKeyframeIndexes: loopedKeyframeIndexes)
    }
    
    private(set) var loopedKeyframeIndexes: [(index: Int, time: Beat, loopCount: Int, loopingCount: Int)]
    private static func loopedKeyframeIndexesWith(
        _ keyframes: [Keyframe], timeLength: Beat
        ) -> [(index: Int, time: Beat, loopCount: Int, loopingCount: Int)] {
        var keyframeIndexes = [(index: Int, time: Beat, loopCount: Int, loopingCount: Int)](), previousIndexes = [Int]()
        for (i, keyframe) in keyframes.enumerated() {
            if keyframe.loop.isEnd, let preIndex = previousIndexes.last {
                let loopCount = previousIndexes.count
                previousIndexes.removeLast()
                let time = keyframe.time, nextTime = i + 1 >= keyframes.count ? timeLength : keyframes[i + 1].time
                var t = time, isEndT = false
                while t <= nextTime {
                    for j in preIndex ..< i {
                        let nk = keyframeIndexes[j]
                        keyframeIndexes.append((nk.index, t, loopCount, loopCount))
                        t += keyframeIndexes[j + 1].time - nk.time
                        if t > nextTime {
                            if i == keyframes.count - 1 {
                                keyframeIndexes.append((keyframeIndexes[j + 1].index, t, loopCount, loopCount))
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
                let loopCount = keyframe.loop.isStart ? previousIndexes.count + 1 : previousIndexes.count
                keyframeIndexes.append((i, keyframe.time, loopCount, max(0, loopCount - 1)))
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
        if interTime == 0 || timeResult.sectionTime == 0 || i1 + 1 >= loopedKeyframeIndexes.count || k1.interpolation == .none {
            self.isInterporation = false
            animatable.step(kis1.index)
            return
        }
        self.isInterporation = true
        let kis2 = loopedKeyframeIndexes[i1 + 1]
        if k1.interpolation == .linear || keyframes.count <= 2 {
            animatable.linear(kis1.index, kis2.index, t: k1.easing.convertT(Double(interTime / timeResult.sectionTime).cf))
        } else {
            let it = Double(interTime / timeResult.sectionTime).cf
            let t = k1.easing.isDefault ?
                Double(time).cf : k1.easing.convertT(it) * Double(timeResult.sectionTime).cf + Double(kis1.time).cf
            let isUseFirstIndex = i1 - 1 >= 0 && k1.interpolation != .bound, isUseEndIndex = i1 + 2 < loopedKeyframeIndexes.count && keyframes[kis2.index].interpolation != .bound
            if isUseFirstIndex {
                if isUseEndIndex {
                    let kis0 = loopedKeyframeIndexes[i1 - 1], kis3 = loopedKeyframeIndexes[i1 + 2]
                    let msx = MonosplineX(x0: Double(kis0.time).cf, x1: Double(kis1.time).cf, x2: Double(kis2.time).cf, x3: Double(kis3.time).cf, x: t, t: k1.easing.convertT(it))
                    animatable.monospline(kis0.index, kis1.index, kis2.index, kis3.index, with: msx)
                } else {
                    let kis0 = loopedKeyframeIndexes[i1 - 1]
                    let mt = k1.easing.convertT(it)
                    let msx = MonosplineX(x0: Double(kis0.time).cf, x1: Double(kis1.time).cf, x2: Double(kis2.time).cf, x: t, t: mt)
                    animatable.endMonospline(kis0.index, kis1.index, kis2.index, with: msx)
                }
            } else if isUseEndIndex {
                let kis3 = loopedKeyframeIndexes[i1 + 2]
                let mt = k1.easing.convertT(it)
                let msx = MonosplineX(x1: Double(kis1.time).cf, x2: Double(kis2.time).cf, x3: Double(kis3.time).cf, x: t, t: mt)
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
    func loopedKeyframeIndex(withTime t: Beat) -> (loopedIndex: Int, index: Int, interTime: Beat, sectionTime: Beat) {
        var oldT = timeLength
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
    var minTimeLength: Beat {
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
        if t >= timeLength {
            return loopedKeyframeIndexes.count >= 2 ? loopedKeyframeIndexes[loopedKeyframeIndexes.count - 2].time : 0
        } else {
            return t
        }
    }
}

struct Keyframe: ByteCoding, Referenceable, Equatable {
    static let name = Localization(english: "Keyframe", japanese: "キーフレーム")
    
    enum Interpolation: Int8 {
        case spline, bound, linear, none
    }
    enum Label: Int8 {
        case main, sub
    }
    let time: Beat, easing: Easing, interpolation: Interpolation, loop: Loop, label: Label
    
    init(time: Beat = 0, easing: Easing = Easing(), interpolation: Interpolation = .spline, loop: Loop = Loop(), label: Label = .main) {
        self.time = time
        self.easing = easing
        self.interpolation = interpolation
        self.loop = loop
        self.label = label
    }
    
    func with(time: Beat) -> Keyframe {
        return Keyframe(time: time, easing: easing, interpolation: interpolation, loop: loop, label: label)
    }
    func with(_ easing: Easing) -> Keyframe {
        return Keyframe(time: time, easing: easing, interpolation: interpolation, loop: loop, label: label)
    }
    func with(_ interpolation: Interpolation) -> Keyframe {
        return Keyframe(time: time, easing: easing, interpolation: interpolation, loop: loop, label: label)
    }
    func with(_ loop: Loop) -> Keyframe {
        return Keyframe(time: time, easing: easing, interpolation: interpolation, loop: loop, label: label)
    }
    func with(_ label: Label) -> Keyframe {
        return Keyframe(time: time, easing: easing, interpolation: interpolation, loop: loop, label: label)
    }
    static func index(time t: Beat, with keyframes: [Keyframe]) -> (index: Int, interTime: Beat, sectionTime: Beat) {
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
    static func == (lhs: Keyframe, rhs: Keyframe) -> Bool {
        return lhs.time == rhs.time
            && lhs.easing == rhs.easing && lhs.interpolation == rhs.interpolation
            && lhs.loop == rhs.loop && lhs.label == rhs.label
    }
    func equalOption(other: Keyframe) -> Bool {
        return easing == other.easing && interpolation == other.interpolation
            && loop == other.loop && label == other.label
    }
}

struct Loop: Equatable, ByteCoding {
    static let name = Localization(english: "Loop", japanese: "ループ")
    
    let isStart: Bool, isEnd: Bool
    
    init(isStart: Bool = false, isEnd: Bool = false) {
        self.isStart = isStart
        self.isEnd = isEnd
    }
    
    static func == (lhs: Loop, rhs: Loop) -> Bool {
        return lhs.isStart == rhs.isStart && lhs.isEnd == rhs.isEnd
    }
}
