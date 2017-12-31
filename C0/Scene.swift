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

typealias BPM = Int
typealias FPS = Int
typealias FrameTime = Int
typealias BaseTime = Q
typealias Beat = Q
typealias DoubleBaseTime = Double
typealias DoubleBeat = Double
typealias Second = Double

final class Scene: NSObject, NSCoding {
    var name: String
    var frame: CGRect, frameRate: FPS, baseTimeInterval: Beat, tempo: BPM
    var colorSpace: ColorSpace {
        didSet {
            self.materials = materials.map { $0.withColor($0.color.with(colorSpace: colorSpace)) }
        }
    }
    var editMaterial: Material, materials: [Material]
    var isShownPrevious: Bool, isShownNext: Bool
    var sound: Sound
    
    var viewTransform: Transform {
        didSet {
            self.scale = viewTransform.scale.x
            self.reciprocalViewScale = 1 / viewTransform.scale.x
        }
    }
    private(set) var scale: CGFloat, reciprocalViewScale: CGFloat
    var reciprocalScale: CGFloat {
        return reciprocalViewScale / editCutItem.cut.editNode.worldScale
    }
    
    var cutItems: [CutItem] {
        didSet {
            updateCutTimeAndDuration()
        }
    }
    var editCutItemIndex: Int
    
    var time: Beat
    private(set) var duration: Beat
    func updateCutTimeAndDuration() {
        self.duration = cutItems.reduce(Beat(0)) {
            $1.time = $0
            return $0 + $1.cut.duration
        }
    }
    var maxCutKeyIndex: Int
    
    init(name: String = Localization(english: "Untitled", japanese: "名称未設定").currentString,
         frame: CGRect = CGRect(x: -288, y: -162, width: 576, height: 324), frameRate: FPS = 24,
         baseTimeInterval: Beat = Beat(1, 24), tempo: BPM = 60,
         colorSpace: ColorSpace = .sRGB,
         editMaterial: Material = Material(), materials: [Material] = [],
         isShownPrevious: Bool = false, isShownNext: Bool = false,
         sound: Sound = Sound(),
         cutItems: [CutItem] = [CutItem()], editCutItemIndex: Int = 0, maxCutKeyIndex: Int = 0,
         time: Beat = 0, duration: Beat = 1,
         viewTransform: Transform = Transform()) {
        
        self.name = name
        self.frame = frame
        self.frameRate = frameRate
        self.baseTimeInterval = baseTimeInterval
        self.tempo = tempo
        self.colorSpace = colorSpace
        self.editMaterial = editMaterial
        self.materials = materials
        self.isShownPrevious = isShownPrevious
        self.isShownNext = isShownNext
        self.sound = sound
        self.viewTransform = viewTransform
        self.cutItems = cutItems
        self.editCutItemIndex = editCutItemIndex
        self.maxCutKeyIndex = maxCutKeyIndex
        self.time = time
        self.duration = duration
        self.scale = viewTransform.scale.x
        self.reciprocalViewScale = 1 / viewTransform.scale.x
    }
    
    private enum CodingKeys: String, CodingKey {
        case
        name, frame, frameRate, baseTimeInterval, tempo, colorSpace,
        editMaterial, materials, isShownPrevious, isShownNext, sound, viewTransform,
        cutItems, editCutItemIndex, maxCutKeyIndex, time, duration
    }
    init?(coder: NSCoder) {
        name = coder.decodeObject(forKey: CodingKeys.name.rawValue) as? String ?? ""
        frame = coder.decodeRect(forKey: CodingKeys.frame.rawValue)
        frameRate = coder.decodeInteger(forKey: CodingKeys.frameRate.rawValue)
        baseTimeInterval = coder.decodeDecodable(
            Beat.self, forKey: CodingKeys.baseTimeInterval.rawValue) ?? Beat(1, 16)
        tempo = coder.decodeInteger(forKey: CodingKeys.tempo.rawValue)
        colorSpace = ColorSpace(
            rawValue: Int8(coder.decodeInt32(forKey: CodingKeys.colorSpace.rawValue))) ?? .sRGB
        editMaterial = coder.decodeObject(
            forKey: CodingKeys.editMaterial.rawValue) as? Material ?? Material()
        materials = coder.decodeObject(forKey: CodingKeys.materials.rawValue) as? [Material] ?? []
        isShownPrevious = coder.decodeBool(forKey: CodingKeys.isShownPrevious.rawValue)
        isShownNext = coder.decodeBool(forKey: CodingKeys.isShownNext.rawValue)
        sound = coder.decodeDecodable(Sound.self, forKey: CodingKeys.sound.rawValue) ?? Sound()
        viewTransform = coder.decodeDecodable(
            Transform.self, forKey: CodingKeys.viewTransform.rawValue) ?? Transform()
        cutItems = coder.decodeObject(
            forKey: CodingKeys.cutItems.rawValue) as? [CutItem] ?? [CutItem()]
        editCutItemIndex = coder.decodeInteger(forKey: CodingKeys.editCutItemIndex.rawValue)
        maxCutKeyIndex = coder.decodeInteger(forKey: CodingKeys.maxCutKeyIndex.rawValue)
        time = coder.decodeDecodable(Beat.self, forKey: CodingKeys.time.rawValue) ?? 0
        duration = coder.decodeDecodable(
            Beat.self, forKey: CodingKeys.duration.rawValue) ?? Beat(0)
        scale = viewTransform.scale.x
        reciprocalViewScale = 1 / viewTransform.scale.x
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: CodingKeys.name.rawValue)
        coder.encode(frame, forKey: CodingKeys.frame.rawValue)
        coder.encode(frameRate, forKey: CodingKeys.frameRate.rawValue)
        coder.encodeEncodable(baseTimeInterval, forKey: CodingKeys.baseTimeInterval.rawValue)
        coder.encode(tempo, forKey: CodingKeys.tempo.rawValue)
        coder.encode(Int32(colorSpace.rawValue), forKey: CodingKeys.colorSpace.rawValue)
        coder.encode(editMaterial, forKey: CodingKeys.editMaterial.rawValue)
        coder.encode(materials, forKey: CodingKeys.materials.rawValue)
        coder.encode(isShownPrevious, forKey: CodingKeys.isShownPrevious.rawValue)
        coder.encode(isShownNext, forKey: CodingKeys.isShownNext.rawValue)
        coder.encodeEncodable(sound, forKey: CodingKeys.sound.rawValue)
        coder.encodeEncodable(viewTransform, forKey: CodingKeys.viewTransform.rawValue)
        coder.encode(cutItems, forKey: CodingKeys.cutItems.rawValue)
        coder.encode(editCutItemIndex, forKey: CodingKeys.editCutItemIndex.rawValue)
        coder.encode(maxCutKeyIndex, forKey: CodingKeys.maxCutKeyIndex.rawValue)
        coder.encodeEncodable(time, forKey: CodingKeys.time.rawValue)
        coder.encodeEncodable(duration, forKey: CodingKeys.duration.rawValue)
    }
    
    var editCutItem: CutItem {
        return cutItems[editCutItemIndex]
    }
    
    func beatTime(withFrameTime frameTime: FrameTime) -> Beat {
        return Beat(frameTime, frameRate) * Beat(tempo, 60)
    }
    func frameTime(withBeatTime beatTime: Beat) -> FrameTime {
        return ((beatTime * Beat(60, tempo)) / Beat(frameRate)).integralPart
    }
    func beatTime(withSecondTime secondTime: Second) -> Beat {
        return basedBeatTime(withDoubleBeatTime: DoubleBeat(secondTime * (Second(tempo) / 60)))
    }
    func secondTime(withBeatTime beatTime: Beat) -> Second {
        return Second(beatTime * Beat(60, tempo))
    }
    func basedBeatTime(withDoubleBeatTime doubleBeatTime: DoubleBeat) -> Beat {
        return Beat(Int(doubleBeatTime / DoubleBeat(baseTimeInterval))) * baseTimeInterval
    }
    func doubleBeatTime(withBeatTime beatTime: Beat) -> DoubleBeat {
        return DoubleBeat(beatTime)
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
    
    func cutTime(withFrameTime frameTime: Int) -> (cutItemIndex: Int, cut: Cut, time: Beat) {
        let t = cutItemIndex(withTime: beatTime(withFrameTime: frameTime))
        return (t.index, cutItems[t.index].cut, t.interTime)
    }
    var secondTime: (second: Int, frame: Int) {
        let frameTime = self.frameTime(withBeatTime: time)
        let second = frameTime / frameRate
        return (second, frameTime - second)
    }
    
    func cutItemIndex(withTime time: Beat) -> (index: Int, interTime: Beat, isOver: Bool) {
        guard cutItems.count > 1 else {
            return (0, time, duration <= time)
        }
        for i in 1 ..< cutItems.count {
            if time < cutItems[i].time {
                return (i - 1, time - cutItems[i - 1].time, false)
            }
        }
        return (cutItems.count - 1, time - cutItems[cutItems.count - 1].time, true)
    }
}
extension Scene: Copying {
    func copied(from copier: Copier) -> Scene {
        return Scene(frame: frame, frameRate: frameRate,
                     editMaterial: editMaterial, materials: materials,
                     isShownPrevious: isShownPrevious, isShownNext: isShownNext,
                     sound: sound,
                     cutItems: cutItems.map { copier.copied($0) },
                     editCutItemIndex: editCutItemIndex, maxCutKeyIndex: maxCutKeyIndex,
                     time: time, duration: duration,
                     viewTransform: viewTransform)
    }
}
extension Scene: Referenceable {
    static let name = Localization(english: "Scene", japanese: "シーン")
}


