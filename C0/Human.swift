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

import AppKit.NSCursor

protocol HumanDelegate: class {
    func didChangedEditTextEditor(_ human: Human, oldEditTextEditor: TextEditor?)
}
final class Human: Respondable, Localizable {
    static let type = ObjectType(identifier: "Human", name: Localization(english: "Human", japanese: "人間"))
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
    var sight = GlobalVariable.shared.backingScaleFactor {
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
                let padding = 5.0.cf
                let inSize = CGSize(width: vision.sceneEditor.frame.width + actionEditor.frame.width + padding*3, height: max(vision.sceneEditor.frame.height, actionEditor.frame.height + copyEditor.frame.height + referenceEditor.frame.height + padding*4))
                let y = round((visionSize.height - inSize.height)/2)
                let origin = CGPoint(x: max(0, round((visionSize.width - inSize.width)/2)), y: min(visionSize.height, y + inSize.height) - inSize.height)
                vision.sceneEditor.frame.origin = CGPoint(x: origin.x + padding, y: origin.y + inSize.height - vision.sceneEditor.frame.height - padding)
                actionEditor.frame.origin = CGPoint(x: origin.x + vision.sceneEditor.frame.width + padding*2, y: origin.y + inSize.height - actionEditor.frame.height - padding)
                copyEditor.frame.origin = CGPoint(x: origin.x + vision.sceneEditor.frame.width + padding*2, y: origin.y + inSize.height - actionEditor.frame.height - copyEditor.frame.height - padding*2)
                referenceEditor.frame.origin = CGPoint(x: origin.x + vision.sceneEditor.frame.width + padding*2, y: origin.y + inSize.height - actionEditor.frame.height - copyEditor.frame.height - referenceEditor.frame.height - padding*3)
            }
        }
    }
    
    weak var deleagte: HumanDelegate?
    
    let vision = Vision()
    let actionEditor = ActionEditor()
    let copyEditor = CopyEditor()
    let referenceEditor = ReferenceEditor()
    var editTextEditor: TextEditor? {
        return indicationResponder as? TextEditor
    }
    var editQuasimode = EditQuasimode.none
    
    init() {
        indicationResponder = vision
        vision.virtual.children = [actionEditor, copyEditor, referenceEditor]
    }
    
    var indicationResponder: Respondable {
        didSet {
            if indicationResponder !== oldValue {
                oldValue.allParents { $0.indication = false }
                indicationResponder.allParents { $0.indication = true }
                if let editTextEditor = oldValue as? TextEditor {
                    deleagte?.didChangedEditTextEditor(self, oldEditTextEditor: editTextEditor)
                }
            }
        }
    }
    func setIndicationResponder(with p: CGPoint) {
        let hitResponder = vision.at(p) ?? vision
        if indicationResponder !== hitResponder {
            indicationResponder = hitResponder
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
            indicationResponder = hitResponder
            if indicationResponder.editQuasimode != editQuasimode {
                indicationResponder.setEditQuasimode(editQuasimode, with: event)
            }
            if oldIndicationResponder.editQuasimode != .none {
                indicationResponder.setEditQuasimode(.none, with: event)
            }
        }
        setCursor(with: event.location)
        indicationResponder.moveCursor(with: event)
    }
    func setCursor(with p: CGPoint) {
        let cursor = indicationResponder.cursor
        if cursor != NSCursor.current() {
            cursor.set()
        }
    }
    
    private var oldQuasimodeAction = Action()
    private weak var oldQuasimodeResponder: Respondable?
    func sendEditQuasimode(with event: Event) {
        let quasimodeAction = actionEditor.actionNode.actionWith(.drag, event) ?? Action()
        if !isDown {
            if editQuasimode != quasimodeAction.editQuasimode {
                editQuasimode = quasimodeAction.editQuasimode
                indicationResponder.setEditQuasimode(quasimodeAction.editQuasimode, with: event)
                setCursor(with: event.location)
            }
        }
        oldQuasimodeAction = quasimodeAction
        oldQuasimodeResponder = indicationResponder
    }
    
    private var isKey = false, keyAction = Action(), keyEvent: Event?
    private weak var keyTextEditor: TextEditor?
    func sendKeyInputIsEditText(with event: KeyInputEvent) -> Bool {
        switch event.sendType {
        case .begin:
            guard !isDown else {
                keyEvent = event
                return false
            }
            isKey = true
            keyAction = actionEditor.actionNode.actionWith(.keyInput, event) ?? Action()
            if let editTextEditor = editTextEditor, keyAction.canTextKeyInput() {
                keyTextEditor = editTextEditor
                return true
            } else if keyAction != Action() {
                keyAction.keyInput?(self, indicationResponder, event)
                if let undoManager = indicationResponder.undoManager, undoManager.groupingLevel >= 1 {
                     indicationResponder.undoManager?.setActionName(type(of: indicationResponder).type.name.currentString + "." + keyAction.name.currentString)
                }
            }
            let newIndicationResponder = vision.at(event.location) ?? vision
            if self.indicationResponder !== newIndicationResponder {
                self.indicationResponder = newIndicationResponder
                setCursor(with: event.location)
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
            isDown = true
            isDrag = false
            dragResponder = indicationResponder
            if let dragResponder = dragResponder {
                dragAction = actionEditor.actionNode.actionWith(.drag, event) ?? defaultDragAction
                dragAction.drag?(self, dragResponder, event)
            }
        case .sending:
            isDrag = true
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
                isDown = false
                
                if let keyEvent = keyEvent {
                    _ = sendKeyInputIsEditText(with: KeyInputEvent(sendType: .begin, location: keyEvent.location, time: keyEvent.time,
                                                     quasimode: keyEvent.quasimode, key: keyEvent.key))
                    self.keyEvent = nil
                } else {
                    if let undoManager = indicationResponder.undoManager, undoManager.groupingLevel >= 1 {
                        indicationResponder.undoManager?.setActionName(type(of: indicationResponder).type.name.currentString + "." + (isDrag ? dragAction.name.currentString : (actionEditor.actionNode.actionWith(.click, event) ?? defaultClickAction).name.currentString))
                    }
                    let newIndicationResponder = vision.at(event.location) ?? vision
                    if self.indicationResponder !== newIndicationResponder {
                        self.indicationResponder = newIndicationResponder
                        setCursor(with: event.location)
                    }
                }
                isDrag = false
                
                if dragAction != oldQuasimodeAction {
                    if let dragResponder = dragResponder {
                        if indicationResponder !== dragResponder {
                            dragResponder.setEditQuasimode(.none, with: event)
                        }
                    }
                    editQuasimode = oldQuasimodeAction.editQuasimode
                    indicationResponder.setEditQuasimode(oldQuasimodeAction.editQuasimode, with: event)
                }
            }
        }
    }
    
    private weak var momentumScrollResponder: Respondable?
    func sendScroll(with event: ScrollEvent, momentum: Bool, isTop: Bool) {
        let indicationResponder = vision.at(event.location) ?? vision
        if !momentum {
            momentumScrollResponder = indicationResponder
        }
        if let momentumScrollResponder = momentumScrollResponder {
            if isTop {
                momentumScrollResponder.topScroll(with: event)
            } else {
                momentumScrollResponder.scroll(with: event)
            }
        }
        setIndicationResponder(with: event.location)
        setCursor(with: event.location)
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
        vision.sceneEditor.undoManager?.registerUndo(withTarget: self) { $0.setReference(oldReference, oldReference: reference) }
        referenceEditor.reference = reference
    }
    
    func sendReset(with event: DoubleTapEvent) {
        indicationResponder(with: event).reset(with: event)
    }
    
    func copy(with event: KeyInputEvent) -> CopyObject {
        return copyEditor.copyObject
    }
    func paste(_ copyObject: CopyObject, with event: KeyInputEvent) {
        setCopyObject(copyObject, oldCopyObject: copyEditor.copyObject)
    }
    func setCopyObject(_ copyObject: CopyObject, oldCopyObject: CopyObject) {
        vision.sceneEditor.undoManager?.registerUndo(withTarget: self) { $0.setCopyObject(oldCopyObject, oldCopyObject: copyObject) }
        copyEditor.copyObject = copyObject
    }
}

final class Vision: LayerRespondable {
    static let type = ObjectType(identifier: "Vision", name: Localization(english: "Vision", japanese: "視界"))
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager? = UndoManager()
    
    let real = GroupResponder()
    let virtual = GroupResponder()
    
    var layer = CALayer() {
        didSet {
            layer.backgroundColor = Defaults.backgroundColor.cgColor
            layer.sublayers = children.flatMap { ($0 as? LayerRespondable)?.layer }
        }
    }
    init() {
        real.children = [sceneEditor]
        children = [real, virtual]
        update(withChildren: children)
    }
    
    var sceneEditor = SceneEditor()
    var entity: SceneEntity? {
        didSet {
            if let entity = entity {
                sceneEditor.sceneEntity = entity
            }
        }
    }
}
