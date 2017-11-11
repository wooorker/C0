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
//時間Undo未実装

import Foundation
import QuartzCore

typealias BPM = Int
typealias FPS = Int
typealias Second = Double

final class Scene: NSObject, ClassCopyData {
    static let name = Localization(english: "Scene", japanese: "シーン")
    
    var frame: CGRect, frameRate: FPS, baseNoteValue: Q, tempo: BPM
    var colorSpace: ColorSpace {
        didSet {
            self.materials = materials.map { $0.withColor($0.color.with(colorSpace: colorSpace)) }
        }
    }
    var editMaterial: Material, materials: [Material]
    var isShownPrevious: Bool, isShownNext: Bool
    var soundItem: SoundItem
    
    var viewTransform: Transform {
        didSet {
            self.scale = viewTransform.scale.x
            self.reciprocalViewScale = 1/viewTransform.scale.x
        }
    }
    private(set) var scale: CGFloat, reciprocalViewScale: CGFloat
    var reciprocalScale: CGFloat {
        return reciprocalViewScale / editCutItem.cut.editNode.worldScale
    }
    
    var cutItems: [CutItem] {
        didSet {
            updateCutTimeAndTimeLength()
        }
    }
    var editCutItemIndex: Int
    
    var time: Q
    private(set) var timeLength: Q
    func updateCutTimeAndTimeLength() {
        self.timeLength = cutItems.reduce(Q(0)) {
            $1.time = $0
            return $0 + $1.cut.timeLength
        }
    }
    fileprivate var maxCutKeyIndex: Int
    
    init(
        frame: CGRect = CGRect(x: -320, y: -180, width: 640, height: 360), frameRate: FPS = 24,
        baseNoteValue: Q = Q(1, 24), tempo: BPM = 60,
        colorSpace: ColorSpace = .sRGB,
        editMaterial: Material = Material(), materials: [Material] = [],
        isShownPrevious: Bool = false, isShownNext: Bool = false,
        soundItem: SoundItem = SoundItem(),
        cutItems: [CutItem] = [CutItem()], editCutItemIndex: Int = 0, maxCutKeyIndex: Int = 0,
        time: Q = 0, timeLength: Q = 1,
        viewTransform: Transform = Transform()
    ) {
        self.frame = frame
        self.frameRate = frameRate
        self.baseNoteValue = baseNoteValue
        self.tempo = tempo
        self.colorSpace = colorSpace
        self.editMaterial = editMaterial
        self.materials = materials
        self.isShownPrevious = isShownPrevious
        self.isShownNext = isShownNext
        self.soundItem = soundItem
        self.viewTransform = viewTransform
        self.cutItems = cutItems
        self.editCutItemIndex = editCutItemIndex
        self.maxCutKeyIndex = maxCutKeyIndex
        self.time = time
        self.timeLength = timeLength
        self.scale = viewTransform.scale.x
        self.reciprocalViewScale = 1/viewTransform.scale.x
        super.init()
    }
    