final class SceneEditor: LayerRespondable, Localizable {
    static let name = Localization(english: "Scene Editor", japanese: "シーンエディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var undoManager: UndoManager? = UndoManager()
    
    var locale = Locale.current {
        didSet {
            updateChildren()
        }
    }
    
    static let valueWidth = 56.cf, colorSpaceWidth = 82.cf
    static let valueFrame = CGRect(x: 0, y: Layout.basicPadding,
                                   width: valueWidth, height: Layout.basicHeight)
    static let colorSpaceFrame = CGRect(x: 0, y: Layout.basicPadding,
                                        width: colorSpaceWidth, height: Layout.basicHeight)
    
    let nameLabel = Label(text: Scene.name, font: .bold)
    let versionEditor = VersionEditor()
    let rendererManager = RendererManager()
    let sizeEditor = DiscreteSizeEditor()
    let frameRateSlider = NumberSlider(frame: SceneEditor.valueFrame,
                                       min: 1, max: 1000, valueInterval: 1, unit: " fps",
                                       description: Localization(english: "Frame rate",
                                                                 japanese: "フレームレート"))
    let baseTimeIntervalSlider = NumberSlider(
        frame: SceneEditor.valueFrame,
        min: 1, max: 1000, valueInterval: 1, unit: " cpb",
        description: Localization(english: "Edit split count per beat",
                                  japanese: "1ビートあたりの編集分割数")
    )
    let colorSpaceLabel = Label(text: Localization(", "))
    let colorSpaceButton = PulldownButton(frame: SceneEditor.colorSpaceFrame,
                                          names: [Localization("sRGB"),
                                                  Localization("Display P3")],
                                          description: Localization(english: "Color Space",
                                                                    japanese: "色空間"))
    let isShownPreviousButton = PulldownButton(
        names: [Localization(english: "Hidden Previous", japanese: "前の表示なし"),
                Localization(english: "Shown Previous", japanese: "前の表示あり")],
        isEnabledCation: true,
        description: Localization(english: "Hide or Show line drawing of previous keyframe",
                                  japanese: "前のキーフレームの表示切り替え")
    )
    let isShownNextButton = PulldownButton(
        names: [Localization(english: "Hidden Next", japanese: "次の表示なし"),
                Localization(english: "Shown Next", japanese: "次の表示あり")],
        isEnabledCation: true,
        description: Localization(english: "Hide or Show line drawing of next keyframe",
                                  japanese: "次のキーフレームの表示切り替え")
    )
    
    let newNodeTrackButton = Button(name: Localization(english: "New Node Track",
                                                       japanese: "新規ノードトラック"))
//    let newCutButton = Button(name: Localization(english: "New Cut", japanese: "新規カット"))
    let newNodeButton = Button(name: Localization(english: "New Node", japanese: "新規ノード"))
    let changeToDraftButton = Button(name: Localization(english: "Change to Draft",
                                                        japanese: "下書き化"))
    let removeDraftButton = Button(name: Localization(english: "Remove Draft", japanese: "下書きを削除"))
    let swapDraftButton = Button(name: Localization(english: "Swap Draft", japanese: "下書きと交換"))
    
    let showAllBox = Button(name: Localization(english: "Unlock All Cells", japanese: "すべてのセルのロックを解除"))
    let splitColorBox = Button(name: Localization(english: "Split Color", japanese: "カラーを分割"))
    let splitOtherThanColorBox = Button(name: Localization(english: "Split Material",
                                                           japanese: "マテリアルを分割"))
    
    let transformEditor = TransformEditor()
    let wiggleEditor = WiggleEditor()
    let soundEditor = SoundEditor()
    
    let timeline = Timeline()
    let canvas = Canvas()
    let playerEditor = PlayerEditor()
    
    static let sceneEditorKey = "sceneEditor", sceneKey = "scene", cutsKey = "cuts"
    var sceneDataModel = DataModel(key: SceneEditor.sceneKey)
    var cutsDataModel = DataModel(key: SceneEditor.cutsKey, directoryWithDataModels: [])
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
            
            timeline.cutsDataModel = cutsDataModel
            timeline.sceneDataModel = sceneDataModel
            update(with: scene)
        }
    }
    
    var scene = Scene() {
        didSet {
            update(with: scene)
        }
    }
    func update(with scene: Scene) {
        sizeEditor.size = scene.frame.size
        frameRateSlider.value = scene.frameRate.cf
        baseTimeIntervalSlider.value = scene.baseTimeInterval.q.cf
        colorSpaceButton.selectionIndex = scene.colorSpace == .sRGB ? 0 : 1
        canvas.scene = scene
        timeline.scene = scene
        rendererManager.scene = scene
        canvas.materialEditor.scene = scene
        canvas.materialEditor.material = scene.editMaterial
        isShownPreviousButton.selectionIndex = scene.isShownPrevious ? 1 : 0
        isShownNextButton.selectionIndex = scene.isShownNext ? 1 : 0
        transformEditor.standardTranslation = CGPoint(x: scene.frame.width, y: scene.frame.height)
        if let transform = scene.editCutItem.cut.editNode.editTrack.transformItem?.transform {
            transformEditor.transform = transform
        }
        if let wiggle = scene.editCutItem.cut.editNode.editTrack.wiggleItem?.wiggle {
            wiggleEditor.wiggle = wiggle
        }
        soundEditor.sound = scene.sound
        playerEditor.frameRate = scene.frameRate
        playerEditor.time = scene.secondTime(withBeatTime: scene.time)
        playerEditor.cutIndex = scene.editCutItemIndex
        playerEditor.maxTime = scene.secondTime(withBeatTime: scene.duration)
    }
    func updateScene() {
        canvas.cameraFrame = scene.frame
        timeline.update()
    }
    
    var nextCutKeyIndex: Int {
        if let maxKey = cutsDataModel.children.max(by: { $0.key < $1.key }) {
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
    
    let layer = CALayer.interface()
    init() {
        rendererManager.progressesEdgeResponder = self
        
        sizeEditor.setSizeHandler = { [unowned self] in
            self.scene.frame = CGRect(origin: CGPoint(x: -$0.size.width / 2,
                                                      y: -$0.size.height / 2), size: $0.size)
            self.canvas.setNeedsDisplay()
            if $0.type == .end {
                self.sceneDataModel.isWrite = true
            }
            self.transformEditor.standardTranslation = CGPoint(x: self.scene.frame.width,
                                                               y: self.scene.frame.height)
        }
        frameRateSlider.setValueHandler = { [unowned self] in
            self.scene.frameRate = Int($0.value)
        }
        baseTimeIntervalSlider.setValueHandler = { [unowned self] in
            self.scene.baseTimeInterval.q = Int($0.value)
        }
        colorSpaceButton.setIndexHandler = { [unowned self] in
            self.scene.colorSpace = $0.index == 0 ? .sRGB : .displayP3
            self.canvas.setNeedsDisplay()
            if $0.type == .end {
                self.sceneDataModel.isWrite = true
            }
        }
        isShownPreviousButton.setIndexHandler = { [unowned self] in
            self.canvas.isShownPrevious = $0.index == 1
            if $0.type == .end {
                self.sceneDataModel.isWrite = true
            }
        }
        isShownNextButton.setIndexHandler = { [unowned self] in
            self.canvas.isShownNext = $0.index == 1
            if $0.type == .end {
                self.sceneDataModel.isWrite = true
            }
        }
        
        newNodeTrackButton.clickHandler = { [unowned self] _ in self.timeline.newNodeTrack() }
//        newCutButton.clickHandler = { [unowned self] in self.timeline.newCut() }
        newNodeButton.clickHandler = { [unowned self] _ in self.timeline.newNode() }
        changeToDraftButton.clickHandler = { [unowned self] _ in self.canvas.changeToRough() }
        removeDraftButton.clickHandler = { [unowned self] _ in self.canvas.removeRough() }
        swapDraftButton.clickHandler = { [unowned self] _ in self.canvas.swapRough() }
        
        showAllBox.clickHandler = { [unowned self] _ in
            self.canvas.editShowInNode()
        }
        splitColorBox.clickHandler = { [unowned self] _ in
            self.canvas.materialEditor.splitColor(at: self.canvas.materialEditor.editPointInScene)
        }
        splitOtherThanColorBox.clickHandler = { [unowned self] _ in
            self.canvas.materialEditor.splitOtherThanColor(at:
                self.canvas.materialEditor.editPointInScene)
        }
        
//        transformEditor.setTimeHandler = { [unowned self] _, time in
//            self.timeline.time = time
//        }
//        transformEditor.setTransformItemHandler = { [unowned self] _, _ in
//            self.timeline.update()
//        }
//        transformEditor.setTransformHandler = { [unowned self] _, _, _, _, cutItem in
//            if cutItem === self.canvas.cutItem {
//                self.canvas.setNeedsDisplay()
//            }
//        }
        
        timeline.scrollHandler = { [unowned self] (timeline, scrollPoint, event) in
            if event.sendType == .begin && self.canvas.player.isPlaying {
                self.canvas.player.layer.opacity = 0.2
            } else if event.sendType == .end && self.canvas.player.layer.opacity != 1 {
                self.canvas.player.layer.opacity = 1
            }
            
            let isInterporation =
                self.scene.editCutItem.cut.editNode.editTrack.animation.isInterporation
            self.transformEditor.isLocked = isInterporation
            self.wiggleEditor.isLocked = isInterporation
        }
        timeline.setDurationHandler = { [unowned self] _, _, _ in
            self.playerEditor.maxTime = self.scene.secondTime(withBeatTime: self.scene.duration)
        }
        timeline.setEditCutItemIndexHandler = { [unowned self] _, _ in
            self.canvas.cutItem = self.scene.editCutItem
            self.transformEditor.transform =
                self.scene.editCutItem.cut.editNode.editTrack.transformItem?.transform ?? Transform()
        }
        timeline.updateViewHandler = { [unowned self] in
            if $0.isCut {
                let p = self.canvas.cursorPoint
                if self.canvas.contains(p) {
                    self.canvas.updateEditView(with: self.canvas.convertToCurrentLocal(p))
                }
                self.canvas.setNeedsDisplay()
            }
            if $0.isTransform {
                self.transformEditor.transform =
                    self.scene.editCutItem.cut.editNode.editTrack.transformItem?.transform ??
                    Transform()
            }
        }
        
        timeline.keyframeEditor.setKeyframeHandler = { [unowned self] _ in
            self.timeline.update()
            self.canvas.setNeedsDisplay()
        }
        
        timeline.nodeEditor.setIsHiddenHandler = { [unowned self] _ in
            self.canvas.setNeedsDisplay()
            self.timeline.update()
        }
        
        canvas.setTimeHandler = { [unowned self] _, time in self.timeline.time = time }
        canvas.updateSceneHandler = { [unowned self] _ in self.sceneDataModel.isWrite = true }
        canvas.setRoughLinesHandler = { [unowned self] _, _ in self.timeline.update() }
        
        canvas.player.didSetTimeHandler = { [unowned self] in
            self.playerEditor.time = self.scene.secondTime(withBeatTime: $0)
        }
        canvas.player.didSetCutIndexHandler = { [unowned self] in self.playerEditor.cutIndex = $0 }
        canvas.player.didSetPlayFrameRateHandler = { [unowned self] in
            if !self.canvas.player.isPause {
                self.playerEditor.playFrameRate = $0
            }
        }
        
        canvas.materialEditor.setMaterialHandler = { [unowned self] _, _ in
            self.sceneDataModel.isWrite = true
            self.canvas.setNeedsDisplay()
        }
        canvas.materialEditor.setMaterialWithCutItemHandler = { [unowned self] _, _, cutItem in
            if cutItem === self.canvas.cutItem {
                self.canvas.setNeedsDisplay()
            }
        }
        canvas.materialEditor.setIsEditingHandler = { [unowned self] (materialEditor, isEditing) in
            self.canvas.materialEditorType = isEditing ?
                .preview : (materialEditor.isSubIndication ? .selection : .none)
        }
        canvas.materialEditor.setIsSubIndicationHandler = {
            [unowned self] (materialEditor, isSubIndication) in
            
            self.canvas.materialEditorType = materialEditor.isEditing ?
                .preview : (isSubIndication ? .selection : .none)
        }
        canvas.setContentsScaleHandler = { [unowned self] _, contentsScale in
            self.rendererManager.rendingContentScale = contentsScale
        }
        
        playerEditor.timeBinding = { [unowned self] in
            switch $1 {
            case .begin:
                self.canvas.player.isPause = true
            case .sending:
                break
            case .end:
                self.canvas.player.isPause = false
            }
            self.canvas.player.currentPlayTime = self.scene.beatTime(withSecondTime: $0)
        }
        playerEditor.isPlayingBinding = { [unowned self] in
            if $0 {
                self.playerEditor.maxTime = self.scene.secondTime(withBeatTime: self.scene.duration)
                self.playerEditor.time = self.scene.secondTime(withBeatTime: self.scene.time)
                self.playerEditor.frameRate = self.scene.frameRate
                self.canvas.play()
            } else {
                self.playerEditor.time = self.scene.secondTime(withBeatTime: self.scene.time)
                self.playerEditor.frameRate = 0
                self.canvas.player.stop()
            }
        }
        
        soundEditor.setSoundHandler = { [unowned self] in
            self.scene.sound = $0.sound
            self.sceneDataModel.isWrite = true
            if self.scene.sound.url == nil && self.canvas.player.audioPlayer?.isPlaying ?? false {
                self.canvas.player.audioPlayer?.stop()
            }
        }
        
        versionEditor.undoManager = undoManager
        
        update(with: scene)
        
        cutsDataModel.insert(scene.cutItems[0].cutDataModel)
        dataModel = DataModel(key: SceneEditor.sceneEditorKey,
                              directoryWithDataModels: [sceneDataModel, cutsDataModel])
        sceneDataModel.dataHandler = { [unowned self] in self.scene.data }
        timeline.cutsDataModel = cutsDataModel
        timeline.sceneDataModel = sceneDataModel
        
        children = [nameLabel,
                    versionEditor, rendererManager.popupBox,
                    sizeEditor, frameRateSlider, baseTimeIntervalSlider, colorSpaceButton,
                    isShownPreviousButton, isShownNextButton,
                    transformEditor, wiggleEditor, soundEditor,
                    newNodeTrackButton, /*newCutButton, */newNodeButton,
                    changeToDraftButton, removeDraftButton, swapDraftButton,
                    splitColorBox, splitOtherThanColorBox,
                    showAllBox,
                    canvas.materialEditor, canvas.cellEditor,
                    timeline.keyframeEditor, timeline.nodeEditor,
                    timeline,
                    canvas,
                    playerEditor]
        update(withChildren: children, oldChildren: [])
        updateChildren()
    }
    
    static let rendererWidth = 80.0.cf, undoWidth = 120.0.cf
    static let canvasSize = CGSize(width: 730, height: 480)
    static let propertyWidth = MaterialEditor.colorEditorWidth + Layout.basicPadding * 2
    static let buttonsWidth = 120.0.cf, timelineWidth = 430.0.cf
    static let timelineButtonsWidth = 142.0.cf, timelineHeight = 120.0.cf
    func updateChildren() {
        let padding = Layout.basicPadding
        let buttonH = Layout.basicHeight
        let h = buttonH + padding * 2
        
        let cs = SceneEditor.canvasSize, th = SceneEditor.timelineHeight
        let width = cs.width + SceneEditor.propertyWidth + padding * 2
        let height = buttonH + h * 3 + th + cs.height + padding * 2
        let y = height - padding
        versionEditor.frame.size = CGSize(width: SceneEditor.undoWidth, height: buttonH)
        rendererManager.popupBox.frame.size = CGSize(width: SceneEditor.rendererWidth,
                                                     height: buttonH)
        
        nameLabel.frame.origin = CGPoint(x: padding, y: y - h + padding * 2)
        let properties: [Respondable] = [versionEditor, rendererManager.popupBox,
                                         sizeEditor,
                                         frameRateSlider, baseTimeIntervalSlider, colorSpaceButton]
        properties.forEach { $0.frame.size.height = h }
        _ = Layout.leftAlignment(properties, minX: nameLabel.frame.maxX + padding,
                                 y: y - h, height: h)
        
        Layout.autoHorizontalAlignment([isShownPreviousButton, isShownNextButton],
                                       in: CGRect(x: colorSpaceButton.frame.maxX,
                                                  y: y - h,
                                                  width: width - colorSpaceButton.frame.maxX
                                                    - padding,
                                                  height: h))
        
        let trw = transformEditor.editBounds.width
        transformEditor.frame = CGRect(x: padding + SceneEditor.propertyWidth,
                                       y: y - h * 2 - buttonH,
                                       width: trw, height: h)
        let ww = wiggleEditor.editBounds.width
        wiggleEditor.frame = CGRect(x: transformEditor.frame.maxX,
                                    y: y - h * 2 - buttonH,
                                    width: ww, height: h)
        soundEditor.frame = CGRect(x: wiggleEditor.frame.maxX,
                                   y: y - h * 2 - buttonH,
                                   width: cs.width - trw - ww, height: h)
        
        let buttons: [Respondable] = [newNodeTrackButton, /*newCutButton, */newNodeButton,
                                      changeToDraftButton, removeDraftButton, swapDraftButton]
        Layout.autoHorizontalAlignment(buttons, in: CGRect(x: padding + SceneEditor.propertyWidth,
                                                           y: y - h - buttonH,
                                                           width: cs.width,
                                                           height: buttonH))
        let keyframeHeight = 160.0.cf
        timeline.nodeEditor.frame = CGRect(x: padding,
                                           y: y - h * 2,
                                           width: SceneEditor.propertyWidth,
                                           height: h)
        timeline.keyframeEditor.frame = CGRect(x: padding,
                                               y: y - h * 2 - keyframeHeight,
                                               width: SceneEditor.propertyWidth,
                                               height: keyframeHeight)
        let ch = canvas.cellEditor.editBounds.height
        let mh = canvas.materialEditor.editBounds.height
        canvas.cellEditor.frame = CGRect(x: padding,
                                         y: y - h * 2 - keyframeHeight - ch,
                                         width: SceneEditor.propertyWidth,
                                         height: ch)
        canvas.materialEditor.frame = CGRect(x: padding,
                                             y: y - h * 2 - keyframeHeight - ch - mh,
                                             width: SceneEditor.propertyWidth,
                                             height: mh)
        splitColorBox.frame = CGRect(x: padding,
                                     y: y - h * 2 - keyframeHeight - ch - mh - buttonH,
                                     width: SceneEditor.propertyWidth,
                                     height: buttonH)
        splitOtherThanColorBox.frame = CGRect(x: padding,
                                              y: y - h * 2 - keyframeHeight - ch - mh - buttonH * 2,
                                              width: SceneEditor.propertyWidth,
                                              height: buttonH)
        showAllBox.frame = CGRect(x: padding,
                                  y: y - h * 2 - keyframeHeight - ch - mh - buttonH * 3,
                                  width: SceneEditor.propertyWidth,
                                  height: buttonH)
        
        timeline.frame = CGRect(x: padding + SceneEditor.propertyWidth,
                                y: y - h * 2 - buttonH - th,
                                width: cs.width, height: SceneEditor.timelineHeight)
        canvas.frame = CGRect(x: padding + SceneEditor.propertyWidth,
                              y: y - h * 2 - buttonH - th - cs.height,
                              width: cs.width, height: cs.height)
        playerEditor.frame = CGRect(x: padding + SceneEditor.propertyWidth,
                                    y: padding, width: cs.width, height: h)
        
        frame.size = CGSize(width: width, height: height)
    }
    
    func scroll(with event: ScrollEvent) {
        timeline.scroll(with: event)
    }
}


final class TransformEditor: LayerRespondable, Localizable {
    static let name = Localization(english: "Transform Editor", japanese: "トランスフォームエディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var locale = Locale.current {
        didSet {
            updateLayout()
        }
    }
    
    static let valueWidth = 50.0.cf
    static let labelFrame = CGRect(x: 0, y: Layout.basicPadding,
                                   width: 0, height: Layout.basicHeight)
    static let valueFrame = CGRect(x: 0, y: Layout.basicPadding,
                                   width: valueWidth, height: Layout.basicHeight)
    
    private let nameLabel = Label(text: Transform.name, font: .bold)
    private let xLabel = Label(text: Localization("x:"))
    private let yLabel = Label(text: Localization("y:"))
    private let zLabel = Label(text: Localization("z:"))
    private let thetaLabel = Label(text: Localization("θ:"))
    private let xSlider = NumberSlider(frame: TransformEditor.valueFrame,
                                       min: -10000, max: 10000, valueInterval: 0.01,
                                       description: Localization(english: "Translation x",
                                                                 japanese: "移動 x"))
    private let ySlider = NumberSlider(frame: TransformEditor.valueFrame,
                                       min: -10000, max: 10000, valueInterval: 0.01,
                                       description: Localization(english: "Translation y",
                                                                 japanese: "移動 y"))
    private let zSlider = NumberSlider(frame: TransformEditor.valueFrame,
                                       min: -20, max: 20, valueInterval: 0.01,
                                       description: Localization(english: "Translation z",
                                                                 japanese: "移動 z"))
    private let thetaSlider = NumberSlider(frame: TransformEditor.valueFrame,
                                           min: -10000, max: 10000, valueInterval: 0.5, unit: "°",
                                           description: Localization(english: "Angle",
                                                                     japanese: "角度"))
    let layer = CALayer.interface()
    init() {
        let children: [Respondable] = [nameLabel, xLabel, xSlider, yLabel, ySlider, zLabel, zSlider,
                                       thetaLabel, thetaSlider]
        self.children = children
        update(withChildren: children, oldChildren: [])
        xSlider.setValueHandler = { [unowned self] in self.setTransform(with: $0) }
        ySlider.setValueHandler = { [unowned self] in self.setTransform(with: $0) }
        zSlider.setValueHandler = { [unowned self] in self.setTransform(with: $0) }
        thetaSlider.setValueHandler = { [unowned self] in self.setTransform(with: $0) }
    }
    private func setTransform(with obj: NumberSlider.HandlerObject) {
        if obj.type == .begin {
            oldTransform = transform
            setTransformHandler?(HandlerObject(transformEditor: self,
                                               transform: oldTransform,
                                               oldTransform: oldTransform, type: .begin))
        } else {
            switch obj.slider {
            case xSlider:
                transform = transform.with(translation: CGPoint(x: obj.value * standardTranslation.x,
                                                                y: transform.translation.y))
            case ySlider:
                transform = transform.with(translation: CGPoint(x: transform.translation.x,
                                                                y: obj.value * standardTranslation.y))
            case zSlider:
                transform = transform.with(z: obj.value)
            case thetaSlider:
                transform = transform.with(rotation: obj.value * (.pi / 180))
            default:
                fatalError()
            }
            setTransformHandler?(HandlerObject(transformEditor: self,
                                               transform: transform,
                                               oldTransform: oldTransform, type: obj.type))
        }
    }
    
    var frame: CGRect {
        get {
            return layer.frame
        }
        set {
            layer.frame = newValue
            updateLayout()
        }
    }
    func updateLayout() {
        let children: [Respondable] = [nameLabel, Padding(),
                                       xLabel, xSlider, Padding(), yLabel, ySlider, Padding(),
                                       zLabel, zSlider, Padding(), thetaLabel, thetaSlider]
        _ = Layout.leftAlignment(children, height: frame.height)
    }
    var editBounds: CGRect {
        let children: [Respondable] = [nameLabel, Padding(),
                                       xLabel, xSlider, Padding(), yLabel, ySlider, Padding(),
                                       zLabel, zSlider, Padding(), thetaLabel, thetaSlider]
        return CGRect(x: 0,
                      y: 0,
                      width: Layout.leftAlignmentWidth(children) + Layout.basicPadding,
                      height: Layout.basicHeight)
    }
    
    var standardTranslation = CGPoint(x: 1, y: 1)
    
    var transform = Transform() {
        didSet {
            if transform != oldValue {
                updateChildren()
            }
        }
    }
//    func update() {
//        transform = scene.editCutItem.cut.editNode
//            .editTrack.transformItem?.transform ?? Transform()
//    }
    private func updateChildren() {
        xSlider.value = transform.translation.x / standardTranslation.x
        ySlider.value = transform.translation.y / standardTranslation.y
        zSlider.value = transform.z
        thetaSlider.value = transform.rotation * 180 / (.pi)
    }
    
    struct HandlerObject {
        let transformEditor: TransformEditor
        let transform: Transform, oldTransform: Transform, type: Action.SendType
    }
    var setTransformHandler: ((HandlerObject) -> ())?
    
//    private func registerUndo(_ handler: @escaping (TransformEditor, Beat) -> Void) {
//        undoManager?.registerUndo(withTarget: self) { [oldTime = scene.time] in
//            handler($0, oldTime)
//        }
//    }
    var isLocked = false {
        didSet {
            xSlider.isLocked = isLocked
            ySlider.isLocked = isLocked
            zSlider.isLocked = isLocked
            thetaSlider.isLocked = isLocked
        }
    }
    
    func copy(with event: KeyInputEvent) -> CopiedObject {
        return CopiedObject(objects: [transform])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        guard !isLocked else {
            return
        }
        for object in copiedObject.objects {
            if let transform = object as? Transform {
                guard transform != self.transform else {
                    continue
                }
                set(transform, oldTransform: self.transform)
                return
            }
        }
    }
    func delete(with event: KeyInputEvent) {
        guard !isLocked else {
            return
        }
        let transform = Transform()
        guard transform != self.transform else {
            return
        }
        set(transform, oldTransform: self.transform)
    }
    func set(_ transform: Transform, oldTransform: Transform) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.set(oldTransform, oldTransform: transform)
        }
        setTransformHandler?(HandlerObject(transformEditor: self,
                                           transform: oldTransform, oldTransform: oldTransform,
                                           type: .begin))
        self.transform = transform
        setTransformHandler?(HandlerObject(transformEditor: self,
                                           transform: transform, oldTransform: oldTransform,
                                           type: .end))
    }
