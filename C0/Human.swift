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
//ReferenceEditorをポップアップ形式にする

import Foundation
import QuartzCore

protocol HumanDelegate: class {
    func didChangeEditTextEditor(_ human: Human, oldEditTextEditor: TextEditor?)
    func didChangeCursor(_ human: Human, cursor: Cursor, oldCursor: Cursor)
}
final class Human: Respondable, Localizable {
    static let name = Localization(english: "Human", japanese: "人間")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var locale = Locale.current {
        didSet {
            if locale.languageCode != oldValue.languageCode {
                vision.allChildren { ($0 as? Localizable)?.locale = locale }
            }
        }
    }
    var sight: CGFloat = GlobalVariable.shared.backingScaleFactor {
        didSet {
            if sight != oldValue {
                vision.allChildren { ($0 as? LayerRespondable)?.contentsScale = sight }
            }
        }
    }
    var visionSize = CGSize() {
        didSet {
            CATransaction.disableAnimation {
                vision.frame.size = visionSize
                let padding: CGFloat = 5.0
                let virtualHeight = actionEditor.frame.height + copyObjectEditor.frame.height + referenceEditor.frame.height
                let inSize = CGSize(
                    width: vision.sceneEditor.frame.width + actionEditor.frame.width + padding*3,
                    height: max(vision.sceneEditor.frame.height, virtualHeight + padding*4)
                )
                let y = round((visionSize.height - inSize.height)/2)
                let origin = CGPoint(
                    x: max(0, round((visionSize.width - inSize.width)/2)),
                    y: min(visionSize.height, y + inSize.height) - inSize.height
                )
                vision.sceneEditor.frame.origin = CGPoint(
                    x: origin.x + padding,
                    y: origin.y + inSize.height - vision.sceneEditor.frame.height - padding
                )
                actionEditor.frame.origin = CGPoint(
                    x: origin.x + vision.sceneEditor.frame.width + padding*2,
                    y: origin.y + inSize.height - actionEditor.frame.height - padding
                )
                copyObjectEditor.frame.origin = CGPoint(
                    x: origin.x + vision.sceneEditor.frame.width + padding*2,
                    y: origin.y + inSize.height - actionEditor.frame.height - copyObjectEditor.frame.height - padding*2
                )
                referenceEditor.frame.origin = CGPoint(
                    x: origin.x + vision.sceneEditor.frame.width + padding*2,
                    y: origin.y + inSize.height - virtualHeight - padding*3
                )
            }
        }
    }
    
    weak var delegate: HumanDelegate?
    
    let vision = Vision()
    let actionEditor = ActionEditor()
    let copyObjectEditor = CopyObjectEditor()
    let referenceEditor = ReferenceEditor()
    var editTextEditor: TextEditor? {
        return indicationResponder as? TextEditor
    }
    var editQuasimode = EditQuasimode.none
    
    init() {
        self.indicationResponder = vision
        vision.virtual.children = [actionEditor, copyObjectEditor, referenceEditor]
    }
    
    var indicationResponder: Respondable {
        didSet {
            if indicationResponder !== oldValue {
                oldValue.allParents { $0.indication = false }
                indicationResponder.allParents { $0.indication = true }
                if let editTextEditor = oldValue as? TextEditor {
                    delegate?.didChangeEditTextEditor(self, oldEditTextEditor: editTextEditor)
                }
            }
        }
    }
    func setIndicationResponder(with p: CGPoint) {
        let hitResponder = vision.at(p) ?? vision
        if indicationResponder !== hitResponder {
            self.indicationResponder = hitResponder
        }
    }
    func indicationResponder(with event: Event) -> Respondable {
        return vision.at(event.location) ?? vision
    }
    func contains(_ p: CGPoint) -> Bool {
        return false
    }
    
    func sendMoveCursor(with event: MoveEvent) {
        let hitResponder = vision.at(event.location) ?? vision
        if indicationResponder !== hitResponder {
            let oldIndicationResponder = indicationResponder
            self.indicationResponder = hitResponder
            if indicationResponder.editQuasimode != editQuasimode {
                indicationResponder.setEditQuasimode(editQuasimode, with: event)
            }
            if oldIndicationResponder.editQuasimode != .none {
                indicationResponder.setEditQuasimode(.none, with: event)
            }
        }
        self.cursor = indicationResponder.cursor
        indicationResponder.moveCursor(with: event)
    }
    
