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
 - 変更通知またはイミュータブル化またはstruct化
 */
protocol Track: Animatable {
    var animation: Animation { get }
}
protocol KeyframeValue {
}

final class TempoTrack: NSObject, Track, NSCoding {
    private(set) var animation: Animation
    private var keySeconds = [Second]()
    
    func updateKeySeconds() {
        guard animation.loopFrames.count >= 2 else {
            keySeconds = []
            return
        }
        var second = Second(0)
        keySeconds = (0..<animation.loopFrames.count).map { li in
            if li == animation.loopFrames.count - 1 {
                return second
            } else {
                let s = second
                second += integralSecondDuration(at: li)
                return s
            }
        }
    }
    func doubleBeatTime(withSecondTime second: Second) -> DoubleBeat {
        guard animation.loopFrames.count >= 2 else {
            return DoubleBeat(second.cf * tempoItem.tempo / 60)
        }
        let tempos = tempoItem.keyTempos
        for (li, keySecond) in keySeconds.enumerated().reversed() {
            if keySecond <= second {
                let loopFrame = animation.loopFrames[li]
                if li == animation.loopFrames.count - 1 {
                    let tempo = tempos[loopFrame.index]
                    let lastTime = DoubleBeat((second - keySecond).cf * (tempo / 60))
                    return DoubleBeat(loopFrame.time) + lastTime
                } else {
                    let i2t = animation.loopFrames[li + 1].time
                    let d = i2t - loopFrame.time
                    if d == 0 {
                        return DoubleBeat(loopFrame.time)
                    } else {
                        return timeWithIntegralSecond(at: li, second - keySecond)
                    }
                }
            }
        }
        return 0
    }
    func secondTime(withBeatTime time: Beat) -> Second {
        guard animation.loopFrames.count >= 2 else {
            return Second(time * 60) / Second(tempoItem.tempo)
        }
        let tempos = tempoItem.keyTempos
        for (li, loopFrame) in animation.loopFrames.enumerated().reversed() {
            if loopFrame.time <= time {
                if li == animation.loopFrames.count - 1 {
                    let tempo = tempos[loopFrame.index]
                    return keySeconds[li] + Second((time - loopFrame.time) * 60) / Second(tempo)
                } else {
                    let i2t = animation.loopFrames[li + 1].time
                    let d = i2t - loopFrame.time
                    if d == 0 {
                        return keySeconds[li]
                    } else {
                        let t = Double((time - loopFrame.time) / d).cf
                        return keySeconds[li] + integralSecondDuration(at: li, maxT: t)
                    }
                }
            }
        }
        return 0
    }
    
    func timeWithIntegralSecond(at li: Int, _ second: Second, minT: CGFloat = 0.0.cf,
                                splitSecondCount: Int = 10) -> DoubleBeat {
        let lf1 = animation.loopFrames[li], lf2 = animation.loopFrames[li + 1]
        let tempos = tempoItem.keyTempos
        let te1 = tempos[lf1.index], te2 = tempos[lf2.index]
        let d = Double(lf2.time - lf1.time).cf
        func shc() -> Int {
            return max(2, Int(max(te1, te2) / d) * splitSecondCount / 2)
        }
        var doubleTime = DoubleBeat(0)
        func step(_ lf1: Animation.LoopFrame) {
            doubleTime = DoubleBeat((second.cf * te1) / 60)
        }
        func simpsonInteglalB(_ f: (CGFloat) -> (CGFloat)) {
            let ns = second.cf / (d * 60)
            let b = CGFloat.simpsonIntegralB(splitHalfCount: shc(), a: minT, maxB: 1, s: ns, f: f)
            doubleTime = DoubleBeat(d * b)
        }
        func linear(_ lf1: Animation.LoopFrame, _ lf2: Animation.LoopFrame) {
            let easing = animation.keyframes[lf1.index].easing
            if easing.isLinear {
                let m = te2 - te1, n = te1
                let l = log(te1) + (m * second.cf) / (d * 60)
                let b = (exp(l) - n) / m
                doubleTime = DoubleBeat(d * b)
            } else {
                simpsonInteglalB {
                    let t = easing.convertT($0)
                    return 1 / BPM.linear(te1, te2, t: t)
                }
            }
        }
        func monospline(_ lf0: Animation.LoopFrame, _ lf1: Animation.LoopFrame,
                        _ lf2: Animation.LoopFrame, _ lf3: Animation.LoopFrame) {
            let te0 = tempos[lf0.index], te3 = tempos[lf3.index]
            var ms = Monospline(x0: Double(lf0.time).cf, x1: Double(lf1.time).cf,
                                x2: Double(lf2.time).cf, x3: Double(lf3.time).cf, t: 0)
            let easing = animation.keyframes[lf1.index].easing
            simpsonInteglalB {
                ms.t = easing.convertT($0)
                return 1 / BPM.monospline(te0, te1, te2, te3, with: ms)
            }
        }
        func firstMonospline(_ lf1: Animation.LoopFrame, _ lf2: Animation.LoopFrame,
                             _ lf3: Animation.LoopFrame) {
            let te3 = tempos[lf3.index]
            var ms = Monospline(x1: Double(lf1.time).cf, x2: Double(lf2.time).cf,
                                x3: Double(lf3.time).cf, t: 0)
            let easing = animation.keyframes[lf1.index].easing
            simpsonInteglalB {
                ms.t = easing.convertT($0)
                return 1 / BPM.firstMonospline(te1, te2, te3, with: ms)
            }
        }
        func lastMonospline(_ lf0: Animation.LoopFrame, _ lf1: Animation.LoopFrame,
                            _ lf2: Animation.LoopFrame) {
            let te0 = tempos[lf0.index]
            var ms = Monospline(x0: Double(lf0.time).cf, x1: Double(lf1.time).cf,
                                x2: Double(lf2.time).cf, t: 0)
            let easing = animation.keyframes[lf1.index].easing
            simpsonInteglalB {
                ms.t = easing.convertT($0)
                return 1 / BPM.lastMonospline(te0, te1, te2, with: ms)
            }
        }
        if te1 == te2 {
            step(lf1)
        } else {
            animation.interpolation(at: li,
                                    step: step, linear: linear,
                                    monospline: monospline,
                                    firstMonospline: firstMonospline, endMonospline: lastMonospline)
        }
        return DoubleBeat(lf1.time) + doubleTime
    }
    func integralSecondDuration(at li: Int, minT: CGFloat = 0, maxT: CGFloat = 1,
                                splitSecondCount: Int = 10) -> Second {
        let lf1 = animation.loopFrames[li], lf2 = animation.loopFrames[li + 1]
        let tempos = tempoItem.keyTempos
        let te1 = tempos[lf1.index], te2 = tempos[lf2.index]
        let d = Double(lf2.time - lf1.time).cf
        func shc() -> Int {
            return max(2, Int(max(te1, te2) / d) * splitSecondCount / 2)
        }
        
        var rTempo = 0.0.cf
        func step(_ lf1: Animation.LoopFrame) {
            rTempo = (maxT - minT) / te1
        }
        func linear(_ lf1: Animation.LoopFrame, _ lf2: Animation.LoopFrame) {
            let easing = animation.keyframes[lf1.index].easing
            if easing.isLinear {
                let linearA = te2 - te1
                let rla = (1 / linearA)
                let fb = rla * log(linearA * maxT + te1)
                let fa = rla * log(linearA * minT + te1)
                rTempo = fb - fa
            } else {
                rTempo = CGFloat.simpsonIntegral(splitHalfCount: shc(), a: minT, b: maxT) {
                    let t = easing.convertT($0)
                    return 1 / BPM.linear(te1, te2, t: t)
                }
            }
        }
        func monospline(_ lf0: Animation.LoopFrame, _ lf1: Animation.LoopFrame,
                        _ lf2: Animation.LoopFrame, _ lf3: Animation.LoopFrame) {
            let te0 = tempos[lf0.index], te3 = tempos[lf3.index]
            var ms = Monospline(x0: Double(lf0.time).cf, x1: Double(lf1.time).cf,
                                x2: Double(lf2.time).cf, x3: Double(lf3.time).cf, t: 0)
            let easing = animation.keyframes[lf1.index].easing
            rTempo = CGFloat.simpsonIntegral(splitHalfCount: shc(), a: minT, b: maxT) {
                ms.t = easing.convertT($0)
                return 1 / BPM.monospline(te0, te1, te2, te3, with: ms)
            }
        }
        func firstMonospline(_ lf1: Animation.LoopFrame, _ lf2: Animation.LoopFrame,
                             _ lf3: Animation.LoopFrame) {
            let te3 = tempos[lf3.index]
            var ms = Monospline(x1: Double(lf1.time).cf, x2: Double(lf2.time).cf,
                                x3: Double(lf3.time).cf, t: 0)
            let easing = animation.keyframes[lf1.index].easing
            rTempo = CGFloat.simpsonIntegral(splitHalfCount: shc(), a: minT, b: maxT) {
                ms.t = easing.convertT($0)
                return 1 / BPM.firstMonospline(te1, te2, te3, with: ms)
            }
        }
        func lastMonospline(_ lf0: Animation.LoopFrame, _ lf1: Animation.LoopFrame,
                            _ lf2: Animation.LoopFrame) {
            let te0 = tempos[lf0.index]
            var ms = Monospline(x0: Double(lf0.time).cf, x1: Double(lf1.time).cf,
                                x2: Double(lf2.time).cf, t: 0)
            let easing = animation.keyframes[lf1.index].easing
            rTempo = CGFloat.simpsonIntegral(splitHalfCount: shc(), a: minT, b: maxT) {
                ms.t = easing.convertT($0)
                return 1 / BPM.lastMonospline(te0, te1, te2, with: ms)
            }
        }
        if te1 == te2 {
            step(lf1)
        } else {
            animation.interpolation(at: li,
                                    step: step, linear: linear,
                                    monospline: monospline,
                                    firstMonospline: firstMonospline, endMonospline: lastMonospline)
        }
        return Second(d * 60 * rTempo)
    }
    
