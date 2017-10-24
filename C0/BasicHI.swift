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
//Sliderの一部をNumberSliderとして分離
//ReferenceEditorをポップアップ形式にする
//カーソルが離れると閉じるプルダウンボタン
//ラジオボタンの導入
//ボタンの可視性の改善

import Foundation
import QuartzCore

final class GlobalVariable {
    static let shared = GlobalVariable()
    var backingScaleFactor = 1.0.cf
    var locale = Locale.current
}

final class Drager {
    private var downPosition = CGPoint(), oldFrame = CGRect()
    func drag(with event: DragEvent, _ responder: LayerRespondable, in parent: LayerRespondable?) {
        if let parent = parent {
            let p = parent.point(from: event)
            switch event.sendType {
            case .begin:
                downPosition = p
                oldFrame = responder.frame
            case .sending:
                let dp =  p - downPosition
                CATransaction.disableAnimation {
                    responder.frame.origin = CGPoint(x: oldFrame.origin.x + dp.x, y: oldFrame.origin.y + dp.y)
                }
            case .end:
                let dp =  p - downPosition
                responder.frame.origin = CGPoint(x: round(oldFrame.origin.x + dp.x), y: round(oldFrame.origin.y + dp.y))
            }
        } else {
            parent?.drag(with: event)
        }
    }
}
final class Scroller {
    func scroll(with event: ScrollEvent, responder: LayerRespondable) {
        CATransaction.disableAnimation {
            responder.frame.origin += event.scrollDeltaPoint
        }
    }
}

final class GroupResponder: LayerRespondable {
    static let name = Localization(english: "Group", japanese: "グループ")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager?
    var layer: CALayer
    init(layer: CALayer = CALayer(), children: [Respondable] = [], frame: CGRect = CGRect()) {
        layer.frame = frame
        self.children = children
        self.layer = layer
        if !children.isEmpty {
            update(withChildren: children)
        }
    }
    let minPasteImageWidth = 400.0.cf
    func paste(_ copyObject: CopyObject, with event: KeyInputEvent) {
        let p = self.point(from: event)
        for object in copyObject.objects {
            if let url = object as? URL {
                children.append(makeImageEditor(url: url, position: p))
            }
        }
    }
    func makeImageEditor(url :URL, position p: CGPoint) -> ImageEditor {
        let imageEditor = ImageEditor(url: url)
        if let size = imageEditor.image?.size {
            let maxWidth = max(size.width, size.height)
            let ratio = minPasteImageWidth < maxWidth ? minPasteImageWidth/maxWidth : 1
            let width = ceil(size.width*ratio), height = ceil(size.height*ratio)
            imageEditor.frame = CGRect(x: round(p.x - width/2), y: round(p.y - height/2), width: width, height: height)
        }
        return imageEditor
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
final class CopyEditor: LayerRespondable {
    static let name = Localization(english: "Copy Editor", japanese: "コピーエディタ")
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
                self.children = [CopyEditor.noCopylabel(bounds: bounds)]
            } else {
                self.children = thumbnailGroups
            }
        }
    }
    static func noCopylabel(bounds: CGRect) -> Label {
        let label = Label(text: Localization(english: "No Copy", japanese: "コピーなし"), font: Font.small, color: Color.smallFont, paddingWidth: 0)
        label.textLine.isCenterWithImageBounds = true
        label.frame = bounds
        return label
    }
    init() {
        layer.masksToBounds = true
        layer.frame = CGRect(x: 0, y: 0, width: 190, height: 56)
        self.children = [CopyEditor.noCopylabel(bounds: bounds)]
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

protocol ButtonDelegate: class {
    func clickButton(_ button: Button)
}
final class Button: LayerRespondable, Equatable, Localizable {
    static let name = Localization(english: "Button", japanese: "ボタン")
    static let description = Localization(english: "Send Action", japanese: "アクションを送信")
    var description: Localization {
        return name
    }
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager?
    var locale = Locale.current {
        didSet {
            textLine.string = name.string(with: locale)
        }
    }
    
    weak var sendDelegate: ButtonDelegate?
    
    var name = Localization()
    var textLine: TextLine {
        didSet {
            layer.setNeedsDisplay()
        }
    }
    var layer: CALayer {
        return drawLayer
    }
    let drawLayer = DrawLayer(fillColor: Color.subBackground), highlight = Highlight()
    
    init(frame: CGRect = CGRect(), title: String = "", name: Localization = Localization()) {
        self.name = name
        self.textLine = TextLine(string: name.currentString, isHorizontalCenter: true)
        drawLayer.drawBlock = { [unowned self] ctx in
            self.textLine.draw(in: self.bounds, in: ctx)
        }
        layer.frame = frame
        highlight.layer.frame = bounds.inset(by: 0.5)
        layer.addSublayer(highlight.layer)
    }
    
    let cursor = Cursor.pointingHand
    
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            layer.frame = frame
            highlight.layer.frame = bounds.inset(by: 0.5)
        }
    }
    
    func drag(with event: DragEvent) {
        switch event.sendType {
        case .begin:
            highlight.setIsHighlighted(true, animate: false)
        case .sending:
            highlight.setIsHighlighted(contains(point(from: event)), animate: false)
        case .end:
            if contains(point(from: event)) {
                sendDelegate?.clickButton(self)
            }
            if highlight.isHighlighted {
                highlight.setIsHighlighted(false, animate: true)
            }
        }
    }
    
    func copy(with event: KeyInputEvent) -> CopyObject {
        return CopyObject(objects: [textLine.string])
    }
}