//    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
//        for object in copiedObject.objects {
//            if let transform = object as? Transform {
//                let cutItem = scene.editCutItem
//                let track = cutItem.cut.editNode.editTrack
//                setTransform(transform, at: track.animation.editKeyframeIndex, in: track, cutItem)
//                return
//            }
//        }
//    }
    
    private var oldTransform = Transform()
//    private var keyIndex = 0, isMadeTransformItem = false
//    private weak var oldTransformItem: TransformItem?, track: NodeTrack?, cutItem: CutItem?
//    func changeValue(_ slider: NumberSlider,
//                     value: CGFloat, oldValue: CGFloat, type: Action.SendType) {
//
//        switch type {
//        case .begin:
//            let cutItem = scene.editCutItem
//            let track = cutItem.cut.editNode.editTrack
//            let t = transformWith(value: value, slider: slider, oldTransform: transform)
//            oldTransformItem = track.transformItem
//            if let transformItem = track.transformItem {
//                oldTransform = transformItem.transform
//                isMadeTransformItem = false
//            } else {
//                let transformItem = TransformItem.empty(with: track.animation)
//                setTransformItem(transformItem, in: track, cutItem)
//                oldTransform = transformItem.transform
//                isMadeTransformItem = true
//            }
//            self.track = track
//            self.cutItem = cutItem
//            keyIndex = track.animation.editKeyframeIndex
//            setTransform(t, at: keyIndex, in: track, cutItem)
//        case .sending:
//            if let track = track, let cutItem = cutItem {
//                let t = transformWith(value: value, slider: slider, oldTransform: transform)
//                setTransform(t, at: keyIndex, in: track, cutItem)
//            }
//        case .end:
//            if let track = track, let cutItem = cutItem {
//                let t = transformWith(value: value, slider: slider, oldTransform: transform)
//                setTransform(t, at: keyIndex, in: track, cutItem)
//                if let transformItem = track.transformItem {
//                    if transformItem.isEmpty {
//                        if isMadeTransformItem {
//                            setTransformItem(nil, in: track, cutItem)
//                        } else {
//                            setTransformItem(nil, oldTransformItem: oldTransformItem,
//                                             in: track, cutItem, time: scene.time)
//                        }
//                    } else {
//                        if isMadeTransformItem {
//                            setTransformItem(transformItem, oldTransformItem: oldTransformItem,
//                                             in: track, cutItem, time: scene.time)
//                        }
//                        if value != oldValue {
//                            setTransform(t, oldTransform: oldTransform, at: keyIndex,
//                                         in: track, cutItem, time: scene.time)
//                        } else {
//                            setTransform(oldTransform, at: keyIndex, in: track, cutItem)
//                        }
//                    }
//                }
//            }
//        }
//    }
//    var setTransformItemHandler: ((TransformEditor, TransformItem?) -> ())?
//    var setTransformHandler: ((TransformEditor, Transform, Int, NodeTrack, CutItem) -> ())?
//    private func setTransformItem(_ transformItem: TransformItem?,
//                                  in track: NodeTrack, _ cutItem: CutItem) {
//        track.transformItem = transformItem
//        setTransformItemHandler?(self, transformItem)
//    }
//    private func setTransform(_ transform: Transform, at index: Int,
//                              in track: NodeTrack, _ cutItem: CutItem) {
//        track.transformItem?.replaceTransform(transform, at: index)
//        cutItem.cut.editNode.updateTransform()
//        self.transform = transform
//        setTransformHandler?(self, transform, index, track, cutItem)
//    }
//    var setTimeHandler: ((TransformEditor, Beat) -> ())?
//    private func setTransformItem(_ transformItem: TransformItem?, oldTransformItem: TransformItem?,
//                                  in track: NodeTrack, _ cutItem: CutItem, time: Beat) {
//        registerUndo {
//            $0.setTransformItem(oldTransformItem, oldTransformItem: transformItem,
//                                in: track, cutItem, time: $1)
//        }
//        setTimeHandler?(self, time)
//
//        setTransformItem(transformItem, in: track, cutItem)
//        cutItem.cutDataModel.isWrite = true
//    }
//    private func setTransform(_ transform: Transform, oldTransform: Transform,
//                              at i: Int, in track: NodeTrack, _ cutItem: CutItem, time: Beat) {
//        registerUndo {
//            $0.setTransform(oldTransform, oldTransform: transform, at: i,
//                            in: track, cutItem, time: $1)
//        }
//        setTimeHandler?(self, time)
//
//        setTransform(transform, at: i, in: track, cutItem)
//        cutItem.cutDataModel.isWrite = true
//    }
}