    var time: Beat {
        didSet {
            updateInterpolation()
        }
    }
    func updateInterpolation() {
        animation.update(withTime: time, to: self)
    }
    func step(_ f0: Int) {
        tempoItem.step(f0)
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        tempoItem.linear(f0, f1, t: t)
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        tempoItem.firstMonospline(f1, f2, f3, with: ms)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        tempoItem.monospline(f0, f1, f2, f3, with: ms)
    }
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline) {
        tempoItem.lastMonospline(f0, f1, f2, with: ms)
    }
    
    var tempoItem: TempoItem {
        didSet {
            check(keyCount: tempoItem.keyTempos.count)
            updateKeySeconds()
        }
    }
    
    func replace(_ keyframe: Keyframe, at index: Int) {
        animation.keyframes[index] = keyframe
        updateKeySeconds()
    }
    func replace(_ keyframes: [Keyframe]) {
        check(keyCount: keyframes.count)
        animation.keyframes = keyframes
        updateKeySeconds()
    }
    func replace(duration: Beat) {
        animation.duration = duration
    }
    func replace(_ keyframes: [Keyframe], duration: Beat) {
        check(keyCount: keyframes.count)
        animation.keyframes = keyframes
        animation.duration = duration
        updateKeySeconds()
    }
    func set(selectionkeyframeIndexes: [Int]) {
        animation.selectionKeyframeIndexes = selectionkeyframeIndexes
    }
    
    private func check(keyCount count: Int) {
        guard count == animation.keyframes.count else {
            fatalError()
        }
    }
    
    struct KeyframeValues: KeyframeValue {
        var tempo: BPM
    }
    func insert(_ keyframe: Keyframe, _ kv: KeyframeValues, at index: Int) {
        tempoItem.keyTempos.insert(kv.tempo, at: index)
        animation.keyframes.insert(keyframe, at: index)
        updateKeySeconds()
    }
    func removeKeyframe(at index: Int) {
        animation.keyframes.remove(at: index)
        tempoItem.keyTempos.remove(at: index)
        updateKeySeconds()
    }
    func set(_ keyTempos: [BPM], isSetTempoInItem: Bool  = true) {
        guard keyTempos.count == animation.keyframes.count else {
            fatalError()
        }
        if isSetTempoInItem {
            tempoItem.tempo = keyTempos[animation.editKeyframeIndex]
        }
        tempoItem.keyTempos = keyTempos
        updateKeySeconds()
    }
    func replace(tempo: BPM, at i: Int) {
        tempoItem.replace(tempo: tempo, at: i)
        updateKeySeconds()
    }
    var currentItemValues: KeyframeValues {
        return KeyframeValues(tempo: tempoItem.tempo)
    }
    func keyframeItemValues(at index: Int) -> KeyframeValues {
        return KeyframeValues(tempo: tempoItem.keyTempos[index])
    }
    
    init(animation: Animation = Animation(), time: Beat = 0,
         tempoItem: TempoItem = TempoItem()) {
        
        self.animation = animation
        self.time = time
        self.tempoItem = tempoItem
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case animation, time, duration, tempoItem, keySeconds
    }
    init?(coder: NSCoder) {
        animation = coder.decodeDecodable(
            Animation.self, forKey: CodingKeys.animation.rawValue) ?? Animation()
        time = coder.decodeDecodable(Beat.self, forKey: CodingKeys.time.rawValue) ?? 0
        tempoItem = coder.decodeDecodable(
            TempoItem.self, forKey: CodingKeys.tempoItem.rawValue) ?? TempoItem()
        keySeconds = coder.decodeObject(forKey: CodingKeys.keySeconds.rawValue) as? [Second] ?? []
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeEncodable(animation, forKey: CodingKeys.animation.rawValue)
        coder.encodeEncodable(time, forKey: CodingKeys.time.rawValue)
        coder.encodeEncodable(tempoItem, forKey: CodingKeys.tempoItem.rawValue)
        coder.encode(keySeconds, forKey: CodingKeys.keySeconds.rawValue)
    }
}
extension TempoTrack: Copying {
    func copied(from copier: Copier) -> TempoTrack {
        return TempoTrack(animation: animation, time: time,
                          tempoItem: copier.copied(tempoItem))
    }
}
extension TempoTrack: Referenceable {
    static let name = Localization(english: "Tempo Track", japanese: "テンポトラック")
}

final class NodeTrack: NSObject, Track, NSCoding {
    private(set) var animation: Animation
    private var keyPhases = [CGFloat]()
    
    var name: String
    let id: UUID
    