protocol PulldownButtonDelegate: class {
    func changeValue(_ pulldownButton: PulldownButton, index: Int, oldIndex: Int, type: Action.SendType)
}
final class PulldownButton: LayerRespondable, Equatable, Localizable {
    static let name = Localization(english: "Pulldown Button", japanese: "プルダウンボタン")
    static let description = Localization(english: "Select Index: Up and down drag", japanese: "インデックスを選択: 上下ドラッグ")
    var description: Localization
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager?
    var locale = Locale.current {
        didSet {
            menu.locale = locale
            textLine.string = isSelectable ? menu.names[selectionIndex].string(with: locale) : name.string(with: locale)
        }
    }
    
    private let arrowLayer: CAShapeLayer = {
        let arrowLayer = CAShapeLayer()
        arrowLayer.strokeColor = Color.edit.cgColor
        arrowLayer.fillColor = nil
        arrowLayer.lineWidth = 2
        return arrowLayer
    }()
    var textLine: TextLine {
        didSet {
            layer.setNeedsDisplay()
        }
    }
    var layer: CALayer {
        return drawLayer
    }
    let drawLayer = DrawLayer(fillColor: Color.subBackground), highlight = Highlight()
    var isSelectable: Bool
    
    var name: Localization
    
    init(
        frame: CGRect = CGRect(), isEnabledCation: Bool = false, isSelectable: Bool = true,
        name: Localization = Localization(), names: [Localization], description: Localization = Localization()
    ) {
        self.description = description
        self.menu = Menu(names: names, width: isSelectable ? frame.width : nil, isSelectable: isSelectable)
        self.name = name
        self.isSelectable = isSelectable
        self.isEnabledCation = isEnabledCation
        self.textLine = TextLine(
            string: isSelectable ? (names.first?.currentString ?? "") : name.currentString,
            paddingWidth: arowWidth, isVerticalCenter: true
        )
        drawLayer.drawBlock = { [unowned self] ctx in
            self.textLine.draw(in: self.bounds, in: ctx)
        }
        layer.frame = frame
        highlight.layer.frame = bounds.inset(by: 0.5)
        updateArrowPosition()
        layer.sublayers = [arrowLayer, highlight.layer]
    }
    
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            layer.frame = newValue
            if isSelectable && menu.width != newValue.width {
                menu.width = newValue.width
            }
            highlight.layer.frame = bounds.inset(by: 0.5)
            updateArrowPosition()
        }
    }
    var contentsScale: CGFloat {
        get {
            return layer.contentsScale
        } set {
            layer.contentsScale = newValue
            menu.contentsScale = newValue
        }
    }
    weak var delegate: PulldownButtonDelegate?
    
    var defaultValue = 0
    func delete(with event: KeyInputEvent) {
        let oldIndex = selectionIndex, newIndex = defaultValue
        if oldIndex != newIndex {
            delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .begin)
            selectionIndex = defaultValue
            delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .end)
        }
    }
    func copy(with event: KeyInputEvent) -> CopyObject {
        return CopyObject(objects: [String(selectionIndex)])
    }
    func paste(_ copyObject: CopyObject, with event: KeyInputEvent) {
        for object in copyObject.objects {
            if let string = object as? String {
                if let i = Int(string) {
                    let oldIndex = selectionIndex
                    delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .begin)
                    selectionIndex = i
                    delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .end)
                    return
                }
            }
        }
    }
    
    var menu: Menu
    private var timer = LockTimer(), isDrag = false, oldIndex = 0
    func drag(with event: DragEvent) {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            if timer.inUse {
                timer.stop()
                closeMenu(animate: false)
            }
            isDrag = false
            highlight.setIsHighlighted(true, animate: false)
            if let root = rootRespondable as? LayerRespondable {
                CATransaction.disableAnimation {
                    menu.frame.origin = root.convert(CGPoint(x: 0, y: -menu.frame.height), from: self)
                    root.children.append(menu)
                }
            }
        case .sending:
            if !isDrag {
                oldIndex = selectionIndex
                delegate?.changeValue(self, index: selectionIndex, oldIndex: selectionIndex, type: .begin)
                isDrag = true
            }
            let i = indexWith(-p.y)
            selectionIndex = i ?? oldIndex
            menu.editIndex = i
            delegate?.changeValue(self, index: selectionIndex, oldIndex: selectionIndex, type: .sending)
        case .end:
            if !isDrag {
                timer.begin(0.2, repeats: false) { [unowned self] in
                    self.closeMenu(animate: true)
                }
            } else {
                isDrag = false
                let i = indexWith(-p.y)
                selectionIndex = i ?? oldIndex
                menu.editIndex = nil
                if i != nil || isSelectable {
                    delegate?.changeValue(self, index: selectionIndex, oldIndex: oldIndex, type: .end)
                }
                closeMenu(animate: false)
            }
        }
    }
    private func closeMenu(animate: Bool) {
        menu.removeFromParent()
        highlight.setIsHighlighted(false, animate: animate)
    }
    func indexWith(_ y: CGFloat) -> Int? {
        let i = y/menu.menuHeight
        return i >= 0 ? min(Int(i), menu.names.count - 1) : nil
    }
    var isEnabledCation = false
    func updateArrowPosition() {
        let d = arowRadius*2/sqrt(3) + 0.5
        let path = CGMutablePath()
        path.move(to: CGPoint(x: arowWidth/2 - d, y: bounds.midY + arowRadius*0.8))
        path.addLine(to: CGPoint(x: arowWidth/2, y: bounds.midY - arowRadius*0.8))
        path.addLine(to: CGPoint(x: arowWidth/2 + d, y: bounds.midY + arowRadius*0.8))
        arrowLayer.path = path
    }
    var arowWidth = 16.0.cf {
        didSet {
            updateArrowPosition()
        }
    }
    private var drawArow = true, arowRadius = 3.0.cf, oldFontColor: Color?
    var selectionIndex = 0 {
        didSet {
            if !isDrag {
                menu.selectionIndex = selectionIndex
            }
            if isSelectable {
                textLine.string = menu.names[selectionIndex].currentString
                if isEnabledCation && selectionIndex != oldValue {
                    if selectionIndex == 0 {
                        if let oldFontColor = oldFontColor {
                            textLine.color = oldFontColor
                        }
                    } else {
                        oldFontColor = textLine.color
                        textLine.color = Color.red
                    }
                }
            }
        }
    }
}

