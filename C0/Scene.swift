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

/*
 # 0.3
 - セルと線を再設計
 - 線の描画を改善
 - 線の分割を改善
 - 点の追加、点の削除、点の移動と線の変形、スナップを再設計
 - 線端の傾きスナップ実装
 - セルの追加時の線の置き換え、編集セルを廃止
 - マテリアルのコピーによるバインドを廃止
 - 変形、歪曲の再設計
 - コマンドを整理
 - コピー表示、取り消し表示
 - シーン設定
 - 書き出し表示修正
 - すべてのインディケーション表示
 - マテリアルの合成機能修正
 - Display P3サポート
 - キーフレームラベルの導入
 - キャンバス上でのスクロール時間移動
 - キャンバスの選択修正
 - 「すべてを選択」「すべてを選択解除」アクションを追加
 - インディケーション再生
 - テキスト設計やGUIの基礎設計を修正
 - キーフレームの複数選択に対応
 - Swift4 (Codableを部分的に導入)
 - サウンドの書き出し
 - 最終キーフレームの継続時間を保持
 - マテリアルの線の色の自由化
 - 正三角形、正方形、正五角形、正六角形、円の追加
 - プロパティの表示修正
 △ ビートタイムライン
 △ ノード導入
 △ カット単位での読み込み、保存
 △ スナップスクロール
 △ ストローク修正、スローの廃止
 △ セルペーストエディタ
 */

import Foundation

typealias BPM = Int
typealias FPS = Int
typealias CPB = Int
typealias FrameTime = Int
typealias BaseTime = Q
typealias Beat = Q
typealias DoubleBaseTime = Double
typealias DoubleBeat = Double
typealias Second = Double

/**
 # Issue
 - 字幕
 - 複数のサウンド
 - 変更通知
 */
