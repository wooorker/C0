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

protocol HumanDelegate: class {
    func didChangeEditText(_ human: Human, oldEditText: Text?)
    func didChangeCursor(_ human: Human, cursor: Cursor, oldCursor: Cursor)
}
final class Human: Respondable {
    static let name = Localization(english: "Human", japanese: "人間")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    weak var delegate: HumanDelegate?
    
    struct Preference: Codable {
        var isHiddenAction = false
    }
    var preference = Preference() {
        didSet {
            actionEditor.isHiddenButton.selectionIndex = preference.isHiddenAction ? 0 : 1
            actionEditor.isHiddenActions = preference.isHiddenAction
            updateChildren()
        }
    }
    
    var worldDataModel: DataModel
    var preferenceDataModel = DataModel(key: preferenceDataModelKey)
    
    let vision = GroupResponder()
    let copiedObjectEditor = CopiedObjectEditor(), actionEditor = ActionEditor()
    let world = GroupResponder()
    let referenceEditor = ReferenceEditor()
    var editText: Text? {
        if let editText = indicationResponder as? Text {
            return editText.isLocked ? nil : editText
        } else {
            return nil
        }
    }
    var editQuasimode = EditQuasimode.none
    
    let sceneEditor = SceneEditor()
    
    init() {
        if let sceneEditorDataModel = sceneEditor.dataModel {
            worldDataModel = DataModel(key: Human.worldDataModelKey,
                                       directoryWithChildren: [sceneEditorDataModel])
        } else {
            worldDataModel = DataModel(key: Human.worldDataModelKey, directoryWithChildren: [])
        }
        self.dataModel = DataModel(key: Human.dataModelKey,
                                   directoryWithChildren: [preferenceDataModel, worldDataModel])
        
        self.indicationResponder = vision
        world.children = [sceneEditor]
        vision.children = [copiedObjectEditor, actionEditor, world]
        
        self.actionEditor.isHiddenActionBinding = { [unowned self] in
            self.preference.isHiddenAction = $0
            self.updateChildren()
            self.preferenceDataModel.isWrite = true
        }
        preferenceDataModel.dataHandler = { [unowned self] in return self.preference.jsonData }
    }
    static let dataModelKey = "human"
    static let worldDataModelKey = "world", preferenceDataModelKey = "preference"
    var dataModel: DataModel? {
        didSet {
            if let worldDataModel = dataModel?.children[Human.worldDataModelKey] {
                self.worldDataModel = worldDataModel
            }
            if let preferenceDataModel = dataModel?.children[Human.preferenceDataModelKey] {
                self.preferenceDataModel = preferenceDataModel
                if let preference: Preference = preferenceDataModel.readObject() {
                    self.preference = preference
                }
                preferenceDataModel.dataHandler = { [unowned self] in
                    return self.preference.jsonData
                }
            }
            if let sceneEditorDataModel = worldDataModel.children[SceneEditor.sceneEditorKey] {
                sceneEditor.dataModel = sceneEditorDataModel
            } else if let sceneEditorDataModel = sceneEditor.dataModel {
                worldDataModel.insert(sceneEditorDataModel)
            }
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
                vision.allChildren { $0.contentsScale = sight }
            }
        }
    }
    var actionWidth = ActionEditor.defaultWidth
    var copyEditorHeight = Layout.basicHeight + Layout.basicPadding * 2
    var fieldOfVision = CGSize() {
        didSet {
            CATransaction.disableAnimation {
                vision.frame.size = fieldOfVision
            }
            updateChildren()
        }
    }
    
    func updateChildren() {
        CATransaction.disableAnimation {
            let padding = Layout.basicPadding
            if preference.isHiddenAction {
                actionEditor.frame = CGRect(
                    x: padding,
                    y: fieldOfVision.height - actionEditor.frame.height - padding,
                    width: actionWidth,
                    height: actionEditor.frame.height
                )
                copiedObjectEditor.frame = CGRect(
                    x: padding + actionWidth,
                    y: fieldOfVision.height - copyEditorHeight - padding,
                    width: fieldOfVision.width - actionWidth - padding * 2,
                    height: copyEditorHeight
                )
                world.frame = CGRect(
                    x: padding,
                    y: padding,
                    width: vision.frame.width - padding * 2,
                    height: vision.frame.height - copyEditorHeight - padding * 2
                )
            } else {
                actionEditor.frame = CGRect(
                    x: padding,
                    y: fieldOfVision.height - actionEditor.frame.height - padding,
                    width: actionWidth,
                    height: actionEditor.frame.height
                )
                copiedObjectEditor.frame = CGRect(
                    x: padding + actionWidth,
                    y: fieldOfVision.height - copyEditorHeight - padding,
                    width: fieldOfVision.width - actionWidth - padding * 2,
                    height: copyEditorHeight
                )
                world.frame = CGRect(
                    x: padding + actionWidth,
                    y: padding,
                    width: vision.frame.width - (padding * 2 + actionWidth),
                    height: vision.frame.height - copyEditorHeight - padding * 2
                )
            }
            world.bounds.origin = CGPoint(
                x: -round((world.frame.width / 2)),
                y: -round((world.frame.height / 2))
            )
            sceneEditor.frame.origin = CGPoint(
                x: -round(sceneEditor.frame.width / 2),
                y: -round(sceneEditor.frame.height / 2)
            )
        }
    }
    
    var indicationResponder: Respondable {
        didSet {
            if indicationResponder !== oldValue {
                var allParents = [Respondable]()
                indicationResponder.allIndicationParents { allParents.append($0) }
                oldValue.allIndicationParents { responder in
                    if let index = allParents.index(where: { $0 === responder }) {
                        allParents.remove(at: index)
                    } else {
                        responder.isSubIndication = false
                    }
                }
                allParents.forEach { $0.isSubIndication = true }
                oldValue.isIndication = false
                indicationResponder.isIndication = true
                if let editText = oldValue as? Text {
                    editText.unmarkText()
                    delegate?.didChangeEditText(self, oldEditText: editText)
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
                indicationResponder.set(editQuasimode, with: event)
            }
            if oldIndicationResponder.editQuasimode != .none {
                indicationResponder.set(EditQuasimode.none, with: event)
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
        let quasimodeAction = actionEditor.actionManager.actionWith(.drag, event) ?? Action()
        if !isDown {
            if editQuasimode != quasimodeAction.editQuasimode {
                self.editQuasimode = quasimodeAction.editQuasimode
                indicationResponder.set(quasimodeAction.editQuasimode, with: event)
                self.cursor = indicationResponder.cursor
            }
        }
        self.oldQuasimodeAction = quasimodeAction
        self.oldQuasimodeResponder = indicationResponder
    }
    
    private var isKey = false, keyAction = Action(), keyEvent: KeyInputEvent?
    private weak var keyText: Text?
    func sendKeyInputIsEditText(with event: KeyInputEvent) -> Bool {
        switch event.sendType {
        case .begin:
            setIndicationResponder(with: event.location)
            guard !isDown else {
                self.keyEvent = event
                return false
            }
            self.isKey = true
            self.keyAction = actionEditor.actionManager.actionWith(.keyInput, event) ?? Action()
            if let editText = editText, keyAction.canTextKeyInput() {
                self.keyText = editText
                return true
            } else if keyAction != Action() {
                keyAction.keyInput?(self, indicationResponder, event)
            }
            let newIndicationResponder = vision.at(event.location) ?? vision
            if self.indicationResponder !== newIndicationResponder {
                self.indicationResponder = newIndicationResponder
                self.cursor = indicationResponder.cursor
            }
        case .sending:
            break
        case .end:
            if keyText != nil, isKey {
                self.keyText = nil
                return false
            }
        }
        return false
    }
    
    func sendRightDrag(with event: DragEvent) {
        if event.sendType == .end {
            indicationResponder(with: event).showProperty(with: event)
            let newIndicationResponder = vision.at(event.location) ?? vision
            if self.indicationResponder !== newIndicationResponder {
                self.indicationResponder = newIndicationResponder
                self.cursor = indicationResponder.cursor
            }
        }
    }
    
    private let defaultClickAction = Action(gesture: .click)
    private let defaultDragAction = Action(drag: { $1.drag(with: $2) })
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
                self.dragAction = actionEditor.actionManager
                    .actionWith(.drag, event) ?? defaultDragAction
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
                            dragResponder.set(EditQuasimode.none, with: event)
                        }
                    }
                    self.editQuasimode = oldQuasimodeAction.editQuasimode
                    indicationResponder.set(oldQuasimodeAction.editQuasimode, with: event)
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
        let p = event.location.integral
        let rp = CGPoint(x: p.x - 5, y: p.y + 5)
        let responder = indicationResponder(with: event)
        let reference = responder.lookUp(with: event)
        let newIndicationResponder = vision.at(event.location) ?? vision
        if self.indicationResponder !== newIndicationResponder {
            self.indicationResponder = newIndicationResponder
            self.cursor = indicationResponder.cursor
        }
        referenceEditor.reference = reference
        CATransaction.disableAnimation {
            referenceEditor.frame.origin = CGPoint(x: rp.x, y: rp.y - referenceEditor.frame.height)
            if !vision.children.contains(where: { $0 === referenceEditor }) {
                vision.children.append(referenceEditor)
            }
        }
    }
    
    func sendReset(with event: DoubleTapEvent) {
        indicationResponder(with: event).reset(with: event)
        setIndicationResponder(with: event.location)
    }
    
    func copy(with event: KeyInputEvent) -> CopiedObject {
        return copiedObjectEditor.copiedObject
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        copiedObjectEditor.paste(copiedObject, with: event)
    }
}

