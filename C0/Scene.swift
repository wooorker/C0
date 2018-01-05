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
 ## 0.3
 * セルと線を再設計
 * 線の描画を改善
 * 線の分割を改善
 * 点の追加、点の削除、点の移動と線の変形、スナップを再設計
 * 線端の傾きスナップ実装
 * セルの追加時の線の置き換え、編集セルを廃止
 * マテリアルのコピーによるバインドを廃止
 * 変形、歪曲の再設計
 * コマンドを整理
 * コピー表示、取り消し表示
 * シーン設定
 * 書き出し表示修正
 * すべてのインディケーション表示
 * マテリアルの合成機能修正
 * Display P3サポート
 * キーフレームラベルの導入
 * キャンバス上でのスクロール時間移動
 * キャンバスの選択修正
 * 「すべてを選択」「すべてを選択解除」アクションを追加
 * インディケーション再生
 * テキスト設計やGUIの基礎設計を修正
 * キーフレームの複数選択に対応
 * Swift4 (Codableを部分的に導入)
 * サウンドの書き出し
 △ プロパティの表示修正、セルのコピー、分割、表示設定の修正、キーフレーム表示の修正
 △ ビートタイムライン、最終キーフレームの継続時間を保持
 △ ノード導入
 △ スナップスクロール
 △ カット単位での読み込み、保存
 △ ストローク修正、スローの廃止
 
 ## 0.4
 X MetalによるGPUレンダリング（リニアワークフロー、マクロ拡散光）
 
 ## 1.0
 X 安定版
 
 # Issue
 補間区間上の選択
 Z移動の修正
 リファレンス表示の具体化
 シーン、カット、ノードなどの変更通知
 0秒キーフレーム
 マテリアルアニメーション
 モードレス文字入力、字幕
 コピー・ペーストなどのアクション対応を拡大
 可視性の改善 (スクロール後の元の位置までの距離を表示など)
 複数のサウンド
 (with: event)を使用しない、protocolモードレスアクション
 NodeTrackのItemのイミュータブル化
 コピーオブジェクトの自由な貼り付け
 コピーの階層化
 QuartzCore, CoreGraphics廃止
 トラックパッドの環境設定を無効化または表示反映
 バージョン管理UndoManager
 様々なメディアファイルに対応
 ファイルシステムのモードレス化
 効果音編集
 シーケンサー
 */

import Foundation
import QuartzCore