final class WiggleEditor: LayerRespondable, Localizable {
    static let name = Localization(english: "Wiggle Editor", japanese: "振動エディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var locale = Locale.current {
        didSet {
            updateLayout()
        }
    }
    
    static let valueWidth = 50.0.cf
    static let labelFrame = CGRect(x: 0, y: Layout.basicPadding,
                                   width: 0, height: Layout.basicHeight)
    static let valueFrame = CGRect(x: 0, y: Layout.basicPadding,
                                   width: valueWidth, height: Layout.basicHeight)
    
    private let nameLabel = Label(text: Wiggle.name, font: .bold)
    private let xLabel = Label(text: Localization("x:"))
    private let yLabel = Label(text: Localization("y:"))
    private let xSlider = NumberSlider(frame: TransformEditor.valueFrame,
                                       min: 0, max: 1000, valueInterval: 0.01,
                                       description: Localization(english: "Amplitude x",
                                                                 japanese: "振幅 x"))
    private let ySlider = NumberSlider(frame: TransformEditor.valueFrame,
                                       min: 0, max: 1000, valueInterval: 0.01,
                                       description: Localization(english: "Amplitude y",
                                                                 japanese: "振幅 y"))
    private let frequencySlider = NumberSlider(frame: TransformEditor.valueFrame,
                                               min: 0.1, max: 100000, valueInterval: 0.1, unit: " Hz",
                                               description: Localization(english: "Frequency",
                                                                         japanese: "振動数"))
    let layer = CALayer.interface()
    init() {
        let children: [Respondable] = [nameLabel, xLabel, xSlider, yLabel, ySlider, frequencySlider]
        self.children = children
        update(withChildren: children, oldChildren: [])
        frequencySlider.defaultValue = wiggle.frequency
        frequencySlider.value = wiggle.frequency
        
        xSlider.setValueHandler = { [unowned self] in self.setWiggle(with: $0) }
        ySlider.setValueHandler = { [unowned self] in self.setWiggle(with: $0) }
        frequencySlider.setValueHandler = { [unowned self] in self.setWiggle(with: $0) }
    }
    private func setWiggle(with obj: NumberSlider.HandlerObject) {
        if obj.type == .begin {
            oldWiggle = wiggle
            setWiggleHandler?(HandlerObject(wiggleEditor: self,
                                            wiggle: oldWiggle,
                                            oldWiggle: oldWiggle, type: .begin))
        } else {
            switch obj.slider {
            case xSlider:
                wiggle = wiggle.with(amplitude: CGPoint(x: obj.value * standardAmplitude.x / 10,
                                                        y: wiggle.amplitude.y))
            case ySlider:
                wiggle = wiggle.with(amplitude: CGPoint(x: wiggle.amplitude.x,
                                                        y: obj.value * standardAmplitude.y / 10))
            case frequencySlider:
                wiggle = wiggle.with(frequency: obj.value)
            default:
                fatalError()
            }
        }

//
//            case xSlider:
//                transform = transform.with(translation: CGPoint(x: obj.value * standardTranslation.x,
//                                                                y: transform.translation.y))
//            case ySlider:
//                transform = transform.with(translation: CGPoint(x: transform.translation.x,
//                                                                y: obj.value * standardTranslation.y))
//            case zSlider:
//                transform = transform.with(z: obj.value)
//            case thetaSlider:
//                transform = transform.with(rotation: obj.value * (.pi / 180))
//            default:
//                fatalError()
//            }
//            setWiggleHandler?(HandlerObject(wiggleEditor: self,
//                                            wiggle: wiggle,
//                                            oldWiggle: oldWiggle, type: obj.type))
//        }
    }
    