    static let cameraFrameKey = "0", frameRateKey = "1",colorSpaceKey = "13", timeKey = "2", materialKey = "3", materialsKey = "12", isShownPreviousKey = "4", isShownNextKey = "5", soundItemKey = "7", viewTransformKey = "6", cutItemsKey = "8", editCutItemIndexKey = "9", maxCutKeyIndexKey = "10", timeLengthKey = "11", baseNoteValueKey = "14", tempoKey = "15"
    init?(coder: NSCoder) {
        frame = coder.decodeRect(forKey: Scene.cameraFrameKey)
        frameRate = coder.decodeInteger(forKey: Scene.frameRateKey)
        baseNoteValue = coder.decodeStruct(forKey: Scene.baseNoteValueKey) ?? Q(1, 16)
        tempo = coder.decodeInteger(forKey: Scene.tempoKey)
        colorSpace = coder.decodeStruct(forKey: Scene.colorSpaceKey) ?? .sRGB
        editMaterial = coder.decodeObject(forKey: Scene.materialKey) as? Material ?? Material()
        materials = coder.decodeObject(forKey: Scene.materialsKey) as? [Material] ?? []
        isShownPrevious = coder.decodeBool(forKey: Scene.isShownPreviousKey)
        isShownNext = coder.decodeBool(forKey: Scene.isShownNextKey)
        soundItem = coder.decodeObject(forKey: Scene.soundItemKey) as? SoundItem ?? SoundItem()
        viewTransform = coder.decodeStruct(forKey: Scene.viewTransformKey) ?? Transform()
        cutItems = coder.decodeObject(forKey: Scene.cutItemsKey) as? [CutItem] ?? [CutItem()]
        editCutItemIndex = coder.decodeInteger(forKey: Scene.editCutItemIndexKey)
        maxCutKeyIndex = coder.decodeInteger(forKey: Scene.maxCutKeyIndexKey)
        time = coder.decodeStruct(forKey: Scene.timeKey) ?? 0
        timeLength = coder.decodeStruct(forKey: Scene.timeLengthKey) ?? Q(0)
        scale = viewTransform.scale.x
        reciprocalViewScale = 1/viewTransform.scale.x
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(frame, forKey: Scene.cameraFrameKey)
        coder.encode(frameRate, forKey: Scene.frameRateKey)
        coder.encodeStruct(baseNoteValue, forKey: Scene.baseNoteValueKey)
        coder.encode(tempo, forKey: Scene.tempoKey)
        coder.encodeStruct(colorSpace, forKey: Scene.colorSpaceKey)
        coder.encodeStruct(time, forKey: Scene.timeKey)
        coder.encode(editMaterial, forKey: Scene.materialKey)
        coder.encode(materials, forKey: Scene.materialsKey)
        coder.encode(isShownPrevious, forKey: Scene.isShownPreviousKey)
        coder.encode(isShownNext, forKey: Scene.isShownNextKey)
        coder.encode(soundItem, forKey: Scene.soundItemKey)
        coder.encodeStruct(viewTransform, forKey: Scene.viewTransformKey)
        coder.encode(cutItems, forKey: Scene.cutItemsKey)
        coder.encode(editCutItemIndex, forKey: Scene.editCutItemIndexKey)
        coder.encode(maxCutKeyIndex, forKey: Scene.maxCutKeyIndexKey)
        coder.encodeStruct(timeLength, forKey: Scene.timeLengthKey)
    }
    
    var deepCopy: Scene {
        return Scene(
            frame: frame, frameRate: frameRate,
            editMaterial: editMaterial, materials: materials,
            isShownPrevious: isShownPrevious, isShownNext: isShownNext,
            soundItem: soundItem,
            cutItems: cutItems.map { $0.deepCopy }, editCutItemIndex: editCutItemIndex, maxCutKeyIndex: maxCutKeyIndex,
            time: time, timeLength: timeLength,
            viewTransform: viewTransform
        )
    }
    
    var editCutItem: CutItem {
        return cutItems[editCutItemIndex]
    }
    
    func time(withFrameRateTime frameRateTime: CGFloat) -> Q {
        return Q(Int(frameRateTime), frameRate)
    }
    func frameRateTime(withTime time: Q) -> CGFloat {
        return time.p.cf*frameRate.cf/time.q.cf
    }
    func cutTime(withFrameRateTime frameRateTime: CGFloat) -> (cutItemIndex: Int, cut: Cut, time: Q) {
        let t = cutItemIndex(withTime: time(withFrameRateTime: frameRateTime))
        return (t.index, cutItems[t.index].cut, t.interTime)
    }
    var secondTime: (second: Int, frame: Int) {
        return (time.integralPart, Int(frameRateTime(withTime: time.decimalPart)))
    }
    