final class Menu: LayerRespondable, Localizable {
    static let name = Localization(english: "Menu", japanese: "メニュー")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager?
    var locale = Locale.current {
        didSet {
            for label in nameLabels {
                label.locale = locale
            }
        }
    }
    
    var width = 0.0.cf {
        didSet {
            updateNameLabels()
        }
    }
    var menuHeight = 17.0.cf, knobWidth = 18.0.cf
    var isSelectable: Bool {
        didSet {
            selectionKnobLayer.isHidden = !isSelectable
        }
    }
    let layer = CALayer.interfaceLayer(isPanel: true)
    init(names: [Localization] = [], width: CGFloat?, isSelectable: Bool = true) {
        self.isSelectable = isSelectable
        self.names = names
        self.width = width ?? self.width(with: names)
        selectionKnobLayer.isHidden = !isSelectable
        updateNameLabels()
    }
    var selectionKnobLayer = CALayer.slideLayer(width: 8, height: 8, lineWidth: 1)
    
    var contentsScale: CGFloat {
        get {
            return layer.contentsScale
        } set {
            layer.contentsScale = newValue
            for menuLabel in nameLabels {
                menuLabel.contentsScale = newValue
            }
        }
    }
    
    var names = [Localization]() {
        didSet {
            updateNameLabels()
        }
    }
    var nameLabels = [Label]()
    func width(with names: [Localization]) -> CGFloat {
        return names.reduce(0.0.cf) { max($0, TextLine(string: $1.currentString, paddingWidth: knobWidth).width) } + knobWidth*2
    }
    func updateNameLabels() {
        let h = menuHeight*names.count.cf
        var y = h
        let nameLabels: [Label] = names.map {
            y -= menuHeight
            return Label(
                frame: CGRect(x: 0, y: y, width: width, height: menuHeight),
                text: $0,
                textLine: TextLine(string: $0.currentString, paddingWidth: knobWidth)
            )
        }
        frame.size = CGSize(width: width, height: h)
        self.nameLabels = nameLabels
        self.children = nameLabels
        selectionKnobLayer.position = CGPoint(x: knobWidth/2, y: nameLabels[selectionIndex].frame.midY)
        layer.addSublayer(selectionKnobLayer)
    }
    var selectionIndex = 0 {
        didSet {
            if selectionIndex != oldValue {
                CATransaction.disableAnimation {
                    selectionKnobLayer.position = CGPoint(x: knobWidth/2, y: nameLabels[selectionIndex].frame.midY)
                }
            }
        }
    }
    var editIndex: Int? {
        didSet {
            if editIndex != oldValue {
                CATransaction.disableAnimation {
                    if let i = editIndex {
                        nameLabels[i].drawLayer.fillColor = Color.subEdit
                    }
                    if let oi = oldValue {
                        nameLabels[oi].drawLayer.fillColor = .subBackground
                    }
                }
            }
        }
    }
}

