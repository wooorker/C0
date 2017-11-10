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
//再生中の時間移動
//Playerを別の場所で常に表示

import Foundation
import QuartzCore
import AVFoundation

protocol PlayerDelegate: class {
    func endPlay(_ player: Player)
}
final class Player: LayerRespondable {
    static let name = Localization(english: "Player", japanese: "プレイヤー")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: [])
        }
    }
    
    var undoManager: UndoManager?
    
    weak var delegate: PlayerDelegate?
    
    var layer = CALayer.interfaceLayer(), drawLayer = DrawLayer(backgroundColor: .white)
    var playCutItem: CutItem? {
        didSet {
            if let playCutItem = playCutItem {
                self.cut = playCutItem.cut.deepCopy
            }
        }
    }
    var cut = Cut()
    var time: Q {
        get {
            return cut.time
        } set {
            cut.time = newValue
        }
    }
    var scene = Scene() {
        didSet {
            updateChildren()
        }
    }
    func updateChildren() {
        CATransaction.disableAnimation {
            let paddingWidth = (bounds.width - scene.frame.size.width)/2
            let paddingHeight = (bounds.height - scene.frame.size.height)/2
            drawLayer.frame = CGRect(origin: CGPoint(x: paddingWidth, y: paddingHeight), size: scene.frame.size)
            screenTransform = CGAffineTransform(translationX: drawLayer.bounds.midX, y: drawLayer.bounds.midY)
            let alltw = timeLabelWidth*3, labelHeight = round(paddingHeight/2) - 15
            timeLabel.frame = CGRect(
                x: bounds.midX - floor(alltw/2), y: labelHeight,
                width: timeLabelWidth, height: 30
            )
            cutLabel.frame = CGRect(
                x: bounds.midX - floor(alltw/2) + timeLabelWidth, y: labelHeight,
                width: timeLabelWidth, height: 30
            )
            frameRateLabel.frame = CGRect(
                x: bounds.midX - floor(alltw/2) + timeLabelWidth*2, y: labelHeight,
                width: timeLabelWidth, height: 30
            )
        }
    }
    func draw(in ctx: CGContext) {
        ctx.concatenate(screenTransform)
        cut.rootNode.draw(
            scene: scene, viewType: .preview,
            scale: 1, rotation: 0, viewScale: scene.scale, viewRotation: scene.viewTransform.rotation,
            in: ctx
        )
    }
    
    private let timeLabelWidth = 40.0.cf
    let timeLabel = Label(string: "00:00", color: .smallFont, backgroundColor: .playBorder)
    let cutLabel = Label(string: "C1", color: .smallFont, backgroundColor: .playBorder)
    let frameRateLabel = Label(string: "0fps", color: .smallFont, backgroundColor: .playBorder)
    
    init() {
        layer.backgroundColor = Color.playBorder.cgColor
        drawLayer.borderWidth = 0
        drawLayer.drawBlock = { [unowned self] ctx in
            self.draw(in: ctx)
        }
        children = [timeLabel, cutLabel, frameRateLabel]
        update(withChildren: children, oldChildren: [])
        layer.addSublayer(drawLayer)
    }
    
    var screenTransform = CGAffineTransform.identity
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            layer.frame = newValue
            updateChildren()
        }
    }
    
    var editCutItem = CutItem()
    var audioPlayer: AVAudioPlayer?
    
    var contentsScale: CGFloat {
        get {
            return layer.contentsScale
        } set {
            layer.contentsScale = newValue
            drawLayer.contentsScale = newValue
            allChildren { ($0 as? LayerRespondable)?.layer.contentsScale = newValue }
        }
    }
    
    private var timer = LockTimer(), oldPlayCutItem: CutItem?, oldPlayTime = Q(0), oldTimestamp = 0.0
    private var playDrawCount = 0, playCutIndex = 0, playSecond = 0, playFrameRate = FPS(0), delayTolerance = 0.5
    var isPlaying = false {
        didSet {
            if isPlaying {
                playCutItem = editCutItem
                oldPlayCutItem = editCutItem
                time = editCutItem.cut.time
                oldPlayTime = editCutItem.cut.time
                oldTimestamp = CFAbsoluteTimeGetCurrent()
                let t = currentPlayTime
                playSecond = t.integralPart
                playCutIndex = scene.editCutItemIndex
                playFrameRate = scene.frameRate
                playDrawCount = 0
                timeLabel.textLine.string = minuteSecondString(withSecond: playSecond, frameRate: scene.frameRate)
                cutLabel.textLine.string = "C\(playCutIndex + 1)"
                frameRateLabel.textLine.string = "\(playFrameRate)fps"
                frameRateLabel.textLine.color = playFrameRate != scene.frameRate ? Color.warning : Color.smallFont
                if let url = scene.soundItem.url {
                    do {
                        try audioPlayer = AVAudioPlayer(contentsOf: url)
                    } catch {
                    }
                }
                audioPlayer?.currentTime = t.doubleValue
                audioPlayer?.play()
                timer.begin(1/scene.frameRate.d, tolerance: 0.1/scene.frameRate.d) { [unowned self] in
                    self.updatePlayTime()
                }
                drawLayer.setNeedsDisplay()
            } else {
                timer.stop()
                playCutItem = nil
                audioPlayer?.stop()
                audioPlayer = nil
                drawLayer.contents = nil
            }
        }
    }
    private func updatePlayTime() {
        if let playCutItem = playCutItem {
            var updated = false
            if let audioPlayer = audioPlayer, !scene.soundItem.isHidden {
                let t = Q(Int(audioPlayer.currentTime*Double(scene.frameRate)), scene.frameRate) //Int(audioPlayer.currentTime*Double(scene.frameRate))
                let pt = currentPlayTime + Q(1, scene.frameRate)
                if abs(pt - t) > Q(1, scene.frameRate) {
                    let viewIndex = scene.cutItemIndex(withTime: t)
                    if viewIndex.isOver {
                        self.playCutItem = scene.cutItems[0]
                        time = 0
                        audioPlayer.currentTime = 0
                    } else {
                        let cutItem = scene.cutItems[viewIndex.index]
                        if cutItem != playCutItem {
                            self.playCutItem = cutItem
                        }
                        time = viewIndex.interTime
                    }
                    updated = true
                }
            }
            if !updated {
                let nextTime = time + Q(1, scene.frameRate)
                if nextTime < playCutItem.cut.timeLength {
                    time =  nextTime
                } else if scene.cutItems.count == 1 {
                    time = 0
                } else {
                    let cutIndex = scene.cutItems.index(of: playCutItem) ?? 0
                    let nextCutIndex = cutIndex + 1 <= scene.cutItems.count - 1 ? cutIndex + 1 : 0
                    let nextCutItem = scene.cutItems[nextCutIndex]
                    self.playCutItem = nextCutItem
                    time = 0
                    if nextCutIndex == 0 {
                        audioPlayer?.currentTime = 0
                    }
                }
                drawLayer.setNeedsDisplay()
            }
            
            let t = currentPlayTime
            let s = t.integralPart
            if s != playSecond {
                playSecond = s
                timeLabel.textLine.string = minuteSecondString(withSecond: playSecond, frameRate: scene.frameRate)
            }
            
            if let cutItemIndex = scene.cutItems.index(of: playCutItem), playCutIndex != cutItemIndex {
                playCutIndex = cutItemIndex
                cutLabel.textLine.string = "C\(playCutIndex + 1)"
            }
            
            playDrawCount += 1
            let newTimestamp = CFAbsoluteTimeGetCurrent()
            let deltaTime = newTimestamp - oldTimestamp
            if deltaTime >= 1 {
                let newPlayFrameRate = min(scene.frameRate, Int(round(Double(playDrawCount)/deltaTime)))
                if newPlayFrameRate != playFrameRate {
                    playFrameRate = newPlayFrameRate
                    frameRateLabel.textLine.string = "\(playFrameRate)fps"
                    frameRateLabel.textLine.color = playFrameRate != scene.frameRate ? Color.warning : Color.smallFont
                }
                oldTimestamp = newTimestamp
                playDrawCount = 0
            }
        }
    }
    func minuteSecondString(withSecond s: Int, frameRate: FPS) -> String {
        if s >= 60 {
            let minute = s/60
            let second = s - minute*60
            return String(format: "%02d:%02d", minute, second)
        } else {
            return String(format: "00:%02d", s)
        }
    }
    var currentPlayTime: Q {
        var t = Q(0)
        for entity in scene.cutItems {
            if playCutItem != entity {
                t += entity.cut.timeLength
            } else {
                t += time
                break
            }
        }
        return t
    }
    
    func play(with event: KeyInputEvent) {
        play()
    }
    func play() {
        if isPlaying {
            isPlaying = false
            isPlaying = true
        } else {
            isPlaying = true
        }
    }
    func cut(with event: KeyInputEvent) -> CopyObject {
        stop()
        return CopyObject()
    }
    
    func zoom(with event: PinchEvent) {
    }
    func rotate(with event: RotateEvent) {
    }
    func stop() {
        if isPlaying {
            isPlaying = false
        }
        delegate?.endPlay(self)
    }
    
    func drag(with event: DragEvent) {
    }
    func scroll(with event: ScrollEvent) {
    }
}