    var time: Beat {
        didSet {
            updateInterpolation()
        }
    }
    func updateInterpolation() {
        animation.update(withTime: time, to: self)
    }
    func step(_ f0: Int) {
        drawingItem.step(f0)
        cellItems.forEach { $0.step(f0) }
        materialItems.forEach { $0.step(f0) }
        transformItem?.step(f0)
        wiggleItem?.step(f0)
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        drawingItem.linear(f0, f1, t: t)
        cellItems.forEach { $0.linear(f0, f1, t: t) }
        materialItems.forEach { $0.linear(f0, f1, t: t) }
        transformItem?.linear(f0, f1, t: t)
        wiggleItem?.linear(f0, f1, t: t)
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        drawingItem.firstMonospline(f1, f2, f3, with: ms)
        cellItems.forEach { $0.firstMonospline(f1, f2, f3, with: ms) }
        materialItems.forEach { $0.firstMonospline(f1, f2, f3, with: ms) }
        transformItem?.firstMonospline(f1, f2, f3, with: ms)
        wiggleItem?.firstMonospline(f1, f2, f3, with: ms)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        drawingItem.monospline(f0, f1, f2, f3, with: ms)
        cellItems.forEach { $0.monospline(f0, f1, f2, f3, with: ms) }
        materialItems.forEach { $0.monospline(f0, f1, f2, f3, with: ms) }
        transformItem?.monospline(f0, f1, f2, f3, with: ms)
        wiggleItem?.monospline(f0, f1, f2, f3, with: ms)
    }
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline) {
        drawingItem.lastMonospline(f0, f1, f2, with: ms)
        cellItems.forEach { $0.lastMonospline(f0, f1, f2, with: ms) }
        materialItems.forEach { $0.lastMonospline(f0, f1, f2, with: ms) }
        transformItem?.lastMonospline(f0, f1, f2, with: ms)
        wiggleItem?.lastMonospline(f0, f1, f2, with: ms)
    }
    
    var isHidden: Bool {
        didSet {
            cellItems.forEach { $0.cell.isHidden = isHidden }
        }
    }
    
    var drawingItem: DrawingItem {
        didSet {
            check(keyCount: drawingItem.keyDrawings.count)
        }
    }
    
    var selectionCellItems: [CellItem]
    private(set) var cellItems: [CellItem]
    func append(_ cellItem: CellItem) {
        check(keyCount: cellItem.keyGeometries.count)
        cellItems.append(cellItem)
    }
    func remove(_ cellItem: CellItem) {
        if let i = cellItems.index(of: cellItem) {
            cellItems.remove(at: i)
        }
    }
    func replace(_ cellItems: [CellItem]) {
        cellItems.forEach { check(keyCount: $0.keyGeometries.count) }
        self.cellItems = cellItems
    }
    
    private(set) var materialItems: [MaterialItem]
    func append(_ materialItem: MaterialItem) {
        check(keyCount: materialItem.keyMaterials.count)
        materialItems.append(materialItem)
    }
    func remove(_ materialItem: MaterialItem) {
        if let i = materialItems.index(of: materialItem) {
            materialItems.remove(at: i)
        }
    }
    func replace(_ materialItems: [MaterialItem]) {
        materialItems.forEach { check(keyCount: $0.keyMaterials.count) }
        self.materialItems = materialItems
    }
    
    var transformItem: TransformItem? {
        didSet {
            if let transformItem = transformItem {
                check(keyCount: transformItem.keyTransforms.count)
            }
        }
    }
    
    var wiggleItem: WiggleItem? {
        didSet {
            if let wiggleItem = wiggleItem {
                check(keyCount: wiggleItem.keyWiggles.count)
            }
            updateKeyPhases()
        }
    }
    private func updateKeyPhases() {
        guard animation.loopFrames.count >= 2 && wiggleItem != nil else {
            keyPhases = []
            return
        }
        var phase = 0.0.cf
        keyPhases = (0..<animation.loopFrames.count).map { li in
            if li == animation.loopFrames.count - 1 {
                return phase
            } else {
                let p = phase
                phase += integralPhaseDifference(at: li)
                return p
            }
        }
    }
    
    func wigglePhase(withBeatTime time: Beat) -> CGFloat {
        guard let wiggleItem = wiggleItem else {
            return 0
        }
        guard animation.loopFrames.count >= 2 else {
            return wiggleItem.wiggle.frequency * Double(time).cf
        }
        let wiggles = wiggleItem.keyWiggles
        for (li, loopFrame) in animation.loopFrames.enumerated().reversed() {
            if loopFrame.time <= time {
                if li == animation.loopFrames.count - 1 {
                    let wiggle = wiggles[loopFrame.index]
                    return keyPhases[li] + wiggle.frequency * Double(time - loopFrame.time).cf
                } else {
                    let i2t = animation.loopFrames[li + 1].time
                    let d = i2t - loopFrame.time
                    if d == 0 {
                        return keyPhases[li]
                    } else {
                        let t = Double((time - loopFrame.time) / d).cf
                        return keyPhases[li] + integralPhaseDifference(at: li, maxT: t)
                    }
                }
            }
        }
        return 0
    }
    func integralPhaseDifference(at li: Int, minT: CGFloat = 0, maxT: CGFloat = 1,
                                 splitSecondCount: Int = 20) -> CGFloat {
        guard let wiggleItem = wiggleItem else {
            return 0
        }
        let lf1 = animation.loopFrames[li], lf2 = animation.loopFrames[li + 1]
        let wiggles = wiggleItem.keyWiggles
        let f1 = wiggles[lf1.index].frequency, f2 = wiggles[lf2.index].frequency
        let d = Double(lf2.time - lf1.time).cf
        func shc() -> Int {
            return max(2, Int(d) * splitSecondCount / 2)
        }
        
        var df = 0.0.cf
        func step(_ lf1: Animation.LoopFrame) {
            df = f1 * Double(maxT - minT).cf
        }
        func linear(_ lf1: Animation.LoopFrame, _ lf2: Animation.LoopFrame) {
            let easing = animation.keyframes[lf1.index].easing
            if easing.isLinear {
                df = CGFloat.integralLinear(f1, f2, a: minT, b: maxT)
            } else {
                df = CGFloat.simpsonIntegral(splitHalfCount: shc(), a: minT, b: maxT) {
                    let t = easing.convertT($0)
                    return CGFloat.linear(f1, f2, t: t)
                }
            }
        }
        func monospline(_ lf0: Animation.LoopFrame, _ lf1: Animation.LoopFrame,
                        _ lf2: Animation.LoopFrame, _ lf3: Animation.LoopFrame) {
            let f0 = wiggles[lf0.index].frequency, f3 = wiggles[lf3.index].frequency
            var ms = Monospline(x0: Double(lf0.time).cf, x1: Double(lf1.time).cf,
                                x2: Double(lf2.time).cf, x3: Double(lf3.time).cf, t: 0)
            let easing = animation.keyframes[lf1.index].easing
            if easing.isLinear {
                df = ms.integralInterpolatedValue(f0, f1, f2, f3, a: minT, b: maxT)
            } else {
                df = CGFloat.simpsonIntegral(splitHalfCount: shc(), a: minT, b: maxT) {
                    ms.t = easing.convertT($0)
                    return CGFloat.monospline(f0, f1, f2, f3, with: ms)
                }
            }
        }
        func firstMonospline(_ lf1: Animation.LoopFrame, _ lf2: Animation.LoopFrame,
                             _ lf3: Animation.LoopFrame) {
            let f3 = wiggles[lf3.index].frequency
            var ms = Monospline(x1: Double(lf1.time).cf, x2: Double(lf2.time).cf,
                                x3: Double(lf3.time).cf, t: 0)
            let easing = animation.keyframes[lf1.index].easing
            if easing.isLinear {
                df = ms.integralFirstInterpolatedValue(f1, f2, f3, a: minT, b: maxT)
            } else {
                df = CGFloat.simpsonIntegral(splitHalfCount: shc(), a: minT, b: maxT) {
                    ms.t = easing.convertT($0)
                    return CGFloat.firstMonospline(f1, f2, f3, with: ms)
                }
            }
        }
        func lastMonospline(_ lf0: Animation.LoopFrame, _ lf1: Animation.LoopFrame,
                            _ lf2: Animation.LoopFrame) {
            let f0 = wiggles[lf0.index].frequency
            var ms = Monospline(x0: Double(lf0.time).cf, x1: Double(lf1.time).cf,
                                x2: Double(lf2.time).cf, t: 0)
            let easing = animation.keyframes[lf1.index].easing
            if easing.isLinear {
                df = ms.integralLastInterpolatedValue(f0, f1, f2, a: minT, b: maxT)
            } else {
                df = CGFloat.simpsonIntegral(splitHalfCount: shc(), a: minT, b: maxT) {
                    ms.t = easing.convertT($0)
                    return CGFloat.lastMonospline(f0, f1, f2, with: ms)
                }
            }
        }
        if f1 == f2 {
            step(lf1)
        } else {
            animation.interpolation(at: li,
                                    step: step, linear: linear,
                                    monospline: monospline,
                                    firstMonospline: firstMonospline, endMonospline: lastMonospline)
        }
        return df * d
    }
    
    func replace(_ keyframe: Keyframe, at index: Int) {
        animation.keyframes[index] = keyframe
        updateKeyPhases()
    }
    func replace(_ keyframes: [Keyframe]) {
        check(keyCount: keyframes.count)
        animation.keyframes = keyframes
        updateKeyPhases()
    }
    func replace(_ keyframes: [Keyframe], duration: Beat) {
        check(keyCount: keyframes.count)
        animation.keyframes = keyframes
        animation.duration = duration
        updateKeyPhases()
    }
    func set(duration: Beat) {
        animation.duration = duration
    }
    func set(selectionkeyframeIndexes: [Int]) {
        animation.selectionKeyframeIndexes = selectionkeyframeIndexes
    }
    
    private func check(keyCount count: Int) {
        guard count == animation.keyframes.count else {
            fatalError()
        }
    }
    
    func insertCell(_ cellItem: CellItem, in parents: [(cell: Cell, index: Int)]) {
        guard cellItem.cell.children.isEmpty else {
            fatalError()
        }
        guard cellItem.keyGeometries.count == animation.keyframes.count else {
            fatalError()
        }
        guard !cellItems.contains(cellItem) else {
            fatalError()
        }
        parents.forEach { $0.cell.children.insert(cellItem.cell, at: $0.index) }
        cellItems.append(cellItem)
    }
    func insertCells(_ insertCellItems: [CellItem], rootCell: Cell, at index: Int, in parent: Cell) {
        rootCell.children.reversed().forEach { parent.children.insert($0, at: index) }
        insertCellItems.forEach {
            guard $0.keyGeometries.count == animation.keyframes.count else {
                fatalError()
            }
            guard !cellItems.contains($0) else {
                fatalError()
            }
            cellItems.append($0)
        }
    }
    func removeCell(_ cellItem: CellItem, in parents: [(cell: Cell, index: Int)]) {
        guard cellItem.cell.children.isEmpty else {
            fatalError()
        }
        parents.forEach { $0.cell.children.remove(at: $0.index) }
        cellItems.remove(at: cellItems.index(of: cellItem)!)
    }
    func removeCells(_ removeCellItems: [CellItem], rootCell: Cell, in parent: Cell) {
        rootCell.children.forEach { parent.children.remove(at: parent.children.index(of: $0)!) }
        removeCellItems.forEach { cellItems.remove(at: cellItems.index(of: $0)!) }
    }
    
    struct KeyframeValues: KeyframeValue {
        var drawing: Drawing, geometries: [Geometry], materials: [Material]
        var transform: Transform?, wiggle: Wiggle?
    }
    func insert(_ keyframe: Keyframe, _ kv: KeyframeValues, at index: Int) {
        guard kv.geometries.count <= cellItems.count
            && kv.materials.count <= materialItems.count else {
                fatalError()
        }
        animation.keyframes.insert(keyframe, at: index)
        drawingItem.keyDrawings.insert(kv.drawing, at: index)
        cellItems.enumerated().forEach { $0.element.keyGeometries.insert(kv.geometries[$0.offset],
                                                                         at: index) }
        materialItems.enumerated().forEach { $0.element.keyMaterials.insert(kv.materials[$0.offset],
                                                                            at: index) }
        if let transform = kv.transform {
            transformItem?.keyTransforms.insert(transform, at: index)
        }
        if let wiggle = kv.wiggle {
            wiggleItem?.keyWiggles.insert(wiggle, at: index)
        }
        updateKeyPhases()
    }
    func removeKeyframe(at index: Int) {
        animation.keyframes.remove(at: index)
        drawingItem.keyDrawings.remove(at: index)
        cellItems.forEach { $0.keyGeometries.remove(at: index) }
        materialItems.forEach { $0.keyMaterials.remove(at: index) }
        transformItem?.keyTransforms.remove(at: index)
        wiggleItem?.keyWiggles.remove(at: index)
        updateKeyPhases()
    }
    func set(_ keyDrawings: [Drawing]) {
        guard keyDrawings.count == animation.keyframes.count else {
            fatalError()
        }
        drawingItem.keyDrawings = keyDrawings
    }
    func set(_ keyGeometries: [Geometry], in cellItem: CellItem, isSetGeometryInCell: Bool  = true) {
        guard keyGeometries.count == animation.keyframes.count else {
            fatalError()
        }
        if isSetGeometryInCell, let i = cellItem.keyGeometries.index(of: cellItem.cell.geometry) {
            cellItem.cell.geometry = keyGeometries[i]
        }
        cellItem.keyGeometries = keyGeometries
    }
    func set(_ keyTransforms: [Transform], isSetTransformInItem: Bool  = true) {
        guard let transformItem = transformItem else {
            return
        }
        guard keyTransforms.count == animation.keyframes.count else {
            fatalError()
        }
        if isSetTransformInItem,
            let i = transformItem.keyTransforms.index(of: transformItem.transform) {
            
            transformItem.transform = keyTransforms[i]
        }
        transformItem.keyTransforms = keyTransforms
    }
    func set(_ keyWiggles: [Wiggle], isSetWiggleInItem: Bool  = true) {
        guard let wiggleItem = wiggleItem else {
            return
        }
        guard keyWiggles.count == animation.keyframes.count else {
            fatalError()
        }
        if isSetWiggleInItem, let i = wiggleItem.keyWiggles.index(of: wiggleItem.wiggle) {
            wiggleItem.wiggle = keyWiggles[i]
        }
        wiggleItem.keyWiggles = keyWiggles
        updateKeyPhases()
    }
    func replaceWiggle(_ wiggle: Wiggle, at i: Int) {
        wiggleItem?.replace(wiggle, at: i)
        updateKeyPhases()
    }
    
    func set(_ keyMaterials: [Material], in materailItem: MaterialItem) {
        guard keyMaterials.count == animation.keyframes.count else {
            fatalError()
        }
        materailItem.keyMaterials = keyMaterials
    }
    var currentItemValues: KeyframeValues {
        let geometries = cellItems.map { $0.cell.geometry }
        let materials = materialItems.map { $0.material }
        return KeyframeValues(drawing: drawingItem.drawing,
                              geometries: geometries, materials: materials,
                              transform: transformItem?.transform, wiggle: wiggleItem?.wiggle)
    }
    func keyframeItemValues(at index: Int) -> KeyframeValues {
        let geometries = cellItems.map { $0.keyGeometries[index] }
        let materials = materialItems.map { $0.keyMaterials[index] }
        return KeyframeValues(drawing: drawingItem.keyDrawings[index],
                              geometries: geometries, materials: materials,
                              transform: transformItem?.keyTransforms[index],
                              wiggle: wiggleItem?.keyWiggles[index])
    }
    
    init(animation: Animation = Animation(), name: String = "",
         time: Beat = 0,
         isHidden: Bool = false, selectionCellItems: [CellItem] = [],
         drawingItem: DrawingItem = DrawingItem(), cellItems: [CellItem] = [],
         materialItems: [MaterialItem] = [],
         transformItem: TransformItem? = nil, wiggleItem: WiggleItem? = nil) {
        
        self.animation = animation
        self.name = name
        self.time = time
        self.isHidden = isHidden
        self.selectionCellItems = selectionCellItems
        self.drawingItem = drawingItem
        self.cellItems = cellItems
        self.materialItems = materialItems
        self.transformItem = transformItem
        self.wiggleItem = wiggleItem
        id = UUID()
        super.init()
    }
    private init(animation: Animation, name: String, time: Beat,
                 isHidden: Bool, selectionCellItems: [CellItem],
                 drawingItem: DrawingItem, cellItems: [CellItem], materialItems: [MaterialItem],
                 transformItem: TransformItem?, wiggleItem: WiggleItem?, keyPhases: [CGFloat]) {
        self.animation = animation
        self.name = name
        self.time = time
        self.isHidden = isHidden
        self.selectionCellItems = selectionCellItems
        self.drawingItem = drawingItem
        self.cellItems = cellItems
        self.materialItems = materialItems
        self.transformItem = transformItem
        self.wiggleItem = wiggleItem
        self.keyPhases = keyPhases
        id = UUID()
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case
        animation, name, time, duration, isHidden, selectionCellItems,
        drawingItem, cellItems, materialItems, transformItem, wiggleItem, keyPhases, id
    }
    init?(coder: NSCoder) {
        animation = coder.decodeDecodable(
            Animation.self, forKey: CodingKeys.animation.rawValue) ?? Animation()
        name = coder.decodeObject(forKey: CodingKeys.name.rawValue) as? String ?? ""
        time = coder.decodeDecodable(Beat.self, forKey: CodingKeys.time.rawValue) ?? 0
        isHidden = coder.decodeBool(forKey: CodingKeys.isHidden.rawValue)
        
        drawingItem = coder.decodeObject(
            forKey: CodingKeys.drawingItem.rawValue) as? DrawingItem ?? DrawingItem()
        cellItems = coder.decodeObject(forKey: CodingKeys.cellItems.rawValue) as? [CellItem] ?? []
        selectionCellItems = coder.decodeObject(
            forKey: CodingKeys.selectionCellItems.rawValue) as? [CellItem] ?? []
        materialItems = coder.decodeObject(
            forKey: CodingKeys.materialItems.rawValue) as? [MaterialItem] ?? []
        transformItem = coder.decodeDecodable(
            TransformItem.self, forKey: CodingKeys.transformItem.rawValue)
        wiggleItem = coder.decodeDecodable(WiggleItem.self, forKey: CodingKeys.wiggleItem.rawValue)
        keyPhases = coder.decodeObject(forKey: CodingKeys.keyPhases.rawValue) as? [CGFloat] ?? []
        id = coder.decodeObject(forKey: CodingKeys.id.rawValue) as? UUID ?? UUID()
        super.init()
        if drawingItem.keyDrawings.count != animation.keyframes.count {
            drawingItem.keyDrawings = emptyKeyDrawings
        }
        cellItems.forEach {
            if $0.keyGeometries.count != animation.keyframes.count {
                $0.keyGeometries = emptyKeyGeometries
            }
        }
    }
    func encode(with coder: NSCoder) {
        coder.encodeEncodable(animation, forKey: CodingKeys.animation.rawValue)
        coder.encode(name, forKey: CodingKeys.name.rawValue)
        coder.encodeEncodable(time, forKey: CodingKeys.time.rawValue)
        coder.encode(isHidden, forKey: CodingKeys.isHidden.rawValue)
        coder.encode(drawingItem, forKey: CodingKeys.drawingItem.rawValue)
        coder.encode(cellItems, forKey: CodingKeys.cellItems.rawValue)
        coder.encode(selectionCellItems, forKey: CodingKeys.selectionCellItems.rawValue)
        coder.encode(materialItems, forKey: CodingKeys.materialItems.rawValue)
        coder.encodeEncodable(transformItem, forKey: CodingKeys.transformItem.rawValue)
        coder.encodeEncodable(wiggleItem, forKey: CodingKeys.wiggleItem.rawValue)
        coder.encode(keyPhases, forKey: CodingKeys.keyPhases.rawValue)
        coder.encode(id, forKey: CodingKeys.id.rawValue)
    }
    
    func contains(_ cell: Cell) -> Bool {
        for cellItem in cellItems {
            if cellItem.cell == cell {
                return true
            }
        }
        return false
    }
    func contains(_ cellItem: CellItem) -> Bool {
        return cellItems.contains(cellItem)
    }
    func cellItem(with cell: Cell) -> CellItem? {
        for cellItem in cellItems {
            if cellItem.cell == cell {
                return cellItem
            }
        }
        return nil
    }
    var cells: [Cell] {
        return cellItems.map { $0.cell }
    }
    var selectionCellItemsWithNoEmptyGeometry: [CellItem] {
        return selectionCellItems.filter { !$0.cell.geometry.isEmpty }
    }
    func selectionCellItemsWithNoEmptyGeometry(at point: CGPoint) -> [CellItem] {
        for cellItem in selectionCellItems {
            if cellItem.cell.contains(point) {
                return selectionCellItems.filter { !$0.cell.geometry.isEmpty }
            }
        }
        return []
    }
    
    var emptyKeyDrawings: [Drawing] {
        return animation.keyframes.map { _ in Drawing() }
    }
    var emptyKeyGeometries: [Geometry] {
        return animation.keyframes.map { _ in Geometry() }
    }
    var isEmptyGeometryWithCells: Bool {
        for cellItem in cellItems {
            if !cellItem.cell.geometry.isEmpty {
                return false
            }
        }
        return true
    }
    func isEmptyGeometryWithCells(at time: Beat) -> Bool {
        let index = animation.loopedKeyframeIndex(withTime: time).keyframeIndex
        for cellItem in cellItems {
            if !cellItem.keyGeometries[index].isEmpty {
                return false
            }
        }
        return true
    }
    func emptyKeyMaterials(with material: Material) -> [Material] {
        return animation.keyframes.map { _ in material }
    }
    
    func snapCells(with cell: Cell) -> [Cell] {
        var cells = self.cells
        var snapedCells = cells.flatMap { $0 !== cell && $0.isSnaped(cell) ? $0 : nil }
        func snap(_ withCell: Cell) {
            var newSnapedCells = [Cell]()
            cells = cells.flatMap {
                if $0.isSnaped(withCell) {
                    newSnapedCells.append($0)
                    return nil
                } else {
                    return $0
                }
            }
            if !newSnapedCells.isEmpty {
                snapedCells += newSnapedCells
                for newCell in newSnapedCells { snap(newCell) }
            }
        }
        snap(cell)
        return snapedCells
    }
    
    func snapPoint(_ point: CGPoint, with n: Node.Nearest.BezierSortedResult,
                   snapDistance: CGFloat, grid: CGFloat?) -> CGPoint {
        
        let p: CGPoint
        if let grid = grid {
            p = CGPoint(x: point.x.interval(scale: grid), y: point.y.interval(scale: grid))
        } else {
            p = point
        }
        var minD = CGFloat.infinity, minP = p
        func updateMin(with ap: CGPoint) {
            let d0 = p.distance(ap)
            if d0 < snapDistance && d0 < minD {
                minD = d0
                minP = ap
            }
        }
        func update(cellItem: CellItem?) {
            for (i, line) in drawingItem.drawing.lines.enumerated() {
                if i == n.lineCap.lineIndex {
                    updateMin(with: n.lineCap.isFirst ? line.lastPoint : line.firstPoint)
                } else {
                    updateMin(with: line.firstPoint)
                    updateMin(with: line.lastPoint)
                }
            }
            for aCellItem in cellItems {
                for (i, line) in aCellItem.cell.geometry.lines.enumerated() {
                    if aCellItem == cellItem && i == n.lineCap.lineIndex {
                        updateMin(with: n.lineCap.isFirst ? line.lastPoint : line.firstPoint)
                    } else {
                        updateMin(with: line.firstPoint)
                        updateMin(with: line.lastPoint)
                    }
                }
            }
        }
        if n.drawing != nil {
            update(cellItem: nil)
        } else if let cellItem = n.cellItem {
            update(cellItem: cellItem)
        }
        return minP
    }
    
    func snapPoint(_ sp: CGPoint, editLine: Line, editPointIndex: Int,
                   snapDistance: CGFloat) -> CGPoint {
        
        let p: CGPoint, isFirst = editPointIndex == 1 || editPointIndex == editLine.controls.count - 1
        if isFirst {
            p = editLine.firstPoint
        } else if editPointIndex == editLine.controls.count - 2 || editPointIndex == 0 {
            p = editLine.lastPoint
        } else {
            fatalError()
        }
        var snapLines = [(ap: CGPoint, bp: CGPoint)](), lastSnapLines = [(ap: CGPoint, bp: CGPoint)]()
        func snap(with lines: [Line]) {
            for line in lines {
                if editLine.controls.count == 3 {
                    if line != editLine {
                        if line.firstPoint == editLine.firstPoint {
                            snapLines.append((line.controls[1].point, editLine.firstPoint))
                        } else if line.lastPoint == editLine.firstPoint {
                            snapLines.append((line.controls[line.controls.count - 2].point,
                                              editLine.firstPoint))
                        }
                        if line.firstPoint == editLine.lastPoint {
                            lastSnapLines.append((line.controls[1].point, editLine.lastPoint))
                        } else if line.lastPoint == editLine.lastPoint {
                            lastSnapLines.append((line.controls[line.controls.count - 2].point,
                                                  editLine.lastPoint))
                        }
                    }
                } else {
                    if line.firstPoint == p && !(line == editLine && isFirst) {
                        snapLines.append((line.controls[1].point, p))
                    } else if line.lastPoint == p && !(line == editLine && !isFirst) {
                        snapLines.append((line.controls[line.controls.count - 2].point, p))
                    }
                }
            }
        }
        snap(with: drawingItem.drawing.lines)
        for cellItem in cellItems {
            snap(with: cellItem.cell.geometry.lines)
        }
        
        var minD = CGFloat.infinity, minIntersectionPoint: CGPoint?, minPoint = sp
        if !snapLines.isEmpty && !lastSnapLines.isEmpty {
            for sl in snapLines {
                for lsl in lastSnapLines {
                    if let ip = CGPoint.intersectionLine(sl.ap, sl.bp, lsl.ap, lsl.bp) {
                        let d = ip.distance(sp)
                        if d < snapDistance && d < minD {
                            minD = d
                            minIntersectionPoint = ip
                        }
                    }
                }
            }
        }
        if let minPoint = minIntersectionPoint {
            return minPoint
        }
        let ss = snapLines + lastSnapLines
        for sl in ss {
            let np = sp.nearestWithLine(ap: sl.ap, bp: sl.bp)
            let d = np.distance(sp)
            if d < snapDistance && d < minD {
                minD = d
                minPoint = np
            }
        }
        return minPoint
    }
    
    var imageBounds: CGRect {
        return cellItems.reduce(CGRect()) { $0.unionNoEmpty($1.cell.imageBounds) }
            .unionNoEmpty(drawingItem.imageBounds)
    }
    
    func drawPreviousNext(isShownPrevious: Bool, isShownNext: Bool,
                          time: Beat, reciprocalScale: CGFloat, in ctx: CGContext) {
        let index = animation.loopedKeyframeIndex(withTime: time).keyframeIndex
        drawingItem.drawPreviousNext(isShownPrevious: isShownPrevious, isShownNext: isShownNext,
                                     index: index, reciprocalScale: reciprocalScale, in: ctx)
        cellItems.forEach {
            $0.drawPreviousNext(lineWidth: drawingItem.lineWidth * reciprocalScale,
                                isShownPrevious: isShownPrevious, isShownNext: isShownNext,
                                index: index, in: ctx)
        }
    }
    func drawSelectionCells(opacity: CGFloat, color: Color, subColor: Color,
                            reciprocalScale: CGFloat, in ctx: CGContext) {
        guard !isHidden && !selectionCellItems.isEmpty else {
            return
        }
        ctx.setAlpha(opacity)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        var geometrys = [Geometry]()
        ctx.setFillColor(subColor.with(alpha: 1).cgColor)
        func setPaths(with cellItem: CellItem) {
            let cell = cellItem.cell
            if !cell.geometry.isEmpty {
                cell.geometry.addPath(in: ctx)
                ctx.fillPath()
                geometrys.append(cell.geometry)
            }
        }
        selectionCellItems.forEach { setPaths(with: $0) }
        ctx.endTransparencyLayer()
        ctx.setAlpha(1)
        
        ctx.setFillColor(color.with(alpha: 1).cgColor)
        geometrys.forEach { $0.draw(withLineWidth: 1.5 * reciprocalScale, in: ctx) }
    }
    func drawTransparentCellLines(withReciprocalScale reciprocalScale: CGFloat, in ctx: CGContext) {
        cellItems.forEach {
            $0.cell.geometry.drawLines(withColor: Color.border,
                                       reciprocalScale: reciprocalScale, in: ctx)
            $0.cell.geometry.drawPathLine(withReciprocalScale: reciprocalScale, in: ctx)
        }
    }
    func drawSkinCellItem(_ cellItem: CellItem,
                          reciprocalScale: CGFloat, reciprocalAllScale: CGFloat, in ctx: CGContext) {
        cellItem.cell.geometry.drawSkin(lineColor: .indicated,
                                        subColor: Color.subIndicated.multiply(alpha: 0.2),
                                        skinLineWidth: animation.isInterpolated ? 3 : 1,
                                        reciprocalScale: reciprocalScale,
                                        reciprocalAllScale: reciprocalAllScale, in: ctx)
    }
}
extension NodeTrack: Copying {
    func copied(from copier: Copier) -> NodeTrack {
        return NodeTrack(animation: animation, name: name,
                         time: time, isHidden: isHidden,
                         selectionCellItems: selectionCellItems.map { copier.copied($0) },
                         drawingItem: copier.copied(drawingItem),
                         cellItems: cellItems.map { copier.copied($0) },
                         materialItems: materialItems.map { copier.copied($0) },
                         transformItem: transformItem != nil ? copier.copied(transformItem!) : nil,
                         wiggleItem: wiggleItem != nil ? copier.copied(wiggleItem!) : nil,
                         keyPhases: keyPhases)
    }
}
extension NodeTrack: Referenceable {
    static let name = Localization(english: "Node Track", japanese: "ノードトラック")
}

