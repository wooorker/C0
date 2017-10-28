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
//サイズとフレームレートの自由化、色空間の設定 (DCI-P3など)
//書き出しの種類を増やす
//時間Undo未実装

import Foundation
import QuartzCore

final class Scene: NSObject, ClassCopyData {
    static let name = Localization(english: "Scene", japanese: "シーン")
    
    var cameraFrame: CGRect {
        didSet {
            affineTransform = viewTransform.affineTransform(with: cameraFrame)
        }
    }
    var frameRate: Int, time: Int, material: Material, isShownPrevious: Bool, isShownNext: Bool, soundItem: SoundItem
    var viewTransform: ViewTransform {
        didSet {
            affineTransform = viewTransform.affineTransform(with: cameraFrame)
        }
    }
    private(set) var affineTransform: CGAffineTransform?
    
    var cutItems: [CutItem] {
        didSet {
            updateCutTimeAndTimeLength()
        }
    }
    var editCutItemIndex: Int, maxCutKeyIndex: Int, timeLength: Int
    var editCutItem: CutItem {
        return cutItems[editCutItemIndex]
    }
    func updateCutTimeAndTimeLength() {
        self.timeLength = cutItems.reduce(0) {
            $1.time = $0
            return $0 + $1.cut.timeLength
        }
    }
    
    var deepCopy: Scene {
        return Scene(
            cameraFrame: cameraFrame, frameRate: frameRate, time: time, material: material,
            isShownPrevious: isShownPrevious, isShownNext: isShownNext, soundItem: soundItem,
            cutItems: cutItems, editCutItemIndex: editCutItemIndex, maxCutKeyIndex: maxCutKeyIndex, timeLength: timeLength,
            viewTransform: viewTransform
        )
    }
    
    init(
        cameraFrame: CGRect = CGRect(x: 0, y: 0, width: 640, height: 360), frameRate: Int = 24, time: Int = 0,
        material: Material = Material(), isShownPrevious: Bool = false, isShownNext: Bool = false,
        soundItem: SoundItem = SoundItem(),
        cutItems: [CutItem] = [CutItem()], editCutItemIndex: Int = 0, maxCutKeyIndex: Int = 0, timeLength: Int = 24,
        viewTransform: ViewTransform = ViewTransform()
    ) {
        self.cameraFrame = cameraFrame
        self.frameRate = frameRate
        self.time = time
        self.material = material
        self.isShownPrevious = isShownPrevious
        self.isShownNext = isShownNext
        self.soundItem = soundItem
        self.viewTransform = viewTransform
        self.cutItems = cutItems
        self.editCutItemIndex = editCutItemIndex
        self.maxCutKeyIndex = maxCutKeyIndex
        self.timeLength = timeLength
        self.affineTransform = viewTransform.affineTransform(with: cameraFrame)
        super.init()
    }
    
    static let cameraFrameKey = "0", frameRateKey = "1", timeKey = "2", materialKey = "3", isShownPreviousKey = "4", isShownNextKey = "5", soundItemKey = "7", viewTransformKey = "6", cutItemsKey = "8", editCutItemIndexKey = "9", maxCutKeyIndexKey = "10", timeLengthKey = "11"
    init?(coder: NSCoder) {
        cameraFrame = coder.decodeRect(forKey: Scene.cameraFrameKey)
        frameRate = coder.decodeInteger(forKey: Scene.frameRateKey)
        time = coder.decodeInteger(forKey: Scene.timeKey)
        material = coder.decodeObject(forKey: Scene.materialKey) as? Material ?? Material()
        isShownPrevious = coder.decodeBool(forKey: Scene.isShownPreviousKey)
        isShownNext = coder.decodeBool(forKey: Scene.isShownNextKey)
        soundItem = coder.decodeObject(forKey: Scene.soundItemKey) as? SoundItem ?? SoundItem()
        viewTransform = coder.decodeStruct(forKey: Scene.viewTransformKey) ?? ViewTransform()
        self.cutItems = coder.decodeObject(forKey: Scene.cutItemsKey) as? [CutItem] ?? [CutItem()]
        self.editCutItemIndex = coder.decodeInteger(forKey: Scene.editCutItemIndexKey)
        self.maxCutKeyIndex = coder.decodeInteger(forKey: Scene.maxCutKeyIndexKey)
        self.timeLength = coder.decodeInteger(forKey: Scene.timeLengthKey)
        affineTransform = viewTransform.affineTransform(with: cameraFrame)
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(cameraFrame, forKey: Scene.cameraFrameKey)
        coder.encode(frameRate, forKey: Scene.frameRateKey)
        coder.encode(time, forKey: Scene.timeKey)
        coder.encode(material, forKey: Scene.materialKey)
        coder.encode(isShownPrevious, forKey: Scene.isShownPreviousKey)
        coder.encode(isShownNext, forKey: Scene.isShownNextKey)
        coder.encode(soundItem, forKey: Scene.soundItemKey)
        coder.encodeStruct(viewTransform, forKey: Scene.viewTransformKey)
        coder.encode(cutItems, forKey: Scene.cutItemsKey)
        coder.encode(editCutItemIndex, forKey: Scene.editCutItemIndexKey)
        coder.encode(maxCutKeyIndex, forKey: Scene.maxCutKeyIndexKey)
        coder.encode(timeLength, forKey: Scene.timeLengthKey)
    }
    
    func convertTime(frameTime ft: Int) -> Double {
        return ft.d/frameRate.d
    }
    func convertFrameTime(time t: Double) -> Int {
        return Int(t*frameRate.d)
    }
    var secondTime: (second: Int, frame: Int) {
        let second = time/frameRate
        return (second, time - second*frameRate)
    }
    