struct CopiedObject {
    var objects: [Any]
    init(objects: [Any] = []) {
        self.objects = objects
    }
}
final class ObjectEditor: LayerRespondable, Localizable {
    static let name = Localization(english: "Object Editor", japanese: "オブジェクトエディタ")
    var instanceDescription: Localization {
        return (object as? Referenceable)?.valueDescription ?? Localization()
    }
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var locale = Locale.current {
        didSet {
            updateFrameWith(origin: frame.origin,
                            thumbnailWidth: thumbnailWidth, height: frame.height)
        }
    }
    
    let object: Any
    
    static let thumbnailWidth = 40.0.cf
    let thumbnailEditor: DrawEditor, label: Label, thumbnailWidth: CGFloat
    let endLabel = Label(
        text: Localization(")")
    )
    let layer = CALayer.interfaceLayer()
    init(object: Any, origin: CGPoint,
         thumbnailWidth: CGFloat = ObjectEditor.thumbnailWidth, height: CGFloat) {
        
        self.object = object
        if let reference = object as? Referenceable {
            self.label = Label(text: type(of: reference).name + Localization("("))
        } else {
            self.label = Label(text: Localization(String(describing: type(of: object)) + "("))
        }
        self.thumbnailWidth = thumbnailWidth
        self.thumbnailEditor = DrawEditor(drawable: object as? Drawable)
        self.children = [label, thumbnailEditor, endLabel]
        update(withChildren: children, oldChildren: [])
        
        updateFrameWith(origin: origin, thumbnailWidth: thumbnailWidth, height: height)
    }
    func updateFrameWith(origin: CGPoint, thumbnailWidth: CGFloat, height: CGFloat) {
        let thumbnailHeight = height - Layout.basicPadding * 2
        let thumbnailSize = CGSize(width: thumbnailWidth, height: thumbnailHeight)
        let width = label.text.frame.width + thumbnailSize.width
            + endLabel.text.frame.width + Layout.basicPadding * 2
        layer.frame = CGRect(x: origin.x, y: origin.y, width: width, height: height)
        label.frame.origin = CGPoint(
            x: Layout.basicPadding, y: Layout.basicPadding
        )
        self.thumbnailEditor.frame = CGRect(
            x: label.frame.maxX,
            y: Layout.basicPadding,
            width: thumbnailSize.width,
            height: thumbnailSize.height
        )
        endLabel.frame.origin = CGPoint(
            x: thumbnailEditor.frame.maxX, y: Layout.basicPadding
        )
    }
    func copy(with event: KeyInputEvent) -> CopiedObject {
        return CopiedObject(objects: [object])
    }
}
final class CopiedObjectEditor: LayerRespondable, Localizable {
    static let name = Localization(english: "Copied Object Editor", japanese: "コピーオブジェクトエディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var locale = Locale.current {
        didSet {
            updateChildren()
        }
    }
    