/**
 # Issue
 - 変更通知またはイミュータブル化またはstruct化
 */
protocol TrackItem {
    func step(_ f0: Int)
    func linear(_ f0: Int, _ f1: Int, t: CGFloat)
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline)
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline)
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline)
}

final class DrawingItem: NSObject, TrackItem, NSCoding {
    var drawing: Drawing, color: Color, lineWidth: CGFloat
    fileprivate(set) var keyDrawings: [Drawing]
    
    func step(_ f0: Int) {
        drawing = keyDrawings[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        drawing = keyDrawings[f0]
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        drawing = keyDrawings[f1]
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        drawing = keyDrawings[f1]
    }
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline) {
        drawing = keyDrawings[f1]
    }
    
    static let defaultLineWidth = 1.0.cf
    
    init(drawing: Drawing = Drawing(), keyDrawings: [Drawing] = [],
         color: Color = .strokeLine, lineWidth: CGFloat = defaultLineWidth) {
        
        self.drawing = drawing
        self.keyDrawings = keyDrawings.isEmpty ? [drawing] : keyDrawings
        self.color = color
        self.lineWidth = lineWidth
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case drawing, keyDrawings, lineWidth
    }
    init(coder: NSCoder) {
        drawing = coder.decodeObject(forKey: CodingKeys.drawing.rawValue) as? Drawing ?? Drawing()
        keyDrawings = coder.decodeObject(forKey: CodingKeys.keyDrawings.rawValue) as? [Drawing] ?? []
        lineWidth = coder.decodeDouble(forKey: CodingKeys.lineWidth.rawValue).cf
        color = .strokeLine
        super.init()
    }
    var isEncodeDrawings = true
    func encode(with coder: NSCoder) {
        if isEncodeDrawings {
            coder.encode(drawing, forKey: CodingKeys.drawing.rawValue)
            coder.encode(keyDrawings, forKey: CodingKeys.keyDrawings.rawValue)
        }
        coder.encode(lineWidth.d, forKey: CodingKeys.lineWidth.rawValue)
    }
    