typealias BPM = Int
typealias FPS = Int
typealias CPB = Int
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
    let clipCellInSelectionBox = Button(name: Localization(english: "Clip Cell in Selection",
                                                           japanese: "セルを選択の中へクリップ"))
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
            transformEditor.isLocked =
                scene.editCutItem.cut.editNode.editTrack.animation.isInterporation
        }
        if let wiggle = scene.editCutItem.cut.editNode.editTrack.wiggleItem?.wiggle {
            wiggleEditor.wiggle = wiggle
            wiggleEditor.isLocked =
                scene.editCutItem.cut.editNode.editTrack.animation.isInterporation
        }
        soundEditor.sound = scene.sound
        playerEditor.time = scene.secondTime(withBeatTime: scene.time)
        playerEditor.cutIndex = scene.editCutItemIndex
        playerEditor.maxTime = scene.secondTime(withBeatTime: scene.duration)
    }
    func updateScene() {
        canvas.cameraFrame = scene.frame
        timeline.update()
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
        transformEditor.frame = CGRect(x: padding,
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
        timeline.nodeEditor.frame = CGRect(x: padding + cs.width,
                                           y: y - h * 2,
                                           width: SceneEditor.propertyWidth,
                                           height: h)
        timeline.keyframeEditor.frame = CGRect(x: padding + cs.width,
                                               y: y - h * 2 - keyframeHeight,
                                               width: SceneEditor.propertyWidth,
                                               height: keyframeHeight)
        let ch = canvas.cellEditor.editBounds.height
        let mh = canvas.materialEditor.editBounds.height
        canvas.cellEditor.frame = CGRect(x: padding + cs.width,
                                         y: y - h * 2 - keyframeHeight - ch,
                                         width: SceneEditor.propertyWidth,
                                         height: ch)
        canvas.materialEditor.frame = CGRect(x: padding + cs.width,
                                             y: y - h * 2 - keyframeHeight - ch - mh,
                                             width: SceneEditor.propertyWidth,
                                             height: mh)
        
        showAllBox.frame = CGRect(x: padding + cs.width,
                                  y: y - h * 2 - keyframeHeight - ch - mh - buttonH,
                                  width: SceneEditor.propertyWidth,
                                  height: buttonH)
        clipCellInSelectionBox.frame = CGRect(x: padding + cs.width,
                                              y: y - h * 2 - keyframeHeight - ch - mh - buttonH * 2,
                                              width: SceneEditor.propertyWidth,
                                              height: buttonH)
        splitColorBox.frame = CGRect(x: padding + cs.width,
                                     y: y - h * 2 - keyframeHeight - ch - mh - buttonH * 3,
                                     width: SceneEditor.propertyWidth,
                                     height: buttonH)
        splitOtherThanColorBox.frame = CGRect(x: padding + cs.width,
                                              y: y - h * 2 - keyframeHeight - ch - mh - buttonH * 4,
                                              width: SceneEditor.propertyWidth,
                                              height: buttonH)
        
        timeline.frame = CGRect(x: padding,
                                y: y - h * 2 - buttonH - th,
                                width: cs.width, height: SceneEditor.timelineHeight)
        canvas.frame = CGRect(x: padding,
                              y: y - h * 2 - buttonH - th - cs.height,
                              width: cs.width, height: cs.height)
        playerEditor.frame = CGRect(x: padding,
                                    y: padding, width: cs.width, height: h)
        
        frame.size = CGSize(width: width, height: height)
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
        cutsDataModel.insert(scene.cutItems[0].cutDataModel)
        dataModel = DataModel(key: SceneEditor.sceneEditorKey,
                              directoryWithDataModels: [sceneDataModel, cutsDataModel])
        timeline.cutsDataModel = cutsDataModel
        timeline.sceneDataModel = sceneDataModel
        
        children = [nameLabel,
                    versionEditor, rendererManager.popupBox,
                    sizeEditor, frameRateSlider, baseTimeIntervalSlider, colorSpaceButton,
                    isShownPreviousButton, isShownNextButton,
                    transformEditor, wiggleEditor, soundEditor,
                    newNodeTrackButton, /*newCutButton, */newNodeButton,
                    changeToDraftButton, removeDraftButton, swapDraftButton,
                    showAllBox, clipCellInSelectionBox, splitColorBox, splitOtherThanColorBox,
                    canvas.materialEditor, canvas.cellEditor,
                    timeline.keyframeEditor, timeline.nodeEditor,
                    timeline,
                    canvas,
                    playerEditor]
        update(withChildren: children, oldChildren: [])
        
        sceneDataModel.dataHandler = { [unowned self] in self.scene.data }
        
        versionEditor.undoManager = undoManager
        rendererManager.progressesEdgeResponder = self
        sizeEditor.setSizeHandler = { [unowned self] in
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
        frameRateSlider.setValueHandler = { [unowned self] in
            self.scene.frameRate = Int($0.value)
            if $0.type == .end && $0.value != $0.oldValue {
                self.sceneDataModel.isWrite = true
            }
        }
        baseTimeIntervalSlider.setValueHandler = { [unowned self] in
            self.scene.baseTimeInterval.q = Int($0.value)
            self.timeline.update()
            if $0.type == .end && $0.value != $0.oldValue {
                self.sceneDataModel.isWrite = true
            }
        }
        colorSpaceButton.setIndexHandler = { [unowned self] in
            self.scene.colorSpace = $0.index == 0 ? .sRGB : .displayP3
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
        
        newNodeTrackButton.clickHandler = { [unowned self] _ in self.timeline.newNodeTrack() }
//        newCutButton.clickHandler = { [unowned self] in self.timeline.newCut() }
        newNodeButton.clickHandler = { [unowned self] _ in self.timeline.newNode() }
        changeToDraftButton.clickHandler = { [unowned self] _ in self.canvas.changeToRough() }
        removeDraftButton.clickHandler = { [unowned self] _ in self.canvas.removeRough() }
        swapDraftButton.clickHandler = { [unowned self] _ in self.canvas.swapRough() }
        
        showAllBox.clickHandler = { [unowned self] _ in self.canvas.editShowInNode() }
        clipCellInSelectionBox.clickHandler = { [unowned self] _ in
            self.canvas.clipCellInSelection(at: self.canvas.materialEditor.editPointInScene)
        }
        splitColorBox.clickHandler = { [unowned self] _ in
            self.canvas.materialEditor.splitColor(at: self.canvas.materialEditor.editPointInScene)
        }
        splitOtherThanColorBox.clickHandler = { [unowned self] _ in
            let me = self.canvas.materialEditor
            me.splitOtherThanColor(at: me.editPointInScene)
        }
        
        transformEditor.setTransformHandler = { [unowned self] in
            self.set($0.transform, oldTransform: $0.oldTransform, type: $0.type)
        }
        wiggleEditor.setWiggleHandler = { [unowned self] in
            self.set($0.wiggle, oldWiggle: $0.oldWiggle, type: $0.type)
        }
        
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
            
            self.playerEditor.time = self.scene.secondTime(withBeatTime: self.time)
            self.playerEditor.cutIndex = self.scene.editCutItemIndex
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
        
        timeline.nodeEditor.setIsHiddenHandler = { [unowned self] in
            self.setIsHiddenInNode(with: $0)
        }
        
        timeline.keyframeEditor.setKeyframeHandler = { [unowned self] _ in
            //
            self.timeline.update()
        }
        
        canvas.setTimeHandler = { [unowned self] _, time in self.timeline.time = time }
        canvas.updateSceneHandler = { [unowned self] _ in self.sceneDataModel.isWrite = true }
        canvas.setRoughLinesHandler = { [unowned self] _, _ in self.timeline.update() }
        canvas.setContentsScaleHandler = { [unowned self] _, contentsScale in
            self.rendererManager.rendingContentScale = contentsScale
        }
        
        canvas.cellEditor.setIsTranslucentLockHandler = { [unowned self] in
            self.setIsTranslucentLockInCell(with: $0)
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
        
        update(with: scene)
        updateChildren()
    }
    
    private func registerUndo(time: Beat, _ handler: @escaping (SceneEditor, Beat) -> Void) {
        undoManager?.registerUndo(withTarget: self) { [oldTime = self.time] in
            handler($0, oldTime)
        }
        self.time = time
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
            }
        }
    }
    
    private var keyframeIndex = 0, isMadeTransformItem = false
    private weak var oldTransformItem: TransformItem?, track: NodeTrack?, cutItem: CutItem?
    func set(_ transform: Transform, oldTransform: Transform, type: Action.SendType) {
        switch type {
        case .begin:
            let cutItem = scene.editCutItem
            let track = cutItem.cut.editNode.editTrack
            oldTransformItem = track.transformItem
            if track.transformItem != nil {
                isMadeTransformItem = false
            } else {
                let transformItem = TransformItem.empty(with: track.animation)
                set(transformItem, in: track, in: cutItem)
                isMadeTransformItem = true
            }
            self.cutItem = cutItem
            self.track = track
            keyframeIndex = track.animation.editKeyframeIndex
            
            set(transform, at: keyframeIndex, in: track, in: cutItem)
        case .sending:
            guard let track = track, let cutItem = cutItem else {
                return
            }
            set(transform, at: keyframeIndex, in: track, in: cutItem)
        case .end:
            guard let track = track, let cutItem = cutItem,
                let transformItem = track.transformItem else {
                    return
            }
            set(transform, at: keyframeIndex, in: track, in: cutItem)
            if transformItem.isEmpty {
                if isMadeTransformItem {
                    set(TransformItem?.none, in: track, in: cutItem)
                } else {
                    set(TransformItem?.none,
                        old: oldTransformItem, in: track, in: cutItem, time: time)
                }
            } else {
                if isMadeTransformItem {
                    set(transformItem, old: oldTransformItem,
                        in: track, in: cutItem, time: scene.time)
                }
                if transform != oldTransform {
                    set(transform, old: oldTransform, at: keyframeIndex,
                        in: track, in: cutItem, time: scene.time)
                } else {
                    set(oldTransform, at: keyframeIndex, in: track, in: cutItem)
                }
            }
        }
    }
    private func set(_ transformItem: TransformItem?, in track: NodeTrack, in cutItem: CutItem) {
        track.transformItem = transformItem
        timeline.update()
    }
    private func set(_ transformItem: TransformItem?, old oldTransformItem: TransformItem?,
                     in track: NodeTrack, in cutItem: CutItem, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldTransformItem, old: transformItem, in: track, in: cutItem, time: $1)
        }
        set(transformItem, in: track, in: cutItem)
        cutItem.cutDataModel.isWrite = true
    }
    private func set(_ transform: Transform, at index: Int,
                     in track: NodeTrack, in cutItem: CutItem) {
        track.transformItem?.replace(transform, at: index)
        cutItem.cut.editNode.updateTransform()
        canvas.setNeedsDisplay()
    }
    private func set(_ transform: Transform, old oldTransform: Transform,
                     at index: Int, in track: NodeTrack, in cutItem: CutItem, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldTransform, old: transform, at: index, in: track, in: cutItem, time: $1)
        }
        set(transform, at: index, in: track, in: cutItem)
        cutItem.cutDataModel.isWrite = true
    }
    
    private var isMadeWiggleItem = false
    private weak var oldWiggleItem: WiggleItem?
    func set(_ wiggle: Wiggle, oldWiggle: Wiggle, type: Action.SendType) {
        switch type {
        case .begin:
            let cutItem = scene.editCutItem
            let track = cutItem.cut.editNode.editTrack
            oldWiggleItem = track.wiggleItem
            if track.wiggleItem != nil {
                isMadeWiggleItem = false
            } else {
                let wiggleItem = WiggleItem.empty(with: track.animation)
                set(wiggleItem, in: track, in: cutItem)
                isMadeWiggleItem = true
            }
            self.cutItem = cutItem
            self.track = track
            keyframeIndex = track.animation.editKeyframeIndex
            
            set(wiggle, at: keyframeIndex, in: track, in: cutItem)
        case .sending:
            guard let track = track, let cutItem = cutItem else {
                return
            }
            set(wiggle, at: keyframeIndex, in: track, in: cutItem)
        case .end:
            guard let track = track, let cutItem = cutItem,
                let wiggleItem = track.wiggleItem else {
                    return
            }
            set(wiggle, at: keyframeIndex, in: track, in: cutItem)
            if wiggleItem.isEmpty {
                if isMadeWiggleItem {
                    set(WiggleItem?.none, in: track, in: cutItem)
                } else {
                    set(WiggleItem?.none,
                        old: oldWiggleItem, in: track, in: cutItem, time: time)
                }
            } else {
                if isMadeWiggleItem {
                    set(wiggleItem, old: oldWiggleItem,
                        in: track, in: cutItem, time: scene.time)
                }
                if wiggle != oldWiggle {
                    set(wiggle, old: oldWiggle, at: keyframeIndex,
                        in: track, in: cutItem, time: scene.time)
                } else {
                    set(oldWiggle, at: keyframeIndex, in: track, in: cutItem)
                }
            }
        }
    }
    private func set(_ wiggleItem: WiggleItem?, in track: NodeTrack, in cutItem: CutItem) {
        track.wiggleItem = wiggleItem
        timeline.update()
    }
    private func set(_ wiggleItem: WiggleItem?, old oldWiggleItem: WiggleItem?,
                     in track: NodeTrack, in cutItem: CutItem, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldWiggleItem, old: wiggleItem, in: track, in: cutItem, time: $1)
        }
        set(wiggleItem, in: track, in: cutItem)
        cutItem.cutDataModel.isWrite = true
    }
    private func set(_ wiggle: Wiggle, at index: Int,
                     in track: NodeTrack, in cutItem: CutItem) {
        track.wiggleItem?.replace(wiggle, at: index)
        cutItem.cut.editNode.updateWiggle()
        canvas.setNeedsDisplay()
    }
    private func set(_ wiggle: Wiggle, old oldWiggle: Wiggle,
                     at index: Int, in track: NodeTrack, in cutItem: CutItem, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldWiggle, old: wiggle, at: index, in: track, in: cutItem, time: $1)
        }
        set(wiggle, at: index, in: track, in: cutItem)
        cutItem.cutDataModel.isWrite = true
    }
    
    private func setIsHiddenInNode(with obj: NodeEditor.HandlerObject) {
        switch obj.type {
        case .begin:
            self.cutItem = scene.editCutItem
        case .sending:
            canvas.setNeedsDisplay()
            timeline.update()
        case .end:
            guard let cutItem = cutItem else {
                return
            }
            if obj.isHidden != obj.oldIsHidden {
                set(isHidden: obj.isHidden,
                    oldIsHidden: obj.oldIsHidden,
                    in: obj.inNode, in: cutItem, time: time)
            } else {
                canvas.setNeedsDisplay()
                timeline.update()
            }
        }
    }
    private func set(isHidden: Bool, oldIsHidden: Bool,
                     in node: Node, in cutItem: CutItem, time: Beat) {
        registerUndo(time: time) {
            $0.set(isHidden: oldIsHidden, oldIsHidden: isHidden, in: node, in: cutItem, time: $1)
        }
        node.isHidden = isHidden
        canvas.setNeedsDisplay()
        timeline.update()
        cutItem.cutDataModel.isWrite = true
    }
    
    private func setIsTranslucentLockInCell(with obj: CellEditor.HandlerObject) {
        switch obj.type {
        case .begin:
            self.cutItem = scene.editCutItem
        case .sending:
            canvas.setNeedsDisplay()
        case .end:
            guard let cutItem = cutItem else {
                return
            }
            if obj.isTranslucentLock != obj.oldIsTranslucentLock {
                set(isTranslucentLock: obj.isTranslucentLock,
                    oldIsTranslucentLock: obj.oldIsTranslucentLock,
                    in: obj.inCell, in: cutItem, time: time)
            } else {
                canvas.setNeedsDisplay()
            }
        }
    }
    private func set(isTranslucentLock: Bool, oldIsTranslucentLock: Bool,
                     in cell: Cell, in cutItem: CutItem, time: Beat) {
        registerUndo(time: time) {
            $0.set(isTranslucentLock: oldIsTranslucentLock, oldIsTranslucentLock: isTranslucentLock, in: cell, in: cutItem, time: $1)
        }
        cell.isTranslucentLock = isTranslucentLock
        canvas.setNeedsDisplay()
        cutItem.cutDataModel.isWrite = true
    }
    
    func scroll(with event: ScrollEvent) {
        timeline.scroll(with: event)
    }
}