    func cutItemIndex(withTime time: Q) -> (index: Int, interTime: Q, isOver: Bool) {
        guard cutItems.count > 1 else {
            return (0, time, timeLength <= time)
        }
        for i in 1 ..< cutItems.count {
            if time < cutItems[i].time {
                return (i - 1, time - cutItems[i - 1].time, false)
            }
        }
        return (cutItems.count - 1, time - timeLength, true)
    }
}

final class SceneEditor: LayerRespondable, Localizable, ButtonDelegate, PulldownButtonDelegate {
    static let name = Localization(english: "Scene Editor", japanese: "シーンエディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    var undoManager: UndoManager?
    
    var locale = Locale.current {
        didSet {
            updateChildren()
        }
    }
    
    let rendererEditor = RendererEditor(), scenePropertyEditor = ScenePropertyEditor()
    let undoEditor = UndoEditor(backgroundColor: .background0)
    let speechEditor = SpeechEditor()
    let transformEditor = TransformEditor(), soundEditor = SoundEditor()
    let newAnimationButton = Button(
        backgroundColor: .background0,
        name: Localization(english: "New Animation", japanese: "新規アニメーション")
    )
    let newCutButton = Button(
        backgroundColor: .background0,
        name: Localization(english: "New Cut", japanese: "新規カット")
    )
    let newNodeButton = Button(
        backgroundColor: .background0,
        name: Localization(english: "New Node", japanese: "新規ノード")
    )
    let changeToRoughButton = Button(
        backgroundColor: .background0,
        name: Localization(english: "Change to Draft", japanese: "下書き化")
    )
    let removeRoughButton = Button(
        backgroundColor: .background0,
        name: Localization(english: "Remove Draft", japanese: "下書きを削除")
    )
    let swapRoughButton = Button(
        backgroundColor: .background0,
        name: Localization(english: "Swap Draft", japanese: "下書きと交換")
    )
    let isShownPreviousButton = PulldownButton(
        backgroundColor: .background0,
        isEnabledCation: true,
        names: [
            Localization(english: "Hidden Previous", japanese: "前の表示なし"),
            Localization(english: "Shown Previous", japanese: "前の表示あり")
        ],
        description: Localization(english: "Hide/Show line drawing of previous keyframe", japanese: "前のキーフレームの表示切り替え")
    )
    let isShownNextButton = PulldownButton(
        backgroundColor: .background0,
        isEnabledCation: true,
        names: [
            Localization(english: "Hidden Next", japanese: "次の表示なし"),
            Localization(english: "Shown Next", japanese: "次の表示あり")
        ],
        description: Localization(english: "Hide/Show line drawing of next keyframe", japanese: "次のキーフレームの表示切り替え")
    )
    let timeline = Timeline(backgroundColor: .background0, description: Localization(english: "For scene", japanese: "シーン用"))
    let canvas = Canvas()
    
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
                canvas.cutItem = scene.editCutItem
            } else {
                dataModel.insert(cutsDataModel)
            }
            