    func cutItemIndex(withTime time: Int) -> (index: Int, interTime: Int, isOver: Bool) {
        var t = 0
        for (i, cutItem) in cutItems.enumerated() {
            let nt = t + cutItem.cut.timeLength
            if time < nt {
                return (i, time - t, false)
            }
            t = nt
        }
        return (cutItems.count - 1, time - t, true)
    }
}
struct ViewTransform: ByteCoding {
    static let name = Localization(english: "View Tranform", japanese: "表示変形")
    var position = CGPoint(), scale = 1.0.cf, rotation = 0.0.cf, isFlippedHorizontal = false
    var isIdentity: Bool {
        return position == CGPoint() && scale == 1 && rotation == 0
    }
    func affineTransform(with bounds: CGRect) -> CGAffineTransform? {
        guard !isIdentity || isFlippedHorizontal else {
            return nil
        }
        var affine = CGAffineTransform.identity
        affine = affine.translatedBy(x: bounds.midX + position.x, y: bounds.midY + position.y)
        affine = affine.rotated(by: rotation)
        affine = affine.scaledBy(x: scale, y: scale)
        affine = affine.translatedBy(x: -bounds.midX, y: -bounds.midY)
        if isFlippedHorizontal {
            affine = affine.flippedHorizontal(by: bounds.width)
        }
        return affine
    }
}

final class SceneEditor: LayerRespondable {
    static let name = Localization(english: "Scene Editor", japanese: "シーンエディタ")
    
    struct Layout {
        static let buttonsWidth = 120.0.cf, buttonHeight = 24.0.cf, height = buttonHeight*5.cf
        static let timelineWidth = 430.0.cf, timelineButtonsWidth = 142.0.cf, materialWidth = 205.0.cf, rightWidth = 205.0.cf
        static let materialLeftWidth = 85.0.cf, easingWidth = 100.0.cf, transformWidth = 32.0.cf
        
        static let timelineFrame = CGRect(x: 0, y: 0, width: timelineWidth, height: buttonHeight*4)
        static let timelineEditFrame = CGRect(x: 0, y: buttonHeight, width: timelineWidth, height: buttonHeight*3)
        static let timelineNewCutFrame = CGRect(x: 0, y: 0, width: timelineButtonsWidth, height: buttonHeight)
        static let timelineNewKeyframeFrame = CGRect(x: timelineButtonsWidth, y: 0, width: timelineButtonsWidth + 4, height: buttonHeight)
        static let timelineNewAnimationFrame = CGRect(x: timelineButtonsWidth*2 + 4, y: 0, width: timelineButtonsWidth, height: buttonHeight)
        
        static let materialFrame =  CGRect(x: 0, y: 0, width: materialWidth, height: height)
        static let materialColorFrame = CGRect(x: materialLeftWidth, y: 0, width: height, height: height)
        static let materialTypeFrame = CGRect(x: 0, y: buttonHeight*4, width: materialLeftWidth, height: buttonHeight)
        static let materialLineWidthFrame = CGRect(x: 0, y: buttonHeight*3, width: materialLeftWidth, height: buttonHeight)
        static let materialLineStrengthFrame = CGRect(x: 0, y: buttonHeight*2, width: materialLeftWidth, height: buttonHeight)
        static let materialOpacityFrame = CGRect(x: 0, y: buttonHeight, width: materialLeftWidth, height: buttonHeight)
        static let materialLuminanceFrame = CGRect(x: 10 - 4, y: 0, width: materialLeftWidth - buttonHeight - 10, height: buttonHeight)
        static let materialBlendHueFrame = CGRect(x: materialLeftWidth - buttonHeight - 4, y: 0, width: buttonHeight, height: buttonHeight)
        static let materialAnimationFrame = CGRect(x: 0, y: 0, width: materialLeftWidth, height: buttonHeight)
        
        static let keyframeFrame = CGRect(x: 0, y: 0, width: rightWidth, height: buttonHeight*2)
        static let keyframeEasingFrame = CGRect(x: 0, y: 0, width: easingWidth, height: buttonHeight*2)
        static let keyframeInterpolationFrame = CGRect(x: easingWidth, y: buttonHeight, width: rightWidth - easingWidth, height: buttonHeight)
        static let keyframeLoopFrame = CGRect(x: easingWidth, y: 0, width: rightWidth - easingWidth, height: buttonHeight)
        
        static let viewTypeFrame = CGRect(x: 0, y: 0, width: rightWidth, height: buttonHeight*4)
        static let viewTypeIsShownPreviousFrame = CGRect(x: 0, y: buttonHeight*3, width: rightWidth, height: buttonHeight)
        static let viewTypeIsShownNextFrame = CGRect(x: 0, y: buttonHeight*2, width: rightWidth, height: buttonHeight)
        static let viewTypeIsFlippedHorizontalFrame = CGRect(x: 0, y: buttonHeight, width: rightWidth, height: buttonHeight)
        
        static let transformFrame = CGRect(x: 0, y: 0, width: timelineWidth, height: buttonHeight)
        static let tarsnformValueFrame = CGRect(x: 0, y: 0, width: transformWidth, height: buttonHeight)
        
        static let soundFrame = CGRect(x: 0, y: 0, width: rightWidth, height: buttonHeight)
    }
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager?
    
    let rendererEditor = RendererEditor(), undoEditor = UndoEditor()
    let canvas = Canvas(), timelineEditor = TimelineEditor(), speechEditor = SpeechEditor()
    let materialEditor = MaterialEditor(), cameraEditor = CameraEditor()
    let keyframeEditor = KeyframeEditor(), soundEditor = SoundEditor(), viewTypesEditor = ViewTypesEditor()
    var timeline: Timeline {
        return timelineEditor.timeline
    }
    