    var cursor = Cursor.arrow {
        didSet {
            delegate?.didChangeCursor(self, cursor: cursor, oldCursor: oldValue)
        }
    }
    
    private var oldQuasimodeAction = Action()
    private weak var oldQuasimodeResponder: Respondable?
    func sendEditQuasimode(with event: Event) {
        let quasimodeAction = actionEditor.actionNode.actionWith(.drag, event) ?? Action()
        if !isDown {
            if editQuasimode != quasimodeAction.editQuasimode {
                self.editQuasimode = quasimodeAction.editQuasimode
                indicationResponder.setEditQuasimode(quasimodeAction.editQuasimode, with: event)
                self.cursor = indicationResponder.cursor
            }
        }
        self.oldQuasimodeAction = quasimodeAction
        self.oldQuasimodeResponder = indicationResponder
    }
    
    private var isKey = false, keyAction = Action(), keyEvent: KeyInputEvent?
    private weak var keyTextEditor: TextEditor?
    func sendKeyInputIsEditText(with event: KeyInputEvent) -> Bool {
        switch event.sendType {
        case .begin:
            guard !isDown else {
                self.keyEvent = event
                return false
            }
            self.isKey = true
            self.keyAction = actionEditor.actionNode.actionWith(.keyInput, event) ?? Action()
            if let editTextEditor = editTextEditor, keyAction.canTextKeyInput() {
                self.keyTextEditor = editTextEditor
                return true
            } else if keyAction != Action() {
                keyAction.keyInput?(self, indicationResponder, event)
                if let undoManager = indicationResponder.undoManager, undoManager.groupingLevel >= 1 {
                     indicationResponder.undoManager?.setActionName(
                        type(of: indicationResponder).name.currentString + "." + keyAction.name.currentString
                    )
                }
            }
            let newIndicationResponder = vision.at(event.location) ?? vision
            if self.indicationResponder !== newIndicationResponder {
                self.indicationResponder = newIndicationResponder
                self.cursor = indicationResponder.cursor
            }
        case .sending:
            break
        case .end:
            if keyTextEditor != nil, isKey {
                self.keyTextEditor = nil
                return true
            }
        }
        return false
    }
    
    private let defaultClickAction = Action(gesture: .click), defaultDragAction = Action(drag: { $1.drag(with: $2) })
    private var isDown = false, isDrag = false, dragAction = Action()
    private weak var dragResponder: Respondable?
    func sendDrag(with event: DragEvent) {
        switch event.sendType {
        case .begin:
            setIndicationResponder(with: event.location)
            self.isDown = true
            self.isDrag = false
            self.dragResponder = indicationResponder
            if let dragResponder = dragResponder {
                self.dragAction = actionEditor.actionNode.actionWith(.drag, event) ?? defaultDragAction
                dragAction.drag?(self, dragResponder, event)
            }
        case .sending:
            self.isDrag = true
            if isDown, let dragResponder = dragResponder {
                dragAction.drag?(self, dragResponder, event)
            }
        case .end:
            if isDown {
                if let dragResponder = dragResponder {
                    dragAction.drag?(self, dragResponder, event)
                }
                if !isDrag {
                    dragResponder?.click(with: event)
                }
                self.isDown = false
                
                if let keyEvent = keyEvent {
                    _ = sendKeyInputIsEditText(with: keyEvent.with(sendType: .begin))
                    self.keyEvent = nil
                } else {
                    if let undoManager = indicationResponder.undoManager, undoManager.groupingLevel >= 1 {
                        if isDrag {
                            indicationResponder.undoManager?.setActionName(
                                type(of: indicationResponder).name.currentString + "." + dragAction.name.currentString
                            )
                        } else {
                            let clickActionName = (actionEditor.actionNode.actionWith(.click, event) ?? defaultClickAction).name
                            indicationResponder.undoManager?.setActionName(
                                type(of: indicationResponder).name.currentString + "." + clickActionName.currentString
                            )
                        }
                    }
                    let newIndicationResponder = vision.at(event.location) ?? vision
                    if self.indicationResponder !== newIndicationResponder {
                        self.indicationResponder = newIndicationResponder
                        self.cursor = indicationResponder.cursor
                    }
                }
                self.isDrag = false
                
                if dragAction != oldQuasimodeAction {
                    if let dragResponder = dragResponder {
                        if indicationResponder !== dragResponder {
                            dragResponder.setEditQuasimode(.none, with: event)
                        }
                    }
                    self.editQuasimode = oldQuasimodeAction.editQuasimode
                    indicationResponder.setEditQuasimode(oldQuasimodeAction.editQuasimode, with: event)
                }
            }
        }
    }
    