protocol SliderDelegate: class {
    func changeValue(_ slider: Slider, value: CGFloat, oldValue: CGFloat, type: Action.SendType)
}
final class Slider: LayerRespondable, Equatable {
    static let name = Localization(english: "Slider", japanese: "スライダー")
    var description: Localization
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager?
    
    weak var delegate: SliderDelegate?
    
    var value = 0.0.cf {
        didSet {
            if isNumberEdit {
                updateText()
            } else {
                updateKnobPosition()
            }
        }
    }
    var textLine: TextLine? {
        didSet {
            drawLayer?.setNeedsDisplay()
        }
    }
    let layer = CALayer.interfaceLayer()
    var drawLayer: DrawLayer?
    let knobLayer = CALayer.knobLayer()
    
    init(
        frame: CGRect = CGRect(), unit: String = "", isNumberEdit: Bool = false, value: CGFloat = 0, defaultValue: CGFloat = 0,
        min: CGFloat = 0, max: CGFloat = 1, invert: Bool = false, isVertical: Bool = false, exp: CGFloat = 1, valueInterval: CGFloat = 0,
        numberOfDigits: Int = 0, numberFont: Font? = .small, description: Localization = Localization()
    ) {
        self.description = description
        self.isNumberEdit = isNumberEdit
        self.unit = unit
        self.value = value.clip(min: min, max: max)
        self.defaultValue = defaultValue
        self.minValue = min
        self.maxValue = max
        self.invert = invert
        self.isVertical = isVertical
        self.exp = exp
        self.valueInterval = valueInterval
        self.numberOfDigits = numberOfDigits
        
        layer.frame = frame
        if isNumberEdit {
            let drawLayer = DrawLayer(fillColor: Color.subBackground)
            drawLayer.drawBlock = { [unowned self] ctx in
                ctx.setFillColor(Color.subBackground4.cgColor)
                ctx.fill(self.bounds.insetBy(dx: 0, dy: 4))
                self.textLine?.draw(in: self.bounds, in: ctx)
            }
            layer.borderWidth = 0
            drawLayer.borderWidth = 0
            var textLine = TextLine(paddingWidth: 4)
            if let numberFont = numberFont {
                textLine.font = numberFont
            }
            self.drawLayer = drawLayer
            self.textLine = textLine
            drawLayer.frame = layer.bounds
            layer.addSublayer(drawLayer)
        } else {
            updateKnobPosition()
            layer.addSublayer(knobLayer)
        }
    }
    var cursor: Cursor {
        return isNumberEdit ? .leftRight : .arrow
    }
    var unit = "", numberOfDigits = 0
    var knobY = 0.0.cf, viewPadding = 10.0.cf, isNumberEdit = false
    var defaultValue = 0.0.cf, minValue: CGFloat, maxValue: CGFloat, valueInterval = 0.0.cf
    var exp = 1.0.cf, invert = false, isVertical = false, slideMinMax = false
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            layer.frame = newValue
            if isNumberEdit {
                updateText()
            } else {
                updateKnobPosition()
            }
        }
    }
    func updateKnobPosition() {
        if minValue < maxValue {
            CATransaction.disableAnimation {
                let t = (value - minValue)/(maxValue - minValue)
                if isVertical {
                    knobLayer.position = CGPoint(
                        x: bounds.midX,
                        y: viewPadding + (bounds.height - viewPadding*2)*pow(invert ? 1 - t : t, 1/exp)
                    )
                } else {
                    knobLayer.position = CGPoint(
                        x: viewPadding + (bounds.width - viewPadding*2)*pow(invert ? 1 - t : t, 1/exp),
                        y: knobY == 0 ? bounds.midY : knobY
                    )
                }
            }
        }
    }
    func updateText() {
        CATransaction.disableAnimation {
            if value - floor(value) > 0 {
                textLine?.string = String(format: numberOfDigits == 0 ? "%g" : "%.\(numberOfDigits)f", value) + "\(unit)"
            } else {
                textLine?.string = "\(Int(value))" + "\(unit)"
            }
        }
    }
    var contentsScale: CGFloat {
        get {
            return layer.contentsScale
        } set {
            layer.contentsScale = newValue
            drawLayer?.contentsScale = newValue
        }
    }
    
    func delete(with event: KeyInputEvent) {
        oldValue = value
        let newValue = defaultValue.clip(min: minValue, max: maxValue)
        if oldValue != newValue {
            delegate?.changeValue(self, value: value, oldValue: oldValue, type: .begin)
            value = defaultValue.clip(min: minValue, max: maxValue)
            delegate?.changeValue(self, value: value, oldValue: oldValue, type: .end)
        }
    }
    func copy(with event: KeyInputEvent) -> CopyObject {
        return CopyObject(objects: [String(value.d)])
    }
    func paste(_ copyObject: CopyObject, with event: KeyInputEvent) {
        for object in copyObject.objects {
            if let string = object as? String {
                if let v = Double(string)?.cf {
                    oldValue = value
                    delegate?.changeValue(self, value: value, oldValue: oldValue, type: .begin)
                    value = v.clip(min: minValue, max: maxValue)
                    delegate?.changeValue(self, value: value, oldValue: oldValue, type: .end)
                    return
                }
            }
        }
    }
    
    private var oldValue = 0.0.cf, oldMinValue = 0.0.cf, oldMaxValue = 0.0.cf, oldPoint = CGPoint()
    func drag(with event: DragEvent) {
        if isNumberEdit {
            numberEdit(with: event, valueInterval: valueInterval)
        } else {
            let p = point(from: event)
            switch event.sendType {
            case .begin:
                oldValue = value
                oldMinValue = minValue
                oldMaxValue = maxValue
                oldPoint = p
                delegate?.changeValue(self, value: value, oldValue: oldValue, type: .begin)
                updateValue(p)
                knobLayer.backgroundColor = Color.editing.cgColor
                delegate?.changeValue(self, value: value, oldValue: oldValue, type: .sending)
            case .sending:
                updateValue(p)
                delegate?.changeValue(self, value: value, oldValue: oldValue, type: .sending)
            case .end:
                updateValue(p)
                knobLayer.backgroundColor = Color.content.cgColor
                delegate?.changeValue(self, value: value, oldValue: oldValue, type: .end)
            }
        }
    }
    private func intervalValue(value v: CGFloat) -> CGFloat {
        if valueInterval == 0 {
            return v
        } else {
            let t = floor(v/valueInterval)*valueInterval
            if v - t > valueInterval/2 {
                return t + valueInterval
            } else {
                return t
            }
        }
    }
    func updateValue(_ point: CGPoint) {
        if slideMinMax && value == maxValue {
            let delta = floor(point.x - oldPoint.x)
            minValue = oldMinValue + delta
            maxValue = oldMaxValue + delta
        } else {
            let v: CGFloat
            if isVertical {
                let h = bounds.height - viewPadding*2
                if h > 0 {
                    let y = (point.y - viewPadding).clip(min: 0, max: h)
                    v = (maxValue - minValue)*pow((invert ? (h - y) : y)/h, exp) + minValue
                } else {
                    v = minValue
                }
            } else {
                let w = bounds.width - viewPadding*2
                if w > 0 {
                    let x = (point.x - viewPadding).clip(min: 0, max: w)
                    v = (maxValue - minValue)*pow((invert ? (w - x) : x)/w, exp) + minValue
                } else {
                    v = minValue
                }
            }
            value = intervalValue(value: v).clip(min: minValue, max: maxValue)
        }
    }
    
    var valueX = 2.0.cf, valueLog = -2
    func slowDrag(with event: DragEvent) {
        numberEdit(with: event, valueInterval: valueInterval)
    }
    func numberEdit(with event: DragEvent, valueInterval: CGFloat) {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            oldValue = value
            oldMinValue = minValue
            oldMaxValue = maxValue
            oldPoint = p
            delegate?.changeValue(self, value: value, oldValue: oldValue, type: .begin)
        case .sending:
            let d = isVertical ? p.y - oldPoint.y : p.x - oldPoint.x
            let v =  oldValue.interval(scale: valueInterval) + value(with: d)
            value = v.clip(min: minValue, max: maxValue)
            delegate?.changeValue(self, value: value, oldValue: oldValue, type: .sending)
        case .end:
            let d = isVertical ? p.y - oldPoint.y : p.x - oldPoint.x
            let v = oldValue.interval(scale: valueInterval) + value(with: d)
            value = v.clip(min: minValue, max: maxValue)
            delegate?.changeValue(self, value: value, oldValue: oldValue, type: .end)
        }
    }
    func value(with delta: CGFloat) -> CGFloat {
        return ((delta/valueX)*valueInterval).interval(scale: valueInterval)
    }
}