final class Scene: NSObject, NSCoding {
    var name: String
    var frame: CGRect, frameRate: FPS, baseTimeInterval: Beat, tempo: BPM
    var colorSpace: ColorSpace {
        didSet {
            self.materials = materials.map { $0.with($0.color.with(colorSpace: colorSpace)) }
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
    
    var tempoTrack: TempoTrack
    var cutItems: [CutItem] {
        didSet {
            updateCutTimeAndDuration()
        }
    }
    var editCutItemIndex: Int
    
    var time: Beat {
        didSet {
            tempo = tempoTrack.tempoItem.tempo
        }
    }
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
         tempoTrack: TempoTrack = TempoTrack(),
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
        self.tempoTrack = tempoTrack
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
        editMaterial, materials, isShownPrevious, isShownNext, sound, viewTransform, tempoTrack,
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
        tempoTrack = coder.decodeObject(
            forKey: CodingKeys.tempoTrack.rawValue) as? TempoTrack ?? TempoTrack()
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
        coder.encode(tempoTrack, forKey: CodingKeys.tempoTrack.rawValue)
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


final class SceneEditor: Layer, Respondable, Localizable {
    static let name = Localization(english: "Scene Editor", japanese: "シーンエディタ")
    
    var locale = Locale.current {
        didSet {
            updateLayout()
        }
    }
    
    var scene = Scene() {
        didSet {
            updateWithScene()
        }
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
    
    static let sceneEditorKey = "sceneEditor", sceneKey = "scene", cutsKey = "cuts"
    var sceneDataModel = DataModel(key: SceneEditor.sceneKey)
    var cutsDataModel = DataModel(key: SceneEditor.cutsKey, directoryWithDataModels: [])
    override var dataModel: DataModel? {
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
            updateWithScene()
        }
    }
    
    static let valueWidth = 56.cf, colorSpaceWidth = 82.cf
    static let valueFrame = CGRect(x: 0, y: Layout.basicPadding,
                                   width: valueWidth, height: Layout.basicHeight)
    static let colorSpaceFrame = CGRect(x: 0, y: Layout.basicPadding,
                                        width: colorSpaceWidth, height: Layout.basicHeight)
    static let rendererWidth = 80.0.cf, undoWidth = 120.0.cf
    static let canvasSize = CGSize(width: 730, height: 480)
    static let propertyWidth = MaterialEditor.defaultWidth + Layout.basicPadding * 2
    static let buttonsWidth = 120.0.cf, timelineWidth = 430.0.cf
    static let timelineButtonsWidth = 142.0.cf, timelineHeight = 120.0.cf
    
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
    
    let shapeLinesBox = PopupBox(frame: CGRect(x: 0, y: 0, width: 100.0, height: Layout.basicHeight),
                                 text: Localization(english: "Shape Lines", japanese: "図形の線"))
    let newNodeTrackButton = Button(name: Localization(english: "New Node Track",
                                                       japanese: "新規ノードトラック"))
    let newNodeButton = Button(name: Localization(english: "New Node", japanese: "新規ノード"))
    let changeToDraftButton = Button(name: Localization(english: "Change to Draft",
                                                        japanese: "下書き化"))
    let removeDraftButton = Button(name: Localization(english: "Remove Draft", japanese: "下書きを削除"))
    let swapDraftButton = Button(name: Localization(english: "Swap Draft", japanese: "下書きと交換"))
    
    let showAllBox = Button(name: Localization(english: "Unlock All Cells", japanese: "すべてのセルのロックを解除"))
    let clipCellInSelectionBox = Button(name: Localization(english: "Clip Cell in Selection",
                                                           japanese: "セルを選択の中へクリップ"))
    let splitColorBox = Button(name: Localization(english: "Split Color", japanese: "カラーを分割"))
    let splitOtherThanColorBox = Button(name: Localization(english: "Split Material",
                                                           japanese: "マテリアルを分割"))
    
    let timeBindingLineLayer: PathLayer = {
        let layer = PathLayer()
        layer.lineWidth = 5
        layer.lineColor = .border
        return layer
    } ()
    let transformEditor = TransformEditor()
    let wiggleEditor = WiggleEditor()
    let soundEditor = SoundEditor()
    
    let timeline = Timeline()
    let canvas = Canvas()
    let playerEditor = PlayerEditor()
    
    let materialManager = SceneMaterialManager()
    
    override init() {
        cutsDataModel.insert(scene.cutItems[0].cutDataModel)
        
        super.init()
        materialManager.sceneEditor = self
        dataModel = DataModel(key: SceneEditor.sceneEditorKey,
                              directoryWithDataModels: [sceneDataModel, cutsDataModel])
        timeline.cutsDataModel = cutsDataModel
        timeline.sceneDataModel = sceneDataModel
        
        replace(children: [nameLabel,
                           versionEditor, rendererManager.popupBox,
                           sizeEditor, frameRateSlider, baseTimeIntervalSlider, colorSpaceButton,
                           timeBindingLineLayer,
                           isShownPreviousButton, isShownNextButton,
                           transformEditor, wiggleEditor, soundEditor,
                           shapeLinesBox, newNodeTrackButton, newNodeButton,
                           changeToDraftButton, removeDraftButton, swapDraftButton,
                           showAllBox, clipCellInSelectionBox, splitColorBox, splitOtherThanColorBox,
                           canvas.editCellBindingLineLayer,
                           canvas.materialEditor, canvas.cellEditor,
                           timeline.keyframeEditor, timeline.nodeEditor,
                           timeline,
                           canvas,
                           playerEditor])
        
        sceneDataModel.dataHandler = { [unowned self] in self.scene.data }
        
        versionEditor.rootUndoManager = rootUndoManager
        rendererManager.progressesEdgeLayer = self
        sizeEditor.binding = { [unowned self] in
            self.scene.frame = CGRect(origin: CGPoint(x: -$0.size.width / 2,
                                                      y: -$0.size.height / 2), size: $0.size)
            self.canvas.setNeedsDisplay()
            let sp = CGPoint(x: self.scene.frame.width, y: self.scene.frame.height)
            self.transformEditor.standardTranslation = sp
            self.wiggleEditor.standardAmplitude = sp
            if $0.type == .end && $0.size != $0.oldSize {
                self.sceneDataModel.isWrite = true
            }
        }
        frameRateSlider.binding = { [unowned self] in
            self.scene.frameRate = Int($0.value)
            if $0.type == .end && $0.value != $0.oldValue {
                self.sceneDataModel.isWrite = true
            }
        }
        baseTimeIntervalSlider.binding = { [unowned self] in
            if $0.type == .begin {
                self.baseTimeIntervalOldTime = self.scene.secondTime(withBeatTime: self.scene.time)
            }
            self.scene.baseTimeInterval.q = Int($0.value)
            self.timeline.time = self.scene.beatTime(withSecondTime: self.baseTimeIntervalOldTime)
            self.timeline.baseTimeInterval = self.scene.baseTimeInterval
            if $0.type == .end && $0.value != $0.oldValue {
                self.sceneDataModel.isWrite = true
            }
        }
        colorSpaceButton.setIndexHandler = { [unowned self] in
            self.scene.colorSpace = $0.index == 0 ? .sRGB : .displayP3// X
            self.canvas.setNeedsDisplay()
            if $0.type == .end && $0.index != $0.oldIndex {
                self.sceneDataModel.isWrite = true
            }
        }
        isShownPreviousButton.setIndexHandler = { [unowned self] in
            self.canvas.isShownPrevious = $0.index == 1
            if $0.type == .end && $0.index != $0.oldIndex {
                self.sceneDataModel.isWrite = true
            }
        }
        isShownNextButton.setIndexHandler = { [unowned self] in
            self.canvas.isShownNext = $0.index == 1
            if $0.type == .end && $0.index != $0.oldIndex {
                self.sceneDataModel.isWrite = true
            }
        }
        
        shapeLinesBox.panel.replace(
            children: [
                Button(name: Localization(english: "Append Triangle Lines",
                                          japanese: "正三角形の線を追加"),
                       isLeftAlignment: true,
                       runHandler: { [unowned self] _ in
                        self.canvas.appendTriangleLines()
                        return true
                }),
                Button(name: Localization(english: "Append Square Lines",
                                          japanese: "正方形の線を追加"),
                       isLeftAlignment: true,
                       runHandler: { [unowned self] _ in
                        self.canvas.appendSquareLines()
                        return true
                }),
                Button(name: Localization(english: "Append Pentagon Lines",
                                          japanese: "正五角形の線を追加"),
                       isLeftAlignment: true,
                       runHandler: { [unowned self] _ in
                        self.canvas.appendPentagonLines()
                        return true
                }),
                Button(name: Localization(english: "Append Hexagon Lines",
                                          japanese: "正六角形の線を追加"),
                       isLeftAlignment: true,
                       runHandler: { [unowned self] _ in
                        self.canvas.appendHexagonLines()
                        return true
                }),
                Button(name: Localization(english: "Append Circle Lines",
                                          japanese: "円の線を追加"),
                       isLeftAlignment: true,
                       runHandler: { [unowned self] _ in
                        self.canvas.appendCircleLines()
                        return true
                })
            ]
        )
        var minSize = CGSize()
        Layout.topAlignment(shapeLinesBox.panel.children, minSize: &minSize)
        shapeLinesBox.panel.frame.size = CGSize(width: minSize.width + Layout.basicPadding * 2,
                                                height: minSize.height + Layout.basicPadding * 2)
        
        newNodeTrackButton.runHandler = { [unowned self] _ in
            self.timeline.newNodeTrack()
            return true
        }
        newNodeButton.runHandler = { [unowned self] _ in
            self.timeline.newNode()
            return true
        }
        changeToDraftButton.runHandler = { [unowned self] _ in
            self.canvas.changeToRough()
            return true
        }
        removeDraftButton.runHandler = { [unowned self] _ in
            self.canvas.removeRough()
            return true
        }
        swapDraftButton.runHandler = { [unowned self] _ in
            self.canvas.swapRough()
            return true
        }
        
        showAllBox.runHandler = { [unowned self] _ in
            self.canvas.editShowInNode()
            return true
        }
        clipCellInSelectionBox.runHandler = { [unowned self] _ in
            self.canvas.clipCellInSelection()
            return true
        }
        splitColorBox.runHandler = { [unowned self] _ in
            self.materialManager.splitColor()
            return true
        }
        splitOtherThanColorBox.runHandler = { [unowned self] _ in
            self.materialManager.splitOtherThanColor()
            return true
        }
        
        transformEditor.setTransformHandler = { [unowned self] in
            self.set($0.transform, old: $0.oldTransform, type: $0.type)
        }
        wiggleEditor.setWiggleHandler = { [unowned self] in
            self.set($0.wiggle, old: $0.oldWiggle, type: $0.type)
        }
        
        timeline.scrollHandler = { [unowned self] (timeline, scrollPoint, event) in
            if event.sendType == .begin && self.canvas.player.isPlaying {
                self.canvas.player.opacity = 0.2
            } else if event.sendType == .end && self.canvas.player.opacity != 1 {
                self.canvas.player.opacity = 1
            }
            
            let isInterpolated =
                self.scene.editCutItem.cut.editNode.editTrack.animation.isInterpolated
            self.transformEditor.isLocked = isInterpolated
            self.wiggleEditor.isLocked = isInterpolated
            
            self.playerEditor.time = self.scene.secondTime(withBeatTime: self.time)
            self.playerEditor.cutIndex = self.scene.editCutItemIndex
        }
        timeline.setSceneDurationHandler = { [unowned self] in
            self.playerEditor.maxTime = self.scene.secondTime(withBeatTime: $1)
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
        
        timeline.nodeEditor.setIsHiddenHandler = { [unowned self] in
            self.setIsHiddenInNode(with: $0)
        }
        timeline.keyframeEditor.binding = { [unowned self] in
            self.setKeyframe(with: $0)
        }
        
        canvas.setTimeHandler = { [unowned self] _, time in self.timeline.time = time }
        canvas.updateSceneHandler = { [unowned self] _ in self.sceneDataModel.isWrite = true }
        canvas.setRoughLinesHandler = { [unowned self] _, _ in
            self.timeline.editCutEditor.updateChildren()
        }
        canvas.setContentsScaleHandler = { [unowned self] _, contentsScale in
            self.rendererManager.rendingContentScale = contentsScale
        }
        canvas.pasteColorBinding = { [unowned self] in
            self.materialManager.paste($1, in: $2)
        }
        canvas.pasteMaterialBinding = { [unowned self] in
            self.materialManager.paste($1, in: $2)
        }
        
        canvas.cellEditor.setIsTranslucentLockHandler = { [unowned self] in
            self.setIsTranslucentLockInCell(with: $0)
        }
        
        canvas.materialEditor.isEditingBinding = { [unowned self] (materialditor, isEditing) in
            self.canvas.materialEditorType = isEditing ?
                .preview : (materialditor.isSubIndicated ? .selection : .none)
        }
        canvas.materialEditor.isSubIndicatedBinding = {
            [unowned self] (materialEditor, isSubIndicated) in
            
            self.canvas.materialEditorType = materialEditor.isEditing ?
                .preview : (isSubIndicated ? .selection : .none)
        }
        
        canvas.player.didSetTimeHandler = { [unowned self] in
            self.playerEditor.time = self.scene.secondTime(withBeatTime: $0)
        }
        canvas.player.didSetCutIndexHandler = { [unowned self] in self.playerEditor.cutIndex = $0 }
        canvas.player.didSetPlayFrameRateHandler = { [unowned self] in
            if !self.canvas.player.isPause {
                self.playerEditor.playFrameRate = $0
            }
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
                self.playerEditor.cutIndex = self.scene.editCutItemIndex
                self.playerEditor.frameRate = 0
                self.canvas.player.stop()
            }
        }
        
        soundEditor.setSoundHandler = { [unowned self] in
            self.scene.sound = $0.sound
            if $0.type == .end && $0.sound != $0.oldSound {
                self.sceneDataModel.isWrite = true
            }
            if self.scene.sound.url == nil && self.canvas.player.audioPlayer?.isPlaying ?? false {
                self.canvas.player.audioPlayer?.stop()
            }
        }
        
        updateWithScene()
        updateLayout()
    }
    
    private func updateLayout() {
        let padding = Layout.basicPadding
        let buttonH = Layout.basicHeight
        let h = buttonH + padding * 2
        
        let cs = SceneEditor.canvasSize, th = SceneEditor.timelineHeight
        let width = cs.width + SceneEditor.propertyWidth + padding * 3
        let height = buttonH + h * 3 + th + cs.height + padding * 4
        let y = height - padding
        versionEditor.frame.size = CGSize(width: SceneEditor.undoWidth, height: buttonH)
        rendererManager.popupBox.frame.size = CGSize(width: SceneEditor.rendererWidth,
                                                     height: buttonH)
        
        nameLabel.frame.origin = CGPoint(x: padding, y: y - h + padding * 2)
        let properties: [Layer] = [versionEditor, rendererManager.popupBox, sizeEditor,
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
        
        let trw = transformEditor.defaultBounds.width, ww = wiggleEditor.defaultBounds.width
        soundEditor.frame = CGRect(x: padding,
                                   y: y - h * 2 - padding,
                                   width: cs.width - trw - ww, height: h)
        transformEditor.frame = CGRect(x: soundEditor.frame.maxX + padding,
                                       y: y - h * 2 - padding,
                                       width: trw, height: h)
        wiggleEditor.frame = CGRect(x: transformEditor.frame.maxX,
                                    y: y - h * 2 - padding,
                                    width: ww, height: h)
        
        let buttons = [shapeLinesBox, newNodeTrackButton, newNodeButton,
                       changeToDraftButton, removeDraftButton, swapDraftButton]
        Layout.autoHorizontalAlignment(buttons, in: CGRect(x: padding,
                                                           y: y - h * 2 - buttonH - padding * 2,
                                                           width: cs.width,
                                                           height: buttonH))
        let kh = 160.0.cf
        let propertyX = padding * 2 + cs.width, propertyMaxY = y - h - padding
        timeline.nodeEditor.frame = CGRect(x: propertyX,
                                           y: propertyMaxY - h,
                                           width: SceneEditor.propertyWidth,
                                           height: h)
        timeline.keyframeEditor.frame = CGRect(x: propertyX,
                                               y: propertyMaxY - h - kh,
                                               width: SceneEditor.propertyWidth,
                                               height: kh)
        let ch = canvas.cellEditor.defaultBounds.height
        let mh = canvas.materialEditor.defaultBounds.height
        let canvasPropertyMaxY = propertyMaxY - h - kh - padding
        
        canvas.cellEditor.frame = CGRect(x: propertyX,
                                         y: canvasPropertyMaxY - ch,
                                         width: SceneEditor.propertyWidth,
                                         height: ch)
        showAllBox.frame = CGRect(x: propertyX,
                                  y: canvasPropertyMaxY - ch - buttonH,
                                  width: SceneEditor.propertyWidth,
                                  height: buttonH)
        clipCellInSelectionBox.frame = CGRect(x: propertyX,
                                              y: canvasPropertyMaxY - ch - buttonH * 2,
                                              width: SceneEditor.propertyWidth,
                                              height: buttonH)
        
        canvas.materialEditor.frame = CGRect(x: propertyX,
                                             y: canvasPropertyMaxY - ch - buttonH * 2 - mh,
                                             width: SceneEditor.propertyWidth,
                                             height: mh)
        splitColorBox.frame = CGRect(x: propertyX,
                                     y: canvasPropertyMaxY - ch - mh - buttonH * 3,
                                     width: SceneEditor.propertyWidth,
                                     height: buttonH)
        splitOtherThanColorBox.frame = CGRect(x: propertyX,
                                              y: canvasPropertyMaxY - ch - mh - buttonH * 4,
                                              width: SceneEditor.propertyWidth,
                                              height: buttonH)
        
        timeline.frame = CGRect(x: padding,
                                y: y - h * 2 - buttonH - th - padding * 2,
                                width: cs.width, height: SceneEditor.timelineHeight)
        canvas.frame = CGRect(x: padding,
                              y: y - h * 2 - buttonH - th - cs.height - padding * 2,
                              width: cs.width, height: cs.height)
        playerEditor.frame = CGRect(x: padding, y: padding, width: cs.width, height: h)
        
        let timeBindingPath = CGMutablePath()
        timeBindingPath.move(to: CGPoint(x: timeline.frame.maxX, y: timeline.frame.midY))
        timeBindingPath.addLine(to: CGPoint(x: propertyX, y: timeline.frame.midY))
        timeBindingLineLayer.path = timeBindingPath
        
        let editCellBindingPath = CGMutablePath()
        editCellBindingPath.move(to: CGPoint(x: canvas.frame.maxX, y: canvas.frame.midY))
        editCellBindingPath.addLine(to: CGPoint(x: propertyX, y: canvas.frame.midY))
        canvas.editCellBindingLineLayer.path = editCellBindingPath
        
        frame.size = CGSize(width: width, height: height)
    }
    private func updateWithScene() {
        materialManager.scene = scene
        rendererManager.scene = scene
        timeline.scene = scene
        canvas.scene = scene
        sizeEditor.size = scene.frame.size
        frameRateSlider.value = scene.frameRate.cf
        baseTimeIntervalSlider.value = scene.baseTimeInterval.q.cf
        colorSpaceButton.selectionIndex = scene.colorSpace == .sRGB ? 0 : 1
        isShownPreviousButton.selectionIndex = scene.isShownPrevious ? 1 : 0
        isShownNextButton.selectionIndex = scene.isShownNext ? 1 : 0
        transformEditor.standardTranslation = CGPoint(x: scene.frame.width, y: scene.frame.height)
        soundEditor.sound = scene.sound
        if let transform = scene.editCutItem.cut.editNode.editTrack.transformItem?.transform {
            transformEditor.transform = transform
        }
        if let wiggle = scene.editCutItem.cut.editNode.editTrack.wiggleItem?.wiggle {
            wiggleEditor.wiggle = wiggle
        }
        transformEditor.isLocked = scene.editCutItem.cut.editNode.editTrack.animation.isInterpolated
        wiggleEditor.isLocked = scene.editCutItem.cut.editNode.editTrack.animation.isInterpolated
        playerEditor.time = scene.secondTime(withBeatTime: scene.time)
        playerEditor.cutIndex = scene.editCutItemIndex
        playerEditor.maxTime = scene.secondTime(withBeatTime: scene.duration)
    }
    
    var time: Beat {
        get {
            return timeline.time
        }
        set {
            if newValue != time {
                timeline.time = newValue
                sceneDataModel.isWrite = true
                playerEditor.time = scene.secondTime(withBeatTime: newValue)
                canvas.updateEditCellBinding()
            }
        }
    }
    
    var rootUndoManager = UndoManager()
    override var undoManager: UndoManager? {
        return rootUndoManager
    }
    
    private func registerUndo(time: Beat, _ handler: @escaping (SceneEditor, Beat) -> Void) {
        undoManager?.registerUndo(withTarget: self) { [oldTime = self.time] in
            handler($0, oldTime)
        }
        self.time = time
    }
    
    private var baseTimeIntervalOldTime = Second(0)
    
    private func setKeyframe(with obj: KeyframeEditor.Binding) {
        switch obj.type {
        case .begin:
            let cutEditor = timeline.editCutEditor
            let track = cutEditor.cutItem.cut.editNode.editTrack
            self.cutEditor = cutEditor
            self.track = track
            keyframeIndex = track.animation.editKeyframeIndex
        case .sending:
            guard let track = track, let cutEditor = cutEditor else {
                return
            }
            set(obj.keyframe, at: keyframeIndex, in: track, in: cutEditor)
        case .end:
            guard let track = track, let cutEditor = cutEditor else {
                    return
            }
            if obj.keyframe != obj.oldKeyframe {
                set(obj.keyframe, old: obj.oldKeyframe, at: keyframeIndex,
                    in: track, in: cutEditor, time: scene.time)
            } else {
                set(obj.oldKeyframe, at: keyframeIndex, in: track, in: cutEditor)
            }
        }
    }
    private func set(_ keyframe: Keyframe, at index: Int,
                     in track: NodeTrack, in cutEditor: CutEditor) {
        track.replace(keyframe, at: index)
        cutEditor.animationEditor.animation = track.animation
        cutEditor.updateChildren()
        canvas.setNeedsDisplay()
    }
    private func set(_ keyframe: Keyframe, old oldKeyframe: Keyframe,
                     at index: Int, in track: NodeTrack, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldKeyframe, old: keyframe, at: index, in: track, in: cutEditor, time: $1)
        }
        set(keyframe, at: index, in: track, in: cutEditor)
        cutEditor.cutItem.cutDataModel.isWrite = true
    }
    
    private var keyframeIndex = 0, isMadeTransformItem = false
    private weak var oldTransformItem: TransformItem?, track: NodeTrack?, cutEditor: CutEditor?
    func set(_ transform: Transform, old oldTransform: Transform, type: Action.SendType) {
        switch type {
        case .begin:
            let cutEditor = timeline.editCutEditor
            let track = cutEditor.cutItem.cut.editNode.editTrack
            oldTransformItem = track.transformItem
            if track.transformItem != nil {
                isMadeTransformItem = false
            } else {
                let transformItem = TransformItem.empty(with: track.animation)
                set(transformItem, in: track, in: cutEditor)
                isMadeTransformItem = true
            }
            self.cutEditor = cutEditor
            self.track = track
            keyframeIndex = track.animation.editKeyframeIndex
            
            set(transform, at: keyframeIndex, in: track, in: cutEditor)
        case .sending:
            guard let track = track, let cutEditor = cutEditor else {
                return
            }
            set(transform, at: keyframeIndex, in: track, in: cutEditor)
        case .end:
            guard let track = track, let cutEditor = cutEditor,
                let transformItem = track.transformItem else {
                    return
            }
            set(transform, at: keyframeIndex, in: track, in: cutEditor)
            if transformItem.isEmpty {
                if isMadeTransformItem {
                    set(TransformItem?.none, in: track, in: cutEditor)
                } else {
                    set(TransformItem?.none,
                        old: oldTransformItem, in: track, in: cutEditor, time: time)
                }
            } else {
                if isMadeTransformItem {
                    set(transformItem, old: oldTransformItem,
                        in: track, in: cutEditor, time: scene.time)
                }
                if transform != oldTransform {
                    set(transform, old: oldTransform, at: keyframeIndex,
                        in: track, in: cutEditor, time: scene.time)
                } else {
                    set(oldTransform, at: keyframeIndex, in: track, in: cutEditor)
                }
            }
        }
    }
    private func set(_ transformItem: TransformItem?, in track: NodeTrack, in cutEditor: CutEditor) {
        track.transformItem = transformItem
        cutEditor.updateChildren()
    }
    private func set(_ transformItem: TransformItem?, old oldTransformItem: TransformItem?,
                     in track: NodeTrack, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldTransformItem, old: transformItem, in: track, in: cutEditor, time: $1)
        }
        set(transformItem, in: track, in: cutEditor)
        cutEditor.cutItem.cutDataModel.isWrite = true
    }
    private func set(_ transform: Transform, at index: Int,
                     in track: NodeTrack, in cutEditor: CutEditor) {
        track.transformItem?.replace(transform, at: index)
        cutEditor.cutItem.cut.editNode.updateTransform()
        cutEditor.updateChildren()
        canvas.setNeedsDisplay()
    }
    private func set(_ transform: Transform, old oldTransform: Transform,
                     at index: Int, in track: NodeTrack, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldTransform, old: transform, at: index, in: track, in: cutEditor, time: $1)
        }
        set(transform, at: index, in: track, in: cutEditor)
        cutEditor.cutItem.cutDataModel.isWrite = true
    }
    
    private var isMadeWiggleItem = false
    private weak var oldWiggleItem: WiggleItem?
    func set(_ wiggle: Wiggle, old oldWiggle: Wiggle, type: Action.SendType) {
        switch type {
        case .begin:
            let cutEditor = timeline.editCutEditor
            let track = cutEditor.cutItem.cut.editNode.editTrack
            oldWiggleItem = track.wiggleItem
            if track.wiggleItem != nil {
                isMadeWiggleItem = false
            } else {
                let wiggleItem = WiggleItem.empty(with: track.animation)
                set(wiggleItem, in: track, in: cutEditor)
                isMadeWiggleItem = true
            }
            self.cutEditor = cutEditor
            self.track = track
            keyframeIndex = track.animation.editKeyframeIndex
            
            set(wiggle, at: keyframeIndex, in: track, in: cutEditor)
        case .sending:
            guard let track = track, let cutEditor = cutEditor else {
                return
            }
            set(wiggle, at: keyframeIndex, in: track, in: cutEditor)
        case .end:
            guard let track = track, let cutEditor = cutEditor,
                let wiggleItem = track.wiggleItem else {
                    return
            }
            set(wiggle, at: keyframeIndex, in: track, in: cutEditor)
            if wiggleItem.isEmpty {
                if isMadeWiggleItem {
                    set(WiggleItem?.none, in: track, in: cutEditor)
                } else {
                    set(WiggleItem?.none,
                        old: oldWiggleItem, in: track, in: cutEditor, time: time)
                }
            } else {
                if isMadeWiggleItem {
                    set(wiggleItem, old: oldWiggleItem,
                        in: track, in: cutEditor, time: scene.time)
                }
                if wiggle != oldWiggle {
                    set(wiggle, old: oldWiggle, at: keyframeIndex,
                        in: track, in: cutEditor, time: scene.time)
                } else {
                    set(oldWiggle, at: keyframeIndex, in: track, in: cutEditor)
                }
            }
        }
    }
    private func set(_ wiggleItem: WiggleItem?, in track: NodeTrack, in cutEditor: CutEditor) {
        track.wiggleItem = wiggleItem
        cutEditor.updateChildren()
    }
    private func set(_ wiggleItem: WiggleItem?, old oldWiggleItem: WiggleItem?,
                     in track: NodeTrack, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldWiggleItem, old: wiggleItem, in: track, in: cutEditor, time: $1)
        }
        set(wiggleItem, in: track, in: cutEditor)
        cutEditor.cutItem.cutDataModel.isWrite = true
    }
    private func set(_ wiggle: Wiggle, at index: Int,
                     in track: NodeTrack, in cutEditor: CutEditor) {
        track.wiggleItem?.replace(wiggle, at: index)
        cutEditor.cutItem.cut.editNode.updateWiggle()
        canvas.setNeedsDisplay()
    }
    private func set(_ wiggle: Wiggle, old oldWiggle: Wiggle,
                     at index: Int, in track: NodeTrack, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldWiggle, old: wiggle, at: index, in: track, in: cutEditor, time: $1)
        }
        set(wiggle, at: index, in: track, in: cutEditor)
        cutEditor.cutItem.cutDataModel.isWrite = true
    }
    
    private func setIsHiddenInNode(with obj: NodeEditor.Binding) {
        switch obj.type {
        case .begin:
            self.cutEditor = timeline.editCutEditor
        case .sending:
            canvas.setNeedsDisplay()
            cutEditor?.updateChildren()
        case .end:
            guard let cutEditor = cutEditor else {
                return
            }
            
            if obj.isHidden != obj.oldIsHidden {
                set(isHidden: obj.isHidden,
                    oldIsHidden: obj.oldIsHidden,
                    in: obj.inNode, in: cutEditor, time: time)
            } else {
                canvas.setNeedsDisplay()
                cutEditor.updateChildren()
            }
        }
    }
    private func set(isHidden: Bool, oldIsHidden: Bool,
                     in node: Node, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) {
            $0.set(isHidden: oldIsHidden, oldIsHidden: isHidden, in: node, in: cutEditor, time: $1)
        }
        node.isHidden = isHidden
        canvas.setNeedsDisplay()
        cutEditor.updateChildren()
        cutEditor.cutItem.cutDataModel.isWrite = true
    }
    
    private func setIsTranslucentLockInCell(with obj: CellEditor.Binding) {
        switch obj.type {
        case .begin:
            self.cutEditor = timeline.editCutEditor
        case .sending:
            canvas.setNeedsDisplay()
        case .end:
            guard let cutEditor = cutEditor else {
                return
            }
            if obj.isTranslucentLock != obj.oldIsTranslucentLock {
                set(isTranslucentLock: obj.isTranslucentLock,
                    oldIsTranslucentLock: obj.oldIsTranslucentLock,
                    in: obj.inCell, in: cutEditor, time: time)
            } else {
                canvas.setNeedsDisplay()
            }
        }
    }
    private func set(isTranslucentLock: Bool, oldIsTranslucentLock: Bool,
                     in cell: Cell, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) {
            $0.set(isTranslucentLock: oldIsTranslucentLock,
                   oldIsTranslucentLock: isTranslucentLock, in: cell, in: cutEditor, time: $1)
        }
        cell.isTranslucentLock = isTranslucentLock
        canvas.setNeedsDisplay()
        cutEditor.cutItem.cutDataModel.isWrite = true
    }
    
    func scroll(with event: ScrollEvent) -> Bool {
        return timeline.scroll(with: event)
    }
}

