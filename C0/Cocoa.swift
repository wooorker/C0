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

final class ScreenView: NSView, NSTextInputClient {
    let screen = Screen()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    private var token: NSObjectProtocol?, localToken: NSObjectProtocol?
    func setup() {
        wantsLayer = true
        if let layer = layer {
            layer.backgroundColor = Defaults.backgroundColor.cgColor
            screen.screenView = self
            screen.rootResponder.layer = layer
            localToken = NotificationCenter.default.addObserver(forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: nil) { [unowned self] _ in
                self.screen.locale = Locale.current
            }
            token = NotificationCenter.default.addObserver(forName: .NSViewFrameDidChange, object: self, queue: nil) {
                ($0.object as? ScreenView)?.updateFrame()
            }
        }
    }
    deinit {
        if let token = token {
            NotificationCenter.default.removeObserver(token)
        }
        if let localToken = localToken {
            NotificationCenter.default.removeObserver(localToken)
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    override func becomeFirstResponder() -> Bool {
        return true
    }
    override func resignFirstResponder() -> Bool {
        return true
    }
    
    override func viewDidChangeBackingProperties() {
        if let backingScaleFactor = window?.backingScaleFactor {
            screen.backingScaleFactor = backingScaleFactor
        }
    }
    
    func createTrackingArea() {
        let options: NSTrackingAreaOptions = [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited]
        addTrackingArea(NSTrackingArea(rect: bounds, options: options, owner: self))
    }
    override func updateTrackingAreas() {
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        createTrackingArea()
        super.updateTrackingAreas()
    }
    
    func updateFrame() {
        screen.frame = bounds
    }
    
    func screenPoint(with event: NSEvent) -> CGPoint {
        return convertToLayer(convert(event.locationInWindow, from: nil))
    }
    var cursorPoint: CGPoint {
        let windowPoint = window?.mouseLocationOutsideOfEventStream ?? NSPoint()
        return convertToLayer(convert(windowPoint, from: nil))
    }
    func convertFromTopScreen(_ p: NSPoint) -> NSPoint {
        let windowPoint = window?.convertFromScreen(NSRect(origin: p, size: NSSize())).origin ?? NSPoint()
        return convert(windowPoint, from: nil)
    }
    func convertToTopScreen(_ r: CGRect) -> NSRect {
        return window?.convertToScreen(convert(r, to: nil)) ?? NSRect()
    }
    
    var descriptionHeight = 30.0.cf
    private var popover = NSPopover()
    func showDescription(_ description: String, from responder: Responder) {
        let vc = NSViewController(), tv = NSTextField(frame: CGRect())
        tv.stringValue = description
        tv.font = Defaults.font
        tv.isBordered = false
        tv.drawsBackground = false
        tv.isEditable = false
        tv.isSelectable = true
        tv.sizeToFit()
        tv.frame.origin = CGPoint(x: 5, y: 5)
        let v = NSView(frame: tv.bounds.inset(by: -5))
        v.addSubview(tv)
        vc.view = v
        popover.close()
        popover = NSPopover()
        popover.animates = false
        popover.contentViewController = vc
        popover.show(relativeTo: screen.convert(responder.bounds, from: responder), of: self, preferredEdge: .minY)
    }
    
    func moveEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> MoveEvent {
        return MoveEvent(sendType: sendType, location: screenPoint(with: nsEvent), time: nsEvent.timestamp)
    }
    func dragEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> DragEvent {
        return DragEvent(sendType: sendType, location: screenPoint(with: nsEvent), time: nsEvent.timestamp, pressure: nsEvent.pressure.cf)
    }
    func scrollEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> ScrollEvent {
        return ScrollEvent(sendType: sendType, location: screenPoint(with: nsEvent), time: nsEvent.timestamp, scrollDeltaPoint: CGPoint(x: nsEvent.scrollingDeltaX, y: nsEvent.scrollingDeltaY), scrollMomentum: nsEvent.momentumPhase)
    }
    func pinchEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> PinchEvent {
        return PinchEvent(sendType: sendType, location: screenPoint(with: nsEvent), time: nsEvent.timestamp, magnification: nsEvent.magnification)
    }
    func rotateEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> RotateEvent {
        return RotateEvent(sendType: sendType, location: screenPoint(with: nsEvent), time: nsEvent.timestamp, rotation: nsEvent.rotation.cf)
    }
    func tapEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> TapEvent {
        return TapEvent(sendType: sendType, location: screenPoint(with: nsEvent), time: nsEvent.timestamp)
    }
    func doubleTapEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> DoubleTapEvent {
        return DoubleTapEvent(sendType: sendType, location: screenPoint(with: nsEvent), time: nsEvent.timestamp)
    }
    func keyInputEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> KeyInputEvent {
        return KeyInputEvent(sendType: sendType, location: cursorPoint, time: nsEvent.timestamp)
    }
    
    private var isKey = false, keyAction = Action(), keyEvent: NSEvent?
    private weak var keyTextEditor: TextEditor?
    override func keyDown(with event: NSEvent) {
        if popover.isShown {
            popover.close()
        }
        if !isDown {
            isKey = true
            keyAction = actionWith(gesture: .keyInput, event: event, from: screen.actionNode) ?? Action()
            
            if let editTextEditor = editTextEditor, keyAction.canTextKeyInput() {
                keyTextEditor = editTextEditor
                editTextEditor.keyInput(with: keyInputEventWith(.begin, event))
                inputContext?.handleEvent(event)
            } else if keyAction != Action() {
                keyAction.keyInput?(screen.indicationResponder, keyInputEventWith(.begin, event))
            }
        } else {
            keyEvent = event
        }
    }
    override func keyUp(with event: NSEvent) {
        if let keyTextEditor = keyTextEditor, isKey {
            keyTextEditor.keyInput(with: keyInputEventWith(.end, event))
            inputContext?.handleEvent(event)
            self.keyTextEditor = nil
        }
    }
    
    private var oldQuasimodeAction = Action()
    private weak var oldQuasimodeResponder: Responder?
    override func flagsChanged(with event: NSEvent) {
        if !isDown, let oldQuasimodeResponder = oldQuasimodeResponder {
            oldQuasimodeAction.changeQuasimode?(oldQuasimodeResponder, false)
            self.oldQuasimodeResponder = nil
        }
        let quasimodeAction = actionWith(gesture: .drag, event: event, from: screen.actionNode) ?? Action()
        if !isDown {
            quasimodeAction.changeQuasimode?(screen.indicationResponder, true)
        }
        oldQuasimodeAction = quasimodeAction
        oldQuasimodeResponder = screen.indicationResponder
    }
    
    override func mouseEntered(with event: NSEvent) {
        mouseMoved(with: event)
    }
    override func mouseExited(with event: NSEvent) {
        mouseMoved(with: event)
    }
    override func mouseMoved(with event: NSEvent) {
        let moveEvent = moveEventWith(.sending, event)
        let p = screen.rootResponder.point(from: moveEvent)
        screen.setIndicationResponder(with: p)
        screen.setCursor(with: p)
        screen.indicationResponder.moveCursor(with: moveEvent)
    }
    
    private let defaultDragAction = Action(drag: { $0.drag(with: $1) })
    private var isDown = false, isDrag = false, dragAction = Action()
    private weak var dragResponder: Responder?
    override func mouseDown(with nsEvent: NSEvent) {
        if popover.isShown {
            popover.close()
        }
        isDown = true
        isDrag = false
        dragResponder = screen.indicationResponder
        if let dragResponder = dragResponder {
            let event = dragEventWith(.begin, nsEvent)
            if !dragResponder.willDrag(with: event) {
                isDown = false
            } else {
                dragAction = actionWith(gesture: .drag, event: nsEvent, from: screen.actionNode) ?? defaultDragAction
                dragAction.drag?(dragResponder, event)
            }
        }
    }
    override func mouseDragged(with nsEvent: NSEvent) {
        isDrag = true
        if isDown, let dragResponder = dragResponder {
            dragAction.drag?(dragResponder, dragEventWith(.sending, nsEvent))
        }
    }
    override func mouseUp(with nsEvent: NSEvent) {
        if isDown {
            let event = dragEventWith(.end, nsEvent)
            if let dragResponder = dragResponder {
                dragAction.drag?(dragResponder, event)
            }
            if !isDrag {
                dragResponder?.click(with: event)
            }
            isDown = false
            isDrag = false
            
            if let keyEvent = keyEvent {
                keyDown(with: keyEvent)
                self.keyEvent = nil
            }
            
            if dragAction != oldQuasimodeAction {
                if let dragResponder = dragResponder {
                    dragAction.changeQuasimode?(dragResponder, false)
                }
                oldQuasimodeAction.changeQuasimode?(screen.indicationResponder, true)
            }
        }
    }
    
    private weak var momentumScrollResponder: Responder?
    override func scrollWheel(with event: NSEvent) {
        if event.phase != .mayBegin && event.phase != .cancelled {
            mouseMoved(with: event)
            if event.momentumPhase != .changed && event.momentumPhase != .ended {
                momentumScrollResponder = screen.indicationResponder
            }
            if let momentumScrollResponder = momentumScrollResponder {
                let sendType: Action.SendType = event.phase == .began ? .begin : (event.phase == .ended ? .end : .sending)
                momentumScrollResponder.scroll(with: scrollEventWith(sendType, event))
            }
        }
    }
    
    private enum TouchGesture {
        case none, scroll, pinch, rotate
    }
    private var blockGesture = TouchGesture.none
    override func magnify(with event: NSEvent) {
        if event.phase == .began {
            if blockGesture == .none {
                blockGesture = .pinch
                screen.indicationResponder.zoom(with: pinchEventWith(.begin, event))
            }
        } else if event.phase == .ended {
            if blockGesture == .pinch {
                blockGesture = .none
                screen.indicationResponder.zoom(with:pinchEventWith(.end, event))
            }
        } else {
            if blockGesture == .pinch {
                screen.indicationResponder.zoom(with: pinchEventWith(.sending, event))
            }
        }
    }
    override func rotate(with event: NSEvent) {
        if event.phase == .began {
            if blockGesture == .none {
                blockGesture = .rotate
                screen.indicationResponder.rotate(with: rotateEventWith(.begin, event))
            }
        } else if event.phase == .ended {
            if blockGesture == .rotate {
                blockGesture = .none
                screen.indicationResponder.rotate(with: rotateEventWith(.end, event))
            }
        } else {
            if blockGesture == .rotate {
                screen.indicationResponder.rotate(with: rotateEventWith(.sending, event))
            }
        }
    }
    
    private func contains(_ event: NSEvent, with quasimode: Action.Quasimode) -> Bool {
        var modifierFlags: NSEventModifierFlags = []
        if quasimode.contains(.shift) {
            modifierFlags.insert(.shift)
        }
        if quasimode.contains(.command) {
            modifierFlags.insert(.command)
        }
        if quasimode.contains(.control) {
            modifierFlags.insert(.control)
        }
        if quasimode.contains(.option) {
            modifierFlags.insert(.option)
        }
        let flipModifierFlags = modifierFlags.symmetricDifference([.shift, .command, .control, .option])
        return event.modifierFlags.contains(modifierFlags) && event.modifierFlags.intersection(flipModifierFlags) == []
    }
    private func canSend(with event: NSEvent, from action: Action) -> Bool {
        if let key = action.key {
            return event.keyCode == key.code && contains(event, with: action.quasimode)
        } else {
            return contains(event, with: action.quasimode)
        }
    }
    private func actionWith(gesture: Action.Gesture, event: NSEvent, from actionNode: ActionNode) -> Action? {
        switch gesture {
        case .keyInput:
            for action in actionNode.keyActions {
                if canSend(with: event, from: action) {
                    return action
                }
            }
        case .click:
            for action in actionNode.clickActions {
                if canSend(with: event, from: action) {
                    return action
                }
            }
        case .rightClick:
            for action in actionNode.rightClickActions {
                if canSend(with: event, from: action) {
                    return action
                }
            }
        case .drag:
            for action in actionNode.dragActions {
                if canSend(with: event, from: action) {
                    return action
                }
            }
        default:
            break
        }
        return nil
    }
    
    override func quickLook(with event: NSEvent) {
        screen.indicationResponder.quickLook(with: tapEventWith(.begin, event))
    }
    override func smartMagnify(with event: NSEvent) {
        screen.indicationResponder.reset(with: doubleTapEventWith(.begin, event))
    }
    
    var editTextEditor: TextEditor? {
        return screen.indicationResponder as? TextEditor
    }
    
    func hasMarkedText() -> Bool {
        return editTextEditor?.hasMarkedText() ?? false
    }
    func markedRange() -> NSRange {
        return editTextEditor?.markedRange() ?? NSRange()
    }
    func selectedRange() -> NSRange {
        return editTextEditor?.selectedRange() ?? NSRange()
    }
    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        editTextEditor?.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
    }
    func unmarkText() {
        editTextEditor?.unmarkText()
    }
    func validAttributesForMarkedText() -> [String] {
        return [NSMarkedClauseSegmentAttributeName, NSGlyphInfoAttributeName]
    }
    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        return editTextEditor?.attributedSubstring(forProposedRange: range, actualRange: actualRange)
    }
    func insertText(_ string: Any, replacementRange: NSRange) {
        editTextEditor?.insertText(string, replacementRange: replacementRange)
    }
    func characterIndex(for point: NSPoint) -> Int {
        return editTextEditor?.characterIndex(for: point) ?? 0
    }
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        return editTextEditor?.firstRect(forCharacterRange: range, actualRange: actualRange) ?? NSRect()
    }
    func attributedString() -> NSAttributedString {
        return editTextEditor?.attributedString() ?? NSAttributedString()
    }
    func fractionOfDistanceThroughGlyph(for point: NSPoint) -> CGFloat {
        return editTextEditor?.fractionOfDistanceThroughGlyph(for: point) ?? 0
    }
    func baselineDeltaForCharacter(at anIndex: Int) -> CGFloat {
        return editTextEditor?.baselineDeltaForCharacter(at: anIndex) ?? 0
    }
    func windowLevel() -> Int {
        return window?.level ?? 0
    }
    func drawsVerticallyForCharacter(at charIndex: Int) -> Bool {
        return false
    }
    
    override func insertNewline(_ sender: Any?) {
        editTextEditor?.insertNewline()
    }
    override func insertTab(_ sender: Any?) {
        editTextEditor?.insertTab()
    }
    override func deleteBackward(_ sender: Any?) {
        editTextEditor?.deleteBackward()
    }
    override func deleteForward(_ sender: Any?) {
        editTextEditor?.deleteForward()
    }
    override func moveLeft(_ sender: Any?) {
        editTextEditor?.moveLeft()
    }
    override func moveRight(_ sender: Any?) {
        editTextEditor?.moveRight()
    }
}