    static let sceneEditorKey = "sceneEditor", sceneKey = "scene", cutsKey = "cuts"
    var sceneDataModel = DataModel(key: SceneEditor.sceneKey), cutsDataModel = DataModel(key: SceneEditor.cutsKey, directoryWithChildren: [])
    var dataModel: DataModel? {
        didSet {
            guard let dataModel = dataModel else {
                return
            }
            if let sceneDataModel = dataModel.children[SceneEditor.sceneKey] {
                self.sceneDataModel = sceneDataModel
                if let scene: Scene = sceneDataModel.readObject() {
                    self.scene = scene
                }
                sceneDataModel.dataHandler = { [unowned self] in self.scene.data }
            } else {
                dataModel.insert(sceneDataModel)
            }
            
            if let cutsDataModel = dataModel.children[SceneEditor.cutsKey] {
                self.cutsDataModel = cutsDataModel
                scene.cutItems.forEach {
                    if let cutDataModel = cutsDataModel.children[$0.key] {
                        $0.cutDataModel = cutDataModel
                    }
                }
            } else {
                dataModel.insert(cutsDataModel)
            }
        }
    }
    
    var scene = Scene() {
        didSet {
            canvas.scene = scene
            timeline.scene = scene
            materialEditor.material = scene.material
            viewTypesEditor.isShownPreviousButton.selectionIndex = scene.isShownPrevious ? 1 : 0
            viewTypesEditor.isShownNextButton.selectionIndex = scene.isShownNext ? 1 : 0
            soundEditor.scene = scene
            keyframeEditor.update()
            cameraEditor.update()
            speechEditor.update()
        }
    }
    
    var nextCutKeyIndex: Int {
        if let maxKey = cutsDataModel.children.max(by:  { $0.key < $1.key }) {
            return max(scene.maxCutKeyIndex, Int(maxKey.key) ?? 0) + 1
        } else {
            return scene.maxCutKeyIndex + 1
        }
    }
    
    func insert(_ cutItem: CutItem, at index: Int) {
        let nextIndex = nextCutKeyIndex
        let key = "\(nextIndex)"
        cutItem.key = key
        cutItem.cutDataModel = DataModel(key: key)
        scene.cutItems.insert(cutItem, at: index)
        cutsDataModel.insert(cutItem.cutDataModel)
        scene.maxCutKeyIndex = nextIndex
        sceneDataModel.isWrite = true
    }
    func removeCutItem(at index: Int) {
        let cutDataModel = scene.cutItems[index].cutDataModel
        scene.cutItems.remove(at: index)
        cutsDataModel.remove(cutDataModel)
        sceneDataModel.isWrite = true
    }
    
    let layer = CALayer.interfaceLayer()
    init() {
        layer.backgroundColor = nil
        canvas.sceneEditor = self
        timelineEditor.sceneEditor = self
        cameraEditor.sceneEditor = self
        speechEditor.sceneEditor = self
        materialEditor.sceneEditor = self
        keyframeEditor.sceneEditor = self
        viewTypesEditor.sceneEditor = self
        rendererEditor.sceneEditor = self
        soundEditor.sceneEditor = self
        self.children = [
            rendererEditor, undoEditor, canvas, timelineEditor, materialEditor,
            keyframeEditor, cameraEditor, speechEditor, viewTypesEditor, soundEditor
        ]
        update(withChildren: children)
        updateChildren()
        
        canvas.scene = scene
        timeline.scene = scene
        materialEditor.material = scene.material
        viewTypesEditor.isShownPreviousButton.selectionIndex = scene.isShownPrevious ? 1 : 0
        viewTypesEditor.isShownNextButton.selectionIndex = scene.isShownNext ? 1 : 0
        soundEditor.scene = scene
        
        cutsDataModel.insert(scene.cutItems[0].cutDataModel)
        dataModel = DataModel(key: SceneEditor.sceneEditorKey, directoryWithChildren: [sceneDataModel, cutsDataModel])
        sceneDataModel.dataHandler = { [unowned self] in self.scene.data }
    }
    func updateChildren() {
        let ih = timelineEditor.frame.height + SceneEditor.Layout.buttonHeight
        let tx = materialEditor.frame.width, gx = materialEditor.frame.width + timelineEditor.frame.width
        let kx = gx, h = ih + SceneEditor.Layout.buttonHeight + canvas.frame.height
        CATransaction.disableAnimation {
            rendererEditor.frame = CGRect(
                x: 0, y: ih + canvas.frame.height,
                width: canvas.frame.width - 300, height: SceneEditor.Layout.buttonHeight
            )
            undoEditor.frame = CGRect(
                x: canvas.frame.width - 300, y: ih + canvas.frame.height,
                width: 300, height: SceneEditor.Layout.buttonHeight
            )
            canvas.frame.origin = CGPoint(x: 0, y: ih)
            materialEditor.frame.origin = CGPoint(x: 0, y: ih - materialEditor.frame.height)
            timelineEditor.frame.origin = CGPoint(x: tx, y: ih - timelineEditor.frame.height)
            keyframeEditor.frame.origin = CGPoint(x: kx, y: ih - keyframeEditor.frame.height)
            viewTypesEditor.frame.origin = CGPoint(x: gx, y: ih - keyframeEditor.frame.height - viewTypesEditor.frame.height)
            cameraEditor.frame.origin = CGPoint(x: tx, y: ih - timelineEditor.frame.height - cameraEditor.frame.height)
            soundEditor.frame.origin = CGPoint(x: kx, y: ih - timelineEditor.frame.height - cameraEditor.frame.height)
            speechEditor.frame.origin = CGPoint(x: tx, y: ih - timelineEditor.frame.height - speechEditor.frame.height - cameraEditor.frame.height)
            frame.size = CGSize(width: canvas.frame.width, height: h)
        }
    }
    