    private weak var momentumScrollResponder: Respondable?
    func sendScroll(with event: ScrollEvent, momentum: Bool) {
        let indicationResponder = vision.at(event.location) ?? vision
        if !momentum {
            self.momentumScrollResponder = indicationResponder
        }
        if let momentumScrollResponder = momentumScrollResponder {
            momentumScrollResponder.scroll(with: event)
        }
        setIndicationResponder(with: event.location)
        self.cursor = indicationResponder.cursor
    }
    func sendZoom(with event: PinchEvent) {
        indicationResponder.zoom(with: event)
    }
    func sendRotate(with event: RotateEvent) {
        indicationResponder.rotate(with: event)
    }
    
    func sendLookup(with event: TapEvent) {
        setReference(indicationResponder(with: event).lookUp(with: event), oldReference: referenceEditor.reference)
    }
    func setReference(_ reference: Referenceable?, oldReference: Referenceable?) {
        vision.sceneEditor.undoManager?.registerUndo(withTarget: self) {
            $0.setReference(oldReference, oldReference: reference)
        }
        referenceEditor.reference = reference
//        if reference == nil {
//            
//        } else {
////            referenceEditor.frame.origin = CGPoint
//            vision.virtual.children.append(referenceEditor)
//        }
    }
    
    func sendReset(with event: DoubleTapEvent) {
        indicationResponder(with: event).reset(with: event)
    }
    
    func copy(with event: KeyInputEvent) -> CopyObject {
        return copyObjectEditor.copyObject
    }
    func paste(_ copyObject: CopyObject, with event: KeyInputEvent) {
        setCopyObject(copyObject, oldCopyObject: copyObjectEditor.copyObject)
    }
    func setCopyObject(_ copyObject: CopyObject, oldCopyObject: CopyObject) {
        vision.sceneEditor.undoManager?.registerUndo(withTarget: self) {
            $0.setCopyObject(oldCopyObject, oldCopyObject: copyObject)
        }
        copyObjectEditor.copyObject = copyObject
    }
}

final class Vision: LayerRespondable {
    static let name = Localization(english: "Vision", japanese: "視界")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager? = UndoManager()
    
    let real = GroupResponder(), virtual = GroupResponder()
    
    var layer = CALayer() {
        didSet {
            layer.backgroundColor = Color.background.cgColor
            layer.sublayers = children.flatMap { ($0 as? LayerRespondable)?.layer }
        }
    }
    init() {
        real.children = [sceneEditor]
        self.children = [real, virtual]
        update(withChildren: children)
        
        if let sceneEditorDataModel = sceneEditor.dataModel {
            dataModel = DataModel(key: Vision.dataModelKey, directoryWithChildren: [sceneEditorDataModel])
        } else {
            dataModel = DataModel(key: Vision.dataModelKey, directoryWithChildren: [])
        }
    }
    
    static let dataModelKey = "vision"
    var sceneEditor = SceneEditor()
    var dataModel: DataModel? {
        didSet {
            if let sceneEditorDataModel = dataModel?.children[SceneEditor.sceneEditorKey] {
                sceneEditor.dataModel = sceneEditorDataModel
            } else if let sceneEditorDataModel = sceneEditor.dataModel {
                dataModel?.insert(sceneEditorDataModel)
            }
        }
    }
}

protocol CopyData: Referenceable {
    static var identifier: String { get }
    var data: Data { get }
    static func with(_ data: Data) -> Self?
}
extension CopyData {
    static var identifier: String {
        return String(describing: type(of: self))
    }
}
struct CopyObject {
    var objects: [CopyData]
    init(objects: [CopyData] = []) {
        self.objects = objects
    }
}
final class CopyObjectEditor: LayerRespondable {
    static let name = Localization(english: "Copy Object Editor", japanese: "コピーオブジェクトエディタ")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager?
    