    var imageBounds: CGRect {
        return drawing.imageBounds(withLineWidth: lineWidth)
    }
    
    func drawEdit(withReciprocalScale reciprocalScale: CGFloat, in ctx: CGContext) {
        drawing.drawEdit(lineWidth: lineWidth * reciprocalScale, lineColor: color, in: ctx)
    }
    func draw(withReciprocalScale reciprocalScale: CGFloat, in ctx: CGContext) {
        drawing.draw(lineWidth: lineWidth * reciprocalScale, lineColor: color, in: ctx)
    }
    func drawPreviousNext(isShownPrevious: Bool, isShownNext: Bool,
                          index: Int, reciprocalScale: CGFloat, in ctx: CGContext) {
        let lineWidth = self.lineWidth * reciprocalScale
        if isShownPrevious && index - 1 >= 0 {
            keyDrawings[index - 1].draw(lineWidth: lineWidth, lineColor: Color.previous, in: ctx)
        }
        if isShownNext && index + 1 <= keyDrawings.count - 1 {
            keyDrawings[index + 1].draw(lineWidth: lineWidth, lineColor: Color.next, in: ctx)
        }
    }
}
extension DrawingItem: Copying {
    func copied(from copier: Copier) -> DrawingItem {
        return DrawingItem(drawing: copier.copied(drawing),
                           keyDrawings: keyDrawings.map { copier.copied($0) }, color: color)
    }
}
extension DrawingItem: Referenceable {
    static let name = Localization(english: "Drawing Item", japanese: "ドローイングアイテム")
}