    var isLocked = false {
        didSet {
            xSlider.isLocked = isLocked
            ySlider.isLocked = isLocked
            frequencySlider.isLocked = isLocked
        }
    }
    
    func updateLayout() {
        let children: [Respondable] = [nameLabel, Padding(), xLabel, xSlider, Padding(),
                                       yLabel, ySlider, frequencySlider]
        _ = Layout.leftAlignment(children, height: frame.height)
    }
    
    var standardAmplitude = CGPoint(x: 1, y: 1)
    
    var frame: CGRect {
        get {
            return layer.frame
        }
        set {
            layer.frame = newValue
            updateLayout()
        }
    }
    var editBounds: CGRect {
        let children: [Respondable] = [nameLabel, Padding(), xLabel, xSlider, Padding(),
                                       yLabel, ySlider, frequencySlider]
        return CGRect(x: 0,
                      y: 0,
                      width: Layout.leftAlignmentWidth(children) + Layout.basicPadding,
                      height: Layout.basicHeight)
    }
    
    var wiggle = Wiggle() {
        didSet {
            if wiggle != oldValue {
                updateChildren()
            }
        }
    }
    private func updateChildren() {
        xSlider.value = 10 * wiggle.amplitude.x / standardAmplitude.x
        ySlider.value = 10 * wiggle.amplitude.y / standardAmplitude.y
        frequencySlider.value = wiggle.frequency
    }
    
