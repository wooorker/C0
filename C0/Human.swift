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

struct Memory {
    var temporaryString = ""
    var isHiddenAction = false
}

protocol HumanDelegate: class {
    func didChangeEditTextEditor(_ human: Human, oldEditTextEditor: TextEditor?)
    func didChangeCursor(_ human: Human, cursor: Cursor, oldCursor: Cursor)
}
final class Human: Respondable, Localizable {
    static let name = Localization(english: "Human", japanese: "人間")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    weak var delegate: HumanDelegate?
    
    let vision = Vision()
    let copyObjectEditor = CopyObjectEditor(), actionEditor = ActionEditor()
    let referenceEditor = ReferenceEditor()
    var editTextEditor: TextEditor? {
        return indicationResponder as? TextEditor
    }
    var editQuasimode = EditQuasimode.none
    
    init() {
        self.indicationResponder = vision
        vision.virtual.children = [copyObjectEditor, actionEditor]
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
    var isHiddenAction = false
    var actionWidth = 180 + Layout.basicPadding*2, copyEditorHeight = Layout.basicHeight
    var fieldOfVision = CGSize() {
        didSet {
            CATransaction.disableAnimation {
                vision.frame.size = fieldOfVision
                if isHiddenAction {
                    vision.sceneEditor.frame.origin = CGPoint(
                        x: round((fieldOfVision.width - vision.sceneEditor.frame.width) / 2),
                        y: round((fieldOfVision.height - copyEditorHeight - vision.sceneEditor.frame.height) / 2)
                    )
                    copyObjectEditor.frame = CGRect(
                        x: 0,
                        y: fieldOfVision.height - copyEditorHeight,
                        width: fieldOfVision.width, height: copyEditorHeight
                    )
                } else {
                    vision.sceneEditor.frame.origin = CGPoint(
                        x: round((fieldOfVision.width - actionWidth - vision.sceneEditor.frame.width) / 2),
                        y: round((fieldOfVision.height - copyEditorHeight - vision.sceneEditor.frame.height) / 2)
                    )
                    copyObjectEditor.frame = CGRect(
                        x: 0,
                        y: fieldOfVision.height - copyEditorHeight,
                        width: fieldOfVision.width, height: copyEditorHeight
                    )
                    actionEditor.frame = CGRect(
                        x: fieldOfVision.width - actionWidth,
                        y: fieldOfVision.height - copyEditorHeight - actionEditor.frame.height,
                        width: actionWidth, height: actionEditor.frame.height
                    )
                }
            }
        }
    }
    
    var indicationResponder: Respondable {
        didSet {
            if indicationResponder !== oldValue {
                var allParents = [Respondable]()
                indicationResponder.allParents { allParents.append($0) }
                oldValue.allParents { responder in
                    if let index = allParents.index(where: { $0 === responder }) {
                        allParents.remove(at: index)
                    } else {
                        responder.isSubIndication = false
                    }
                }
                allParents.forEach { $0.isSubIndication = true }
                oldValue.isIndication = false
                indicationResponder.isIndication = true
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
        let quasimodeAction = actionEditor.actionNode.actionWith(.drag, event) ?? Action()
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
    
    func sendRightDrag(with event: DragEvent) {
        if event.sendType == .end {
            indicationResponder(with: event).showProperty(with: event)
//            let newIndicationResponder = vision.at(event.location) ?? vision
//            if self.indicationResponder !== newIndicationResponder {
//                self.indicationResponder = newIndicationResponder
//                self.cursor = indicationResponder.cursor
//            }
        }
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
        setReference(indicationResponder(with: event).lookUp(with: event), oldReference: referenceEditor.reference, point: rp)
//        let newIndicationResponder = vision.at(event.location) ?? vision
//        if self.indicationResponder !== newIndicationResponder {
//            self.indicationResponder = newIndicationResponder
//            self.cursor = indicationResponder.cursor
//        }
    }
    func setReference(_ reference: Referenceable?, oldReference: Referenceable?, point p: CGPoint) {
        vision.sceneEditor.undoManager?.registerUndo(withTarget: self) { [op = CGPoint(x: referenceEditor.layer.frame.origin.x, y: referenceEditor.layer.frame.maxY)] in
            $0.setReference(oldReference, oldReference: reference, point: op)
        }
        referenceEditor.reference = reference
        CATransaction.disableAnimation {
            if reference == nil {
                referenceEditor.removeFromParent()
            } else {
                referenceEditor.frame.origin = CGPoint(x: p.x, y: p.y - referenceEditor.frame.height)
                if !vision.children.contains(where: { $0 === referenceEditor }) {
                    vision.children.append(referenceEditor)
                }
            }
        }
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
            update(withChildren: children, oldChildren: oldValue)
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
        update(withChildren: children, oldChildren: [])
        
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
final class ObjectEditor: LayerRespondable {
    static let name = Localization(english: "Object Editor", japanese: "オブジェクトエディタ")
    var instanceDescription: Localization {
        return object.instanceDescription
    }
    var valueDescription: Localization {
        return object.valueDescription
    }
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    var undoManager: UndoManager?
    
    var object: CopyData
    
    let thumbnailEditor: DrawEditor, label: Label
    
    static let labelHeight = 12.0.cf
    let layer: CALayer
    init(x: CGFloat, y: CGFloat, height: CGFloat, copyData: CopyData, backgroundColor0: Color, backgroundColor1: Color) {
        self.layer = CALayer.interfaceLayer(backgroundColor: backgroundColor0)
        self.object = copyData
        let thumbnailHeight = height - ObjectEditor.labelHeight - Layout.basicPadding * 2
        let thumbnailSize = CGSize(width: thumbnailHeight, height: thumbnailHeight)
        label = Label(text: type(of: copyData).name, font: Font.small, color: Color.locked, backgroundColor: backgroundColor0)
        label.textLine.isCenterWithImageBounds = true
        let width = max(thumbnailSize.width, ceil(label.textLine.imageBounds.width)) + Layout.basicPadding * 2
        layer.frame = CGRect(x: x, y: y, width: width, height: height)
        label.frame = CGRect(x: 0, y: Layout.basicPadding, width: width, height: ObjectEditor.labelHeight)
        thumbnailEditor = DrawEditor(
            drawable: copyData as? Drawable,
            frame: CGRect(
                x: round((width - thumbnailSize.width)/2),
                y: ObjectEditor.labelHeight + Layout.basicPadding,
                width: thumbnailSize.width,
                height: thumbnailSize.height
            ),
            backgroundColor: backgroundColor1
        )
        self.children = [thumbnailEditor, label]
        update(withChildren: children, oldChildren: [])
    }
    func updateFrameWith(x: CGFloat, y: CGFloat, height: CGFloat) {
        let thumbnailHeight = height - ObjectEditor.labelHeight - Layout.basicPadding * 2
        let thumbnailSize = CGSize(width: thumbnailHeight, height: thumbnailHeight)
        let width = max(thumbnailSize.width, ceil(label.textLine.imageBounds.width)) + Layout.basicPadding * 2
        layer.frame = CGRect(x: x, y: y, width: width, height: height)
        if width != layer.frame.width || height != layer.frame.height {
            label.frame.origin = CGPoint(x: 0, y: Layout.basicPadding)
            thumbnailEditor.frame = CGRect(
                x: round((width - thumbnailSize.width)/2),
                y: ObjectEditor.labelHeight + Layout.basicPadding,
                width: thumbnailSize.width,
                height: thumbnailSize.height
            )
        }
    }
}
final class CopyObjectEditor: LayerRespondable {
    static let name = Localization(english: "Copy Object Editor", japanese: "コピーオブジェクトエディタ")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    var undoManager: UndoManager?
    
    var changeCount = 0
    
    var defaultBorderColor: CGColor? = Color.border.cgColor
    
    var copyDataEditors = [ObjectEditor]() {
        didSet {
            if copyDataEditors.isEmpty {
                let noCopyLabel = CopyObjectEditor.noCopyLabel(
                    frame: CGRect(
                        x: Layout.basicPadding, y: Layout.basicPadding,
                        width: frame.width - Layout.basicPadding * 2,
                        height: frame.height - Layout.basicPadding * 3 - copyLabel.frame.height
                    )
                )
                self.noCopyLabel = noCopyLabel
                self.children = [copyLabel, noCopyLabel]
            } else {
                self.noCopyLabel = nil
                self.children = [copyLabel] as [Respondable] + copyDataEditors as [Respondable]
            }
        }
    }
    let copyLabel = Label(
        text: Localization(english: "Copied Object", japanese: "コピーオブジェクト"),
        font: .small, color: .locked, paddingWidth: 0
    )
    var noCopyLabel: Label?
    static func noCopyLabel(frame: CGRect) -> Label {
        let label = Label(
//            frame: frame,
            text: Localization(english: "No Copy", japanese: "コピーなし"),
            font: .small, color: .locked, backgroundColor: .background,
            paddingWidth: 0, isSizeToFit: false
        )
        label.textLine.isCenterWithImageBounds = true
        label.frame = frame
        return label
    }
    let layer: CALayer
    init(backgroundColor: Color = .background) {
        self.layer = CALayer.interfaceLayer(backgroundColor: backgroundColor, borderColor: .border)
        layer.masksToBounds = true
        let noCopyLabel = CopyObjectEditor.noCopyLabel(
            frame: CGRect(
                x: Layout.basicPadding, y: Layout.basicPadding,
                width: bounds.width - Layout.basicPadding * 2,
                height: frame.height - Layout.basicPadding * 3 - copyLabel.frame.height
            )
        )
        self.noCopyLabel = noCopyLabel
        self.children = [copyLabel, noCopyLabel]
        update(withChildren: children, oldChildren: [])
    }
    var copyObject = CopyObject() {
        didSet {
            changeCount += 1
            CATransaction.disableAnimation {
                var x = Layout.basicPadding
                copyDataEditors = copyObject.objects.map { object in
                    let copyDataEditor = ObjectEditor(
                        x: x, y: Layout.basicPadding,
                        height: frame.height - Layout.basicPadding * 3 - copyLabel.frame.height,
                        copyData: object, backgroundColor0: .background, backgroundColor1: .background
                    )
                    x += copyDataEditor.frame.width + Layout.basicPadding
                    return copyDataEditor
                }
            }
        }
    }
    var frame: CGRect {
        get {
            return layer.frame
        }
        set {
            if newValue.size != layer.frame.size {
                copyLabel.frame.origin = CGPoint(
                    x: round((newValue.width - copyLabel.frame.width) / 2),
                    y: newValue.height - copyLabel.frame.height - Layout.basicPadding
                )
                CATransaction.disableAnimation {
                    if let noCopyLabel = noCopyLabel {
                        noCopyLabel.frame = CGRect(
                            x: Layout.basicPadding, y: Layout.basicPadding,
                            width: newValue.width - Layout.basicPadding * 2,
                            height: newValue.height - Layout.basicPadding * 3 - copyLabel.frame.height
                        )
                    } else {
                        var x = Layout.basicPadding
                        copyDataEditors.forEach {
                            $0.updateFrameWith(
                                x: x, y: Layout.basicPadding,
                                height: newValue.height - Layout.basicPadding * 3 - copyLabel.frame.height
                            )
                            x += $0.frame.width + Layout.basicPadding
                        }
                    }
                }
            }
            layer.frame = newValue
        }
    }
    
    func delete(with event: KeyInputEvent) {
        copyObject = CopyObject()
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
    var undoManager: UndoManager?
    
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
    
    init(drawable: Drawable? = nil, frame: CGRect = CGRect(), backgroundColor: Color) {
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

protocol Referenceable: CustomStringConvertible {
    static var name: Localization { get }
    static var feature: Localization { get }
    var instanceDescription: Localization { get }
    var valueDescription: Localization { get }
}
extension Referenceable {
    static var feature: Localization {
        return Localization()
    }
    var instanceDescription: Localization {
        return Localization()
    }
    var valueDescription: Localization {
        return Localization()
    }
    var description: String {
        return "name: \(type(of: self).name)\nfeature: \(type(of: self).feature)\nInstance Description: \(instanceDescription)\nValue Description: \(valueDescription)\n"
    }
}
final class ReferenceEditor: LayerRespondable {
    static let name = Localization(english: "Reference Editor", japanese: "情報エディタ")
    static let feature = Localization(english: "Close: Move cursor to outside", japanese: "閉じる: カーソルを外に出す")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    var undoManager: UndoManager?
    
    let layer: CALayer
    let minWidth = 200.0.cf
    init(backgroundColor: Color = .background) {
        layer = CALayer.interfaceLayer(backgroundColor: backgroundColor, borderColor: .border)
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
    static func childrenAndSize(with reference: Referenceable, width: CGFloat) -> (children: [Respondable], size: CGSize) {
        let type =  type(of: reference).name, feature = type(of: reference).feature
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
            text: description, font: .small, color: .locked
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