/**
 # Issue
 - Undo時の時間の登録
 - マテリアルアニメーション
 */
final class SceneMaterialManager {
    lazy var scene = Scene()
    weak var sceneEditor: SceneEditor? {
        didSet {
            guard let sceneEditor = sceneEditor else {
                return
            }
            let editor = sceneEditor.canvas.materialEditor
            editor.typeBinding = { [unowned self] in self.setType(with: $0) }
            editor.colorBinding = { [unowned self] in self.setColor(with: $0) }
            editor.lineColorBinding = { [unowned self] in self.setLineColor(with: $0) }
            editor.lineWidthBinding = { [unowned self] in self.setLineWidth(with: $0) }
            editor.opacityBinding = { [unowned self] in self.setOpacity(with: $0) }
        }
    }
    
    var material: Material {
        get {
            return scene.editMaterial
        }
        set {
            scene.editMaterial = newValue
            sceneEditor?.canvas.materialEditor.material = newValue
            sceneEditor?.sceneDataModel.isWrite = true
        }
    }
    
    var undoManager: UndoManager? {
        return sceneEditor?.undoManager
    }
    
    var isAnimatedMaterial: Bool {
        for materialItem in scene.editCutItem.cut.editNode.editTrack.materialItems {
            if materialItem.keyMaterials.contains(material) {
                return true
            }
        }
        return false
    }
    