protocol TextInput {
}

extension NSCoding {
    static func with(_ data: Data) -> Self? {
        return data.isEmpty ? nil : NSKeyedUnarchiver.unarchiveObject(with: data) as? Self
    }
    var data: Data {
        return NSKeyedArchiver.archivedData(withRootObject: self)
    }
}
extension NSCoder {
    func decodeStruct<T: ByteCoding>(forKey key: String) -> T? {
        return T(coder: self, forKey: key)
    }
    func encodeStruct(_ byteCoding: ByteCoding, forKey key: String) {
        byteCoding.encode(in: self, forKey: key)
    }
}
protocol ByteCoding {
    init?(coder: NSCoder, forKey key: String)
    func encode(in coder: NSCoder, forKey key: String)
    init(data: Data)
    var data: Data { get }
}
extension ByteCoding {
    init?(coder: NSCoder, forKey key: String) {
        var length = 0
        if let ptr = coder.decodeBytes(forKey: key, returnedLength: &length) {
            self = UnsafeRawPointer(ptr).assumingMemoryBound(to: Self.self).pointee
        } else {
            return nil
        }
    }
    func encode(in coder: NSCoder, forKey key: String) {
        var t = self
        withUnsafePointer(to: &t) {
            coder.encodeBytes(UnsafeRawPointer($0).bindMemory(to: UInt8.self, capacity: 1), length: MemoryLayout<Self>.size, forKey: key)
        }
    }
    init(data: Data) {
        self = data.withUnsafeBytes {
            UnsafeRawPointer($0).assumingMemoryBound(to: Self.self).pointee
        }
    }
    var data: Data {
        var t = self
        return Data(buffer: UnsafeBufferPointer(start: &t, count: 1))
    }
}
extension Array: ByteCoding {
    init?(coder: NSCoder, forKey key: String) {
        var length = 0
        if let ptr = coder.decodeBytes(forKey: key, returnedLength: &length) {
            let count = length/MemoryLayout<Element>.stride
            self = count == 0 ? [] : ptr.withMemoryRebound(to: Element.self, capacity: 1) {
                Array(UnsafeBufferPointer<Element>(start: $0, count: count))
            }
        } else {
            return nil
        }
    }
    func encode(in coder: NSCoder, forKey key: String) {
        withUnsafeBufferPointer { ptr in
            ptr.baseAddress?.withMemoryRebound(to: UInt8.self, capacity: 1) {
                coder.encodeBytes($0, length: ptr.count*MemoryLayout<Element>.stride, forKey: key)
            }
        }
    }
}

