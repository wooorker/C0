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
 ## 0.3.0
 * セル、線を再設計
 * 点の追加、点の削除、点の移動と線の変形、スナップを再設計
 * セルの追加時の線の置き換えを廃止、編集セルを廃止、編集表示を再設計
 * マテリアルのコピーによるバインドを廃止、クリックでマテリアルを選択
 * 線の描画、分割を改善
 * 「変形」の再設計
 * コマンドを整理
 */

//# Issue
//Swift4への対応
//汎用性、モードレス性に基づいたオブジェクト設計（ある特定の処理のためだけに設計したオブジェクトをすべて排除する）
//描画高速化（GPUを積極活用するように再設計する。Metal APIを利用）
//DCI-P3色空間
//リニアワークフロー（移行した場合、「スクリーン」は「発光」に統合）
//CanvasのCutを不変にしてCanvasを時間に合わせて入れ替える
//SceneEditor関連の時間Undo未実装
//カット単位での読み込み
//安全性の高いデータベース設計（保存が途中で中断された場合に、マテリアルの保存が部分的に行われていない状態になる）
//強制アンラップの抑制
//guard文
//CALayerのdrawsAsynchronouslyのメモリリーク修正（GPU描画に変更）
//SceneEditorDelegate実装（viewのカプセル化を強化）
//モデルのカプセル化を強化
//保存高速化
//安全なシリアライズ（NSObject, NSCodingを取り除く。Swift4のCodableを使用）
//Collectionプロトコル（allCellsやallBeziers、allEditPointsなどに適用）
//privateを少なくし、関数のネストなどを増やす
//TextEditorとStringViewの統合
//TimelineEditorなどをリファクタリング
//ProtocolなView
//ModelとViewを統合、表現形態はModelへのリンクで成立させる
//永続データ構造に近づける
//Main.storyboard, Localizable.strings, Assets.xcassetsの廃止
//Cocoa脱却
//クローン実装
//Union選択（選択の結合を明示的に行う）
//コピーオブジェクト表示
//コピーUndo
//パネルにindication表示を付ける
//カーソルが離れると閉じるプルダウンボタン
//スロー操作時の値の変更を相対的にする
//ラジオボタンの導入
//ボタンの可視性の改善
//スクロールの可視性の改善・位置表示（元の位置までの距離などを表示）
//トラックパッドの環境設定を無効化または表示反映
//書き出し時間表示の精度を改善
//ファイルシステムのモードレス化
//音楽（シーケンサー付き）・効果音
//スローコマンドを廃止

import Cocoa

protocol SceneEntityDelegate: class {
    func changedUpdateWithPreference(_ sceneEntity: SceneEntity)
}
final class SceneEntity {
    let preferenceKey = "preference", cutsKey = "cuts", materialsKey = "materials"
    
    weak var delegate: SceneEntityDelegate?
    
    var preference = Preference(), cutEntities = [CutEntity]()
    
    init() {
        let cutEntity = CutEntity()
        cutEntity.sceneEntity = self
        cutEntities = [cutEntity]
        
        cutsFileWrapper = FileWrapper(directoryWithFileWrappers: [String(0): cutEntity.fileWrapper])
        materialsFileWrapper = FileWrapper(directoryWithFileWrappers: [String(0): cutEntity.materialWrapper])
        rootFileWrapper = FileWrapper(directoryWithFileWrappers: [
            preferenceKey : preferenceFileWrapper,
            cutsKey: cutsFileWrapper,
            materialsKey: materialsFileWrapper
            ])
    }
    
    var rootFileWrapper = FileWrapper() {
        didSet {
            if let fileWrappers = rootFileWrapper.fileWrappers {
                if let fileWrapper = fileWrappers[preferenceKey] {
                    preferenceFileWrapper = fileWrapper
                }
                if let fileWrapper = fileWrappers[cutsKey] {
                    cutsFileWrapper = fileWrapper
                }
                if let fileWrapper = fileWrappers[materialsKey] {
                    materialsFileWrapper = fileWrapper
                }
            }
        }
    }
    var preferenceFileWrapper = FileWrapper()
    var cutsFileWrapper = FileWrapper() {
        didSet {
            if let fileWrappers = cutsFileWrapper.fileWrappers {
                let sortedFileWrappers = fileWrappers.sorted {
                    $0.key.localizedStandardCompare($1.key) == .orderedAscending
                }
                cutEntities = sortedFileWrappers.map {
                    return CutEntity(fileWrapper: $0.value, index: Int($0.key) ?? 0, sceneEntity: self)
                }
            }
        }
    }
    var materialsFileWrapper = FileWrapper() {
        didSet {
            if let fileWrappers = materialsFileWrapper.fileWrappers {
                let sortedFileWrappers = fileWrappers.sorted {
                    $0.key.localizedStandardCompare($1.key) == .orderedAscending
                }
                for (i, cutEntity) in cutEntities.enumerated() {
                    if i < sortedFileWrappers.count {
                        cutEntity.materialWrapper = sortedFileWrappers[i].value
                    }
                }
            }
        }
    }
    