    private struct ColorTuple {
        var color: Color, materialTuples: [UUID: MaterialTuple]
    }
    private struct MaterialTuple {
        var material: Material, cutTuples: [CutTuple]
    }
    private struct CutTuple {
        var cutItem: CutItem, cells: [Cell], materialItemTuples: [MaterialItemTuple]
    }
    private struct MaterialItemTuple {
        var track: NodeTrack, materialItem: MaterialItem, editIndexes: [Int]
        static func materialItemTuples(with materialItem: MaterialItem,
                                       isSelection: Bool, in track: NodeTrack
            ) -> [UUID: (material: Material, itemTupe: MaterialItemTuple)] {
            
            var materialItemTuples = [UUID: (material: Material, itemTupe: MaterialItemTuple)]()
            for (i, material) in materialItem.keyMaterials.enumerated() {
                if materialItemTuples[material.id] == nil {
                    let indexes: [Int]
                    if isSelection {
                        indexes = [track.animation.editKeyframeIndex]
                    } else {
                        indexes = (i ..< materialItem.keyMaterials.count)
                            .filter { materialItem.keyMaterials[$0].id == material.id }
                    }
                    materialItemTuples[material.id] = (material,
                                                       MaterialItemTuple(track: track,
                                                                         materialItem: materialItem,
                                                                         editIndexes: indexes))
                }
            }
            return materialItemTuples
        }
    }
    