    var changeCount = 0
    
    let layer = CALayer.interfaceLayer(isPanel: true)
    var thumbnailGroups = [GroupResponder]() {
        didSet {
            if thumbnailGroups.isEmpty {
                self.children = [CopyObjectEditor.noCopyLabel(bounds: bounds)]
            } else {
                self.children = thumbnailGroups
            }
        }
    }
    static func noCopyLabel(bounds: CGRect) -> Label {
        let label = Label(
            text: Localization(english: "No Copy", japanese: "コピーなし"),
            font: Font.small, color: Color.smallFont, paddingWidth: 0, isSizeToFit: false
        )
        label.textLine.isCenterWithImageBounds = true
        label.frame = bounds
        return label
    }
    init() {
        layer.masksToBounds = true
        layer.frame = CGRect(x: 0, y: 0, width: 190, height: 56)
        self.children = [CopyObjectEditor.noCopyLabel(bounds: bounds)]
        update(withChildren: children)
    }
    var copyObject = CopyObject() {
        didSet {
            changeCount += 1
            CATransaction.disableAnimation {
                var x = 5.0.cf
                thumbnailGroups = copyObject.objects.map { object in
                    let size = CGSize(width: 44, height: 44), labelHeight = 12.0.cf, padding = 2.0.cf
                    let label = Label(text: type(of: object).name, font: Font.small, color: Color.smallFont)
                    label.textLine.isCenterWithImageBounds = true
                    let frame = CGRect(x: x, y: 0, width: max(size.width, label.textLine.imageBounds.width), height: size.height)
                    label.frame = CGRect(x: 0, y: padding, width: frame.width, height: labelHeight)
                    let thumbnailEditor = DrawEditor(
                        drawable: object as? Drawable,
                        frame: CGRect(
                            x: round((frame.width - size.width)/2),
                            y: labelHeight + padding,
                            width: size.width - padding*2,
                            height: size.height - padding*2
                        )
                    )
                    x += frame.width + 5
                    return GroupResponder(children: [thumbnailEditor, label], frame: frame)
                }
            }
        }
    }
    
    func delete(with event: KeyInputEvent) {
        copyObject = CopyObject()
    }
}

final class UndoEditor: LayerRespondable, Localizable {
    static let name = Localization(english: "Undo Editor", japanese: "取り消しエディタ")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    private var token: NSObjectProtocol?
    var undoManager: UndoManager? {
        didSet {
            if let token = token {
                NotificationCenter.default.removeObserver(token)
            }
            token = NotificationCenter.default.addObserver(
                forName: NSNotification.Name.NSUndoManagerCheckpoint, object: undoManager, queue: nil,
                using: { [unowned self] _ in self.updateLabel()  }
            )
            updateLabel()
        }
    }
    var locale = Locale.current {
        didSet {
            updateLabel()
        }
    }
    
    let layer = CALayer.interfaceLayer()
    let label = Label(string: "", font: Font.small, color: Color.smallFont, height: 0)
    let redoLabel = Label(string: "", font: Font.small, color: Color.smallFont, height: 0)
    init() {
        children = [label, redoLabel]
        update(withChildren: children)
    }
    deinit {
        if let token = token {
            NotificationCenter.default.removeObserver(token)
        }
    }
    
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            layer.frame = newValue
            label.sizeToFit(withHeight: newValue.height/2)
            redoLabel.sizeToFit(withHeight: newValue.height/2)
            label.frame.origin.y = newValue.height/2
            updateLabel()
        }
    }
    func updateLabel() {
        if let undoManager = undoManager {
            CATransaction.disableAnimation {
                label.textLine.string = Localization(english: "Undo", japanese: "取り消し").currentString + ": " + (
                    undoManager.canUndo ?
                        undoManager.undoActionName :
                        Localization(english: "None", japanese: "なし").currentString
                )
                redoLabel.textLine.string = Localization(english: "Redo", japanese: "やり直し").currentString + ": " + (
                    undoManager.canRedo ?
                        undoManager.redoActionName :
                        Localization(english: "None", japanese: "なし").currentString
                )
                label.sizeToFit(withHeight: frame.height/2)
                redoLabel.sizeToFit(withHeight: frame.height/2)
            }
        }
    }
}