    func moveToPrevious(with event: KeyInputEvent) {
        timeline.moveToPrevious(with: event)
    }
    func moveToNext(with event: KeyInputEvent) {
        timeline.moveToNext(with: event)
    }
    func play(with event: KeyInputEvent) {
        timeline.play(with: event)
    }
    func changeToRough(with event: KeyInputEvent) {
        canvas.changeToRough(with: event)
    }
    func removeRough(with event: KeyInputEvent) {
        canvas.removeRough(with: event)
    }
    func swapRough(with event: KeyInputEvent) {
        canvas.swapRough(with: event)
    }
    func scroll(with event: ScrollEvent) {
        timeline.scroll(with: event)
    }
}

final class KeyframeEditor: LayerRespondable, EasingEditorDelegate, PulldownButtonDelegate {
    static let name = Localization(english: "Keyframe Editor", japanese: "キーフレームエディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    
    var undoManager: UndoManager?
    
    weak var sceneEditor: SceneEditor!
    
    let easingEditor = EasingEditor(
        frame: SceneEditor.Layout.keyframeEasingFrame,
        description: Localization(
            english: "Easing Editor for Keyframe",
            japanese: "キーフレーム用イージングエディタ"
        )
    )
    let interpolationButton = PulldownButton(
        frame: SceneEditor.Layout.keyframeInterpolationFrame,
        names: [
            Localization(english: "Spline", japanese: "スプライン"),
            Localization(english: "Bound", japanese: "バウンド"),
            Localization(english: "Linear", japanese: "リニア"),
            Localization(english: "Step", japanese: "補間なし")
        ],
        description: Localization(
            english: "\"Bound\": Uses \"Spline\" without interpolation on previous, Not previous and next: Use \"Linear\"",
            japanese: "バウンド: 前方側の補間をしないスプライン補間, 前後が足りない場合: リニア補間を使用"
        )
    )
    let loopButton = PulldownButton(
        frame: SceneEditor.Layout.keyframeLoopFrame,
        names: [
            Localization(english: "No Loop", japanese: "ループなし"),
            Localization(english: "Began Loop", japanese: "ループ開始"),
            Localization(english: "Ended Loop", japanese: "ループ終了")
        ],
        description: Localization(
            english: "Loop from  \"Began Loop\" keyframe to \"Ended Loop\" keyframe on \"Ended Loop\" keyframe",
            japanese: "「ループ開始」キーフレームから「ループ終了」キーフレームの間を「ループ終了」キーフレーム上でループ"
        )
    )
    let layer = CALayer.interfaceLayer()
    init() {
        layer.frame = SceneEditor.Layout.keyframeFrame
        easingEditor.delegate = self
        interpolationButton.delegate = self
        loopButton.delegate = self
        children = [easingEditor, interpolationButton, loopButton]
        update(withChildren: children)
    }
    
    var keyframe = Keyframe() {
        didSet {
            if !keyframe.equalOption(other: oldValue) {
                updateChildren()
            }
        }
    }
    func update() {
        keyframe = sceneEditor.scene.editCutItem.cut.editAnimation.editKeyframe
    }
    private func updateChildren() {
        loopButton.selectionIndex = KeyframeEditor.loopIndexWith(keyframe.loop, keyframe: keyframe)
        interpolationButton.selectionIndex = KeyframeEditor.interpolationIndexWith(keyframe.interpolation)
        easingEditor.easing = keyframe.easing
    }
    
    static func loopIndexWith(_ loop: Loop, keyframe: Keyframe) -> Int {
        let loop = keyframe.loop
        if !loop.isStart && !loop.isEnd {
            return 0
        } else if loop.isStart {
            return 1
        } else {
            return 2
        }
    }
    static func loopWith(_ index: Int) -> Loop {
        switch index {
        case 0:
            return Loop(isStart: false, isEnd: false)
        case 1:
            return Loop(isStart: true, isEnd: false)
        default:
            return Loop(isStart: false, isEnd: true)
        }
    }
    static func interpolationIndexWith(_ interpolation: Keyframe.Interpolation) -> Int {
        return Int(interpolation.rawValue)
    }
    static func interpolationWith(_ index: Int) -> Keyframe.Interpolation {
        return Keyframe.Interpolation(rawValue: Int8(index)) ?? .spline
    }
    
    private var changekeyframeTuple: (oldKeyframe: Keyframe, index: Int, animation: Animation, cutItem: CutItem)?
    static func changekeyframeTupleWith(_ cutItem: CutItem) -> (oldKeyframe: Keyframe, index: Int, animation: Animation, cutItem: CutItem) {
        let animation = cutItem.cut.editAnimation
        return (animation.editKeyframe, animation.editKeyframeIndex, animation, cutItem)
    }
    func changeEasing(_ easingEditor: EasingEditor, easing: Easing, oldEasing: Easing, type: Action.SendType) {
        switch type {
        case .begin:
            changekeyframeTuple = KeyframeEditor.changekeyframeTupleWith(sceneEditor.scene.editCutItem)
        case .sending:
            if let ckp = changekeyframeTuple {
                let keyframe = ckp.oldKeyframe.withEasing(easing)
                setKeyframe(keyframe, at: ckp.index, animation: ckp.animation)
            }
        case .end:
            if let ckp = changekeyframeTuple {
                let keyframe = ckp.oldKeyframe.withEasing(easing)
                setEasing(keyframe, oldKeyframe: ckp.oldKeyframe, at: ckp.index, animation: ckp.animation, cutItem: ckp.cutItem)
                changekeyframeTuple = nil
            }
        }
    }
    func changeValue(_ pulldownButton: PulldownButton, index: Int, oldIndex: Int, type: Action.SendType) {
        switch pulldownButton {
        case interpolationButton:
            switch type {
            case .begin:
                changekeyframeTuple = KeyframeEditor.changekeyframeTupleWith(sceneEditor.scene.editCutItem)
            case .sending:
                if let ckp = changekeyframeTuple {
                    let keyframe = ckp.oldKeyframe.withInterpolation(KeyframeEditor.interpolationWith(index))
                    setKeyframe(keyframe, at: ckp.index, animation: ckp.animation)
                }
            case .end:
                if let ckp = changekeyframeTuple {
                    let keyframe = ckp.oldKeyframe.withInterpolation(KeyframeEditor.interpolationWith(index))
                    setInterpolation(keyframe, oldKeyframe: ckp.oldKeyframe, at: ckp.index, animation: ckp.animation, cutItem: ckp.cutItem)
                    changekeyframeTuple = nil
                }
            }
        case loopButton:
            switch type {
            case .begin:
                changekeyframeTuple = KeyframeEditor.changekeyframeTupleWith(sceneEditor.scene.editCutItem)
            case .sending:
                if let ckp = changekeyframeTuple {
                    let keyframe = ckp.oldKeyframe.withLoop(KeyframeEditor.loopWith(index))
                    setKeyframe(keyframe, at: ckp.index, animation: ckp.animation)
                }
            case .end:
                if let ckp = changekeyframeTuple {
                    let keyframe = ckp.oldKeyframe.withLoop(KeyframeEditor.loopWith(index))
                    setLoop(keyframe, oldKeyframe: ckp.oldKeyframe, at: ckp.index, animation: ckp.animation, cutItem: ckp.cutItem)
                    changekeyframeTuple = nil
                }
            }
        default:
            break
        }
    }
    private func setEasing(_ keyframe: Keyframe, oldKeyframe: Keyframe, at i: Int, animation: Animation, cutItem: CutItem) {
        undoManager?.registerUndo(withTarget: self) {
            $0.setEasing(oldKeyframe, oldKeyframe: keyframe, at: i, animation: animation, cutItem: cutItem)
        }
        setKeyframe(keyframe, at: i, animation: animation)
        easingEditor.easing = keyframe.easing
        cutItem.cutDataModel.isWrite = true
    }
    private func setInterpolation(_ keyframe: Keyframe, oldKeyframe: Keyframe, at i: Int, animation: Animation, cutItem: CutItem) {
        undoManager?.registerUndo(withTarget: self) {
            $0.setInterpolation(oldKeyframe, oldKeyframe: keyframe, at: i, animation: animation, cutItem: cutItem)
        }
        setKeyframe(keyframe, at: i, animation: animation)
        interpolationButton.selectionIndex = KeyframeEditor.interpolationIndexWith(keyframe.interpolation)
        cutItem.cutDataModel.isWrite = true
    }
    private func setLoop(_ keyframe: Keyframe, oldKeyframe: Keyframe, at i: Int, animation: Animation, cutItem: CutItem) {
        undoManager?.registerUndo(withTarget: self) {
            $0.setLoop(oldKeyframe, oldKeyframe: keyframe, at: i, animation: animation, cutItem: cutItem)
        }
        setKeyframe(keyframe, at: i, animation: animation)
        loopButton.selectionIndex = KeyframeEditor.loopIndexWith(keyframe.loop, keyframe: keyframe)
        cutItem.cutDataModel.isWrite = true
    }
    func setKeyframe(_ keyframe: Keyframe, at i: Int, animation: Animation) {
        animation.replaceKeyframe(keyframe, at: i)
        update()
        sceneEditor.timeline.setNeedsDisplay()
        sceneEditor.canvas.setNeedsDisplay()
    }
}

final class ViewTypesEditor: LayerRespondable, PulldownButtonDelegate {
    static let name = Localization(english: "View Types Editor", japanese: "表示タイプエディタ")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager?
    