    private var materialTuples = [UUID: MaterialTuple](), colorTuples = [ColorTuple]()
    private var oldMaterialTuple: MaterialTuple?, oldMaterial: Material?
    private func colorTuplesWith(color: Color?, useSelection: Bool = false,
                                 in cutItem: CutItem, _ cutItems: [CutItem]) -> [ColorTuple] {
        if useSelection {
            let allSelectionCells = cutItem.cut.editNode.allSelectionCellItemsWithNoEmptyGeometry
            if !allSelectionCells.isEmpty {
                return colorTuplesWith(cells: allSelectionCells.map { $0.cell },
                                       isSelection: useSelection, in: cutItem)
            }
        }
        if let color = color {
            return colorTuplesWith(color: color, isSelection: useSelection, in: cutItems)
        } else {
            return colorTuplesWith(cells: cutItem.cut.cells,
                                   isSelection: useSelection, in: cutItem)
        }
    }
    private func colorTuplesWith(cells: [Cell], isSelection: Bool,
                                 in cutItem: CutItem) -> [ColorTuple] {
        struct ColorCell {
            var color: Color, cells: [Cell]
        }
        var colorDic = [UUID: ColorCell]()
        for cell in cells {
            if colorDic[cell.material.color.id] != nil {
                colorDic[cell.material.color.id]?.cells.append(cell)
            } else {
                colorDic[cell.material.color.id] = ColorCell(color: cell.material.color,
                                                             cells: [cell])
            }
        }
        return colorDic.map {
            ColorTuple(color: $0.value.color,
                       materialTuples: materialTuplesWith(cells: $0.value.cells,
                                                          isSelection: isSelection, in: cutItem))
        }
    }
    private func colorTuplesWith(color: Color, isSelection: Bool,
                                 in cutItems: [CutItem]) -> [ColorTuple] {
        var materialTuples = [UUID: MaterialTuple]()
        for cutItem in cutItems {
            let cells = cutItem.cut.cells.filter { $0.material.color == color }
            if !cells.isEmpty {
                let mts = materialTuplesWith(cells: cells, color: color,
                                             isSelection: isSelection, in: cutItem)
                for mt in mts {
                    if materialTuples[mt.key] != nil {
                        materialTuples[mt.key]?.cutTuples += mt.value.cutTuples
                    } else {
                        materialTuples[mt.key] = mt.value
                    }
                }
            }
        }
        return materialTuples.isEmpty ? [] : [ColorTuple(color: color,
                                                         materialTuples: materialTuples)]
    }
    