    struct HandlerObject {
        let wiggleEditor: WiggleEditor
        let wiggle: Wiggle, oldWiggle: Wiggle, type: Action.SendType
    }
    var setWiggleHandler: ((HandlerObject) -> ())?

    private var oldWiggle = Wiggle()
//keyIndex = 0, isMadeTransformItem = false
//    private weak var oldTransformItem: TransformItem?, track: NodeTrack?, cutItem: CutItem?
//    func changeValue(_ slider: NumberSlider,
//                     value: CGFloat, oldValue: CGFloat, type: Action.SendType) {
//
//        switch type {
//        case .begin:
//            let cutItem = scene.editCutItem
//            let track = cutItem.cut.editNode.editTrack
//            let t = transformWith(value: value, slider: slider, oldTransform: transform)
//            oldTransformItem = track.transformItem
//            if let transformItem = track.transformItem {
//                oldTransform = transformItem.transform
//                isMadeTransformItem = false
//            } else {
//                let transformItem = TransformItem.empty(with: track.animation)
//                setTransformItem(transformItem, in: track, cutItem)
//                oldTransform = transformItem.transform
//                isMadeTransformItem = true
//            }
//            self.track = track
//            self.cutItem = cutItem
//            keyIndex = track.animation.editKeyframeIndex
//            setTransform(t, at: keyIndex, in: track, cutItem)
//        case .sending:
//            if let track = track, let cutItem = cutItem {
//                let t = transformWith(value: value, slider: slider, oldTransform: transform)
//                setTransform(t, at: keyIndex, in: track, cutItem)
//            }
//        case .end:
//            if let track = track, let cutItem = cutItem {
//                let t = transformWith(value: value, slider: slider, oldTransform: transform)
//                setTransform(t, at: keyIndex, in: track, cutItem)
//                if let transformItem = track.transformItem {
//                    if transformItem.isEmpty {
//                        if isMadeTransformItem {
//                            setTransformItem(nil, in: track, cutItem)
//                        } else {
//                            setTransformItem(nil, oldTransformItem: oldTransformItem,
//                                             in: track, cutItem, time: scene.time)
//                        }
//                    } else {
//                        if isMadeTransformItem {
//                            setTransformItem(transformItem, oldTransformItem: oldTransformItem,
//                                             in: track, cutItem, time: scene.time)
//                        }
//                        if value != oldValue {
//                            setTransform(t, oldTransform: oldTransform, at: keyIndex,
//                                         in: track, cutItem, time: scene.time)
//                        } else {
//                            setTransform(oldTransform, at: keyIndex, in: track, cutItem)
//                        }
//                    }
//                }
//            }
//        }
//    }
//    private func transformWith(value: CGFloat, slider: NumberSlider,
//                               oldTransform t: Transform) -> Transform {
//        let b = scene.frame
//        switch slider {
//        case xSlider:
//            return t.with(translation: CGPoint(x: value * b.width, y: t.translation.y))
//        case ySlider:
//            return t.with(translation: CGPoint(x: t.translation.x, y: value * b.height))
//        case zSlider:
//            return t.with(z: value)
//        case thetaSlider:
//            return t.with(rotation: value * (.pi / 180))
//        case xSlider:
//            return t.with(wiggle: t.wiggle.with(amplitude: CGPoint(x: value * b.width / 10,
//                                                                   y: t.wiggle.amplitude.y)))
//        case ySlider:
//            return t.with(wiggle: t.wiggle.with(amplitude: CGPoint(x: t.wiggle.amplitude.x,
//                                                                   y: value * b.height / 10)))
//        case frequencySlider:
//            return t.with(wiggle: t.wiggle.with(frequency: value))
//        default:
//            return t
//        }
//    }
//    var setTransformItemHandler: ((TransformEditor, TransformItem?) -> ())?
//    var setTransformHandler: ((TransformEditor, Transform, Int, NodeTrack, CutItem) -> ())?
//    private func setTransformItem(_ transformItem: TransformItem?,
//                                  in track: NodeTrack, _ cutItem: CutItem) {
//        track.transformItem = transformItem
//        setTransformItemHandler?(self, transformItem)
//    }
//    private func setTransform(_ transform: Transform, at index: Int,
//                              in track: NodeTrack, _ cutItem: CutItem) {
//        track.transformItem?.replaceTransform(transform, at: index)
//        cutItem.cut.editNode.updateTransform()
//        self.transform = transform
//        setTransformHandler?(self, transform, index, track, cutItem)
//    }
//    var setTimeHandler: ((TransformEditor, Beat) -> ())?
//    private func setTransformItem(_ transformItem: TransformItem?, oldTransformItem: TransformItem?,
//                                  in track: NodeTrack, _ cutItem: CutItem, time: Beat) {
//        registerUndo {
//            $0.setTransformItem(oldTransformItem, oldTransformItem: transformItem,
//                                in: track, cutItem, time: $1)
//        }
//        setTimeHandler?(self, time)
//
//        setTransformItem(transformItem, in: track, cutItem)
//        cutItem.cutDataModel.isWrite = true
//    }
//    private func setTransform(_ transform: Transform, oldTransform: Transform,
//                              at i: Int, in track: NodeTrack, _ cutItem: CutItem, time: Beat) {
//        registerUndo {
//            $0.setTransform(oldTransform, oldTransform: transform, at: i,
//                            in: track, cutItem, time: $1)
//        }
//        setTimeHandler?(self, time)
//
//        setTransform(transform, at: i, in: track, cutItem)
//        cutItem.cutDataModel.isWrite = true
//    }
}