    weak var sceneEditor: SceneEditor!
    let isShownPreviousButton = PulldownButton(
        frame: SceneEditor.Layout.viewTypeIsShownPreviousFrame, isEnabledCation: true,
        names: [
            Localization(english: "Hidden Previous", japanese: "前の表示なし"),
            Localization(english: "Shown Previous", japanese: "前の表示あり")
        ],
        description: Localization(english: "Hide/Show line drawing of previous keyframe", japanese: "前のキーフレームの表示切り替え")
    )
    let isShownNextButton = PulldownButton(
        frame: SceneEditor.Layout.viewTypeIsShownNextFrame, isEnabledCation: true,
        names: [
            Localization(english: "Hidden Next", japanese: "次の表示なし"),
            Localization(english: "Shown Next", japanese: "次の表示あり")
        ],
        description: Localization(english: "Hide/Show line drawing of next keyframe", japanese: "次のキーフレームの表示切り替え")
    )
    let layer = CALayer.interfaceLayer()
    init() {
        layer.frame = SceneEditor.Layout.viewTypeFrame
        layer.backgroundColor = nil
        isShownPreviousButton.delegate = self
        isShownNextButton.delegate = self
        children = [isShownPreviousButton, isShownNextButton]
        update(withChildren: children)
    }
    
