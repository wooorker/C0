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

final class Human: Respondable {
    static let name = Localization(english: "Human", japanese: "人間")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
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
    
    let vision = Vision()
    let copiedObjectEditor = CopiedObjectEditor(), actionEditor = ActionEditor()
    let world = GroupResponder()
    var editTextEditor: TextEditor? {
        if let editTextEditor = indicationResponder as? TextEditor {
            return editTextEditor.isLocked ? nil : editTextEditor
        } else {
            return nil
        }
    }
    var editQuasimode = EditQuasimode.none
    
    let sceneEditor = SceneEditor()
    
    init() {
        if let sceneEditorDataModel = sceneEditor.dataModel {
            worldDataModel = DataModel(key: Human.worldDataModelKey,
                                       directoryWithDataModels: [sceneEditorDataModel])
        } else {
            worldDataModel = DataModel(key: Human.worldDataModelKey, directoryWithDataModels: [])
        }
        self.dataModel = DataModel(key: Human.dataModelKey,
                                   directoryWithDataModels: [preferenceDataModel, worldDataModel])
        
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
                vision.allChildrenAndSelf { ($0 as? Localizable)?.locale = locale }
            }
        }
    }
    var sight: CGFloat = GlobalVariable.shared.backingScaleFactor {
        didSet {
            if sight != oldValue {
                vision.allChildrenAndSelf { $0.contentsScale = sight }
            }
        }
    }
    var actionWidth = ActionEditor.defaultWidth
    var copyEditorHeight = Layout.basicHeight + Layout.basicPadding * 2
    var fieldOfVision = CGSize() {
        didSet {
            vision.frame.size = fieldOfVision
            updateChildren()
        }
    }
    
    func updateChildren() {
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
    
    var setEditTextEditor: (((human: Human, textEditor: TextEditor?, oldValue: TextEditor?)) -> ())?
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
                if indicationResponder is TextEditor || oldValue is TextEditor {
                    if let editTextEditor = oldValue as? TextEditor {
                        editTextEditor.unmarkText()
                    }
                    setEditTextEditor?((self,
                                        indicationResponder as? TextEditor,
                                        oldValue as? TextEditor))
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
        vision.cursorPoint = event.location
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
    
    var setCursorHandler: (((human: Human, cursor: Cursor, oldCursor: Cursor)) -> ())?
    var cursor = Cursor.arrow {
        didSet {
            setCursorHandler?((self, cursor, oldValue))
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
    private weak var keyTextEditor: TextEditor?
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
            if let editTextEditor = editTextEditor, keyAction.canTextKeyInput() {
                self.keyTextEditor = editTextEditor
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
            if keyTextEditor != nil, isKey {
                self.keyTextEditor = nil
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
    
    let panel = Panel(isUseHedding: true)
    
    func sendLookup(with event: TapEvent) {
        let p = event.location.integral
        let responder = indicationResponder(with: event)
        let referenceEditor = ReferenceEditor(reference: responder.lookUp(with: event))
        panel.contents = [referenceEditor]
        panel.openPoint = p.integral
        panel.openViewPoint = point(from: event)
        panel.indicationParent = vision
        
        let newIndicationResponder = vision.at(event.location) ?? vision
        if self.indicationResponder !== newIndicationResponder {
            self.indicationResponder = newIndicationResponder
            self.cursor = indicationResponder.cursor
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

final class Vision: LayerRespondable {
    static let name = Localization(english: "Vision", japanese: "視界")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    lazy var layer = CALayer.interface()
    var cursorPoint = CGPoint()
}