    private func materialTuplesWith(cells: [Cell], color: Color? = nil,
                                    isSelection: Bool, in cutItem: CutItem) -> [UUID: MaterialTuple] {
        var materialDic = [UUID: MaterialTuple]()
        for cell in cells {
            if materialDic[cell.material.id] != nil {
                materialDic[cell.material.id]?.cutTuples[0].cells.append(cell)
            } else {
                let cutTuples = [CutTuple(cutItem: cutItem, cells: [cell], materialItemTuples: [])]
                materialDic[cell.material.id] = MaterialTuple(material: cell.material,
                                                              cutTuples: cutTuples)
            }
        }
        
        for track in cutItem.cut.editNode.tracks {
            for materialItem in track.materialItems {
                if cells.contains(where: { materialItem.cells.contains($0) }) {
                    let materialItemTuples = MaterialItemTuple.materialItemTuples(
                        with: materialItem, isSelection: isSelection, in: track)
                    for materialItemTuple in materialItemTuples {
                        if let color = color {
                            if materialItemTuple.value.material.color != color {
                                continue
                            }
                        }
                        if materialDic[materialItemTuple.key] != nil {
                            materialDic[materialItemTuple.key]?.cutTuples[0]
                                .materialItemTuples.append(materialItemTuple.value.itemTupe)
                        } else {
                            let materialItemTuples = [materialItemTuple.value.itemTupe]
                            let cutTuples = [CutTuple(cutItem: cutItem, cells: [],
                                                      materialItemTuples: materialItemTuples)]
                            materialDic[materialItemTuple.key] = MaterialTuple(
                                material: materialItemTuple.value.material,
                                cutTuples: cutTuples
                            )
                        }
                    }
                }
            }
        }
        
        return materialDic
    }
    private func materialTuplesWith(material: Material?, useSelection: Bool = false,
                                    in cutItem: CutItem,
                                    _ cutItems: [CutItem]) -> [UUID: MaterialTuple] {
        if useSelection {
            let allSelectionCells = cutItem.cut.editNode.allSelectionCellItemsWithNoEmptyGeometry
            if !allSelectionCells.isEmpty {
                return materialTuplesWith(cells: allSelectionCells.map { $0.cell },
                                          isSelection: useSelection, in: cutItem)
            }
        }
        if let material = material {
            let cutTuples: [CutTuple] = cutItems.flatMap { cutItem in
                let cells = cutItem.cut.cells.filter { $0.material.id == material.id }
                
                var materialItemTuples = [MaterialItemTuple]()
                for track in cutItem.cut.editNode.tracks {
                    for materialItem in track.materialItems {
                        let indexes = useSelection ?
                            [track.animation.editKeyframeIndex] :
                            materialItem.keyMaterials.enumerated().flatMap {
                                $0.element.id == material.id ? $0.offset : nil }
                        if !indexes.isEmpty {
                            materialItemTuples.append(MaterialItemTuple(track: track,
                                                                        materialItem: materialItem,
                                                                        editIndexes: indexes))
                        }
                    }
                }
                
                return cells.isEmpty && materialItemTuples.isEmpty ?
                    nil : CutTuple(cutItem: cutItem, cells: cells,
                                   materialItemTuples: materialItemTuples)
            }
            return cutTuples.isEmpty ? [:] : [material.id: MaterialTuple(material: material,
                                                                         cutTuples: cutTuples)]
        } else {
            return materialTuplesWith(cells: cutItem.cut.cells,
                                      isSelection: useSelection, in: cutItem)
        }
    }
    