final class SoundEditor: LayerRespondable, Localizable {
    static let name = Localization(english: "Sound Editor", japanese: "サウンドエディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var locale = Locale.current {
        didSet {
            updateLayout()
        }
    }
    
    let nameLabel = Label(text: Localization(english: "Sound", japanese: "サウンド"), font: .bold)
    let soundLabel = Label(text: Localization(english: "Empty", japanese: "空"))
    let layer = CALayer.interface()
    init() {
        layer.masksToBounds = true
        soundLabel.defaultBorderColor = Color.border.cgColor
        children = [nameLabel, soundLabel]
        update(withChildren: children, oldChildren: [])
        updateLayout()
    }
    
    var sound = Sound() {
        didSet {
            soundLabel.localization = sound.url != nil ?
                Localization(sound.name) : Localization(english: "Empty", japanese: "空")
        }
    }
    
    var frame: CGRect {
        get {
            return layer.frame
        }
        set {
            layer.frame = newValue
            updateLayout()
        }
    }
    func updateLayout() {
        _ = Layout.leftAlignment([nameLabel, Padding(), soundLabel],
                                 height: frame.height)
    }
    
    var disabledRegisterUndo = false
    
    struct HandlerObject {
        let soundEditor: SoundEditor, sound: Sound, oldSound: Sound, type: Action.SendType
    }
    var setSoundHandler: ((HandlerObject) -> ())?
    