extension NSColor {
    final class func checkerboardColor(_ color: NSColor, subColor: NSColor, size s: CGFloat = 5.0) -> NSColor {
        let size = NSSize(width: s*2,  height: s*2)
        let image = NSImage(size: size) { ctx in
            let rect = CGRect(origin: CGPoint(), size: size)
            ctx.setFillColor(color.cgColor)
            ctx.fill(rect)
            ctx.fill(CGRect(x: 0, y: s, width: s, height: s))
            ctx.fill(CGRect(x: s, y: 0, width: s, height: s))
            ctx.setFillColor(subColor.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))
            ctx.fill(CGRect(x: s, y: s, width: s, height: s))
        }
        return NSColor(patternImage: image)
    }
    static func polkaDotColorWith(color: NSColor?, dotColor: NSColor, radius r: CGFloat = 1.0, distance d: CGFloat = 4.0) -> NSColor {
        let tw = (2*r + d)*cos(.pi/3), th = (2*r + d)*sin(.pi/3)
        let bw = (tw - 2*r)/2, bh = (th - 2*r)/2
        let size = CGSize(width: floor(bw*2 + tw + r*2), height: floor(bh*2 + th + r*2))
        let image = NSImage(size: size) { ctx in
            if let color = color {
                ctx.setFillColor(color.cgColor)
                ctx.fill(CGRect(origin: CGPoint(), size: size))
            }
            ctx.setFillColor(dotColor.cgColor)
            ctx.fillEllipse(in: CGRect(x: bw, y: bh, width: r*2, height: r*2))
            ctx.fillEllipse(in: CGRect(x: bw + tw, y: bh + th, width: r*2, height: r*2))
        }
        return NSColor(patternImage: image)
    }
}