protocol ProgressBarDelegate: class {
    func delete(_ progressBar: ProgressBar)
}
final class ProgressBar: LayerRespondable, Localizable {
    static let name = Localization(english: "Progress Bar", japanese: "プログレスバー")
    static let description = Localization(english: "Stop: Send \"Delete\"", japanese: "停止: \"削除\"を送信")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager?
    var locale = Locale.current {
        didSet {
            updateString(with: locale)
        }
    }
    
    weak var delegate: ProgressBarDelegate?
    
    var layer: CALayer {
        return drawLayer
    }
    var drawLayer = DrawLayer(fillColor: Color.subBackground2), barLayer = CALayer()
    var textLine: TextLine {
        didSet {
            layer.setNeedsDisplay()
        }
    }
    
    init(frame: CGRect = CGRect()) {
        textLine = TextLine(isHorizontalCenter: true, isVerticalCenter: true)
        drawLayer.drawBlock = { [unowned self] ctx in
            self.textLine.draw(in: self.bounds, in: ctx)
        }
        layer.frame = frame
        barLayer.backgroundColor = Color.translucentBackground.cgColor
        layer.addSublayer(barLayer)
    }
    
    var value = 0.0.cf {
        didSet {
            barLayer.frame = CGRect(x: 0, y: 0, width: bounds.size.width*value, height: bounds.size.height)
            if let startDate = startDate {
                let time = abs(startDate.timeIntervalSinceNow)
                if time > computationTime && value > 0 {
                    remainingTime = time/value.d - time
                } else {
                    remainingTime = nil
                }
            } else {
                remainingTime = nil
            }
        }
    }
    func begin() {
        startDate = Date()
    }
    func end() {}
    var startDate: Date?
    var remainingTime: Double? {
        didSet {
            updateString(with: Locale.current)
        }
    }
    var computationTime = 5.0, name = ""
    var state: Localization?
    weak var operation: Operation?
    func delete(with event: KeyInputEvent) {
        if let operation = operation {
            operation.cancel()
        }
        delegate?.delete(self)
    }
    func updateString(with locale: Locale) {
        if let state = state {
            textLine.string = state.string(with: locale)
        } else if let remainingTime = remainingTime {
            let minutes = Int(ceil(remainingTime))/60
            let seconds = Int(ceil(remainingTime)) - minutes*60
            if minutes == 0 {
                let translator = Localization(english: "%@sec left", japanese: "あと%@秒").string(with: locale)
                textLine.string = String(format: translator, String(seconds))
            } else {
                let translator = Localization(english: "%@min %@sec left", japanese: "あと%@分%@秒").string(with: locale)
                textLine.string = String(format: translator, String(minutes), String(seconds))
            }
        } else {
            textLine.string = ""
        }
    }
}