final class CellItem: NSObject, TrackItem, NSCoding {
    let cell: Cell
    let id: UUID
    fileprivate(set) var keyGeometries: [Geometry]
    func replace(_ geometry: Geometry, at i: Int) {
        if keyGeometries[i] == cell.geometry {
            cell.geometry = geometry
        }
        keyGeometries[i] = geometry
    }
    
    func step(_ f0: Int) {
        cell.geometry = keyGeometries[f0]
        cell.drawGeometry = keyGeometries[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        cell.geometry = keyGeometries[f0]
        cell.drawGeometry = Geometry.linear(keyGeometries[f0], keyGeometries[f1], t: t)
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        cell.geometry = keyGeometries[f1]
        cell.drawGeometry = Geometry.firstMonospline(keyGeometries[f1], keyGeometries[f2],
                                                     keyGeometries[f3], with: ms)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        cell.geometry = keyGeometries[f1]
        cell.drawGeometry = Geometry.monospline(keyGeometries[f0], keyGeometries[f1],
                                                keyGeometries[f2], keyGeometries[f3], with: ms)
    }
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline) {
        cell.geometry = keyGeometries[f1]
        cell.drawGeometry = Geometry.lastMonospline(keyGeometries[f0], keyGeometries[f1],
                                                    keyGeometries[f2], with: ms)
    }
    