extension NSImage {
    convenience init(size: CGSize, handler: (CGContext) -> Void) {
        self.init(size: size)
        lockFocus()
        if let ctx = NSGraphicsContext.current()?.cgContext {
            handler(ctx)
        }
        unlockFocus()
    }
    final var bitmapSize: CGSize {
        if let tiffRepresentation = tiffRepresentation {
            if let bitmap = NSBitmapImageRep(data: tiffRepresentation) {
                return CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
            }
        }
        return CGSize()
    }
    final var PNGRepresentation: Data? {
        if let tiffRepresentation = tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffRepresentation) {
            return bitmap.representation(using: .PNG, properties: [NSImageInterlaced: false])
        } else {
            return nil
        }
    }
    static func exportAppIcon() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.begin { [unowned panel] result in
            if result == NSFileHandlingPanelOKButton, let url = panel.url {
                for s in [16.0.cf, 32.0.cf, 64.0.cf, 128.0.cf, 256.0.cf, 512.0.cf, 1024.0.cf] {
                    try? NSImage(size: CGSize(width: s, height: s), flipped: false) { rect -> Bool in
                        let ctx = NSGraphicsContext.current()!.cgContext, c = s*0.5, r = s*0.43, l = s*0.008, fs = s*0.45, fillColor = NSColor(white: 1, alpha: 1), fontColor = NSColor(white: 0.4, alpha: 1)
                        ctx.setFillColor(fillColor.cgColor)
                        ctx.setStrokeColor(fontColor.cgColor)
                        ctx.setLineWidth(l)
                        ctx.addEllipse(in: CGRect(x: c - r, y: c - r, width: r*2, height: r*2))
                        ctx.drawPath(using: .fillStroke)
                        var textLine = TextLine()
                        textLine.string = "C\u{2080}"
                        textLine.font = NSFont(name: "Avenir Next Regular", size: fs) ?? NSFont.systemFont(ofSize: fs)
                        textLine.color = fontColor.cgColor
                        textLine.isHorizontalCenter = true
                        textLine.isCenterWithImageBounds = true
                        textLine.draw(in: rect, in: ctx)
                        return true
                        }.PNGRepresentation?.write(to: url.appendingPathComponent("\(String(Int(s))).png"))
                }
            }
        }
    }
}

extension NSAttributedString {
    static func attributes(_ font: NSFont, color: CGColor) -> [String: Any] {
        return [String(kCTFontAttributeName): font, String(kCTForegroundColorAttributeName): color]
    }
}

extension Bundle {
    var version: Int {
        return Int(infoDictionary?[String(kCFBundleVersionKey)] as? String ?? "0") ?? 0
    }
}
