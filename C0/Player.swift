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
import AVFoundation

final class Player: LayerRespondable {
    static let name = Localization(english: "Player", japanese: "プレイヤー")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: [])
        }
    }
    
    let layer = CALayer.interface(), drawLayer = DrawLayer()
    var playCutItem: CutItem? {
        didSet {
            if let playCutItem = playCutItem {
                self.cut = playCutItem.cut.copied
            }
        }
    }
    var cut = Cut()
    var time: Beat {
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
        let paddingOrigin = CGPoint(x: (bounds.width - scene.frame.size.width) / 2,
                                    y: (bounds.height - scene.frame.size.height) / 2)
        drawLayer.frame = CGRect(origin: paddingOrigin, size: scene.frame.size)
        screenTransform = CGAffineTransform(translationX: drawLayer.bounds.midX,
                                            y: drawLayer.bounds.midY)
    }
    func draw(in ctx: CGContext) {
        ctx.concatenate(screenTransform)
        cut.rootNode.draw(scene: scene, viewType: .preview,
                          scale: 1, rotation: 0,
                          viewScale: scene.scale,
                          viewRotation: scene.viewTransform.rotation,
                          in: ctx)
    }
    
    init() {
        layer.backgroundColor = Color.playBorder.cgColor
        drawLayer.borderWidth = 0
        drawLayer.drawBlock = { [unowned self] ctx in self.draw(in: ctx) }
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
        }
    }
    
    private var playDrawCount = 0, playCutIndex = 0, playSecond = 0
    private var playFrameRate = FPS(0), delayTolerance = 0.5
    var didSetTimeHandler: ((Beat) -> (Void))? = nil
    var didSetCutIndexHandler: ((Int) -> (Void))? = nil
    var didSetPlayFrameRateHandler: ((Int) -> (Void))? = nil
    
    private var timer = LockTimer(), oldPlayCutItem: CutItem?
    private var oldPlayTime = Beat(0), oldTimestamp = 0.0
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
                if let url = scene.sound.url {
                    do {
                        try audioPlayer = AVAudioPlayer(contentsOf: url)
                        audioPlayer?.volume = Float(scene.sound.volume)
                    } catch {
                    }
                }
                audioPlayer?.currentTime = scene.secondTime(withBeatTime: t)
                audioPlayer?.play()
                timer.begin(interval: 1 / Second(scene.frameRate),
                            tolerance: 0.1 / Second(scene.frameRate)) { [unowned self] in
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
    var isPause = false {
        didSet {
            if isPause {
                timer.stop()
                audioPlayer?.pause()
            } else {
                timer.begin(interval: 1 / Second(scene.frameRate),
                            tolerance: 0.1 / Second(scene.frameRate)) { [unowned self] in
                                self.updatePlayTime()
                }
                audioPlayer?.play()
            }
        }
    }
    var beatFrameTime: Beat {
        return scene.beatTime(withFrameTime: 1)
    }
    private func updatePlayTime() {
        if let playCutItem = playCutItem {
            var updated = false
            if let audioPlayer = audioPlayer, !scene.sound.isHidden {
                let t = scene.beatTime(withSecondTime: audioPlayer.currentTime)
                let pt = currentPlayTime + beatFrameTime
                if abs(pt - t) > beatFrameTime {
                    let viewIndex = scene.cutItemIndex(withTime: t)
                    if viewIndex.isOver {
                        self.playCutItem = scene.cutItems[0]
                        self.time = 0
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
                let nextTime = time + beatFrameTime
                if nextTime < playCutItem.cut.duration {
                    time = nextTime
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
            
            updateBinding()
        }
    }
    func updateBinding() {
        let t = currentPlayTime
        didSetTimeHandler?(t)
        
        if let playCutItem = playCutItem, let cutItemIndex = scene.cutItems.index(of: playCutItem),
            playCutIndex != cutItemIndex {
            
            playCutIndex = cutItemIndex
            didSetCutIndexHandler?(cutItemIndex)
        }
        
        playDrawCount += 1
        let newTimestamp = CFAbsoluteTimeGetCurrent()
        let deltaTime = newTimestamp - oldTimestamp
        if deltaTime >= 1 {
            let newPlayFrameRate = min(scene.frameRate, Int(round(Double(playDrawCount) / deltaTime)))
            if newPlayFrameRate != playFrameRate {
                playFrameRate = newPlayFrameRate
                didSetPlayFrameRateHandler?(playFrameRate)
            }
            oldTimestamp = newTimestamp
            playDrawCount = 0
        }
    }
    
    var currentPlayTime: Beat {
        get {
            var t = Beat(0)
            for entity in scene.cutItems {
                if playCutItem != entity {
                    t += entity.cut.duration
                } else {
                    t += time
                    break
                }
            }
            return t
        }
        set {
            let viewIndex = scene.cutItemIndex(withTime: newValue)
            let cutItem = scene.cutItems[viewIndex.index]
            if cutItem != playCutItem {
                self.playCutItem = cutItem
            }
            time = viewIndex.interTime
            
            audioPlayer?.currentTime = scene.secondTime(withBeatTime: newValue)
            
            drawLayer.setNeedsDisplay()
            
            updateBinding()
        }
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
    
    func zoom(with event: PinchEvent) {
    }
    func rotate(with event: RotateEvent) {
    }
    var endPlayHandler: ((Player) -> (Void))? = nil
    func stop() {
        if isPlaying {
            isPlaying = false
        }
        endPlayHandler?(self)
    }
    
    func drag(with event: DragEvent) {
    }
    func scroll(with event: ScrollEvent) {
    }
}

final class PlayerEditor: LayerRespondable {
    static let name = Localization(english: "Player Editor", japanese: "プレイヤーエディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: [])
        }
    }
    
    var contentsScale: CGFloat {
        get {
            return layer.contentsScale
        } set {
            layer.contentsScale = newValue
            timeLabel.contentsScale = newValue
            cutLabel.contentsScale = newValue
            frameRateLabel.contentsScale = newValue
        }
    }
    
    private let timeLabelWidth = 40.0.cf, sliderWidth = 300.0.cf
    let playLabel = Label(
        text: Localization(english: "Play by Indication", japanese: "指し示して再生"), color: .locked
    )
    let slider = Slider(
        min: 0, max: 1,
        description: Localization(english: "Play Time", japanese: "再生時間")
    )
    let timeLabel = Label(text: Localization("0:00"), color: .locked)
    let cutLabel = Label(text: Localization("No.0"), color: .locked)
    let frameRateLabel = Label(text: Localization("0 fps"), color: .locked)
    
    let layer = CALayer.interface()
    init() {
//        self.children = [playLabel]
        children = [playLabel, slider, timeLabel, cutLabel, frameRateLabel]
        update(withChildren: children, oldChildren: [])
        updateChildren()
        slider.disabledRegisterUndo = true
        slider.setValueHandler = { [unowned self] in
            self.time = Second($0.value)
            self.timeBinding?(self.time, $0.type)
        }
    }
    
    var timeBinding: ((Second, Action.SendType) -> (Void))? = nil
    
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            layer.frame = newValue
            updateChildren()
        }
    }
    func updateChildren() {
        let padding = Layout.basicPadding, height = Layout.basicHeight
        let sliderY = round((frame.height - height) / 2)
        let labelHeight = Layout.basicHeight - padding * 2
        let labelY = round((frame.height - labelHeight) / 2)
        playLabel.frame.origin = CGPoint(x: Layout.basicPadding, y: labelY)
        
        var x = bounds.width - timeLabelWidth - padding
        frameRateLabel.frame.origin = CGPoint(x: x, y: labelY)
        x -= timeLabelWidth
        cutLabel.frame.origin = CGPoint(x: x, y: labelY)
        x -= timeLabelWidth
        timeLabel.frame.origin = CGPoint(x: x, y: labelY)
        x -= padding
        
        let sliderWidth = x - playLabel.frame.maxX - padding
        slider.frame = CGRect(x: playLabel.frame.maxX + padding, y: sliderY,
                              width: sliderWidth, height: height)
        let sliderLayer = PlayerEditor.sliderLayer(with: slider.bounds,
                                                   viewPadding: slider.viewPadding)
        slider.layer.sublayers = [sliderLayer, slider.knobLayer]
    }
    static func sliderLayer(with bounds: CGRect, viewPadding: CGFloat) -> CALayer {
        let shapeLayer = CAShapeLayer()
        let shapeRect = CGRect(x: viewPadding, y: bounds.midY - 1,
                               width: bounds.width - viewPadding * 2, height: 2)
        shapeLayer.path = CGPath(rect: shapeRect, transform: nil)
        shapeLayer.fillColor = Color.content.cgColor
        return shapeLayer
    }
    
    var isSubIndication = false {
        didSet {
            isPlayingBinding?(isSubIndication)
            isPlaying = isSubIndication
        }
    }
    var isPlayingBinding: ((Bool) -> (Void))? = nil
    var isPlaying = false {
        didSet {
//            if isPlaying {
//                children = [playLabel, slider, timeLabel, cutLabel, frameRateLabel]
//            } else {
//                children = [playLabel]
//            }
//            updateChildren()
        }
    }
    
    var time = Second(0.0) {
        didSet {
            slider.value = CGFloat(time)
            second = Int(time)
        }
    }
    var maxTime = Second(1.0) {
        didSet {
            slider.maxValue = Double(maxTime).cf
        }
    }
    private(set) var second = 0 {
        didSet {
            guard second != oldValue else {
                return
            }
            timeLabel.string = minuteSecondString(withSecond: second, frameRate: frameRate)
        }
    }
    func minuteSecondString(withSecond s: Int, frameRate: FPS) -> String {
        if s >= 60 {
            let minute = s / 60
            let second = s - minute * 60
            return String(format: "%d:%02d", minute, second)
        } else {
            return String(format: "0:%02d", s)
        }
    }
    var cutIndex = 0 {
        didSet {
            cutLabel.string = "No.\(cutIndex)"
        }
    }
    var playFrameRate = 1 {
        didSet {
            frameRateLabel.string = "\(playFrameRate) fps"
            frameRateLabel.textFrame.color = playFrameRate < frameRate ? .warning : .locked
        }
    }
    var frameRate = 1 {
        didSet {
            playFrameRate = frameRate
            frameRateLabel.string = "\(playFrameRate) fps"
            frameRateLabel.textFrame.color = playFrameRate < frameRate ? .warning : .locked
        }
    }
}