final class ImageEditor: LayerRespondable {
    static let name = Localization(english: "Image Editor", japanese: "画像エディタ")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager?
    
    var layer = CALayer()
    init(image: CGImage? = nil) {
        self.image = image
        layer.minificationFilter = kCAFilterTrilinear
        layer.magnificationFilter = kCAFilterTrilinear
    }
    init(url: URL?) {
        self.url = url
        layer.minificationFilter = kCAFilterTrilinear
        layer.magnificationFilter = kCAFilterTrilinear
    }
    
    var image: CGImage? {
        didSet {
            layer.contents = image
        }
    }
    var url: URL? {
        didSet {
            if let url = url {
                guard
                    let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                    let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                        return
                }
                self.image = image
            }
        }
    }
    func delete(with event: KeyInputEvent) {
        removeFromParent()
    }
    enum DragType {
        case move, resizeMinXMinY, resizeMaxXMinY, resizeMinXMaxY, resizeMaxXMaxY
    }
    var dragType = DragType.move, downPosition = CGPoint(), oldFrame = CGRect(), resizeWidth = 10.0.cf, ratio = 1.0.cf
    func drag(with event: DragEvent) {
        if let parent = parent as? LayerRespondable {
            let p = parent.point(from: event), ip = point(from: event)
            switch event.sendType {
            case .begin:
                if CGRect(x: 0, y: 0, width: resizeWidth, height: resizeWidth).contains(ip) {
                    dragType = .resizeMinXMinY
                } else if CGRect(x:  bounds.width - resizeWidth, y: 0, width: resizeWidth, height: resizeWidth).contains(ip) {
                    dragType = .resizeMaxXMinY
                } else if CGRect(x: 0, y: bounds.height - resizeWidth, width: resizeWidth, height: resizeWidth).contains(ip) {
                    dragType = .resizeMinXMaxY
                } else if CGRect(x: bounds.width - resizeWidth, y: bounds.height - resizeWidth, width: resizeWidth, height: resizeWidth).contains(ip) {
                    dragType = .resizeMaxXMaxY
                } else {
                    dragType = .move
                }
                downPosition = p
                oldFrame = frame
                ratio = frame.height/frame.width
            case .sending, .end:
                let dp =  p - downPosition
                var frame = self.frame
                switch dragType {
                case .move:
                    frame.origin = CGPoint(x: oldFrame.origin.x + dp.x, y: oldFrame.origin.y + dp.y)
                case .resizeMinXMinY:
                    frame.origin.x = oldFrame.origin.x + dp.x
                    frame.origin.y = oldFrame.origin.y + dp.y
                    frame.size.width = oldFrame.width - dp.x
                    frame.size.height = frame.size.width*ratio
                case .resizeMaxXMinY:
                    frame.origin.y = oldFrame.origin.y + dp.y
                    frame.size.width = oldFrame.width + dp.x
                    frame.size.height = frame.size.width*ratio
                case .resizeMinXMaxY:
                    frame.origin.x = oldFrame.origin.x + dp.x
                    frame.size.width = oldFrame.width - dp.x
                    frame.size.height = frame.size.width*ratio
                case .resizeMaxXMaxY:
                    frame.size.width = oldFrame.width + dp.x
                    frame.size.height = frame.size.width*ratio
                }
                CATransaction.disableAnimation {
                    self.frame = event.sendType == .end ? frame.integral : frame
                }
            }
        }
    }
}