            timeline.keyframeEditor.update()
            transformEditor.update()
            speechEditor.update()
        }
    }
    
    var scene = Scene() {
        didSet {
            scenePropertyEditor.scene = scene
            canvas.scene = scene
            timeline.scene = scene
            canvas.materialEditor.material = scene.editMaterial
            isShownPreviousButton.selectionIndex = scene.isShownPrevious ? 1 : 0
            isShownNextButton.selectionIndex = scene.isShownNext ? 1 : 0
            soundEditor.scene = scene
            timeline.keyframeEditor.update()
            transformEditor.update()
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
        newAnimationButton.sendDelegate = self
        newCutButton.sendDelegate = self
        newNodeButton.sendDelegate = self
        changeToRoughButton.sendDelegate = self
        removeRoughButton.sendDelegate = self
        swapRoughButton.sendDelegate = self
        isShownPreviousButton.delegate = self
        isShownNextButton.delegate = self
        
        canvas.sceneEditor = self
        canvas.materialEditor.sceneEditor = self
        timeline.sceneEditor = self
        transformEditor.sceneEditor = self
        speechEditor.sceneEditor = self
        canvas.materialEditor.sceneEditor = self
        timeline.keyframeEditor.sceneEditor = self
        rendererEditor.sceneEditor = self
        soundEditor.sceneEditor = self
        self.children = [
            rendererEditor, scenePropertyEditor, undoEditor,
            speechEditor,
            transformEditor, soundEditor,
            newAnimationButton, newCutButton, newNodeButton,
            changeToRoughButton, removeRoughButton, swapRoughButton,
            isShownPreviousButton, isShownNextButton,
            timeline,
            canvas,
        ]
        update(withChildren: children, oldChildren: [])
        updateChildren()
        
        scenePropertyEditor.scene = scene
        canvas.scene = scene
        timeline.scene = scene
        canvas.materialEditor.material = scene.editMaterial
        isShownPreviousButton.selectionIndex = scene.isShownPrevious ? 1 : 0
        isShownNextButton.selectionIndex = scene.isShownNext ? 1 : 0
        soundEditor.scene = scene
        
        cutsDataModel.insert(scene.cutItems[0].cutDataModel)
        dataModel = DataModel(key: SceneEditor.sceneEditorKey, directoryWithChildren: [sceneDataModel, cutsDataModel])
        sceneDataModel.dataHandler = { [unowned self] in self.scene.data }
        scenePropertyEditor.didChangeSceneHandler = { [unowned self] in
            self.canvas.cameraFrame = $0.frame
            self.timeline.setNeedsDisplay()
        }
    }
    
    static let rendererWidth = 350.0.cf, undoWidth = 150.0.cf, soundWidth = 200.0.cf, canvasSize = CGSize(width: 840, height: 560)
    static let buttonsWidth = 120.0.cf, timelineWidth = 430.0.cf, timelineButtonsWidth = 142.0.cf
    func updateChildren() {
        CATransaction.disableAnimation {
            let pd = Layout.basicPadding, h = Layout.basicHeight, cs = SceneEditor.canvasSize, th = Layout.basicHeight*4
            let width = cs.width + pd*2, height = h*3 + th + cs.height + pd*4 + pd*2
            rendererEditor.frame = CGRect(
                x: pd, y: height - pd - h,
                width: SceneEditor.rendererWidth, height: h
            )
            scenePropertyEditor.frame = CGRect(
                x: pd*2 + SceneEditor.rendererWidth, y: height - pd - h,
                width: cs.width - SceneEditor.undoWidth - SceneEditor.rendererWidth - pd*2, height: h
            )
            undoEditor.frame = CGRect(
                x: pd + cs.width - SceneEditor.undoWidth, y: height - pd - h,
                width: SceneEditor.undoWidth, height: h
            )
            
            soundEditor.frame = CGRect(
                x: pd, y: height - pd*2 - h*2,
                width: SceneEditor.soundWidth, height: h
            )
            transformEditor.frame = CGRect(
                x: pd*2 + SceneEditor.soundWidth, y: height - pd*2 - h*2,
                width: cs.width - SceneEditor.soundWidth - pd, height: h
            )
            
            let buttons: [Respondable] = [
                newAnimationButton, newCutButton, newNodeButton,
                changeToRoughButton, removeRoughButton, swapRoughButton,
                isShownPreviousButton, isShownNextButton
            ]
            Layout.autoHorizontalAlignment(buttons, padding: pd, in:
                CGRect(
                    x: pd, y: height - pd*3 - h*3,
                    width: cs.width, height: h
                )
            )
            timeline.frame = CGRect(x: pd, y: height - pd*4 - h*3 - th, width: cs.width, height: th)
            canvas.frame = CGRect(x: pd, y: height - pd*5 - h*3 - th - cs.height, width: cs.width, height: cs.height)
            frame.size = CGSize(width: width, height: height)
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
    
    func clickButton(_ button: Button) {
        switch button {
        case newAnimationButton:
            timeline.newAnimation()
        case newCutButton:
            timeline.newCut()
        case newNodeButton:
            timeline.newNode()
        case changeToRoughButton:
            canvas.changeToRough()
        case removeRoughButton:
            canvas.removeRough()
        case swapRoughButton:
            canvas.swapRough()
        default:
            break
        }
    }
    func changeValue(_ pulldownButton: PulldownButton, index: Int, oldIndex: Int, type: Action.SendType) {
        switch pulldownButton {
        case isShownPreviousButton:
            switch type {
            case .begin:
                break
            case .sending:
                canvas.isShownPrevious = index == 1
            case .end:
                if index != oldIndex {
                    setIsShownPrevious(index == 1, oldIsShownPrevious: oldIndex == 1)
                } else {
                    canvas.isShownPrevious = index == 1
                }
            }
        case isShownNextButton:
            switch type {
            case .begin:
                break
            case .sending:
                canvas.isShownNext = index == 1
            case .end:
                if index != oldIndex {
                    setIsShownNext(index == 1, oldIsShownNext: oldIndex == 1)
                } else {
                    canvas.isShownNext = index == 1
                }
            }
        default:
            break
        }
    }
    private func setIsShownPrevious(_ isShownPrevious: Bool, oldIsShownPrevious: Bool) {
        undoManager?.registerUndo(withTarget: self) { $0.setIsShownPrevious(oldIsShownPrevious, oldIsShownPrevious: isShownPrevious) }
        isShownPreviousButton.selectionIndex = isShownPrevious ? 1 : 0
        canvas.isShownPrevious = isShownPrevious
        sceneDataModel.isWrite = true
    }
    private func setIsShownNext(_ isShownNext: Bool, oldIsShownNext: Bool) {
        undoManager?.registerUndo(withTarget: self) { $0.setIsShownNext(oldIsShownNext, oldIsShownNext: isShownNext) }
        isShownNextButton.selectionIndex = isShownNext ? 1 : 0
        canvas.isShownNext = isShownNext
        sceneDataModel.isWrite = true
    }
}

final class ScenePropertyEditor: LayerRespondable, NumberSliderDelegate, PulldownButtonDelegate {
    static let name = Localization(english: "Scene Property Editor", japanese: "シーンプロパティエディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var undoManager: UndoManager?
    
    static let valueWidth = 50.cf, colorSpaceWidth = 82.cf
    static let valueFrame = CGRect(
        x: 0, y: Layout.basicPadding,
        width: valueWidth, height: Layout.basicHeight - Layout.basicPadding*2
    )
    static let colorSpaceFrame = CGRect(
        x: 0, y: Layout.basicPadding,
        width: colorSpaceWidth, height: Layout.basicHeight - Layout.basicPadding*2
    )
    
    weak var sceneEditor: SceneEditor!
    private let wLabel = Label(
        frame: CGRect(x: 0, y: Layout.basicPadding, width: 0, height: Layout.basicHeight - Layout.basicPadding*2),
        string: "w:", font: Font.small, color: Color.smallFont, backgroundColor: .background0,
        paddingWidth: 2
    )
    private let hLabel = Label(
        frame: CGRect(x: 0, y: Layout.basicPadding, width: 0, height: Layout.basicHeight - Layout.basicPadding*2),
        string: "h:", font: Font.small, color: Color.smallFont, backgroundColor: .background0,
        paddingWidth: 2
    )
    private let widthSlider = NumberSlider(
        frame: ScenePropertyEditor.valueFrame, min: 1, max: 10000, valueInterval: 1,
        description: Localization(english: "Scene width", japanese: "シーンの幅")
    )
    private let heightSlider = NumberSlider(
        frame: ScenePropertyEditor.valueFrame, min: 1, max: 10000, valueInterval: 1,
        description: Localization(english: "Scene height", japanese: "シーンの高さ")
    )
    private let frameRateSlider = NumberSlider(
        frame: ScenePropertyEditor.valueFrame, min: 1, max: 1000, valueInterval: 1, unit: " fps",
        description: Localization(english: "Scene frame rate", japanese: "シーンのフレームレート")
    )
    private let tempoSlider = NumberSlider(
        frame: ScenePropertyEditor.valueFrame, min: 1, max: 10000000, valueInterval: 1, unit: " bpm",
        description: Localization(english: "Scene tempo", japanese: "シーンのテンポ")
    )
    let colorSpaceButton = PulldownButton(
        frame: ScenePropertyEditor.colorSpaceFrame,
        backgroundColor: .background1,
        names: [
            Localization("sRGB"),
            Localization("Display P3")
        ],
        description: Localization(
            english: "Color Space",
            japanese: "色空間"
        )
    )
    
    var didChangeSceneHandler: ((Scene) -> (Void))?
    var scene = Scene() {
        didSet {
            widthSlider.value = scene.frame.width
            heightSlider.value = scene.frame.height
            frameRateSlider.value = scene.frameRate.cf
            tempoSlider.value = scene.tempo.cf
            colorSpaceButton.selectionIndex = scene.colorSpace == .sRGB ? 0 : 1
        }
    }
    
    let layer = CALayer.interfaceLayer(backgroundColor: .background0)
    init() {
        widthSlider.delegate = self
        heightSlider.delegate = self
        frameRateSlider.delegate = self
        tempoSlider.delegate = self
        colorSpaceButton.delegate = self
        
        let children: [LayerRespondable] = [wLabel, widthSlider, hLabel, heightSlider, frameRateSlider, tempoSlider, colorSpaceButton]
        self.children = children
        update(withChildren: children, oldChildren: [])
        Layout.centered(children, in: layer.bounds)
    }
    
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            layer.frame = newValue
            if let children = children as? [LayerRespondable] {
                Layout.centered(children, in: layer.bounds)
            }
        }
    }
    
    func changeValue(_ slider: NumberSlider, value: CGFloat, oldValue: CGFloat, type: Action.SendType) {
        switch slider {
        case widthSlider:
            scene.frame.origin.x = -value/2
            scene.frame.size.width = value
            didChangeSceneHandler?(scene)
        case heightSlider:
            scene.frame.origin.y = -value/2
            scene.frame.size.height = value
            didChangeSceneHandler?(scene)
        case frameRateSlider:
            scene.frameRate = FPS(value)
            didChangeSceneHandler?(scene)
        case tempoSlider:
            scene.tempo = BPM(value)
            didChangeSceneHandler?(scene)
        default:
            return
        }
    }
    func changeValue(_ pulldownButton: PulldownButton, index: Int, oldIndex: Int, type: Action.SendType) {
        switch pulldownButton {
        case colorSpaceButton:
            scene.colorSpace = index == 0 ? .sRGB : .displayP3
            didChangeSceneHandler?(scene)
        default:
            break
        }
    }
}

final class TransformEditor: LayerRespondable, NumberSliderDelegate, Localizable {
    static let name = Localization(english: "Transform Editor", japanese: "トランスフォームエディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var undoManager: UndoManager?
    
    var locale = Locale.current {
        didSet {
            CATransaction.disableAnimation {
                if let children = children as? [LayerRespondable] {
                    Layout.centered(children, in: layer.bounds)
                }
            }
        }
    }
    
    static let valueWidth = 46.0.cf
    static let labelFrame = CGRect(x: 0, y: Layout.basicPadding, width: 0, height: Layout.basicHeight - Layout.basicPadding*2)
    static let valueFrame = CGRect(x: 0, y: Layout.basicPadding, width:  valueWidth, height: Layout.basicHeight - Layout.basicPadding*2)
    
    weak var sceneEditor: SceneEditor!
    private let xLabel = Label(
        frame: labelFrame,
        string: "x:", font: .small, color: .smallFont, backgroundColor: .background0, paddingWidth: 2
    )
    private let yLabel = Label(
        frame: labelFrame,
        string: "y:", font: .small, color: .smallFont, backgroundColor: .background0, paddingWidth: 2
    )
    private let zLabel = Label(
        frame: labelFrame,
        string: "z:", font: .small, color: .smallFont, backgroundColor: .background0, paddingWidth: 2
    )
    private let thetaLabel = Label(
        frame: labelFrame,
        string: "θ:", font: .small, color: .smallFont, backgroundColor: .background0, paddingWidth: 2
    )
    private let wiggleXLabel = Label(
        frame: labelFrame,
        text: Localization(english: "Wiggle(x:", japanese: "振動(x:"),
        font: .small, color: .smallFont, backgroundColor: .background0, paddingWidth: 2
    )
    private let wiggleYLabel = Label(
        frame: labelFrame,
        string: "y:", font: .small, color: .smallFont, backgroundColor: .background0, paddingWidth: 2
    )
    private let wiggleEndLabel = Label(
        frame: labelFrame,
        string: ")", font: .small, color: .smallFont, backgroundColor: .background0, paddingWidth: 2
    )
    private let xSlider = NumberSlider(
        frame: TransformEditor.valueFrame, min: -10000, max: 10000, valueInterval: 0.01,
        description: Localization(english: "Transform position x", japanese: "トランスフォームの位置 x")
    )
    private let ySlider = NumberSlider(
        frame: TransformEditor.valueFrame, min: -10000, max: 10000, valueInterval: 0.01,
        description: Localization(english: "Transform position y", japanese: "トランスフォームの位置 y")
    )
    private let zSlider = NumberSlider(
        frame: TransformEditor.valueFrame, min: -20, max: 20, valueInterval: 0.01,
        description: Localization(english: "Transform position z", japanese: "トランスフォームの位置 z")
    )
    private let thetaSlider = NumberSlider(
        frame: TransformEditor.valueFrame, min: -10000, max: 10000, valueInterval: 0.5, unit: "°",
        description: Localization(english: "Transform angle", japanese: "トランスフォームの角度")
    )
    private let wiggleXSlider = NumberSlider(
        frame: TransformEditor.valueFrame, min: 0, max: 1000, valueInterval: 0.01,
        description: Localization(english: "Transform wiggle amplitude x", japanese: "トランスフォームの振幅 x")
    )
    private let wiggleYSlider = NumberSlider(
        frame: TransformEditor.valueFrame, min: 0, max: 1000, valueInterval: 0.01,
        description: Localization(english: "Transform wiggle amplitude y", japanese: "トランスフォームの振幅 y")
    )
    private let wiggleFrequencySlider = NumberSlider(
        frame: TransformEditor.valueFrame, min: 0.1, max: 100000, valueInterval: 0.1, unit: " Hz",
        description: Localization(english: "Transform wiggle frequency", japanese: "トランスフォームの振動数")
    )
    let layer = CALayer.interfaceLayer(backgroundColor: .background0)
    init() {
        xSlider.delegate = self
        ySlider.delegate = self
        zSlider.delegate = self
        thetaSlider.delegate = self
        wiggleXSlider.delegate = self
        wiggleYSlider.delegate = self
        wiggleFrequencySlider.delegate = self
        let children: [LayerRespondable] = [
            xLabel, xSlider, yLabel, ySlider, zLabel, zSlider, thetaLabel, thetaSlider,
            wiggleXLabel, wiggleXSlider, wiggleYLabel, wiggleYSlider, wiggleFrequencySlider, wiggleEndLabel
        ]
        self.children = children
        update(withChildren: children, oldChildren: [])
        wiggleFrequencySlider.value = transform.wiggle.frequency
        Layout.centered(children, in: layer.bounds)
    }
    
    var frame: CGRect {
        get {
            return layer.frame
        }
        set {
            layer.frame = newValue
            Layout.centered(children, in: bounds)
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
        transform = sceneEditor.scene.editCutItem.cut.editNode.editAnimation.transformItem?.transform ?? Transform()
    }
    private func updateChildren() {
        let b = sceneEditor.scene.frame
        xSlider.value = transform.translation.x/b.width
        ySlider.value = transform.translation.y/b.height
        zSlider.value = transform.z
        thetaSlider.value = transform.rotation*180/(.pi)
        wiggleXSlider.value = 10*transform.wiggle.amplitude.x/b.width
        wiggleYSlider.value = 10*transform.wiggle.amplitude.y/b.height
        wiggleFrequencySlider.value = transform.wiggle.frequency
    }
    
    func copy(with event: KeyInputEvent) -> CopyObject {
        return CopyObject(objects: [transform])
    }
    func paste(_ copyObject: CopyObject, with event: KeyInputEvent) {
        for object in copyObject.objects {
            if let transform = object as? Transform {
                let cutItem = sceneEditor.scene.editCutItem
                let animation = cutItem.cut.editNode.editAnimation
//                if cutItem.cut.editNode.isInterpolatedKeyframe(with: animation) {
//                    sceneEditor.timeline.splitKeyframe(with: animation)
//                }
                setTransform(transform, at: animation.editKeyframeIndex, in: animation, cutItem)
                return
            }
        }
    }
    
    private var oldTransform = Transform(), keyIndex = 0, isMadeTransformItem = false
    private weak var oldTransformItem: TransformItem?, animation: Animation?, cutItem: CutItem?
    func changeValue(_ slider: NumberSlider, value: CGFloat, oldValue: CGFloat, type: Action.SendType) {
        switch type {
        case .begin:
            undoManager?.beginUndoGrouping()
            let cutItem = sceneEditor.scene.editCutItem
            let animation = cutItem.cut.editNode.editAnimation
//            if cutItem.cut.editNode.isInterpolatedKeyframe(with: animation) {
//                sceneEditor.timeline.splitKeyframe(with: animation)
//            }
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
    private func transformWith(value: CGFloat, slider: NumberSlider, oldTransform t: Transform) -> Transform {
        let b = sceneEditor.scene.frame
        switch slider {
        case xSlider:
            return t.with(translation: CGPoint(x: value*b.width, y: t.translation.y))
        case ySlider:
            return t.with(translation: CGPoint(x: t.translation.x, y: value*b.height))
        case zSlider:
            return t.with(z: value)
        case thetaSlider:
            return t.with(rotation: value*(.pi/180))
        case wiggleXSlider:
            return t.with(wiggle: t.wiggle.with(amplitude: CGPoint(x: value*b.width/10, y: t.wiggle.amplitude.y)))
        case wiggleYSlider:
            return t.with(wiggle: t.wiggle.with(amplitude: CGPoint(x: t.wiggle.amplitude.x, y: value*b.height/10)))
        case wiggleFrequencySlider:
            return t.with(wiggle: t.wiggle.with(frequency: value))
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
        cutItem.cut.editNode.updateTransform()
        if cutItem === sceneEditor.canvas.cutItem {
            sceneEditor.canvas.setNeedsDisplay()
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
            update(withChildren: children, oldChildren: oldValue)
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
    let drawLayer = DrawLayer(backgroundColor: Color.background0)
    
    init() {
        textLine = TextLine(string: "", font: Font.small, color: Color.smallFont, isVerticalCenter: true)
        drawLayer.drawBlock = { [unowned self] ctx in
            if self.scene.soundItem.isHidden {
                ctx.setAlpha(0.25)
            }
            self.textLine.draw(in: self.bounds, in: ctx)
        }
//        layer.frame = SceneEditor.Layout.soundFrame
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
            update(withChildren: children, oldChildren: oldValue)
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
        update(withChildren: children, oldChildren: [])
    }
    func update() {
        self.text = sceneEditor.scene.editCutItem.cut.editNode.editAnimation.textItem?.text ?? Text()
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
        sceneEditor.scene.editCutItem.cutDataModel.isWrite = true
        self.text = text
    }
}