    init(cell: Cell, keyGeometries: [Geometry] = []) {
        self.cell = cell
        self.keyGeometries = keyGeometries
        id = UUID()
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case cell, cells, keyGeometries, id
    }
    init?(coder: NSCoder) {
        cell = coder.decodeObject(forKey: CodingKeys.cell.rawValue) as? Cell ?? Cell()
        keyGeometries = coder.decodeObject(
            forKey: CodingKeys.keyGeometries.rawValue) as? [Geometry] ?? []
        id = coder.decodeObject(forKey: CodingKeys.id.rawValue) as? UUID ?? UUID()
        super.init()
    }
    var isEncodeGeometries = true {
        didSet {
            cell.isEncodeGeometry = isEncodeGeometries
        }
    }
    func encode(with coder: NSCoder) {
        coder.encode(cell, forKey: CodingKeys.cell.rawValue)
        if isEncodeGeometries {
            coder.encode(keyGeometries, forKey: CodingKeys.keyGeometries.rawValue)
        }
        coder.encode(id, forKey: CodingKeys.id.rawValue)
    }
    
    var isEmptyKeyGeometries: Bool {
        for keyGeometry in keyGeometries {
            if !keyGeometry.isEmpty {
                return false
            }
        }
        return true
    }
    
    func drawPreviousNext(lineWidth: CGFloat,
                          isShownPrevious: Bool, isShownNext: Bool, index: Int, in ctx: CGContext) {
        if isShownPrevious && index - 1 >= 0 {
            ctx.setFillColor(Color.previous.cgColor)
            keyGeometries[index - 1].draw(withLineWidth: lineWidth, in: ctx)
        }
        if isShownNext && index + 1 <= keyGeometries.count - 1 {
            ctx.setFillColor(Color.next.cgColor)
            keyGeometries[index + 1].draw(withLineWidth: lineWidth, in: ctx)
        }
    }
}
extension CellItem: Copying {
    func copied(from copier: Copier) -> CellItem {
        return CellItem(cell: copier.copied(cell), keyGeometries: keyGeometries)
    }
}
extension CellItem: Referenceable {
    static let name = Localization(english: "Cell Item", japanese: "セルアイテム")
}

final class MaterialItem: NSObject, TrackItem, NSCoding {
    var cells: [Cell]
    var material: Material {
        didSet {
            self.cells.forEach { $0.material = material }
        }
    }
    fileprivate(set) var keyMaterials: [Material]
    func replace(_ material: Material, at i: Int) {
        if keyMaterials[i] == self.material {
            self.material = material
        }
        keyMaterials[i] = material
    }
    
    func step(_ f0: Int) {
        self.material = keyMaterials[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        self.material = Material.linear(keyMaterials[f0], keyMaterials[f1], t: t)
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        self.material = Material.firstMonospline(keyMaterials[f1], keyMaterials[f2],
                                                 keyMaterials[f3], with: ms)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        self.material = Material.monospline(keyMaterials[f0], keyMaterials[f1],
                                            keyMaterials[f2], keyMaterials[f3], with: ms)
    }
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline) {
        self.material = Material.lastMonospline(keyMaterials[f0], keyMaterials[f1],
                                               keyMaterials[f2], with: ms)
    }
    
    init(material: Material = Material(), cells: [Cell] = [], keyMaterials: [Material] = []) {
        self.material = material
        self.cells = cells
        self.keyMaterials = keyMaterials
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case material, cells, keyMaterials
    }
    init?(coder: NSCoder) {
        material = coder.decodeObject(
            forKey: CodingKeys.material.rawValue) as? Material ?? Material()
        cells = coder.decodeObject(forKey: CodingKeys.cells.rawValue) as? [Cell] ?? []
        keyMaterials = coder.decodeObject(
            forKey: CodingKeys.keyMaterials.rawValue) as? [Material] ?? []
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(material, forKey: CodingKeys.material.rawValue)
        coder.encode(cells, forKey: CodingKeys.cells.rawValue)
        coder.encode(keyMaterials, forKey: CodingKeys.keyMaterials.rawValue)
    }
}
extension MaterialItem: Copying {
    func copied(from copier: Copier) -> MaterialItem {
        return MaterialItem(material: material,
                            cells: cells.map { copier.copied($0) }, keyMaterials: keyMaterials)
    }
}
extension MaterialItem: Referenceable {
    static let name = Localization(english: "Material Item", japanese: "マテリアルアイテム")
}

final class TransformItem: TrackItem, Codable {
    var transform: Transform
    fileprivate(set) var keyTransforms: [Transform]
    func replace(_ transform: Transform, at i: Int) {
        if keyTransforms[i] == self.transform {
            self.transform = transform
        }
        keyTransforms[i] = transform
    }
    var drawTransform: Transform
    