    func read() {
        for cutEntity in cutEntities {
            cutEntity.read()
        }
    }
    
    func write() {
        writePreference()
        for cutEntity in cutEntities {
            cutEntity.write()
        }
    }
    
    func allWrite() {
        isUpdatePreference = true
        writePreference()
        for cutEntity in cutEntities {
            cutEntity.isUpdate = true
            cutEntity.isUpdateMaterial = true
            cutEntity.write()
        }
    }
    
    var isUpdatePreference = false {
        didSet {
            if isUpdatePreference != oldValue {
                delegate?.changedUpdateWithPreference(self)
            }
        }
    }
    func readPreference() {
        if let data = preferenceFileWrapper.regularFileContents, let preference = Preference.with(data) {
            self.preference = preference
        }
    }
    func writePreference() {
        if isUpdatePreference {
            writePreference(with: preference.data)
            isUpdatePreference = false
        }
    }
    func writePreference(with data: Data) {
        rootFileWrapper.removeFileWrapper(preferenceFileWrapper)
        preferenceFileWrapper = FileWrapper(regularFileWithContents: data)
        preferenceFileWrapper.preferredFilename = preferenceKey
        rootFileWrapper.addFileWrapper(preferenceFileWrapper)
    }
    
    func insert(_ cutEntity: CutEntity, at index: Int) {
        if index < cutEntities.count {
            for i in (index ..< cutEntities.count).reversed() {
                let cutEntity = cutEntities[i]
                cutsFileWrapper.removeFileWrapper(cutEntity.fileWrapper)
                cutEntity.fileWrapper.preferredFilename = String(i + 1)
                cutsFileWrapper.addFileWrapper(cutEntity.fileWrapper)
                
                materialsFileWrapper.removeFileWrapper(cutEntity.materialWrapper)
                cutEntity.materialWrapper.preferredFilename = String(i + 1)
                materialsFileWrapper.addFileWrapper(cutEntity.materialWrapper)
                
                cutEntity.index = i + 1
            }
        }
        cutEntity.fileWrapper.preferredFilename = String(index)
        cutEntity.index = index
        cutEntity.materialWrapper.preferredFilename = String(index)
        
        cutsFileWrapper.addFileWrapper(cutEntity.fileWrapper)
        materialsFileWrapper.addFileWrapper(cutEntity.materialWrapper)
        cutEntities.insert(cutEntity, at: index)
        cutEntity.sceneEntity = self
    }
    func removeCutEntity(at index: Int) {
        let cutEntity = cutEntities[index]
        cutsFileWrapper.removeFileWrapper(cutEntity.fileWrapper)
        materialsFileWrapper.removeFileWrapper(cutEntity.materialWrapper)
        cutEntity.sceneEntity = nil
        cutEntities.remove(at: index)
        
        for i in index ..< cutEntities.count {
            let cutEntity = cutEntities[i]
            cutsFileWrapper.removeFileWrapper(cutEntity.fileWrapper)
            cutEntity.fileWrapper.preferredFilename = String(i)
            cutsFileWrapper.addFileWrapper(cutEntity.fileWrapper)
            
            materialsFileWrapper.removeFileWrapper(cutEntity.materialWrapper)
            cutEntity.materialWrapper.preferredFilename = String(i)
            materialsFileWrapper.addFileWrapper(cutEntity.materialWrapper)
            
            cutEntity.index = i
        }
    }
    var cuts: [Cut] {
        return cutEntities.map { $0.cut }
    }
}

final class CutEntity: Equatable {
    weak var sceneEntity: SceneEntity!
    
    var cut: Cut, index: Int
    var fileWrapper = FileWrapper(), materialWrapper = FileWrapper()
    var isUpdate = false, isUpdateMaterial = false, useWriteMaterial = false, isReadContent = true
    
    init(fileWrapper: FileWrapper, index: Int, sceneEntity: SceneEntity? = nil) {
        cut = Cut()
        self.fileWrapper = fileWrapper
        self.index = index
        self.sceneEntity = sceneEntity
    }
    init(cut: Cut = Cut(), index: Int = 0) {
        self.cut = cut
        self.index = index
    }
    