struct Highlight {
    init() {
        layer.backgroundColor = Color.black.cgColor
        layer.opacity = 0.23
        layer.isHidden = true
    }
    let layer = CALayer()
    var isHighlighted: Bool {
        return !layer.isHidden
    }
    func setIsHighlighted(_ h: Bool, animate: Bool) {
        if !animate {
            CATransaction.disableAnimation {
                layer.isHidden = !h
            }
        } else {
            layer.isHidden = !h
        }
    }
}

final class DrawLayer: CALayer {
    init(fillColor: Color? = nil) {
        if let fillColor = fillColor {
            self.fillColor = fillColor
        }
        super.init()
        self.contentsScale = GlobalVariable.shared.backingScaleFactor
        self.isOpaque = true
        self.needsDisplayOnBoundsChange = true
        self.drawsAsynchronously = true
        self.anchorPoint = CGPoint()
        self.borderWidth = 0.5
        self.borderColor = Color.background.cgColor
    }
    override init(layer: Any) {
        super.init(layer: layer)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func action(forKey event: String) -> CAAction? {
        return event == "contents" ? nil : super.action(forKey: event)
    }
    override var contentsScale: CGFloat {
        didSet {
            setNeedsDisplay()
        }
    }
    var fillColor = Color.white {
        didSet {
            setNeedsDisplay()
        }
    }
    var drawBlock: ((_ in: CGContext) -> Void)?
    override func draw(in ctx: CGContext) {
        ctx.setFillColor(fillColor.cgColor)
        ctx.fill(ctx.boundingBoxOfClipPath)
        drawBlock?(ctx)
    }
}

extension CALayer {
    static func knobLayer(radius r: CGFloat = 5, lineWidth l: CGFloat = 1) -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = Color.content.cgColor
        layer.borderColor = Color.edit.cgColor
        layer.borderWidth = l
        layer.cornerRadius = r
        layer.bounds = CGRect(x: 0, y: 0, width: r*2, height: r*2)
        layer.actions = ["backgroundColor": NSNull()]
        return layer
    }
    static func slideLayer(width w: CGFloat = 5, height h: CGFloat = 10, lineWidth l: CGFloat = 1) -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = Color.content.cgColor
        layer.borderColor = Color.edit.cgColor
        layer.borderWidth = l
        layer.bounds = CGRect(x: 0, y: 0, width: w, height: h)
        layer.actions = ["backgroundColor": NSNull()]
        return layer
    }
    static func selectionLayer() -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = Color(red: 0, green: 0.7, blue: 1, alpha: 0.3).cgColor
        layer.borderColor = Color(red: 0.1, green: 0.4, blue: 1, alpha: 0.5).cgColor
        layer.borderWidth = 1
        return layer
    }
    static func interfaceLayer(isPanel: Bool = false) -> CALayer {
        let layer = CALayer()
        layer.isOpaque = true
        layer.borderWidth = 0.5
        layer.borderColor = isPanel ? Color.panelBorder.cgColor : Color.background.cgColor
        layer.backgroundColor = Color.subBackground.cgColor
        return layer
    }
    func allSublayers(_ handler: (CALayer) -> Void) {
        func allSublayersRecursion(_ layer: CALayer, _ handler: (CALayer) -> Void) {
            if let sublayers = layer.sublayers {
                for sublayer in sublayers {
                    allSublayersRecursion(sublayer, handler)
                }
            }
            handler(layer)
        }
        allSublayersRecursion(self, handler)
    }
}

extension CATransaction {
    static func disableAnimation(_ handler: (Void) -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        handler()
        CATransaction.commit()
    }
}