protocol Drawable {
    func draw(with bounds: CGRect, in ctx: CGContext)
}
final class DrawEditor: LayerRespondable {
    static let name = Localization(english: "Draw Editor", japanese: "描画エディタ")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager?
    
    init(drawable: Drawable? = nil, frame: CGRect = CGRect()) {
        if let drawable = drawable {
            self.drawable = drawable
            drawLayer.drawBlock = { [unowned self] ctx in
                self.drawable?.draw(with: self.bounds, in: ctx)
            }
            drawLayer.setNeedsDisplay()
        }
        layer.frame = frame
    }
    var drawable: Drawable? {
        didSet {
            drawLayer.drawBlock = { [unowned self] ctx in
                self.drawable?.draw(with: self.bounds, in: ctx)
            }
            drawLayer.setNeedsDisplay()
        }
    }
    var layer: CALayer {
        return drawLayer
    }
    let drawLayer = DrawLayer(fillColor: Color.subBackground)
}

protocol Referenceable {
    static var name: Localization { get }
    static var description: Localization { get }
    var description: Localization { get }
}
extension Referenceable {
    static var description: Localization {
        return Localization()
    }
    var description: Localization {
        return Localization()
    }
}
final class ReferenceEditor: LayerRespondable {
    static let name = Localization(english: "Reference Editor", japanese: "情報エディタ")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager?
    
    let layer = CALayer.interfaceLayer(isPanel: true)
    let minBounds = CGRect(x: 0, y: 0, width: 190, height: 90)
    init() {
        layer.frame = minBounds
    }
    
    var reference: Referenceable? {
        didSet {
            CATransaction.disableAnimation {
                if let reference = reference {
                    let cas = ReferenceEditor.childrenAndSize(with: reference, in: minBounds)
                    self.children = cas.children
                    if cas.size.height > minBounds.height {
                        frame = CGRect(
                            x: frame.origin.x, y: frame.origin.y - (cas.size.height - frame.height),
                            width: minBounds.width, height: cas.size.height
                        )
                    } else {
                        frame = CGRect(
                            x: frame.origin.x, y: frame.origin.y - (minBounds.height - frame.height),
                            width: minBounds.width, height: minBounds.height
                        )
                    }
                } else {
                    children = []
                }
            }
        }
    }
    static func childrenAndSize(with reference: Referenceable, in frame: CGRect) -> (children: [Respondable], size: CGSize) {
        let type =  type(of: reference).name, description = type(of: reference).description, instanceDescription = reference.description
        let typeLabel = Label(text: type, font: Font.hedding, height: 16)
        let descriptionLabel = Label(
            text: description.isEmpty ?
                Localization(english: "No description", japanese: "説明なし") :
            description, font: Font.small, color: Color.smallFont, width: frame.width
        )
        let instanceLabel = Label(text: type + Localization(english: " (Instance)", japanese: " (インスタンス)"), font: Font.hedding, height: 16)
        let instanceDescriptionLabel = Label(
            text: instanceDescription.isEmpty ?
                Localization(english: "No description", japanese: "説明なし") : instanceDescription,
            font: Font.small, color: Color.smallFont, width: frame.width
        )
        
        typeLabel.frame.origin = CGPoint(x: 0, y: frame.height - typeLabel.frame.height - 5)
        descriptionLabel.frame.origin = CGPoint(x: 0, y: frame.height - typeLabel.frame.height - descriptionLabel.frame.height - 5)
        instanceLabel.frame.origin = CGPoint(
            x: 0,
            y: frame.height - typeLabel.frame.height - descriptionLabel.frame.height - instanceLabel.frame.height - 10
        )
        instanceDescriptionLabel.frame.origin = CGPoint(
            x: 0,
            y: frame.height - typeLabel.frame.height - descriptionLabel.frame.height
                - instanceLabel.frame.height - instanceDescriptionLabel.frame.height - 10
        )
        let size = CGSize(
            width: ceil(max(typeLabel.frame.width, descriptionLabel.frame.width, instanceDescriptionLabel.frame.width) + 10),
            height: ceil(typeLabel.frame.height + descriptionLabel.frame.height + instanceDescriptionLabel.frame.height + 15)
        )
        return ([typeLabel, descriptionLabel, instanceLabel, instanceDescriptionLabel], size)
    }
    
    func delete(with event: KeyInputEvent) {
        reference = nil
    }
}