    func read() {
        if let s = fileWrapper.preferredFilename {
            index = Int(s) ?? 0
        } else {
            index = 0
        }
        isReadContent = false
        readContent()
    }
    func readContent() {
        if !isReadContent {
            if let data = fileWrapper.regularFileContents, let cut = Cut.with(data) {
                self.cut = cut
            }
            if let materialsData = materialWrapper.regularFileContents, !materialsData.isEmpty {
                if let materialCellIDs = NSKeyedUnarchiver.unarchiveObject(with: materialsData) as? [MaterialCellID] {
                    cut.materialCellIDs = materialCellIDs
                    useWriteMaterial = true
                }
            }
            isReadContent = true
        }
    }
    func write() {
        if isUpdate {
            writeCut(with: cut.data)
            isUpdate = false
            isUpdateMaterial = false
            if useWriteMaterial {
                writeMaterials(with: Data())
                useWriteMaterial = false
            }
        }
        if isUpdateMaterial {
            writeMaterials(with: NSKeyedArchiver.archivedData(withRootObject: cut.materialCellIDs))
            isUpdateMaterial = false
            useWriteMaterial = true
        }
    }
    func writeCut(with data: Data) {
        sceneEntity.cutsFileWrapper.removeFileWrapper(fileWrapper)
        fileWrapper = FileWrapper(regularFileWithContents: data)
        fileWrapper.preferredFilename = String(index)
        sceneEntity.cutsFileWrapper.addFileWrapper(fileWrapper)
    }
    func writeMaterials(with data: Data) {
        sceneEntity.materialsFileWrapper.removeFileWrapper(materialWrapper)
        materialWrapper = FileWrapper(regularFileWithContents: data)
        materialWrapper.preferredFilename = String(index)
        sceneEntity.materialsFileWrapper.addFileWrapper(materialWrapper)
        
        isUpdateMaterial = false
    }
    
    static func == (lhs: CutEntity, rhs: CutEntity) -> Bool {
        return lhs === rhs
    }
}

final class Preference: NSObject, NSCoding {
    var version = Bundle.main.version
    var isFullScreen = false, windowFrame = NSRect()
    var scene = Scene()
    
    init(version: Int = Bundle.main.version, isFullScreen: Bool = false, windowFrame: NSRect = NSRect(), scene: Scene = Scene()) {
        self.version = version
        self.isFullScreen = isFullScreen
        self.windowFrame = windowFrame
        self.scene = scene
        super.init()
    }
    
    static let dataType = "C0.Preference.1", versionKey = "0", isFullScreenKey = "1", windowFrameKey = "2", sceneKey = "3"
    init?(coder: NSCoder) {
        version = coder.decodeInteger(forKey: Preference.versionKey)
        isFullScreen = coder.decodeBool(forKey: Preference.isFullScreenKey)
        windowFrame = coder.decodeRect(forKey: Preference.windowFrameKey)
        scene = coder.decodeObject(forKey: Preference.sceneKey) as? Scene ?? Scene()
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(version, forKey: Preference.versionKey)
        coder.encode(isFullScreen, forKey: Preference.isFullScreenKey)
        coder.encode(windowFrame, forKey: Preference.windowFrameKey)
        coder.encode(scene, forKey: Preference.sceneKey)
    }
}

final class MaterialCellID: NSObject, NSCoding {
    var material: Material, cellIDs: [UUID]
    
    init(material: Material, cellIDs: [UUID]) {
        self.material = material
        self.cellIDs = cellIDs
        super.init()
    }
    
    static let dataType = "C0.MaterialCellID.1", materialKey = "0", cellIDsKey = "1"
    init?(coder: NSCoder) {
        material = coder.decodeObject(forKey: MaterialCellID.materialKey) as? Material ?? Material()
        cellIDs = coder.decodeObject(forKey: MaterialCellID.cellIDsKey) as? [UUID] ?? []
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(material, forKey: MaterialCellID.materialKey)
        coder.encode(cellIDs, forKey: MaterialCellID.cellIDsKey)
    }
}

@NSApplicationMain final class AppDelegate: NSObject, NSApplicationDelegate {}
final class Document: NSDocument, NSWindowDelegate, SceneEntityDelegate {
    let sceneEntity = SceneEntity()
    var window: NSWindow {
        return windowControllers.first!.window!
    }
    weak var screenView: ScreenView!, sceneEditor: SceneEditor!
    
    override init() {
        super.init()
    }
    convenience init(type typeName: String) throws {
        self.init()
        fileType = typeName
    }
    