    func delete(with event: KeyInputEvent) {
        if sound.url != nil {
            set(Sound(), old: self.sound)
        }
    }
    func copy(with event: KeyInputEvent) -> CopiedObject {
        guard let url = sound.url else {
            return CopiedObject(objects: [sound])
        }
        return CopiedObject(objects: [sound, url])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        for object in copiedObject.objects {
            if let url = object as? URL, url.isConforms(uti: kUTTypeAudio as String) {
                var sound = Sound()
                sound.url = url
                set(sound, old: self.sound)
                return
            } else if let sound = object as? Sound {
                set(sound, old: self.sound)
                return
            }
        }
    }
    func set(_ sound: Sound, old oldSound: Sound) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldSound, old: sound) }
        setSoundHandler?(HandlerObject(soundEditor: self,
                                       sound: oldSound, oldSound: oldSound, type: .begin))
        self.sound = sound
        setSoundHandler?(HandlerObject(soundEditor: self,
                                       sound: sound, oldSound: oldSound, type: .end))
    }
    
//    var setURLHandler: ((SoundEditor, URL?) -> ())?
//
//    func setURL(_ url: URL?, name: String) {
//        undoManager?.registerUndo(withTarget: self) { [ou = scene.soundItem.url,
//            on = scene.soundItem.name] in
//            $0.setURL(ou, name: on)
//        }
//        scene.soundItem.url = url
//        scene.soundItem.name = name
//        updateSoundText(with: scene.soundItem, with: Locale.current)
//        setURLHandler?(self, url)
//    }
//    func updateSoundText(with soundItem: SoundItem, with locale: Locale) {
//        let nameString = soundItem.url != nil ?
//            soundItem.name : Localization(english: "Empty", japanese: "空").string(with: locale)
//        label.string =  soundString + nameString + ")"
//        label.frame.origin = CGPoint(x: Layout.basicPadding,
//                                     y: (frame.height - label.frame.height) / 2)
//    }
    
//    func show(with event: KeyInputEvent) {
//        if scene.soundItem.isHidden {
//            setIsHidden(false)
//        }
//    }
//    func hide(with event: KeyInputEvent) {
//        if !scene.soundItem.isHidden {
//            setIsHidden(true)
//        }
//    }
//    var setIsHiddenSoundHandler: ((SoundEditor, Bool) -> ())?
//    func setIsHidden(_ isHidden: Bool) {
//        undoManager?.registerUndo(withTarget: self) { [oh = scene.soundItem.isHidden] in
//            $0.setIsHidden(oh)
//        }
//        scene.soundItem.isHidden = isHidden
//
//        label.layer.opacity = isHidden ? 0.25 : 1
//        setIsHiddenSoundHandler?(self, isHidden)
//    }
}