    var undoManager: UndoManager? = UndoManager()
    
    var changeCount = 0
    
    var defaultBorderColor: CGColor? = Color.border.cgColor
    
    var objectEditors = [ObjectEditor]() {
        didSet {
            if objectEditors.isEmpty {
                self.children = [copyLabel, versionEditor, versionCommaLabel, noneLabel, copyEndLabel]
            } else {
                self.children = [copyLabel, versionEditor, versionCommaLabel] as [Respondable]
                    + objectEditors as [Respondable] + [copyEndLabel] as [Respondable]
            }
            Layout.leftAlignment(children, height: frame.height)
        }
    }
    let copyLabel = Label(
        text: Localization(english: "Copy Manager(", japanese: "コピー管理(")
    )
    let versionEditor = VersionEditor()
    let versionCommaLabel = Label(
        text: Localization(english: ", Copied:", japanese: ", コピー済み:")
    )
    let noneLabel = Label(
        text: Localization(english: "Empty", japanese: "空")
    )
    let copyEndLabel = Label(
        text: Localization(")")
    )
    let layer = CALayer.interfaceLayer(borderColor: .border)
    init() {
        versionEditor.frame = CGRect(x: 0, y: 0, width: 120, height: Layout.basicHeight)
        versionEditor.undoManager = undoManager
        layer.masksToBounds = true
        self.children = [copyLabel, versionEditor, versionCommaLabel, noneLabel, copyEndLabel]
        update(withChildren: children, oldChildren: [])
    }
    var copiedObject = CopiedObject() {
        didSet {
            changeCount += 1
            updateChildren()
        }
    }
    func updateChildren() {
        CATransaction.disableAnimation {
            var origin = CGPoint(x: Layout.basicPadding, y: Layout.basicPadding)
            objectEditors = copiedObject.objects.map { object in
                let objectEditor = ObjectEditor(
                    object: object, origin: origin,
                    height: frame.height - Layout.basicPadding * 2
                )
                origin.x += objectEditor.frame.width + Layout.basicPadding
                return objectEditor
            }
        }
    }
    