    func step(_ f0: Int) {
        transform = keyTransforms[f0]
        drawTransform = keyTransforms[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        transform = keyTransforms[f0]
        drawTransform = Transform.linear(keyTransforms[f0], keyTransforms[f1], t: t)
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        transform = keyTransforms[f1]
        drawTransform = Transform.firstMonospline(keyTransforms[f1], keyTransforms[f2],
                                                  keyTransforms[f3], with: ms)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        transform = keyTransforms[f1]
        drawTransform = Transform.monospline(keyTransforms[f0], keyTransforms[f1],
                                             keyTransforms[f2], keyTransforms[f3], with: ms)
    }
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline) {
        transform = keyTransforms[f1]
        drawTransform = Transform.lastMonospline(keyTransforms[f0], keyTransforms[f1],
                                                 keyTransforms[f2], with: ms)
    }
    
    init(transform: Transform = Transform(), keyTransforms: [Transform] = [Transform()]) {
        self.transform = transform
        self.drawTransform = transform
        self.keyTransforms = keyTransforms
    }
    
    static func empty(with animation: Animation) -> TransformItem {
        let transformItem =  TransformItem()
        let transforms = animation.keyframes.map { _ in Transform() }
        transformItem.keyTransforms = transforms
        transformItem.transform = transforms[animation.editKeyframeIndex]
        return transformItem
    }
    var isEmpty: Bool {
        for t in keyTransforms {
            if !t.isIdentity {
                return false
            }
        }
        return true
    }
}
extension TransformItem: Copying {
    func copied(from copier: Copier) -> TransformItem {
        return TransformItem(transform: transform, keyTransforms: keyTransforms)
    }
}
extension TransformItem: Referenceable {
    static let name = Localization(english: "Transform Item", japanese: "トランスフォームアイテム")
}

final class WiggleItem: TrackItem, Codable {
    var wiggle: Wiggle
    fileprivate(set) var keyWiggles: [Wiggle]
    func replace(_ wiggle: Wiggle, at i: Int) {
        if keyWiggles[i] == self.wiggle {
            self.wiggle = wiggle
        }
        keyWiggles[i] = wiggle
    }
    var drawWiggle: Wiggle
    
    func step(_ f0: Int) {
        wiggle = keyWiggles[f0]
        drawWiggle = keyWiggles[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        wiggle = keyWiggles[f0]
        drawWiggle = Wiggle.linear(keyWiggles[f0], keyWiggles[f1], t: t)
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        wiggle = keyWiggles[f1]
        drawWiggle = Wiggle.firstMonospline(keyWiggles[f1], keyWiggles[f2],
                                            keyWiggles[f3], with: ms)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        wiggle = keyWiggles[f1]
        drawWiggle = Wiggle.monospline(keyWiggles[f0], keyWiggles[f1],
                                       keyWiggles[f2], keyWiggles[f3], with: ms)
    }
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline) {
        wiggle = keyWiggles[f1]
        drawWiggle = Wiggle.lastMonospline(keyWiggles[f0], keyWiggles[f1],
                                           keyWiggles[f2], with: ms)
    }
    
    init(wiggle: Wiggle = Wiggle(), keyWiggles: [Wiggle] = [Wiggle()]) {
        self.wiggle = wiggle
        drawWiggle = wiggle
        self.keyWiggles = keyWiggles
    }
    
    static func empty(with animation: Animation) -> WiggleItem {
        let wiggleItem =  WiggleItem()
        let wiggles = animation.keyframes.map { _ in Wiggle() }
        wiggleItem.keyWiggles = wiggles
        wiggleItem.wiggle = wiggles[animation.editKeyframeIndex]
        return wiggleItem
    }
    var isEmpty: Bool {
        for t in keyWiggles {
            if !t.isEmpty {
                return false
            }
        }
        return true
    }
}
extension WiggleItem: Copying {
    func copied(from copier: Copier) -> WiggleItem {
        return WiggleItem(wiggle: wiggle, keyWiggles: keyWiggles)
    }
}
extension WiggleItem: Referenceable {
    static let name = Localization(english: "Wiggle Item", japanese: "振動アイテム")
}

final class SpeechItem: TrackItem, Codable {
    var speech: Speech
    fileprivate(set) var keySpeechs: [Speech]
    func replaceSpeech(_ speech: Speech, at i: Int) {
        keySpeechs[i] = speech
        self.speech = speech
    }
    
    func step(_ f0: Int) {
        self.speech = keySpeechs[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        self.speech = keySpeechs[f0]
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        self.speech = keySpeechs[f1]
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        self.speech = keySpeechs[f1]
    }
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline) {
        self.speech = keySpeechs[f1]
    }
    
    func update(with f0: Int) {
        self.speech = keySpeechs[f0]
    }
    
    init(speech: Speech = Speech(), keySpeechs: [Speech] = [Speech()]) {
        self.speech = speech
        self.keySpeechs = keySpeechs
    }
    
    var isEmpty: Bool {
        for t in keySpeechs {
            if !t.isEmpty {
                return false
            }
        }
        return true
    }
}
extension SpeechItem: Copying {
    func copied(from copier: Copier) -> SpeechItem {
        return SpeechItem(speech: speech, keySpeechs: keySpeechs)
    }
}
extension SpeechItem: Referenceable {
    static let name = Localization(english: "Speech Item", japanese: "スピーチアイテム")
}

final class TempoItem: TrackItem, Codable {
    var tempo: BPM
    fileprivate(set) var keyTempos: [BPM]
    func replace(tempo: BPM, at i: Int) {
        keyTempos[i] = tempo
        self.tempo = tempo
    }
    var drawTempo: BPM

    func step(_ f0: Int) {
        tempo = keyTempos[f0]
        drawTempo = keyTempos[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        tempo = keyTempos[f0]
        drawTempo = BPM.linear(keyTempos[f0], keyTempos[f1], t: t)
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        tempo = keyTempos[f1]
        drawTempo = BPM.firstMonospline(keyTempos[f1], keyTempos[f2], keyTempos[f3], with: ms)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        tempo = keyTempos[f1]
        drawTempo = BPM.monospline(keyTempos[f0], keyTempos[f1],
                                   keyTempos[f2], keyTempos[f3], with: ms)
    }
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline) {
        tempo = keyTempos[f1]
        drawTempo = BPM.lastMonospline(keyTempos[f0], keyTempos[f1], keyTempos[f2], with: ms)
    }

    static let defaultTempo = BPM(60)
    init(tempo: BPM = defaultTempo, keyTempos: [BPM] = [defaultTempo]) {
        self.tempo = tempo
        drawTempo = tempo
        self.keyTempos = keyTempos
    }

    static func empty(with animation: Animation) -> TempoItem {
        let tempoItem =  TempoItem()
        let tempos = animation.keyframes.map { _ in defaultTempo }
        tempoItem.keyTempos = tempos
        tempoItem.tempo = tempos[animation.editKeyframeIndex]
        return tempoItem
    }
}
extension TempoItem: Copying {
    func copied(from copier: Copier) -> TempoItem {
        return TempoItem(tempo: tempo, keyTempos: keyTempos)
    }
}
extension TempoItem: Referenceable {
    static let name = Localization(english: "Tempo Item", japanese: "テンポアイテム")
}

final class SoundItem: TrackItem, Codable {
    var sound: Sound
    fileprivate(set) var keySounds: [Sound]
    func replace(_ sound: Sound, at i: Int) {
        keySounds[i] = sound
        self.sound = sound
    }
    
    func step(_ f0: Int) {
        sound = keySounds[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        sound = keySounds[f0]
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        sound = keySounds[f1]
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        sound = keySounds[f1]
    }
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline) {
        sound = keySounds[f1]
    }
    
    static let defaultSound = Sound()
    init(sound: Sound = defaultSound, keySounds: [Sound] = [defaultSound]) {
        self.sound = sound
        self.keySounds = keySounds
    }
}
extension SoundItem: Copying {
    func copied(from copier: Copier) -> SoundItem {
        return SoundItem(sound: sound, keySounds: keySounds)
    }
}
extension SoundItem: Referenceable {
    static let name = Localization(english: "Sound Item", japanese: "サウンドアイテム")
}