    func changeValue(_ pulldownButton: PulldownButton, index: Int, oldIndex: Int, type: Action.SendType) {
        switch pulldownButton {
        case isShownPreviousButton:
            switch type {
            case .begin:
                break
            case .sending:
                sceneEditor.canvas.isShownPrevious = index == 1
            case .end:
                if index != oldIndex {
                    setIsShownPrevious(index == 1, oldIsShownPrevious: oldIndex == 1)
                } else {
                    sceneEditor.canvas.isShownPrevious = index == 1
                }
            }
        case isShownNextButton:
            switch type {
            case .begin:
                break
            case .sending:
                sceneEditor.canvas.isShownNext = index == 1
            case .end:
                if index != oldIndex {
                    setIsShownNext(index == 1, oldIsShownNext: oldIndex == 1)
                } else {
                    sceneEditor.canvas.isShownNext = index == 1
                }
            }
        default:
            break
        }
    }
    private func setIsShownPrevious(_ isShownPrevious: Bool, oldIsShownPrevious: Bool) {
        undoManager?.registerUndo(withTarget: self) { $0.setIsShownPrevious(oldIsShownPrevious, oldIsShownPrevious: isShownPrevious) }
        isShownPreviousButton.selectionIndex = isShownPrevious ? 1 : 0
        sceneEditor.canvas.isShownPrevious = isShownPrevious
        sceneEditor.sceneDataModel.isWrite = true
    }
    private func setIsShownNext(_ isShownNext: Bool, oldIsShownNext: Bool) {
        undoManager?.registerUndo(withTarget: self) { $0.setIsShownNext(oldIsShownNext, oldIsShownNext: isShownNext) }
        isShownNextButton.selectionIndex = isShownNext ? 1 : 0
        sceneEditor.canvas.isShownNext = isShownNext
        sceneEditor.sceneDataModel.isWrite = true
    }
    private func setIsFlippedHorizontal(_ isFlippedHorizontal: Bool, oldIsFlippedHorizontal: Bool) {
        undoManager?.registerUndo(withTarget: self) { $0.setIsFlippedHorizontal(oldIsFlippedHorizontal, oldIsFlippedHorizontal: isFlippedHorizontal) }
        sceneEditor.canvas.viewTransform.isFlippedHorizontal = isFlippedHorizontal
        sceneEditor.sceneDataModel.isWrite = true
    }
}

final class CameraEditor: LayerRespondable, SliderDelegate, Localizable {
    static let name = Localization(english: "Camera Editor", japanese: "カメラエディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    
    var undoManager: UndoManager?
    
    var locale = Locale.current {
        didSet {
            CATransaction.disableAnimation {
                if let children = children as? [LayerRespondable] {
                    CameraEditor.centered(children, in: layer.bounds)
                }
            }
        }
    }
    
    weak var sceneEditor: SceneEditor!
    private let xLabel = Label(
        string: "X:", font: Font.small, color: Color.smallFont,
        paddingWidth: 2, height: SceneEditor.Layout.buttonHeight
    )
    private let yLabel = Label(
        string: "Y:", font: Font.small, color: Color.smallFont,
        paddingWidth: 2, height: SceneEditor.Layout.buttonHeight
    )
    private let zLabel = Label(
        string: "Z:", font: Font.small, color: Color.smallFont,
        paddingWidth: 2, height: SceneEditor.Layout.buttonHeight
    )
    private let thetaLabel = Label(
        string: "θ:", font: Font.small, color: Color.smallFont,
        paddingWidth: 2, height: SceneEditor.Layout.buttonHeight
    )
    private let wiggleXLabel = Label(
        text: Localization(english: "Wiggle X:", japanese: "振動 X:"), font: Font.small, color: Color.smallFont,
        paddingWidth: 2, height: SceneEditor.Layout.buttonHeight
    )
    private let wiggleYLabel = Label(
        text: Localization(english: "Wiggle Y:", japanese: "振動 Y:"), font: Font.small, color: Color.smallFont,
        paddingWidth: 2, height: SceneEditor.Layout.buttonHeight
    )
    private let xSlider = Slider(
        frame: SceneEditor.Layout.tarsnformValueFrame, unit: "", isNumberEdit: true, min: -10000, max: 10000, valueInterval: 0.01,
        description: Localization(english: "Camera position X", japanese: "カメラの位置X")
    )
    private let ySlider = Slider(
        frame: SceneEditor.Layout.tarsnformValueFrame, unit: "", isNumberEdit: true, min: -10000, max: 10000, valueInterval: 0.01,
        description: Localization(english: "Camera position Y", japanese: "カメラの位置Y")
    )
    private let zSlider = Slider(
        frame: SceneEditor.Layout.tarsnformValueFrame, unit: "", isNumberEdit: true, min: -20, max: 20, valueInterval: 0.01,
        description: Localization(english: "Camera position Z", japanese: "カメラの位置Z")
    )
    private let thetaSlider = Slider(
        frame: SceneEditor.Layout.tarsnformValueFrame, unit: "°", isNumberEdit: true, min: -10000, max: 10000, valueInterval: 0.5,
        description: Localization(english: "Camera angle", japanese: "カメラの角度")
    )
    private let wiggleXSlider = Slider(
        frame: SceneEditor.Layout.tarsnformValueFrame, unit: "", isNumberEdit: true, min: 0, max: 1000, valueInterval: 0.01,
        description: Localization(english: "Camera wiggle X", japanese: "カメラの振動X")
    )
    private let wiggleYSlider = Slider(
        frame: SceneEditor.Layout.tarsnformValueFrame, unit: "", isNumberEdit: true, min: 0, max: 1000, valueInterval: 0.01,
        description: Localization(english: "Camera wiggle Y", japanese: "カメラの振動Y")
    )
    let layer = CALayer.interfaceLayer()
    init() {
        layer.frame = SceneEditor.Layout.transformFrame
        xSlider.delegate = self
        ySlider.delegate = self
        zSlider.delegate = self
        thetaSlider.delegate = self
        wiggleXSlider.delegate = self
        wiggleYSlider.delegate = self
        let children: [LayerRespondable] = [
            xLabel, xSlider, yLabel, ySlider, zLabel, zSlider, thetaLabel, thetaSlider,
            wiggleXLabel, wiggleXSlider, wiggleYLabel, wiggleYSlider
        ]
        self.children = children
        update(withChildren: children)
        CameraEditor.centered(children, in: layer.bounds)
    }
    private static func centered(_ responders: [LayerRespondable], in bounds: CGRect, paddingWidth: CGFloat = 4) {
        let w = responders.reduce(-paddingWidth) { $0 +  $1.frame.width + paddingWidth }
        _ = responders.reduce(floor((bounds.width - w)/2)) { x, responder in
            responder.frame.origin = CGPoint(x: x, y: 0)
            return x + responder.frame.width + paddingWidth
        }
    }
    
    var transform = Transform() {
        didSet {
            if transform != oldValue {
                updateChildren()
            }
        }
    }
    func update() {
        transform = sceneEditor.scene.editCutItem.cut.editAnimation.transformItem?.transform ?? Transform()
    }
    private func updateChildren() {
        let b = sceneEditor.scene.cameraFrame
        xSlider.value = transform.position.x/b.width
        ySlider.value = transform.position.y/b.height
        zSlider.value = transform.scale.width
        thetaSlider.value = transform.rotation*180/(.pi)
        wiggleXSlider.value = 10*transform.wiggle.maxSize.width/b.width
        wiggleYSlider.value = 10*transform.wiggle.maxSize.height/b.height
    }
    
    func copy(with event: KeyInputEvent) -> CopyObject {
        return CopyObject(objects: [transform])
    }
    func paste(_ copyObject: CopyObject, with event: KeyInputEvent) {
        for object in copyObject.objects {
            if let transform = object as? Transform {
                let cutItem = sceneEditor.scene.editCutItem
                let animation = cutItem.cut.editAnimation
                if cutItem.cut.isInterpolatedKeyframe(with: animation) {
                    sceneEditor.timeline.splitKeyframe(with: animation)
                }
                setTransform(transform, at: animation.editKeyframeIndex, in: animation, cutItem)
                return
            }
        }
    }
    
    private var oldTransform = Transform(), keyIndex = 0, isMadeTransformItem = false
    private weak var oldTransformItem: TransformItem?, animation: Animation?, cutItem: CutItem?
    func changeValue(_ slider: Slider, value: CGFloat, oldValue: CGFloat, type: Action.SendType) {
        switch type {
        case .begin:
            undoManager?.beginUndoGrouping()
            let cutItem = sceneEditor.scene.editCutItem
            let animation = cutItem.cut.editAnimation
            if cutItem.cut.isInterpolatedKeyframe(with: animation) {
                sceneEditor.timeline.splitKeyframe(with: animation)
            }
            let t = transformWith(value: value, slider: slider, oldTransform: transform)
            oldTransformItem = animation.transformItem
            if let transformItem = animation.transformItem {
                oldTransform = transformItem.transform
                isMadeTransformItem = false
            } else {
                let transformItem = TransformItem.empty(with: animation)
                setTransformItem(transformItem, in: animation, cutItem)
                oldTransform = transformItem.transform
                isMadeTransformItem = true
            }
            self.animation = animation
            self.cutItem = cutItem
            keyIndex = animation.editKeyframeIndex
            setTransform(t, at: keyIndex, in: animation, cutItem)
        case .sending:
            if let animation = animation, let cutItem = cutItem {
                let t = transformWith(value: value, slider: slider, oldTransform: transform)
                setTransform(t, at: keyIndex, in: animation, cutItem)
            }
        case .end:
            if let animation = animation, let cutItem = cutItem {
                let t = transformWith(value: value, slider: slider, oldTransform: transform)
                setTransform(t, at: keyIndex, in: animation, cutItem)
                if let transformItem = animation.transformItem {
                    if transformItem.isEmpty {
                        if isMadeTransformItem {
                            setTransformItem(nil, in: animation, cutItem)
                        } else {
                            setTransformItem(nil, oldTransformItem: oldTransformItem, in: animation, cutItem)
                        }
                    } else {
                        if isMadeTransformItem {
                            setTransformItem(transformItem, oldTransformItem: oldTransformItem, in: animation, cutItem)
                        }
                        if value != oldValue {
                            setTransform(t, oldTransform: oldTransform, at: keyIndex, in: animation, cutItem)
                        } else {
                            setTransform(oldTransform, at: keyIndex, in: animation, cutItem)
                        }
                    }
                }
            }
            undoManager?.endUndoGrouping()
        }
    }
    private func transformWith(value: CGFloat, slider: Slider, oldTransform t: Transform) -> Transform {
        let b = sceneEditor.scene.cameraFrame
        switch slider {
        case xSlider:
            return t.withPosition(CGPoint(x: value*b.width, y: t.position.y))
        case ySlider:
            return t.withPosition(CGPoint(x: t.position.x, y: value*b.height))
        case zSlider:
            return t.withScale(value)
        case thetaSlider:
            return t.withRotation(value*(.pi/180))
        case wiggleXSlider:
            return t.withWiggle(t.wiggle.withMaxSize(CGSize(width: value*b.width/10, height: t.wiggle.maxSize.height)))
        case wiggleYSlider:
            return t.withWiggle(t.wiggle.withMaxSize(CGSize(width: t.wiggle.maxSize.width, height: value*b.height/10)))
        default:
            return t
        }
    }
    private func setTransformItem(_ transformItem: TransformItem?, in animation: Animation, _ cutItem: CutItem) {
        animation.transformItem = transformItem
        sceneEditor.timeline.setNeedsDisplay()
    }
    private func setTransform(_ transform: Transform, at index: Int, in animation: Animation, _ cutItem: CutItem) {
        animation.transformItem?.replaceTransform(transform, at: index)
        cutItem.cut.updateCamera()
        if cutItem === sceneEditor.canvas.cutItem {
            sceneEditor.canvas.updateViewAffineTransform()
        }
        self.transform = transform
    }
    private func setTransformItem(_ transformItem: TransformItem?, oldTransformItem: TransformItem?, in animation: Animation, _ cutItem: CutItem) {
        undoManager?.registerUndo(withTarget: self) {
            $0.setTransformItem(oldTransformItem, oldTransformItem: transformItem, in: animation, cutItem)
        }
        setTransformItem(transformItem, in: animation, cutItem)
        cutItem.cutDataModel.isWrite = true
    }
    private func setTransform(_ transform: Transform, oldTransform: Transform, at i: Int, in animation: Animation, _ cutItem: CutItem) {
        undoManager?.registerUndo(withTarget: self) {
            $0.setTransform(oldTransform, oldTransform: transform, at: i, in: animation, cutItem)
        }
        setTransform(transform, at: i, in: animation, cutItem)
        cutItem.cutDataModel.isWrite = true
    }
}

final class SoundEditor: LayerRespondable, Localizable {
    static let name = Localization(english: "Sound Editor", japanese: "サウンドエディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    
    var undoManager: UndoManager?
    
    var locale = Locale.current {
        didSet {
            updateSoundText(with: scene.soundItem, with: locale)
        }
    }
    
    var sceneEditor: SceneEditor!
    var scene = Scene() {
        didSet {
            updateSoundText(with: scene.soundItem, with: Locale.current)
        }
    }
    var textLine: TextLine {
        didSet {
            layer.setNeedsDisplay()
        }
    }
    var layer: CALayer {
        return drawLayer
    }
    let drawLayer = DrawLayer(fillColor: Color.subBackground)
    
    init() {
        textLine = TextLine(string: "", font: Font.small, color: Color.smallFont, isVerticalCenter: true)
        drawLayer.drawBlock = { [unowned self] ctx in
            if self.scene.soundItem.isHidden {
                ctx.setAlpha(0.25)
            }
            self.textLine.draw(in: self.bounds, in: ctx)
        }
        layer.frame = SceneEditor.Layout.soundFrame
        updateSoundText(with: scene.soundItem, with: Locale.current)
    }
    
    func delete(with event: KeyInputEvent) {
        if scene.soundItem.url != nil {
            setURL(nil, name: "")
        }
    }
    func copy(with event: KeyInputEvent) -> CopyObject {
        guard let url = scene.soundItem.url else {
            return CopyObject()
        }
        return CopyObject(objects: [url])
    }
    func paste(_ copyObject: CopyObject, with event: KeyInputEvent) {
        for object in copyObject.objects {
            if let url = object as? URL, url.isConforms(uti: kUTTypeAudio as String) {
                setURL(url, name: url.lastPathComponent)
            }
        }
    }
    func setURL(_ url: URL?, name: String) {
        undoManager?.registerUndo(withTarget: self) { [ou = scene.soundItem.url, on = scene.soundItem.name] in
            $0.setURL(ou, name: on)
        }
        if url == nil && sceneEditor.canvas.player.audioPlayer?.isPlaying ?? false {
            sceneEditor.canvas.player.audioPlayer?.stop()
        }
        scene.soundItem.url = url
        scene.soundItem.name = name
        updateSoundText(with: scene.soundItem, with: Locale.current)
        sceneEditor.sceneDataModel.isWrite = true
    }
    func updateSoundText(with soundItem: SoundItem, with locale: Locale) {
        if soundItem.url != nil {
            textLine.string = "♫ \(soundItem.name)"
        } else {
            textLine.string = Localization(english: "No Sound", japanese: "サウンドなし").string(with: locale)
        }
        layer.setNeedsDisplay()
    }
    
    func show(with event: KeyInputEvent) {
        if scene.soundItem.isHidden {
            setIsHidden(false)
        }
    }
    func hide(with event: KeyInputEvent) {
        if !scene.soundItem.isHidden {
            setIsHidden(true)
        }
    }
    func setIsHidden(_ isHidden: Bool) {
        undoManager?.registerUndo(withTarget: self) { [oh = scene.soundItem.isHidden] in $0.setIsHidden(oh) }
        scene.soundItem.isHidden = isHidden
        sceneEditor.canvas.player.audioPlayer?.volume = isHidden ? 0 : 1
        sceneEditor.sceneDataModel.isWrite = true
        layer.setNeedsDisplay()
    }
}

final class SpeechEditor: LayerRespondable, TextEditorDelegate {
    static let name = Localization(english: "Speech Editor", japanese: "字幕エディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    
    var undoManager: UndoManager?
    
    weak var sceneEditor: SceneEditor!
    var text = Text() {
        didSet {
            if text !== oldValue {
                textEditor.string = text.string
            }
        }
    }
    private let textEditor = TextEditor()
    let layer = CALayer.interfaceLayer()
    init() {
        layer.frame = CGRect()
        textEditor.delegate = self
        self.children = [textEditor]
        update(withChildren: children)
    }
    func update() {
        self.text = sceneEditor.scene.editCutItem.cut.editAnimation.textItem?.text ?? Text()
    }
    
    private var textPack: (oldText: Text, textItem: TextItem)?
    func changeText(textEditor: TextEditor, string: String, oldString: String, type: Action.SendType) {
    }
    private func _setTextItem(_ textItem: TextItem?, oldTextItem: TextItem?, in animation: Animation, _ cutItem: CutItem) {
        undoManager?.registerUndo(withTarget: self) { $0._setTextItem(oldTextItem, oldTextItem: textItem, in: animation, cutItem) }
        animation.textItem = textItem
        cutItem.cutDataModel.isWrite = true
        sceneEditor.timeline.setNeedsDisplay()
    }
    private func _setText(_ text: Text, oldText: Text, at i: Int, in animation: Animation, _ cutItem: CutItem) {
        undoManager?.registerUndo(withTarget: self) { $0._setText(oldText, oldText: text, at: i, in: animation, cutItem) }
        animation.textItem?.replaceText(text, at: i)
        animation.textItem?.text = text
        sceneEditor.canvas.updateViewAffineTransform()
        sceneEditor.scene.editCutItem.cutDataModel.isWrite = true
        self.text = text
    }
}
