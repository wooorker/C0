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
import AVFoundation

final class Player: Layer, Respondable {
    static let name = Localization(english: "Player", japanese: "プレイヤー")
    
    private let drawLayer = DrawLayer()
    override init() {
        super.init()
        fillColor = .playBorder
        drawLayer.lineWidth = 0
        drawLayer.drawBlock = { [unowned self] ctx in self.draw(in: ctx) }
        append(child: drawLayer)
    }
    
    var scene = Scene() {
        didSet {
            updateChildren()
        }
    }
    
    var playCutItem = CutItem() {
        didSet {
            self.playCut = playCutItem.cut.copied
        }
    }
    var playCut = Cut()
    
    override var bounds: CGRect {
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
        playCut.rootNode.draw(scene: scene, viewType: .preview,
                              scale: 1, rotation: 0,
                              viewScale: scene.scale,
                              viewRotation: scene.viewTransform.rotation,
                              in: ctx)
    }
    
    var screenTransform = CGAffineTransform.identity
    
    var audioPlayer: AVAudioPlayer?
    
    private var playCutIndex = 0, playFrameTime = FrameTime(0), playIntSecond = 0
    private var playDrawCount = 0, playFrameRate = FPS(0), delayTolerance = 0.5
    var didSetTimeHandler: ((Beat) -> (Void))? = nil
    var didSetCutIndexHandler: ((Int) -> (Void))? = nil
    var didSetPlayFrameRateHandler: ((Int) -> (Void))? = nil
    
    private var timer = LockTimer(), oldPlayCutItem: CutItem?
    private var oldPlayTime = Beat(0), oldTimestamp = 0.0
    var isPlaying = false {
        didSet {
            if isPlaying {
                playCutItem = scene.editCutItem
                oldPlayCutItem = scene.editCutItem
                oldPlayTime = scene.editCutItem.cut.time
                oldTimestamp = CFAbsoluteTimeGetCurrent()
                let t = currentPlayTime
                playIntSecond = t.integralPart
                playCutIndex = scene.editCutItemIndex
                playFrameRate = scene.frameRate
                playFrameTime = scene.frameTime(withBeatTime: scene.time)
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
                            tolerance: 0.1 / Second(scene.frameRate),
                            handler: { [unowned self] in self.updatePlayTime() })
                drawLayer.draw()
            } else {
                timer.stop()
                audioPlayer?.stop()
                audioPlayer = nil
                drawLayer.image = nil
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
                            tolerance: 0.1 / Second(scene.frameRate),
                            handler: { [unowned self] in self.updatePlayTime() })
                audioPlayer?.play()
            }
        }
    }
    private func updatePlayTime() {
        playFrameTime += 1
        
        let newTime: Beat = {
            if let audioPlayer = audioPlayer, !scene.sound.isHidden {
                let audioFrameTime = scene.frameTime(withSecondTime: audioPlayer.currentTime)
                if abs(playFrameTime - audioFrameTime) > scene.frameRate {
                    return scene.basedBeatTime(withSecondTime: audioPlayer.currentTime)
                }
            }
            return scene.beatTime(withFrameTime: playFrameTime)
        } ()
        
        update(withTime: newTime)
    }
    private func updateBinding() {
        let t = currentPlayTime
        didSetTimeHandler?(t)
        
        if let cutItemIndex = scene.cutItems.index(of: playCutItem), playCutIndex != cutItemIndex {
            playCutIndex = cutItemIndex
            didSetCutIndexHandler?(cutItemIndex)
        }
        
        if isPlaying && !isPause {
            playDrawCount += 1
            let newTimestamp = CFAbsoluteTimeGetCurrent()
            let deltaTime = newTimestamp - oldTimestamp
            if deltaTime >= 1 {
                let newPlayFrameRate = min(scene.frameRate,
                                           Int(round(Double(playDrawCount) / deltaTime)))
                if newPlayFrameRate != playFrameRate {
                    playFrameRate = newPlayFrameRate
                    didSetPlayFrameRateHandler?(playFrameRate)
                }
                oldTimestamp = newTimestamp
                playDrawCount = 0
            }
        } else {
            playFrameRate = 0
        }
    }
    
    private func update(withTime newTime: Beat) {
        let ci = scene.cutItemIndex(withTime: newTime)
        if ci.isOver {
            playCutItem = scene.cutItems[0]
            playCut.time = 0
            audioPlayer?.currentTime = 0
            playFrameTime = 0
        } else {
            let playCutItem = scene.cutItems[ci.index]
            if playCutItem != self.playCutItem {
                self.playCutItem = playCutItem
            }
            playCut.time = ci.interTime
        }
        drawLayer.draw()
        updateBinding()
    }
    
    var currentPlaySecond: Second {
        get {
            return scene.secondTime(withBeatTime: currentPlayTime)
        }
        set {
            update(withTime: scene.basedBeatTime(withSecondTime: newValue))
            playFrameTime = scene.frameTime(withSecondTime: newValue)
            audioPlayer?.currentTime = newValue
        }
    }
    var currentPlayTime: Beat {
        get {
            var t = Beat(0)
            for cutItem in scene.cutItems {
                if playCutItem != cutItem {
                    t += cutItem.cut.duration
                } else {
                    t += playCut.time
                    break
                }
            }
            return t
        }
        set {
            update(withTime: newValue)
            playFrameTime = scene.frameTime(withBeatTime: newValue)
            audioPlayer?.currentTime = scene.secondTime(withFrameTime: playFrameTime)
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
    
    var endPlayHandler: ((Player) -> (Void))? = nil
    func stop() {
        if isPlaying {
            isPlaying = false
        }
        endPlayHandler?(self)
    }
}

final class PlayerEditor: Layer, Respondable {
    static let name = Localization(english: "Player Editor", japanese: "プレイヤーエディタ")
    
    private let timeLabelWidth = 40.0.cf, sliderWidth = 300.0.cf
    let playLabel = Label(text: Localization(english: "Play by Indicated", japanese: "指し示して再生"),
                          color: .locked)
    let slider = Slider(min: 0, max: 1,
                        description: Localization(english: "Play Time", japanese: "再生時間"))
    let timeLabel = Label(text: Localization("0:00"), color: .locked)
    let cutLabel = Label(text: Localization("No.0"), color: .locked)
    let frameRateLabel = Label(text: Localization("0 fps"), color: .locked)
    
    override init() {
        super.init()
        replace(children: [playLabel, slider, timeLabel, cutLabel, frameRateLabel])
        
        slider.disabledRegisterUndo = true
        slider.binding = { [unowned self] in
            self.time = Second($0.value)
            self.timeBinding?(self.time, $0.type)
        }
    }
    
    var timeBinding: ((Second, Action.SendType) -> (Void))? = nil
    
    override var bounds: CGRect {
        didSet {
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
        slider.backgroundLayers = [PlayerEditor.sliderLayer(with: slider.bounds,
                                                            padding: slider.padding)]
    }
    static func sliderLayer(with bounds: CGRect, padding: CGFloat) -> Layer {
        let layer = PathLayer()
        let shapeRect = CGRect(x: padding, y: bounds.midY - 1,
                               width: bounds.width - padding * 2, height: 2)
        layer.path = CGPath(rect: shapeRect, transform: nil)
        layer.fillColor = .content
        return layer
    }
    
    override var isSubIndicated: Bool {
        didSet {
            isPlayingBinding?(isSubIndicated)
            isPlaying = isSubIndicated
        }
    }
    var isPlayingBinding: ((Bool) -> (Void))? = nil
    var isPlaying = false
    
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