    private func selectionMaterialTuple(with colorTuples: [ColorTuple]) -> MaterialTuple? {
        for colorTuple in colorTuples {
            if let tuple = colorTuple.materialTuples[material.id] {
                return tuple
            }
        }
        return nil
    }
    private func selectionMaterialTuple(with materialTuples: [UUID: MaterialTuple]) -> MaterialTuple? {
        return materialTuples[material.id]
    }
    
    private var oldTime = Beat(0)
    
    private func changeMaterialWith(isColorTuple: Bool, type: Action.SendType) {
        switch type {
        case .begin:
            oldMaterialTuple = isColorTuple ?
                selectionMaterialTuple(with: colorTuples) :
                selectionMaterialTuple(with: materialTuples)
            if let oldMaterialTuple = oldMaterialTuple {
                material = oldMaterialTuple.cutTuples[0].cells[0].material
            }
        case .sending:
            if let oldMaterialTuple = oldMaterialTuple {
                material = oldMaterialTuple.cutTuples[0].cells[0].material
            }
        case .end:
            if let oldMaterialTuple = oldMaterialTuple {
                _set(oldMaterialTuple.cutTuples[0].cells[0].material,
                     old: oldMaterialTuple.material)
            }
            oldMaterialTuple = nil
        }
    }
    private func set(_ material: Material, in materialTuple: MaterialTuple) {
        for cutTuple in materialTuple.cutTuples {
            for cell in cutTuple.cells {
                cell.material = material
            }
            for materialItemTuple in cutTuple.materialItemTuples {
                var keyMaterials = materialItemTuple.materialItem.keyMaterials
                materialItemTuple.editIndexes.forEach { keyMaterials[$0] = material }
                materialItemTuple.track.set(keyMaterials, in: materialItemTuple.materialItem)
                materialItemTuple.materialItem.cells.forEach { $0.material = material }
            }
        }
    }
    private func _set(_ material: Material, in materialTuple: MaterialTuple) {
        for cutTuple in materialTuple.cutTuples {
            _set(material, old: materialTuple.material,
                 in: cutTuple.cells, cutTuple.cutItem)
        }
    }
    