    func delete(with event: KeyInputEvent) {
        setCopiedObject(CopiedObject(), oldCopiedObject: copiedObject)
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        setCopiedObject(copiedObject, oldCopiedObject: self.copiedObject)
    }
    func setCopiedObject(_ copiedObject: CopiedObject, oldCopiedObject: CopiedObject) {
        undoManager?.registerUndo(withTarget: self) {
            $0.setCopiedObject(oldCopiedObject, oldCopiedObject: copiedObject)
        }
        self.copiedObject = copiedObject
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
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var layer: CALayer {
        return drawLayer
    }
    let drawLayer: DrawLayer
    
    var drawable: Drawable? {
        didSet {
            drawLayer.drawBlock = { [unowned self] ctx in
                self.drawable?.draw(with: self.bounds, in: ctx)
            }
            drawLayer.setNeedsDisplay()
        }
    }
    
    init(drawable: Drawable? = nil, frame: CGRect = CGRect(), backgroundColor: Color = .background) {
        self.drawLayer = DrawLayer(backgroundColor: backgroundColor)
        if let drawable = drawable {
            self.drawable = drawable
            drawLayer.drawBlock = { [unowned self] ctx in
                self.drawable?.draw(with: self.bounds, in: ctx)
            }
            drawLayer.setNeedsDisplay()
        }
        layer.frame = frame
    }
}

final class ReferenceEditor: LayerRespondable {
    static let name = Localization(english: "Reference Editor", japanese: "情報エディタ")
    static let feature = Localization(english: "Close: Move cursor to outside",
                                      japanese: "閉じる: カーソルを外に出す")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    let layer: CALayer
    let minWidth = 200.0.cf
    init() {
        layer = CALayer.interfaceLayer(backgroundColor: .background, borderColor: .border)
    }
    
    var defaultBorderColor: CGColor? = Color.border.cgColor
    var isSubIndication = false {
        didSet {
            if !isSubIndication {
                removeFromParent()
            }
        }
    }
    
    var reference: Referenceable? {
        didSet {
            CATransaction.disableAnimation {
                if let reference = reference {
                    let cas = ReferenceEditor.childrenAndSize(with: reference, width: minWidth)
                    self.children = cas.children
                    frame = CGRect(
                        x: frame.origin.x, y: frame.origin.y - (cas.size.height - frame.height),
                        width: cas.size.width, height: cas.size.height
                    )
                } else {
                    children = []
                }
            }
        }
    }
    static func childrenAndSize(with reference: Referenceable,
                                width: CGFloat) -> (children: [Respondable], size: CGSize) {
        
        let type =  Swift.type(of: reference).name, feature = Swift.type(of: reference).feature
        let instanceDescription = reference.instanceDescription
        let description: Localization
        if instanceDescription.isEmpty && feature.isEmpty {
            description = Localization(english: "No description", japanese: "説明なし")
        } else {
            description = !instanceDescription.isEmpty && !feature.isEmpty ?
                instanceDescription + Localization("\n\n") + feature : instanceDescription + feature
        }
        
        let typeLabel = Label(
            frame: CGRect(x: 0, y: 0, width: width, height: 0),
            text: type, font: .hedding0
        )
        let descriptionLabel = Label(
            frame: CGRect(x: 0, y: 0, width: width, height: 0),
            text: description
        )
        let size = CGSize(
            width: max(typeLabel.frame.width, descriptionLabel.frame.width) + Layout.basicPadding * 2,
            height: typeLabel.frame.height + descriptionLabel.frame.height + Layout.basicPadding * 5
        )
        var y = size.height - typeLabel.frame.height - Layout.basicPadding * 2
        typeLabel.frame.origin = CGPoint(x: Layout.basicPadding, y: y)
        y -= descriptionLabel.frame.height + Layout.basicPadding
        descriptionLabel.frame.origin = CGPoint(x: Layout.basicPadding, y: y)
        return ([typeLabel, descriptionLabel], size)
    }
    
    func delete(with event: KeyInputEvent) {
        reference = nil
    }
    
    let scroller = Scroller()
    func scroll(with event: ScrollEvent) {
        scroller.scroll(with: event, responder: self)
    }
}