    override class func autosavesInPlace() -> Bool {
        return true
    }
    
    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: "Document Window Controller") as! NSWindowController
        addWindowController(windowController)
        screenView = windowController.contentViewController!.view as! ScreenView
        
        let sceneEditor = SceneEditor()
        sceneEditor.displayActionNode = screenView.screen.actionNode
        sceneEditor.sceneEntity = sceneEntity
        self.sceneEditor = sceneEditor
        screenView.screen.content = sceneEditor
        if let undoManager = undoManager {
            screenView.screen.undoManager = undoManager
        }
        
        setupWindow(with: sceneEntity.preference)
        sceneEntity.delegate = self
    }
    private func setupWindow(with preference: Preference) {
        if preference.windowFrame.isEmpty, let frame = NSScreen.main()?.frame {
            let size = NSSize(width: 1050, height: 740)
            let origin = NSPoint(x: round((frame.width - size.width)/2), y: round((frame.height - size.height)/2))
            preference.windowFrame = NSRect(origin: origin, size: size)
        }
        window.setFrame(preference.windowFrame, display: false)
        if preference.isFullScreen {
            window.toggleFullScreen(nil)
        }
        window.delegate = self
    }
    
    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        sceneEntity.write()
        return sceneEntity.rootFileWrapper
    }
    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        sceneEntity.rootFileWrapper = fileWrapper
        sceneEntity.readPreference()
        if sceneEntity.preference.version < 4 {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }
        sceneEntity.read()
    }
    
    func changedUpdateWithPreference(_ sceneEntity: SceneEntity) {
        if sceneEntity.isUpdatePreference {
            updateChangeCount(.changeDone)
        }
    }
    
    func windowDidResize(_ notification: Notification) {
        sceneEntity.preference.windowFrame = window.frame
        sceneEntity.isUpdatePreference = true
    }
    func windowDidEnterFullScreen(_ notification: Notification) {
        sceneEntity.preference.isFullScreen = true
        sceneEntity.isUpdatePreference = true
    }
    func windowDidExitFullScreen(_ notification: Notification) {
        sceneEntity.preference.isFullScreen = false
        sceneEntity.isUpdatePreference = true
    }
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.action else {
            return true
        }
        switch action {
        case #selector(exportMovie720pFromSelectionCut(_:)):
            menuItem.title = String(format: "Export 720p Movie with %@...".localized, "C\(sceneEditor.timeline.selectionCutEntity.index + 1)")
        case #selector(exportMovie1080pFromSelectionCut(_:)):
            menuItem.title = String(format: "Export 1080p Movie with %@...".localized, "C\(sceneEditor.timeline.selectionCutEntity.index + 1)")
        default:
            break
        }
        return true
    }
    
    @IBAction func exportMovie720p(_ sender: Any?) {
        sceneEditor.rendererEditor.exportMovie(message: (sender as? NSMenuItem)?.title ?? "", size: CGSize(width: 1280, height: 720), fps: 24, isSelectionCutOnly: false)
    }
    @IBAction func exportMovie1080p(_ sender: Any?) {
        sceneEditor.rendererEditor.exportMovie(message: (sender as? NSMenuItem)?.title ?? "", size: CGSize(width: 1920, height: 1080), fps: 24, isSelectionCutOnly: false)
    }
    @IBAction func exportMovie720pFromSelectionCut(_ sender: Any?) {
        sceneEditor.rendererEditor.exportMovie(message: (sender as? NSMenuItem)?.title ?? "", name: "C\(sceneEditor.timeline.selectionCutEntity.index + 1)", size: CGSize(width: 1280, height: 720), fps: 24, isSelectionCutOnly: true)
    }
    @IBAction func exportMovie1080pFromSelectionCut(_ sender: Any?) {
        sceneEditor.rendererEditor.exportMovie(message: (sender as? NSMenuItem)?.title ?? "", name: "C\(sceneEditor.timeline.selectionCutEntity.index + 1)", size: CGSize(width: 1920, height: 1080), fps: 24, isSelectionCutOnly: true)
    }
    @IBAction func exportImage720p(_ sender: Any?) {
        sceneEditor.rendererEditor.exportImage(message: (sender as? NSMenuItem)?.title ?? "", size: CGSize(width: 1280, height: 720))
    }
    @IBAction func exportImage1080p(_ sender: Any?) {
        sceneEditor.rendererEditor.exportImage(message: (sender as? NSMenuItem)?.title ?? "", size: CGSize(width: 1920, height: 1080))
    }

    @IBAction func openHelp(_ sender: Any?) {
        if let url = URL(string:  "https://github.com/smdls/C0") {
            NSWorkspace.shared().open(url)
        }
    }
    
    func openEmoji() {
        NSApp.orderFrontCharacterPalette(nil)
    }
}