    private func append(_ materialItem: MaterialItem, in track: NodeTrack, _ cutItem: CutItem) {
        undoManager?.registerUndo(withTarget: self) { $0.remove(materialItem, in: track, cutItem) }
        track.append(materialItem)
        cutItem.cutDataModel.isWrite = true
    }
    private func remove(_ materialItem: MaterialItem, in track: NodeTrack, _ cutItem: CutItem) {
        undoManager?.registerUndo(withTarget: self) {
            $0.append(materialItem, in: track, cutItem)
        }
        track.remove(materialItem)
        cutItem.cutDataModel.isWrite = true
    }
    
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        for object in copiedObject.objects {
            if let material = object as? Material {
                paste(material, withSelection: self.material, useSelection: false)
                return true
            }
        }
        return false
    }
    
    func splitColor() {
        guard let editCell = sceneEditor?.canvas.editCell else {
            return
        }
        let node = scene.editCutItem.cut.editNode
        let cells = node.selectionCells(with: editCell)
        if !cells.isEmpty {
            splitColor(with: cells)
        }
    }
    func splitOtherThanColor() {
        guard let editCell = sceneEditor?.canvas.editCell else {
            return
        }
        let node = scene.editCutItem.cut.editNode
        let cells = node.selectionCells(with: editCell)
        if !cells.isEmpty {
            splitOtherThanColor(with: cells)
        }
    }
    
    func paste(_ material: Material, in cells: [Cell]) {
        if cells.count == 1, let cell = cells.first {
            paste(material, withSelection: cell.material, useSelection: false)
        } else {
            let materialTuples = materialTuplesWith(cells: cells, isSelection: true,
                                                    in: scene.editCutItem)
            for materialTuple in materialTuples.values {
                _set(material, in: materialTuple)
            }
            if let material = materialTuples.first?.value.cutTuples.first?.cells.first?.material {
                _set(material, old: self.material)
            }
        }
    }
    func paste(_ color: Color, in cells: [Cell]) {
        let colorTuples = colorTuplesWith(cells: cells, isSelection: true,
                                          in: scene.editCutItem)
        for colorTuple in colorTuples {
            for materialTuple in colorTuple.materialTuples.values {
                _set(materialTuple.material.with(color), in: materialTuple)
            }
        }
        if let material =
            colorTuples.first?.materialTuples.first?.value.cutTuples.first?.cells.first?.material {
            
            _set(material, old: self.material)
        }
        
    }
    func paste(_ material: Material, withSelection selectionMaterial: Material, useSelection: Bool) {
        let materialTuples = materialTuplesWith(material: selectionMaterial,
                                                useSelection: useSelection,
                                                in: scene.editCutItem, scene.cutItems)
        for materialTuple in materialTuples.values {
            _set(material, in: materialTuple)
        }
        if let material = materialTuples.first?.value.cutTuples.first?.cells.first?.material {
            _set(material, old: self.material)
        }
    }
    func paste(_ color: Color, withSelection selectionMaterial: Material, useSelection: Bool) {
        let colorTuples = colorTuplesWith(color: selectionMaterial.color, useSelection: useSelection,
                                          in: scene.editCutItem, scene.cutItems)
        _setColor(color, in: colorTuples)
        if let material =
            colorTuples.first?.materialTuples.first?.value.cutTuples.first?.cells.first?.material {
            
            _set(material, old: self.material)
        }
    }
    func splitMaterial(with cells: [Cell]) {
        let materialTuples = materialTuplesWith(cells: cells, isSelection: true,
                                                in: scene.editCutItem)
        for materialTuple in materialTuples.values {
            _set(materialTuple.material.with(materialTuple.material.color.withNewID()),
                 in: materialTuple)
        }
        if let material = materialTuples.first?.value.cutTuples.first?.cells.first?.material {
            _set(material, old: self.material)
        }
    }
    func splitColor(with cells: [Cell]) {
        let colorTuples = colorTuplesWith(cells: cells, isSelection: true,
                                          in: scene.editCutItem)
        for colorTuple in colorTuples {
            let newColor = colorTuple.color.withNewID()
            for materialTuple in colorTuple.materialTuples.values {
                _set(materialTuple.material.with(newColor), in: materialTuple)
            }
        }
        if let material =
            colorTuples.first?.materialTuples.first?.value.cutTuples.first?.cells.first?.material {
            
            _set(material, old: self.material)
        }
    }
    func splitOtherThanColor(with cells: [Cell]) {
        let materialTuples = materialTuplesWith(cells: cells, isSelection: true,
                                                in: scene.editCutItem)
        for materialTuple in materialTuples.values {
            _set(materialTuple.material.with(materialTuple.material.color),
                 in: materialTuple)
        }
        if let material = materialTuples.first?.value.cutTuples.first?.cells.first?.material {
            _set(material, old: self.material)
        }
    }
    private func _set(_ material: Material, old oldMaterial: Material,
                      in cells: [Cell], _ cutItem: CutItem) {
        undoManager?.registerUndo(withTarget: self) {
            $0._set(oldMaterial, old: material, in: cells, cutItem)
        }
        cells.forEach { $0.material = material }
        cutItem.cutDataModel.isWrite = true
        if cutItem === sceneEditor?.canvas.cutItem {
            sceneEditor?.canvas.setNeedsDisplay()
        }
    }
    func select(_ material: Material) {
        _set(material, old: self.material)
    }
    private func _set(_ material: Material, old oldMaterial: Material) {
        undoManager?.registerUndo(withTarget: self) { $0._set(oldMaterial, old: material) }
        self.material = material
    }
    
    func setType(with binding: MaterialEditor.TypeBinding) {
        switch binding.sendType {
        case .begin:
            materialTuples = materialTuplesWith(material: binding.oldMaterial,
                                                in: scene.editCutItem, scene.cutItems)
        case .sending:
            setMaterialType(binding.type, in: materialTuples)
        case .end:
            _setMaterialType(binding.type, in: materialTuples)
            materialTuples = [:]
        }
        changeMaterialWith(isColorTuple: false, type: binding.sendType)
        sceneEditor?.canvas.setNeedsDisplay()
    }
    private func setMaterialType(_ type: Material.MaterialType,
                                 in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            set(materialTuple.material.with(type), in: materialTuple)
        }
    }
    private func _setMaterialType(_ type: Material.MaterialType,
                                  in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            _set(materialTuple.material.with(type), in: materialTuple)
        }
    }
    
    private func setColor(with binding: MaterialEditor.ColorBinding) {
        switch binding.type {
        case .begin:
            colorTuples = colorTuplesWith(color: binding.oldColor,
                                          in: scene.editCutItem, scene.cutItems)
        case .sending:
            setColor(binding.color, in: colorTuples)
        case .end:
            _setColor(binding.color, in: colorTuples)
            colorTuples = []
        }
        changeMaterialWith(isColorTuple: true, type: binding.type)
        sceneEditor?.canvas.setNeedsDisplay()
    }
    private func setColor(_ color: Color, in colorTuples: [ColorTuple]) {
        for colorTuple in colorTuples {
            for materialTuple in colorTuple.materialTuples.values {
                set(materialTuple.material.with(color), in: materialTuple)
            }
        }
    }
    private func _setColor(_ color: Color, in colorTuples: [ColorTuple]) {
        for colorTuple in colorTuples {
            for materialTuple in colorTuple.materialTuples.values {
                _set(materialTuple.material.with(color), in: materialTuple)
            }
        }
    }
    
    private func setLineColor(with binding: MaterialEditor.LineColorBinding) {
        switch binding.type {
        case .begin:
            materialTuples = materialTuplesWith(material: binding.oldMaterial,
                                                in: scene.editCutItem, scene.cutItems)
            setLineColor(binding.lineColor, in: materialTuples)
        case .sending:
            setLineColor(binding.lineColor, in: materialTuples)
        case .end:
            _setLineColor(binding.lineColor, in: materialTuples)
            materialTuples = [:]
        }
        changeMaterialWith(isColorTuple: false, type: binding.type)
        sceneEditor?.canvas.setNeedsDisplay()
    }
    private func setLineColor(_ lineColor: Color, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            set(materialTuple.material.with(lineColor: lineColor), in: materialTuple)
        }
    }
    private func _setLineColor(_ lineColor: Color, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            _set(materialTuple.material.with(lineColor: lineColor), in: materialTuple)
        }
    }
    
    func setLineWidth(with binding: MaterialEditor.LineWidthBinding) {
        switch binding.type {
        case .begin:
            materialTuples = materialTuplesWith(material: binding.oldMaterial,
                                                in: scene.editCutItem, scene.cutItems)
        case .sending:
            setLineWidth(binding.lineWidth, in: materialTuples)
        case .end:
            _setLineWidth(binding.lineWidth, in: materialTuples)
            materialTuples = [:]
        }
        changeMaterialWith(isColorTuple: false, type: binding.type)
        sceneEditor?.canvas.setNeedsDisplay()
    }
    private func setLineWidth(_ lineWidth: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            set(materialTuple.material.with(lineWidth: lineWidth), in: materialTuple)
        }
    }
    private func _setLineWidth(_ lineWidth: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            _set(materialTuple.material.with(lineWidth: lineWidth), in: materialTuple)
        }
    }
    
    func setOpacity(with binding: MaterialEditor.OpacityBinding) {
        switch binding.type {
        case .begin:
            materialTuples = materialTuplesWith(material: binding.oldMaterial,
                                                in: scene.editCutItem, scene.cutItems)
        case .sending:
            setOpacity(binding.opacity, in: materialTuples)
        case .end:
            _setOpacity(binding.opacity, in: materialTuples)
            materialTuples = [:]
        }
        changeMaterialWith(isColorTuple: false, type: binding.type)
        sceneEditor?.canvas.setNeedsDisplay()
    }
    private func setOpacity(_ opacity: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            set(materialTuple.material.with(opacity: opacity), in: materialTuple)
        }
    }
    private func _setOpacity(_ opacity: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            _set(materialTuple.material.with(opacity: opacity), in: materialTuple)
        }
    }
    
    private func changeAnimation(with binding: PulldownButton.Binding) {
        let isAnimation = self.isAnimatedMaterial
        if binding.index == 0 && !isAnimation {
            let cutItem =  scene.editCutItem
            let track = cutItem.cut.editNode.editTrack
            let keyMaterials = track.emptyKeyMaterials(with: material)
            let cells = cutItem.cut.cells.filter { $0.material == material }
            append(MaterialItem(material: material, cells: cells, keyMaterials: keyMaterials),
                   in: track, cutItem)
        } else if isAnimation {
            let cutItem =  scene.editCutItem
            let track = cutItem.cut.editNode.editTrack
            remove(track.materialItems[track.materialItems.count - 1],
                   in: cutItem.cut.editNode.editTrack, cutItem)
        }
    }
}
